
%code requires {
#include "ast.h"
}

%{
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "runtime.h"

int yylex(void);
extern FILE *yyin;
static void yyerror(const char *msg);
static void compile_program(Node *prog);
%}

%locations
%define parse.error verbose

%union {
    double num;
    char  *str;
    int    ival;
    Node  *node;
}

%token CANVAS PEN SLIDE SPIN GROW INK WHEN OTHERWISE SWIRL STAMP TIMES PATTERN GIVE
%token LE GE EQ NE AND OR
%token <num>  NUMBER
%token <str>  STRING IDENT
%token <ival> SHAPE

%type <node> stmts stmt when_stmt block args arglist arg params expr unary primary

/* Lowest to highest precedence. */
%left OR
%left AND
%left EQ NE
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/' '%'

%start program


%expect 1

%%

program
    : stmts                             { compile_program($1); }
    ;

stmts
    : %empty                            { $$ = NULL; }
    | stmts stmt                        { $$ = append($1, $2); }
    ;

stmt
    : CANVAS NUMBER NUMBER ';'          { $$ = mk(N_CANVAS, @1.first_line); $$->num = $2; $$->num2 = $3; }
    | PEN STRING ';'                    { $$ = mk_str(N_PEN, $2, @1.first_line); }
    | SHAPE '(' args ')' ';'            { $$ = mk(N_SHAPE, @1.first_line); $$->op = $1; $$->args = $3; }
    | SLIDE unary unary ';'             { $$ = mk(N_SLIDE, @1.first_line); $$->a = $2; $$->b = $3; }
    | SPIN '(' expr ')' block           { $$ = mk(N_SPIN, @1.first_line); $$->a = $3; $$->body = $5; }
    | GROW '(' expr ')' block           { $$ = mk(N_GROW, @1.first_line); $$->a = $3; $$->body = $5; }
    | INK IDENT '=' expr ';'            { $$ = mk_str(N_INK, $2, @1.first_line); $$->a = $4; }
    | IDENT '=' expr ';'                { $$ = mk_str(N_ASSIGN, $1, @1.first_line); $$->a = $3; }
    | IDENT '(' args ')' ';'            { $$ = mk(N_CALLSTMT, @1.first_line);
                                          $$->a = mk_str(N_CALL, $1, @1.first_line); $$->a->args = $3; }
    | when_stmt                         { $$ = $1; }
    | SWIRL '(' expr ')' block          { $$ = mk(N_SWIRL, @1.first_line); $$->a = $3; $$->body = $5; }
    | STAMP expr TIMES block            { $$ = mk(N_STAMP, @1.first_line); $$->a = $2; $$->body = $4; }
    | PATTERN IDENT '(' params ')' block
                                        { $$ = mk_str(N_PATTERN, $2, @1.first_line); $$->params = $4; $$->body = $6; }
    | GIVE expr ';'                     { $$ = mk(N_GIVE, @1.first_line); $$->a = $2; }
    ;

/* `otherwise when (...)` chains without extra braces. */
when_stmt
    : WHEN '(' expr ')' block           { $$ = mk(N_WHEN, @1.first_line); $$->a = $3; $$->body = $5; }
    | WHEN '(' expr ')' block OTHERWISE block
                                        { $$ = mk(N_WHEN, @1.first_line); $$->a = $3; $$->body = $5; $$->els = $7; }
    | WHEN '(' expr ')' block OTHERWISE when_stmt
                                        { $$ = mk(N_WHEN, @1.first_line); $$->a = $3; $$->body = $5; $$->els = $7; }
    ;

block
    : '{' stmts '}'                     { $$ = $2; }
    ;

args
    : %empty                            { $$ = NULL; }
    | arglist                           { $$ = $1; }
    ;

arglist
    : arg                               { $$ = $1; }
    | arglist ',' arg                   { $$ = append($1, $3); }
    ;

/* Strings are accepted here so the checker can give a clear message;
 * only text() may take one. */
arg
    : expr                              { $$ = $1; }
    | STRING                            { $$ = mk_str(N_STR, $1, @1.first_line); }
    ;

params
    : %empty                            { $$ = NULL; }
    | IDENT                             { $$ = mk_str(N_VAR, $1, @1.first_line); }
    | params ',' IDENT                  { $$ = append($1, mk_str(N_VAR, $3, @3.first_line)); }
    ;

