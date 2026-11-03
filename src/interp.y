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
%token LE GE EQ NE AND OR
%token <num>  NUMBER
%token <str>  STRING IDENT
%token <ival> SHAPE

%type <node> stmts stmt args arglist arg expr unary primary

/* Lowest to highest precedence. */
%left OR
%left AND
%left EQ NE
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/' '%'

%start program

%%

program
    : stmts                             { /* execution in later commit */ }
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
    : expr                              { $$ = $1; }
    | STRING                            { $$ = mk_str(N_STR, $1, @1.first_line); }
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

unary
    : '-' unary                         { $$ = mk(N_NEG, @1.first_line); $$->a = $2; }
    | '!' unary                         { $$ = mk(N_NOT, @1.first_line); $$->a = $2; }
    | primary                           { $$ = $1; }
    ;

primary
    : NUMBER                            { $$ = mk_num($1, @1.first_line); }
    | IDENT                             { $$ = mk_str(N_VAR, $1, @1.first_line); }
    | '(' expr ')'                      { $$ = $2; }
    ;

%%

static void yyerror(const char *msg)
{
    fprintf(stderr, "%s:%d: %s\n", src_name, yylloc.first_line, msg);
}
