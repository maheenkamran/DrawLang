%option noyywrap nounput noinput yylineno

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "runtime.h"
#include "parser.h"

#define YY_USER_ACTION yylloc.first_line = yylloc.last_line = yylineno;

static char *unquote(const char *s, int len)
{
    char *out = malloc(len), *o = out;
    for (int i = 1; i < len - 1; i++) {
        if (s[i] == '\\' && i + 1 < len - 1) {
            i++;
            *o++ = (s[i] == 'n') ? '\n' : s[i];
        } else {
            *o++ = s[i];
        }
    }
    *o = '\0';
    return out;
}
%}

%%

"//".*                  { /* line comment */ }

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
\"([^\"\\\n]|\\.)*\"     { yylval.str = unquote(yytext, yyleng); return STRING; }

"<="                    { return LE; }
">="                    { return GE; }
"=="                    { return EQ; }
"!="                    { return NE; }
"&&"                    { return AND; }
"||"                    { return OR; }
[-+*/%<>=!(){},;]       { return yytext[0]; }

%%
