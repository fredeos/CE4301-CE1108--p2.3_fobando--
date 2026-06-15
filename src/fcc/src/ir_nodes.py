from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable, List, Optional


TERMINATOR_OPS = {"goto", "if", "if_false", "return"}
CONTROL_OPS = {"label", *TERMINATOR_OPS}
PURE_VALUE_OPS = {"const", "assign", "binop", "unop", "call", "load_index", "addr", "deref"}
WRITE_OPS = {"store_index", "store_deref", "param"}


@dataclass
class IRInstruction:
    """Instruccion TAC.

    Entradas: op, destino opcional, operandos, salto, extra y ubicacion fuente.
    Salida: objeto usado por IRBuilder, optimizador, bloques y backend IR.
    Uso: ir_builder, ir_optimizer, basic_blocks, ir_driver e ir_assembly_generator.
    """

    op: str
    dest: Optional[str] = None
    args: List[str] = field(default_factory=list)
    target: Optional[str] = None
    extra: Optional[str] = None
    line: int = 0
    column: int = 0

    def clone(self) -> "IRInstruction":
        """Entradas: self. Salida: copia independiente. Uso: optimizaciones no destructivas."""

        return IRInstruction(
            op=self.op,
            dest=self.dest,
            args=list(self.args),
            target=self.target,
            extra=self.extra,
            line=self.line,
            column=self.column,
        )

    @property
    def is_label(self) -> bool:
        """Entradas: self. Salida: True si abre bloque/label. Uso: CFG y formateo."""
        return self.op == "label"

    @property
    def is_terminator(self) -> bool:
        """Entradas: self. Salida: True si corta flujo. Uso: bloques basicos."""
        return self.op in TERMINATOR_OPS

    def used_names(self) -> List[str]:
        """Entradas: instruccion. Salida: nombres leidos. Uso: analisis de usos/renombramiento."""

        if self.op == "label":
            return []
        if self.op == "call":
            # Las llamadas leen sus argumentos, aunque tambien existan param previos.
            return list(self.args)
        if self.op in {"goto"}:
            return []
        return list(self.args)

    def defined_name(self) -> Optional[str]:
        """Entradas: instruccion. Salida: nombre definido o None. Uso: renombramiento."""

        if self.op in PURE_VALUE_OPS and self.dest:
            # Solo valores puros producen una nueva version SSA-like.
            return self.dest
        return None

    def replace_uses(self, replacements: dict[str, str]):
        """Entradas: mapa viejo->nuevo. Salida: muta args. Uso: SSA-like y unrolling."""

        # Las reescrituras son locales: labels y destinos se tratan aparte.
        self.args = [replacements.get(arg, arg) for arg in self.args]

    def __str__(self) -> str:
        """Entradas: instruccion. Salida: TAC legible. Uso: reportes y depuracion."""
        if self.op == "label":
            return f"{self.dest}:"
        if self.op == "const":
            return f"  {self.dest} = {self.extra}"
        if self.op == "assign":
            return f"  {self.dest} = {self.args[0]}"
        if self.op == "binop":
            return f"  {self.dest} = {self.args[0]} {self.extra} {self.args[1]}"
        if self.op == "unop":
            return f"  {self.dest} = {self.extra}{self.args[0]}"
        if self.op == "addr":
            return f"  {self.dest} = &{self.args[0]}"
        if self.op == "deref":
            return f"  {self.dest} = *{self.args[0]}"
        if self.op == "load_index":
            return f"  {self.dest} = {self.args[0]}[{self.args[1]}]"
        if self.op == "store_index":
            return f"  {self.args[0]}[{self.args[1]}] = {self.args[2]}"
        if self.op == "store_deref":
            return f"  *{self.args[0]} = {self.args[1]}"
        if self.op == "param":
            return f"  param {self.args[0]}"
        if self.op == "call":
            call_text = f"call {self.extra}, {len(self.args)}"
            return f"  {self.dest} = {call_text}" if self.dest else f"  {call_text}"
        if self.op == "goto":
            return f"  goto {self.target}"
        if self.op == "if":
            return f"  if {self.args[0]} goto {self.target}"
        if self.op == "if_false":
            return f"  if_false {self.args[0]} goto {self.target}"
        if self.op == "return":
            return f"  return {self.args[0]}" if self.args else "  return"
        if self.op == "comment":
            return f"  # {self.extra or ''}"
        parts = [self.op, *(self.args or [])]
        if self.dest:
            parts.insert(0, f"{self.dest} =")
        if self.target:
            parts.append(f"-> {self.target}")
        return "  " + " ".join(parts)


@dataclass
class IRFunction:
    """Funcion IR lineal.

    Entradas: nombre, parametros, tipo y TAC.
    Salida: contenedor de instrucciones por funcion.
    Uso: builder, optimizador, CFG, formatter y backend IR.
    """

    name: str
    params: List[str] = field(default_factory=list)
    return_type: str = "void"
    instructions: List[IRInstruction] = field(default_factory=list)

    def emit(self, instruction: IRInstruction):
        """Entradas: instruccion. Salida: actualiza lista. Uso: IRBuilder."""
        self.instructions.append(instruction)

    def text(self) -> str:
        """Entradas: funcion. Salida: texto TAC. Uso: depuracion y archivos IR."""
        lines = [f"func {self.name}({', '.join(self.params)}) -> {self.return_type}"]
        lines.extend(str(instruction) for instruction in self.instructions)
        return "\n".join(lines)


@dataclass
class IRProgram:
    """Programa IR completo.

    Entradas: funciones y globales.
    Salida: unidad optimizable/compilable.
    Uso: CLI, optimizer, formatter, CFG y backend IR.
    """

    functions: List[IRFunction] = field(default_factory=list)
    globals: List[str] = field(default_factory=list)

    def function(self, name: str) -> Optional[IRFunction]:
        """Entradas: nombre. Salida: funcion o None. Uso: consultas internas."""
        for function in self.functions:
            if function.name == name:
                return function
        return None

    def text(self) -> str:
        """Entradas: programa. Salida: texto TAC completo. Uso: reportes."""
        lines: List[str] = []
        if self.globals:
            lines.append("globals:")
            for global_name in self.globals:
                lines.append(f"  {global_name}")
            lines.append("")
        for index, function in enumerate(self.functions):
            if index:
                lines.append("")
            lines.append(function.text())
        return "\n".join(lines)


def clone_instructions(instructions: Iterable[IRInstruction]) -> List[IRInstruction]:
    """Entradas: instrucciones. Salida: clones. Uso: optimizer y unrolling."""

    return [instruction.clone() for instruction in instructions]
