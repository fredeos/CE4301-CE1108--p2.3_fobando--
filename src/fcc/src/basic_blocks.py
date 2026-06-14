from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Set

from ir_nodes import IRFunction, IRInstruction, IRProgram, TERMINATOR_OPS


@dataclass
class BasicBlock:
    """Bloque basico de una funcion IR.

    Entradas: nombre, TAC, predecesores y sucesores.
    Salida: nodo de CFG.
    Uso: BasicBlockBuilder y reportes .blocks.
    """

    name: str
    instructions: List[IRInstruction] = field(default_factory=list)
    predecessors: Set[str] = field(default_factory=set)
    successors: Set[str] = field(default_factory=set)

    def text(self) -> str:
        """Entradas: bloque. Salida: texto con pred/succ. Uso: ProgramBlocks.text."""
        lines = [f"{self.name}:"]
        if self.predecessors:
            lines.append(f"  pred: {', '.join(sorted(self.predecessors))}")
        if self.successors:
            lines.append(f"  succ: {', '.join(sorted(self.successors))}")
        for instruction in self.instructions:
            if instruction.op == "label" and instruction.dest == self.name:
                # El nombre del bloque ya representa ese label.
                continue
            lines.append(str(instruction))
        return "\n".join(lines)


@dataclass
class FunctionBlocks:
    """CFG de una funcion.

    Entradas: nombre de funcion y bloques.
    Salida: vista de bloques por funcion.
    Uso: ProgramBlocks y archivos .blocks.
    """

    function_name: str
    blocks: List[BasicBlock] = field(default_factory=list)

    def text(self) -> str:
        """Entradas: CFG de funcion. Salida: texto. Uso: reportes."""
        lines = [f"bloques {self.function_name}:"]
        for block in self.blocks:
            lines.append(block.text())
            lines.append("")
        return "\n".join(lines).rstrip()


@dataclass
class ProgramBlocks:
    """CFG de todo el programa.

    Entradas: CFG por funcion.
    Salida: texto consolidado.
    Uso: ir_driver.format_basic_blocks.
    """

    functions: List[FunctionBlocks] = field(default_factory=list)

    def text(self) -> str:
        """Entradas: programa de bloques. Salida: texto unido. Uso: CLI/IDE."""
        return "\n\n".join(function.text() for function in self.functions)


class BasicBlockBuilder:
    """Constructor de bloques basicos.

    Entradas: IRProgram/IRFunction.
    Salida: ProgramBlocks/FunctionBlocks con sucesores.
    Uso: ir_driver para .blocks y depuracion de CFG.
    """

    def build_program(self, program: IRProgram) -> ProgramBlocks:
        """Entradas: IRProgram. Salida: CFG por funcion. Uso: format_basic_blocks."""
        return ProgramBlocks(functions=[self.build_function(function) for function in program.functions])

    def build_function(self, function: IRFunction) -> FunctionBlocks:
        """Entradas: IRFunction. Salida: bloques con pred/succ. Uso: build_program."""
        instructions = function.instructions
        if not instructions:
            # Sin TAC no hay leaders ni aristas que construir.
            return FunctionBlocks(function.name, [])

        # Labels permiten ubicar destinos reales de saltos.
        label_to_index = {
            instruction.dest: index
            for index, instruction in enumerate(instructions)
            if instruction.op == "label" and instruction.dest is not None
        }

        leaders: Set[int] = {0}
        for index, instruction in enumerate(instructions):
            if instruction.op == "label":
                # Un label siempre inicia bloque.
                leaders.add(index)
            if instruction.target and instruction.target in label_to_index:
                # El destino de un salto tambien es leader.
                leaders.add(label_to_index[instruction.target])
            if instruction.op in TERMINATOR_OPS and index + 1 < len(instructions):
                # Lo que sigue a un terminador inicia otro bloque.
                leaders.add(index + 1)

        sorted_leaders = sorted(leaders)
        blocks: List[BasicBlock] = []
        instruction_to_block: Dict[int, str] = {}

        for block_index, start in enumerate(sorted_leaders):
            end = sorted_leaders[block_index + 1] if block_index + 1 < len(sorted_leaders) else len(instructions)
            block_instructions = instructions[start:end]
            name = self._block_name(function.name, block_index, block_instructions)
            block = BasicBlock(name=name, instructions=block_instructions)
            blocks.append(block)
            for instruction_index in range(start, end):
                # Mapa inverso util para depurar a que bloque pertenece cada TAC.
                instruction_to_block[instruction_index] = name

        label_to_block = {}
        for block in blocks:
            for instruction in block.instructions:
                if instruction.op == "label" and instruction.dest:
                    # Los saltos apuntan a labels, pero el CFG conecta bloques.
                    label_to_block[instruction.dest] = block.name

        block_by_name = {block.name: block for block in blocks}
        for index, block in enumerate(blocks):
            last = block.instructions[-1] if block.instructions else None
            if last is None:
                # Bloque vacio: no aporta aristas.
                continue
            # La ultima instruccion determina las aristas del CFG.
            successors = self._successors(last, blocks, index, label_to_block)
            block.successors.update(successors)
            for successor in successors:
                if successor in block_by_name:
                    block_by_name[successor].predecessors.add(block.name)

        return FunctionBlocks(function.name, blocks)

    def _block_name(self, function_name: str, index: int, instructions: List[IRInstruction]) -> str:
        """Entradas: funcion, indice e instrucciones. Salida: label o nombre sintetico. Uso: build_function."""
        for instruction in instructions:
            if instruction.op == "label" and instruction.dest:
                return instruction.dest
        return f"{function_name}_B{index}"

    def _successors(
        self,
        instruction: IRInstruction,
        blocks: List[BasicBlock],
        block_index: int,
        label_to_block: Dict[str, str],
    ) -> Set[str]:
        """Entradas: terminador y contexto. Salida: sucesores CFG. Uso: build_function."""
        successors: Set[str] = set()
        fallthrough = blocks[block_index + 1].name if block_index + 1 < len(blocks) else None

        if instruction.op == "goto":
            if instruction.target and instruction.target in label_to_block:
                successors.add(label_to_block[instruction.target])
            # Un goto no cae al siguiente bloque.
            return successors

        if instruction.op in {"if", "if_false"}:
            if instruction.target and instruction.target in label_to_block:
                successors.add(label_to_block[instruction.target])
            if fallthrough:
                successors.add(fallthrough)
            return successors

        if instruction.op == "return":
            # Return cierra la funcion: no tiene sucesores.
            return successors

        if fallthrough:
            successors.add(fallthrough)
        return successors
