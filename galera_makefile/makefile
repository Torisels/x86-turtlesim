CC=gcc
ASMBIN=nasm

all : asm cc link
asm :
	$(ASMBIN) -o func.o -f elf64 -g -l program.lst program.asm
cc :
	$(CC) -c -g -O0 -fpack-struct -std=c99 main.c
link :
	$(CC) -g -o turtle main.o func.o
gdb :
	gdb turtle

clean :
	rm *.o
	rm *.lst
debug : all gdb
