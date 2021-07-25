%code requires {
	#ifndef TYPEDEF
	#define TYPEDEF
	enum TYPE {
		TYPE_INT=0,
		TYPE_STR=1,
		TYPE_BOOL=2,
		TYPE_REAL=3,
		TYPE_INT_ARRAY=4,
		TYPE_STR_ARRAY=5,
		TYPE_BOOL_ARRAY=6,
		TYPE_REAL_ARRAY=7,
		TYPE_PROG=8,
		TYPE_PROC=9,
		NONE=-1
	};
	#endif
	
	// extend table for procedure
	struct funcEx
	{
		enum TYPE returnType;
		short paramNum;
		enum TYPE paramType[32];
	};
	struct linkedList
	{
		char id[1024];
		enum TYPE type;
		short isConst;
		short isGlobal;
		unsigned int localIndex;
		struct funcEx procExtend;

		union
		{
			int intval;
			char strval[100];
			short boolval;
		};

		struct linkedList* nextNode;
	};
	struct Table
	{
		struct Table* pastTable;
		struct linkedList* fastIndex[52];
	};
	// type stack
	struct typeStack
	{
		int top;
		enum TYPE stack[100];
	};
	// label stack
	struct labelStack
	{
		int top;
		unsigned int stack[100];
	};
	// value stack
	struct valueStack
	{
		int inttop;
		int strtop;
		int booltop;
		int intstack[100];
		short boolstack[100];
		char strstack[100][100];
	};

	typedef struct linkedList symbolNode;
	typedef struct Table symbolTable;
	typedef struct funcEx procEx;
	
	// create new symbol table
	void create();

	// lookup id in symbol table
	symbolNode* lookup(char* s, short onlyTop);

	// insert id into symbol table
	// stroage on top
	void insert(char* s);

	// dump symbol table
	void dump();

	// delete top symbol table
	void delete();

	// fill id type in symbol table
	void fillType(char* id, enum TYPE type, short isConst, short isGlobal);

	static symbolTable* table = NULL;

	#define false 0
	#define true 1

	FILE* commentout;

	// print tabs
	void printTabs(short iscomment);
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define false 0
#define true 1

extern FILE* yyin;
extern FILE* yyout;
extern unsigned int lineCount;
extern char currLine[1024];

// print out error msg and end program
void yyerror(char* msg);

#ifndef TYPEDEF
#define TYPEDEF
// type defination for storage and sentiment check
enum TYPE {
	TYPE_INT=0,
	TYPE_STR=1,
	TYPE_BOOL=2,
	TYPE_REAL=3,
	TYPE_INT_ARRAY=4,
	TYPE_STR_ARRAY=5,
	TYPE_BOOL_ARRAY=6,
	TYPE_REAL_ARRAY=7,
	TYPE_PROG=8,
	TYPE_PROC=9,
	NONE=-1,
	SPECIAL_NOT_PROC_CALL = -2
};
#endif

typedef struct linkedList symbolNode;
typedef struct Table symbolTable;
typedef struct funcEx procEx;

// enum TYPE to Sting name
char* num_type(enum TYPE type);

// check id is in symbol table or not
// if not, raise error and end parsing
void check_id_exist(char* id);

enum TYPE type_check_t; //stroage type (variable declare)
struct typeStack expr_types;	// stroage type (expr)
								// stackId = 0
struct typeStack param_types;	// stroage type (params) 
								//stackId = 1

// reset typestack
void typeStack_init(short stackId);

// add type into stack
void typeStack_add(enum TYPE type, short stackId);

// get type on top of stack and move it out
enum TYPE typeStack_getDel(short stackId);

// dump stack for debug
void typeStack_dump(short stackId);

// lock for block in order to not create redundant symbol table
// this only happened when create procedure
short blockLock = false;
// flag counter use for restrict block not to print { / }
int blockFgCt = 0;

// use for check procedure has return or not
int procDeepCt = 0;
short hasReturn = false;

// declare is in global or local
// 0: none
// 1: global
// 2: local
short vdeclareState = 0;

// how many tabs to print
unsigned int tabDepth = 0;

// use for local variable indexing
unsigned int localIndex = 0;

// symbolnode which needs on assign operation
symbolNode* assignNode = NULL;
struct valueStack valStack;
void valueStack_init();
void valueStack_add(int intval, short boolval, char* strval, short channel);
int valueStack_int_getDel();
short valueStack_bool_getDel();
char* valueStack_str_getDel();

// procedure return type
enum TYPE returnType = SPECIAL_NOT_PROC_CALL;

// program name use for get global variable
char progName[100];

// label id
unsigned int labelId = 0;
// label stack use for if/loop
struct labelStack labelIdStack;
void labelStack_add(unsigned int id);
unsigned int labelStack_getDel();

// flag for debug
int yydebug = 1;

%}

%token BOOLEAN BREAK CHARACTER CASE CONTINUE CONSTANT DECLARE DO ELSE
%token END EXIT FLOAT FOR IF IN INTEGER LOOP PRINT PRINTLN PROCEDURE PROGRAM
%token RETURN STRING THEN WHILE

%token LT LE GE GT EQ NE ASSIGN MY_BEGIN AND OR NOT READ

%union {
	char string[100];
	int integer;
	double real;
}
%token <integer> Boolean
%token <integer> Integer
%token <real> Real
%token <string> Id
%token <string> String

%left OR
%left AND
%nonassoc NOT
%left LT LE EQ GE GT NE
%left '+' '-'
%left '*' '/'
%nonassoc UMINUS
%nonassoc BRACE

%start program
%%
/* basic types */
type: INTEGER {type_check_t=TYPE_INT;}
	| STRING {type_check_t=TYPE_STR;}
	| BOOLEAN {type_check_t=TYPE_BOOL;}
	| FLOAT {type_check_t=TYPE_REAL;}
	;

/* optional < := expr > pattern */
opt_assign_expr: {typeStack_init(0); typeStack_add(NONE, 0);}
			   | ASSIGN {typeStack_init(0);} expr
			   ;
/* optional < : type > pattern */
opt_colon_type: {type_check_t=NONE;}
			  | ':' type
			  ;
/* constant variable declaration */
const_declare: Id ':' CONSTANT opt_colon_type ASSIGN {
			 	typeStack_init(0);
			 	
				if(lookup($1, true) == NULL)
				{
					insert($1);
				}
				assignNode = lookup($1, true);
				valueStack_init();
			 } expr ';' {
			 		assignNode = NULL;

					enum TYPE t = type_check_t;
					enum TYPE t2 = typeStack_getDel(0); /* get expr type */
					if(t == NONE) /* no < : type > pattern */
					{
						t = t2;
					}
					else
					{
						if(t != t2)
						{
							// implicit type defined incompatible with expr type
							yyerror("ERROR!! Type incompatible");
						}
					}
					fillType($1, t, 1, (vdeclareState==1)); // fill type in symbol table

					symbolNode* node = lookup($1, false);
					if(t2 == TYPE_INT)
					{
						node->intval = valueStack_int_getDel();
					}
					else if(t2 == TYPE_STR)
					{
						strcpy(node->strval, valueStack_str_getDel());
					}
					else if(t2 == TYPE_BOOL)
					{
						node->boolval = valueStack_bool_getDel();
					}
				}
			 ;
