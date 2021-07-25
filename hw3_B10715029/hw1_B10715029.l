%{
#include "y.tab.h"
#include <stdio.h>
#include <string.h>

#define TOKEN(token) \
{ \
	/*printf("<%s>\n", token);*/ \
	return(token); \
}
#define TOKEN_INT(token, val) \
{ \
	/*printf("<%s: %d>\n", token, val);*/ \
	yylval.integer=atoi(val); \
	return(token); \
}
#define TOKEN_REAL(token, val) \
{ \
	/*printf("<%s: %d>\n", token, val);*/ \
	yylval.real=atof(val); \
	return(token); \
}
#define TOKEN_BOOL(token, val) \
{ \
	/*printf("<%s: %d>\n", token, val);*/ \
	yylval.integer=(strcmp(val, "true")==0)? 1: 0; \
	return(token); \
}
#define TOKEN_STR(token, val) \
{ \
	/*printf("<%s: %s>\n", token, val);*/ \
	strcpy(yylval.string, val); \
	return(token); \
}
#define BUFLINE \
{ \
	strcat(currLine, yytext); \
}

unsigned int lineCount = 0;
char currLine[1024] = "\0";
unsigned int commentDepth = 0;
%}

digit	[0-9]
alphaL	[a-z]
alphaU	[A-Z]
alpha	{alphaL}|{alphaU}

int	{digit}+
float	{int}"."{int}
intEx	{int}[eE][+-]?{int}
floatEx	{float}[eE][+-]?{int}
number	{int}|{float}|{intEx}|{floatEx}

id	{alpha}({alpha}|{digit})*

%x	COMMENT

%%

","	{
		BUFLINE;
		TOKEN(',');
	}
":"	{
		BUFLINE;
		TOKEN(':');
	}
"."	{
		BUFLINE;
		TOKEN('.');
	}
";"	{
		BUFLINE;
		TOKEN(';');
	}
"("	{
		BUFLINE;
		TOKEN('(');
	}
")"	{
		BUFLINE;
		TOKEN(')');
	}
"["	{
		BUFLINE;
		TOKEN('[');
	}
"]"	{
		BUFLINE;
		TOKEN(']');
	}

"+"	{
		BUFLINE;
		TOKEN('+');
	}
"-"	{
		BUFLINE;
		TOKEN('-');
	}
"*"	{
		BUFLINE;
		TOKEN('*');
	}
"/"	{
		BUFLINE;
		TOKEN('/');
	}
"%"	{
		BUFLINE;
		TOKEN('%');
	}

"<"	{
		BUFLINE;
		TOKEN(LT);
	}
"<="	{
		BUFLINE;
		TOKEN(LE);
	}
">="	{
		BUFLINE;
		TOKEN(GE);
	}
">"	{
		BUFLINE;
		TOKEN(GT);
	}
"="	{
		BUFLINE;
		TOKEN(EQ);
	}
"/="	{
		BUFLINE;
		TOKEN(NE);
	}
":="	{
		BUFLINE;
		TOKEN(ASSIGN);
	}

[aA][nN][dD]	{
		BUFLINE;
		TOKEN(AND);
	}
[bB][eE][gG][iI][nN]	{
		BUFLINE;
		TOKEN(MY_BEGIN);
	}
[bB][oO][oO][lL][eE][aA][nN]	{
		BUFLINE;
		TOKEN(BOOLEAN);
	}
[bB][rR][eE][aA][kK]	{
		BUFLINE;
		TOKEN(BREAK);
	}
[cC][hH][aA][rR][aA][cC][tT][eE][rR]	{
		BUFLINE;
		TOKEN(CHARACTER);
	}
[cC][aA][sS][eE]	{
		BUFLINE;
		TOKEN(CASE);
	}
[cC][oO][nN][tT][iI][nN][uU][eE]	{
		BUFLINE;
		TOKEN(CONTINUE);
	}
[cC][oO][nN][sS][tT][aA][nN][tT]	{
		BUFLINE;
		TOKEN(CONSTANT);
	}
[dD][eE][cC][lL][aA][rR][eE]	{
		BUFLINE;
		TOKEN(DECLARE);
	}
[dD][oO]	{
		BUFLINE;
		TOKEN(DO);
	}
[eE][lL][sS][eE]	{
		BUFLINE;
		TOKEN(ELSE);
	}
[eE][nN][dD]	{
		BUFLINE;
		TOKEN(END);
	}
[eE][xX][iI][tT]	{
		BUFLINE;
		TOKEN(EXIT);
	}
[fF][aA][lL][sS][eE]	{
		BUFLINE;
		TOKEN_BOOL(Boolean, "false");
	}
[fF][lL][oO][aA][tT]	{
		BUFLINE;
		TOKEN(FLOAT);
	}
[fF][oO][rR]	{
		BUFLINE;
		TOKEN(FOR);
	}
[iI][fF]	{
		BUFLINE;
		TOKEN(IF);
	}
