
CC      = gcc
CFLAGS  ?= -Wall -Wextra -O2 -std=gnu11
LLC     ?= llc
CLANG   ?= clang
SRC     ?= source.draw

COMMON  = src/ast.c src/check.c src/runtime.c
HEADERS = src/ast.h src/runtime.h

.PHONY: all interpreter compiler run-interp run-compiled test clean

all: interpreter compiler

interpreter: drawi
compiler: drawc build/runtime.o

# Phase 1: interpreter 
build/interp/parser.c build/interp/parser.h: src/interp.y
	@mkdir -p build/interp
	bison -Wall -d -o build/interp/parser.c $<

build/interp/lexer.c: src/drawlang.l build/interp/parser.h
	flex -o $@ $<

drawi: build/interp/parser.c build/interp/lexer.c $(COMMON) $(HEADERS)
	$(CC) $(CFLAGS) -Isrc -Ibuild/interp -o $@ build/interp/parser.c build/interp/lexer.c $(COMMON) -lm

# Phase 2: compiler 
build/comp/parser.c build/comp/parser.h: src/compiler.y
	@mkdir -p build/comp
	bison -Wall -d -o build/comp/parser.c $<

build/comp/lexer.c: src/drawlang.l build/comp/parser.h
	flex -o $@ $<

drawc: build/comp/parser.c build/comp/lexer.c $(COMMON) $(HEADERS)
	$(CC) $(CFLAGS) -Isrc -Ibuild/comp -o $@ build/comp/parser.c build/comp/lexer.c $(COMMON) -lm

build/runtime.o: src/runtime.c src/runtime.h
	@mkdir -p build
	$(CLANG) -O2 -c -o $@ src/runtime.c

run-interp: drawi
	./drawi $(SRC)

run-compiled: drawc build/runtime.o
	@mkdir -p build/out
	./drawc $(SRC) -o build/out/program.ll
	$(LLC) -filetype=obj -relocation-model=pic build/out/program.ll -o build/out/program.o
	$(CLANG) build/out/program.o build/runtime.o -lm -o build/out/program
	./build/out/program

test: all
	LLC=$(LLC) CLANG=$(CLANG) ./test.sh

clean:
	rm -rf build drawi drawc picture.svg
