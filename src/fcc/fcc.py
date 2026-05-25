from __future__ import annotations

import argparse
import os
from pathlib import Path
from pprint import pprint
import sys
from textwrap import dedent


PROJECT_ROOT = Path(__file__).resolve().parent
SRC_PATH = PROJECT_ROOT / "src"
if str(SRC_PATH) not in sys.path:
    sys.path.insert(0, str(SRC_PATH))

from assembly_generator import AssemblyGenerator
from ast_json import derive_ast_json_output_path, write_ast_json
from asm_parser import parse_assembly_text
from asm_to_bin import (
    F32IS_Writer,
    build_global_data_blob,
    build_program_header,
    encode_instruction_stream,
)
from import_resolver import ImportResolutionError, resolve_program_ast
from semantic_analyzer import SemanticAnalyzer
from semantic_driver import (
    format_semantic_error,
    print_function_frames,
    print_symbol_table,
)


def format_codegen_error(diagnostic) -> str:
    return f"Error [ensamblador] en linea {diagnostic.line}: {diagnostic.message}"


def format_binary_error(error: Exception) -> str:
    return f"Error [binario]: {error}"


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="fcc",
        description="Compilador FCC unificado.",
        usage="fcc [opciones] <archivo_fuente> [-o <salida>]",
        epilog=dedent(
            """\
            Ejemplos:
              fcc main.f
              fcc main.f -o programa.bin
              fcc main.f -c
              fcc main.f -c -o modulo.obj
              fcc main.f -s
              fcc main.f -v -m
              fcc main.f -t
              fcc main.f -I libs
            """
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "archivo_fuente",
        nargs="?",
        metavar="<archivo_fuente>",
        help="Archivo fuente principal del programa.",
    )
    parser.add_argument(
        "-o",
        dest="salida",
        nargs="?",
        const="",
        metavar="<salida>",
        help=(
            "Especifica el nombre del archivo binario de salida. "
            "Si se omite, o si se usa -o sin archivo, se toma el nombre del "
            "fuente con extension .bin, o .obj si se usa -c."
        ),
    )
    parser.add_argument(
        "-c",
        "--compile-only",
        action="store_true",
        help="Solo compila y genera un archivo objeto textual (.obj), sin realizar el enlazado/binarizacion final.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Activa el modo detallado e imprime las fases del proceso.",
    )
    parser.add_argument(
        "-s",
        "--asm",
        action="store_true",
        help="Genera el archivo de ensamblador (.asm) ademas del binario final.",
    )
    parser.add_argument(
        "-t",
        "--ast",
        action="store_true",
        help="Imprime el AST consolidado en consola.",
    )
    parser.add_argument(
        "-m",
        "--memory",
        action="store_true",
        help="Imprime la tabla de simbolos y las asignaciones de memoria.",
    )
    parser.add_argument(
        "-I",
        dest="include_dirs",
        action="append",
        default=[],
        metavar="<directorio>",
        help="Agrega un directorio adicional para resolver imports.",
    )
    parser.add_argument(
        "--install-path",
        action="store_true",
        help="Agrega el directorio del compilador al PATH del usuario en Windows.",
    )
    parser.add_argument(
        "--ide",
        action="store_true",
        help="Abre el prototipo grafico de IDE para editar archivos .f.",
    )
    return parser


def derive_binary_output_path(input_path: Path, explicit_output: str | None, compile_only: bool = False) -> Path:
    if explicit_output:
        return Path(explicit_output)
    return input_path.with_suffix(".obj" if compile_only else ".bin")


def derive_asm_output_path(binary_output_path: Path) -> Path:
    if binary_output_path.suffix:
        return binary_output_path.with_suffix(".asm")
    return Path(f"{binary_output_path}.asm")


def derive_hex_output_path(binary_output_path: Path) -> Path:
    if binary_output_path.suffix:
        return binary_output_path.with_suffix(".hex")
    return Path(f"{binary_output_path}.hex")


def print_semantic_memory_summary(semantic_result) -> None:
    print_symbol_table(semantic_result.symbol_table)
    print_function_frames(semantic_result.symbol_table)

    if semantic_result.labels:
        print("\nLabels semanticos registrados:")
        for label in semantic_result.labels:
            print(
                f"  - {label.name} | kind={label.kind} | function={label.function_name} | "
                f"address={label.address} | target={label.target}"
            )


