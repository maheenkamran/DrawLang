#include "ast.h"
#include "runtime.h"
#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

const char *src_name = "source.draw";
static int errors;
static double canvas_w, canvas_h;

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
    "black", "blue", "green", "red", "white", "yellow", "gray", "purple", "orange"
};

static int valid_colour(const char *c)
{
    if (c[0] == '#') return 1;
    for (size_t i = 0; i < sizeof colours / sizeof *colours; i++)
        if (strcasecmp(c, colours[i]) == 0) return 1;
    return 0;
}

int check_program(Node *prog, int *main_slots)
{
    *main_slots = 0;
    if (!prog || prog->kind != N_CANVAS) {
        error(prog ? prog->line : 1, "program must start with 'canvas WIDTH HEIGHT;'");
    } else {
        canvas_w = prog->num; canvas_h = prog->num2;
        if (canvas_w <= 0 || canvas_h <= 0) error(prog->line, "canvas size must be positive");
    }
    for (Node *st = prog; st; st = st->next) {
        if (st->kind == N_PEN && !valid_colour(st->str))
            error(st->line, "unknown colour \"%s\"", st->str);
        if (st->kind == N_SHAPE) {
            int argc = list_len(st->args);
            if (argc != shape_argc[st->op])
                error(st->line, "%s expects %d argument(s) but got %d", shape_names[st->op], shape_argc[st->op], argc);
        }
    }
    return errors;
}
