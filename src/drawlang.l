%option noyywrap nounput noinput yylineno

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "runtime.h"
#include "parser.h"

#define YY_USER_ACTION yylloc.first_line = yylloc.last_line = yylineno;
%}

%%

[ \t\r\n]+              { /* whitespace */ }

"canvas"                { return CANVAS; }
"pen"                   { return PEN; }
"circle"                { yylval.ival = SH_CIRCLE;   return SHAPE; }
"rect"                  { yylval.ival = SH_RECT;     return SHAPE; }
"line"                  { yylval.ival = SH_LINE;     return SHAPE; }
"triangle"              { yylval.ival = SH_TRIANGLE; return SHAPE; }
"text"                  { yylval.ival = SH_TEXT;     return SHAPE; }

[0-9]+(\.[0-9]+)?       { yylval.num = strtod(yytext, NULL); return NUMBER; }
[A-Za-z_][A-Za-z0-9_]*  { yylval.str = strdup(yytext); return IDENT; }

%%
