
#include "runtime.h"
#include <stdio.h>
#include <stdlib.h>

#define OUTPUT_FILE "picture.svg"

const char *const shape_names[SH_COUNT] = { "circle", "rect", "line", "triangle", "text" };
const int shape_argc[SH_COUNT] = { 3, 4, 4, 6, 4 };

static FILE *out;
static double canvas_w, canvas_h;
static const char *pen = "black";   
static double off_x, off_y;         
static int depth;                   

static int inside(double x, double y, double W, double H)
{
    return x >= 0 && x <= W && y >= 0 && y <= H;
}

static void outside_msg(char *buf, size_t n, const char *what, double ox, double oy,
                        double W, double H)
{
    if (ox != 0 || oy != 0)
        snprintf(buf, n, "%s (after slide %g %g) is outside the %gx%g canvas", what, ox, oy, W, H);
    else
        snprintf(buf, n, "%s is outside the %gx%g canvas", what, W, H);
}

int dl_shape_error(int kind, const double *v, double ox, double oy,
                   double W, double H, char *buf, size_t n)
{
    char what[160];
    switch (kind) {
    case SH_CIRCLE:
        if (v[2] < 0) { snprintf(buf, n, "circle radius is negative (%g)", v[2]); return 1; }
        if (!inside(v[0] - v[2] + ox, v[1] - v[2] + oy, W, H) || !inside(v[0] + v[2] + ox, v[1] + v[2] + oy, W, H)) {
            snprintf(what, sizeof what, "circle(%g, %g, %g)", v[0], v[1], v[2]);
            outside_msg(buf, n, what, ox, oy, W, H);
            return 1;
        }
        return 0;
    case SH_RECT:
        if (v[2] < 0 || v[3] < 0) { snprintf(buf, n, "rect has a negative size (%g x %g)", v[2], v[3]); return 1; }
        if (!inside(v[0] + ox, v[1] + oy, W, H) || !inside(v[0] + v[2] + ox, v[1] + v[3] + oy, W, H)) {
            snprintf(what, sizeof what, "rect(%g, %g, %g, %g)", v[0], v[1], v[2], v[3]);
            outside_msg(buf, n, what, ox, oy, W, H);
            return 1;
        }
        return 0;
    case SH_LINE:
        if (!inside(v[0] + ox, v[1] + oy, W, H) || !inside(v[2] + ox, v[3] + oy, W, H)) {
            snprintf(what, sizeof what, "line(%g, %g, %g, %g)", v[0], v[1], v[2], v[3]);
            outside_msg(buf, n, what, ox, oy, W, H);
            return 1;
        }
        return 0;
    case SH_TRIANGLE:
        for (int i = 0; i < 6; i += 2)
            if (!inside(v[i] + ox, v[i + 1] + oy, W, H)) {
                snprintf(what, sizeof what, "triangle corner (%g, %g)", v[i], v[i + 1]);
                outside_msg(buf, n, what, ox, oy, W, H);
                return 1;
            }
        return 0;
    case SH_TEXT:
        if (v[2] < 0) { snprintf(buf, n, "text size is negative (%g)", v[2]); return 1; }
        if (!inside(v[0] + ox, v[1] + oy, W, H)) {
            snprintf(what, sizeof what, "text at (%g, %g)", v[0], v[1]);
            outside_msg(buf, n, what, ox, oy, W, H);
            return 1;
        }
        return 0;
    }
    return 0;
}

static void runtime_error(int line, const char *msg)
{
    fprintf(stderr, "runtime error: %s\n", msg);
    if (out) { fclose(out); remove(OUTPUT_FILE); }
    exit(1);
}

static void check(int kind, int line, const double *v)
{
    char msg[256];
    if (dl_shape_error(kind, v, off_x, off_y, canvas_w, canvas_h, msg, sizeof msg))
        runtime_error(line, msg);
}

static void indent(void)
{
    for (int i = 0; i <= depth; i++) fputs("  ", out);
}

void svg_begin(double w, double h)
{
    out = fopen(OUTPUT_FILE, "w");
    if (!out) { perror(OUTPUT_FILE); exit(1); }
    canvas_w = w; canvas_h = h;
    fprintf(out, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%g\" height=\"%g\" viewBox=\"0 0 %g %g\">\n", w, h, w, h);
    fprintf(out, "  <rect width=\"%g\" height=\"%g\" fill=\"white\"/>\n", w, h);
}

void svg_end(void)
{
    fputs("</svg>\n", out);
    fclose(out);
    out = NULL;
    printf("wrote " OUTPUT_FILE "\n");
}

void svg_pen(const char *colour) { pen = colour; }

void svg_slide(double dx, double dy) { off_x += dx; off_y += dy; }

void svg_circle(int line, double x, double y, double r)
{
    double v[] = { x, y, r };
    check(SH_CIRCLE, line, v);
    indent();
    fprintf(out, "<circle cx=\"%g\" cy=\"%g\" r=\"%g\" fill=\"%s\"/>\n", x + off_x, y + off_y, r, pen);
}

void svg_rect(int line, double x, double y, double w, double h)
{
    double v[] = { x, y, w, h };
    check(SH_RECT, line, v);
    indent();
    fprintf(out, "<rect x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\" fill=\"%s\"/>\n", x + off_x, y + off_y, w, h, pen);
}

void svg_line(int line, double x1, double y1, double x2, double y2)
{
    double v[] = { x1, y1, x2, y2 };
    check(SH_LINE, line, v);
    indent();
    fprintf(out, "<line x1=\"%g\" y1=\"%g\" x2=\"%g\" y2=\"%g\" stroke=\"%s\" stroke-width=\"2\"/>\n",
            x1 + off_x, y1 + off_y, x2 + off_x, y2 + off_y, pen);
}

void svg_triangle(int line, double x1, double y1, double x2, double y2, double x3, double y3)
{
    double v[] = { x1, y1, x2, y2, x3, y3 };
    check(SH_TRIANGLE, line, v);
    indent();
    fprintf(out, "<polygon points=\"%g,%g %g,%g %g,%g\" fill=\"%s\"/>\n",
            x1 + off_x, y1 + off_y, x2 + off_x, y2 + off_y, x3 + off_x, y3 + off_y, pen);
}

void svg_text(int line, double x, double y, double size, const char *s)
{
    double v[] = { x, y, size };
    check(SH_TEXT, line, v);
    indent();
    fprintf(out, "<text x=\"%g\" y=\"%g\" font-size=\"%g\" fill=\"%s\">", x + off_x, y + off_y, size, pen);
    for (; *s; s++) {          
        switch (*s) {
        case '<': fputs("&lt;", out); break;
        case '>': fputs("&gt;", out); break;
        case '&': fputs("&amp;", out); break;
        default: fputc(*s, out);
        }
    }
    fputs("</text>\n", out);
}

void svg_spin_begin(int line, double angle)
{
    (void)line;
    indent();
    fprintf(out, "<g transform=\"rotate(%g %g %g)\">\n", angle, off_x, off_y);
    depth++;
}

void svg_grow_begin(int line, double factor)
{
    if (factor <= 0) {
        char msg[64];
        snprintf(msg, sizeof msg, "grow factor must be positive (%g)", factor);
        runtime_error(line, msg);
    }
    indent();
    fprintf(out, "<g transform=\"translate(%g %g) scale(%g) translate(%g %g)\">\n",
            off_x, off_y, factor, 0.0 - off_x, 0.0 - off_y); /* 0-x avoids printing "-0" */
    depth++;
}

void svg_group_end(void)
{
    depth--;
    indent();
    fputs("</g>\n", out);
}
