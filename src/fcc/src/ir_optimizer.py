from __future__ import annotations

from dataclasses import dataclass, field
import re
from typing import Dict, List, Optional, Set, Tuple

from ir_nodes import IRFunction, IRInstruction, IRProgram, clone_instructions
from dead_code_elimination import DeadCodeEliminator
from instruction_reordering import SafeInstructionReorderer


UNROLL_BODY_INSTRUCTION_BUDGET = 96


@dataclass
class LoopUnrollLimit:
    """Resultado del limite de unrolling.

    Entradas: funcion, label, maximo y razon opcional.
    Salida: registro para reportes.
    Uso: analyze_unroll_limits y OptimizationReport.
    """
    function_name: str
    label_name: str
    max_factor: int
    reason: Optional[str] = None

    def text(self) -> str:
        """Entradas: limite. Salida: linea legible. Uso: report.text."""
        if self.max_factor >= 2:
            if self.reason:
                return f"{self.function_name}:{self.label_name} max={self.max_factor} ({self.reason})"
            return f"{self.function_name}:{self.label_name} max={self.max_factor}"
        return f"{self.function_name}:{self.label_name} no aplicable ({self.reason})"

@dataclass
class OptimizationReport:
    """Reporte de optimizacion IR.

    Entradas: contadores y listas de pases.
    Salida: resumen textual.
    Uso: fcc.py, .opt.report y consola.
    """
    loop_unrolled: List[str] = field(default_factory=list)
    loop_skipped: List[str] = field(default_factory=list)
    unroll_limits: List[str] = field(default_factory=list)
    renamed_defs: int = 0
    dead_code_removed: int = 0
    reordered_instructions: int = 0
    opt_level: str = "O0"
    unroll_factor: int = 1
    rename_statics: bool = False

    def text(self) -> str:
        """Entradas: reporte. Salida: texto. Uso: CLI/archivos."""
        lines = ["Reporte de optimizacion IR:"]
        lines.append(f"  Nivel: {self.opt_level}")
        lines.append(f"  Loop unrolling parcial: factor={self.unroll_factor}")
        lines.append(f"  Renombramiento de temporales/estaticos: {'si' if self.rename_statics else 'no'}")
        lines.append(f"  Renombramientos aplicados: {self.renamed_defs}")
        lines.append(f"  Eliminación de código muerto: {'sí' if self.opt_level == 'O3' else 'no'}")
        lines.append(f"  Instrucciones eliminadas por DCE: {self.dead_code_removed}")
        lines.append(f"  Reordenamiento seguro: {'sí' if self.opt_level == 'O4' else 'no'}")
        lines.append(f"  Instrucciones reordenadas: {self.reordered_instructions}")
        if self.loop_unrolled:
            lines.append("  Loops desenrollados:")
            for item in self.loop_unrolled:
                lines.append(f"    - {item}")
        if self.unroll_limits:
            lines.append("  Maximo factor detectado por loop:")
            for item in self.unroll_limits:
                lines.append(f"    - {item}")
        if self.loop_skipped:
            lines.append("  Loops no desenrollados:")
            for item in self.loop_skipped:
                lines.append(f"    - {item}")
        return "\n".join(lines)


