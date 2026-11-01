CC      = gcc
CFLAGS  ?= -Wall -Wextra -O2 -std=gnu11
SRC     ?= source.draw

COMMON  = src/ast.c src/check.c src/runtime.c
HEADERS = src/ast.h src/runtime.h

.PHONY: all interpreter run-interp clean

all: interpreter

interpreter: drawi

# Phase 1: interpreter 
build/interp/parser.c build/interp/parser.h: src/interp.y
	@mkdir -p build/interp
	bison -Wall -d -o build/interp/parser.c $<

build/interp/lexer.c: src/drawlang.l build/interp/parser.h
	flex -o $@ $<

drawi: build/interp/parser.c build/interp/lexer.c $(COMMON) $(HEADERS)
	$(CC) $(CFLAGS) -Isrc -Ibuild/interp -o $@ build/interp/parser.c build/interp/lexer.c $(COMMON) -lm

run-interp: drawi
	./drawi $(SRC)

clean:
	rm -rf build drawi picture.svg