/* variable declaration */
var_declare: Id opt_colon_type {
				if(lookup($1, true) == NULL)
				{
					insert($1);
				}
				assignNode = lookup($1, true);
				valueStack_init();
		   } opt_assign_expr ';' {
		   			assignNode = NULL;

					enum TYPE t = type_check_t;
					enum TYPE t2 = typeStack_getDel(0); // expr type
					short hasExpr = true;
					if(t == NONE)
					{
						t = t2;
						if(t == NONE) // no < : type > and < := expr >
						{
							t = TYPE_INT; // default type
							hasExpr = false;
						}
					}
					else
					{
						if(t != t2 && t2 != NONE)
						{
							// implicit type incompatible with expr
							yyerror("ERROR! Type incompatible");
						}
						if(t2 == NONE)
						{
							hasExpr = false;
						}
					}
					//typeStack_dump(0);
					fillType($1, t, 0, (vdeclareState==1));

					symbolNode* node = lookup($1, false);
					if(hasExpr)
					{
						if(t2 == TYPE_INT)
						{
							node->intval = valueStack_int_getDel();
						}
						else if(t2 == TYPE_STR)
						{
							strcpy(node->strval, valueStack_str_getDel());
						}
						else if(t2 == TYPE_BOOL)
						{
							node->boolval = valueStack_bool_getDel();
						}
					}
					
					if(vdeclareState == 1) // global
					{
						if(t == TYPE_INT)
						{
							printTabs(false);
							fprintf(yyout, "field static int %s", $1);
							if(hasExpr)
							{
								fprintf(yyout, " = %d", node->intval);
							}
							fprintf(yyout, "\n");
						}
						else if(t == TYPE_BOOL)
						{
							printTabs(false);
							fprintf(yyout, "field static int %s", $1);
							if(hasExpr)
							{
								fprintf(yyout, " = %d", (node->boolval == 0)? 0: 1);
							}
							fprintf(yyout, "\n");
						}
			 		}
					else if(vdeclareState == 2) // local
					{
						if(t == TYPE_INT)
						{
							if(hasExpr)
							{
								printTabs(false);
								fprintf(yyout, "sipush %d\n", node->intval);
								printTabs(false);
								fprintf(yyout, "istore %d\n", node->localIndex);
							}
						}
						else if(t == TYPE_BOOL)
						{
							if(hasExpr)
							{
								printTabs(false);
								fprintf(yyout, "iconst_%d\n", (node->boolval == 0)? 0: 1);
								printTabs(false);
								fprintf(yyout, "istore %d\n", node->localIndex);
							}
						}
					}
				}
		   ;
/* array declaration */
arr_declare: Id ':' type '[' Integer ']' ';' {
		   			if(lookup($1, true) == NULL)
					{
						insert($1);
					}

		   			fillType($1, type_check_t+4, 0, (vdeclareState==1));
				}
		   ;

/* any variable declaration */
vdeclare: const_declare
		| var_declare
		| arr_declare
		;
/* zero or more variable declare */
zeromore_vdeclare:
				 | vdeclare zeromore_vdeclare
				 ;
/* optional variable declare */
opt_vdeclare:
			| DECLARE zeromore_vdeclare
			;
/* zero or more procedure declare */
zeromore_pdeclare:
				 | procedure zeromore_pdeclare
				 ;
/*opt_pdeclare:
			| zeromore_pdeclare
			;*/
/* zero or more stat */
zeromore_stat:
			 | stat zeromore_stat
			 ;
/* program */
program: PROGRAM Id {
	   		insert($2);
			fillType($2, TYPE_PROG, 0, true);
			typeStack_init(1); // initialize

			fprintf(yyout, "class %s\n", $2);
			fprintf(yyout, "{\n");
			tabDepth += 1;

			strcpy(progName, $2);

			vdeclareState = 1;	// global declaration

			labelIdStack.top = 0; // initialize
		} opt_vdeclare {vdeclareState = 0;} zeromore_pdeclare MY_BEGIN {
			printTabs(false);
			fprintf(yyout, "method public static void main(java.lang.String[])\n");
			printTabs(false);
			fprintf(yyout, "max_stack 15\n");
			printTabs(false);
			fprintf(yyout, "max_locals 15\n");
			printTabs(false);
			fprintf(yyout, "{\n");
			tabDepth += 1;

			dump();
		} zeromore_stat END ';'{
			printTabs(false);
			fprintf(yyout, "return\n");
			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "}\n");
		} END Id {
	   		if(strcmp($2, $14) != 0)
			{
				yyerror("ERROR!! Id after END incompatible with Id at beginning");
			}
			
			tabDepth -= 1;
			fprintf(yyout, "}\n");
	   }
	   ;
/* args */
args: Id {if(lookup($1, true) == NULL){insert($1);}} ':' type {fillType($1, type_check_t, 0, false); typeStack_add(type_check_t, 1);} argsEx
	;
/* args extend rule */
argsEx:
	  | ';' args
	  ;
/* optional (args) */
opt_brace_arg_brace:
				   | '(' args ')'
				   ;
/* optional return type */
opt_return_type: {type_check_t=NONE;}
			   | RETURN type
			   ;
/* procedure */
procedure: {
		 		printTabs(true);
				fprintf(commentout, "/*\n");
				printTabs(true);
				fprintf(commentout, " *\n");
				printTabs(true);
				fprintf(commentout, " * <Procedure>\n");
				printTabs(true);
				fprintf(commentout, " */\n");
			} PROCEDURE Id {
		 		insert($3); 
				fillType($3, TYPE_PROC, 0, true);
				create();  // new symbol table
				blockLock=true; // prevent procedure block create new symbol table

				typeStack_init(1);

				localIndex = 0;
			} opt_brace_arg_brace {
				int argCt = param_types.top; // params count
				symbolNode* node = lookup($3, false);

				(node->procExtend).paramNum = argCt;
				for(int i=argCt-1; i>=0; i--)
				{
					// stroage param types
					(node->procExtend).paramType[i] = typeStack_getDel(1);
				}
			} opt_return_type {
				// stroage retuen type
				(lookup($3, false)->procExtend).returnType=type_check_t;
				returnType = type_check_t;

				symbolNode* node = lookup($3, false);
				printTabs(false);
				fprintf(yyout, "method public static");
				if(returnType == NONE)
				{
					fprintf(yyout, " void");
				}
				else if(returnType == TYPE_INT || returnType == TYPE_BOOL)
				{
					fprintf(yyout, " int");
				}
				fprintf(yyout, " %s", $3);
				fprintf(yyout, "(");
				short isBegin = true;
				for(int i=0; i<((node->procExtend).paramNum); i++)
				{
					if(isBegin == false)
					{
						fprintf(yyout, ", ");
					}
					else
					{
						isBegin = false;
					}
					if((node->procExtend).paramType[i] == TYPE_INT)
					{
						fprintf(yyout, "int");
					}
					else if((node->procExtend).paramType[i] == TYPE_BOOL)
					{
						fprintf(yyout, "int");
					}
				}
				fprintf(yyout, ")\n");
				printTabs(false);
				fprintf(yyout, "max_stack 15\n");
				printTabs(false);
				fprintf(yyout, "max_locals 15\n");

				procDeepCt = 0;
				hasReturn = false;
			} block END Id ';' {
				returnType = SPECIAL_NOT_PROC_CALL;
		 		/*delete();*/
				if(strcmp($3, $11) != 0)
				{
					yyerror("ERROR!! Id after END incompatible with Id at beginning");
				}
				
				printTabs(true);
				fprintf(commentout, "/*\n");
				printTabs(true);
				fprintf(commentout, " * <End Procedure>\n");
				printTabs(true);
				fprintf(commentout, " *\n");
				printTabs(true);
				fprintf(commentout, " */\n");
		 }
		 ;

