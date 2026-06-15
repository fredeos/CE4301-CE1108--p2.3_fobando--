from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List


@dataclass
class AssemblyPostOptimizationResult:
    """Resultado de una pasada ASM.

    Entradas: lineas optimizadas y conteo.
    Salida: datos para fcc.py/reporte.
    Uso: O4 post-backend.
    """

    lines: List[str]
    reordered_instructions: int = 0
    removed_instructions: int = 0


def optimize_o1_assembly(lines: List[str]) -> AssemblyPostOptimizationResult:
    """Entradas: ASM O1. Salida: ASM sin recargas falsas. Uso: fcc.py."""
    optimized: List[str] = []
    removed = 0

    for line in lines:
        load = _load_from_memory(line)
        previous_store = _store_to_memory(optimized[-1]) if optimized else None
        if load is not None and previous_store is not None and load[1] == previous_store[1]:
            stored_register, _memory = previous_store
            load_register, _ = load
            if load_register == stored_register:
                # El valor ya sigue en el mismo registro: la recarga no cambia nada.
                removed += 1
                continue
            optimized.append(f"    mov {load_register}, {stored_register}    # recarga eliminada por O1")
            continue

        if _is_return_wait_nop(line):
            previous_instruction = _previous_instruction(optimized)
            if previous_instruction is not None and _loaded_register(previous_instruction) is None:
                # Si el valor de retorno no viene de ldw, no hay burbuja load-use.
                removed += 1
                continue

        optimized.append(line)

    return AssemblyPostOptimizationResult(optimized, removed_instructions=removed)


def optimize_o4_assembly(lines: List[str]) -> AssemblyPostOptimizationResult:
    """Entradas: ASM renderizado. Salida: ASM O4 ajustado. Uso: fcc.py."""
    optimized = list(lines)
    reordered = 0
    index = 0

    while index + 5 < len(optimized):
        ret_reg = _loaded_register(optimized[index])
        if (
            ret_reg
            and _is_return_wait_nop(optimized[index + 1])
            and _is_return_move(optimized[index + 2], ret_reg)
            and _is_ra_restore(optimized[index + 3])
            and _is_sp_restore(optimized[index + 4])
            and _is_ret(optimized[index + 5])
        ):
            # La carga de ra ocupa el hueco del nop; WB->EX alimenta luego mov p0.
            optimized[index + 1] = optimized[index + 3]
            optimized[index + 3] = optimized[index + 4]
            optimized[index + 4] = optimized[index + 5]
            optimized[index + 5] = "    nop    # relleno no ejecutado tras ret"
            reordered += 3
            index += 6
            continue
        index += 1

    return AssemblyPostOptimizationResult(optimized, reordered_instructions=reordered)


def _store_to_memory(line: str) -> tuple[str, str] | None:
    """Entradas: linea ASM. Salida: (registro, memoria) si es stw. Uso: O1."""
    match = re.match(r"^\s*stw\s+([A-Za-z0-9_]+)\s*,\s*([^#;]+)", line)
    if not match:
        return None
    return match.group(1), _normalize_memory_operand(match.group(2))


def _load_from_memory(line: str) -> tuple[str, str] | None:
    """Entradas: linea ASM. Salida: (registro, memoria) si es ldw. Uso: O1."""
    match = re.match(r"^\s*ldw\s+([A-Za-z0-9_]+)\s*,\s*([^#;]+)", line)
    if not match:
        return None
    return match.group(1), _normalize_memory_operand(match.group(2))


def _normalize_memory_operand(raw: str) -> str:
    """Entradas: operando memoria. Salida: texto comparable. Uso: O1."""
    return re.sub(r"\s+", "", raw.strip()).lower()


def _previous_instruction(lines: List[str]) -> str | None:
    """Entradas: lineas emitidas. Salida: ultima instruccion real. Uso: O1."""
    for line in reversed(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or stripped.endswith(":"):
            continue
        return line
    return None


def _loaded_register(line: str) -> str | None:
    """Entradas: linea ASM. Salida: destino de ldw o None. Uso: scheduler."""
    match = re.match(r"^\s*ldw\s+([A-Za-z0-9_]+)\s*,", line)
    return match.group(1) if match else None


def _is_return_wait_nop(line: str) -> bool:
    """Entradas: linea ASM. Salida: True si es nop de retorno. Uso: scheduler."""
    return bool(re.match(r"^\s*nop\b", line)) and "espera valor antes de mover retorno" in line


def _is_return_move(line: str, register: str) -> bool:
    """Entradas: linea y registro. Salida: True si mueve retorno. Uso: scheduler."""
    return bool(re.match(rf"^\s*mov\s+p0\s*,\s*{re.escape(register)}\b", line))


def _is_ra_restore(line: str) -> bool:
    """Entradas: linea ASM. Salida: True si restaura ra. Uso: scheduler."""
    return bool(re.match(r"^\s*ldw\s+ra\s*,", line))


def _is_sp_restore(line: str) -> bool:
    """Entradas: linea ASM. Salida: True si libera frame. Uso: scheduler."""
    return bool(re.match(r"^\s*addi\s+sp\s*,\s*sp\s*,\s*-", line))


def _is_ret(line: str) -> bool:
    """Entradas: linea ASM. Salida: True si retorna. Uso: scheduler."""
    return bool(re.match(r"^\s*ret\b", line))
