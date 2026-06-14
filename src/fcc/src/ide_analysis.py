from __future__ import annotations

from dataclasses import dataclass, field
import re
from typing import Dict, Iterable, List, Sequence, Set, Tuple


EPSILON = "EPSILON"
EOF = "EOF"


@dataclass
class Token:
    """Token del IDE. Entradas: tipo/texto/posicion. Salida: unidad lexica. Uso: lexer, parser y UI."""

    kind: str
    lexeme: str
    line: int
    column: int
    start: int
    end: int


@dataclass
class Diagnostic:
    """Diagnostico. Entradas: fase, mensaje y rango. Salida: error visual. Uso: IDE."""

    phase: str
    message: str
    line: int
    column: int
    start: int
    end: int
    expected: Set[str] = field(default_factory=set)


@dataclass
class Suggestion:
    """Sugerencia. Entradas: texto y detalle. Salida: item del popup. Uso: IDE."""

    text: str
    detail: str = ""


@dataclass
class Correction:
    """Correccion automatica. Entradas: rango/reemplazo. Salida: edicion. Uso: IDE."""

    title: str
    detail: str
    start: int
    end: int
    replacement: str


@dataclass
class AnalysisResult:
    """Resultado del analisis. Entradas: productos de fases. Salida: paquete para UI. Uso: ide_app."""

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
    """Lexer tolerante.

    Entradas: texto parcial .f.
    Salida: tokens y diagnosticos lexicos.
    Uso: FCCIDEAnalyzer.analyze.
    """

    def tokenize(self, text: str) -> Tuple[List[Token], List[Diagnostic]]:
        """Entradas: codigo fuente. Salida: tokens/diagnosticos. Uso: IDE."""
        tokens: List[Token] = []
        diagnostics: List[Diagnostic] = []
        index = 0
        line = 1
        column = 0

        def advance(fragment: str):
            """Entradas: fragmento consumido. Salida: actualiza linea/columna. Uso: tokenize."""
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
                # Espacios solo actualizan posicion, no generan token.
                advance(char)
                index += 1
                continue

            # Comentario multilinea: si no cierra, se reporta y se consume el resto.
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

            # Comentario de linea: no produce tokens.
            if char == "#":
                end = text.find("\n", index)
                fragment = text[index:] if end == -1 else text[index:end]
                advance(fragment)
                index += len(fragment)
                continue

            # @secure se tokeniza antes que identificadores por iniciar con @.
            if text.startswith("@secure", index):
                lexeme = "@secure"
                tokens.append(Token("SECURE", lexeme, start_line, start_col, start, start + len(lexeme)))
                advance(lexeme)
                index += len(lexeme)
                continue

            # Strings incompletos tambien se tokenizan para poder subrayarlos.
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

            # Chars incompletos generan diagnostico lexico recuperable.
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

            # El orden permite distinguir hex, reales y enteros.
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

            # Palabras reservadas y nombres comparten patron.
            identifier_match = re.match(r"[A-Za-z_][A-Za-z_0-9]*", text[index:])
            if identifier_match:
                lexeme = identifier_match.group(0)
                kind = KEYWORDS.get(lexeme, "IDENTIFIER")
                tokens.append(Token(kind, lexeme, start_line, start_col, start, start + len(lexeme)))
                advance(lexeme)
                index += len(lexeme)
                continue

            # Se prueban operadores largos antes de los cortos: >= antes de >.
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
        # EOF da un punto estable para sugerencias al final del texto.
        return tokens, diagnostics


