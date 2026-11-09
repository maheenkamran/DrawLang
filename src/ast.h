#ifndef DRAWLANG_AST_H
#define DRAWLANG_AST_H

typedef enum {
    N_NUM, /* num */
    N_STR, /* str */
    N_VAR,      
    N_BIN, /* op, a, b (+ - * / % < > <= >= == != ) */
    N_AND, /* a && b */
    N_OR, /* a || b */
    N_NEG, /* -a */
    N_NOT,/* !a*/
    N_CALL,/* str = pattern name, args, target*/
    N_CANVAS, /* num = width, num2 = height*/
    N_PEN,   /* str = colour */
    N_SHAPE,    
    N_SLIDE, /* a = dx, b = dy */
    N_SPIN, /* a = angle, body */
    N_GROW, /* a = factor, body  */
    N_INK, /* str = name, a = initial value, slot   */
    N_ASSIGN, /* str = name, a = value, slot  */
    N_WHEN,/* a = cond, body, els */
    N_SWIRL, /* a = cond, body */
    N_STAMP, /* a = count, body, slot = counter slots */
    N_PATTERN, /* str = name, params, body, nslots */
    N_GIVE, /* a = value  */
    N_CALLSTMT /* a = N_CALL */
} Kind;

enum { OP_LE = 256, OP_GE, OP_EQ, OP_NE };

typedef struct Node Node;
struct Node {
    Kind kind;
    int line;
    int op;
    double num, num2;
    char *str;
    Node *a, *b;
    Node *args;        
    Node *params;      
    Node *body, *els;  
    Node *target;      
    int slot;          
    int nslots;        
    int nparams;
    Node *next;        /* next node*/
};

//Tree construction 
Node *mk(Kind k, int line);
Node *mk_num(double v, int line);
Node *mk_str(Kind k, char *s, int line);
Node *mk_bin(int op, Node *a, Node *b, int line);
Node *append(Node *list, Node *item);
int list_len(const Node *list);

int check_program(Node *prog, int *main_slots);

extern const char *src_name;

#endif
