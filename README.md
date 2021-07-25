# Ada-_Compiler
Compiler project.

A Compiler of subset of Ada (Ada_minus) to java assembly compiler.

# Ada_minus lexical defination
## Character Set
ASCII characters

case-sensitive
## delimiters
```
comma           ,
colon           :
period          .
semicolon       ;
parentheses     ( )
square brackets [ ]
```
## operators
```
arithmetic      + - * /
relational      < <= >= > = /=
logical         and or not
assignment      :=
```
## keywords
```
and begin boolean break character case continue constant declare do else end exit false
float for if in integer loop not or print println procedure program return string true while
```
## identifiers
An identifier is a string of letters and digits beginning with a letter. Case of letters is relevant.
## integer constants
A sequence of one or more digits.
## Boolean Constants
Either true or false.
## String Constants
A string constant is a sequence of zero or more ASCII characters appearing between double-quote (")
delimiters. A double-quote appearing with a string must be written after a ". For example, "aa""bb"
denotes the string constant aa"bb.
## comments
A line comment us a text following a “--” delimiter running up to the end of the line.

# Ada_minus syntactic defination
Between < and > means optional
## declaration
### constant
```
identifier : constant <: type > := constant exp ;
```
### veriable
```
identifier <: type >< := constant exp > ;
```
## program unit
### program
```
program identifier
<declare
zero or more variable and constant declarations>
<zero or more procedure declarations>
begin
<zero or more statements>
end ;
end identifier
```
### procedure
```
procedure identifier < ( formal arguments ) > < return type >
block
end identifier ;
```
## statements
### simple
```
identifier := expression ;
```
or
```
print <(> expression <)> ;
```
or
```
println <(> expression <)> ;
```
or
```
read identifier ;
```
or
```
return ;
```
or
```
return expression ;
```
#### operations
Follow the precedence below. Left associative.
```
(1) - (unary)
(2) * /
(3) + -
(4) < <= = => > /=
(5) not
(6) and
(7) or
```
#### function invocation
```
identifier < ( comma-separated expressions ) >
```
### block
```
< declare
zero or more variable and constant declarations>
begin
<one or more statements>
end ;
```
### condition
```
if boolean expr then
a block or simple statement
else
a block or simple statement
end if ;
```
or
```
if boolean expr then
a block or simple statement
end if ;
```
### loop
```
while boolean expr loop
a block or simple statement
end loop ;
```
or
```
for ( identifier in num . . num )
a block or simple statement
end loop ;
```
### procedure invocation
```
identifier < ( semicomma-separated expressions ) > ;
```

# semantic defination
* The parameter passing mechanism for procedures in call-by-value.
* Scope rules are similar to C.
* The identifier after the end of program or procedure declaration must be the same identifiers as the
name given at the beginning of the declaration.
* Types of the left-hand-side identifier and the right-hand-side expression of every assignment must be
matched.
* The types of formal parameters must match the types of the actual parameters.