class IROptimizer:
    """Optimizador TAC.

    Entradas: IRProgram y opciones -O.
    Salida: IRProgram transformado y reporte.
    Uso: ir_driver.optimize_ir y backend IR.
    """

    def __init__(self):
        """Entradas: ninguna. Salida: reporte inicial. Uso: optimize."""
        self.report = OptimizationReport()

    def optimize(
        self,
        program: IRProgram,
        unroll_factor: int = 1,
        rename_statics: bool = False,
        heuristic: bool = True,
        opt_level: str = "O0",
    ) -> tuple[IRProgram, OptimizationReport]:
        """Entradas: IR y flags. Salida: IR optimizada/reporte. Uso: fcc.py."""
        self.report = OptimizationReport(
            opt_level=opt_level,
            unroll_factor=unroll_factor,
            rename_statics=rename_statics,
        )
        if unroll_factor > 1:
            # Antes de transformar se valida que el factor sea legal para el programa.
            limits = self.analyze_unroll_limits(program, heuristic=heuristic)
            self.report.unroll_limits = [limit.text() for limit in limits]
            program_max = max((limit.max_factor for limit in limits), default=1)
            if program_max < unroll_factor:
                details = "; ".join(limit.text() for limit in limits) or "sin loops aplicables"
                raise ValueError(
                    f"--unroll-factor {unroll_factor} excede el maximo aplicable para este programa "
                    f"({program_max}). Detalle: {details}."
                )

        global_names = set(program.globals)
        optimized = IRProgram(globals=list(program.globals))
        for function in program.functions:
            # Cada funcion se clona para no mutar la IR original.
            current = IRFunction(
                name=function.name,
                params=list(function.params),
                return_type=function.return_type,
                instructions=clone_instructions(function.instructions),
            )
            if unroll_factor > 1:
                current = self.unroll_loops(
                    current,
                    unroll_factor,
                    heuristic=heuristic,
                )
            if rename_statics:
                current = self.rename_static_dependencies(current, protected_names=global_names)
            optimized.functions.append(current)

        # El dce va fuera del for, ya que recibe un IRProgram completo
        if opt_level == "O3":
            optimized, dce_result = DeadCodeEliminator().eliminate(optimized)
            self.report.dead_code_removed = dce_result.removed_count

        if opt_level == "O4":
            optimized, reordered_count = SafeInstructionReorderer().reorder_program(optimized)
            self.report.reordered_instructions = reordered_count
        return optimized, self.report

    def analyze_unroll_limits(self, program: IRProgram, heuristic: bool = True) -> List[LoopUnrollLimit]:
        """Entradas: IRProgram y heuristica. Salida: maximo por loop. Uso: validate O2."""
        limits: List[LoopUnrollLimit] = []
        for function in program.functions:
            instructions = function.instructions
            label_to_index = {
                instruction.dest: index
                for index, instruction in enumerate(instructions)
                if instruction.op == "label" and instruction.dest
            }

            index = 0
            while index < len(instructions):
                loop = self._find_loop_at(instructions, index, label_to_index)
                if loop is None:
                    # No hay loop iniciando aqui; se avanza linealmente.
                    index += 1
                    continue

                start, branch_index, back_index, _end_index = loop
                label_name = instructions[start].dest or f"{function.name}_loop"
                cond_segment = instructions[start + 1:branch_index + 1]
                body_segment = self._loop_body_segment(instructions, branch_index, back_index)
                pre_segment = instructions[:start]
                max_factor, reason = self._max_unroll_factor(pre_segment, cond_segment, body_segment, heuristic)
                limits.append(LoopUnrollLimit(function.name, label_name, max_factor, reason))
                index = back_index + 1
        return limits

    def unroll_loops(
        self,
        function: IRFunction,
        factor: int,
        heuristic: bool = True,
    ) -> IRFunction:
        """Entradas: funcion y factor. Salida: funcion con loops clonados. Uso: optimize."""

        instructions = function.instructions
        label_to_index = {
            instruction.dest: index
            for index, instruction in enumerate(instructions)
            if instruction.op == "label" and instruction.dest
        }

        result: List[IRInstruction] = []
        index = 0
        while index < len(instructions):
            loop = self._find_loop_at(instructions, index, label_to_index)
            if loop is None:
                # Instruccion fuera de loop: pasa intacta.
                result.append(instructions[index].clone())
                index += 1
                continue

            start, branch_index, back_index, end_index = loop
            label_name = instructions[start].dest or f"{function.name}_loop"
            # Segmentos: condicion, cuerpo y salto de regreso.
            cond_segment = instructions[start + 1:branch_index + 1]
            body_segment = self._loop_body_segment(instructions, branch_index, back_index)
            back_jump = instructions[back_index]

            pre_segment = instructions[:start]
            reason = self._unroll_rejection_reason(pre_segment, cond_segment, body_segment, factor, heuristic)
            if reason:
                # Se conserva intacto si el patron no es seguro.
                self.report.loop_skipped.append(f"{function.name}:{label_name} ({reason})")
                for item in instructions[start:end_index]:
                    result.append(item.clone())
                index = end_index
                continue

            result.append(instructions[start].clone())
            result.extend(clone_instructions(cond_segment))
            result.extend(clone_instructions(body_segment))

            for copy_index in range(1, factor):
                suffix = f"u{copy_index}"
                # Cada copia renombra temporales internos con sufijo uN.
                result.extend(self._clone_loop_segment(cond_segment, suffix))
                result.extend(self._clone_loop_segment(body_segment, suffix))

            result.append(back_jump.clone())
            self.report.loop_unrolled.append(f"{function.name}:{label_name} x{factor}")
            index = back_index + 1

        return IRFunction(function.name, list(function.params), function.return_type, result)

    def _loop_body_segment(
        self,
        instructions: List[IRInstruction],
        branch_index: int,
        back_index: int,
    ) -> List[IRInstruction]:
        """Entradas: TAC y limites del loop. Salida: cuerpo normalizado. Uso: unrolling."""
        segment = instructions[branch_index + 1:back_index]
        normalized: List[IRInstruction] = []
        for instruction in segment:
            if instruction.op == "label" and instruction.dest and "_for_update_" in instruction.dest:
                # El for baja a IR con label de update; no se clona porque no hay continue.
                continue
            normalized.append(instruction)
        return normalized

    def _find_loop_at(
        self,
        instructions: List[IRInstruction],
        start: int,
        label_to_index: Dict[str, int],
    ) -> Optional[tuple[int, int, int, int]]:
        """Entradas: TAC, indice y labels. Salida: rango de loop o None. Uso: unrolling/analisis."""
        if start >= len(instructions) or instructions[start].op != "label" or not instructions[start].dest:
            return None

        label = instructions[start].dest
        branch_index = None
        end_label = None
        scan_limit = min(len(instructions), start + 120)
        for index in range(start + 1, scan_limit):
            instruction = instructions[index]
            if instruction.op in {"if_false", "if"} and instruction.target:
                # Primer branch despues del label se toma como condicion del loop.
                branch_index = index
                end_label = instruction.target
                break
            if instruction.op == "label":
                # Otro label antes de condicion rompe el patron simple.
                return None

        if branch_index is None or end_label is None:
            return None

        for index in range(branch_index + 1, scan_limit):
            instruction = instructions[index]
            if instruction.op == "goto" and instruction.target == label:
                end_index = index + 1
                if end_label in label_to_index:
                    end_index = max(end_index, label_to_index[end_label])
                return (start, branch_index, index, end_index)
            if instruction.op == "return":
                # Un return dentro del cuerpo impide desenrollado seguro.
                return None
        return None

    def _unroll_rejection_reason(
        self,
        pre_segment: List[IRInstruction],
        cond_segment: List[IRInstruction],
        body_segment: List[IRInstruction],
        factor: int,
        heuristic: bool,
    ) -> Optional[str]:
        """Entradas: segmentos de loop/factor. Salida: razon de rechazo o None. Uso: unroll_loops."""
        if factor < 2:
            return "factor menor que 2"
        if not body_segment:
            return "cuerpo vacio"
        if any(instruction.op == "label" for instruction in body_segment):
            # Labels internos requieren analisis de flujo mas fino.
            return "cuerpo con labels internos"
        if any(instruction.op in {"goto", "if", "if_false", "return"} for instruction in body_segment):
            return "cuerpo con control de flujo interno"
        if any(instruction.op == "call" for instruction in body_segment):
            return "cuerpo con llamadas"
        if len(cond_segment) > 16:
            return "condicion demasiado grande"
        max_factor, _reason = self._max_unroll_factor(pre_segment, cond_segment, body_segment, heuristic)
        if factor > max_factor:
            # El factor pedido supera dependencias/trip count/heuristica.
            return f"factor {factor} mayor al maximo aplicable {max_factor}"
        return None

    def _max_unroll_factor(
        self,
        pre_segment: List[IRInstruction],
        cond_segment: List[IRInstruction],
        body_segment: List[IRInstruction],
        heuristic: bool,
    ) -> tuple[int, Optional[str]]:
        """Entradas: segmentos de loop. Salida: factor maximo y razon. Uso: validacion O2."""
        if not body_segment:
            return (1, "cuerpo vacio")
        if any(instruction.op == "label" for instruction in body_segment):
            return (1, "cuerpo con labels internos")
        if any(instruction.op in {"goto", "if", "if_false", "return"} for instruction in body_segment):
            return (1, "cuerpo con control de flujo interno")
        if any(instruction.op == "call" for instruction in body_segment):
            return (1, "cuerpo con llamadas")
        if len(cond_segment) > 16:
            return (1, "condicion demasiado grande")
        loop_var = self._infer_loop_variable(body_segment)
        if loop_var is None:
            return (1, "variable de control no identificada")
        loop_step = self._infer_loop_step(body_segment, loop_var)
        if loop_step is None or loop_step <= 0:
            return (1, "paso de loop no identificado")

        dependency_max, dependency_reason = self._loop_dependency_limit(body_segment, loop_var, loop_step)
        if dependency_max == 1:
            # Distancia 1 o dependencia escalar no admite factor mayor.
            return (1, dependency_reason)

        trip_count = self._infer_trip_count(pre_segment, cond_segment, body_segment, loop_var)
        if heuristic:
            max_factor = UNROLL_BODY_INSTRUCTION_BUDGET // len(body_segment)
            if trip_count is not None:
                max_factor = min(max_factor, trip_count)
            if dependency_max is not None:
                max_factor = min(max_factor, dependency_max)
            if max_factor < 2:
                # El cuerpo creceria demasiado para esta heuristica.
                return (1, "heuristica: cuerpo demasiado grande")
            return (max_factor, dependency_reason)

        max_factor = trip_count if trip_count is not None else len(body_segment)
        if dependency_max is not None:
            max_factor = min(max_factor, dependency_max)
        return (max_factor, dependency_reason)

    def _infer_loop_variable(self, body_segment: List[IRInstruction]) -> Optional[str]:
        """Entradas: cuerpo del loop. Salida: variable de control o None. Uso: dependencias."""
        definitions: Dict[str, IRInstruction] = {}
        constants: Dict[str, int] = {}
        for instruction in body_segment:
            if instruction.op == "const" and instruction.dest and instruction.extra is not None:
                value = self._parse_int(instruction.extra)
                if value is not None:
                    constants[instruction.dest] = value
            if instruction.dest:
                definitions[instruction.dest] = instruction
            if instruction.op != "assign" or not instruction.dest or not instruction.args:
                continue

            source = definitions.get(instruction.args[0])
            if source is None or source.op != "binop" or source.extra not in {"+", "-"}:
                continue
            if (
                len(source.args) >= 2
                and source.args[0] == instruction.dest
                and self._resolve_constant(source.args[1], constants) is not None
            ):
                # Patron k = k + c / k = k - c: es el contador del loop.
                return instruction.dest
        return None

    def _infer_trip_count(
        self,
        pre_segment: List[IRInstruction],
        cond_segment: List[IRInstruction],
        body_segment: List[IRInstruction],
        loop_var: str,
    ) -> Optional[int]:
        """Entradas: pre/cond/body y contador. Salida: iteraciones si son constantes. Uso: max factor."""
        constants = self._constant_environment(pre_segment + cond_segment)
        start = constants.get(loop_var)
        step = self._infer_loop_step(body_segment, loop_var)
        if start is None or step is None or step <= 0:
            return None

        for instruction in cond_segment:
            if instruction.op != "binop" or instruction.extra not in {"<", "<="} or len(instruction.args) < 2:
                continue
            if instruction.args[0] != loop_var:
                continue
            bound = self._resolve_constant(instruction.args[1], constants)
            if bound is None:
                continue
            if instruction.extra == "<":
                # Conteo entero para k < bound con paso positivo.
                return max(0, (bound - start + step - 1) // step)
            return max(0, ((bound - start) // step) + 1)
        return None

    def _infer_loop_step(self, body_segment: List[IRInstruction], loop_var: str) -> Optional[int]:
        """Entradas: cuerpo y contador. Salida: paso constante o None. Uso: trip count/dependencias."""
        definitions: Dict[str, IRInstruction] = {}
        constants: Dict[str, int] = {}
        for instruction in body_segment:
            if instruction.op == "const" and instruction.dest and instruction.extra is not None:
                value = self._parse_int(instruction.extra)
                if value is not None:
                    constants[instruction.dest] = value
            if instruction.dest:
                definitions[instruction.dest] = instruction
            if instruction.op != "assign" or instruction.dest != loop_var or not instruction.args:
                continue

            source = definitions.get(instruction.args[0])
            if source is None or source.op != "binop" or len(source.args) < 2:
                continue
            if source.args[0] != loop_var:
                continue
            delta = self._resolve_constant(source.args[1], constants)
            if delta is None:
                continue
            if source.extra == "+":
                return delta
            if source.extra == "-":
                return -delta
        return None

    def _constant_environment(self, instructions: List[IRInstruction]) -> Dict[str, int]:
        """Entradas: TAC. Salida: constantes conocidas por nombre. Uso: indices/trip count."""
        constants: Dict[str, int] = {}
        for instruction in instructions:
            if instruction.op == "const" and instruction.dest and instruction.extra is not None:
                value = self._parse_int(instruction.extra)
                if value is not None:
                    constants[instruction.dest] = value
            elif instruction.op == "assign" and instruction.dest and instruction.args:
                value = self._resolve_constant(instruction.args[0], constants)
                if value is not None:
                    constants[instruction.dest] = value
        return constants

    def _loop_dependency_limit(
        self,
        body_segment: List[IRInstruction],
        loop_var: str,
        loop_step: int,
    ) -> tuple[Optional[int], Optional[str]]:
        """Entradas: cuerpo, contador y paso. Salida: limite por dependencias. Uso: max factor."""
        array_reads, array_writes = self._array_accesses(body_segment, loop_var)
        min_distance: Optional[int] = None
        min_reason: Optional[str] = None

        for written_array, write_offset in array_writes:
            for array_name, read_offset in array_reads:
                if array_name != written_array:
                    continue
                distance = self._iteration_distance(write_offset - read_offset, loop_step)
                if distance is not None:
                    # RAW: una escritura futura depende de lectura pasada del mismo arreglo.
                    min_distance, min_reason = self._select_min_dependency(
                        min_distance,
                        min_reason,
                        distance,
                        f"distancia verdadera {distance} en {array_name}[k]",
                    )

                anti_distance = self._iteration_distance(read_offset - write_offset, loop_step)
                if anti_distance is not None:
                    # WAR: una escritura puede pisar una lectura pendiente.
                    min_distance, min_reason = self._select_min_dependency(
                        min_distance,
                        min_reason,
                        anti_distance,
                        f"distancia WAR {anti_distance} en {array_name}[k]",
                    )

        for first_index, (array_name, first_offset) in enumerate(array_writes):
            for written_array, second_offset in array_writes[first_index + 1:]:
                if array_name != written_array:
                    continue
                distance = self._iteration_distance(abs(first_offset - second_offset), loop_step)
                if distance is not None:
                    # WAW: dos escrituras a posiciones relacionadas limitan reordenamiento.
                    min_distance, min_reason = self._select_min_dependency(
                        min_distance,
                        min_reason,
                        distance,
                        f"distancia WAW {distance} en {array_name}[k]",
                    )

        scalar_reads, scalar_writes = self._scalar_accesses(body_segment, loop_var)
        dependent_scalars = sorted(scalar_reads & scalar_writes)
        if dependent_scalars:
            if min_distance == 1 and min_reason is not None:
                return (min_distance, min_reason)
            # Escalares acumuladores tienen dependencia de distancia 1.
            return (1, f"dependencia escalar entre iteraciones en {dependent_scalars[0]}")

        return (min_distance, min_reason)

    def _iteration_distance(self, offset_delta: int, loop_step: int) -> Optional[int]:
        """Entradas: delta de offsets y paso. Salida: distancia en iteraciones. Uso: dependencias."""
        if offset_delta <= 0 or loop_step <= 0:
            return None
        if offset_delta % loop_step != 0:
            return None
        distance = offset_delta // loop_step
        return distance if distance > 0 else None

    def _select_min_dependency(
        self,
        current_distance: Optional[int],
        current_reason: Optional[str],
        candidate_distance: int,
        candidate_reason: str,
    ) -> tuple[int, str]:
        """Entradas: distancia actual/candidata. Salida: dependencia mas restrictiva. Uso: analisis."""
        if current_distance is None or candidate_distance < current_distance:
            return (candidate_distance, candidate_reason)
        return (current_distance, current_reason or candidate_reason)

    def _array_accesses(
        self,
        body_segment: List[IRInstruction],
        loop_var: str,
    ) -> tuple[List[Tuple[str, int]], List[Tuple[str, int]]]:
        """Entradas: cuerpo y contador. Salida: lecturas/escrituras array k+cte. Uso: dependencias."""
        constants: Dict[str, int] = {}
        affine: Dict[str, Tuple[str, int]] = {loop_var: (loop_var, 0)}
        reads: List[Tuple[str, int]] = []
        writes: List[Tuple[str, int]] = []

        for instruction in body_segment:
            self._record_constant_and_affine(instruction, constants, affine, loop_var)
            if instruction.op == "load_index" and len(instruction.args) >= 2:
                index = self._resolve_affine(instruction.args[1], constants, affine, loop_var)
                if index is not None:
                    # Solo indices afines al contador participan en distancia.
                    reads.append((instruction.args[0], index[1]))
            elif instruction.op == "store_index" and len(instruction.args) >= 2:
                index = self._resolve_affine(instruction.args[1], constants, affine, loop_var)
                if index is not None:
                    writes.append((instruction.args[0], index[1]))
        return reads, writes

    def _record_constant_and_affine(
        self,
        instruction: IRInstruction,
        constants: Dict[str, int],
        affine: Dict[str, Tuple[str, int]],
        loop_var: str,
    ) -> None:
        """Entradas: instruccion y mapas. Salida: actualiza constantes/afines. Uso: _array_accesses."""
        if instruction.op == "const" and instruction.dest and instruction.extra is not None:
            value = self._parse_int(instruction.extra)
            if value is not None:
                constants[instruction.dest] = value
            return

        if instruction.op == "assign" and instruction.dest and instruction.args:
            resolved = self._resolve_affine(instruction.args[0], constants, affine, loop_var)
            if resolved is not None:
                # Propaga copias como t = k - 2.
                affine[instruction.dest] = resolved
            return

        if instruction.op != "binop" or not instruction.dest or len(instruction.args) < 2:
            return

        left = self._resolve_affine(instruction.args[0], constants, affine, loop_var)
        right = self._resolve_affine(instruction.args[1], constants, affine, loop_var)
        right_const = self._resolve_constant(instruction.args[1], constants)
        left_const = self._resolve_constant(instruction.args[0], constants)

        if instruction.extra == "+":
            if left is not None and right_const is not None:
                affine[instruction.dest] = (left[0], left[1] + right_const)
            elif right is not None and left_const is not None:
                affine[instruction.dest] = (right[0], right[1] + left_const)
        elif instruction.extra == "-" and left is not None and right_const is not None:
            affine[instruction.dest] = (left[0], left[1] - right_const)

    def _resolve_affine(
        self,
        value: str,
        constants: Dict[str, int],
        affine: Dict[str, Tuple[str, int]],
        loop_var: str,
    ) -> Optional[Tuple[str, int]]:
        """Entradas: nombre y mapas. Salida: (contador, offset) o None. Uso: indices."""
        if value == loop_var:
            return (loop_var, 0)
        return affine.get(value)

    def _resolve_constant(self, value: str, constants: Dict[str, int]) -> Optional[int]:
        """Entradas: literal/nombre. Salida: entero o None. Uso: indices y pasos."""
        parsed = self._parse_int(value)
        if parsed is not None:
            return parsed
        return constants.get(value)

    def _parse_int(self, value: str) -> Optional[int]:
        """Entradas: texto. Salida: int o None. Uso: constantes TAC."""
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    def _scalar_accesses(
        self,
        body_segment: List[IRInstruction],
        loop_var: str,
    ) -> tuple[Set[str], Set[str]]:
        """Entradas: cuerpo y contador. Salida: escalares leidos/escritos. Uso: dependencias."""
        reads: Set[str] = set()
        writes: Set[str] = set()
        for instruction in body_segment:
            for index, arg in enumerate(instruction.args):
                if instruction.op in {"load_index", "store_index"} and index == 0:
                    continue
                if self._is_user_scalar(arg, loop_var):
                    reads.add(arg)

            defined = instruction.defined_name()
            if defined and self._is_user_scalar(defined, loop_var):
                writes.add(defined)
        return reads, writes

    def _is_user_scalar(self, name: str, loop_var: str) -> bool:
        """Entradas: nombre y contador. Salida: True si escalar de usuario. Uso: dependencias."""
        if name == loop_var or self._is_temp(name):
            return False
        return bool(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name))

    def _clone_loop_segment(self, segment: List[IRInstruction], suffix: str) -> List[IRInstruction]:
        """Entradas: TAC y sufijo. Salida: copia con temporales nuevos. Uso: unrolling."""
        mapping: Dict[str, str] = {}
        cloned: List[IRInstruction] = []

        for instruction in segment:
            copy = instruction.clone()
            copy.replace_uses(mapping)
            if copy.dest and self._is_temp(copy.dest):
                new_name = f"{copy.dest}_{suffix}"
                mapping[copy.dest] = new_name
                copy.dest = new_name
            cloned.append(copy)
        return cloned

    def rename_static_dependencies(
        self,
        function: IRFunction,
        protected_names: Optional[Set[str]] = None,
    ) -> IRFunction:
        """Entradas: funcion y nombres protegidos. Salida: funcion versionada. Uso: optimize O1/O2."""

        versions: Dict[str, int] = {}
        current_name: Dict[str, str] = {}
        protected = set(protected_names or set())
        protected.update(self._address_taken_names(function.instructions))
        # Sin phi, variables de usuario solo se versionan en codigo lineal.
        allow_user_variables = not any(
            instruction.op in {"label", "goto", "if", "if_false"}
            for instruction in function.instructions
        )
        renamed: List[IRInstruction] = []

        for param in function.params:
            current_name[param] = param

        for instruction in function.instructions:
            copy = instruction.clone()
            if copy.op == "label":
                # Labels delimitan flujo; no tienen usos versionables.
                renamed.append(copy)
                continue

            use_replacements = self._use_replacements(copy, current_name)
            copy.replace_uses(use_replacements)

            defined = copy.defined_name()
            if defined and self._can_rename(defined, allow_user_variables, protected):
                # Nueva version: los usos posteriores apuntan a este nombre.
                new_name = self._new_version(defined, versions)
                copy.dest = new_name
                current_name[defined] = new_name
                self.report.renamed_defs += 1
            renamed.append(copy)

        return IRFunction(function.name, list(function.params), function.return_type, renamed)

    def _use_replacements(self, instruction: IRInstruction, current_name: Dict[str, str]) -> Dict[str, str]:
        """Entradas: instruccion y versiones vigentes. Salida: usos a reemplazar. Uso: renombramiento."""
        replacements: Dict[str, str] = {}
        for position, arg in enumerate(instruction.args):
            if instruction.op in {"load_index", "store_index"} and position == 0:
                # La base de arreglo es ubicacion, no valor versionable.
                continue
            if instruction.op == "addr":
                continue
            if arg in current_name:
                replacements[arg] = current_name[arg]
        return replacements

    def _new_version(self, name: str, versions: Dict[str, int]) -> str:
        """Entradas: nombre base y contadores. Salida: nombre versionado. Uso: renombramiento."""
        versions[name] = versions.get(name, 0) + 1
        safe = re.sub(r"[^A-Za-z0-9_]", "_", name)
        return f"{safe}_{versions[name]}"

    def _address_taken_names(self, instructions: List[IRInstruction]) -> Set[str]:
        """Entradas: TAC. Salida: nombres usados con &. Uso: proteger aliasing."""
        names: Set[str] = set()
        for instruction in instructions:
            if instruction.op == "addr" and instruction.args:
                names.add(instruction.args[0])
        return names

    def _can_rename(self, name: str, allow_user_variables: bool, protected_names: Set[str]) -> bool:
        """Entradas: nombre y politica. Salida: True si se puede versionar. Uso: rename."""
        if not name or name == "_" or name.startswith("__") or name in protected_names:
            return False
        return self._is_temp(name) or allow_user_variables

    def _is_temp(self, name: str) -> bool:
        """Entradas: nombre. Salida: True si es tN. Uso: unrolling/rename."""
        return bool(re.fullmatch(r"t\d+", name))
