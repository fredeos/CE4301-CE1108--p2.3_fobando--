"""Driver de consola para la fase de generacion de ensamblador."""

from pathlib import Path
import sys
import argparse
from pprint import pprint

from semantic_analyzer import SemanticAnalyzer
from semantic_driver import format_semantic_error
from assembly_generator import AssemblyGenerator
from ast_json import derive_ast_json_output_path, write_ast_json
from import_resolver import ImportResolutionError, resolve_program_ast


def format_codegen_error(diagnostic) -> str:
    """Convierte un diagnostico de codegen en un mensaje legible."""

    return f"Error [ensamblador] en linea {diagnostic.line}: {diagnostic.message}"


def main():
    """Resuelve imports, corre semantica y genera ensamblador FCC."""

    parser = argparse.ArgumentParser(
        prog="assembly_driver.py",
        description="Genera ensamblador FCC usando la ISA F32IS.",
    )
    parser.add_argument("archivo_fuente")
    parser.add_argument(
        "-I",
        dest="include_dirs",
        action="append",
        default=[],
        help="Agrega un directorio adicional para resolver imports.",
    )
    parser.add_argument(
        "-o",
        dest="output_path",
        help="Ruta del archivo de salida. Si se omite, imprime en consola.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Muestra informacion adicional del proceso.",
    )
    parser.add_argument(
        "-t",
        "--ast",
        action="store_true",
        help="Imprime el AST consolidado antes de generar ensamblador.",
    )
    args = parser.parse_args()

    input_path = Path(args.archivo_fuente)
    include_dirs = [Path(path) for path in args.include_dirs]

    try:
        resolved = resolve_program_ast(input_path, include_dirs=include_dirs)
    except ImportResolutionError as exc:
        print(exc.message)
        sys.exit(1)

    ast = resolved.program

    if args.verbose:
        print("Archivos cargados:")
        for loaded in resolved.loaded_files:
            print(f"  - {loaded}")
        print()

    if args.ast:
        print("AST consolidado:\n")
        pprint(ast)
        ast_json_output_path = derive_ast_json_output_path(input_path)
        write_ast_json(ast, ast_json_output_path)
        print(f"AST JSON escrito en: {ast_json_output_path.resolve()}")
        print()

    # La generacion solo avanza si el programa ya paso semantica.
    analyzer = SemanticAnalyzer()
    semantic_result = analyzer.analyze(ast)
    if semantic_result.has_errors:
        for diagnostic in semantic_result.diagnostics:
            print(format_semantic_error(diagnostic))
        sys.exit(1)

    generator = AssemblyGenerator()
    assembly_result = generator.generate(ast, semantic_result.symbol_table)
    if assembly_result.has_errors:
        for diagnostic in assembly_result.diagnostics:
            print(format_codegen_error(diagnostic))
        sys.exit(1)

    if args.output_path:
        output_path = Path(args.output_path)
        output_path.write_text(assembly_result.text + "\n", encoding="utf-8")
        if args.verbose:
            print(f"Salida escrita en: {output_path.resolve()}")
    else:
        print(assembly_result.text)


if __name__ == "__main__":
    main()