/* stat */
stat: simple_stat
	| block
	| cond
	| loop
	| proc_call
	;
/* simple stat */
simple_stat: Id {check_id_exist($1);} ASSIGN {typeStack_init(0);} expr ';' {
		   		enum TYPE t = lookup($1, false)->type; // id type
				enum TYPE t2 = typeStack_getDel(0); // expr type
				if(t != t2)
				{
					yyerror("ERROR!! Type incompetible");
				}

				symbolNode* node = lookup($1, false);
				if(t == TYPE_INT || t == TYPE_BOOL)
				{
					if(node->isGlobal)
					{
						printTabs(false);
						fprintf(yyout, "putstatic int %s.%s\n", progName, $1);
					}
					else
					{
						printTabs(false);
						fprintf(yyout, "istore %u\n", node->localIndex);
					}
				}
		   }
		   | Id {check_id_exist($1);} '[' {typeStack_init(0);} expr {
		   		if(typeStack_getDel(0) != TYPE_INT)
				{
					// index field is not integer
					yyerror("ERROR!! Type of array index is not integer");
				}
			} ']' ASSIGN {typeStack_init(0);} expr ';' {
				// get array stroage type
				// stroaged type = (original array type id) - 4
				enum TYPE t = lookup($1, false)->type - 4;

				enum TYPE t2 = typeStack_getDel(0); // expr type
				if(t != t2)
				{
					yyerror("ERROR!! Type incompetible");
				}
		   }
		   | PRINT {
		   		typeStack_init(0);

				printTabs(false);
				fprintf(yyout, "getstatic java.io.PrintStream java.lang.System.out\n");
			} expr ';' {
		   		enum TYPE t = typeStack_getDel(0); // expr type
		   		if(t == TYPE_PROG || t == TYPE_PROC || t == NONE)
				{
					yyerror("ERROR!! Not printable");
				}

				if(t == TYPE_STR)
				{
					printTabs(false);
					fprintf(yyout, "invokevirtual void java.io.PrintStream.print(java.lang.String)\n");
				}
				else if(t == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "invokevirtual void java.io.PrintStream.print(int)\n");
				}
				else if(t == TYPE_BOOL)
				{
					printTabs(false);
					fprintf(yyout, "invokevirtual void java.io.PrintStream.print(boolean)\n");
				}
		   }
		   | PRINTLN {
		   		typeStack_init(0);

				printTabs(false);
				fprintf(yyout, "getstatic java.io.PrintStream java.lang.System.out\n");
			} expr ';' {
		   		enum TYPE t = typeStack_getDel(0); // expr type
		   		if(t == TYPE_PROG || t == TYPE_PROC || t == NONE)
				{
					yyerror("ERROR!! Not printable");
				}

				if(t == TYPE_STR)
				{
					printTabs(false);
					fprintf(yyout, "invokevirtual void java.io.PrintStream.println(java.lang.String)\n");
				}
				else if(t == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "invokevirtual void java.io.PrintStream.println(int)\n");
				}
				else if(t == TYPE_BOOL)
				{
					printTabs(false);
					fprintf(yyout, "invokevirtual void java.io.PrintStream.println(boolean)\n");
				}
		   }
		   | READ Id {check_id_exist($2);} ';'
		   | RETURN ';' {
		   		/*returnType;*/
				if(returnType == NONE)
				{
					printTabs(false);
					fprintf(yyout, "return\n");

					hasReturn = true;
				}
			}
		   | RETURN {typeStack_init(0);} expr ';' {
		   		if(returnType == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "ireturn\n");

					hasReturn = true;
				}
				else if(returnType == TYPE_BOOL)
				{
					printTabs(false);
					fprintf(yyout, "ireturn\n");

					hasReturn = true;
				}
		   }
		   ;
/* expr, expr, ... , expr */
comma_sep_expr: expr {typeStack_add(typeStack_getDel(0), 1);}
			  | expr {typeStack_add(typeStack_getDel(0), 1);} ',' comma_sep_expr
			  ;
/*opt_params: 
		  | '(' comma_sep_expr ')'
		  ;*/