expr
    : expr OR expr                      { $$ = mk(N_OR, @2.first_line); $$->a = $1; $$->b = $3; }
    | expr AND expr                     { $$ = mk(N_AND, @2.first_line); $$->a = $1; $$->b = $3; }
    | expr EQ expr                      { $$ = mk_bin(OP_EQ, $1, $3, @2.first_line); }
    | expr NE expr                      { $$ = mk_bin(OP_NE, $1, $3, @2.first_line); }
    | expr '<' expr                     { $$ = mk_bin('<', $1, $3, @2.first_line); }
    | expr '>' expr                     { $$ = mk_bin('>', $1, $3, @2.first_line); }
    | expr LE expr                      { $$ = mk_bin(OP_LE, $1, $3, @2.first_line); }
    | expr GE expr                      { $$ = mk_bin(OP_GE, $1, $3, @2.first_line); }
    | expr '+' expr                     { $$ = mk_bin('+', $1, $3, @2.first_line); }
    | expr '-' expr                     { $$ = mk_bin('-', $1, $3, @2.first_line); }
    | expr '*' expr                     { $$ = mk_bin('*', $1, $3, @2.first_line); }
    | expr '/' expr                     { $$ = mk_bin('/', $1, $3, @2.first_line); }
    | expr '%' expr                     { $$ = mk_bin('%', $1, $3, @2.first_line); }
    | unary                             { $$ = $1; }
    ;

/* `slide` takes two unary expressions, so `slide 20 -5;` means (20, -5). */
unary
    : '-' unary                         { $$ = mk(N_NEG, @1.first_line); $$->a = $2; }
    | '!' unary                         { $$ = mk(N_NOT, @1.first_line); $$->a = $2; }
    | primary                           { $$ = $1; }
    ;

primary
    : NUMBER                            { $$ = mk_num($1, @1.first_line); }
    | IDENT                             { $$ = mk_str(N_VAR, $1, @1.first_line); }
    | IDENT '(' args ')'                { $$ = mk_str(N_CALL, $1, @1.first_line); $$->args = $3; }
    | '(' expr ')'                      { $$ = $2; }
    ;

%%

static void yyerror(const char *msg)
{
    fprintf(stderr, "%s:%d: %s\n", src_name, yylloc.first_line, msg);
}

/* ------------------------------------------------------------------ */
/*                         LLVM IR generation                         */
/* ------------------------------------------------------------------ */

static const char *out_name = "out.ll";
static FILE *ir;            /* the .ll file                              */
static FILE *strs;          /* string constants, written at the end      */
static char *strs_buf;
static size_t strs_len;
static int ntmp, nlabel, nstr;
static char cur_label[32];  /* block currently being filled (for phi)    */
static int open_groups;     /* spin/grow groups open in this function    */

/* An IR operand: a register name ("%t3") or a constant. */
typedef struct { char s[48]; } Val;

static Val reg(void)
{
    Val v;
    snprintf(v.s, sizeof v.s, "%%t%d", ntmp++);
    return v;
}

/* Doubles are written in LLVM's exact hexadecimal form. */
static Val constant(double d)
{
    Val v;
    uint64_t bits;
    memcpy(&bits, &d, sizeof bits);
    snprintf(v.s, sizeof v.s, "0x%016" PRIX64, bits);
    return v;
}

static int new_label(void) { return nlabel++; }

static void start_block(int l)
{
    fprintf(ir, "L%d:\n", l);
    snprintf(cur_label, sizeof cur_label, "L%d", l);
}

/* Emit a NUL-terminated global string constant; returns its id. */
static int string_const(const char *s)
{
    size_t n = strlen(s);
    fprintf(strs, "@.str%d = private unnamed_addr constant [%zu x i8] c\"", nstr, n + 1);
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        if (*p < 32 || *p > 126 || *p == '"' || *p == '\\') fprintf(strs, "\\%02X", *p);
        else fputc(*p, strs);
    }
    fputs("\\00\"\n", strs);
    return nstr++;
}

/* Compare a double with zero: produces an i1 "is true" register. */
static Val truth(Val v)
{
    Val c = reg();
    fprintf(ir, "  %s = fcmp une double %s, 0.0\n", c.s, v.s);
    return c;
}

static Val bool_to_double(Val c)
{
    Val d = reg();
    fprintf(ir, "  %s = uitofp i1 %s to double\n", d.s, c.s);
    return d;
}

static Val gen_expr(const Node *e);

/* Evaluate argument list left to right into vals[]; returns the count. */
static int gen_args(const Node *args, Val *vals)
{
    int n = 0;
    for (const Node *a = args; a; a = a->next)
        if (a->kind != N_STR) vals[n++] = gen_expr(a);
    return n;
}

