"""Driver del parser y constructor del AST a partir del arbol sintactico."""

from pathlib import Path
import importlib.util
import sys
from pprint import pprint

try:
    from antlr4 import FileStream, CommonTokenStream
    from antlr4.error.ErrorListener import ErrorListener
except ModuleNotFoundError as exc:
    if exc.name == "antlr4":
        sys.exit(
            "Error: falta instalar antlr4-python3-runtime. "
            "Ejecuta: python -m pip install -r fcc/requirements.txt"
        )
    raise


PROJECT_ROOT = Path(__file__).resolve().parent.parent
GENERATED_PATH = PROJECT_ROOT / "generated" / "fcc" / "grammar"


def load_generated_module(module_name: str):
    """Carga un modulo generado por ANTLR desde la carpeta generated."""

    module_path = GENERATED_PATH / f"{module_name}.py"

    if not module_path.exists():
        sys.exit(f"No se encontro {module_name}.py en {GENERATED_PATH}")

    spec = importlib.util.spec_from_file_location(module_name, module_path)

    if spec is None or spec.loader is None:
        sys.exit(f"No se pudo cargar {module_name}")

    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)

    return module


lexer_module = load_generated_module("FCCLexer")
parser_module = load_generated_module("FCCParser")

FCCLexer = lexer_module.FCCLexer
FCCParser = parser_module.FCCParser

from ast_builder import ASTBuilder
from lexer_driver import check_lexical_errors


class SyntaxErrorListener(ErrorListener):
    """Convierte errores crudos de ANTLR en mensajes mas utiles para FCC."""

    def __init__(self):
        """Inicializa el listener y evita cascadas de errores duplicados."""

        super().__init__()
        self.has_error = False
        self._reported = False

    def _format_message(self, offending_symbol, msg: str) -> str:
        """Traduce mensajes de ANTLR a descripciones mas legibles."""

        token_text = ""
        if offending_symbol is not None and offending_symbol.text is not None:
            token_text = offending_symbol.text

        msg_lower = msg.lower()

        if "missing ';'" in msg_lower:
            return 'se esperaba ";" al final de la sentencia.'
        if "missing '}'" in msg_lower:
            return 'se esperaba "}" para cerrar el bloque.'
        if "missing '{'" in msg_lower:
            return 'se esperaba "{" para iniciar el bloque.'
        if "missing ')'" in msg_lower:
            return 'se esperaba ")" para cerrar la expresion o parametros.'
        if "missing '('" in msg_lower:
            return 'se esperaba "(" para iniciar la expresion o parametros.'
        if "missing ']'" in msg_lower:
            return 'se esperaba "]" para cerrar el acceso de arreglo.'
        if "missing '['" in msg_lower:
            return 'se esperaba "[" para iniciar el acceso de arreglo.'

        if "extraneous input" in msg_lower:
            if token_text == "else":
                return 'se esperaba "}" para cerrar el bloque antes de "else".'
            if token_text == "<EOF>":
                return 'se esperaba "}" para cerrar el bloque.'
            return f'token inesperado "{token_text}".'

        if "mismatched input" in msg_lower:
            if token_text == "<EOF>":
                return "fin de archivo inesperado."
            return f'sintaxis invalida cerca de "{token_text}".'

        if "no viable alternative" in msg_lower:
            return "expresion o estructura invalida."

        return "estructura sintactica invalida."

    def syntaxError(self, recognizer, offendingSymbol, line, column, msg, e):
        """Reporta solo el primer error sintactico encontrado."""

        if self._reported:
            return

        self.has_error = True
        self._reported = True
        formatted_msg = self._format_message(offendingSymbol, msg)
        print(f"Error [sintactico] en linea {line}: {formatted_msg}")


def parse_and_build_ast(input_path: Path):
    """Ejecuta lexer, parser y builder para producir el AST de un archivo."""

    if not input_path.exists():
        print(f'Error: no existe el archivo "{input_path}".')
        sys.exit(1)

    input_stream = FileStream(str(input_path), encoding="utf-8")

    lexer = FCCLexer(input_stream)
    token_stream = CommonTokenStream(lexer)
    token_stream.fill()

    # El parser solo corre si la fase lexica no encontro errores.
    if check_lexical_errors(token_stream, lexer):
        sys.exit(1)

    parser = FCCParser(token_stream)
    parser.removeErrorListeners()

    error_listener = SyntaxErrorListener()
    parser.addErrorListener(error_listener)

    tree = parser.program()

    if error_listener.has_error:
        sys.exit(1)

    builder = ASTBuilder()
    ast = builder.visit(tree)

    return parser, tree, ast


def main():
    """Punto de entrada de consola para depurar parser y AST."""

    if len(sys.argv) != 2:
        print("Uso: python fcc/src/parser_driver.py <archivo_fuente>")
        sys.exit(1)

    input_path = Path(sys.argv[1])

    parser, tree, ast = parse_and_build_ast(input_path)

    print("\nAnalisis sintactico correcto\n")
    print(tree.toStringTree(recog=parser))

    print("\nAST construido correctamente:\n")
    pprint(ast)


if __name__ == "__main__":
    main()