/* expr components */
expr_obj: Boolean {
			typeStack_add(TYPE_BOOL, 0);
			if(assignNode != NULL)
			{
				valueStack_add(-1, $1, NULL, 2);
			}
			else
			{
				printTabs(false);
				fprintf(yyout, "iconst_%d\n", ($1 == 0)? 0: 1);
			}
		}
		| Integer {
			typeStack_add(TYPE_INT, 0);
			if(assignNode != NULL)
			{
				valueStack_add($1, -1, NULL, 1);
			}
			else
			{
				printTabs(false);
				fprintf(yyout, "sipush %d\n", $1);
			}
		}
		| Real {typeStack_add(TYPE_REAL, 0);}
		| String {
			typeStack_add(TYPE_STR, 0);
			if(assignNode != NULL)
			{
				valueStack_add(-1, -1, $1, 3);
			}
			else
			{
				printTabs(false);
				fprintf(yyout, "ldc \"%s\"\n", $1);
			}
		}
		| Id {
			check_id_exist($1);
			symbolNode* node = lookup($1, false); // get symbol table entry
			if(node->type == TYPE_PROC) // procedure type
			{
				typeStack_add((node->procExtend).returnType, 0);
			}
			else
			{
				typeStack_add(node->type, 0);
			}

			if(assignNode != NULL)
			{
				if(node->type == TYPE_INT)
				{
					valueStack_add(node->intval, -1, NULL, 1);
				}
				else if(node->type == TYPE_STR)
				{
					valueStack_add(-1, -1, node->strval, 3);
				}
				else if(node->type == TYPE_BOOL)
				{
					valueStack_add(-1, node->boolval, NULL, 2);
				}
			}
			else
			{
				if(node->type == TYPE_PROC)
				{
					printTabs(false);
					fprintf(yyout, "invokestatic void %s.%s()\n", progName, $1);
				}
				else if(node->isConst)
				{
					if(node->type == TYPE_INT)
					{
						printTabs(false);
						fprintf(yyout, "sipush %d\n", node->intval);
					}
					else if(node->type == TYPE_BOOL)
					{
						printTabs(false);
						fprintf(yyout, "iconst_%d\n", (node->boolval == 0)? 0: 1);
					}
					else if(node->type == TYPE_STR)
					{
						printTabs(false);
						fprintf(yyout, "ldc \"%s\"\n", node->strval);
					}
				}
				else
				{
					if(node->isGlobal)
					{
						if(node->type == TYPE_INT || node->type == TYPE_BOOL)
						{
							printTabs(false);
							fprintf(yyout, "getstatic int %s.%s\n", progName, $1);
						}
					}
					else
					{
						if(node->type == TYPE_INT || node->type == TYPE_BOOL)
						{
							printTabs(false);
							fprintf(yyout, "iload %u\n", node->localIndex);
						}
					}
				}
			}
		}
		| Id {check_id_exist($1);} '(' comma_sep_expr ')' {
			symbolNode* node = lookup($1, false); // get entry
			if(node->type != TYPE_PROC) // procedure type
			{
				yyerror("ERROR!! Ident is not callable");
			}
			int ct = param_types.top; // params count
			if((node->procExtend).paramNum != ct)
			{
				// num of param incompatible
				yyerror("ERROR!! Num of procedure params incompatible");
			}
			for(int i=ct-1; i>=0; i--)
			{
				if((node->procExtend).paramType[i] != typeStack_getDel(1))
				{
					// type of param incompatible
					yyerror("ERROR!! Type of procedure params incompatible");
				}
			}
			typeStack_add((node->procExtend).returnType, 0);

			if(assignNode == NULL)
			{
				printTabs(false);
				fprintf(yyout, "invokestatic");
				if((node->procExtend).returnType == TYPE_INT)
				{
					fprintf(yyout, " int");
				}
				else if((node->procExtend).returnType == TYPE_BOOL)
				{
					fprintf(yyout, " int");
				}
				else if((node->procExtend).returnType == TYPE_BOOL)
				{
					fprintf(yyout, " void");
				}
				fprintf(yyout, " %s.%s", progName, $1);
				fprintf(yyout, "(");
				short isBegin = true;
				for(int i=0; i<((node->procExtend).paramNum); i++)
				{
					if(isBegin == false)
					{
						fprintf(yyout, ", ");
					}
					else
					{
						isBegin = false;
					}
					if((node->procExtend).paramType[i] == TYPE_INT)
					{
						fprintf(yyout, "int");
					}
					else if((node->procExtend).paramType[i] == TYPE_BOOL)
					{
						fprintf(yyout, "int");
					}
				}
				fprintf(yyout, ")\n");
			}
		}
		| Id {check_id_exist($1);} '[' expr {
				if(typeStack_getDel(0) != TYPE_INT)
				{
					// index field is not integer
					yyerror("ERROR!! Type of array index is not integer");
				}
			} ']' {
			enum TYPE t = lookup($1, false)->type;
			if(t < 4 || t > 7)
			{
				// not array type
				yyerror("ERROR!! Ident is not indexable");
			}
			typeStack_add(t - 4, 0); // record array stroaged type, not array itself
		}
		;