static Val gen_call(const Node *call)
{
    Val vals[64];
    int n = gen_args(call->args, vals);
    Val r = reg();
    fprintf(ir, "  %s = call double @dl_%s(", r.s, call->str);
    for (int i = 0; i < n; i++) fprintf(ir, "%sdouble %s", i ? ", " : "", vals[i].s);
    fputs(")\n", ir);
    return r;
}

/* && and || short-circuit, exactly like the interpreter. */
static Val gen_logic(const Node *e)
{
    int is_and = (e->kind == N_AND);
    int rhs = new_label(), end = new_label();
    Val ca = truth(gen_expr(e->a));
    char from_a[32];
    strcpy(from_a, cur_label);
    if (is_and) fprintf(ir, "  br i1 %s, label %%L%d, label %%L%d\n", ca.s, rhs, end);
    else        fprintf(ir, "  br i1 %s, label %%L%d, label %%L%d\n", ca.s, end, rhs);
    start_block(rhs);
    Val cb = truth(gen_expr(e->b));
    char from_b[32];
    strcpy(from_b, cur_label);
    fprintf(ir, "  br label %%L%d\n", end);
    start_block(end);
    Val r = reg();
    fprintf(ir, "  %s = phi i1 [ %s, %%%s ], [ %s, %%%s ]\n",
            r.s, is_and ? "false" : "true", from_a, cb.s, from_b);
    return bool_to_double(r);
}

static Val gen_expr(const Node *e)
{
    Val a, b, r;
    const char *op = NULL, *cmp = NULL;
    switch (e->kind) {
    case N_NUM: return constant(e->num);
    case N_VAR:
        r = reg();
        fprintf(ir, "  %s = load double, ptr %%s%d\n", r.s, e->slot);
        return r;
    case N_NEG:
        a = gen_expr(e->a);
        r = reg();
        fprintf(ir, "  %s = fneg double %s\n", r.s, a.s);
        return r;
    case N_NOT:
        a = gen_expr(e->a);
        r = reg();
        fprintf(ir, "  %s = fcmp oeq double %s, 0.0\n", r.s, a.s);
        return bool_to_double(r);
    case N_AND: case N_OR: return gen_logic(e);
    case N_CALL: return gen_call(e);
    case N_BIN:
        a = gen_expr(e->a);
        b = gen_expr(e->b);
        switch (e->op) {
        case '+': op = "fadd"; break;
        case '-': op = "fsub"; break;
        case '*': op = "fmul"; break;
        case '/': op = "fdiv"; break;
        case '%': op = "frem"; break;       /* same as C fmod */
        case '<': cmp = "olt"; break;
        case '>': cmp = "ogt"; break;
        case OP_LE: cmp = "ole"; break;
        case OP_GE: cmp = "oge"; break;
        case OP_EQ: cmp = "oeq"; break;
        case OP_NE: cmp = "une"; break;     /* C != is true for NaN */
        }
        r = reg();
        if (op) { fprintf(ir, "  %s = %s double %s, %s\n", r.s, op, a.s, b.s); return r; }
        fprintf(ir, "  %s = fcmp %s double %s, %s\n", r.s, cmp, a.s, b.s);
        return bool_to_double(r);
    default: break;
    }
    return constant(0.0);
}

static void gen_list(const Node *list);

static void gen_shape(const Node *st)
{
    static const char *fn[SH_COUNT] = { "svg_circle", "svg_rect", "svg_line", "svg_triangle", "svg_text" };
    Val vals[6];
    int n = gen_args(st->args, vals);
    int label = -1;
    if (st->op == SH_TEXT) {
        const Node *a = st->args;
        while (a->next) a = a->next;    /* the checker guarantees a string here */
        label = string_const(a->str);
    }
    fprintf(ir, "  call void @%s(i32 %d", fn[st->op], st->line);
    for (int i = 0; i < n; i++) fprintf(ir, ", double %s", vals[i].s);
    if (label >= 0) fprintf(ir, ", ptr @.str%d", label);
    fputs(")\n", ir);
}

