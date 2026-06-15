"""Driver de consola para la fase de analisis semantico."""

from pathlib import Path
import sys
import argparse

from semantic_analyzer import SemanticAnalyzer
from import_resolver import ImportResolutionError, resolve_program_ast


def format_semantic_error(diagnostic) -> str:
    """Traduce un diagnostico semantico a un mensaje legible."""

    code = diagnostic.code
    d = diagnostic.details

    if code == "undeclared_reference":
        return f'Error [semantico] en linea {diagnostic.line}: la referencia "{d["name"]}" no ha sido declarada.'
    if code == "redeclared_function":
        return f'Error [semantico] en linea {diagnostic.line}: la funcion "{d["name"]}" ya fue declarada previamente.'
    if code == "redeclared_global_variable":
        return f'Error [semantico] en linea {diagnostic.line}: la variable global "{d["name"]}" ya fue declarada previamente.'
    if code == "redeclared_variable":
        return f'Error [semantico] en linea {diagnostic.line}: la variable "{d["name"]}" ya fue declarada en este ambito.'
    if code == "duplicated_parameter":
        return f'Error [semantico] en linea {diagnostic.line}: el parametro "{d["name"]}" ya fue declarado en la funcion.'
    if code == "assignment_type_mismatch":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'no se puede asignar un valor de tipo "{d["source_type"]}" '
            f'a un destino de tipo "{d["target_type"]}".'
        )
    if code == "compound_assignment_type_mismatch":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el operador "{d["operator"]}" no es valido entre '
            f'"{d["target_type"]}" y "{d["source_type"]}".'
        )
    if code == "return_outside_function":
        return f'Error [semantico] en linea {diagnostic.line}: la sentencia "ret" no puede usarse fuera de una funcion.'
    if code == "void_function_return_forbidden":
        return f'Error [semantico] en linea {diagnostic.line}: una funcion "void" no puede retornar un valor.'
    if code == "missing_return_expression":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'la funcion "{d["function_name"]}" debe usar "ret <expresion>;" con un valor de tipo "{d["expected_type"]}".'
        )
    if code == "void_function_not_allowed":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'la funcion "{d["function_name"]}" no puede declararse como "void"; debe tener un tipo de retorno concreto.'
        )
    if code == "main_with_parameters":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            'la funcion "main" no puede recibir parametros.'
        )
    if code == "return_type_mismatch":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el retorno tiene tipo "{d["actual_type"]}" pero la funcion espera "{d["expected_type"]}".'
        )
    if code == "function_missing_return":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'la funcion "{d["function_name"]}" debe garantizar un retorno de tipo "{d["expected_type"]}" '
            f'en todos los caminos de ejecucion.'
        )
    if code == "main_missing_return":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            'la funcion "main" debe incluir una sentencia "ret" en todos los caminos de ejecucion.'
        )
    if code == "condition_type_mismatch":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'la condicion de "{d["construct"]}" debe ser "bool", pero se recibio "{d["actual_type"]}".'
        )
    if code == "continue_outside_loop":
        return f'Error [semantico] en linea {diagnostic.line}: la sentencia "continue" solo puede usarse dentro de un ciclo.'
    if code == "break_outside_loop":
        return f'Error [semantico] en linea {diagnostic.line}: la sentencia "break" solo puede usarse dentro de un ciclo.'
    if code == "invalid_operation":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'operacion "{d["operator"]}" no valida entre "{d["left_type"]}" y "{d["right_type"]}".'
        )
    if code == "invalid_comparison":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'comparacion "{d["operator"]}" no valida entre "{d["left_type"]}" y "{d["right_type"]}".'
        )
    if code == "invalid_unary_operand":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el operador unario "{d["operator"]}" espera "{d["expected_type"]}", '
            f'pero recibio "{d["operand_type"]}".'
        )
    if code == "invalid_indexing":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'no se puede indexar una expresion de tipo "{d["target_type"]}".'
        )
    if code == "array_index_type_mismatch":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el indice de un arreglo debe ser "int", pero se recibio "{d["actual_type"]}".'
        )
    if code == "array_index_out_of_bounds":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el indice {d["index"]} esta fuera del rango del arreglo de tamano {d["size"]}.'
        )
    if code == "not_a_function":
        return f'Error [semantico] en linea {diagnostic.line}: "{d["name"]}" no es una funcion.'
    if code == "function_used_as_value":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'la funcion "{d["name"]}" debe invocarse con parentesis para usar su resultado.'
        )
    if code == "assignment_to_function":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'no se puede asignar sobre la funcion "{d["name"]}".'
        )
    if code == "assignment_to_readonly_register":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'no se puede asignar sobre el registro de solo lectura "{d["name"]}".'
        )
    if code == "assignment_to_array":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'no se puede asignar directamente sobre "{d["name"]}" de tipo "{d["target_type"]}".'
        )
    if code == "invalid_assignment_target":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            "el lado izquierdo de una asignacion debe ser una variable, puntero desreferenciado o elemento de arreglo."
        )
    if code == "invalid_member_access":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el acceso al miembro "{d["member"]}" no esta definido para los tipos actuales.'
        )
    if code == "unsupported_indirect_call":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'las llamadas indirectas sobre "{d["callee_type"]}" no estan soportadas.'
        )
    if code == "wrong_argument_count":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'la funcion "{d["name"]}" espera {d["expected"]} argumento(s) y recibio {d["actual"]}.'
        )
    if code == "incompatible_argument":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'argumento {d["position"]} incompatible en "{d["function_name"]}": '
            f'se esperaba "{d["expected_type"]}" y se recibio "{d["actual_type"]}".'
        )
    if code == "too_many_parameters":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'la funcion "{d["function_name"]}" excede el limite de {d["limit"]} parametros soportados por la arquitectura.'
        )
    if code == "parameter_out_of_register_range":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el parametro "{d["name"]}" excede el rango de registros p0-p8 de la arquitectura.'
        )
    if code == "array_dimension_must_be_int_literal":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            "en esta version, las dimensiones de arreglos deben ser literales enteros."
        )
    if code == "array_dimension_must_be_positive":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'las dimensiones de arreglos deben ser mayores que cero; se recibio {d["value"]}.'
        )
    if code == "array_dimension_missing":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el arreglo "{d["name"]}" necesita una dimension concreta para reservar memoria.'
        )
    if code == "invalid_type":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el tipo "{d["type_name"]}" usado en "{d["name"]}" no existe.'
        )
    if code == "invalid_void_declaration":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'no se puede declarar "{d["name"]}" como "{d["usage"]}" de tipo void.'
        )
    if code == "invalid_void_type":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el tipo "{d["type_name"]}" de "{d["name"]}" no es valido.'
        )
    if code == "invalid_vault_type":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'el tipo "{d["type_name"]}" de "{d["name"]}" debe declararse como "vault[<entero>]".'
        )
    if code == "direct_vault_value_forbidden":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            'un acceso "vault[i]" no puede usarse solo; debe combinarse con otra variable o literal.'
        )
    if code == "neutral_vault_operation":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'no se permite operar un acceso vault con el neutro del operador "{d["operator"]}".'
        )
    if code == "vault_comparison_forbidden":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            f'no se permiten comparaciones que involucren accesos vault con "{d["operator"]}".'
        )
    if code == "vault_index_expression_forbidden":
        return (
            f'Error [semantico] en linea {diagnostic.line}: '
            'no se permite usar un acceso "vault[i]" dentro del indice de otro acceso.'
        )

    return f'Error [semantico] en linea {diagnostic.line}: error semantico no especificado.'


