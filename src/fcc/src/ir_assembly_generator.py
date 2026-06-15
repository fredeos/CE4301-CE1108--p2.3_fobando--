from __future__ import annotations

from typing import Dict, List, Optional, Set

from ast_nodes import FunctionDeclNode, ProgramNode, VarDeclNode
from assembly_generator import (
    ARITHMETIC_OPS,
    AssemblyGenerator,
    AssemblyResult,
    BRANCH_TRUE_OPS,
    CodegenDiagnostic,
    AddressRef,
    LabelRef,
    StackBaseRef,
    SAVE_REGS,
    WORD_SIZE,
)
from ir_nodes import IRFunction, IRInstruction, IRProgram
from symbol_table import PARAM_REGISTER_LIMIT, PROGRAM_RESULT_SYMBOL, Scope, Symbol, SymbolTable, TypeInfo


class IRAssemblyGenerator(AssemblyGenerator):
    """Backend de TAC a ensamblador.

    Entradas: IRProgram, AST y tabla de simbolos.
    Salida: AssemblyResult listo para binarizar.
    Uso: fcc.py con -O/--ir-backend.
    """

    def __init__(self):
        """Entradas: ninguna. Salida: estado IR limpio. Uso: generate_from_ir."""
        super().__init__()
        self.function_ast_by_name: Dict[str, FunctionDeclNode] = {}
        self.ir_symbol_map: Dict[str, Symbol] = {}
        self.ir_virtual_offsets: Dict[str, int] = {}
        self.ir_virtual_types: Dict[str, TypeInfo] = {}
        self.ir_param_stride_registers: Dict[str, str] = {}
        self.ir_pending_params: List[str] = []
        self.ir_slot_size = 0
        self.ir_current_total_frame = 0

    def generate_from_ir(
        self,
        ir_program: IRProgram,
        ast_program: ProgramNode,
        symbol_table: SymbolTable,
        emit_entrypoint: bool = True,
    ) -> AssemblyResult:
        """Entradas: IR, AST y simbolos. Salida: ASM o diagnosticos. Uso: fcc.py."""
        self.symbol_table = symbol_table
        self.scope_by_name = {scope.name: scope for scope in symbol_table.all_scopes}
        self.current_scope = symbol_table.global_scope
        self.emit_entrypoint = emit_entrypoint
        # El AST se conserva para inicializadores, secure y firmas.
        self.function_ast_by_name = {
            decl.name: decl for decl in ast_program.declarations if isinstance(decl, FunctionDeclNode)
        }

        self._emit_comment("; Codigo ensamblador generado por FCC")
        self._emit_comment("; Backend: IR TAC")
        self._emit_ir_program(ir_program, ast_program)

        if self.diagnostics:
            # Errores tempranos cancelan renderizado.
            return AssemblyResult(diagnostics=self.diagnostics)

        rendered_lines = self._render_items()
        if self.diagnostics:
            return AssemblyResult(diagnostics=self.diagnostics)

        return AssemblyResult(lines=rendered_lines)

    def _emit_ir_program(self, ir_program: IRProgram, ast_program: ProgramNode):
        """Entradas: programa IR/AST. Salida: items ASM. Uso: generate_from_ir."""
        if self.emit_entrypoint:
            main_symbol = self.symbol_table.global_scope.symbols.get("main")
            if main_symbol is None or main_symbol.kind != "function":
                self.diagnostics.append(
                    CodegenDiagnostic(
                        line=ast_program.line,
                        column=ast_program.column,
                        code="missing_main_entrypoint",
                        message='no se encontro una funcion "main" para generar el punto de entrada.',
                    )
                )
                return

            self._emit_label("__init__")
            self._emit("li", "sp", StackBaseRef())
            for decl in ast_program.declarations:
                if isinstance(decl, VarDeclNode):
                    # Las globales aun se inicializan desde el AST original.
                    self._emit_global_initializers(decl)

            self._emit("mov", "p0", "zero", comment="resultado de programa por defecto")
            self._emit("call", LabelRef("main"), comment="entrada principal")
            self._emit_end_marker(comment="fin real del programa tras retornar de main")
            self._emit_label("__end_fallback__")
            self._emit("jmp", LabelRef("__end_fallback__"), comment="respaldo si end se interpreta como nop")

        for function in ir_program.functions:
            # Se emiten todas las funciones despues del punto de entrada.
            self._emit_ir_function(function)

        # end marca el cierre fisico y debe quedar despues de todo el codigo IR.
        self._emit_end_marker(comment="cierre fisico del stream IR")

    def _emit_end_marker(self, comment: Optional[str] = None):
        """Entradas: comentario opcional. Salida: 3 nop y end. Uso: cierre ASM."""
        for _ in range(3):
            self._emit("nop", comment="relleno antes de end")
        self._emit("end", comment=comment)

    def _emit_ir_function(self, function: IRFunction):
        """Entradas: funcion IR. Salida: prologo, cuerpo y epilogo. Uso: _emit_ir_program."""
        function_symbol = self.symbol_table.global_scope.symbols.get(function.name)
        if function_symbol is None:
            # Funcion no registrada por semantica: no se puede bajar.
            return

        function_ast = self.function_ast_by_name.get(function.name)
        if function_ast is None:
            self.diagnostics.append(
                CodegenDiagnostic(
                    line=0,
                    column=0,
                    code="missing_function_ast",
                    message=f'no se encontro el AST de la funcion "{function.name}" para generar IR.',
                )
            )
            return

        return_type = function_symbol.return_type
        if (
            return_type is not None
            and not return_type.is_void
            and not self._ensure_codegen_type(return_type, function_ast, f'retorno de "{function.name}"')
        ):
            return

        previous_scope = self._push_scope(f"function:{function.name}")
        # Guardar estado evita contaminar la siguiente funcion.
        previous_function = self.current_function
        previous_function_symbol = self.current_function_symbol
        previous_secure = self.current_function_secure
        previous_secure_exit_label = self.current_secure_exit_label
        previous_homed_params = self.current_homed_params
        previous_param_stride_registers = self.ir_param_stride_registers

        self.current_function = function_ast
        self.current_function_symbol = function_symbol
        # Secure se conserva desde el AST porque la IR no modela anotaciones.
        self.current_function_secure = function_ast.secure is not None
        self.current_secure_exit_label = self._new_label("secure_exit") if function_ast.secure is not None else None
        self.current_call_spill_max = 0
        self.current_homed_params = set()
        self.ir_pending_params = []
        self.ir_virtual_types = {}
        self._reset_temp_pool()

        self.current_local_size = function_symbol.extra.get("local_size", 0)
        self.ir_symbol_map = self._collect_function_symbols(function.name)
        self.ir_param_stride_registers = self._assign_dynamic_stride_registers(function_ast)
        homed_params = self._collect_ir_parameter_homes(function)
        # El allocator materializa cada temporal/version IR en un slot estable.
        self.ir_virtual_offsets = self._allocate_ir_slots(function)
        self.ir_slot_size = len(self.ir_virtual_offsets) * WORD_SIZE
        # Parametros con direccion tomada necesitan copia en stack.
        self.current_param_shadow_offsets = {
            param.name: self.current_saved_area + self.current_local_size + self.ir_slot_size + (index * WORD_SIZE)
            for index, param in enumerate(function_ast.params)
            if param.name in homed_params
        }
        self.ir_current_total_frame = (
            self.current_saved_area
            + self.current_local_size
            + self.ir_slot_size
            + (len(self.current_param_shadow_offsets) * WORD_SIZE)
        )

        self._emit_label(function.name)
        # Prologo: reserva frame y guarda registros que deben sobrevivir.
        self._emit_sp_adjust(self.ir_current_total_frame)
        for index, register in enumerate(SAVE_REGS):
            self._emit("stw", register, self._format_memory_operand(index * WORD_SIZE, "sp", function_ast))

        if self.current_function_secure:
            if not self._validate_secure_literal(function_ast):
                return
            if return_type is not None and not return_type.is_void:
                self._emit("mov", "p0", "zero")
            # login valida entrada a funcion segura antes de ejecutar su cuerpo.
            self._emit("login", function_ast.secure.value)
            self._emit("beqz", "lr", LabelRef(self.current_secure_exit_label))

        for instruction in function.instructions:
            # Cada TAC se traduce usando simbolos reales o slots virtuales.
            self._emit_ir_instruction(instruction)

        if function.instructions and function.instructions[-1].op != "return":
            # Si la IR puede caer al final, se emite retorno implicito.
            self._emit_function_cleanup(function_ast, self.ir_current_total_frame)

        if self.current_secure_exit_label is not None:
            self._emit_label(self.current_secure_exit_label)
            self._emit_function_cleanup(function_ast, self.ir_current_total_frame)

        function_symbol.extra["call_spill_size"] = self.current_call_spill_max
        function_symbol.extra["ir_backend"] = True
        function_symbol.extra["ir_slot_count"] = len(self.ir_virtual_offsets)

        # Restaurar estado evita contaminar la siguiente funcion.
        self.current_param_shadow_offsets = {}
        self.ir_symbol_map = {}
        self.ir_virtual_offsets = {}
        self.ir_virtual_types = {}
        self.ir_param_stride_registers = previous_param_stride_registers
        self.ir_pending_params = []
        self.current_function = previous_function
        self.current_function_symbol = previous_function_symbol
        self.current_function_secure = previous_secure
        self.current_secure_exit_label = previous_secure_exit_label
        self.current_homed_params = previous_homed_params
        self._pop_scope(previous_scope)

    def _emit_ir_instruction(self, instruction: IRInstruction):
        """Entradas: instruccion TAC. Salida: ASM equivalente. Uso: _emit_ir_function."""
        op = instruction.op
        if op == "comment":
            if instruction.extra:
                self._emit_comment(f"; {instruction.extra}")
            return
        if op == "label" and instruction.dest:
            self._emit_label(instruction.dest)
            return
        if op == "const" and instruction.dest:
            result = self._alloc_temp(instruction)
            # Constante TAC -> inmediato en registro -> destino IR.
            self._emit_load_immediate_user(result, self._parse_ir_const(instruction))
            self._store_ir_value(instruction.dest, result, instruction)
            self._remember_ir_type(instruction.dest, TypeInfo("int"))
            self._free_temp(result)
            return
        if op == "assign" and instruction.dest and instruction.args:
            value = self._load_ir_value(instruction.args[0], instruction)
            self._store_ir_value(instruction.dest, value, instruction)
            self._remember_ir_type(instruction.dest, self._ir_value_type(instruction.args[0]))
            self._free_temp(value)
            return
        if op == "binop" and instruction.dest and len(instruction.args) >= 2:
            # Operaciones binarias devuelven un registro temporal materializado.
            result = self._emit_ir_binop(instruction)
            self._store_ir_value(instruction.dest, result, instruction)
            self._remember_ir_type(instruction.dest, TypeInfo("int"))
            self._free_temp(result)
            return
        if op == "unop" and instruction.dest and instruction.args:
            result = self._emit_ir_unop(instruction)
            self._store_ir_value(instruction.dest, result, instruction)
            self._remember_ir_type(instruction.dest, self._ir_value_type(instruction.args[0]) or TypeInfo("int"))
            self._free_temp(result)
            return
        if op == "addr" and instruction.dest and instruction.args:
            result = self._address_ir_name(instruction.args[0], instruction)
            self._store_ir_value(instruction.dest, result, instruction)
            base_type = self._ir_value_type(instruction.args[0]) or TypeInfo("int")
            self._remember_ir_type(instruction.dest, TypeInfo(base_type.name, is_pointer=True, vault_inner=base_type.vault_inner))
            self._free_temp(result)
            return
        if op == "deref" and instruction.dest and instruction.args:
            pointer = self._load_ir_value(instruction.args[0], instruction)
            result = self._alloc_temp(instruction)
            # *ptr en IR carga una palabra desde la direccion calculada.
            self._emit_user("ldw", result, self._format_memory_operand(0, pointer, instruction))
            self._store_ir_value(instruction.dest, result, instruction)
            self._free_temp(result)
            self._free_temp(pointer)
            return
        if op == "load_index" and instruction.dest and len(instruction.args) >= 2:
            element_type = self._indexed_element_type(instruction.args[0])
            addr = self._indexed_ir_address(instruction.args[0], instruction.args[1], instruction)
            if element_type is not None and element_type.is_array:
                # A[i] en una matriz produce la direccion de la fila, no una carga escalar.
                self._store_ir_value(instruction.dest, addr, instruction)
                self._remember_ir_type(instruction.dest, element_type)
            else:
                result = self._alloc_temp(instruction)
                load_type = element_type or TypeInfo("int")
                self._emit_user(self._type_load_op(load_type), result, self._format_memory_operand(0, addr, instruction))
                self._store_ir_value(instruction.dest, result, instruction)
                self._remember_ir_type(instruction.dest, load_type)
                self._free_temp(result)
            self._free_temp(addr)
            return
        if op == "store_index" and len(instruction.args) >= 3:
            # base[index] = value: primero direccion efectiva, luego store.
            addr = self._indexed_ir_address(instruction.args[0], instruction.args[1], instruction)
            value = self._load_ir_value(instruction.args[2], instruction)
            self._emit_user("stw", value, self._format_memory_operand(0, addr, instruction))
            self._free_temp(value)
            self._free_temp(addr)
            return
        if op == "store_deref" and len(instruction.args) >= 2:
            pointer = self._load_ir_value(instruction.args[0], instruction)
            value = self._load_ir_value(instruction.args[1], instruction)
            self._emit_user("stw", value, self._format_memory_operand(0, pointer, instruction))
            self._free_temp(value)
            self._free_temp(pointer)
            return
        if op == "param" and instruction.args:
            # Los param se acumulan hasta ver la instruccion call.
            self.ir_pending_params.append(instruction.args[0])
            return
        if op == "call":
            # La instruccion call consume los param acumulados inmediatamente antes.
            self._emit_ir_call(instruction)
            return
        if op == "goto" and instruction.target:
            self._emit_user("jmp", LabelRef(instruction.target))
            return
        if op in {"if", "if_false"} and instruction.args and instruction.target:
            cond = self._load_ir_value(instruction.args[0], instruction)
            if op == "if_false":
                # if_false usa branch directo a cero.
                self._emit_user("beqz", cond, LabelRef(instruction.target))
            else:
                # if verdadero se invierte con salto corto a etiqueta local.
                end_label = self._new_label("ir_if_skip")
                self._emit_user("beqz", cond, LabelRef(end_label))
                self._emit_user("jmp", LabelRef(instruction.target))
                self._emit_label(end_label)
            self._free_temp(cond)
            return
        if op == "return":
            if instruction.args:
                value = self._load_ir_value(instruction.args[0], instruction)
                # p0 es el registro convencional de retorno.
                self._emit("nop", comment="espera valor antes de mover retorno")
                self._emit_user("mov", "p0", value)
                self._free_temp(value)
            self._emit_function_cleanup(self.current_function, self.ir_current_total_frame)
            return

        self.error(instruction, "unsupported_ir_instruction", f'la instruccion IR "{op}" no se puede bajar a ensamblador.')

    def _emit_ir_binop(self, instruction: IRInstruction) -> str:
        """Entradas: binop TAC. Salida: registro resultado. Uso: _emit_ir_instruction."""
        operator = instruction.extra or ""
        left = self._load_ir_value(instruction.args[0], instruction)
        right = self._load_ir_value(instruction.args[1], instruction)

        if operator in ARITHMETIC_OPS:
            # Se reutiliza left como acumulador para reducir registros vivos.
            self._emit_user(ARITHMETIC_OPS[operator], left, left, right)
            self._free_temp(right)
            return left

        if operator in BRANCH_TRUE_OPS:
            result = self._alloc_temp(instruction)
            if operator in {"==", "!="}:
                # Igualdad puede materializarse con seq/seqz.
                self._emit_user("seq", result, left, right)
                if operator == "!=":
                    self._emit_user("seqz", result, result)
            else:
                # Comparaciones de orden se materializan con labels 0/1.
                true_label = self._new_label("ir_cmp_true")
                end_label = self._new_label("ir_cmp_end")
                self._emit_load_immediate_user(result, 0)
                self._emit_user(BRANCH_TRUE_OPS[operator], left, right, LabelRef(true_label))
                self._emit_user("jmp", LabelRef(end_label))
                self._emit_label(true_label)
                self._emit_load_immediate_user(result, 1)
                self._emit_label(end_label)
            self._free_temp(right)
            self._free_temp(left)
            return result

        self.error(instruction, "unsupported_ir_operator", f'el operador IR "{operator}" no se puede bajar a ensamblador.')
        self._free_temp(right)
        return left

    def _emit_ir_unop(self, instruction: IRInstruction) -> str:
        """Entradas: unop TAC. Salida: registro resultado. Uso: _emit_ir_instruction."""
        operator = instruction.extra or ""
        operand = self._load_ir_value(instruction.args[0], instruction)
        if operator == "-":
            self._emit_user("sub", operand, "zero", operand)
            return operand
        if operator == "!":
            self._emit_user("seqz", operand, operand)
            return operand
        self.error(instruction, "unsupported_ir_operator", f'el operador unario IR "{operator}" no se puede bajar a ensamblador.')
        return operand

    def _emit_ir_call(self, instruction: IRInstruction):
        """Entradas: call TAC. Salida: argumentos, call y retorno opcional. Uso: _emit_ir_instruction."""
        args = instruction.args if instruction.args else self.ir_pending_params
        if not instruction.extra:
            self.error(instruction, "missing_ir_callee", "llamada IR sin nombre de funcion.")
            return

        call_regs: List[str] = []
        for arg in args:
            # Se calculan primero para no pisar parametros vivos en p0, p1, etc.
            call_regs.append(self._load_ir_argument(arg, instruction))

        hidden_stride_regs = self._load_hidden_stride_arguments(instruction.extra, args, instruction)
        call_regs.extend(hidden_stride_regs)

        if len(call_regs) > PARAM_REGISTER_LIMIT:
            self.error(instruction, "too_many_call_arguments", "la llamada excede los registros de parametros disponibles.")
            for reg in call_regs:
                self._free_temp(reg)
            return

        for index, reg in enumerate(call_regs):
            # Convencion de llamada: argumentos visibles y ocultos en p0, p1, ...
            self._emit_user("mov", f"p{index}", reg)
            self._free_temp(reg)

        self._emit_user("call", LabelRef(instruction.extra))
        self.ir_pending_params = []

        callee_symbol = self.symbol_table.global_scope.symbols.get(instruction.extra)
        returns_value = callee_symbol is None or callee_symbol.return_type is None or not callee_symbol.return_type.is_void
        if instruction.dest and returns_value:
            # El resultado de llamada solo se guarda si la funcion retorna valor.
            result = self._alloc_temp(instruction)
            # Tras call se lee p0 y se guarda en el destino TAC.
            self._emit("nop", comment="espera retorno de call antes de leer p0")
            self._emit_user("mov", result, "p0")
            self._store_ir_value(instruction.dest, result, instruction)
            self._remember_ir_type(instruction.dest, callee_symbol.return_type if callee_symbol else TypeInfo("int"))
            self._free_temp(result)

    def _load_ir_argument(self, name: str, context) -> str:
        """Entradas: argumento IR. Salida: valor o direccion base. Uso: llamadas."""
        symbol = self._resolve_ir_symbol(name)
        if symbol is not None and symbol.type_info is not None and symbol.type_info.is_array:
            # Los arreglos se pasan por referencia, no por su primer elemento.
            return self._address_ir_name(name, context)
        return self._load_ir_value(name, context)

    def _load_hidden_stride_arguments(self, callee_name: str, args: List[str], context) -> List[str]:
        """Entradas: callee y args. Salida: strides ocultos. Uso: llamadas a matrices."""
        callee_ast = self.function_ast_by_name.get(callee_name)
        if callee_ast is None:
            return []

        hidden: List[str] = []
        callee_scope = self.scope_by_name.get(f"function:{callee_name}")
        if callee_scope is None:
            return hidden

        for param, arg in zip(callee_ast.params, args):
            param_symbol = callee_scope.symbols.get(param.name)
            if param_symbol is None or not self._needs_dynamic_row_stride(param_symbol.type_info):
                continue
            hidden.append(self._load_ir_row_stride(arg, context))
        return hidden

    def _load_ir_row_stride(self, name: str, context) -> str:
        """Entradas: arreglo argumento. Salida: bytes por fila. Uso: int[][] dinamico."""
        result = self._alloc_temp(context)
        value_type = self._ir_value_type(name)
        static_stride = self._static_row_stride(value_type)
        if static_stride is not None:
            self._emit_load_immediate_user(result, static_stride)
            return result

        symbol = self._resolve_ir_symbol(name)
        if symbol is not None and symbol.name in self.ir_param_stride_registers:
            # Propaga el stride recibido cuando se pasa una matriz parametro a otra funcion.
            self._emit_user("mov", result, self.ir_param_stride_registers[symbol.name])
            return result

        self.error(context, "missing_matrix_stride", f'no se pudo determinar el stride de filas para "{name}".')
        self._emit_user("mov", result, "zero")
        return result

    def _load_ir_value(self, name: str, context) -> str:
        """Entradas: nombre IR/simbolo. Salida: registro cargado. Uso: TAC que lee valores."""
        result = self._alloc_temp(context)
        symbol = self._resolve_ir_symbol(name)
        if symbol is not None:
            # Simbolo real: global, local, parametro o builtin.
            if symbol.type_info is not None and symbol.type_info.is_array:
                if symbol.segment == "param" or self._is_array_reference_symbol(symbol):
                    self._emit_load_symbol(symbol, result)
                    return result
                self._free_temp(result)
                return self._address_ir_name(name, context)
            self._emit_load_symbol(symbol, result)
            return result

        offset = self.ir_virtual_offsets.get(name)
        if offset is None:
            self.error(context, "unknown_ir_value", f'no se pudo resolver el valor IR "{name}".')
            self._emit_user("mov", result, "zero")
            return result

        # Valor virtual: temporal/version almacenado en stack.
        self._emit_user("ldw", result, self._format_memory_operand(offset, "sp", context))
        return result

    def _store_ir_value(self, name: str, value_reg: str, context):
        """Entradas: destino IR y registro. Salida: store a simbolo/slot. Uso: TAC que define."""
        symbol = self._resolve_ir_symbol(name)
        if symbol is not None:
            self._emit_store_symbol(symbol, value_reg)
            return

        offset = self.ir_virtual_offsets.get(name)
        if offset is None:
            self.error(context, "unknown_ir_destination", f'no se pudo resolver el destino IR "{name}".')
            return
        # Destino virtual: se conserva en stack para usos posteriores.
        self._emit_user("stw", value_reg, self._format_memory_operand(offset, "sp", context))

    def _address_ir_name(self, name: str, context) -> str:
        """Entradas: nombre IR/simbolo. Salida: registro direccion. Uso: addr e indexacion."""
        result = self._alloc_temp(context)
        symbol = self._resolve_ir_symbol(name)
        if symbol is None:
            offset = self.ir_virtual_offsets.get(name)
            if offset is None:
                self.error(context, "unknown_ir_address", f'no se pudo tomar direccion de "{name}".')
                self._emit_user("mov", result, "zero")
                return result
            # Direccion de slot virtual dentro del frame.
            self._emit_add_immediate_user(result, "sp", offset)
            return result

        if symbol.segment == "global":
            # Globales usan direccion absoluta resuelta al renderizar.
            self._emit_user("la", result, AddressRef(symbol.name))
            return result
        if symbol.segment == "vault":
            self._emit_load_immediate_user(result, symbol.address or 0)
            return result
        if symbol.segment == "stack":
            if self._is_array_reference_symbol(symbol):
                # Referencias int[][] locales guardan una direccion en su slot.
                self._emit_user(
                    "ldw",
                    result,
                    self._format_memory_operand(self._local_slot_offset(symbol), "sp", context),
                )
                return result
            # Locales reales usan su offset asignado por semantica.
            self._emit_add_immediate_user(result, "sp", self._local_slot_offset(symbol))
            return result
        if symbol.segment == "param":
            if symbol.type_info is not None and symbol.type_info.is_array and symbol.register is not None:
                # Arreglos parametro ya llegan como direccion base.
                self._emit_user("mov", result, symbol.register)
                return result
            shadow_offset = self._parameter_shadow_offset(symbol)
            if shadow_offset is not None:
                self._ensure_parameter_home(symbol)
                self._emit_add_immediate_user(result, "sp", shadow_offset)
                return result

        self.error(context, "unsupported_ir_address", f'no se puede tomar direccion de "{name}".')
        self._emit_user("mov", result, "zero")
        return result

    def _indexed_ir_address(self, base_name: str, index_name: str, context) -> str:
        """Entradas: base e indice IR. Salida: direccion efectiva. Uso: load/store_index."""
        if base_name == "data_mem":
            # data_mem ya esta indexada por bytes.
            base_reg = self._alloc_temp(context)
            index_reg = self._load_ir_value(index_name, context)
            self._emit_load_immediate_user(base_reg, 0)
            self._emit_user("add", base_reg, base_reg, index_reg)
            self._free_temp(index_reg)
            return base_reg

        symbol = self._resolve_ir_symbol(base_name)
        base_type = self._ir_value_type(base_name)
        if symbol is not None and symbol.type_info is not None and symbol.type_info.is_array:
            # Arreglo local/global: se toma direccion base real.
            base_reg = self._address_ir_name(base_name, context)
            element_type = symbol.type_info.element_type()
        elif base_type is not None and base_type.is_array:
            # Subarreglo virtual: su valor ya es direccion base de la fila.
            base_reg = self._load_ir_value(base_name, context)
            element_type = base_type.element_type()
        else:
            # Puntero/temporal: su valor ya representa una direccion.
            base_reg = self._load_ir_value(base_name, context)
            element_type = base_type.element_type() if base_type is not None else TypeInfo("int")

        index_reg = self._load_ir_value(index_name, context)
        stride_reg = self._dynamic_row_stride_register(base_name, context)
        if stride_reg is not None:
            # En int[][] el ancho de fila llega oculto con la llamada.
            self._emit_user("mul", index_reg, index_reg, stride_reg)
            self._free_temp(stride_reg)
        else:
            element_size = self._type_size(element_type)
            if element_size != 1:
                # Arreglos normales indexan elementos, no bytes.
                self._emit_user("muli", index_reg, index_reg, str(element_size))
        self._emit_user("add", base_reg, base_reg, index_reg)
        self._free_temp(index_reg)
        return base_reg

    def _dynamic_row_stride_register(self, base_name: str, context) -> Optional[str]:
        """Entradas: base indexada. Salida: registro stride o None. Uso: int[][]."""
        symbol = self._resolve_ir_symbol(base_name)
        if symbol is None or not self._needs_dynamic_row_stride(symbol.type_info):
            return None
        stride_register = self.ir_param_stride_registers.get(symbol.name)
        if stride_register is None:
            self.error(context, "missing_matrix_stride", f'no se encontro stride oculto para "{base_name}".')
            return None
        result = self._alloc_temp(context)
        self._emit_user("mov", result, stride_register)
        return result

    def _ir_value_type(self, name: str) -> Optional[TypeInfo]:
        """Entradas: nombre IR/simbolo. Salida: tipo conocido o None. Uso: matrices."""
        symbol = self._resolve_ir_symbol(name)
        if symbol is not None:
            return symbol.type_info
        return self.ir_virtual_types.get(name)

    def _indexed_element_type(self, base_name: str) -> Optional[TypeInfo]:
        """Entradas: base indexada. Salida: tipo del elemento. Uso: load_index."""
        base_type = self._ir_value_type(base_name)
        if base_type is None:
            return None
        if base_type.is_array or base_type.is_pointer:
            return base_type.element_type()
        return TypeInfo(base_type.name, vault_inner=base_type.vault_inner)

    def _remember_ir_type(self, name: str | None, type_info: Optional[TypeInfo]) -> None:
        """Entradas: destino y tipo. Salida: cache actualizada. Uso: temporales."""
        if name and type_info is not None and self._resolve_ir_symbol(name) is None:
            self.ir_virtual_types[name] = type_info

    def _assign_dynamic_stride_registers(self, function_ast: FunctionDeclNode) -> Dict[str, str]:
        """Entradas: firma. Salida: parametro->registro stride. Uso: int[][]."""
        registers: Dict[str, str] = {}
        next_index = len(function_ast.params)
        for param in function_ast.params:
            symbol = self.ir_symbol_map.get(param.name)
            if symbol is None or not self._needs_dynamic_row_stride(symbol.type_info):
                continue
            if next_index >= PARAM_REGISTER_LIMIT:
                self.error(param, "too_many_matrix_parameters", "no hay registros suficientes para strides ocultos.")
                continue
            registers[param.name] = f"p{next_index}"
            next_index += 1
        return registers

    def _needs_dynamic_row_stride(self, type_info: Optional[TypeInfo]) -> bool:
        """Entradas: tipo. Salida: True si int[][] necesita stride oculto. Uso: matrices."""
        return bool(type_info and type_info.is_array and len(type_info.array_dims) > 1 and type_info.array_dims[1] <= 0)

    def _static_row_stride(self, type_info: Optional[TypeInfo]) -> Optional[int]:
        """Entradas: tipo matriz. Salida: bytes por fila si se conoce. Uso: llamadas."""
        if type_info is None or not type_info.is_array or len(type_info.array_dims) <= 1:
            return None
        row_type = type_info.element_type()
        if row_type.has_unknown_size:
            return None
        return self._type_size(row_type)

    def _resolve_ir_symbol(self, name: str) -> Optional[Symbol]:
        """Entradas: nombre. Salida: simbolo real o None. Uso: cargas, stores y direcciones."""
        if name in self.ir_symbol_map:
            return self.ir_symbol_map[name]
        if self.symbol_table is not None:
            symbol = self.symbol_table.global_scope.symbols.get(name)
            if symbol is not None:
                return symbol
        if name in {"zero", "delta", "max", "data_mem"}:
            return self._resolve_symbol(name)
        return None

    def _collect_function_symbols(self, function_name: str) -> Dict[str, Symbol]:
        """Entradas: nombre funcion. Salida: simbolos visibles. Uso: _emit_ir_function."""
        scope = self.scope_by_name.get(f"function:{function_name}")
        symbols: Dict[str, Symbol] = {}
        if scope is not None:
            self._collect_scope_symbols(scope, symbols)
        return symbols

    def _collect_scope_symbols(self, scope: Scope, symbols: Dict[str, Symbol]):
        """Entradas: scope y acumulador. Salida: muta simbolos. Uso: _collect_function_symbols."""
        for name, symbol in scope.symbols.items():
            symbols.setdefault(name, symbol)
        for child in scope.children:
            self._collect_scope_symbols(child, symbols)

    def _collect_ir_parameter_homes(self, function: IRFunction) -> Set[str]:
        """Entradas: funcion IR. Salida: parametros con direccion requerida. Uso: frame."""
        params = set(self.ir_symbol_map[name].name for name in function.params if name in self.ir_symbol_map)
        homes: Set[str] = set()
        for instruction in function.instructions:
            if instruction.op == "addr" and instruction.args and instruction.args[0] in params:
                # &param obliga a darle direccion estable dentro del frame.
                homes.add(instruction.args[0])
        return homes

    def _allocate_ir_slots(self, function: IRFunction) -> Dict[str, int]:
        """Entradas: funcion IR. Salida: offsets de virtuales. Uso: _load/_store_ir_value."""
        names: Set[str] = set()
        for instruction in function.instructions:
            if instruction.dest and instruction.op not in {"label"}:
                # Cada definicion IR necesita donde vivir si no es simbolo real.
                names.add(instruction.dest)
            for position, arg in enumerate(instruction.args):
                if instruction.op == "addr":
                    # addr no lee el valor, solo necesita direccion.
                    continue
                if instruction.op == "store_index" and position == 0 and self._resolve_ir_symbol(arg) is not None:
                    # La base real de un arreglo no necesita slot virtual.
                    continue
                names.add(arg)

        ignored = {"_", "void", "zero", "delta", "max", "data_mem"}
        virtual_names = sorted(
            name
            for name in names
            if name not in ignored and self._resolve_ir_symbol(name) is None
        )
        # El renombramiento aumenta virtual_names; aqui se vuelven slots separados.
        return {
            name: self.current_saved_area + self.current_local_size + (index * WORD_SIZE)
            for index, name in enumerate(virtual_names)
        }

    def _parse_ir_const(self, instruction: IRInstruction) -> int:
        """Entradas: const TAC. Salida: entero materializable. Uso: _emit_ir_instruction."""
        raw = (instruction.extra or "0").strip()
        if raw in {"True", "true"}:
            return 1
        if raw in {"False", "false"}:
            return 0
        if len(raw) >= 2 and raw[0] == "'" and raw[-1] == "'":
            body = raw[1:-1]
            if body.startswith("\\"):
                escape_map = {"n": "\n", "t": "\t", "r": "\r", "b": "\b", "\\": "\\", "'": "'", '"': '"'}
                body = escape_map.get(body[1:], body[1:])
            return ord(body[0]) if body else 0
        try:
            return int(raw, 0)
        except ValueError:
            # El backend solo materializa constantes enteras/bool/char.
            self.error(instruction, "unsupported_ir_const", f'la constante IR "{raw}" no se puede materializar.')
            return 0