class LL1Grammar:
    """Gramatica LL(1).

    Entradas: producciones internas.
    Salida: FIRST, FOLLOW y tabla predictiva.
    Uso: PredictiveParser y sugerencias.
    """

    def __init__(self):
        """Entradas: ninguna. Salida: gramatica calculada. Uso: FCCIDEAnalyzer."""
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
            "statement": [["var_decl"], ["if_stmt"], ["while_stmt"], ["for_stmt"], ["return_stmt"], ["continue_stmt"], ["break_stmt"], ["simple_stmt"], ["block"]],
            "simple_stmt": [["expression", "simple_stmt_tail"]],
            "simple_stmt_tail": [["assignment_operator", "expression", "SEMI"], ["SEMI"]],
            "assignment_operator": [["ASSIGN"], ["PLUS_ASSIGN"], ["MINUS_ASSIGN"], ["STAR_ASSIGN"], ["SLASH_ASSIGN"], ["PERCENT_ASSIGN"], ["AND_ASSIGN"], ["OR_ASSIGN"], ["XOR_ASSIGN"]],
            "return_stmt": [["RET", "expression_opt", "SEMI"]],
            "continue_stmt": [["CONTINUE", "SEMI"]],
            "break_stmt": [["BREAK", "SEMI"]],
            "if_stmt": [["IF", "LPAREN", "expression", "RPAREN", "block", "elif_tail", "else_opt"]],
            "elif_tail": [["ELIF", "LPAREN", "expression", "RPAREN", "block", "elif_tail"], [EPSILON]],
            "else_opt": [["ELSE", "block"], [EPSILON]],
            "while_stmt": [["WHILE", "LPAREN", "expression", "RPAREN", "block"]],
            "for_stmt": [["FOR", "LPAREN", "for_initializer", "SEMI", "assignment_stmt_no_semi", "SEMI", "expression", "RPAREN", "block"]],
            "for_initializer": [["var_decl_no_semi"], ["assignment_stmt_no_semi"]],
            "var_decl_no_semi": [["type", "declarators"]],
            "assignment_stmt_no_semi": [["expression", "assignment_operator", "expression"]],
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
        # Terminales: todo simbolo usado que no es no-terminal ni EPSILON.
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
        self.parse_table, self.conflicts = self._build_parse_table()

    def _first_of_sequence(self, symbols: Sequence[str]) -> Set[str]:
        """Entradas: simbolos. Salida: FIRST(secuencia). Uso: FOLLOW y tabla LL(1)."""

        result: Set[str] = set()
        if not symbols:
            return {EPSILON}
        for symbol in symbols:
            if symbol == EPSILON:
                # La secuencia completa puede ser vacia.
                result.add(EPSILON)
                break
            if symbol not in self.nonterminals:
                # Un terminal corta la busqueda: ya sabemos como inicia.
                result.add(symbol)
                break
            # Un no-terminal aporta sus posibles inicios.
            result.update(self.first_sets[symbol] - {EPSILON})
            if EPSILON not in self.first_sets[symbol]:
                # Si no es anulable, no se mira el siguiente simbolo.
                break
        else:
            # Todos los simbolos de la secuencia eran anulables.
            result.add(EPSILON)
        return result

    def _compute_first_sets(self) -> Dict[str, Set[str]]:
        """Entradas: producciones. Salida: FIRST por no-terminal. Uso: __init__."""

        first = {nonterminal: set() for nonterminal in self.nonterminals}
        changed = True
        while changed:
            # Se sale cuando una pasada completa no agrega nada nuevo.
            changed = False
            for nonterminal, alternatives in self.productions.items():
                for production in alternatives:
                    before = len(first[nonterminal])
                    if production == [EPSILON]:
                        # Produccion vacia: A puede desaparecer.
                        first[nonterminal].add(EPSILON)
                    else:
                        # Sigue al siguiente simbolo solo si el actual acepta EPSILON.
                        nullable = True
                        for symbol in production:
                            if symbol not in self.nonterminals:
                                # Un terminal al inicio pertenece directo a FIRST(A).
                                first[nonterminal].add(symbol)
                                nullable = False
                                break
                            # FIRST(B) aporta todo excepto EPSILON.
                            first[nonterminal].update(first[symbol] - {EPSILON})
                            if EPSILON not in first[symbol]:
                                nullable = False
                                break
                        if nullable:
                            # Toda la produccion puede desaparecer.
                            first[nonterminal].add(EPSILON)
                    # Si el conjunto crecio, otra pasada puede propagar el cambio.
                    changed = changed or len(first[nonterminal]) != before
        return first

    def _compute_follow_sets(self) -> Dict[str, Set[str]]:
        """Entradas: FIRST/producciones. Salida: FOLLOW por no-terminal. Uso: __init__."""

        follow = {nonterminal: set() for nonterminal in self.nonterminals}
        # EOF siempre puede seguir al simbolo inicial.
        follow[self.start].add(EOF)
        changed = True
        while changed:
            changed = False
            for nonterminal, alternatives in self.productions.items():
                for production in alternatives:
                    # Trailer representa lo que puede aparecer despues del simbolo actual.
                    trailer = set(follow[nonterminal])
                    for symbol in reversed(production):
                        if symbol in self.nonterminals:
                            before = len(follow[symbol])
                            # Lo que venia despues de A ahora puede seguir a este simbolo.
                            follow[symbol].update(trailer)
                            changed = changed or len(follow[symbol]) != before
                            if EPSILON in self.first_sets[symbol]:
                                # Si symbol es anulable, tambien deja pasar el trailer previo.
                                trailer.update(self.first_sets[symbol] - {EPSILON})
                            else:
                                # Si no es anulable, el nuevo trailer es FIRST(symbol).
                                trailer = set(self.first_sets[symbol])
                        elif symbol != EPSILON:
                            # Un terminal reinicia el trailer.
                            trailer = {symbol}
        return follow

    def expected_for(self, nonterminal: str) -> Set[str]:
        """Entradas: no-terminal. Salida: tokens esperables. Uso: sugerencias/diagnostico."""
        expected = set(self.first_sets.get(nonterminal, set()))
        if EPSILON in expected:
            expected.remove(EPSILON)
            expected.update(self.follow_sets.get(nonterminal, set()))
        return expected

    def _build_parse_table(self) -> Tuple[Dict[Tuple[str, str], List[str]], List[str]]:
        """Entradas: FIRST/FOLLOW. Salida: tabla LL(1) y conflictos. Uso: parser."""

        table: Dict[Tuple[str, str], List[str]] = {}
        conflicts: List[str] = []
        for nonterminal, alternatives in self.productions.items():
            for production in alternatives:
                first = self._first_of_sequence(production)
                # Producciones no anulables se indexan por su FIRST.
                lookaheads = set(first - {EPSILON})
                if EPSILON in first:
                    # Producciones anulables tambien se indexan por FOLLOW(A).
                    lookaheads.update(self.follow_sets[nonterminal])
                for lookahead in lookaheads:
                    key = (nonterminal, lookahead)
                    if key in table and table[key] != production:
                        # Un conflicto aqui indica que la gramatica no es LL(1).
                        conflicts.append(f"{nonterminal} con {lookahead}")
                        continue
                    table[key] = production
        return table, conflicts