/*expr*/
expr: expr_obj
	| '(' expr ')' %prec BRACE
	| '-' expr %prec UMINUS {
		enum TYPE t = typeStack_getDel(0); // expr type
		if(t != TYPE_INT && t != TYPE_REAL)
		{
			// not int or real
			yyerror("ERROR!! Type error in '-'(unary)");
		}
		typeStack_add(t, 0);
		
		if(assignNode != NULL)
		{
			if(t == TYPE_INT)
			{
				int val = valueStack_int_getDel();
				val = -val;
				valueStack_add(val, -1, NULL, 1);
			}
		}
		else
		{
			if(t == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "ineg\n");
			}
		}
	}
	| expr '*' expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr type
		enum TYPE t2 = typeStack_getDel(0); // left expr type
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '*'");
		}
		typeStack_add(t1, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				int val = val1 * val2;
				valueStack_add(val, -1, NULL, 1);
			}
		}
		else
		{
			if(t1 == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "imul\n");
			}
		}
	}
	| expr '/' expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '/'");
		}
		typeStack_add(t1, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				if(val2 == 0)
				{
					yyerror("ERROR! div 0");
				}
				int val = val1 / val2;
				valueStack_add(val, -1, NULL, 1);
			}
		}
		else
		{
			if(t1 == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "idiv\n");
			}
		}
	}
	| expr '+' expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '+'");
		}
		typeStack_add(t1, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				int val = val1 + val2;
				valueStack_add(val, -1, NULL, 1);
			}
		}
		else
		{
			if(t1 == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "iadd\n");
			}
		}
	}
	| expr '-' expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '-'(binary)");
		}
		typeStack_add(t1, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				int val = val1 - val2;
				valueStack_add(val, -1, NULL, 1);
			}
		}
		else
		{
			if(t1 == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "isub\n");
			}
		}
	}
	| expr LT expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL && t1 != TYPE_STR))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '<'");
		}
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				short val = (val1 < val2);
				valueStack_add(-1, val, NULL, 2);
			}
			else if(t1 == TYPE_STR)
			{
				char val2[100];
				strcpy(val2, valueStack_str_getDel());
				char val1[100];
				strcpy(val1, valueStack_str_getDel());
				int l1 = strlen(val1);
				int l2 = strlen(val2);
				short val = ((l1 < l2) || ((l1 == l2) && (strcmp(val1, val2)<0)));
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			if(t1 == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "isub\n");
				printTabs(false);
				fprintf(yyout, "iflt L%u\n", labelId);
				printTabs(false);
				fprintf(yyout, "iconst_0\n");
				printTabs(false);
				fprintf(yyout, "goto L%u\n", labelId+1);

				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId);
				tabDepth += 1;

				printTabs(false);
				fprintf(yyout, "iconst_1\n");
				
				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId+1);
				tabDepth += 1;

				labelId += 2;
			}
		}
	}
	| expr LE expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL && t1 != TYPE_STR))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '<='");
		}
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				short val = (val1 <= val2);
				valueStack_add(-1, val, NULL, 2);
			}
			else if(t1 == TYPE_STR)
			{
				char val2[100];
				strcpy(val2, valueStack_str_getDel());
				char val1[100];
				strcpy(val1, valueStack_str_getDel());
				int l1 = strlen(val1);
				int l2 = strlen(val2);
				short val = ((l1 < l2) || ((l1 == l2) && (strcmp(val1, val2)<=0)));
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			if(t1 == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "isub\n");
				printTabs(false);
				fprintf(yyout, "ifle L%u\n", labelId);
				printTabs(false);
				fprintf(yyout, "iconst_0\n");
				printTabs(false);
				fprintf(yyout, "goto L%u\n", labelId+1);

				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId);
				tabDepth += 1;

				printTabs(false);
				fprintf(yyout, "iconst_1\n");
				
				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId+1);
				tabDepth += 1;

				labelId += 2;
			}
		}
	}
	| expr EQ expr{
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // leftexpr
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL && t1 != TYPE_STR && t1 != TYPE_BOOL))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '='");
		}
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				short val = (val1 == val2);
				valueStack_add(-1, val, NULL, 2);
			}
			else if(t1 == TYPE_STR)
			{
				char val2[100];
				strcpy(val2, valueStack_str_getDel());
				char val1[100];
				strcpy(val1, valueStack_str_getDel());
				int l1 = strlen(val1);
				int l2 = strlen(val2);
				short val = (strcmp(val1, val2) == 0);
				valueStack_add(-1, val, NULL, 2);
			}
			else if(t1 == TYPE_BOOL)
			{
				short val2 = valueStack_bool_getDel();
				short val1 = valueStack_bool_getDel();
				short val = (val1 == val2);
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			if(t1 == TYPE_INT || t1 == TYPE_BOOL)
			{
				printTabs(false);
				fprintf(yyout, "isub\n");
				printTabs(false);
				fprintf(yyout, "ifeq L%u\n", labelId);
				printTabs(false);
				fprintf(yyout, "iconst_0\n");
				printTabs(false);
				fprintf(yyout, "goto L%u\n", labelId+1);

				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId);
				tabDepth += 1;

				printTabs(false);
				fprintf(yyout, "iconst_1\n");
				
				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId+1);
				tabDepth += 1;

				labelId += 2;
			}
		}
	}
	| expr GE expr {
		enum TYPE t1 = typeStack_getDel(0); // right expt
		enum TYPE t2 = typeStack_getDel(0); // left expt
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL && t1 != TYPE_STR))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '>='");
		}
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				short val = (val1 >= val2);
				valueStack_add(-1, val, NULL, 2);
			}
			else if(t1 == TYPE_STR)
			{
				char val2[100];
				strcpy(val2, valueStack_str_getDel());
				char val1[100];
				strcpy(val1, valueStack_str_getDel());
				int l1 = strlen(val1);
				int l2 = strlen(val2);
				short val = ((l1 > l2) || ((l1 == l2) && (strcmp(val1, val2)>=0)));
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			if(t1 == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "isub\n");
				printTabs(false);
				fprintf(yyout, "ifge L%u\n", labelId);
				printTabs(false);
				fprintf(yyout, "iconst_0\n");
				printTabs(false);
				fprintf(yyout, "goto L%u\n", labelId+1);

				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId);
				tabDepth += 1;

				printTabs(false);
				fprintf(yyout, "iconst_1\n");
				
				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId+1);
				tabDepth += 1;

				labelId += 2;
			}
		}
	}
	| expr GT expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL && t1 != TYPE_STR))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '>'");
		}
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				short val = (val1 > val2);
				valueStack_add(-1, val, NULL, 2);
			}
			else if(t1 == TYPE_STR)
			{
				char val2[100];
				strcpy(val2, valueStack_str_getDel());
				char val1[100];
				strcpy(val1, valueStack_str_getDel());
				int l1 = strlen(val1);
				int l2 = strlen(val2);
				short val = ((l1 > l2) || ((l1 == l2) && (strcmp(val1, val2)>0)));
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			if(t1 == TYPE_INT)
			{
				printTabs(false);
				fprintf(yyout, "isub\n");
				printTabs(false);
				fprintf(yyout, "ifgt L%u\n", labelId);
				printTabs(false);
				fprintf(yyout, "iconst_0\n");
				printTabs(false);
				fprintf(yyout, "goto L%u\n", labelId+1);

				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId);
				tabDepth += 1;

				printTabs(false);
				fprintf(yyout, "iconst_1\n");
				
				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId+1);
				tabDepth += 1;

				labelId += 2;
			}
		}
	}
	| expr NE expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || (t1 != TYPE_INT && t1 != TYPE_REAL && t1 != TYPE_STR && t1 != TYPE_BOOL))
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in '/='");
		}
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_INT)
			{
				int val2 = valueStack_int_getDel();
				int val1 = valueStack_int_getDel();
				short val = (val1 != val2);
				valueStack_add(-1, val, NULL, 2);
			}
			else if(t1 == TYPE_STR)
			{
				char val2[100];
				strcpy(val2, valueStack_str_getDel());
				char val1[100];
				strcpy(val1, valueStack_str_getDel());
				int l1 = strlen(val1);
				int l2 = strlen(val2);
				short val = (strcmp(val1, val2) != 0);
				valueStack_add(-1, val, NULL, 2);
			}
			else if(t1 == TYPE_BOOL)
			{
				short val2 = valueStack_bool_getDel();
				short val1 = valueStack_bool_getDel();
				short val = (val1 != val2);
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			if(t1 == TYPE_INT || t1 == TYPE_BOOL)
			{
				printTabs(false);
				fprintf(yyout, "isub\n");
				printTabs(false);
				fprintf(yyout, "ifne L%u\n", labelId);
				printTabs(false);
				fprintf(yyout, "iconst_0\n");
				printTabs(false);
				fprintf(yyout, "goto L%u\n", labelId+1);

				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId);
				tabDepth += 1;

				printTabs(false);
				fprintf(yyout, "iconst_1\n");
				
				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "L%u:\n", labelId+1);
				tabDepth += 1;

				labelId += 2;
			}
		}
	}
	| NOT expr {
		enum TYPE t = typeStack_getDel(0); // expr
		if(t != TYPE_BOOL)
		{
			// wrong type
			yyerror("ERROR!! Type error in 'NOT'");
		}	
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t == TYPE_BOOL)
			{
				short val = valueStack_bool_getDel();
				val = !val;
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			printTabs(false);
			fprintf(yyout, "iconst_1\n");
			printTabs(false);
			fprintf(yyout, "ixor\n");
		}
	}
	| expr AND expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || t1 != TYPE_BOOL)
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in 'AND'");
		}	
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_BOOL)
			{
				short val2 = valueStack_bool_getDel();
				short val1 = valueStack_bool_getDel();
				short val = (val1 && val2);
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			printTabs(false);
			fprintf(yyout, "iand\n");
		}
	}
	| expr OR expr {
		enum TYPE t1 = typeStack_getDel(0); // right expr
		enum TYPE t2 = typeStack_getDel(0); // left expr
		if(t1 != t2 || t1 != TYPE_BOOL)
		{
			// incompatible or wrong type
			yyerror("ERROR!! Type error in 'OR'");
		}	
		typeStack_add(TYPE_BOOL, 0);
		
		if(assignNode != NULL)
		{
			if(t1 == TYPE_BOOL)
			{
				short val2 = valueStack_bool_getDel();
				short val1 = valueStack_bool_getDel();
				short val = (val1 || val2);
				valueStack_add(-1, val, NULL, 2);
			}
		}
		else
		{
			printTabs(false);
			fprintf(yyout, "ior\n");
		}
	}
	;
/*one or more stat*/
onemore_stat: stat
			| stat onemore_stat
			;
