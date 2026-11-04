
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
    | INK IDENT '=' expr ';'            { $$ = mk_str(N_INK, $2, @1.first_line); $$->a = $4; }
    | IDENT '=' expr ';'                { $$ = mk_str(N_ASSIGN, $1, @1.first_line); $$->a = $3; }
    | IDENT '(' args ')' ';'            { $$ = mk(N_CALLSTMT, @1.first_line);
                                          $$->a = mk_str(N_CALL, $1, @1.first_line); $$->a->args = $3; }
    | when_stmt                         { $$ = $1; }
    | SWIRL '(' expr ')' block          { $$ = mk(N_SWIRL, @1.first_line); $$->a = $3; $$->body = $5; }
    | STAMP expr TIMES block            { $$ = mk(N_STAMP, @1.first_line); $$->a = $2; $$->body = $4; }
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


static void run_program(Node *prog) { (void)prog; }
int main(int argc, char **argv) {
    if (argc > 1) src_name = argv[1];
    yyin = fopen(src_name, "r");
    if (!yyin) return 1;
    return yyparse() != 0;
}