class PredictiveParser:
    """Parser predictivo LL(1).

    Entradas: tokens y gramatica.
    Salida: diagnosticos y esperados en cursor.
    Uso: FCCIDEAnalyzer.analyze.
    """

    def __init__(self, tokens: List[Token], grammar: LL1Grammar):
        """Entradas: tokens/gramatica. Salida: parser listo. Uso: analyze."""
        self.tokens = tokens
        self.grammar = grammar
        self.pos = 0
        self.diagnostics: List[Diagnostic] = []
        self.expected_at_cursor: Set[str] = set()

    @property
    def current(self) -> Token:
        """Entradas: posicion actual. Salida: token seguro. Uso: parse/recuperacion."""
        return self.tokens[min(self.pos, len(self.tokens) - 1)]

    def parse(self):
        """Entradas: pila inicial LL(1). Salida: diagnosticos. Uso: FCCIDEAnalyzer."""
        stack = [EOF, self.grammar.start]
        while stack:
            top = stack.pop()
            lookahead = self.current.kind

            if top == EPSILON:
                # EPSILON no consume entrada.
                continue

            if top not in self.grammar.nonterminals:
                if top == lookahead:
                    # Terminal esperado: se consume token.
                    self.pos += 1
                    continue
                self._error({top})
                if lookahead == EOF:
                    break
                self._recover_terminal(top)
                continue

            production = self.grammar.parse_table.get((top, lookahead))
            if production is None:
                # Celda vacia en la tabla: error predictivo.
                self._error(self._expected_from_table(top))
                if lookahead == EOF:
                    break
                self._recover_nonterminal(top)
                continue

            # Aqui se usa la tabla predictiva M[no_terminal, lookahead].
            # La pila expande de derecha a izquierda.
            for symbol in reversed(production):
                if symbol != EPSILON:
                    stack.append(symbol)
        return self.diagnostics

    def _error(self, expected: Iterable[str] | str):
        """Entradas: esperados. Salida: agrega diagnostico. Uso: parse."""
        expected_set = {expected} if isinstance(expected, str) else set(expected)
        token = self.current
        if token.kind == EOF and expected_set:
            self.expected_at_cursor.update(expected_set)
        expected_text = ", ".join(DISPLAY_BY_TOKEN.get(item, item) for item in sorted(expected_set))
        message = f"se esperaba uno de: {expected_text}."
        if token.kind != EOF:
            message += f' Token recibido: "{token.lexeme}".'
        self.diagnostics.append(Diagnostic("LL(1)", message, token.line, token.column, token.start, max(token.end, token.start + 1), expected_set))

    def _expected_from_table(self, nonterminal: str) -> Set[str]:
        """Entradas: no-terminal. Salida: columnas validas LL(1). Uso: errores."""
        # Se listan las columnas validas de la fila del no-terminal.
        return {
            terminal
            for (row, terminal), _production in self.grammar.parse_table.items()
            if row == nonterminal
        }

    def _recover_terminal(self, terminal: str):
        """Entradas: terminal esperado. Salida: avanza o simula insercion. Uso: parse."""
        if self.current.kind == EOF:
            return
        # Simula insercion de cierres comunes; para otros tokens descarta entrada.
        if terminal in {"SEMI", "RPAREN", "RBRACE", "RBRACK"}:
            return
        # Avance panic-mode minimo para evitar ciclos infinitos.
        self.pos += 1

    def _recover_nonterminal(self, nonterminal: str):
        """Entradas: no-terminal. Salida: panic-mode local. Uso: parse."""
        if self.current.kind == EOF:
            return
        # Si el token actual pertenece al FOLLOW, se omite el no-terminal.
        if self.current.kind in self.grammar.follow_sets.get(nonterminal, set()):
            return
        self.pos += 1

