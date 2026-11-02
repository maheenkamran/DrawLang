
#ifndef DRAWLANG_RUNTIME_H
#define DRAWLANG_RUNTIME_H

#include <stddef.h>

enum { SH_CIRCLE, SH_RECT, SH_LINE, SH_TRIANGLE, SH_TEXT, SH_COUNT };

extern const char *const shape_names[SH_COUNT];
extern const int shape_argc[SH_COUNT];


int dl_shape_error(int kind, const double *v, double ox, double oy,
                   double W, double H,
                   char *buf, size_t n);

void svg_begin(double w, double h);
void svg_end(void);

void svg_pen(const char *colour);
void svg_slide(double dx, double dy);

void svg_circle(int line, double x, double y, double r);
void svg_rect(int line, double x, double y, double w, double h);
void svg_line(int line, double x1, double y1, double x2, double y2);
void svg_triangle(int line, double x1, double y1, double x2, double y2,
                  double x3, double y3);
void svg_text(int line, double x, double y, double size, const char *s);

void svg_spin_begin(int line, double angle);
void svg_grow_begin(int line, double factor);
void svg_group_end(void);

#endif
