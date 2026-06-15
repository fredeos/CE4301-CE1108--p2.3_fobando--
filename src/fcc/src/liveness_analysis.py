from __future__ import annotations
from dataclasses import dataclass, field
from basic_blocks import BasicBlock, FunctionBlocks, ProgramBlocks
from ir_nodes import IRInstruction
from typing import Dict, Set


@dataclass
class LivenessResult:
    gen: Dict[str, Set[str]] = field(default_factory=dict)
    kill: Dict[str, Set[str]] = field(default_factory=dict)
    in_sets: Dict[str, Set[str]] = field(default_factory=dict)
    out_sets: Dict[str, Set[str]] = field(default_factory=dict)


class LivenessAnalyzer:
    def analyze_liveness(self, program: ProgramBlocks) -> Dict[str, LivenessResult]:
        results = {}
        for function_blocks in program.functions:
            result = self.analyze_function(function_blocks)
            results[function_blocks.function_name] = result
        return results

    def analyze_function(self, function_blocks: FunctionBlocks) -> LivenessResult:
        liveness = LivenessResult()
        # paso 1: update the local data flow for each basic block
        for basic_block in function_blocks.blocks:
            gen, kill = self.define_ldf(basic_block)
            liveness.gen[basic_block.name] = gen
            liveness.kill[basic_block.name] = kill
        # paso 2: define ins and outs
        liveness = self.define_gdf(liveness, function_blocks.blocks)
        return liveness

    def define_gdf(self, liveness: LivenessResult, basic_blocks: list[BasicBlock]) -> LivenessResult:
        """Aqui calculamos in[B] y out[B] por cada bloque
        debe de ir del ultimo bloque al primero"""

        reversed_blocks = list(reversed(basic_blocks))
        for b in reversed_blocks:
            liveness.in_sets[b.name] = set()
            liveness.out_sets[b.name] = set()

        # changed nos va a ayudar a verificar que ya no hay cambios en las iteraciones
        changed = True
        while changed:
            changed = False  # para salirnos a la siguiente iteracion

            for b in reversed_blocks:
                old_in = set(liveness.in_sets[b.name])
                old_out = set(liveness.out_sets[b.name])

                # out = U in[sucesores]
                new_out = set()
                for successor in b.successors:
                    new_out.update(liveness.in_sets[successor])

                # in = gen[b] U (out[B]-kill[B])
                new_in = liveness.gen[b.name] | (new_out - liveness.kill[b.name])

                liveness.out_sets[b.name] = new_out
                liveness.in_sets[b.name] = new_in

                if old_in != new_in or old_out != new_out:
                    # si el bloque cambio sus ins o outs significa que se ocupa otra iteracion
                    changed = True
        return liveness

    def define_ldf(self, basic_block: BasicBlock) -> tuple[set[str], set[str]]:
        """define local data flow"""
        gen = set()
        kill = set()
        for instr in basic_block.instructions:
            if instr.op == 'label':
                continue

            # obtener los args
            for arg in instr.args:
                if arg not in kill:
                    gen.add(arg)
            # obtener el kill
            defined = instr.defined_name()
            if defined is not None:
                kill.add(defined)
        return gen, kill
