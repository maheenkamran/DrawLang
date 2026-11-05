/*
 * DrawLang compile-time checks, shared by both phases.
 *
 * Runs on the whole tree before anything executes or any IR is printed:
 *   - canvas must be the first statement (exactly once, positive size)
 *   - unknown colour names in pen
 *   - wrong argument count for a shape or a pattern
 *   - undeclared (or redeclared) variables, unknown patterns
 *   - shapes outside the canvas / negative sizes, for every shape whose
 *     arguments are compile-time constants (literals and arithmetic on
 *     them) and whose slide offset is known at compile time. Other shapes
 *     are checked by the runtime with exactly the same rules.
 * Also resolves each variable to a slot in its function's frame, so the
 * interpreter and the code generator never look names up by string.
 */
#include "ast.h"
#include "runtime.h"
#include <ctype.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

const char *src_name = "source.draw";

static int errors;
static double canvas_w, canvas_h;
static Node *patterns;  


static int off_known = 1;
static double off_x, off_y;
static int pattern_slides;   
static int program_slides;  

static int has_slide(const Node *list)
{
    for (; list; list = list->next)
        if (list->kind == N_SLIDE || has_slide(list->body) || has_slide(list->els)) return 1;
    return 0;
}

static void error(int line, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "%s:%d: error: ", src_name, line);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
    errors++;
}

static const char *const colours[] = {
    "aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige", "bisque", "black",
    "blanchedalmond", "blue", "blueviolet", "brown", "burlywood", "cadetblue", "chartreuse",
    "chocolate", "coral", "cornflowerblue", "cornsilk", "crimson", "cyan", "darkblue",
    "darkcyan", "darkgoldenrod", "darkgray", "darkgreen", "darkgrey", "darkkhaki",
    "darkmagenta", "darkolivegreen", "darkorange", "darkorchid", "darkred", "darksalmon",
    "darkseagreen", "darkslateblue", "darkslategray", "darkslategrey", "darkturquoise",
    "darkviolet", "deeppink", "deepskyblue", "dimgray", "dimgrey", "dodgerblue", "firebrick",
    "floralwhite", "forestgreen", "fuchsia", "gainsboro", "ghostwhite", "gold", "goldenrod",
    "gray", "grey", "green", "greenyellow", "honeydew", "hotpink", "indianred", "indigo",
    "ivory", "khaki", "lavender", "lavenderblush", "lawngreen", "lemonchiffon", "lightblue",
    "lightcoral", "lightcyan", "lightgoldenrodyellow", "lightgray", "lightgreen", "lightgrey",
    "lightpink", "lightsalmon", "lightseagreen", "lightskyblue", "lightslategray",
    "lightslategrey", "lightsteelblue", "lightyellow", "lime", "limegreen", "linen", "magenta",
    "maroon", "mediumaquamarine", "mediumblue", "mediumorchid", "mediumpurple",
    "mediumseagreen", "mediumslateblue", "mediumspringgreen", "mediumturquoise",
    "mediumvioletred", "midnightblue", "mintcream", "mistyrose", "moccasin", "navajowhite",
    "navy", "oldlace", "olive", "olivedrab", "orange", "orangered", "orchid", "palegoldenrod",
    "palegreen", "paleturquoise", "palevioletred", "papayawhip", "peachpuff", "peru", "pink",
    "plum", "powderblue", "purple", "red", "rosybrown", "royalblue", "saddlebrown", "salmon",
    "sandybrown", "seagreen", "seashell", "sienna", "silver", "skyblue", "slateblue",
    "slategray", "slategrey", "snow", "springgreen", "steelblue", "tan", "teal", "thistle",
    "tomato", "turquoise", "violet", "wheat", "white", "whitesmoke", "yellow", "yellowgreen",
};

