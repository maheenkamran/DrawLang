#include "runtime.h"
#include <stdio.h>
#include <stdlib.h>

#define OUTPUT_FILE "picture.svg"

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