def install_to_user_path() -> int:
    if os.name != "nt":
        print('Error: "--install-path" solo esta soportado en Windows.')
        return 1

    try:
        import winreg
    except ImportError:
        print('Error: no se pudo importar "winreg" para actualizar el PATH del usuario.')
        return 1

    target_dir = str(PROJECT_ROOT)
    try:
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Environment",
            0,
            winreg.KEY_READ | winreg.KEY_WRITE,
        ) as key:
            try:
                current_path, reg_type = winreg.QueryValueEx(key, "Path")
            except FileNotFoundError:
                current_path, reg_type = ("", winreg.REG_EXPAND_SZ)

            entries = [entry for entry in current_path.split(";") if entry.strip()]
            normalized_target = os.path.normcase(os.path.normpath(target_dir))
            normalized_entries = {
                os.path.normcase(os.path.normpath(entry)): entry
                for entry in entries
            }

            if normalized_target in normalized_entries:
                print("El directorio del compilador ya existe en el PATH del usuario:")
                print(f"  {target_dir}")
            else:
                new_entries = entries + [target_dir]
                new_path = ";".join(new_entries)
                winreg.SetValueEx(key, "Path", 0, reg_type, new_path)
                print("Se agrego el directorio del compilador al PATH del usuario:")
                print(f"  {target_dir}")
    except PermissionError:
        print("Error: no se pudo actualizar el PATH del usuario por permisos insuficientes.")
        print("Prueba abrir PowerShell como tu usuario normal en una nueva terminal o agrega la ruta manualmente:")
        print(f"  {target_dir}")
        return 1

    print("")
    print("Abre una nueva terminal y luego podras invocar:")
    print("  fcc fcc\\examples\\prueba.f")
    return 0


def main():
    parser = build_arg_parser()
    args = parser.parse_args()

    if args.install_path:
        raise SystemExit(install_to_user_path())

    if args.ide:
        from ide_app import main as run_ide

        run_ide()
        raise SystemExit(0)

    if not args.archivo_fuente:
        parser.error("se requiere <archivo_fuente>, --ide o usar --install-path")

    input_path = Path(args.archivo_fuente)
    include_dirs = [Path(path) for path in args.include_dirs]

    try:
        if args.verbose:
            print("[1/3] Resolviendo imports y construyendo AST...")
        resolved = resolve_program_ast(input_path, include_dirs=include_dirs)
    except ImportResolutionError as exc:
        print(exc.message)
        raise SystemExit(1)
    except SystemExit as exc:
        raise SystemExit(exc.code)

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

    if args.verbose:
        print("[2/3] Ejecutando analisis semantico...")
    analyzer = SemanticAnalyzer()
    semantic_result = analyzer.analyze(ast)
    if semantic_result.has_errors:
        for diagnostic in semantic_result.diagnostics:
            print(format_semantic_error(diagnostic))
        raise SystemExit(1)

    if args.memory:
        print_semantic_memory_summary(semantic_result)
        print()

    if args.verbose:
        print("[3/4] Generando ensamblador...")
    generator = AssemblyGenerator()
    assembly_result = generator.generate(ast, semantic_result.symbol_table)
    if assembly_result.has_errors:
        for diagnostic in assembly_result.diagnostics:
            print(format_codegen_error(diagnostic))
        raise SystemExit(1)

    binary_output_path = derive_binary_output_path(input_path, args.salida, compile_only=args.compile_only)
    asm_output_path = derive_asm_output_path(binary_output_path)
    hex_output_path = derive_hex_output_path(binary_output_path)

    if args.compile_only:
        binary_output_path.write_text(assembly_result.text + "\n", encoding="utf-8")
        if args.asm:
            asm_output_path.write_text(assembly_result.text + "\n", encoding="utf-8")

        print("Compilacion completada correctamente.")
        print(f"Objeto escrito en: {binary_output_path.resolve()}")
        if args.asm:
            print(f"Ensamblador escrito en: {asm_output_path.resolve()}")
        else:
            print("Usa -s para generar tambien el archivo ensamblador (.asm).")

        if args.verbose:
            print("Nota: el objeto textual contiene el ensamblador consolidado, sin binarizacion ni encabezado final.")
        raise SystemExit(0)

    if args.asm:
        asm_output_path.write_text(assembly_result.text + "\n", encoding="utf-8")

    if args.verbose:
        print("[4/4] Generando codigo binario...")
    try:
        parsed_instructions = parse_assembly_text(assembly_result.text)
        encoded_instructions = encode_instruction_stream(parsed_instructions)
        data_blob, data_base = build_global_data_blob(ast, semantic_result.symbol_table)
        header = build_program_header(encoded_instructions, data_blob, entry_point=0, data_base=data_base)
        F32IS_Writer.save_program_bin(
            str(binary_output_path),
            header,
            encoded_instructions,
            data_blob,
        )
        F32IS_Writer.save_hex(str(hex_output_path), encoded_instructions)
    except Exception as exc:
        print(format_binary_error(exc))
        raise SystemExit(1)

    print("Compilacion completada correctamente.")
    print(f"Binario escrito en: {binary_output_path.resolve()}")
    print(f"Hexadecimal escrito en: {hex_output_path.resolve()}")
    if args.asm:
        print(f"Ensamblador escrito en: {asm_output_path.resolve()}")
    else:
        print("Usa -s para generar tambien el archivo ensamblador (.asm).")

    if args.verbose:
        print("Nota: el binario contiene encabezado, codigo e imagen inicial de datos globales.")


if __name__ == "__main__":
    main()
