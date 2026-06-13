from __future__ import annotations

from typing import List, Optional

from basic_blocks import BasicBlockBuilder
from ir_builder import IRBuilder
from ir_optimizer import IROptimizer, OptimizationReport
from ir_nodes import IRFunction, IRInstruction, IRProgram


COMPARISON_OPS = {"==", "!=", "<", "<=", ">", ">="}


def build_ir(ast) -> IRProgram:
    """Entradas: AST consolidado. Salida: IRProgram TAC. Uso: fcc.py e IDE."""
    # El AST es la fuente semantica; la IR queda lineal para optimizar y bajar.
    return IRBuilder().build(ast)


def optimize_ir(
    program: IRProgram,
    unroll_factor: int = 1,
    rename_statics: bool = False,
    heuristic: bool = True,
    opt_level: str = "O0",
) -> tuple[IRProgram, OptimizationReport]:
    """Entradas: IR y flags -O. Salida: IR optimizada y reporte. Uso: fcc.py."""
    # Todas las banderas llegan explicitas desde consola/IDE; O0 no cambia la IR.
    return IROptimizer().optimize(
        program,
        unroll_factor=unroll_factor,
        rename_statics=rename_statics,
        heuristic=heuristic,
        opt_level=opt_level,
    )


def format_ir(program: IRProgram) -> str:
    """Entradas: IRProgram. Salida: TAC legible. Uso: boton IR y CLI."""
    return ThreeAddressFormatter().format_program(program)


def format_basic_blocks(program: IRProgram) -> str:
    """Entradas: IRProgram. Salida: bloques basicos. Uso: --blocks/.blocks."""
    return BasicBlockBuilder().build_program(program).text()


