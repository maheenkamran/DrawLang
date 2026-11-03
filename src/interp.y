%code requires {
#include "ast.h"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include "ast.h"
#include "runtime.h"

int yylex(void);
extern FILE *yyin;
static void yyerror(const char *msg);
%}

%locations
%define parse.error verbose

%union {
    double num;
    char  *str;
    int    ival;
    Node  *node;
}

%token CANVAS PEN
%token <num>  NUMBER
%token <str>  STRING IDENT
%token <ival> SHAPE

%type <node> stmts stmt args arglist arg

%start program

%%

program
    : stmts                             { /* execution handled in later commit */ }
    ;

stmts
    : %empty                            { $$ = NULL; }
    | stmts stmt                        { $$ = append($1, $2); }
    ;

stmt
    : CANVAS NUMBER NUMBER ';'          { $$ = mk(N_CANVAS, @1.first_line); $$->num = $2; $$->num2 = $3; }
    | PEN STRING ';'                    { $$ = mk_str(N_PEN, $2, @1.first_line); }
    | SHAPE '(' args ')' ';'            { $$ = mk(N_SHAPE, @1.first_line); $$->op = $1; $$->args = $3; }
    ;

args
    : %empty                            { $$ = NULL; }
    | arglist                           { $$ = $1; }
    ;

arglist
    : arg                               { $$ = $1; }
    | arglist ',' arg                   { $$ = append($1, $3); }
    ;

arg
    : NUMBER                            { $$ = mk_num($1, @1.first_line); }
    | STRING                            { $$ = mk_str(N_STR, $1, @1.first_line); }
    ;

%%

static void yyerror(const char *msg)
{
    fprintf(stderr, "%s:%d: %s\n", src_name, yylloc.first_line, msg);
}
