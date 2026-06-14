from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Set

from ir_nodes import IRFunction, IRInstruction, IRProgram, TERMINATOR_OPS


BLOCK_DELIMITER_WIDTH = 72


@dataclass
class CFGEdge:
    """Union dirigida entre bloques.

    Entradas: bloque origen, destino y condicion.
    Salida: arista serializable.
    Uso: texto CFG y .cfg.json.
    """

    source: str
    target: str
    kind: str
    condition: str
    terminator: str

    def to_jsonable(self) -> dict:
        """Entradas: arista. Salida: dict minimo para visualizador JSON. Uso: CFG JSON."""
        edge = {
            "from": self.source,
            "to": self.target,
        }
        if self.kind in {"true", "false"}:
            # Solo las ramas condicionales necesitan explicar la condicion.
            edge["condition"] = self.condition
        return edge

    def to_dot(self) -> str:
        """Entradas: arista CFG. Salida: linea DOT. Uso: CFG Graphviz."""
        source = dot_quote(self.source)
        target = dot_quote(self.target)
        if self.kind in {"true", "false"}:
            # Graphviz muestra la condicion sobre la flecha.
            return f"  {source} -> {target} [label={dot_quote(self.condition)}];"
        return f"  {source} -> {target};"


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
    edges: List[CFGEdge] = field(default_factory=list)

    def text(self, call_targets: List[str] | None = None) -> str:
        """Entradas: bloque y llamadas. Salida: texto con flujo. Uso: ProgramBlocks.text."""
        lines = [f"{self.name}:"]
        if self.predecessors:
            lines.append(f"  pred: {', '.join(sorted(self.predecessors))}")
        if self.successors:
            lines.append(f"  succ: {', '.join(sorted(self.successors))}")
        if call_targets:
            # Las llamadas son uniones visuales; no alteran succ/pred internos.
            lines.append(f"  calls: {', '.join(call_targets)}")
        for instruction in self.instructions:
            if instruction.op == "label" and instruction.dest == self.name:
                # El nombre del bloque ya representa ese label.
                continue
            lines.append(str(instruction))
        return "\n".join(lines)

    def to_jsonable(self) -> dict:
        """Entradas: bloque. Salida: nodo minimo serializable. Uso: CFG JSON."""
        return {
            "id": self.name,
        }