[iI][nN]	{
		BUFLINE;
		TOKEN(IN);
	}
[iI][nN][tT][eE][gG][eE][rR]	{
		BUFLINE;
		TOKEN(INTEGER);
	}
[lL][oO][oO][pP]	{
		BUFLINE;
		TOKEN(LOOP);
	}
[nN][oO][tT]	{
		BUFLINE;
		TOKEN(NOT);
	}
[oO][rR]	{
		BUFLINE;
		TOKEN(OR);
	}
[pP][rR][iI][nN][tT]	{
		BUFLINE;
		TOKEN(PRINT);
	}
[pP][rR][iI][nN][tT][lL][nN]	{
		BUFLINE;
		TOKEN(PRINTLN);
	}
[pP][rR][oO][cC][eE][dD][uU][rR][eE]	{
		BUFLINE;
		TOKEN(PROCEDURE);
	}
[pP][rR][oO][gG][rR][aA][mM]	{
		BUFLINE;
		TOKEN(PROGRAM);
	}
[rR][eE][tT][uU][rR][nN]	{
		BUFLINE;
		TOKEN(RETURN);
	}
[sS][tT][rR][iI][nN][gG]	{
		BUFLINE;
		TOKEN(STRING);
	}
[tT][hH][eE][nN]	{
		BUFLINE;
		TOKEN(THEN);
	}
[tT][rR][uU][eE]	{
		BUFLINE;
		TOKEN_BOOL(Boolean, "true");
	}
[wW][hH][iI][lL][eE]	{
		BUFLINE;
		TOKEN(WHILE);
	}

{int}	{
		BUFLINE;
		//sscanf(yytext, "%d", &yylval);
		//TOKEN_INT("CONST", yylval);
		TOKEN_INT(Integer, yytext);
	}
{float}|{intEx}|{floatEx}	{
		BUFLINE;
		TOKEN_REAL(Real, yytext);
	}
{id}	{
		BUFLINE;

		/*if(lookup(yytext, false) == NULL)
		{
			insert(yytext);
		}*/

		TOKEN_STR(Id, yytext);
	}
\".*\"	{
		BUFLINE;

		//printf("Test: [%s]\n", yytext);

		char newStr[1024] = "\0";
		char last = '\0';
		short lastWrite = 0;
		for(int i=1; yytext[i]!='\0'; i++)
		{
			if(yytext[i] == '"' && last == '"' && lastWrite)
			{
				// nothing
				lastWrite = 0;
			}
			else
			{
				char temp[2];
				temp[0] = yytext[i];
				temp[1] = '\0';

				strcat(newStr, temp);
				lastWrite = 1;
			}
			last = yytext[i];
		}
		newStr[strlen(newStr)-1] = '\0';

		TOKEN_STR(String, newStr);
	}

[ \t]*	{
		BUFLINE;
	}

(--.*)?\n	{
		BUFLINE;
		lineCount ++;
		printTabs(true);
		fprintf(commentout, "/*\n");
		printTabs(true);
		fprintf(commentout, " * %d: %s", lineCount, currLine);
		printTabs(true);
		fprintf(commentout, " */\n");
		currLine[0] = '\0';
	}

"{"	{
		BUFLINE;
		commentDepth ++;
		BEGIN(COMMENT);
	}
<COMMENT>"{"	{
		BUFLINE;
		commentDepth ++;
	}
<COMMENT>"}"	{
		BUFLINE;
		commentDepth --;
		if(commentDepth == 0)
		{
			BEGIN(INITIAL);
		}
	}
<COMMENT>\n	{
		BUFLINE;
		lineCount ++;
		printTabs(true);
		fprintf(commentout, "/*\n");
		printTabs(true);
		fprintf(commentout, " * %d: %s", lineCount, currLine);
		printTabs(true);
		fprintf(commentout, " */\n");
		currLine[0] = '\0';
	}
<COMMENT>.	{
		BUFLINE;
	}

.	{
		BUFLINE;
		fprintf(stderr, "Invaild Token!!\n");
		fprintf(stderr, "Happened at Line: %u\n", lineCount);
		exit(1);
	}

%%

int yywrap()
{
	//dump();
	printf("\n");
	printf("=== Compile Successful ===\n");
	delete();
	//printf("=== Cleaning Symbol Table Complete ===\n");
	//dump();
	return 1;
}

/*int main(int argc, char** argv)
{
	if(argc == 1)
	{
		yyin = stdin;
	}
	else if(argc == 2)
	{
		FILE* fh = fopen(argv[1], "r");
		if(!fh)
		{
			fprintf(stderr, "Can't open file %s\n", argv[1]);
			exit(1);
		}
		else
		{
			yyin = fh;
		}
	}
	else
	{
		fprintf(stderr, "Command error!\n");
		exit(1);
	}

	create();

	char* test = yylex();
	printf("\"<%s>\"", test);
	exit(0);
}*/

