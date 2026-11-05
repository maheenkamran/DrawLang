
%code requires {
#include "ast.h"
}

%{
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "ast.h"
#include "runtime.h"

int yylex(void);
extern FILE *yyin;
static void yyerror(const char *msg);
static void run_program(Node *prog);
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
    : stmts                             { run_program($1); }
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

static int returning;
static double return_value;

static double eval(const Node *e, double *frame);
static void exec_list(const Node *list, double *frame);

static double call_pattern(const Node *call, double *frame)
{
    const Node *p = call->target;
    double *callee = calloc(p->nslots ? p->nslots : 1, sizeof *callee);
    int i = 0;
    for (const Node *a = call->args; a; a = a->next)   /* left to right */
        callee[i++] = eval(a, frame);
    exec_list(p->body, callee);
    double result = returning ? return_value : 0.0;    /* no give -> 0 */
    returning = 0;
    free(callee);
    return result;
}

static double eval(const Node *e, double *frame)
{
    double a, b;
    switch (e->kind) {
    case N_NUM: return e->num;
    case N_VAR: return frame[e->slot];
    case N_NEG: return -eval(e->a, frame);
    case N_NOT: return eval(e->a, frame) == 0.0 ? 1.0 : 0.0;
    case N_AND: return (eval(e->a, frame) != 0.0 && eval(e->b, frame) != 0.0) ? 1.0 : 0.0;
    case N_OR:  return (eval(e->a, frame) != 0.0 || eval(e->b, frame) != 0.0) ? 1.0 : 0.0;
    case N_CALL: return call_pattern(e, frame);
    case N_BIN:
        a = eval(e->a, frame);
        b = eval(e->b, frame);
        switch (e->op) {
        case '+': return a + b;
        case '-': return a - b;
        case '*': return a * b;
        case '/': return a / b;
        case '%': return fmod(a, b);
        case '<': return a < b;
        case '>': return a > b;
        case OP_LE: return a <= b;
        case OP_GE: return a >= b;
        case OP_EQ: return a == b;
        case OP_NE: return a != b;
        }
        break;
    default: break;
    }
    return 0.0;
}


static void exec_stmt(const Node *st, double *frame) { (void)st; (void)frame; }
static void exec_list(const Node *list, double *frame) { (void)list; (void)frame; }
static void run_program(Node *prog) {
    int nslots;
    if (check_program(prog, &nslots) > 0) exit(1);
}
int main(int argc, char **argv) {
    if (argc > 1) src_name = argv[1];
    yyin = fopen(src_name, "r");
    if (!yyin) return 1;
    return yyparse() != 0;
}
