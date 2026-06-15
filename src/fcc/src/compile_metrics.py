from __future__ import annotations

from dataclasses import dataclass
import csv
import math
from pathlib import Path
import re
from typing import Iterable, Optional

from asm_parser import parse_instr
from asm_to_bin import encode_instruction_stream
from ir_optimizer import OptimizationReport


WORD_BYTES = 4


@dataclass
class AssemblyProgram:
    """ASM con labels conservados.

    Entradas: texto ensamblador.
    Salida: instrucciones y mapa label->indice.
    Uso: estimacion dinamica de ciclos.
    """

    instructions: list
    labels: dict[str, int]


@dataclass
class LoopExecutionHint:
    """Pista de ejecucion para un loop optimizado.

    Entradas: label, N y factor.
    Salida: guia para ciclos dinamicos.
    Uso: measure_assembly.
    """

    label_name: str
    trip_count: int
    unroll_factor: int = 1


@dataclass
class AssemblyMetrics:
    """Entradas: ASM textual. Salida: conteos medidos. Uso: CompileMetrics."""

    instruction_count: int
    code_size_bytes: int
    estimated_cycles: int
    pipeline_stalls: int


@dataclass
class SequenceMetrics:
    """Metricas de una secuencia ASM ejecutable.

    Entradas: instrucciones parseadas.
    Salida: ciclos y stalls.
    Uso: estimacion dinamica.
    """

    estimated_cycles: int
    pipeline_stalls: int


@dataclass
class CompileMetrics:
    """Entradas: medidas antes/despues. Salida: filas CSV/tabla. Uso: fcc.py."""

    before: AssemblyMetrics
    after: AssemblyMetrics
    compile_time_ms: float
    removed_instructions: int = 0
    reordered_instructions: int = 0
    renamed_instructions: int = 0
    unrolled_loops: int = 0


def derive_metrics_output_paths(input_path: Path) -> dict[str, Path]:
    """Entradas: fuente .f. Salida: rutas .metrics. Uso: fcc.py."""
    return {
        "csv": input_path.with_suffix(".metrics.csv"),
        "table": input_path.with_suffix(".metrics.txt"),
    }


def measure_assembly(assembly_text: str, loop_hints: Optional[list[LoopExecutionHint]] = None) -> AssemblyMetrics:
    """Entradas: ASM. Salida: instrucciones, bytes y ciclos. Uso: build_compile_metrics."""
    program = parse_assembly_program(assembly_text)
    metrics = estimate_dynamic_metrics(program, loop_hints or [])
    # Codificar valida que el conteo corresponda a instrucciones reales de la ISA.
    encoded = encode_instruction_stream(program.instructions)
    return AssemblyMetrics(
        instruction_count=len(encoded),
        code_size_bytes=len(encoded) * WORD_BYTES,
        estimated_cycles=metrics.estimated_cycles,
        pipeline_stalls=metrics.pipeline_stalls,
    )


def estimate_instruction_cycles(op: str) -> int:
    """Entradas: opcode ASM. Salida: ciclos estimados. Uso: measure_assembly."""
    op = op.lstrip("@").lower()
    if op == "end":
        # end es solo una marca de parada para el simulador; no representa trabajo util.
        return 0
    if op in {"div", "divi", "pdiv", "pdivi", "mod", "modi", "pmod", "pmodi"}:
        # Division/modulo son las operaciones aritmeticas mas costosas.
        return 8
    if op in {"mul", "muli", "pmul", "pmuli"}:
        return 3
    if op.startswith("ld") or op.startswith("st"):
        # Accesos a memoria consumen un ciclo extra estimado.
        return 2
    if op in {"beq", "bne", "bgt", "blt", "bge", "ble", "beqz", "jmp", "jal", "call", "ret"}:
        # Cambios de flujo incluyen costo de control.
        return 2
    if op.startswith("p") or op in {"login", "quit", "send", "recv"}:
        return 2
    return 1


