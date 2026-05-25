"""Analisis interactivo para el prototipo de IDE FCC.

El modulo mantiene una gramatica LL(1) explicita con conjuntos FIRST/FOLLOW,
un parser predictivo descendente para diagnosticos y sugerencias, y una pasada
ascendente ligera para validar delimitadores y terminaciones.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import re
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple


EPSILON = "EPSILON"
EOF = "EOF"


@dataclass
class Token:
    kind: str
    lexeme: str
    line: int
    column: int
    start: int
    end: int


@dataclass
class Diagnostic:
    phase: str
    message: str
    line: int
    column: int
    start: int
    end: int
    expected: Set[str] = field(default_factory=set)


@dataclass
class Suggestion:
    text: str
    detail: str = ""


@dataclass
class Correction:
    title: str
    detail: str
    start: int
    end: int
    replacement: str


@dataclass
class AnalysisResult:
    tokens: List[Token]
    diagnostics: List[Diagnostic]
    suggestions: List[Suggestion]
    corrections: List[Correction]
    first_sets: Dict[str, Set[str]]
    follow_sets: Dict[str, Set[str]]


KEYWORDS = {
    "func": "FUNC",
    "ret": "RET",
    "void": "VOID",
    "int": "INT",
    "float": "FLOAT",
    "bool": "BOOL",
    "char": "CHAR",
    "if": "IF",
    "elif": "ELIF",
    "else": "ELSE",
    "for": "FOR",
    "while": "WHILE",
    "vault": "VAULT",
    "true": "TRUE",
    "false": "FALSE",
    "traigase": "TRAIGASE",
    "main": "MAIN",
    "continue": "CONTINUE",
    "break": "BREAK",
}

DISPLAY_BY_TOKEN = {
    "FUNC": "func",
    "RET": "ret",
    "VOID": "void",
    "INT": "int",
    "FLOAT": "float",
    "BOOL": "bool",
    "CHAR": "char",
    "IF": "if",
    "ELIF": "elif",
    "ELSE": "else",
    "FOR": "for",
    "WHILE": "while",
    "VAULT": "vault",
    "TRUE": "true",
    "FALSE": "false",
    "TRAIGASE": "traigase",
    "MAIN": "main",
    "CONTINUE": "continue",
    "BREAK": "break",
    "SECURE": "@secure",
    "IDENTIFIER": "identificador",
    "INT_LITERAL": "entero",
    "REAL_LITERAL": "real",
    "HEX_LITERAL": "hexadecimal",
    "STRING_LITERAL": '"archivo.f"',
    "CHAR_LITERAL": "'c'",
    "SEMI": ";",
    "COMMA": ",",
    "LPAREN": "(",
    "RPAREN": ")",
    "LBRACE": "{",
    "RBRACE": "}",
    "LBRACK": "[",
    "RBRACK": "]",
    "ASSIGN": "=",
}

TYPE_TOKENS = {"INT", "FLOAT", "BOOL", "CHAR", "VOID", "VAULT"}
LITERAL_TOKENS = {"INT_LITERAL", "REAL_LITERAL", "HEX_LITERAL", "STRING_LITERAL", "CHAR_LITERAL", "TRUE", "FALSE"}
EXPRESSION_START = {"IDENTIFIER", "MAIN", "LPAREN", "MINUS", "NOT", "AMPERSAND", "STAR", *LITERAL_TOKENS}
STATEMENT_START = {*TYPE_TOKENS, "IF", "WHILE", "FOR", "RET", "CONTINUE", "BREAK", "LBRACE", *EXPRESSION_START}

OPERATORS = {
    "==": "EQ",
    "!=": "NEQ",
    "<=": "LE",
    ">=": "GE",
    "<<": "SHIFT_LEFT",
    ">>": "SHIFT_RIGHT",
    "+=": "PLUS_ASSIGN",
    "-=": "MINUS_ASSIGN",
    "*=": "STAR_ASSIGN",
    "/=": "SLASH_ASSIGN",
    "%=": "PERCENT_ASSIGN",
    "&=": "AND_ASSIGN",
    "|=": "OR_ASSIGN",
    "^=": "XOR_ASSIGN",
    "+": "PLUS",
    "-": "MINUS",
    "*": "STAR",
    "/": "SLASH",
    "%": "PERCENT",
    "~": "POWER",
    "&": "AMPERSAND",
    "|": "OR",
    "^": "XOR",
    "!": "NOT",
    "=": "ASSIGN",
    "<": "LT",
    ">": "GT",
    "{": "LBRACE",
    "}": "RBRACE",
    "(": "LPAREN",
    ")": "RPAREN",
    "[": "LBRACK",
    "]": "RBRACK",
    ";": "SEMI",
    ",": "COMMA",
    ".": "DOT",
}


class FCCInteractiveLexer:
    """Lexer simple para edicion incremental del IDE."""

    def tokenize(self, text: str) -> Tuple[List[Token], List[Diagnostic]]:
        tokens: List[Token] = []
        diagnostics: List[Diagnostic] = []
        index = 0
        line = 1
        column = 0

        def advance(fragment: str):
            nonlocal line, column
            for char in fragment:
                if char == "\n":
                    line += 1
                    column = 0
                else:
                    column += 1

        while index < len(text):
            char = text[index]
            start_line = line
            start_col = column
            start = index

            if char.isspace():
                advance(char)
                index += 1
                continue

            if text.startswith("#*", index):
                close = text.find("*#", index + 2)
                if close == -1:
                    diagnostics.append(
                        Diagnostic(
                            "lexico",
                            "comentario multilinea no cerrado; agrega *#.",
                            start_line,
                            start_col,
                            start,
                            len(text),
                            {"*#"},
                        )
                    )
                    advance(text[index:])
                    break
                fragment = text[index:close + 2]
                advance(fragment)
                index = close + 2
                continue

            if char == "#":
                end = text.find("\n", index)
                fragment = text[index:] if end == -1 else text[index:end]
                advance(fragment)
                index += len(fragment)
                continue

            if text.startswith("@secure", index):
                lexeme = "@secure"
                tokens.append(Token("SECURE", lexeme, start_line, start_col, start, start + len(lexeme)))
                advance(lexeme)
                index += len(lexeme)
                continue

            string_match = re.match(r'"(?:\\[btnr"\'\\]|[^"\\\r\n])*"?', text[index:])
            if char == '"':
                lexeme = string_match.group(0) if string_match else char
                kind = "STRING_LITERAL" if lexeme.endswith('"') and len(lexeme) > 1 else "ERROR"
                tokens.append(Token(kind, lexeme, start_line, start_col, start, start + len(lexeme)))
                if kind == "ERROR":
                    diagnostics.append(Diagnostic("lexico", "string sin comilla de cierre.", start_line, start_col, start, start + len(lexeme), {'"'}))
                advance(lexeme)
                index += len(lexeme)
                continue

            char_match = re.match(r"'(?:\\[btnr\"'\\]|[^'\\\r\n])'?", text[index:])
            if char == "'":
                lexeme = char_match.group(0) if char_match else char
                kind = "CHAR_LITERAL" if lexeme.endswith("'") and len(lexeme) > 2 else "ERROR"
                tokens.append(Token(kind, lexeme, start_line, start_col, start, start + len(lexeme)))
                if kind == "ERROR":
                    diagnostics.append(Diagnostic("lexico", "literal char sin cierre.", start_line, start_col, start, start + len(lexeme), {"'"}))
                advance(lexeme)
                index += len(lexeme)
                continue

            number_match = re.match(r"0[xX][0-9a-fA-F]+|[0-9]+\.[0-9]+|[0-9]+", text[index:])
            if number_match:
                lexeme = number_match.group(0)
                if lexeme.lower().startswith("0x"):
                    kind = "HEX_LITERAL"
                elif "." in lexeme:
                    kind = "REAL_LITERAL"
                else:
                    kind = "INT_LITERAL"
                tokens.append(Token(kind, lexeme, start_line, start_col, start, start + len(lexeme)))
                advance(lexeme)
                index += len(lexeme)
                continue

            identifier_match = re.match(r"[A-Za-z_][A-Za-z_0-9]*", text[index:])
            if identifier_match:
                lexeme = identifier_match.group(0)
                kind = KEYWORDS.get(lexeme, "IDENTIFIER")
                tokens.append(Token(kind, lexeme, start_line, start_col, start, start + len(lexeme)))
                advance(lexeme)
                index += len(lexeme)
                continue

            matched_op = None
            for op in sorted(OPERATORS, key=len, reverse=True):
                if text.startswith(op, index):
                    matched_op = op
                    break
            if matched_op is not None:
                tokens.append(Token(OPERATORS[matched_op], matched_op, start_line, start_col, start, start + len(matched_op)))
                advance(matched_op)
                index += len(matched_op)
                continue

            diagnostics.append(
                Diagnostic(
                    "lexico",
                    f'el simbolo "{char}" no pertenece al lenguaje FCC.',
                    start_line,
                    start_col,
                    start,
                    start + 1,
                )
            )
            advance(char)
            index += 1

        tokens.append(Token(EOF, "", line, column, len(text), len(text)))
        return tokens, diagnostics


class LL1Grammar:
    """Gramatica LL(1) resumida para explicar y guiar el IDE."""

    def __init__(self):
        self.start = "program"
        self.productions: Dict[str, List[List[str]]] = {
            "program": [["top_decl", "program"], [EPSILON]],
            "top_decl": [["import_stmt"], ["secure_function"], ["function_decl"], ["var_decl"]],
            "import_stmt": [["TRAIGASE", "STRING_LITERAL"]],
            "secure_function": [["SECURE", "LPAREN", "HEX_LITERAL", "RPAREN", "function_decl"]],
            "function_decl": [["FUNC", "type", "function_name", "LPAREN", "params_opt", "RPAREN", "block"]],
            "function_name": [["IDENTIFIER"], ["MAIN"]],
            "params_opt": [["parameter", "params_tail"], [EPSILON]],
            "params_tail": [["COMMA", "parameter", "params_tail"], [EPSILON]],
            "parameter": [["type", "IDENTIFIER"]],
            "var_decl": [["type", "declarators", "SEMI"]],
            "declarators": [["declarator", "declarators_tail"]],
            "declarators_tail": [["COMMA", "declarator", "declarators_tail"], [EPSILON]],
            "declarator": [["IDENTIFIER", "array_tail", "initializer_opt"]],
            "initializer_opt": [["ASSIGN", "expression"], [EPSILON]],
            "type": [["base_type", "pointer_tail", "array_tail"]],
            "base_type": [["INT"], ["FLOAT"], ["BOOL"], ["CHAR"], ["VOID"], ["VAULT", "LBRACK", "INT_LITERAL", "RBRACK"]],
            "pointer_tail": [["STAR", "pointer_tail"], [EPSILON]],
            "array_tail": [["LBRACK", "array_bound", "RBRACK", "array_tail"], [EPSILON]],
            "array_bound": [["expression"], [EPSILON]],
            "block": [["LBRACE", "statement_list", "RBRACE"]],
            "statement_list": [["statement", "statement_list"], [EPSILON]],
            "statement": [["var_decl"], ["assignment_stmt"], ["if_stmt"], ["while_stmt"], ["for_stmt"], ["return_stmt"], ["continue_stmt"], ["break_stmt"], ["expr_stmt"], ["block"]],
            "assignment_stmt": [["assignable", "assignment_operator", "expression", "SEMI"]],
            "assignable": [["postfix"]],
            "assignment_operator": [["ASSIGN"], ["PLUS_ASSIGN"], ["MINUS_ASSIGN"], ["STAR_ASSIGN"], ["SLASH_ASSIGN"], ["PERCENT_ASSIGN"], ["AND_ASSIGN"], ["OR_ASSIGN"], ["XOR_ASSIGN"]],
            "return_stmt": [["RET", "expression_opt", "SEMI"]],
            "continue_stmt": [["CONTINUE", "SEMI"]],
            "break_stmt": [["BREAK", "SEMI"]],
            "expr_stmt": [["expression", "SEMI"]],
            "if_stmt": [["IF", "LPAREN", "expression", "RPAREN", "block", "elif_tail", "else_opt"]],
            "elif_tail": [["ELIF", "LPAREN", "expression", "RPAREN", "block", "elif_tail"], [EPSILON]],
            "else_opt": [["ELSE", "block"], [EPSILON]],
            "while_stmt": [["WHILE", "LPAREN", "expression", "RPAREN", "block"]],
            "for_stmt": [["FOR", "LPAREN", "for_initializer", "SEMI", "assignment_stmt_no_semi", "SEMI", "expression", "RPAREN", "block"]],
            "for_initializer": [["var_decl_no_semi"], ["assignment_stmt_no_semi"]],
            "var_decl_no_semi": [["type", "declarators"]],
            "assignment_stmt_no_semi": [["assignable", "assignment_operator", "expression"]],
            "expression_opt": [["expression"], [EPSILON]],
            "expression": [["bitwise_or"]],
            "bitwise_or": [["bitwise_xor", "bitwise_or_tail"]],
            "bitwise_or_tail": [["OR", "bitwise_xor", "bitwise_or_tail"], [EPSILON]],
            "bitwise_xor": [["bitwise_and", "bitwise_xor_tail"]],
            "bitwise_xor_tail": [["XOR", "bitwise_and", "bitwise_xor_tail"], [EPSILON]],
            "bitwise_and": [["equality", "bitwise_and_tail"]],
            "bitwise_and_tail": [["AMPERSAND", "equality", "bitwise_and_tail"], [EPSILON]],
            "equality": [["relational", "equality_tail"]],
            "equality_tail": [["EQ", "relational", "equality_tail"], ["NEQ", "relational", "equality_tail"], [EPSILON]],
            "relational": [["shift", "relational_tail"]],
            "relational_tail": [["LT", "shift", "relational_tail"], ["LE", "shift", "relational_tail"], ["GT", "shift", "relational_tail"], ["GE", "shift", "relational_tail"], [EPSILON]],
            "shift": [["additive", "shift_tail"]],
            "shift_tail": [["SHIFT_LEFT", "additive", "shift_tail"], ["SHIFT_RIGHT", "additive", "shift_tail"], [EPSILON]],
            "additive": [["multiplicative", "additive_tail"]],
            "additive_tail": [["PLUS", "multiplicative", "additive_tail"], ["MINUS", "multiplicative", "additive_tail"], [EPSILON]],
            "multiplicative": [["unary", "multiplicative_tail"]],
            "multiplicative_tail": [["STAR", "unary", "multiplicative_tail"], ["SLASH", "unary", "multiplicative_tail"], ["PERCENT", "unary", "multiplicative_tail"], ["POWER", "unary", "multiplicative_tail"], [EPSILON]],
            "unary": [["NOT", "unary"], ["MINUS", "unary"], ["AMPERSAND", "unary"], ["STAR", "unary"], ["postfix"]],
            "postfix": [["primary", "postfix_tail"]],
            "postfix_tail": [["LPAREN", "arguments_opt", "RPAREN", "postfix_tail"], ["LBRACK", "expression", "RBRACK", "postfix_tail"], ["DOT", "IDENTIFIER", "postfix_tail"], [EPSILON]],
            "arguments_opt": [["expression", "arguments_tail"], [EPSILON]],
            "arguments_tail": [["COMMA", "expression", "arguments_tail"], [EPSILON]],
            "primary": [["IDENTIFIER"], ["MAIN"], ["literal"], ["LPAREN", "expression", "RPAREN"]],
            "literal": [["INT_LITERAL"], ["REAL_LITERAL"], ["HEX_LITERAL"], ["STRING_LITERAL"], ["CHAR_LITERAL"], ["TRUE"], ["FALSE"]],
        }
        self.nonterminals = set(self.productions)
        self.terminals = {
            symbol
            for alternatives in self.productions.values()
            for production in alternatives
            for symbol in production
            if symbol not in self.nonterminals and symbol != EPSILON
        }
        self.first_sets = self._compute_first_sets()
        self.follow_sets = self._compute_follow_sets()

    def _first_of_sequence(self, symbols: Sequence[str]) -> Set[str]:
        result: Set[str] = set()
        if not symbols:
            return {EPSILON}
        for symbol in symbols:
            if symbol == EPSILON:
                result.add(EPSILON)
                break
            if symbol not in self.nonterminals:
                result.add(symbol)
                break
            result.update(self.first_sets[symbol] - {EPSILON})
            if EPSILON not in self.first_sets[symbol]:
                break
        else:
            result.add(EPSILON)
        return result

    def _compute_first_sets(self) -> Dict[str, Set[str]]:
        first = {nonterminal: set() for nonterminal in self.nonterminals}
        changed = True
        while changed:
            changed = False
            for nonterminal, alternatives in self.productions.items():
                for production in alternatives:
                    before = len(first[nonterminal])
                    if production == [EPSILON]:
                        first[nonterminal].add(EPSILON)
                    else:
                        nullable = True
                        for symbol in production:
                            if symbol not in self.nonterminals:
                                first[nonterminal].add(symbol)
                                nullable = False
                                break
                            first[nonterminal].update(first[symbol] - {EPSILON})
                            if EPSILON not in first[symbol]:
                                nullable = False
                                break
                        if nullable:
                            first[nonterminal].add(EPSILON)
                    changed = changed or len(first[nonterminal]) != before
        return first

    def _compute_follow_sets(self) -> Dict[str, Set[str]]:
        follow = {nonterminal: set() for nonterminal in self.nonterminals}
        follow[self.start].add(EOF)
        changed = True
        while changed:
            changed = False
            for nonterminal, alternatives in self.productions.items():
                for production in alternatives:
                    trailer = set(follow[nonterminal])
                    for symbol in reversed(production):
                        if symbol in self.nonterminals:
                            before = len(follow[symbol])
                            follow[symbol].update(trailer)
                            changed = changed or len(follow[symbol]) != before
                            if EPSILON in self.first_sets[symbol]:
                                trailer.update(self.first_sets[symbol] - {EPSILON})
                            else:
                                trailer = set(self.first_sets[symbol])
                        elif symbol != EPSILON:
                            trailer = {symbol}
        return follow

    def expected_for(self, nonterminal: str) -> Set[str]:
        expected = set(self.first_sets.get(nonterminal, set()))
        if EPSILON in expected:
            expected.remove(EPSILON)
            expected.update(self.follow_sets.get(nonterminal, set()))
        return expected


class PredictiveParser:
    """Parser descendente predictivo con recuperacion simple por FOLLOW."""

    def __init__(self, tokens: List[Token], grammar: LL1Grammar):
        self.tokens = tokens
        self.grammar = grammar
        self.pos = 0
        self.diagnostics: List[Diagnostic] = []
        self.expected_at_cursor: Set[str] = set()

    @property
    def current(self) -> Token:
        return self.tokens[min(self.pos, len(self.tokens) - 1)]

    def parse(self):
        self._parse_program()
        if self.current.kind != EOF:
            self._error("EOF", "fin de archivo")
        return self.diagnostics

    def _at(self, *kinds: str) -> bool:
        return self.current.kind in kinds

    def _consume(self, kind: str, description: Optional[str] = None) -> bool:
        if self.current.kind == kind:
            self.pos += 1
            return True
        self._error(kind, description or DISPLAY_BY_TOKEN.get(kind, kind))
        return False

    def _error(self, expected: Iterable[str] | str, description: str = ""):
        expected_set = {expected} if isinstance(expected, str) else set(expected)
        token = self.current
        if token.kind == EOF and expected_set:
            self.expected_at_cursor.update(expected_set)
        expected_text = ", ".join(DISPLAY_BY_TOKEN.get(item, item) for item in sorted(expected_set))
        if description:
            message = f"se esperaba {description}."
        else:
            message = f"se esperaba uno de: {expected_text}."
        if token.kind != EOF:
            message += f' Token recibido: "{token.lexeme}".'
        self.diagnostics.append(Diagnostic("LL(1)", message, token.line, token.column, token.start, max(token.end, token.start + 1), expected_set))

    def _synchronize(self, follow: Set[str]):
        while self.current.kind not in follow and self.current.kind != EOF:
            self.pos += 1

    def _parse_program(self):
        while self.current.kind != EOF:
            if self.current.kind in {"TRAIGASE", "SECURE", "FUNC", *TYPE_TOKENS}:
                self._parse_top_decl()
            else:
                self._error(self.grammar.expected_for("top_decl"))
                self._synchronize({"TRAIGASE", "SECURE", "FUNC", *TYPE_TOKENS, EOF})

    def _parse_top_decl(self):
        if self._at("TRAIGASE"):
            self._consume("TRAIGASE")
            self._consume("STRING_LITERAL", "ruta de import")
            return
        if self._at("SECURE"):
            self._consume("SECURE")
            self._consume("LPAREN")
            self._consume("HEX_LITERAL", "literal hexadecimal")
            self._consume("RPAREN")
            self._parse_function_decl()
            return
        if self._at("FUNC"):
            self._parse_function_decl()
            return
        self._parse_var_decl(require_semicolon=True)

    def _parse_function_decl(self):
        self._consume("FUNC")
        self._parse_type()
        if not self._at("IDENTIFIER", "MAIN"):
            self._error({"IDENTIFIER", "MAIN"}, "nombre de funcion")
        else:
            self.pos += 1
        self._consume("LPAREN")
        if not self._at("RPAREN", EOF):
            self._parse_parameter()
            while self._at("COMMA"):
                self._consume("COMMA")
                self._parse_parameter()
        self._consume("RPAREN")
        self._parse_block()

    def _parse_parameter(self):
        self._parse_type()
        self._consume("IDENTIFIER", "nombre de parametro")

    def _parse_type(self):
        if not self._at(*TYPE_TOKENS):
            self._error(TYPE_TOKENS, "tipo")
            return
        if self._at("VAULT"):
            self._consume("VAULT")
            self._consume("LBRACK")
            self._consume("INT_LITERAL", "tamano de vault")
            self._consume("RBRACK")
        else:
            self.pos += 1
        while self._at("STAR"):
            self.pos += 1
        self._parse_array_tail()

    def _parse_array_tail(self):
        while self._at("LBRACK"):
            self._consume("LBRACK")
            if not self._at("RBRACK"):
                self._parse_expression()
            self._consume("RBRACK")

    def _parse_var_decl(self, require_semicolon: bool):
        self._parse_type()
        self._parse_declarator()
        while self._at("COMMA"):
            self._consume("COMMA")
            self._parse_declarator()
        if require_semicolon:
            self._consume("SEMI", "punto y coma")

    def _parse_declarator(self):
        self._consume("IDENTIFIER", "nombre de variable")
        self._parse_array_tail()
        if self._at("ASSIGN"):
            self._consume("ASSIGN")
            self._parse_expression()

    def _parse_block(self):
        self._consume("LBRACE")
        while self.current.kind not in {"RBRACE", EOF}:
            self._parse_statement()
        self._consume("RBRACE")

    def _parse_statement(self):
        if self._at(*TYPE_TOKENS):
            self._parse_var_decl(require_semicolon=True)
            return
        if self._at("IF"):
            self._parse_if()
            return
        if self._at("WHILE"):
            self._parse_while()
            return
        if self._at("FOR"):
            self._parse_for()
            return
        if self._at("RET"):
            self._consume("RET")
            if not self._at("SEMI"):
                self._parse_expression()
            self._consume("SEMI", "punto y coma")
            return
        if self._at("CONTINUE", "BREAK"):
            self.pos += 1
            self._consume("SEMI", "punto y coma")
            return
        if self._at("LBRACE"):
            self._parse_block()
            return
        if self.current.kind in EXPRESSION_START:
            self._parse_expression()
            if self._at(
                "ASSIGN", "PLUS_ASSIGN", "MINUS_ASSIGN", "STAR_ASSIGN", "SLASH_ASSIGN",
                "PERCENT_ASSIGN", "AND_ASSIGN", "OR_ASSIGN", "XOR_ASSIGN",
            ):
                self.pos += 1
                self._parse_expression()
            self._consume("SEMI", "punto y coma")
            return
        self._error(STATEMENT_START, "sentencia")
        self._synchronize({"SEMI", "RBRACE", EOF})
        if self._at("SEMI"):
            self.pos += 1

    def _parse_if(self):
        self._consume("IF")
        self._consume("LPAREN")
        self._parse_expression()
        self._consume("RPAREN")
        self._parse_block()
        while self._at("ELIF"):
            self._consume("ELIF")
            self._consume("LPAREN")
            self._parse_expression()
            self._consume("RPAREN")
            self._parse_block()
        if self._at("ELSE"):
            self._consume("ELSE")
            self._parse_block()

    def _parse_while(self):
        self._consume("WHILE")
        self._consume("LPAREN")
        self._parse_expression()
        self._consume("RPAREN")
        self._parse_block()

    def _parse_for(self):
        self._consume("FOR")
        self._consume("LPAREN")
        if self._at(*TYPE_TOKENS):
            self._parse_var_decl(require_semicolon=False)
        else:
            self._parse_expression()
            if not self._at("ASSIGN", "PLUS_ASSIGN", "MINUS_ASSIGN", "STAR_ASSIGN", "SLASH_ASSIGN", "PERCENT_ASSIGN", "AND_ASSIGN", "OR_ASSIGN", "XOR_ASSIGN"):
                self._error(self.grammar.expected_for("assignment_operator"), "operador de asignacion")
            else:
                self.pos += 1
            self._parse_expression()
        self._consume("SEMI")
        self._parse_expression()
        if not self._at("ASSIGN", "PLUS_ASSIGN", "MINUS_ASSIGN", "STAR_ASSIGN", "SLASH_ASSIGN", "PERCENT_ASSIGN", "AND_ASSIGN", "OR_ASSIGN", "XOR_ASSIGN"):
            self._error(self.grammar.expected_for("assignment_operator"), "operador de asignacion")
        else:
            self.pos += 1
        self._parse_expression()
        self._consume("SEMI")
        self._parse_expression()
        self._consume("RPAREN")
        self._parse_block()

    def _parse_expression(self, min_precedence: int = 0):
        if self._at("NOT", "MINUS", "AMPERSAND", "STAR"):
            self.pos += 1
            self._parse_expression(8)
        else:
            self._parse_primary()

        precedence = {
            "OR": 1,
            "XOR": 2,
            "AMPERSAND": 3,
            "EQ": 4,
            "NEQ": 4,
            "LT": 5,
            "LE": 5,
            "GT": 5,
            "GE": 5,
            "SHIFT_LEFT": 6,
            "SHIFT_RIGHT": 6,
            "PLUS": 7,
            "MINUS": 7,
            "STAR": 8,
            "SLASH": 8,
            "PERCENT": 8,
            "POWER": 8,
        }

        while self.current.kind in precedence and precedence[self.current.kind] >= min_precedence:
            op_precedence = precedence[self.current.kind]
            self.pos += 1
            self._parse_expression(op_precedence + 1)

    def _parse_primary(self):
        if self._at("IDENTIFIER", "MAIN", *LITERAL_TOKENS):
            self.pos += 1
        elif self._at("LPAREN"):
            self._consume("LPAREN")
            self._parse_expression()
            self._consume("RPAREN")
        else:
            self._error(self.grammar.expected_for("primary"), "expresion")
            return

        while self._at("LPAREN", "LBRACK", "DOT"):
            if self._at("LPAREN"):
                self._consume("LPAREN")
                if not self._at("RPAREN"):
                    self._parse_expression()
                    while self._at("COMMA"):
                        self._consume("COMMA")
                        self._parse_expression()
                self._consume("RPAREN")
            elif self._at("LBRACK"):
                self._consume("LBRACK")
                self._parse_expression()
                self._consume("RBRACK")
            else:
                self._consume("DOT")
                self._consume("IDENTIFIER", "miembro")


class BottomUpAnalyzer:
    """Analisis ascendente de pares y reducciones pequenas de sentencias."""

    PAIRS = {"LPAREN": "RPAREN", "LBRACK": "RBRACK", "LBRACE": "RBRACE"}
    REVERSE = {value: key for key, value in PAIRS.items()}

    def analyze(self, text: str, tokens: List[Token]) -> Tuple[List[Diagnostic], List[Correction]]:
        diagnostics: List[Diagnostic] = []
        corrections: List[Correction] = []
        stack: List[Token] = []

        for token in tokens:
            if token.kind == EOF:
                continue
            if token.kind in self.PAIRS:
                stack.append(token)
                continue
            if token.kind in self.REVERSE:
                if stack and stack[-1].kind == self.REVERSE[token.kind]:
                    stack.pop()
                    continue
                opener = DISPLAY_BY_TOKEN.get(self.REVERSE[token.kind], self.REVERSE[token.kind])
                diagnostics.append(
                    Diagnostic(
                        "ascendente",
                        f'cierre "{token.lexeme}" sin apertura compatible; se esperaba abrir con {opener}.',
                        token.line,
                        token.column,
                        token.start,
                        token.end,
                        {self.REVERSE[token.kind]},
                    )
                )
                corrections.append(Correction("Eliminar cierre sobrante", f'Quita "{token.lexeme}".', token.start, token.end, ""))

        for opener in reversed(stack):
            closer = self.PAIRS[opener.kind]
            display = DISPLAY_BY_TOKEN.get(closer, closer)
            diagnostics.append(
                Diagnostic(
                    "ascendente",
                    f'falta cerrar "{opener.lexeme}" con {display}.',
                    opener.line,
                    opener.column,
                    opener.start,
                    opener.end,
                    {closer},
                )
            )
            corrections.append(Correction(f"Agregar {display}", f'Inserta {display} al final del archivo.', len(text), len(text), DISPLAY_BY_TOKEN.get(closer, "")))

        corrections.extend(self._missing_semicolon_corrections(text, tokens, diagnostics))
        return diagnostics, corrections

    def _missing_semicolon_corrections(self, text: str, tokens: List[Token], diagnostics: List[Diagnostic]) -> List[Correction]:
        corrections: List[Correction] = []
        by_line: Dict[int, List[Token]] = {}
        for token in tokens:
            if token.kind != EOF:
                by_line.setdefault(token.line, []).append(token)

        line_starts = [0]
        for match in re.finditer("\n", text):
            line_starts.append(match.end())

        starters_requiring_semicolon = {"RET", "CONTINUE", "BREAK", "IDENTIFIER", "MAIN", *TYPE_TOKENS}
        no_semicolon_end = {"SEMI", "LBRACE", "RBRACE", "COMMA", "LPAREN", "ASSIGN", "PLUS_ASSIGN", "MINUS_ASSIGN", "STAR_ASSIGN", "SLASH_ASSIGN", "PERCENT_ASSIGN", "AND_ASSIGN", "OR_ASSIGN", "XOR_ASSIGN"}

        for line_no, line_tokens in by_line.items():
            first = line_tokens[0]
            last = line_tokens[-1]
            if first.kind not in starters_requiring_semicolon:
                continue
            if last.kind in no_semicolon_end:
                continue
            if first.kind in TYPE_TOKENS and any(token.kind == "LPAREN" for token in line_tokens):
                continue
            if first.kind == "FUNC":
                continue
            if last.kind in {"RPAREN", "RBRACK", "IDENTIFIER", "MAIN", "RET", "CONTINUE", "BREAK", *LITERAL_TOKENS}:
                diagnostics.append(
                    Diagnostic(
                        "ascendente",
                        'posible falta de ";" al final de la sentencia.',
                        last.line,
                        last.column,
                        last.start,
                        last.end,
                        {"SEMI"},
                    )
                )
                corrections.append(Correction('Agregar ";"', f"Agrega punto y coma al final de la linea {line_no}.", last.end, last.end, ";"))

        return corrections


class FCCIDEAnalyzer:
    """Fachada usada por la interfaz grafica."""

    def __init__(self):
        self.lexer = FCCInteractiveLexer()
        self.grammar = LL1Grammar()
        self.bottom_up = BottomUpAnalyzer()

    def analyze(self, text: str, cursor_offset: int = 0) -> AnalysisResult:
        tokens, lexical_diagnostics = self.lexer.tokenize(text)
        parser = PredictiveParser(tokens, self.grammar)
        syntactic_diagnostics = parser.parse()
        bottom_up_diagnostics, corrections = self.bottom_up.analyze(text, tokens)
        diagnostics = lexical_diagnostics + syntactic_diagnostics + bottom_up_diagnostics
        suggestions = self._suggest(text, tokens, cursor_offset, parser.expected_at_cursor)

        return AnalysisResult(
            tokens=tokens,
            diagnostics=diagnostics,
            suggestions=suggestions,
            corrections=corrections,
            first_sets=self.grammar.first_sets,
            follow_sets=self.grammar.follow_sets,
        )

    def _suggest(self, text: str, tokens: List[Token], cursor_offset: int, expected: Set[str]) -> List[Suggestion]:
        prefix_match = re.search(r"[A-Za-z_][A-Za-z_0-9]*$", text[:cursor_offset])
        prefix = prefix_match.group(0) if prefix_match else ""
        tokens_before = [token for token in tokens if token.end <= cursor_offset and token.kind != EOF]
        previous = tokens_before[-1] if tokens_before else None

        candidates: Set[str] = set()
        candidates.update(
            {
                "func",
                "main",
                "void",
                "int",
                "float",
                "bool",
                "char",
                "vault",
                "if",
                "elif",
                "else",
                "for",
                "while",
                "ret",
                "continue",
                "break",
                "traigase",
                "@secure",
                "true",
                "false",
                "data_mem",
                "zero",
                "delta",
                "max",
            }
        )
        if expected:
            candidates.update(DISPLAY_BY_TOKEN.get(kind, kind) for kind in expected if kind != EOF)
        if previous is None or previous.kind in {"SEMI", "LBRACE", "RBRACE"}:
            candidates.update(
                [
                    "func void main(){\n    \n}",
                    "func int nombre(){\n    ret 0;\n}",
                    "if (){\n    \n}",
                    "while (){\n    \n}",
                    "for (int i = 0; i += 1; i < 10){\n    \n}",
                ]
            )
        elif previous.kind == "FUNC":
            candidates.update(["int", "float", "bool", "char", "void"])
        elif previous.kind in TYPE_TOKENS:
            candidates.update(["main", "nombre_variable", "nombre_funcion"])
        elif previous.kind in {"IF", "WHILE"}:
            candidates.add("(")
        elif previous.kind == "RET":
            candidates.update(self._known_identifiers(tokens))
        else:
            candidates.update(self._known_identifiers(tokens))
            candidates.update(["true", "false"])

        if prefix:
            candidates.discard(prefix)

        filtered = sorted(
            candidate
            for candidate in candidates
            if candidate and (not prefix or candidate.startswith(prefix) or candidate == "identificador")
        )
        return [Suggestion(candidate, self._suggestion_detail(candidate)) for candidate in filtered[:32]]

    def _known_identifiers(self, tokens: List[Token]) -> Set[str]:
        identifiers = {token.lexeme for token in tokens if token.kind in {"IDENTIFIER", "MAIN"}}
        return {name for name in identifiers if name}

    def _suggestion_detail(self, candidate: str) -> str:
        snippets = {
            "main": "funcion principal",
            "void": "tipo sin retorno",
            "int": "tipo entero",
            "float": "tipo real",
            "bool": "tipo booleano",
            "char": "tipo caracter",
            "vault": "memoria segura",
            "@secure": "anotacion secure",
            "data_mem": "memoria de datos",
            "func": "declarar funcion",
            "func void main(){\n    \n}": "plantilla main",
            "func int nombre(){\n    ret 0;\n}": "plantilla funcion int",
            "if": "bloque condicional",
            "if (){\n    \n}": "plantilla if",
            "while": "ciclo while",
            "while (){\n    \n}": "plantilla while",
            "for": "ciclo for",
            "for (int i = 0; i += 1; i < 10){\n    \n}": "plantilla for",
            "ret": "retornar valor",
            "traigase": "importar archivo .f",
            ";": "terminar sentencia",
            "}": "cerrar bloque",
            ")": "cerrar parentesis",
        }
        return snippets.get(candidate, "sugerencia LL(1)")