static int valid_colour(const char *c)
{
    if (c[0] == '#') {
        size_t n = strlen(c + 1);
        if (n != 3 && n != 6) return 0;
        for (size_t i = 1; i <= n; i++)
            if (!isxdigit((unsigned char)c[i])) return 0;
        return 1;
    }
    for (size_t i = 0; i < sizeof colours / sizeof *colours; i++)
        if (strcasecmp(c, colours[i]) == 0) return 1;
    return 0;
}


#define MAX_VARS 1024
typedef struct {
    const char *names[MAX_VARS];
    int count;      
    int nslots;     
    int in_pattern;
} Scope;

static int lookup(Scope *s, const char *name)
{
    for (int i = 0; i < s->count; i++)
        if (strcmp(s->names[i], name) == 0) return i;
    return -1;
}

static int declare(Scope *s, const char *name, int line)
{
    if (lookup(s, name) >= 0) { error(line, "variable '%s' is already declared", name); return lookup(s, name); }
    if (s->count == MAX_VARS) { error(line, "too many variables"); return 0; }
    s->names[s->count] = name;
    return s->count++;
}

static Node *find_pattern(const char *name)
{
    for (Node *p = patterns; p; p = p->target)
        if (strcmp(p->str, name) == 0) return p;
    return NULL;
}

static int fold(const Node *e, double *v)
{
    double a, b;
    switch (e->kind) {
    case N_NUM: *v = e->num; return 1;
    case N_NEG: if (!fold(e->a, &a)) return 0; *v = -a; return 1;
    case N_BIN:
        if (!fold(e->a, &a) || !fold(e->b, &b)) return 0;
        switch (e->op) {
        case '+': *v = a + b; return 1;
        case '-': *v = a - b; return 1;
        case '*': *v = a * b; return 1;
        case '/': *v = a / b; return 1;
        default: return 0;
        }
    default: return 0;
    }
}

static void check_expr(Node *e, Scope *s);
static void check_list(Node *list, Scope *s, int top_level);

static void check_args(Node *args, Scope *s)
{
    for (Node *a = args; a; a = a->next) {
        if (a->kind == N_STR) error(a->line, "a string is only allowed as the last argument of text()");
        else check_expr(a, s);
    }
}

static void check_expr(Node *e, Scope *s)
{
    switch (e->kind) {
    case N_NUM: break;
    case N_STR: error(e->line, "a string cannot be used in an expression"); break;
    case N_VAR:
        e->slot = lookup(s, e->str);
        if (e->slot < 0) { error(e->line, "undeclared variable '%s'", e->str); e->slot = 0; }
        break;
    case N_BIN: case N_AND: case N_OR:
        check_expr(e->a, s); check_expr(e->b, s); break;
    case N_NEG: case N_NOT:
        check_expr(e->a, s); break;
    case N_CALL:
        if (pattern_slides) off_known = 0;   /* the call may move the pen */
        e->target = find_pattern(e->str);
        if (!e->target) error(e->line, "unknown pattern '%s'", e->str);
        else if (list_len(e->args) != e->target->nparams)
            error(e->line, "pattern '%s' expects %d argument(s) but got %d",
                  e->str, e->target->nparams, list_len(e->args));
        check_args(e->args, s);
        break;
    default: break;
    }
}

static void check_shape(Node *st, Scope *s)
{
    int kind = st->op, argc = list_len(st->args);
    if (argc != shape_argc[kind]) {
        error(st->line, "%s expects %d argument(s) but got %d", shape_names[kind], shape_argc[kind], argc);
        check_args(st->args, s);
        return;
    }
    double v[6];
    int constant = 1, i = 0;
    for (Node *a = st->args; a; a = a->next, i++) {
        int is_label = (kind == SH_TEXT && i == 3);
        if (is_label) {
            if (a->kind != N_STR) error(a->line, "the last argument of text() must be a string");
            continue;
        }
        if (a->kind == N_STR) { error(a->line, "a string is only allowed as the last argument of text()"); constant = 0; continue; }
        check_expr(a, s);
        constant = 0;
    }
    char msg[256];
    if (constant && off_known && dl_shape_error(kind, v, off_x, off_y, canvas_w, canvas_h, msg, sizeof msg))
        error(st->line, "%s", msg);
}