@dataclass
class FunctionBlocks:
    """CFG de una funcion.

    Entradas: nombre de funcion y bloques.
    Salida: vista de bloques por funcion.
    Uso: ProgramBlocks y archivos .blocks.
    """

    function_name: str
    blocks: List[BasicBlock] = field(default_factory=list)

    def text(self, call_targets_by_block: Dict[str, List[str]] | None = None) -> str:
        """Entradas: CFG de funcion. Salida: texto. Uso: reportes."""
        call_targets_by_block = call_targets_by_block or {}
        lines = [f"bloques {self.function_name}:"]
        for block in self.blocks:
            # Delimitadores visibles separan inicio/fin de cada bloque.
            lines.append(self._delimiter(f"inicio {block.name}"))
            lines.append(block.text(call_targets_by_block.get(block.name)))
            lines.append(self._delimiter(f"fin {block.name}"))
        return "\n".join(lines).rstrip()

    def _delimiter(self, label: str) -> str:
        """Entradas: etiqueta. Salida: separador visual. Uso: text."""
        text = f" {label} "
        padding = max(BLOCK_DELIMITER_WIDTH - len(text), 0)
        left = padding // 2
        right = padding - left
        return f"{'-' * left}{text}{'-' * right}"

    def to_jsonable(self) -> dict:
        """Entradas: CFG de funcion. Salida: nodos/aristas minimos. Uso: CFG JSON."""
        edges = [edge.to_jsonable() for block in self.blocks for edge in block.edges]
        nodes = [block.to_jsonable() for block in self.blocks]
        return {
            "nodes": nodes,
            "edges": edges,
        }


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
        call_targets_by_block = self._call_targets_by_block()
        return "\n\n".join(function.text(call_targets_by_block) for function in self.functions)

    def to_jsonable(self) -> dict:
        """Entradas: CFG del programa. Salida: nodes/edges para visualizador. Uso: CFG JSON."""
        # Vista plana: solo bloques y uniones entre bloques.
        nodes = [block.to_jsonable() for function in self.functions for block in function.blocks]
        edges = [edge.to_jsonable() for edge in self._visual_edges()]
        return {
            "nodes": nodes,
            "edges": edges,
        }

    def to_dot(self) -> str:
        """Entradas: CFG del programa. Salida: digraph DOT. Uso: Graphviz."""
        lines = ["digraph CFG {"]
        emitted_nodes: Set[str] = set()
        for function in self.functions:
            for block in function.blocks:
                if block.name in emitted_nodes:
                    continue
                emitted_nodes.add(block.name)
                # Cada bloque basico es un nodo del grafo.
                lines.append(f"  {dot_quote(block.name)};")
        for edge in self._visual_edges():
            lines.append(edge.to_dot())
        lines.append("}")
        return "\n".join(lines)

    def _visual_edges(self) -> List[CFGEdge]:
        """Entradas: CFG completo. Salida: aristas para JSON/DOT. Uso: visualizacion."""
        edges = [edge for function in self.functions for block in function.blocks for edge in block.edges]
        edges.extend(self._call_edges())
        return self._dedupe_edges(edges)

    def _call_edges(self) -> List[CFGEdge]:
        """Entradas: bloques con call. Salida: aristas visuales a funciones. Uso: reportes CFG."""
        edges: List[CFGEdge] = []
        entry_by_function = self._entry_blocks()
        for function in self.functions:
            for block in function.blocks:
                for instruction in block.instructions:
                    if instruction.op != "call" or not instruction.extra:
                        # Solo una llamada con nombre puede unir funciones en la vista.
                        continue
                    target = entry_by_function.get(instruction.extra)
                    if not target:
                        # Llamadas externas o no resueltas no tienen bloque local.
                        continue
                    edges.append(CFGEdge(block.name, target, "call", "", str(instruction).strip()))
        return self._dedupe_edges(edges)

    def _call_targets_by_block(self) -> Dict[str, List[str]]:
        """Entradas: aristas call. Salida: bloque->entradas llamadas. Uso: .blocks."""
        targets: Dict[str, List[str]] = {}
        for edge in self._call_edges():
            targets.setdefault(edge.source, []).append(edge.target)
        return targets

    def _entry_blocks(self) -> Dict[str, str]:
        """Entradas: funciones. Salida: funcion->primer bloque. Uso: aristas de call visuales."""
        entries: Dict[str, str] = {}
        for function in self.functions:
            if function.blocks:
                # El primer bloque es la entrada natural de la funcion.
                entries[function.function_name] = function.blocks[0].name
        return entries

    def _dedupe_edges(self, edges: List[CFGEdge]) -> List[CFGEdge]:
        """Entradas: aristas. Salida: lista sin duplicados. Uso: JSON/DOT limpio."""
        seen = set()
        unique: List[CFGEdge] = []
        for edge in edges:
            key = (edge.source, edge.target, edge.kind, edge.condition)
            if key in seen:
                continue
            seen.add(key)
            unique.append(edge)
        return unique


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
            edges = self._edges(block.name, last, blocks, index, label_to_block)
            block.edges.extend(edges)
            block.successors.update(edge.target for edge in edges)
            for successor in block.successors:
                if successor in block_by_name:
                    block_by_name[successor].predecessors.add(block.name)

        return FunctionBlocks(function.name, blocks)

    def _block_name(self, function_name: str, index: int, instructions: List[IRInstruction]) -> str:
        """Entradas: funcion, indice e instrucciones. Salida: label o nombre sintetico. Uso: build_function."""
        for instruction in instructions:
            if instruction.op == "label" and instruction.dest:
                return instruction.dest
        return f"{function_name}_B{index}"

    def _edges(
        self,
        source_block: str,
        instruction: IRInstruction,
        blocks: List[BasicBlock],
        block_index: int,
        label_to_block: Dict[str, str],
    ) -> List[CFGEdge]:
        """Entradas: terminador/contexto. Salida: aristas CFG. Uso: build_function."""
        edges: List[CFGEdge] = []
        fallthrough = blocks[block_index + 1].name if block_index + 1 < len(blocks) else None
        terminator = str(instruction).strip()

        if instruction.op == "goto":
            if instruction.target and instruction.target in label_to_block:
                # Salto incondicional: una sola salida posible.
                edges.append(CFGEdge(source_block, label_to_block[instruction.target], "unconditional", "always", terminator))
            # Un goto no cae al siguiente bloque.
            return edges

        if instruction.op in {"if", "if_false"}:
            condition_name = instruction.args[0] if instruction.args else "cond"
            if instruction.target and instruction.target in label_to_block:
                if instruction.op == "if_false":
                    kind = "false"
                    condition = f"{condition_name} == 0"
                else:
                    kind = "true"
                    condition = f"{condition_name} != 0"
                edges.append(CFGEdge(source_block, label_to_block[instruction.target], kind, condition, terminator))
            if fallthrough:
                if instruction.op == "if_false":
                    kind = "true"
                    condition = f"{condition_name} != 0"
                else:
                    kind = "false"
                    condition = f"{condition_name} == 0"
                edges.append(CFGEdge(source_block, fallthrough, kind, condition, terminator))
            return edges

        if instruction.op == "return":
            # Return cierra la funcion: no tiene sucesores.
            return edges

        if fallthrough:
            edges.append(CFGEdge(source_block, fallthrough, "fallthrough", "next", terminator))
        return edges


def dot_quote(value: str) -> str:
    """Entradas: texto. Salida: string escapado DOT. Uso: CFG Graphviz."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'