class ThreeAddressFormatter:
    """Formateador de TAC.

    Entradas: IRProgram.
    Salida: texto tipo codigo de tres direcciones.
    Uso: format_ir, --ir, --optimized-ir y boton IR.
    """

    def __init__(self):
        """Entradas: ninguna. Salida: estado de labels limpio. Uso: format_program."""
        self.label_names: dict[str, str] = {}
        self.synthetic_labels: dict[int, str] = {}
        self.label_counter = 0

    def format_program(self, program: IRProgram) -> str:
        """Entradas: IRProgram. Salida: texto completo. Uso: format_ir."""
        lines: List[str] = []
        if program.globals:
            lines.append("globals:")
            for global_name in program.globals:
                lines.append(f"  {global_name}")
            lines.append("")

        for index, function in enumerate(program.functions):
            if index:
                # Separador visual entre funciones.
                lines.append("")
            lines.extend(self._format_function(function))
        return "\n".join(lines)

    def _format_function(self, function: IRFunction) -> List[str]:
        """Entradas: IRFunction. Salida: lineas TAC. Uso: format_program."""
        self.label_names = {}
        self.synthetic_labels = {}
        self.label_counter = 0

        lines = [f"func {function.name}({', '.join(function.params)}) -> {function.return_type}"]
        instructions = function.instructions
        index = 0
        while index < len(instructions):
            instruction = instructions[index]

            if instruction.op == "label" and instruction.dest:
                # Labels internos se normalizan a L1, L2...
                lines.append(f"{self._label(instruction.dest)}:")
                index += 1
                continue

            branch_lines, consumed = self._format_branch_pattern(instructions, index)
            if branch_lines is not None:
                # El patron comparacion+branch se consume como una unidad.
                lines.extend(branch_lines)
                index += consumed
                continue

            lines.append(self._format_instruction(instruction))
            index += 1

        return lines

    def _format_branch_pattern(
        self,
        instructions: List[IRInstruction],
        index: int,
    ) -> tuple[Optional[List[str]], int]:
        """Entradas: TAC e indice. Salida: branch formateado y consumo. Uso: _format_function."""
        instruction = instructions[index]
        next_instruction = instructions[index + 1] if index + 1 < len(instructions) else None

        if self._is_comparison_assignment(instruction) and self._branches_on(next_instruction, instruction.dest):
            # Convierte t = a < b; if_false t goto L en if a < b goto ...
            condition = f"{instruction.args[0]} {instruction.extra} {instruction.args[1]}"
            return self._format_explicit_branch(condition, next_instruction, instructions, index + 2), 2

        if instruction.op in {"if", "if_false"} and instruction.args and instruction.target:
            return self._format_explicit_branch(instruction.args[0], instruction, instructions, index + 1), 1

        return None, 0

    def _format_explicit_branch(
        self,
        condition: str,
        branch: IRInstruction,
        instructions: List[IRInstruction],
        fallthrough_index: int,
    ) -> List[str]:
        """Entradas: condicion y salto. Salida: if/goto explicitos. Uso: _format_branch_pattern."""
        fallthrough_label, synthetic = self._fallthrough_label(instructions, fallthrough_index)
        target_label = self._label(branch.target or "")

        if branch.op == "if_false":
            # if_false se muestra como dos saltos explicitos: verdadero y falso.
            lines = [f"  if {condition} goto {fallthrough_label}", f"  goto {target_label}"]
        else:
            lines = [f"  if {condition} goto {target_label}", f"  goto {fallthrough_label}"]

        if synthetic:
            # Si no habia label real, se crea uno solo para lectura.
            lines.append(f"{fallthrough_label}:")
        return lines

    def _fallthrough_label(
        self,
        instructions: List[IRInstruction],
        index: int,
    ) -> tuple[str, bool]:
        """Entradas: TAC e indice. Salida: label de caida y si fue sintetico. Uso: branches."""
        if index < len(instructions):
            instruction = instructions[index]
            if instruction.op == "label" and instruction.dest:
                return self._label(instruction.dest), False

        if index not in self.synthetic_labels:
            # Mismo indice debe reutilizar el mismo label sintetico.
            self.synthetic_labels[index] = self._new_label()
        return self.synthetic_labels[index], True

    def _format_instruction(self, instruction: IRInstruction) -> str:
        """Entradas: IRInstruction. Salida: linea TAC. Uso: _format_function."""
        if instruction.op == "const":
            return f"  {instruction.dest} = {instruction.extra}"
        if instruction.op == "assign" and instruction.args:
            return f"  {instruction.dest} = {instruction.args[0]}"
        if instruction.op == "binop" and len(instruction.args) >= 2:
            return f"  {instruction.dest} = {instruction.args[0]} {instruction.extra} {instruction.args[1]}"
        if instruction.op == "unop" and instruction.args:
            return f"  {instruction.dest} = {instruction.extra}{instruction.args[0]}"
        if instruction.op == "addr" and instruction.args:
            return f"  {instruction.dest} = &{instruction.args[0]}"
        if instruction.op == "deref" and instruction.args:
            return f"  {instruction.dest} = *{instruction.args[0]}"
        if instruction.op == "load_index" and len(instruction.args) >= 2:
            return f"  {instruction.dest} = {instruction.args[0]}[{instruction.args[1]}]"
        if instruction.op == "store_index" and len(instruction.args) >= 3:
            return f"  {instruction.args[0]}[{instruction.args[1]}] = {instruction.args[2]}"
        if instruction.op == "store_deref" and len(instruction.args) >= 2:
            return f"  *{instruction.args[0]} = {instruction.args[1]}"
        if instruction.op == "param" and instruction.args:
            return f"  param {instruction.args[0]}"
        if instruction.op == "call":
            call_text = f"call {instruction.extra}, {len(instruction.args)}"
            return f"  {instruction.dest} = {call_text}" if instruction.dest else f"  {call_text}"
        if instruction.op == "goto" and instruction.target:
            return f"  goto {self._label(instruction.target)}"
        if instruction.op == "return":
            return f"  return {instruction.args[0]}" if instruction.args else "  return"
        if instruction.op == "comment":
            return f"  # {instruction.extra or ''}"
        return str(instruction)

    def _is_comparison_assignment(self, instruction: IRInstruction) -> bool:
        """Entradas: instruccion. Salida: True si materializa comparacion. Uso: branches."""
        return (
            instruction.op == "binop"
            and instruction.dest is not None
            and instruction.extra in COMPARISON_OPS
            and len(instruction.args) >= 2
        )

    def _branches_on(self, instruction: Optional[IRInstruction], name: Optional[str]) -> bool:
        """Entradas: posible branch y nombre. Salida: True si branch usa ese nombre. Uso: formatter."""
        return (
            instruction is not None
            and instruction.op in {"if", "if_false"}
            and name is not None
            and instruction.args == [name]
        )

    def _label(self, original: str) -> str:
        """Entradas: label interno. Salida: label estable Lx. Uso: formateo."""
        if original not in self.label_names:
            self.label_names[original] = self._new_label()
        return self.label_names[original]

    def _new_label(self) -> str:
        """Entradas: ninguna. Salida: nuevo Lx. Uso: _label y labels sinteticos."""
        self.label_counter += 1
        return f"L{self.label_counter}"