def parse_assembly_program(assembly_text: str) -> AssemblyProgram:
    """Entradas: ASM textual. Salida: instrucciones con labels. Uso: metricas."""
    instructions = []
    labels: dict[str, int] = {}

    for raw_line in assembly_text.splitlines():
        # Se quitan comentarios, pero se conserva cualquier label antes de la instruccion.
        line = re.split(r"[;#]", raw_line, maxsplit=1)[0].strip()
        while line:
            label_match = re.match(r"^([A-Za-z_]\w*):", line)
            if not label_match:
                break
            labels[label_match.group(1)] = len(instructions)
            line = line[label_match.end():].strip()
        if not line:
            continue
        instruction = parse_instr(line)
        if instruction is not None:
            instructions.append(instruction)

    return AssemblyProgram(instructions=instructions, labels=labels)


def estimate_dynamic_metrics(
    program: AssemblyProgram,
    loop_hints: list[LoopExecutionHint],
) -> SequenceMetrics:
    """Entradas: ASM y loops con N. Salida: ciclos/stalls estimados. Uso: measure_assembly."""
    active_indices = executable_instruction_indices(program)
    dynamic = estimate_sequence_metrics(program.instructions, active_indices)
    applied_ranges: set[tuple[int, int]] = set()

    for hint in loop_hints:
        if hint.trip_count <= 1:
            continue
        start = program.labels.get(hint.label_name)
        if start is None:
            continue
        back_jump = find_loop_back_jump(program, start)
        if back_jump is None:
            continue
        loop_range = (start, back_jump)
        if loop_range in applied_ranges:
            continue
        applied_ranges.add(loop_range)

        loop_metrics = estimate_sequence_metrics(program.instructions[start:back_jump + 1])
        executions = math.ceil(hint.trip_count / max(hint.unroll_factor, 1))
        # La version estatica ya conto una copia; se agregan las repeticiones reales restantes.
        dynamic.estimated_cycles += loop_metrics.estimated_cycles * (executions - 1)
        dynamic.pipeline_stalls += loop_metrics.pipeline_stalls * (executions - 1)

    return dynamic


def executable_instruction_indices(program: AssemblyProgram) -> set[int]:
    """Entradas: ASM con labels. Salida: indices alcanzables lineales. Uso: ciclos."""
    label_indices = set(program.labels.values())
    fallback_indices = {
        index for label, index in program.labels.items() if label.startswith("__end_fallback__")
    }
    active: set[int] = set()
    reachable = True

    for index, instruction in enumerate(program.instructions):
        if index in fallback_indices:
            # El respaldo solo se ejecuta si end se ignora; no pertenece a la medicion normal.
            reachable = False
            continue
        if index in label_indices:
            # Un label inicia un bloque que puede alcanzarse desde saltos/llamadas.
            reachable = True
        if not reachable:
            continue
        active.add(index)
        if normalized_op(instruction) in {"ret", "jmp", "end"}:
            # Despues de un terminador no hay caida hasta el siguiente label.
            reachable = False

    return active


def estimate_sequence_metrics(instructions: list, active_indices: Optional[set[int]] = None) -> SequenceMetrics:
    """Entradas: instrucciones ASM. Salida: ciclos con forwarding. Uso: metricas."""
    active = [
        instruction
        for index, instruction in enumerate(instructions)
        if active_indices is None or index in active_indices
    ]
    base_cycles = sum(estimate_instruction_cycles(instruction.op) for instruction in active)
    stalls = estimate_pipeline_stalls(active)
    return SequenceMetrics(base_cycles + stalls, stalls)


def estimate_pipeline_stalls(instructions: list) -> int:
    """Entradas: instrucciones. Salida: stalls RAW con EX/MEM->EX y WB->EX. Uso: ciclos."""
    stalls = 0
    previous = None

    for instruction in instructions:
        if previous is not None and has_immediate_load_use_hazard(previous, instruction):
            # Un load inmediatamente consumido necesita una burbuja; luego llega por WB->EX.
            stalls += 1
        previous = instruction

    return stalls


def has_immediate_load_use_hazard(producer, consumer) -> bool:
    """Entradas: productor/consumidor vecinos. Salida: True si falta un ciclo. Uso: stalls."""
    if not is_load_instruction(producer):
        return False
    produced = destination_registers(producer)
    consumed = source_registers(consumer)
    return bool(produced & consumed)