/*block*/
block: {
	 		if(blockLock==false)
			{
				printTabs(true);
				fprintf(commentout, "/*\n");
				printTabs(true);
				fprintf(commentout, " *\n");
			}
			else
			{
				printTabs(true);
				fprintf(commentout, "/*\n");
			}
			printTabs(true);
			fprintf(commentout, " * <Block>\n");
			printTabs(true);
			fprintf(commentout, " */\n");
			if(blockLock==false)
			{
				create();
				localIndex = 0;
			}
			blockLock=false; // disable block lock

			vdeclareState = 2; // local declaration
			
			if(blockFgCt == 0)
			{
				printTabs(false);
				fprintf(yyout, "{\n");
				tabDepth += 1;
			}

			procDeepCt += 1;
		} opt_vdeclare {vdeclareState = 0;} MY_BEGIN {dump();} onemore_stat END ';' {
			delete();

			procDeepCt -= 1;
			if(returnType != SPECIAL_NOT_PROC_CALL && procDeepCt == 0 && hasReturn == false)
			{
				if(returnType == NONE)
				{
					printTabs(false);
					fprintf(yyout, "return\n");
				}
				else
				{
					yyerror("ERROR! Procedure has no return inside");
				}
			}
			
			if(blockFgCt == 0)
			{
				tabDepth -= 1;
				printTabs(false);
				fprintf(yyout, "}\n");
			}
			printTabs(true);
			fprintf(commentout, "/*\n");
			printTabs(true);
			fprintf(commentout, " * <End Block>\n");
			printTabs(true);
			fprintf(commentout, " *\n");
			printTabs(true);
			fprintf(commentout, " */\n");
	 }
	 ;
/* one block or simple stat */
one_block_or_simple_stat: {blockFgCt += 1;} block {blockFgCt -= 1;}
						| simple_stat
						;
/* optional else */
opt_else: {
			unsigned int label = labelStack_getDel();
			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", label);
			tabDepth += 1;
		}
		| ELSE {
			unsigned int label = labelStack_getDel();
			printTabs(false);
			fprintf(yyout, "goto L%u\n", label+1);
			labelStack_add(label+1);

			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", label);
			tabDepth += 1;
		} one_block_or_simple_stat {
			unsigned int label = labelStack_getDel();
			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", label);
			tabDepth += 1;
		}
		;
/* condition */
cond: IF {typeStack_init(0);} expr {
		   	if(typeStack_getDel(0) != TYPE_BOOL) /* expr */
			{
				yyerror("ERROR!! Type in condition is not boolean");
			}

			printTabs(false);
			fprintf(yyout, "ifeq L%u\n", labelId);
			labelStack_add(labelId);
			labelId += 2;
		} THEN one_block_or_simple_stat opt_else END IF ';'
	;
/* loop */
loop: WHILE {
			typeStack_init(0);
			
			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", labelId);
			tabDepth += 1;

			labelStack_add(labelId);
			labelId += 2;
		} expr {
		   	if(typeStack_getDel(0) != TYPE_BOOL) /* expr */
			{
				yyerror("ERROR!! Type in condition is not boolean");
			}
			
			unsigned int label = labelStack_getDel();
			printTabs(false);
			fprintf(yyout, "ifeq L%u\n", label+1);
			labelStack_add(label);
		} LOOP one_block_or_simple_stat {
			unsigned int label = labelStack_getDel();
			printTabs(false);
			fprintf(yyout, "goto L%u\n", label);

			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", label+1);
			tabDepth += 1;
		} END LOOP ';'
	| FOR '(' Id {
			check_id_exist($3);
			if(lookup($3, false)->type != TYPE_INT)
			{
				yyerror("ERROR!! Type of loop variable is not integer");
			}
		} IN Integer '.' '.' Integer ')' LOOP {
			symbolNode* node = lookup($3, false);

			printTabs(false);
			fprintf(yyout, "sipush %d\n", $6);
			if(node->isGlobal)
			{
				if(node->type == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "putstatic int %s.%s\n", progName, $3);
				}
			}
			else
			{
				if(node->type == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "istore %u\n", node->localIndex);
				}
			}

			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", labelId);
			tabDepth += 1;
			if(node->isGlobal)
			{
				if(node->type == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "getstatic int %s.%s\n", progName, $3);
				}
			}
			else
			{
				if(node->type == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "iload %u\n", node->localIndex);
				}
			}
			printTabs(false);
			fprintf(yyout, "sipush %d\n", $9);
			printTabs(false);
			fprintf(yyout, "isub\n");
			printTabs(false);
			fprintf(yyout, "ifle L%u\n", labelId+1);
			printTabs(false);
			fprintf(yyout, "iconst_0\n");
			printTabs(false);
			fprintf(yyout, "goto L%u\n", labelId+2);
			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", labelId+1);
			tabDepth += 1;
			printTabs(false);
			fprintf(yyout, "iconst_1\n");
			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", labelId+2);
			tabDepth += 1;
			
			printTabs(false);
			fprintf(yyout, "ifeq L%u\n", labelId+3);
			
			labelStack_add(labelId);
			labelId += 4;
		} one_block_or_simple_stat {
			symbolNode* node = lookup($3, false);
			if(node->isGlobal)
			{
				if(node->type == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "getstatic int %s.%s\n", progName, $3);
				}
			}
			else
			{
				if(node->type == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "iload %u\n", node->localIndex);
				}
			}
			printTabs(false);
			fprintf(yyout, "sipush 1\n");
			printTabs(false);
			fprintf(yyout, "iadd\n");
			if(node->isGlobal)
			{
				if(node->type == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "putstatic int %s.%s\n", progName, $3);
				}
			}
			else
			{
				if(node->type == TYPE_INT)
				{
					printTabs(false);
					fprintf(yyout, "istore %u\n", node->localIndex);
				}
			}
			
			unsigned int label = labelStack_getDel();
			printTabs(false);
			fprintf(yyout, "goto L%u\n", label);
			tabDepth -= 1;
			printTabs(false);
			fprintf(yyout, "L%u:\n", label+3);
			tabDepth += 1;
		} END LOOP ';'
	;
