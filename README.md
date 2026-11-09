# DrawLang

DrawLang is a small language for drawing pictures with code. You write a
`.draw` file with shapes, colours, loops and functions, and it produces
`picture.svg`, which you can open in any browser.

We built it in two phases:

- **`drawi`** is an interpreter. It reads your program and draws it straight away.
- **`drawc`** is a compiler. It translates your program to LLVM IR, which is
  then built into a normal executable that writes the picture.

Both share the same lexer, error checks and SVG code, so they always give the
same picture.

## Example

```
canvas 300 200;
pen "orange";
stamp 4 times {
  circle(40, 100, 20);
  slide 60 0;
}
```

This draws four orange circles in a row. More programs are in `examples/`.

## Setup

You need flex, bison, gcc, make, llvm and clang (LLVM 15 or newer). On
Ubuntu or Debian:

```bash
sudo apt-get install -y flex bison gcc make llvm clang
```

If `llc` or `clang` aren't found, your system probably installed them with a
version suffix. Run `make LLC=llc-18 CLANG=clang-18` instead.

## Build and run

```bash
make                                  # builds ./drawi and ./drawc
./drawi examples/02_rosette.draw      # interpreter, writes picture.svg
make run-compiled SRC=examples/02_rosette.draw   # compiler, writes picture.svg
make test                             # runs every example through both phases
```

If you don't give a file, both programs read `source.draw`. Open
`picture.svg` in a browser to see the result. `make clean` removes everything
that was built.

To compile by hand, the steps are:

```bash
./drawc prog.draw -o prog.ll
llc -filetype=obj -relocation-model=pic prog.ll -o prog.o
clang prog.o build/runtime.o -lm -o prog
./prog
```

You can open `prog.ll` in a text editor to see the generated LLVM IR.

## The language

The keywords are painter-themed versions of the usual ones:

| Usual | DrawLang | Example |
|---|---|---|
| variable | `ink` | `ink i = 0;` |
| if / else | `when` / `otherwise` | `when (x > 1) { ... } otherwise { ... }` |
| while | `swirl` | `swirl (i < 3) { ... }` |
| for N times | `stamp` | `stamp 5 times { ... }` |
| function | `pattern` | `pattern flower(x, y, size) { ... }` |
| return | `give` | `give n * 2;` |

Drawing statements:

- `canvas W H;` sets the image size. It must be the first statement.
- `pen "colour";` sets the colour. It accepts any SVG colour name or `#rrggbb`.
- `circle(x, y, r);`, `rect(x, y, w, h);`, `line(x1, y1, x2, y2);`,
  `triangle(x1, y1, x2, y2, x3, y3);` and `text(x, y, size, "words");`
- `slide dx dy;` moves the drawing position for everything after it.
  Slide back with negative numbers.
- `spin(angle) { ... }` and `grow(factor) { ... }` rotate or scale the shapes
  inside the block.

Some things to know:

- All numbers are doubles. Comparisons give 1 or 0, and any non-zero value
  counts as true.
- Patterns can be called before they are defined and can call themselves.
  They can't see the main program's variables, so pass values in as arguments.
- A pattern with no `give` returns 0.
- `slide a (b);` is read as a call to a pattern `a`. Write `slide a b;` if you
  mean two values.
- Comments are `//` and `/* ... */`.

## Error checking

Before anything runs, the checker reads the whole program and reports every
error it finds with its line number, then exits with code 1. It catches
unknown colours, wrong argument counts, undeclared variables, unknown
patterns, shapes outside the canvas, and negative sizes.

```
examples/05_error_drawing.draw:6: error: rect(150, 150, 100, 20) is outside the 200x200 canvas
```

If a shape's position depends on a variable or a loop, the checker can't know
it in advance. The runtime checks it with the same rules when it is drawn:

```
line 7: runtime error: circle(200, 50, 10) is outside the 200x100 canvas
```

The partly written `picture.svg` is deleted in that case.

## How it works

1. **Lexer** (`drawlang.l`, Flex) turns the text into tokens.
2. **Parser** (`interp.y` and `compiler.y`, Bison) checks the grammar and
   builds a syntax tree (`ast.h`).
3. **Checker** (`check.c`) finds errors and gives each variable a slot number
   in its function's memory.
4. The last step is different for each phase:
   - `interp.y` walks the tree and runs it directly.
   - `compiler.y` walks the tree and prints LLVM IR. Variables become
     `alloca`/`load`/`store`, loops and `when` become basic blocks with `br`,
     patterns become functions, and `&&`/`||` use a `phi`.
5. **Runtime** (`runtime.c`) is a set of C functions that write the SVG. The
   interpreter calls them directly and the compiled program links against them.

The syntax tree is only a copy of the source in memory. It is not an
intermediate language.

## Files

```
src/
  drawlang.l    lexer, shared by both phases
  interp.y      grammar + interpreter (builds drawi)
  compiler.y    grammar + LLVM IR generator (builds drawc)
  ast.h, ast.c  syntax tree
  check.c       compile-time checks
  runtime.c/.h  SVG output and shape rules
examples/       sample programs (05-07 fail on purpose)
Makefile        build rules
test.sh         runs all examples through both phases and compares output
```

## Tests

`make test` runs each example through both phases. It checks that the SVG
files are byte-for-byte identical, that the messages and exit codes match,
and that the error examples are rejected.

