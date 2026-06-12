from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List

from basic_blocks import BasicBlock, BasicBlockBuilder, ProgramBlocks
from ir_nodes import IRFunction, IRInstruction, IRProgram


class SafeInstructionReorderer:
    """
       Reordenamiento seguro de instrucciones dentro de bloques básicos.
       - Recibe un IRProgram
       - Construye bloques básicos usando BasicBlockBuilder
       - Reordena unicamente instrucciones puras dentro de cada bloque
       - Respeta dependencias RAW WAR y WAW
       - No mueve instrucciones de control ni instrucciones con efectos secundarios
       - Cuenta la cantidad de instrucciones reordenadas
       """

    def __init__(self):
        self.block_builder = BasicBlockBuilder()
        self.reordered_instructions_count = 0

        self.reorderable_ops = {
            "const",
            "assign",
            "binop",
            "unop",
        }

        self.fixed_ops = {
            "label",
            "if",
            "if_false",
            "goto",
            "return",
            "param",
            "call",
            "store_index",
            "store_deref",
            "load_index",
            "addr",
            "deref",
        }

        # Prioridad usada para escoger entre instrucciones listas.
        # No afecta la seguridad, solo decide qué instrucción independiente va primero.
        self.op_priority = {
            "const": 0,
            "binop": 1,
            "unop": 1,
            "assign": 2,
        }

    def reorder_program(self, program: IRProgram) -> tuple[IRProgram, int]:
        """
        Reordena instrucciones dentro de cada bloque básico del programa.

        Retorna:
        - Un nuevo IRProgram modificado.
        - Cantidad de instrucciones que cambiaron de posición.
        """

        self.reordered_instructions_count = 0

        # 1. Clonar el programa para no modificar el original
        current_program = self.clone_program(program)

        # 2. Construir bloques desde la copia
        program_blocks = self.block_builder.build_program(current_program)

        # 3. Buscar FunctionBlocks por nombre
        function_blocks_by_name = {
            function_blocks.function_name: function_blocks
            for function_blocks in program_blocks.functions
        }

        # 4. Recorrer las funciones de la copia
        for function in current_program.functions:
            function_blocks = function_blocks_by_name.get(function.name)

            if function_blocks is None:
                continue

            new_instructions: list[IRInstruction] = []

            for block in function_blocks.blocks:
                reordered_block = self.reorder_block(block)
                new_instructions.extend(reordered_block)

            function.instructions = new_instructions

        return current_program, self.reordered_instructions_count

    def clone_program(self, program: IRProgram) -> IRProgram:
        """
        Crea una copia del IRProgram para no modificar el programa original.
        """

        return IRProgram(
            globals=list(program.globals),
            functions=[
                IRFunction(
                    name=function.name,
                    params=list(function.params),
                    return_type=function.return_type,
                    instructions=[instr.clone() for instr in function.instructions],
                )
                for function in program.functions
            ],
        )

    def reorder_block(self, block: BasicBlock) -> list[IRInstruction]:
        """
        Reordena instrucciones dentro de un bloque básico.

        Las instrucciones fijas funcionan como barreras.
        O sea no se puede mover instrucciones a través de labels,
        saltos, returns, calls, params, etc.
        """

        new_block_instructions: list[IRInstruction] = []
        current_segment: list[IRInstruction] = []

        for instr in block.instructions:
            if self.is_reorderable_instruction(instr):
                current_segment.append(instr)
            else:
                # Antes de meter una instrucción fija, cerramos y reordenamos
                # el segmento reordenable acumulado.
                reordered_segment = self.reorder_segment(current_segment)
                new_block_instructions.extend(reordered_segment)
                current_segment = []

                # La instrucción fija se queda exactamente donde estaba.
                new_block_instructions.append(instr)

        # Reordenar el último segmento, si quedó algo pendiente.
        reordered_segment = self.reorder_segment(current_segment)
        new_block_instructions.extend(reordered_segment)

        return new_block_instructions

    def reorder_segment(self, segment: list[IRInstruction]) -> list[IRInstruction]:
        """
        Reordena un segmento de instrucciones puras respetando RAW/WAR/WAW.

        - Si instr A debe ir antes que instr B, se crea una dependencia A -> B.
        - Luego se genera un nuevo orden que respeta esas dependencias.
        """

        if len(segment) <= 1:
            return segment

        original_segment = list(segment)
        n = len(segment)

        successors: dict[int, set[int]] = {i: set() for i in range(n)}
        indegree: dict[int, int] = {i: 0 for i in range(n)}

        # Construir dependencias.
        # Solo revisamos pares donde i aparece antes que j en el código original.
        for i in range(n):
            for j in range(i + 1, n):
                first = segment[i]
                second = segment[j]

                if self.has_dependency(first, second):
                    successors[i].add(j)
                    indegree[j] += 1

        # Instrucciones que no dependen de ninguna otra pendiente.
        ready = [i for i in range(n) if indegree[i] == 0]
        scheduled_indices: list[int] = []

        while ready:
            last_index = scheduled_indices[-1] if scheduled_indices else None

            ready.sort(
                key=lambda index: self.scheduling_key(
                    segment,
                    index,
                    last_index,
                    successors
                )
            )

            current = ready.pop(0)
            scheduled_indices.append(current)

            for succ in sorted(successors[current]):
                indegree[succ] -= 1

                if indegree[succ] == 0:
                    ready.append(succ)

        # Por seguridad. No debería pasar porque las dependencias van hacia adelante.
        if len(scheduled_indices) != n:
            return original_segment

        reordered_segment = [segment[index] for index in scheduled_indices]

        self.reordered_instructions_count += self.count_moved_instructions(
            original_segment,
            reordered_segment
        )

        return reordered_segment

    def scheduling_key(self, segment: list[IRInstruction], index: int, last_index: int | None,
                       successors: dict[int, set[int]]) -> tuple[int, int, int, int]:
        """
        Decide cuál instrucción lista conviene escoger.

        Prioridades:
        1. Evitar poner justo después una instrucción que depende de la anterior.
        2. Mantener la prioridad normal por tipo de operación.
        3. Preferir instrucciones que desbloquean más instrucciones futuras.
        4. Mantener orden original como desempate.
        """

        depends_on_previous = 0

        if last_index is not None and index in successors[last_index]:
            depends_on_previous = 1

        op_priority = self.op_priority.get(segment[index].op, 99)

        unlocks = len(successors[index])

        return depends_on_previous, op_priority, -unlocks, index

    def count_moved_instructions(self, original: list[IRInstruction], reordered: list[IRInstruction]) -> int:
        """
        Cuenta cuántas instrucciones cambiaron de posición dentro del segmento.
        """

        moved = 0
        for index, instr in enumerate(original):
            if reordered[index] is not instr:
                moved += 1
        return moved

    def is_reorderable_instruction(self, instr: IRInstruction) -> bool:
        """
        Solo se reordenan instrucciones puras y con destino.
        """

        if instr.op in self.fixed_ops:
            return False

        if instr.op not in self.reorderable_ops:
            return False

        if instr.defined_name() is None:
            return False

        return True

    def get_def(self, instr: IRInstruction) -> set[str]:
        defined = instr.defined_name()

        if defined is None:
            return set()

        return {defined}

    def has_dependency(self, first: IRInstruction, second: IRInstruction) -> bool:
        use_first = set(first.used_names())
        def_first = self.get_def(first)

        use_second = set(second.used_names())
        def_second = self.get_def(second)

        raw = bool(def_first & use_second)
        war = bool(use_first & def_second)
        waw = bool(def_first & def_second)

        return raw or war or waw