class BottomUpAnalyzer:
    """Analisis ascendente local.

    Entradas: texto y tokens.
    Salida: diagnosticos/correcciones de pares y ';'.
    Uso: FCCIDEAnalyzer.analyze.
    """

    PAIRS = {"LPAREN": "RPAREN", "LBRACK": "RBRACK", "LBRACE": "RBRACE"}
    REVERSE = {value: key for key, value in PAIRS.items()}

    def analyze(self, text: str, tokens: List[Token]) -> Tuple[List[Diagnostic], List[Correction]]:
        """Entradas: texto/tokens. Salida: errores y correcciones. Uso: IDE."""
        diagnostics: List[Diagnostic] = []
        corrections: List[Correction] = []
        stack: List[Token] = []

        for token in tokens:
            if token.kind == EOF:
                continue
            if token.kind in self.PAIRS:
                # Aperturas pendientes: luego deben reducir con su cierre.
                stack.append(token)
                continue
            if token.kind in self.REVERSE:
                if stack and stack[-1].kind == self.REVERSE[token.kind]:
                    # Cierre compatible: reduce el par superior.
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
            # Si queda algo en la pila, falta insertar su cierre.
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
        """Entradas: texto/tokens/diagnosticos. Salida: correcciones ';'. Uso: analyze."""
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
                # La linea parece cerrada semanticamente, pero no tiene ';'.
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
    """Fachada del analizador del IDE.

    Entradas: texto y cursor.
    Salida: AnalysisResult para resaltado, errores y sugerencias.
    Uso: ide_app.FCCIDE.
    """

    def __init__(self):
        """Entradas: ninguna. Salida: fases listas. Uso: IDE."""
        self.lexer = FCCInteractiveLexer()
        self.grammar = LL1Grammar()
        self.bottom_up = BottomUpAnalyzer()

    def analyze(self, text: str, cursor_offset: int = 0) -> AnalysisResult:
        """Entradas: codigo y cursor. Salida: AnalysisResult. Uso: ide_app."""
        tokens, lexical_diagnostics = self.lexer.tokenize(text)
        parser = PredictiveParser(tokens, self.grammar)
        syntactic_diagnostics = parser.parse()
        bottom_up_diagnostics, corrections = self.bottom_up.analyze(text, tokens)
        # Las sugerencias mezclan contexto LL(1), prefijo e identificadores.
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
        """Entradas: contexto y esperados LL(1). Salida: sugerencias. Uso: analyze."""
        prefix_match = re.search(r"[A-Za-z_][A-Za-z_0-9]*$", text[:cursor_offset])
        prefix = prefix_match.group(0) if prefix_match else ""
        tokens_before = [token for token in tokens if token.end <= cursor_offset and token.kind != EOF]
        previous = tokens_before[-1] if tokens_before else None

        # Base amplia: keywords, builtins y plantillas comunes.
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
            # Tokens esperados por la tabla LL(1) cuando el cursor esta en EOF.
            candidates.update(DISPLAY_BY_TOKEN.get(kind, kind) for kind in expected if kind != EOF)
        if previous is None or previous.kind in {"SEMI", "LBRACE", "RBRACE"}:
            # Inicio de sentencia: conviene sugerir snippets completos.
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
            # En expresiones se priorizan nombres ya escritos y literales bool.
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
        """Entradas: tokens. Salida: identificadores conocidos. Uso: _suggest."""
        identifiers = {token.lexeme for token in tokens if token.kind in {"IDENTIFIER", "MAIN"}}
        return {name for name in identifiers if name}

    def _suggestion_detail(self, candidate: str) -> str:
        """Entradas: candidato. Salida: descripcion corta. Uso: _suggest."""
        snippets = {
            "main": "funcion principal",
            "void": "tipo sin retorno",
            "int": "tipo entero",
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