def format_location(symbol) -> str:
    """Resume donde vive un simbolo dentro del modelo de memoria."""

    if symbol.segment == "global":
        return f"addr={symbol.address}"
    if symbol.segment == "code":
        return f"addr={symbol.address}"
    if symbol.segment == "stack":
        return f"offset={symbol.offset}"
    if symbol.segment == "param":
        return f"reg={symbol.register}" if symbol.register else f"offset={symbol.offset}"
    if symbol.segment == "label":
        return f"addr={symbol.address}"
    return "sin memoria"


def print_symbol_table(symbol_table):
    """Imprime la tabla de simbolos agrupada por ambitos."""

    print("Tabla de simbolos:")
    for scope in symbol_table.all_scopes:
        print(f"  Ambito {scope.name} ({scope.kind})")
        if not scope.symbols:
            print("    - sin simbolos")
            continue
        visible_symbols = [
            (name, symbol)
            for name, symbol in scope.symbols.items()
            if not symbol.extra.get("compiler_generated")
        ]
        if not visible_symbols:
            print("    - sin simbolos")
            continue
        for name, symbol in visible_symbols:
            if symbol.kind == "function":
                type_text = symbol.extra.get("signature", str(symbol.return_type))
            else:
                type_text = str(symbol.type_info) if symbol.type_info else "-"
            print(
                f"    - {name} | kind={symbol.kind} | tipo={type_text} | "
                f"segmento={symbol.segment} | {format_location(symbol)} | size={symbol.size}"
            )


def print_function_frames(symbol_table):
    """Imprime el tamano y la forma de los frames de funciones."""

    if not symbol_table.function_frames:
        return

    print("\nFrames de funciones:")
    for name, frame in symbol_table.function_frames.items():
        registers = ", ".join(frame.parameter_registers) if frame.parameter_registers else "-"
        print(
            f"  - {name} | frame={frame.frame_size} bytes | locals={frame.local_size} bytes | "
            f"param_regs={registers} | stack_params={frame.stack_parameters}"
        )


def main():
    """Carga un programa FCC y ejecuta la fase semantica completa."""

    parser = argparse.ArgumentParser(
        prog="semantic_driver.py",
        description="Ejecuta el analisis semantico del programa FCC.",
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
        "-v",
        "--verbose",
        action="store_true",
        help="Muestra informacion adicional del proceso.",
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

    analyzer = SemanticAnalyzer()
    result = analyzer.analyze(ast)

    if result.has_errors:
        for diagnostic in result.diagnostics:
            print(format_semantic_error(diagnostic))
        sys.exit(1)

    print("Analisis semantico correcto.\n")

    print_symbol_table(result.symbol_table)
    print_function_frames(result.symbol_table)

    if result.labels:
        print("\nLabels semanticos registrados:")
        for label in result.labels:
            print(
                f"  - {label.name} | kind={label.kind} | function={label.function_name} | "
                f"address={label.address} | target={label.target}"
            )


if __name__ == "__main__":
    main()