static void gen_stmt(const Node *st)
{
    Val a, b, c;
    int l1, l2, l3;
    switch (st->kind) {
    case N_CANVAS:
        fprintf(ir, "  call void @svg_begin(double %s, double %s)\n",
                constant(st->num).s, constant(st->num2).s);
        break;
    case N_PEN:
        fprintf(ir, "  call void @svg_pen(ptr @.str%d)\n", string_const(st->str));
        break;
    case N_SHAPE: gen_shape(st); break;
    case N_SLIDE:
        a = gen_expr(st->a);
        b = gen_expr(st->b);
        fprintf(ir, "  call void @svg_slide(double %s, double %s)\n", a.s, b.s);
        break;
    case N_SPIN:
    case N_GROW:
        a = gen_expr(st->a);
        fprintf(ir, "  call void @%s(i32 %d, double %s)\n",
                st->kind == N_SPIN ? "svg_spin_begin" : "svg_grow_begin", st->line, a.s);
        open_groups++;
        gen_list(st->body);
        open_groups--;
        fputs("  call void @svg_group_end()\n", ir);
        break;
    case N_INK:
    case N_ASSIGN:
        a = gen_expr(st->a);
        fprintf(ir, "  store double %s, ptr %%s%d\n", a.s, st->slot);
        break;
    case N_WHEN:
    case N_SWIRL:
    case N_STAMP:
    default: break;
    }
}
static void gen_list(const Node *list);

static void gen_shape(const Node *st)
{
    static const char *fn[SH_COUNT] = { "svg_circle", "svg_rect", "svg_line", "svg_triangle", "svg_text" };
    Val vals[6];
    int n = gen_args(st->args, vals);
    int label = -1;
    if (st->op == SH_TEXT) {
        const Node *a = st->args;
        while (a->next) a = a->next;    /* the checker guarantees a string here */
        label = string_const(a->str);
    }
    fprintf(ir, "  call void @%s(i32 %d", fn[st->op], st->line);
    for (int i = 0; i < n; i++) fprintf(ir, ", double %s", vals[i].s);
    if (label >= 0) fprintf(ir, ", ptr @.str%d", label);
    fputs(")\n", ir);
}

static void gen_stmt(const Node *st)
{
    Val a, b, c;
    int l1, l2, l3;
    switch (st->kind) {
    case N_CANVAS:
        fprintf(ir, "  call void @svg_begin(double %s, double %s)\n",
                constant(st->num).s, constant(st->num2).s);
        break;
    case N_PEN:
        fprintf(ir, "  call void @svg_pen(ptr @.str%d)\n", string_const(st->str));
        break;
    case N_SHAPE: gen_shape(st); break;
    case N_SLIDE:
        a = gen_expr(st->a);
        b = gen_expr(st->b);
        fprintf(ir, "  call void @svg_slide(double %s, double %s)\n", a.s, b.s);
        break;
    case N_SPIN:
    case N_GROW:
        a = gen_expr(st->a);
        fprintf(ir, "  call void @%s(i32 %d, double %s)\n",
                st->kind == N_SPIN ? "svg_spin_begin" : "svg_grow_begin", st->line, a.s);
        open_groups++;
        gen_list(st->body);
        open_groups--;
        fputs("  call void @svg_group_end()\n", ir);
        break;
    case N_INK:
    case N_ASSIGN:
        a = gen_expr(st->a);
        fprintf(ir, "  store double %s, ptr %%s%d\n", a.s, st->slot);
        break;
    case N_WHEN:
        l1 = new_label(); l2 = new_label(); l3 = new_label();
        c = truth(gen_expr(st->a));
        fprintf(ir, "  br i1 %s, label %%L%d, label %%L%d\n", c.s, l1, l2);
        start_block(l1);
        gen_list(st->body);
        fprintf(ir, "  br label %%L%d\n", l3);
        start_block(l2);
        gen_list(st->els);
        fprintf(ir, "  br label %%L%d\n", l3);
        start_block(l3);
        break;
    case N_SWIRL:
        l1 = new_label(); l2 = new_label(); l3 = new_label();
        fprintf(ir, "  br label %%L%d\n", l1);
        start_block(l1);                                  /* condition */
        c = truth(gen_expr(st->a));
        fprintf(ir, "  br i1 %s, label %%L%d, label %%L%d\n", c.s, l2, l3);
        start_block(l2);                                  /* body */
        gen_list(st->body);
        fprintf(ir, "  br label %%L%d\n", l1);
        start_block(l3);                                  /* exit */
        break;
    case N_STAMP:
        /* counter in slot, limit in slot+1; count evaluated once */
        a = gen_expr(st->a);
        fprintf(ir, "  store double %s, ptr %%s%d\n", a.s, st->slot + 1);
        fprintf(ir, "  store double 0.0, ptr %%s%d\n", st->slot);
        l1 = new_label(); l2 = new_label(); l3 = new_label();
        fprintf(ir, "  br label %%L%d\n", l1);
        start_block(l1);
        a = reg(); b = reg(); c = reg();
        fprintf(ir, "  %s = load double, ptr %%s%d\n", a.s, st->slot);
        fprintf(ir, "  %s = load double, ptr %%s%d\n", b.s, st->slot + 1);
        fprintf(ir, "  %s = fcmp olt double %s, %s\n", c.s, a.s, b.s);
        fprintf(ir, "  br i1 %s, label %%L%d, label %%L%d\n", c.s, l2, l3);
        start_block(l2);
        gen_list(st->body);
        a = reg(); b = reg();
        fprintf(ir, "  %s = load double, ptr %%s%d\n", a.s, st->slot);
        fprintf(ir, "  %s = fadd double %s, 1.0\n", b.s, a.s);
        fprintf(ir, "  store double %s, ptr %%s%d\n", b.s, st->slot);
        fprintf(ir, "  br label %%L%d\n", l1);
        start_block(l3);
        break;
    case N_GIVE:
        a = gen_expr(st->a);
        for (int i = 0; i < open_groups; i++)          /* close open spin/grow */
            fputs("  call void @svg_group_end()\n", ir);
        fprintf(ir, "  ret double %s\n", a.s);
        start_block(new_label());                      /* unreachable code after give */
        break;
    case N_CALLSTMT: gen_call(st->a); break;
    case N_PATTERN: break;                             /* emitted separately */
    default: break;
    }
}

