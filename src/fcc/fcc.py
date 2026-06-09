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
from ir_assembly_generator import IRAssemblyGenerator
from ir_driver import build_ir, format_basic_blocks, format_ir, optimize_ir
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
              fcc main.f --ir
              fcc main.f --blocks
              fcc main.f --optimized-ir -O2 --unroll-factor 4
              fcc main.f --emit-ir-files -O2 --unroll-factor 3
              fcc main.f --ir-backend -O1 -s
              fcc main.f --optimized-ir -O3
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
    parser.add_argument(
        "--ir",
        action="store_true",
        help="Genera e imprime la forma TAC interna derivada del AST.",
    )
    parser.add_argument(
        "--blocks",
        action="store_true",
        help="Imprime la identificacion de bloques basicos y sucesores de la IR.",
    )
    parser.add_argument(
        "--optimized-ir",
        action="store_true",
        help="Imprime la IR despues de aplicar el nivel -O seleccionado.",
    )
    parser.add_argument(
        "-O",
        "--opt-level",
        choices=["0", "1", "2", "3", "O0", "O1", "O2", "O3"],
        default="0",
        metavar="<0|1|2>",
        help=(
            "Nivel de optimizacion: O0 sin cambios; O1 renombra temporales/estaticos y baja por ASM desde TAC; "
            "O2 agrega loop unrolling parcial con factor configurable."
        ),
    )
    parser.add_argument("-O0", action="store_const", const="0", dest="opt_level", help="Equivale a -O 0.")
    parser.add_argument("-O1", action="store_const", const="1", dest="opt_level", help="Equivale a -O 1.")
    parser.add_argument("-O2", action="store_const", const="2", dest="opt_level", help="Equivale a -O 2.")
    parser.add_argument("-O3", action="store_const", const="3", dest="opt_level", help="Equivale a -O 3.")
    parser.add_argument(
        "--unroll-factor",
        type=int,
        default=None,
        metavar="<n>",
        help="Factor configurable para loop unrolling parcial. No tiene valor por defecto en -O2.",
    )
    parser.add_argument(
        "--no-unroll-heuristic",
        action="store_true",
        help="Desactiva la heuristica de tamano para loop unrolling.",
    )
    parser.add_argument(
        "--rename-statics",
        action="store_true",
        default=None,
        help="Activa renombramiento de estaticos/temporales para eliminar WAR/WAW falsas en IR.",
    )
    parser.add_argument(
        "--no-rename-statics",
        action="store_false",
        dest="rename_statics",
        help="Desactiva renombramiento aunque el nivel -O lo habilite.",
    )
    parser.add_argument(
        "--emit-ir-files",
        action="store_true",
        help="Escribe archivos .ir, .blocks, .opt.ir, .opt.blocks y .opt.report junto al fuente.",
    )
    parser.add_argument(
        "--ir-backend",
        action="store_true",
        help="Genera ensamblador/binario desde la IR seleccionada por -O en vez de hacerlo directamente desde el AST.",
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


def derive_ir_output_paths(input_path: Path) -> dict[str, Path]:
    return {
        "ir": input_path.with_suffix(".ir"),
        "blocks": input_path.with_suffix(".blocks"),
        "optimized_ir": input_path.with_suffix(".opt.ir"),
        "optimized_blocks": input_path.with_suffix(".opt.blocks"),
        "report": input_path.with_suffix(".opt.report"),
    }


def resolve_source_path(raw_path: str) -> Path:
    source_path = Path(raw_path)
    candidate_names = [source_path]
    if not source_path.suffix:
        candidate_names.append(source_path.with_suffix(".f"))

    search_roots = [Path.cwd(), PROJECT_ROOT, PROJECT_ROOT / "examples"]
    for root in search_roots:
        for candidate_name in candidate_names:
            candidate = candidate_name if candidate_name.is_absolute() else root / candidate_name
            if candidate.exists() and candidate.is_file():
                return candidate.resolve()
    return source_path


def normalize_opt_level(raw_level: str) -> str:
    normalized = str(raw_level).upper()
    if normalized.startswith("O"):
        normalized = normalized[1:]
    return f"O{normalized}"


def build_optimization_options(args) -> dict[str, object]:
    opt_level = normalize_opt_level(args.opt_level)
    opt_number = int(opt_level[1:])

    # O0 queda limpio; cada nivel superior prende pases por defecto.
    rename_statics = args.rename_statics if args.rename_statics is not None else opt_number == 1

    if args.unroll_factor is not None:
        unroll_factor = args.unroll_factor
    else:
        unroll_factor = 1

    return {
        "opt_level": opt_level,
        "opt_number": opt_number,
        "unroll_factor_was_set": args.unroll_factor is not None,
        "rename_statics": rename_statics,
        "unroll_factor": unroll_factor,
        "heuristic": not args.no_unroll_heuristic,
    }


def validate_optimization_options(options: dict[str, object]) -> str | None:
    opt_number = int(options["opt_number"])
    unroll_factor = int(options["unroll_factor"])
    unroll_factor_was_set = bool(options["unroll_factor_was_set"])

    if opt_number == 2 and not unroll_factor_was_set:
        return (
            "Error: -O2 requiere --unroll-factor <n>. "
            "No hay factor por defecto; el compilador lo validara contra los loops del programa."
        )

    if opt_number != 2 and unroll_factor_was_set:
        return "Error: --unroll-factor solo se usa con -O2."

    if unroll_factor_was_set and unroll_factor < 2:
        return "Error: --unroll-factor debe ser mayor o igual que 2 para aplicar loop unrolling."
    return None


def optimization_enabled(options: dict[str, object]) -> bool:
    return (
        bool(options["rename_statics"])
        or int(options["unroll_factor"]) > 1
        or str(options["opt_level"]) == "O3"
    )


def optimize_ir_or_exit(ir_program, options: dict[str, object]):
    try:
        return optimize_ir(
            ir_program,
            unroll_factor=int(options["unroll_factor"]),
            rename_statics=bool(options["rename_statics"]),
            heuristic=bool(options["heuristic"]),
            opt_level=str(options["opt_level"]),
        )
    except ValueError as exc:
        print(f"Error: {exc}")
        raise SystemExit(1)


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

    input_path = resolve_source_path(args.archivo_fuente)
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

    opt_options = build_optimization_options(args)

    optimization_error = validate_optimization_options(opt_options)
    if optimization_error is not None:
        print(optimization_error)
        raise SystemExit(1)

    if args.ir or args.blocks or args.optimized_ir or args.emit_ir_files:
        ir_program = build_ir(ast)
        print(ir_program)
        has_optimizations = optimization_enabled(opt_options)
        display_program = ir_program
        report = None
        if args.optimized_ir or args.emit_ir_files or has_optimizations:
            display_program, report = optimize_ir_or_exit(ir_program, opt_options)

        if args.emit_ir_files or args.optimized_ir:
            paths = derive_ir_output_paths(input_path)
            if args.emit_ir_files:
                paths["ir"].write_text(format_ir(ir_program) + "\n", encoding="utf-8")
                paths["blocks"].write_text(format_basic_blocks(ir_program) + "\n", encoding="utf-8")
            paths["optimized_ir"].write_text(format_ir(display_program) + "\n", encoding="utf-8")
            paths["optimized_blocks"].write_text(format_basic_blocks(display_program) + "\n", encoding="utf-8")
            if report is not None:
                paths["report"].write_text(report.text() + "\n", encoding="utf-8")
            if args.emit_ir_files:
                print("Archivos de IR escritos:")
                for path in paths.values():
                    if path.exists():
                        print(f"  - {path.resolve()}")
                print()

        if args.ir and not args.optimized_ir:
            print("IR de tres direcciones:\n")
            print(format_ir(ir_program))
            print()

        if args.optimized_ir:
            print("IR optimizada:\n")
            print(format_ir(display_program))
            if report is not None:
                print()
                print(report.text())
            print()

        if args.blocks:
            title = "Bloques basicos de IR optimizada" if display_program is not ir_program else "Bloques basicos de IR"
            print(f"{title}:\n")
            print(format_basic_blocks(display_program))
            print()

        if args.ir or args.blocks or args.emit_ir_files:
            raise SystemExit(0)

    if args.verbose:
        backend_name = "IR" if (args.ir_backend or optimization_enabled(opt_options)) else "AST"
        print(f"[3/4] Generando ensamblador desde {backend_name}...")

    use_ir_backend = args.ir_backend or optimization_enabled(opt_options)
    if use_ir_backend:
        ir_program = build_ir(ast)
        # El backend IR recibe la IR transformada solo cuando -O/flags lo piden.
        program_for_backend, report = optimize_ir_or_exit(ir_program, opt_options)
        generator = IRAssemblyGenerator()
        assembly_result = generator.generate_from_ir(program_for_backend, ast, semantic_result.symbol_table)
        if args.verbose:
            print(report.text())
    else:
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
