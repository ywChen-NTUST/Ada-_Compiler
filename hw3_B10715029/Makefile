LEX = hw1_B10715029.l
YACC = hw2_B10715029.y
OUTPUT = parser

$(OUTPUT): y.tab.o lex.yy.o
	gcc -o $(OUTPUT) lex.yy.o y.tab.o -ll -O1

lex.yy.o: lex.yy.c
	gcc -c -g lex.yy.c
	
y.tab.o: y.tab.c y.tab.h lex.yy.c
	gcc -c -g y.tab.c

lex.yy.c: $(LEX) y.tab.h
	lex $(LEX)

y.tab.c: $(YACC)
	yacc -d $(YACC)

y.tab.h: $(YACC)
	yacc -d $(YACC)

yaccDebug: $(YACC)
	yacc -v $(YACC)

clean:
	rm -f *.o lex.yy.c y.tab.c y.tab.h y.output *.jasm *.class