static void gen_list(const Node *list)
{
    for (; list; list = list->next) gen_stmt(list);
}

static void gen_allocas(int nslots)
{
    for (int i = 0; i < nslots; i++) fprintf(ir, "  %%s%d = alloca double\n", i);
    for (int i = 0; i < nslots; i++) fprintf(ir, "  store double 0.0, ptr %%s%d\n", i);
}

static void gen_pattern(const Node *p)
{
    fprintf(ir, "\ndefine double @dl_%s(", p->str);
    for (int i = 0; i < p->nparams; i++) fprintf(ir, "%sdouble %%p%d", i ? ", " : "", i);
    fputs(") {\nentry:\n", ir);
    strcpy(cur_label, "entry");
    gen_allocas(p->nslots);
    for (int i = 0; i < p->nparams; i++) fprintf(ir, "  store double %%p%d, ptr %%s%d\n", i, i);
    open_groups = 0;
    gen_list(p->body);
    fputs("  ret double 0.0\n}\n", ir);               /* no give -> 0 */
}

/* Start-rule action: check everything, then print the whole module. */
static void compile_program(Node *prog)
{
    int nslots;
    if (check_program(prog, &nslots) > 0) exit(1);

    ir = fopen(out_name, "w");
    if (!ir) { perror(out_name); exit(1); }
    strs = open_memstream(&strs_buf, &strs_len);

    fprintf(ir, "; DrawLang program compiled from %s\n\n", src_name);
    fputs("declare void @svg_begin(double, double)\n"
          "declare void @svg_end()\n"
          "declare void @svg_pen(ptr)\n"
          "declare void @svg_slide(double, double)\n"
          "declare void @svg_circle(i32, double, double, double)\n"
          "declare void @svg_rect(i32, double, double, double, double)\n"
          "declare void @svg_line(i32, double, double, double, double)\n"
          "declare void @svg_triangle(i32, double, double, double, double, double, double)\n"
          "declare void @svg_text(i32, double, double, double, ptr)\n"
          "declare void @svg_spin_begin(i32, double)\n"
          "declare void @svg_grow_begin(i32, double)\n"
          "declare void @svg_group_end()\n", ir);

    for (const Node *st = prog; st; st = st->next)
        if (st->kind == N_PATTERN) gen_pattern(st);

    fputs("\ndefine i32 @main() {\nentry:\n", ir);
    strcpy(cur_label, "entry");
    gen_allocas(nslots);
    open_groups = 0;
    gen_list(prog);
    fputs("  call void @svg_end()\n  ret i32 0\n}\n", ir);

    fclose(strs);
    fprintf(ir, "\n%s", strs_buf);
    free(strs_buf);
    fclose(ir);
}

int main(int argc, char **argv)
{
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) out_name = argv[++i];
        else src_name = argv[i];
    }
    yyin = fopen(src_name, "r");
    if (!yyin) { perror(src_name); return 1; }
    if (yyparse() != 0) return 1;
    printf("wrote %s\n", out_name);
    return 0;
}