def is_load_instruction(instruction) -> bool:
    """Entradas: instruccion ASM. Salida: True si carga memoria. Uso: hazards."""
    op = normalized_op(instruction)
    return op.startswith("ld")


def normalized_op(instruction) -> str:
    """Entradas: instruccion ASM. Salida: opcode normalizado. Uso: helpers."""
    return instruction.op.lstrip("@").lower()


def source_registers(instruction) -> set[str]:
    """Entradas: instruccion ASM. Salida: registros leidos. Uso: hazards."""
    op = normalized_op(instruction)

    if op in {"ret"}:
        return {"ra"}
    if op.startswith("st"):
        return clean_registers([instruction.rd, instruction.rn])
    if op in {"beq", "bne", "bgt", "blt", "bge", "ble", "beqz"}:
        return clean_registers([instruction.rn, instruction.rm])
    if op in {"jmp", "jal", "call", "end", "nop", "li", "la", "movi", "pmovi", "pli", "pla"}:
        return set()
    if op.startswith("ld"):
        return clean_registers([instruction.rn])
    return clean_registers([instruction.rn, instruction.rm, instruction.sf])


def destination_registers(instruction) -> set[str]:
    """Entradas: instruccion ASM. Salida: registros escritos. Uso: hazards."""
    op = normalized_op(instruction)

    if op.startswith("st") or op in {"beq", "bne", "bgt", "blt", "bge", "ble", "beqz", "jmp", "ret", "end", "nop"}:
        return set()
    if op == "call":
        return {"ra"}
    return clean_registers([instruction.rd])


def clean_registers(registers: Iterable[object]) -> set[str]:
    """Entradas: posibles registros. Salida: nombres validos. Uso: source/dest."""
    cleaned: set[str] = set()
    for register in registers:
        if register is None:
            continue
        name = str(register).lower()
        if name in {"zero", "none"}:
            continue
        cleaned.add(name)
    return cleaned


def find_loop_back_jump(program: AssemblyProgram, start_index: int) -> Optional[int]:
    """Entradas: ASM y label inicial. Salida: indice del salto de regreso. Uso: ciclos."""
    for index in range(start_index + 1, len(program.instructions)):
        instruction = program.instructions[index]
        if instruction.op.lstrip("@").lower() not in {"jmp", "jal"}:
            continue
        if instruction.imm is None or instruction.imm >= 0:
            continue
        # Los saltos generados por FCC son relativos al PC siguiente.
        target_index = index + 1 + instruction.imm
        if target_index == start_index:
            return index
    return None


def build_compile_metrics(
    before_assembly: str,
    after_assembly: str,
    report: OptimizationReport | None,
    compile_time_ms: float,
) -> CompileMetrics:
    """Entradas: ASM antes/despues y reporte. Salida: metricas. Uso: fcc.py."""
    before_hints, after_hints = loop_hints_from_report(report)
    return CompileMetrics(
        before=measure_assembly(before_assembly, before_hints),
        after=measure_assembly(after_assembly, after_hints),
        compile_time_ms=compile_time_ms,
        removed_instructions=(
            getattr(report, "dead_code_removed", 0) + getattr(report, "asm_cleanup_removed", 0)
        ) if report else 0,
        reordered_instructions=getattr(report, "reordered_instructions", 0) if report else 0,
        renamed_instructions=getattr(report, "renamed_defs", 0) if report else 0,
        unrolled_loops=len(getattr(report, "unrolled_loops", [])) if report else 0,
    )


def loop_hints_from_report(
    report: OptimizationReport | None,
) -> tuple[list[LoopExecutionHint], list[LoopExecutionHint]]:
    """Entradas: reporte -O. Salida: hints antes/despues. Uso: build_compile_metrics."""
    if report is None:
        return [], []

    before: list[LoopExecutionHint] = []
    after: list[LoopExecutionHint] = []
    for loop in getattr(report, "unrolled_loops", []):
        if loop.trip_count is None:
            continue
        before.append(LoopExecutionHint(loop.label_name, loop.trip_count, 1))
        after.append(LoopExecutionHint(loop.label_name, loop.trip_count, loop.factor))
    return before, after


