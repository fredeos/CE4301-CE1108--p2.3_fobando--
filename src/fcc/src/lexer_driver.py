"""Driver del analisis lexico y utilidades para listar tokens."""

from pathlib import Path
import importlib.util
import sys

try:
    from antlr4 import FileStream, CommonTokenStream
except ModuleNotFoundError as exc:
    if exc.name == "antlr4":
        sys.exit(
            "Error: falta instalar antlr4-python3-runtime. "
            "Ejecuta: python -m pip install -r fcc/requirements.txt"
        )
    raise

PROJECT_ROOT = Path(__file__).resolve().parent.parent
GENERATED_LEXER_PATHS = (
    PROJECT_ROOT / "generated" / "grammar" / "FCCLexer.py",
    PROJECT_ROOT / "generated" / "fcc" / "grammar" / "FCCLexer.py",
)


def load_generated_lexer():
    """Carga dinamicamente el lexer generado por ANTLR."""

    for lexer_path in GENERATED_LEXER_PATHS:
        if not lexer_path.exists():
            continue

        spec = importlib.util.spec_from_file_location("FCCLexer", lexer_path)
        if spec is None or spec.loader is None:
            continue

        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        return module.FCCLexer

    expected_paths = "\n".join(f"  - {path}" for path in GENERATED_LEXER_PATHS)
    sys.exit(
        "Error: no se encontro FCCLexer.py generado. "
        "Rutas revisadas:\n"
        f"{expected_paths}"
    )


FCCLexer = load_generated_lexer()


def get_token_name(lexer, token_type):
    """Retorna el nombre simbolico de un token."""

    if token_type == -1:
        return "EOF"
    return lexer.symbolicNames[token_type]


def check_lexical_errors(token_stream, lexer):
    """Revisa si el stream contiene tokens marcados como errores lexicos."""

    for token in token_stream.tokens:
        if token.type == -1:
            continue

        token_name = get_token_name(lexer, token.type)

        if token_name == "UNCLOSED_BLOCK_COMMENT":
            print(
                f"Error [lexico] en linea {token.line}: comentario multilinea no cerrado."
            )
            return True

        if token_name == "INVALID_HASH_OPERATOR":
            print(
                f'Error [lexico] en linea {token.line}: operador "{token.text}" no reconocido.'
            )
            return True

        if token_name == "INVALID_REAL_LITERAL":
            print(
                f'Error [lexico] en linea {token.line}: numero real "{token.text}" mal formado.'
            )
            return True

        if token_name == "INVALID_OPERATOR":
            print(
                f'Error [lexico] en linea {token.line}: operador "{token.text}" no reconocido.'
            )
            return True

        if token_name == "ERROR_CHAR":
            print(
                f'Error [lexico] en linea {token.line}: el simbolo "{token.text}" no pertenece al lenguaje.'
            )
            return True

    return False


def print_token_table(token_stream, lexer):
    """Imprime una tabla de los tokens validos encontrados."""

    print("=" * 90)
    print(f"{'Linea':<8}{'Columna':<10}{'Token':<30}{'Lexema'}")
    print("=" * 90)

    for token in token_stream.tokens:
        if token.type == -1:
            continue

        token_name = get_token_name(lexer, token.type)

        # Los tokens de error ya se reportaron antes y no deben listarse aqui.
        if token_name in {
            "UNCLOSED_BLOCK_COMMENT",
            "INVALID_HASH_OPERATOR",
            "INVALID_REAL_LITERAL",
            "INVALID_OPERATOR",
            "ERROR_CHAR",
        }:
            continue

        lexeme = token.text.replace("\n", "\\n").replace("\t", "\\t")
        print(f"{token.line:<8}{token.column:<10}{token_name:<30}{lexeme}")

    print("=" * 90)
    print("Analisis lexico completado correctamente.")


def main():
    """Ejecuta el lexer sobre un archivo y muestra la tabla de tokens."""

    if len(sys.argv) != 2:
        sys.exit(1)

    input_path = Path(sys.argv[1])

    if not input_path.exists():
        print(f'Error: no existe el archivo "{input_path}".')
        sys.exit(1)

    try:
        input_stream = FileStream(str(input_path), encoding="utf-8")
    except Exception as exc:
        print(f"Error al leer el archivo: {exc}")
        sys.exit(1)

    lexer = FCCLexer(input_stream)
    token_stream = CommonTokenStream(lexer)
    token_stream.fill()

    has_error = check_lexical_errors(token_stream, lexer)

    if has_error:
        sys.exit(1)

    print_token_table(token_stream, lexer)


if __name__ == "__main__":
    main()
