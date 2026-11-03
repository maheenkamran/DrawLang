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
    (void)line;
    fprintf(out, "  <circle cx=\"%g\" cy=\"%g\" r=\"%g\" fill=\"%s\"/>\n", x + off_x, y + off_y, r, pen);
}

void svg_rect(int line, double x, double y, double w, double h)
{
    (void)line;
    fprintf(out, "  <rect x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\" fill=\"%s\"/>\n", x + off_x, y + off_y, w, h, pen);
}

void svg_line(int line, double x1, double y1, double x2, double y2)
{
    (void)line;
    fprintf(out, "  <line x1=\"%g\" y1=\"%g\" x2=\"%g\" y2=\"%g\" stroke=\"%s\" stroke-width=\"2\"/>\n",
            x1 + off_x, y1 + off_y, x2 + off_x, y2 + off_y, pen);
}

void svg_triangle(int line, double x1, double y1, double x2, double y2, double x3, double y3)
{
    (void)line;
    fprintf(out, "  <polygon points=\"%g,%g %g,%g %g,%g\" fill=\"%s\"/>\n",
            x1 + off_x, y1 + off_y, x2 + off_x, y2 + off_y, x3 + off_x, y3 + off_y, pen);
}

void svg_text(int line, double x, double y, double size, const char *s)
{
    (void)line;
    fprintf(out, "  <text x=\"%g\" y=\"%g\" font-size=\"%g\" fill=\"%s\">%s</text>\n", x + off_x, y + off_y, size, pen, s);
}