def metrics_rows(metrics: CompileMetrics) -> list[tuple[str, str, str, str, str]]:
    """Entradas: metricas. Salida: filas tabla/CSV. Uso: write_compile_metrics."""
    return [
        (
            "Conteo de instrucciones",
            str(metrics.before.instruction_count),
            str(metrics.after.instruction_count),
            "instrucciones",
            improvement_smaller_is_better(metrics.before.instruction_count, metrics.after.instruction_count),
        ),
        (
            "Tamano de codigo",
            str(metrics.before.code_size_bytes),
            str(metrics.after.code_size_bytes),
            "bytes",
            improvement_smaller_is_better(metrics.before.code_size_bytes, metrics.after.code_size_bytes),
        ),
        (
            "Ciclos estimados por simulador",
            str(metrics.before.estimated_cycles),
            str(metrics.after.estimated_cycles),
            "ciclos",
            improvement_smaller_is_better(metrics.before.estimated_cycles, metrics.after.estimated_cycles),
        ),
        (
            "Tiempo de compilacion",
            "-",
            f"{metrics.compile_time_ms:.3f}",
            "ms",
            "medido",
        ),
        (
            "Loops desenrollados",
            "0",
            str(metrics.unrolled_loops),
            "loops",
            improvement_counter(metrics.unrolled_loops),
        ),
        (
            "Instrucciones eliminadas",
            "0",
            str(metrics.removed_instructions),
            "instrucciones",
            improvement_counter(metrics.removed_instructions),
        ),
        (
            "Instrucciones reordenadas",
            "0",
            str(metrics.reordered_instructions),
            "instrucciones",
            improvement_counter(metrics.reordered_instructions),
        ),
        (
            "Instrucciones renombradas",
            "0",
            str(metrics.renamed_instructions),
            "instrucciones",
            improvement_counter(metrics.renamed_instructions),
        ),
    ]


def improvement_smaller_is_better(before: int, after: int) -> str:
    """Entradas: valores antes/despues. Salida: delta legible. Uso: filas."""
    delta = before - after
    if delta > 0:
        return f"mejora {delta}"
    if delta < 0:
        return f"aumenta {abs(delta)}"
    return "sin cambio"


def improvement_counter(value: int) -> str:
    """Entradas: contador de pase. Salida: estado. Uso: filas."""
    return f"mejora {value}" if value > 0 else "sin cambios"


def write_compile_metrics(input_path: Path, metrics: CompileMetrics) -> dict[str, Path]:
    """Entradas: fuente y metricas. Salida: archivos escritos. Uso: fcc.py."""
    paths = derive_metrics_output_paths(input_path)
    rows = metrics_rows(metrics)
    write_metrics_csv(paths["csv"], rows)
    paths["table"].write_text(format_metrics_table(rows) + "\n", encoding="utf-8")
    return paths


def write_metrics_csv(path: Path, rows: Iterable[tuple[str, str, str, str, str]]) -> None:
    """Entradas: filas. Salida: CSV. Uso: write_compile_metrics."""
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["Metrica", "Antes: sin optimizacion", "Despues: con optimizacion", "Unidad", "Mejora"])
        writer.writerows(rows)


def format_metrics_table(rows: Iterable[tuple[str, str, str, str, str]]) -> str:
    """Entradas: filas. Salida: tabla texto. Uso: write_compile_metrics."""
    table_rows = [("Metrica", "Antes: sin optimizacion", "Despues: con optimizacion", "Unidad", "Mejora"), *rows]
    widths = [max(len(row[index]) for row in table_rows) for index in range(5)]
    separator = "-+-".join("-" * width for width in widths)
    lines = [
        " | ".join(cell.ljust(widths[index]) for index, cell in enumerate(table_rows[0])),
        separator,
    ]
    for row in table_rows[1:]:
        lines.append(" | ".join(cell.ljust(widths[index]) for index, cell in enumerate(row)))
    return "\n".join(lines)