static void assign_hidden(Node *list, Scope *s)
{
    for (Node *st = list; st; st = st->next) {
        if (st->kind == N_STAMP) { st->slot = s->nslots; s->nslots += 2; }  
        if (st->kind != N_PATTERN) { assign_hidden(st->body, s); assign_hidden(st->els, s); }
    }
}

static void check_stmt(Node *st, Scope *s, int top_level, int first)
{
    double v, dx, dy;
    if (st->kind != N_PATTERN && (has_slide(st->body) || has_slide(st->els))) off_known = 0;
    switch (st->kind) {
    case N_CANVAS:
        if (!top_level || !first) error(st->line, "canvas must be the first statement of the program");
        break;
    case N_PEN:
        if (!valid_colour(st->str)) error(st->line, "unknown colour \"%s\"", st->str);
        break;
    case N_SHAPE: check_shape(st, s); break;
    case N_SLIDE:
        check_expr(st->a, s);
        check_expr(st->b, s);
        if (top_level && fold(st->a, &dx) && fold(st->b, &dy)) { off_x += dx; off_y += dy; }
        else off_known = 0;
        break;
    case N_SPIN: check_expr(st->a, s); check_list(st->body, s, 0); break;
    case N_GROW:
        check_expr(st->a, s);
        if (fold(st->a, &v) && v <= 0) error(st->line, "grow factor must be positive (%g)", v);
        check_list(st->body, s, 0);
        break;
    case N_INK:
        check_expr(st->a, s);              
        st->slot = declare(s, st->str, st->line);
        break;
    case N_ASSIGN:
        check_expr(st->a, s);
        st->slot = lookup(s, st->str);
        if (st->slot < 0) { error(st->line, "undeclared variable '%s'", st->str); st->slot = 0; }
        break;
    case N_WHEN: check_expr(st->a, s); check_list(st->body, s, 0); check_list(st->els, s, 0); break;
    case N_SWIRL: check_expr(st->a, s); check_list(st->body, s, 0); break;
    case N_STAMP: check_expr(st->a, s); check_list(st->body, s, 0); break;
    case N_GIVE:
        if (!s->in_pattern) error(st->line, "give can only be used inside a pattern");
        check_expr(st->a, s);
        break;
    case N_CALLSTMT: check_expr(st->a, s); break;
    case N_PATTERN:
        if (!top_level) error(st->line, "pattern '%s' must be defined at the top level", st->str);
        break;  
    default: break;
    }
}

static void check_list(Node *list, Scope *s, int top_level)
{
    for (Node *st = list; st; st = st->next)
        check_stmt(st, s, top_level, top_level && st == list);
}

static void collect_patterns(Node *list)
{
    for (Node *st = list; st; st = st->next) {
        if (st->kind == N_PATTERN) {
            if (find_pattern(st->str)) error(st->line, "pattern '%s' is already defined", st->str);
            else {                
                Node **tail = &patterns;
                while (*tail) tail = &(*tail)->target;
                *tail = st;
            }
            st->nparams = list_len(st->params);
        }
        collect_patterns(st->body);
        collect_patterns(st->els);
    }
}


int check_program(Node *prog, int *main_slots)
{
    static Scope s;
    if (!prog || prog->kind != N_CANVAS) {
        error(prog ? prog->line : 1, "program must start with 'canvas WIDTH HEIGHT;'");
    } else {
        canvas_w = prog->num; canvas_h = prog->num2;
        if (canvas_w <= 0 || canvas_h <= 0) error(prog->line, "canvas size must be positive");
    }
    check_list(prog, &s, 1);
    s.nslots = s.count;
    assign_hidden(prog, &s);
    *main_slots = s.nslots;
    return errors;
}
