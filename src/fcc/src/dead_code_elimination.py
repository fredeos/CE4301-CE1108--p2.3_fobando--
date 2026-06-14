from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List

from basic_blocks import BasicBlock, BasicBlockBuilder, ProgramBlocks
from ir_nodes import IRFunction, IRInstruction, IRProgram
from liveness_analysis import LivenessAnalyzer


@dataclass
class DeadCodeResult:
    removed_count: int = 0
    removed_instructions: Dict[str, List[IRInstruction]] = field(default_factory=dict)


class DeadCodeEliminator:
    def __init__(self):
        self.liveness_analyzer = LivenessAnalyzer()

        # Estas operaciones se pueden eliminar si su resultado no se usa
        # Son operaciones "puras" no afectan memoria, no saltan
        self.removable_ops = {
            "const",
            "assign",
            "binop",
            "unop",
            "addr",
            "load_index",
        }

    def eliminate(self, program: IRProgram) -> tuple[IRProgram, DeadCodeResult]:
        """
        Elimina código muerto usando análisis de variables vivas.
        Devuelve un nuevo IRProgram optimizado y un reporte de DCE.
        """

        current_program = IRProgram(
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

        total_result = DeadCodeResult()
        block_builder = BasicBlockBuilder()
        observable_globals = set(current_program.globals)
        changed = True

        while changed:
            changed = False

            # 1. Construir bloques básicos desde el IRProgram actual
            program_blocks = block_builder.build_program(current_program)

            # 2. Calcular liveness sobre ProgramBlocks
            liveness_results = self.liveness_analyzer.analyze_liveness(program_blocks)

            # 3. Aplicar DCE sobre los bloques
            for function_blocks in program_blocks.functions:
                function_name = function_blocks.function_name
                liveness = liveness_results[function_name]

                for basic_block in function_blocks.blocks:
                    removed = self.eliminate_block_dead_code(
                        basic_block,
                        liveness.out_sets[basic_block.name],
                        observable_globals,
                    )

                    if removed:
                        # si se elimina algo que vuelva a revisar para ver si se puede eliminar algo mas
                        changed = True
                        total_result.removed_count += len(removed)

                        # llave para identificar en que funcion y bloque se eliminaron las instrucciones
                        key = f"{function_name}.{basic_block.name}"
                        # si no existe una lista en ese bloque crearla
                        if key not in total_result.removed_instructions:
                            total_result.removed_instructions[key] = []

                        # add a las instrucciones eliminadas
                        total_result.removed_instructions[key].extend(removed)

            # 4. Reconstruir IRProgram desde los bloques modificados
            current_program = self.rebuild_program_from_blocks(
                current_program,
                program_blocks,
            )
        #print(total_result.removed_instructions)

        return current_program, total_result

    def eliminate_block_dead_code(
        self,
        basic_block: BasicBlock,
        out_set: set[str],
        observable_globals: set[str],
    ) -> List[IRInstruction]:
        """
        Elimina instrucciones muertas dentro de un bloque básico.
        Se recorre de abajo hacia arriba porque el liveness es un análisis hacia atrás.
        """
        live = set(out_set) # variables vivas
        new_instructions_reversed = [] # instrucciones vivvas :D
        removed_instructions = [] # instrucciones muertas

        # recorrer instrucciones de abajo a arriba
        for instr in reversed(basic_block.instructions):
            defined = instr.defined_name()

            if self.is_dead_instruction(instr, defined, live, observable_globals):
                removed_instructions.append(instr)
                continue

            if defined is not None:
                live.discard(defined)

            for arg in instr.used_names():
                # si la instr usa variables, las mismas deben de estar vivas
                live.add(arg)

            new_instructions_reversed.append(instr)

        basic_block.instructions = list(reversed(new_instructions_reversed))

        return removed_instructions

    def is_dead_instruction(
        self,
        instr: IRInstruction,
        defined: str | None,
        live: set[str],
        observable_globals: set[str],
    ) -> bool:
        """
        Una instrucción es ccdigo muerto si:
        - define una variable,
        - esa variable no esta viva después de la instrucción,
        - y la operacion no tiene efectos secundarios.
        """

        if defined is None:
            # si no define nada, no se borra (return, goto, label, ...)
            return False

        if defined in observable_globals:
            # Una escritura global es visible desde memoria y no se elimina.
            return False

        if defined in live:
            return False

        if instr.op not in self.removable_ops:
            return False

        return True

    def rebuild_program_from_blocks(self,previous_program: IRProgram, program_blocks: ProgramBlocks,) -> IRProgram:
        """
        Reconstruye un IRProgram lineal a partir de los bloques modificados.
        """

        function_info = {
            function.name: function
            for function in previous_program.functions
        }

        rebuilt_program = IRProgram(globals=list(previous_program.globals))

        for function_blocks in program_blocks.functions:
            original_function = function_info[function_blocks.function_name]

            rebuilt_instructions = []

            for basic_block in function_blocks.blocks:
                rebuilt_instructions.extend(basic_block.instructions)

            rebuilt_function = IRFunction(
                name=original_function.name,
                params=list(original_function.params),
                return_type=original_function.return_type,
                instructions=rebuilt_instructions,
            )

            rebuilt_program.functions.append(rebuilt_function)

        return rebuilt_program