/* procedure call */
proc_call: Id {check_id_exist($1);} ';' {
		 	symbolNode* node = lookup($1, false);
		 	if(node->type != TYPE_PROC)
			{
				yyerror("ERROR!! Id is not a procedure");
			}
			if((node->procExtend).paramNum != 0)
			{
				// num of param incompatible
				yyerror("ERROR!! Num of procedure params incompatible");
			}

			printTabs(false);
			fprintf(yyout, "invokestatic");
			if((node->procExtend).returnType == TYPE_INT)
			{
				fprintf(yyout, " int");
			}
			else if((node->procExtend).returnType == TYPE_BOOL)
			{
				fprintf(yyout, " int");
			}
			else if((node->procExtend).returnType == NONE)
			{
				fprintf(yyout, " void");
			}
			fprintf(yyout, " %s.%s()\n", progName, $1);
		 }
		 | Id {check_id_exist($1);} '(' {typeStack_init(1);} comma_sep_expr ')' ';' {
		 	symbolNode* node = lookup($1, false);
			if(node->type != TYPE_PROC)
			{
				yyerror("ERROR!! Id is not a procedure");
			}
			int ct = param_types.top; // param count
			if((node->procExtend).paramNum != ct)
			{
				// num of param incompatible
				yyerror("ERROR!! Num of procedure params incompatible");
			}
			for(int i=ct-1; i>=0; i--)
			{
				if((node->procExtend).paramType[i] != typeStack_getDel(1))
				{
					// type of param incomaptible
					yyerror("ERROR!! Type of procedure params incompatible");
				}
			}

			printTabs(false);
			fprintf(yyout, "invokestatic");
			if((node->procExtend).returnType == TYPE_INT)
			{
				fprintf(yyout, " int");
			}
			else if((node->procExtend).returnType == TYPE_BOOL)
			{
				fprintf(yyout, " int");
			}
			else if((node->procExtend).returnType == NONE)
			{
				fprintf(yyout, " void");
			}
			fprintf(yyout, " %s.%s", progName, $1);
			fprintf(yyout, "(");
			short isBegin = true;
			for(int i=0; i<((node->procExtend).paramNum); i++)
			{
				if(isBegin == false)
				{
					fprintf(yyout, ", ");
				}
				else
				{
					isBegin = false;
				}
				if((node->procExtend).paramType[i] == TYPE_INT)
				{
					fprintf(yyout, "int");
				}
				else if((node->procExtend).paramType[i] == TYPE_BOOL)
				{
					fprintf(yyout, "int");
				}
			}
			fprintf(yyout, ")\n");
		 }
		 ;

%%
//#include "lex.yy.c"

// report error and stop parsing
void yyerror(char* msg)
{
	
    fprintf(stderr, "\n%s\n", msg);
	fprintf(stderr, "Compile Failed!\n");
	fprintf(stderr, "Happened at Line: %u\n", lineCount);
	fprintf(stderr, "currLine: %s\n\n", currLine);
	exit(1);
}

int main(int argc, char**argv)
{
    /* open the source program file */
    if (argc != 3 && argc != 2) {
        printf ("Usage: ./parser fileInput [fileOutput]\n");
        exit(1);
    }
    yyin = fopen(argv[1], "r");         /* open input file */
	if(argc == 3)
	{
		yyout = fopen(argv[2], "w");	/* open specific output file */
	}
	else
	{
		char* pch = strtok(argv[1], "/");
		char* ptemp = pch;
		while(pch != NULL)
		{
			ptemp = pch;
			pch = strtok(NULL, "/");
		}
		char* pch2 = strtok(ptemp, ".");
		if(pch2 == NULL)
		{
			yyout = fopen("a.jasm", "w");	/* open default output file */
		}
		else
		{
			char fn[100];
			fn[0] = '\0';
			strcpy(fn, pch2);
			strcat(fn, ".jasm");
			yyout = fopen(fn, "w");	/* open default output file */
		}
	}
	//yyout = stdout;
	commentout = yyout;
	//commentout = fopen("b.jasm", "w");
	create();

    /* perform parsing */
    if (yyparse() == 1)                 /* parsing */
        yyerror("Parsing error !");     /* syntax error */
}

// enum TYPE to type name
char* num_type(enum TYPE type)
{
	switch(type)
	{
		case TYPE_INT:
			return "Integer";
		case TYPE_STR:
			return "String";
		case TYPE_BOOL:
			return "Bool";
		case TYPE_REAL:
			return "Real";
		case TYPE_INT_ARRAY:
			return "Integer array";
		case TYPE_STR_ARRAY:
			return "String array";
		case TYPE_BOOL_ARRAY:
			return "Bool array";
		case TYPE_REAL_ARRAY:
			return "Real array";
		case TYPE_PROG:
			return "Program";
		case TYPE_PROC:
			return "Procedure";
		case NONE:
			return "NONE";
		default:
			return "ERROR";
	}
}

// initialize type stack
void typeStack_init(short stackId)
{
	if(stackId == 0)
	{
		expr_types.top = 0;
	}
	else if(stackId == 1)
	{
		param_types.top = 0;
	}
}
// add type into type staack
void typeStack_add(enum TYPE type, short stackId)
{
	if(stackId == 0)
	{
		expr_types.stack[expr_types.top] = type;
		expr_types.top += 1;
	}
	else if(stackId == 1)
	{
		param_types.stack[param_types.top] = type;
		param_types.top += 1;
	}
}
// get type on top of stack and move it out
enum TYPE typeStack_getDel(short stackId)
{
	if(stackId == 0)
	{
		expr_types.top -= 1;
		return expr_types.stack[expr_types.top];
	}
	else if(stackId == 1)
	{
		param_types.top -= 1;
		return param_types.stack[param_types.top];
	}
	else
	{
		return -2; //ERROR
	}
}
// dump type stack
void typeStack_dump(short stackId)
{
	printf("===== Type Stack =====\n");
	if(stackId == 0)
	{
		printf("=       top: %d      =\n", expr_types.top);
		for(int i=0; i<expr_types.top; i++)
		{
			printf("=       %d: %d       =\n", i, expr_types.stack[i]);
		}
	}
	else if(stackId == 1)
	{
		printf("=       top: %d      =\n", param_types.top);
		for(int i=0; i<param_types.top; i++)
		{
			printf("=       %d: %d       =\n", i, param_types.stack[i]);
		}
	}
	printf("======================\n");
}

void labelStack_add(unsigned int id)
{
	labelIdStack.stack[labelIdStack.top] = id;
	labelIdStack.top += 1;
}
unsigned int labelStack_getDel()
{
	labelIdStack.top -= 1;
	return labelIdStack.stack[labelIdStack.top];
}

void valueStack_init()
{
	valStack.inttop = 0;
	valStack.booltop = 0;
	valStack.strtop = 0;
}
void valueStack_add(int intval, short boolval, char* strval, short channel)
{
	if(channel == 1)
	{
		valStack.intstack[valStack.inttop] = intval;
		valStack.inttop += 1;
	}
	else if(channel == 2)
	{
		valStack.boolstack[valStack.booltop] = boolval;
		valStack.booltop += 1;
	}
	else if(channel == 3)
	{
		strcpy(valStack.strstack[valStack.strtop], strval);
		valStack.strtop += 1;
	}
}
int valueStack_int_getDel()
{
	valStack.inttop -= 1;
	return valStack.intstack[valStack.inttop];
}
short valueStack_bool_getDel()
{
	valStack.booltop -= 1;
	return valStack.boolstack[valStack.booltop];
}
char* valueStack_str_getDel()
{
	valStack.strtop -= 1;
	return valStack.strstack[valStack.strtop];
}

// check id is in symbol table or not
// if not, raise error
void check_id_exist(char* id)
{	
	if(lookup(id, false) == NULL)
	{
		char msg[80] = {0};
		strcat(msg, "ERROR! id ");
		strcat(msg, id);
		strcat(msg, " not declare before use.");
		yyerror(msg);
	}
}

