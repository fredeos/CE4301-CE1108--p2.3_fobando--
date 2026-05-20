parser grammar FCCParser;

options { tokenVocab=FCCLexer; }


// 1. REGLA INICIAL

program
    : topLevelDecl* EOF
    ;


// 2. ELEMENTOS DE ALTO NIVEL

topLevelDecl
    : importStmt
    | secureFunctionDecl
    | functionDecl
    | globalVarDecl
    ;

importStmt
    : TRAIGASE STRING_LITERAL
    ;

secureFunctionDecl
    : secureAnnotation functionDecl
    ;

secureAnnotation
    : SECURE LPAREN HEX_LITERAL RPAREN
    ;

functionName
    : IDENTIFIER
    | MAIN
    ;

functionDecl
    : FUNC typeRule functionName LPAREN parameterList? RPAREN block
    ;

globalVarDecl
    : varDecl
    ;

parameterList
    : parameter (COMMA parameter)*
    ;

parameter
    : typeRule IDENTIFIER
    ;


// 3. TIPOS

typeRule
    : (vaultType | baseType) (STAR)* arraySuffix*
    ;

baseType
    : INT
    | FLOAT
    | BOOL
    | CHAR
    | VOID
    ;

vaultType
    : VAULT LBRACK INT_LITERAL RBRACK
    ;

arraySuffix
    : LBRACK expression? RBRACK
    ;


// 4. BLOQUES Y SENTENCIAS

block
    : LBRACE statement* RBRACE
    ;

statement
    : varDecl
    | assignmentStmt
    | ifStmt
    | whileStmt
    | forStmt
    | returnStmt
    | continueStmt
    | breakStmt
    | exprStmt
    | block
    ;

varDecl
    : typeRule variableDeclaratorList SEMI
    ;

variableDeclaratorList
    : variableDeclarator (COMMA variableDeclarator)*
    ;

variableDeclarator
    : IDENTIFIER arraySuffix* (ASSIGN initializer)?
    ;

initializer
    : expression
    ;

assignmentStmt
    : assignment SEMI
    ;

assignment
    : assignable assignmentOperator expression
    ;

assignmentOperator
    : ASSIGN
    | PLUS_ASSIGN
    | MINUS_ASSIGN
    | STAR_ASSIGN
    | SLASH_ASSIGN
    | PERCENT_ASSIGN
    | AND_ASSIGN
    | OR_ASSIGN
    | XOR_ASSIGN
    ;

assignable
    : postfixExpression
    ;

returnStmt
    : RET expression? SEMI
    ;

continueStmt
    : CONTINUE SEMI
    ;

breakStmt
    : BREAK SEMI
    ;

exprStmt
    : expression SEMI
    ;


// 5. ESTRUCTURAS DE CONTROL

ifStmt
    : IF LPAREN expression RPAREN block elifBranch* elseBranch?
    ;

elifBranch
    : ELIF LPAREN expression RPAREN block
    ;

elseBranch
    : ELSE block
    ;

whileStmt
    : WHILE LPAREN expression RPAREN block
    ;

forStmt
    : FOR LPAREN forInitializer SEMI forIncrement SEMI forCondition RPAREN block
    ;
forInitializer
    : varDeclNoSemi
    | assignment
    ;

forIncrement
    : assignment
    ;

forCondition
    : expression
    ;

varDeclNoSemi
    : typeRule variableDeclaratorList
    ;


// 6. EXPRESIONES

expression
    : bitwiseOrExpression
    ;

bitwiseOrExpression
    : bitwiseXorExpression (OR bitwiseXorExpression)*
    ;

bitwiseXorExpression
    : bitwiseAndExpression (XOR bitwiseAndExpression)*
    ;

bitwiseAndExpression
    : equalityExpression (AMPERSAND equalityExpression)*
    ;

equalityExpression
    : relationalExpression ((EQ | NEQ) relationalExpression)*
    ;

relationalExpression
    : shiftExpression ((LT | LE | GT | GE) shiftExpression)*
    ;

shiftExpression
    : additiveExpression ((SHIFT_LEFT | SHIFT_RIGHT) additiveExpression)*
    ;

additiveExpression
    : multiplicativeExpression ((PLUS | MINUS) multiplicativeExpression)*
    ;

multiplicativeExpression
    : unaryExpression ((STAR | SLASH | PERCENT | POWER) unaryExpression)*
    ;

unaryExpression
    : (NOT | MINUS | AMPERSAND | STAR) unaryExpression
    | postfixExpression
    ;

postfixExpression
    : primary postfixSuffix*
    ;

postfixSuffix
    : LPAREN argumentList? RPAREN
    | LBRACK expression RBRACK
    | DOT IDENTIFIER
    ;

argumentList
    : expression (COMMA expression)*
    ;

primary
    : IDENTIFIER
    | MAIN
    | literal
    | LPAREN expression RPAREN
    ;

literal
    : INT_LITERAL
    | REAL_LITERAL
    | HEX_LITERAL
    | STRING_LITERAL
    | CHAR_LITERAL
    | TRUE
    | FALSE
    ;
