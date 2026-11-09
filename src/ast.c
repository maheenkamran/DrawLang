#include "ast.h"
#include <stdio.h>
#include <stdlib.h>

//memory allocator
Node *mk(Kind k, int line)
{
    Node *n = calloc(1, sizeof *n);
    if (!n) { perror("calloc"); exit(1); }
    n->kind = k;
    n->line = line;
    return n;
}

//numeric node
Node *mk_num(double v, int line)
{
    Node *n = mk(N_NUM, line);
    n->num = v;
    return n;
}

//string node
Node *mk_str(Kind k, char *s, int line)
{
    Node *n = mk(k, line);
    n->str = s;
    return n;
}

Node *mk_bin(int op, Node *a, Node *b, int line)
{
    Node *n = mk(N_BIN, line);
    n->op = op;
    n->a = a;
    n->b = b;
    return n;
}

// append item to the end of a next-linked list
Node *append(Node *list, Node *item)
{
    if (!list) return item;
    Node *p = list;
    while (p->next) p = p->next;
    p->next = item;
    return list;
}

int list_len(const Node *list)
{
    int n = 0;
    for (; list; list = list->next) n++;
    return n;
}