// create new symbol table
void create()
{
	symbolTable* oldTable = table;
	table = (symbolTable*)malloc(sizeof(symbolTable));
	table->pastTable = oldTable;
	for(int i=0; i<52; i++)
	{
		table->fastIndex[i] = NULL;
	}
}
// lookup symbol table entry of id
symbolNode* lookup(char* s, short onlyTop)
{
	if(table == NULL)
	{
		fprintf(stderr, "ERROR! table is NULL\n");
		return NULL;
	}

	// get index
	int index = -1;
	if((s[0] >= 'A') && (s[0] <= 'Z'))
	{
		index = 26 + (s[0] - 'A');
	}
	else if((s[0] >= 'a') && (s[0] <= 'z'))
	{
		index = (s[0] - 'a');
	}
	
	if(index == -1) // index is not alphabet
	{
		fprintf(stderr, "Index error\n");
		fprintf(stderr, "Key: %s", s);
		exit(1);
	}
	else
	{
		symbolTable* currTable = table;
		while(currTable != NULL)
		{
			// find entry in single symbol table
			symbolNode* curr = currTable->fastIndex[index];
			while(curr != NULL)
			{
				if(strcmp(curr->id, s) == 0)
				{
					return curr;
				}
				else
				{
					curr = curr->nextNode;
				}
			}
			
			// move to next table
			currTable = currTable->pastTable;

			if(onlyTop)
			{
				break;
			}
		}

		return NULL;
	}
}
// insert id into symbol table
void insert(char* s)
{
	if(table == NULL)
	{
		fprintf(stderr, "ERROR! table is NULL!\n");
		return;
	}
	
	// get index
	int index = -1;
	if((s[0] >= 'A') && (s[0] <= 'Z'))
	{
		index = 26 + (s[0] - 'A');
	}
	else if((s[0] >= 'a') && (s[0] <= 'z'))
	{
		index = (s[0] - 'a');
	}
	
	if(index == -1) // index is not alphabet
	{
		fprintf(stderr, "Index error\n");
		fprintf(stderr, "Key: %s", s);
		exit(1);
	}
	else
	{
		symbolNode* curr = table->fastIndex[index];
		if(curr == NULL || strcmp(s, curr->id) < 0)
		{
			// fastIndex has no node

			table->fastIndex[index] = (symbolNode*)malloc(sizeof(symbolNode));
			strcpy(table->fastIndex[index]->id, s);
			table->fastIndex[index]->type = NONE;
			table->fastIndex[index]->nextNode = curr;
		}
		else
		{
			// fastIndex has node

			symbolNode* last = curr;
			curr = curr->nextNode;
			while(curr != NULL && strcmp(s, curr->id) >= 0)
			{
				last = curr;
				curr = curr->nextNode;
			}
			
			last->nextNode = (symbolNode*)malloc(sizeof(symbolNode));
			strcpy(last->nextNode->id, s);
			last->nextNode->type = NONE;
			last->nextNode->nextNode = curr;
		}
	}
}
// dump symbol table
void dump()
{
	printTabs(true);
	fprintf(commentout, "/*\n");
	printTabs(true);
	fprintf(commentout, " * ----------------------------------\n");
	printTabs(true);
	fprintf(commentout, " * \tDump Symbol Tables:\n");

	if(table == NULL)
	{
		printTabs(true);
		fprintf(commentout, " * \n");
		printTabs(true);
		fprintf(commentout, " * \t[table is NULL]\n");
		printTabs(true);
		fprintf(commentout, " * ----------------------------------\n");
		printTabs(true);
		fprintf(commentout, " *\n");
		printTabs(true);
		fprintf(commentout, " */\n");
		return;
	}
	int ct = 0;
	symbolTable* currTable = table;

	while(currTable != NULL)
	{
		printTabs(true);
		fprintf(commentout, " * \n");
		printTabs(true);
		fprintf(commentout, " * \t[Symbol Table %d]:\n", ct);
	
		for(int i=0; i<52; i++)
		{
			symbolNode* curr = currTable->fastIndex[i];
			while(curr != NULL)
			{
				printTabs(true);
				fprintf(commentout, " * \t(%s%s)", (curr->isConst)? "const ": "", num_type(curr->type));
				fprintf(commentout, " [%s", (curr->isGlobal)? "G": "L");
				if(curr->isGlobal == false)
				{
					fprintf(commentout, " %u", curr->localIndex);
				}
				fprintf(commentout, "]");

				fprintf(commentout, " %s", curr->id);
				if(curr->type == TYPE_PROC)
				{
					// print additional procedure info
					fprintf(commentout, " < [ ");
					int ct = (curr->procExtend).paramNum;
					for(int i=0; i<ct; i++)
					{
						fprintf(commentout, "%s, ", num_type((curr->procExtend).paramType[i]));
					}
					fprintf(commentout, "] -> %s >", num_type((curr->procExtend).returnType));
				}
				else if(curr->type == TYPE_INT)
				{
					fprintf(commentout, " = %d", curr->intval);
				}
				else if(curr->type == TYPE_STR)
				{
					fprintf(commentout, " = %s", curr->strval);
				}
				else if(curr->type == TYPE_BOOL)
				{
					fprintf(commentout, " = %s", (curr->boolval == 0)? "false": "true");
				}
				fprintf(commentout, "\n");
				curr = curr->nextNode;
			}
		}
		ct -= 1;
		currTable = currTable->pastTable;
	}
	printTabs(true);
	fprintf(commentout, " * \n");
	printTabs(true);
	fprintf(commentout, " * \t[No past tables]\n");
	
	printTabs(true);
	fprintf(commentout, " * ----------------------------------\n");
	printTabs(true);
	fprintf(commentout, " *\n");
	printTabs(true);
	fprintf(commentout, " */\n");
}
// free single symbol table
void delete()
{
	if(table == NULL)
	{
		return;
	}
	symbolTable* lastTable = table->pastTable;

	// free fastIndex
	for(int i=0; i<52; i++)
	{
		symbolNode* currNode = table->fastIndex[i];
		while(currNode != NULL)
		{
			symbolNode* nextNode = currNode->nextNode;
			free(currNode);
			currNode = nextNode;
		}
	}
	free(table);
	table = lastTable;
}
// fill type of id in symbol table
void fillType(char* id, enum TYPE type, short isConst, short isGlobal)
{
	symbolNode* node = lookup(id, false);

	if(node == NULL)
	{
		fprintf(stderr, "ERROR! id isn't in symbol table\n");
		fprintf(stderr, "==========\n");
		fprintf(stderr, "%s\n", id);
		dump();
		fprintf(stderr, "==========\n");
		return;
	}

	node->type = type;
	node->isConst = isConst;
	node->isGlobal = isGlobal;

	if(isGlobal == false)
	{
		node->localIndex = localIndex;
		localIndex += 1;
	}
}

void printTabs(short isComment)
{
	FILE* out = stdout;
	if(isComment)
	{
		out = commentout;
	}
	else
	{
		out = yyout;
	}

	for(int tabs =0; tabs<tabDepth; tabs++)
	{
		fprintf(out, "\t");
	}
}
