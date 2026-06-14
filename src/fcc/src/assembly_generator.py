"""Generador de ensamblador FCC basado en el AST y la tabla de simbolos."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Union
import re

from ast_nodes import (
    AssignmentNode,
    BinaryOpNode,
    BlockNode,
    BreakNode,
    CallNode,
    ContinueNode,
    ExpressionStmtNode,
    ForNode,
    FunctionDeclNode,
    IdentifierNode,
    IfNode,
    IndexAccessNode,
    LiteralNode,
    ProgramNode,
    ReturnNode,
    UnaryOpNode,
    VarDeclNode,
    WhileNode,
)
from symbol_table import DATA_BASE, MEMORY_SIZE, PROGRAM_RESULT_SYMBOL, Scope, Symbol, SymbolTable, TypeInfo


WORD_SIZE = 4
TEMP_REGS = [f"r{i}" for i in range(16)]
SECURE_REGS = ["ax", "bx", "cx", "dx", "ex", "fx", "gx", "hx"]
WRITABLE_SECURE_REGS = SECURE_REGS[1:]
SAVE_REGS = ["ra"]
BRANCH_IMMEDIATE_BITS = 12
JUMP_IMMEDIATE_BITS = 21
SIGNED_IMMEDIATE_MIN = -(1 << 11)
SIGNED_IMMEDIATE_MAX = (1 << 11) - 1
MEMORY_OFFSET_MAX = (1 << 12) - 1

ARITHMETIC_OPS = {
    "+": "add",
    "-": "sub",
    "*": "mul",
    "/": "div",
    "%": "mod",
    "&": "and",
    "|": "orr",
    "^": "xor",
    "<<": "sll",
    ">>": "srl",
}
ARITHMETIC_IMM_OPS = {
    "+": "addi",
    "-": "subi",
    "*": "muli",
    "/": "divi",
    "%": "modi",
    "&": "andi",
    "|": "orri",
    "^": "xori",
    "<<": "slli",
    ">>": "srli",
}
BRANCH_TRUE_OPS = {
    "==": "beq",
    "!=": "bne",
    ">": "bgt",
    "<": "blt",
    ">=": "bge",
    "<=": "ble",
}
BRANCH_FALSE_OPS = {
    "==": "bne",
    "!=": "beq",
    ">": "ble",
    "<": "bge",
    ">=": "blt",
    "<=": "bgt",
}
RELATIVE_BRANCH_OPS = {*BRANCH_TRUE_OPS.values(), *BRANCH_FALSE_OPS.values(), "beqz"}
RELATIVE_JUMP_OPS = {"jmp", "call", "jal"}
BUILTIN_READONLY_REGISTERS = {"zero", "delta", "max"}
BUILTIN_DATA_MEMORY = "data_mem"


@dataclass
class CodegenDiagnostic:
    """Representa un error detectado durante la generacion de ensamblador."""

    line: int
    column: int
    code: str
    message: str


@dataclass
class LabelRef:
    """Referencia diferida a una etiqueta relativa dentro del codigo."""

    name: str


@dataclass
class AddressRef:
    """Referencia diferida a la direccion final de un simbolo global."""

    symbol_name: str


@dataclass
class StackBaseRef:
    """Marca especial para resolver la base final del stack al renderizar."""

    pass


@dataclass
class Instruction:
    """Modelo intermedio de una instruccion antes del render final."""

    op: str
    args: List[Union[str, int, LabelRef]] = field(default_factory=list)
    secure: bool = False
    comment: Optional[str] = None


@dataclass
class LabelMarker:
    """Marca la posicion de una etiqueta dentro de la secuencia emitida."""

    name: str


@dataclass
class AssemblyResult:
    """Empaqueta lineas generadas y diagnosticos de codegen."""

    diagnostics: List[CodegenDiagnostic] = field(default_factory=list)
    lines: List[str] = field(default_factory=list)

    @property
    def has_errors(self) -> bool:
        """Indica si la generacion produjo al menos un error."""

        return len(self.diagnostics) > 0

    @property
    def text(self) -> str:
        """Devuelve la salida ensamblada como texto plano."""

        return "\n".join(self.lines)


class AssemblyGenerator:
    """Traduce el AST FCC a ensamblador textual de la ISA objetivo."""

    def __init__(self):
        """Inicializa buffers, estado de funcion y pools temporales."""

        self.diagnostics: List[CodegenDiagnostic] = []
        self.items: List[Union[Instruction, LabelMarker, str]] = []
        self.label_counter = 0
        self.free_temps: List[str] = []

        self.symbol_table: Optional[SymbolTable] = None
        self.scope_by_name: Dict[str, Scope] = {}
        self.current_scope: Optional[Scope] = None
        self.current_function: Optional[FunctionDeclNode] = None
        self.current_function_symbol: Optional[Symbol] = None
        self.current_function_secure = False
        self.current_secure_exit_label: Optional[str] = None
        self.current_loop_stack: List[dict] = []
        self.current_call_spill_max = 0
        self.current_homed_params: set[str] = set()

        self.current_saved_area = len(SAVE_REGS) * WORD_SIZE
        self.current_local_size = 0
        self.current_param_shadow_offsets: Dict[str, int] = {}
        self.emit_entrypoint = True
        self.stack_base_address = DATA_BASE

    # API PRINCIPAL

    def generate(
        self,
        program: ProgramNode,
        symbol_table: SymbolTable,
        emit_entrypoint: bool = True,
    ) -> AssemblyResult:
        """Genera ensamblador para un programa completo."""

        self.symbol_table = symbol_table
        self.scope_by_name = {scope.name: scope for scope in symbol_table.all_scopes}
        self.current_scope = symbol_table.global_scope
        self.emit_entrypoint = emit_entrypoint

        self._emit_comment("; Codigo ensamblador generado por FCC")
        self._emit_comment("; ISA base: F32IS (isa.md)")
        self._emit_program(program)

        if self.diagnostics:
            return AssemblyResult(diagnostics=self.diagnostics)

        rendered_lines = self._render_items()
        if self.diagnostics:
            return AssemblyResult(diagnostics=self.diagnostics)

        return AssemblyResult(lines=rendered_lines)

    # UTILIDADES

    def error(self, node, code: str, message: str):
        """Registra un error de generacion asociado a un nodo fuente."""

        self.diagnostics.append(
            CodegenDiagnostic(
                line=getattr(node, "line", 0),
                column=getattr(node, "column", 0),
                code=code,
                message=message,
            )
        )

    def _emit_comment(self, text: str):
        """Agrega un comentario literal a la salida intermedia."""

        self.items.append(text)

    def _emit_label(self, name: str):
        """Agrega una etiqueta al flujo intermedio."""

        self.items.append(LabelMarker(name))

    def _emit(self, op: str, *args, secure: bool = False, comment: Optional[str] = None):
        """Agrega una instruccion al flujo intermedio."""

        self.items.append(
            Instruction(
                op=op,
                args=list(args),
                secure=secure,
                comment=comment,
            )
        )

    def _emit_user(self, op: str, *args, comment: Optional[str] = None):
        """Emite una instruccion respetando el modo secure de la funcion."""

        self._emit(op, *args, secure=self.current_function_secure, comment=comment)

    def _new_label(self, prefix: str) -> str:
        """Construye un nombre de etiqueta unico dentro del programa."""

        self.label_counter += 1
        function_name = self.current_function.name if self.current_function else "global"
        return f"{function_name}_{prefix}_{self.label_counter}"

    def _push_scope(self, name: str) -> Optional[Scope]:
        """Cambia temporalmente al scope solicitado durante codegen."""

        previous = self.current_scope
        self.current_scope = self.scope_by_name.get(name, previous)
        return previous

    def _pop_scope(self, previous: Optional[Scope]):
        """Restaura el scope anterior tras salir de un bloque o funcion."""

        self.current_scope = previous

    def _resolve_symbol(self, name: str) -> Optional[Symbol]:
        """Busca un simbolo visible desde el scope actual."""

        scope = self.current_scope
        while scope is not None:
            symbol = scope.symbols.get(name)
            if symbol is not None:
                return symbol
            scope = scope.parent
        if name in BUILTIN_READONLY_REGISTERS:
            return Symbol(
                name=name,
                kind="register",
                type_info=TypeInfo("int"),
                scope_name="builtin",
                line=0,
                column=0,
                segment="register",
                register=name,
                extra={"readonly": True},
            )
        if name == BUILTIN_DATA_MEMORY:
            return Symbol(
                name=name,
                kind="memory",
                type_info=TypeInfo("int", is_pointer=True),
                scope_name="builtin",
                line=0,
                column=0,
                segment="data_mem",
                address=0,
                extra={"readonly": True, "byte_indexed": True},
            )
        return None

    def _alloc_temp(self, node) -> str:
        """Reserva un registro temporal libre."""

        if not self.free_temps:
            self.error(node, "register_exhaustion", "no hay registros temporales disponibles.")
            return TEMP_REGS[0]
        return self.free_temps.pop()

    def _free_temp(self, reg: str):
        """Devuelve un registro temporal al pool de disponibles."""

        if reg in TEMP_REGS and reg not in self.free_temps:
            self.free_temps.append(reg)

    def _reset_temp_pool(self):
        """Reinicia el pool de temporales al entrar a una nueva unidad."""

        self.free_temps = list(reversed(TEMP_REGS))

    def _current_live_temp_regs(self) -> List[str]:
        """Retorna los temporales actualmente en uso."""

        return [reg for reg in TEMP_REGS if reg not in self.free_temps]

    def _format_memory_operand(self, offset: int, base: str, context=None) -> str:
        """Formatea un operando de memoria y valida el rango del offset."""

        if abs(offset) > MEMORY_OFFSET_MAX:
            self.error(
                context if context is not None else self.current_function or self.current_scope,
                "memory_offset_out_of_range",
                f"el desplazamiento de memoria {offset} excede el rango soportado de +/-{MEMORY_OFFSET_MAX}.",
            )
        op_sign = "+" if offset >= 0 else "-"
        return f"{op_sign}{abs(offset)}({base})"

    def _align(self, value: int, alignment: int = WORD_SIZE) -> int:
        """Alinea un valor al multiplo requerido."""

        if value <= 0:
            return 0
        return ((value + alignment - 1) // alignment) * alignment

    def _split_signed_immediate(self, value: int) -> List[int]:
        """Parte un inmediato grande en trozos validos para la ISA."""

        if value == 0:
            return [0]

        chunks: List[int] = []
        remaining = value
        while remaining != 0:
            if remaining > 0:
                chunk = min(remaining, SIGNED_IMMEDIATE_MAX)
            else:
                chunk = max(remaining, SIGNED_IMMEDIATE_MIN)
            chunks.append(chunk)
            remaining -= chunk
        return chunks

    def _emit_add_immediate(self, target: str, source: str, value: int, secure: bool = False):
        """Emite una suma con inmediato aunque el valor requiera varios pasos."""

        if value == 0:
            if target != source:
                self._emit("mov", target, source, secure=secure)
            return

        chunks = self._split_signed_immediate(value)
        current_source = source
        for chunk in chunks:
            self._emit("addi", target, current_source, chunk, secure=secure)
            current_source = target

    def _emit_add_immediate_user(self, target: str, source: str, value: int):
        """Version de _emit_add_immediate que hereda el modo secure."""

        self._emit_add_immediate(target, source, value, secure=self.current_function_secure)

    def _emit_load_immediate(self, target: str, value: int, secure: bool = False):
        """Carga un inmediato arbitrario en un registro."""

        if SIGNED_IMMEDIATE_MIN <= value <= SIGNED_IMMEDIATE_MAX:
            self._emit("li", target, value, secure=secure)
            return

        self._emit("li", target, 0, secure=secure)
        for chunk in self._split_signed_immediate(value):
            if chunk == 0:
                continue
            self._emit("addi", target, target, chunk, secure=secure)

    def _emit_load_immediate_user(self, target: str, value: int):
        """Version de _emit_load_immediate que hereda el modo secure."""

        self._emit_load_immediate(target, value, secure=self.current_function_secure)

    def _emit_sp_adjust(self, delta: int):
        """Ajusta el stack pointer segun la convencion adoptada."""

        if delta == 0:
            return
        self._emit_add_immediate("sp", "sp", delta)

    def _is_integral_type(self, type_info: Optional[TypeInfo]) -> bool:
        """Indica si un tipo pertenece al subconjunto entero soportado."""

        if type_info is None:
            return False
        return (
            type_info.name in {"int", "char", "bool"}
            and not type_info.is_pointer
            and not type_info.is_array
        )

    def _is_float_type(self, type_info: Optional[TypeInfo]) -> bool:
        """Indica si un tipo corresponde a float escalar."""

        return type_info is not None and type_info.name == "float" and not type_info.is_pointer and not type_info.is_array

    def _ensure_codegen_type(self, type_info: Optional[TypeInfo], node, usage: str) -> bool:
        """Verifica que un tipo pueda materializarse en ensamblador."""

        if type_info is None:
            return False

        if self._is_float_type(type_info):
            self.error(
                node,
                "unsupported_float_codegen",
                f'la ISA actual no soporta generar ensamblador para "{usage}" de tipo float.',
            )
            return False

        if type_info.name == "void" and not type_info.is_pointer and not type_info.is_array:
            self.error(
                node,
                "unsupported_void_codegen",
                f'no se puede materializar "{usage}" de tipo void en ensamblador.',
            )
            return False

        return True

    def _infer_type(self, node) -> Optional[TypeInfo]:
        """Infiere el tipo de una expresion para orientar el codegen."""

        if isinstance(node, IdentifierNode):
            symbol = self._resolve_symbol(node.name)
            return symbol.type_info if symbol else None

        if isinstance(node, LiteralNode):
            if node.literal_type in {"int", "hex"}:
                return TypeInfo("int")
            if node.literal_type == "float":
                return TypeInfo("float")
            if node.literal_type == "char":
                return TypeInfo("char")
            if node.literal_type == "bool":
                return TypeInfo("bool")
            if node.literal_type == "string":
                return TypeInfo("char", is_pointer=True)
            return None

        if isinstance(node, UnaryOpNode):
            operand_type = self._infer_type(node.operand)
            if operand_type is None:
                return None
            if node.operator == "!":
                return TypeInfo("bool")
            if node.operator == "-":
                return TypeInfo("float" if operand_type.name == "float" else "int")
            if node.operator == "&":
                return TypeInfo(operand_type.name, is_pointer=True, vault_inner=operand_type.vault_inner)
            if node.operator == "*":
                return TypeInfo(operand_type.name, vault_inner=operand_type.vault_inner)
            return operand_type

        if isinstance(node, BinaryOpNode):
            left = self._infer_type(node.left)
            right = self._infer_type(node.right)
            if left is None or right is None:
                return None
            if node.operator in {"==", "!=", "<", "<=", ">", ">="}:
                return TypeInfo("bool")
            if node.operator in {"+", "-", "*", "/", "~"}:
                if left.name == "float" or right.name == "float":
                    return TypeInfo("float")
                return TypeInfo("int")
            if node.operator in {"%", "<<", ">>"}:
                return TypeInfo("int")
            if node.operator in {"&", "|", "^"}:
                if left.name == "bool" and right.name == "bool":
                    return TypeInfo("bool")
                return TypeInfo("int")
            return None

        if isinstance(node, CallNode):
            if isinstance(node.callee, IdentifierNode):
                symbol = self._resolve_symbol(node.callee.name)
                return symbol.return_type if symbol else None
            return None

        if isinstance(node, IndexAccessNode):
            target = self._infer_type(node.target)
            if target is None:
                return None
            if target.is_array:
                return target.element_type()
            if target.is_pointer:
                return TypeInfo(target.name, vault_inner=target.vault_inner)
            return None

        return None

    def _type_store_op(self, type_info: TypeInfo) -> str:
        """Selecciona la instruccion de store segun el tamano del tipo."""

        if type_info.name == "char" and not type_info.is_pointer and not type_info.is_array:
            return "stb"
        return "stw"

    def _type_load_op(self, type_info: TypeInfo) -> str:
        """Selecciona la instruccion de load segun el tamano del tipo."""

        if type_info.name == "char" and not type_info.is_pointer and not type_info.is_array:
            return "ldb"
        return "ldw"

    def _vault_load_op(self, type_info: TypeInfo) -> str:
        """Retorna la carga segura correspondiente a un acceso sobre vault."""

        if type_info.name == "char" and not type_info.is_pointer and not type_info.is_array:
            return "ldvb"
        return "ldvw"

    def _vault_store_op(self, type_info: TypeInfo) -> str:
        """Retorna el store seguro correspondiente a un acceso sobre vault."""

        if type_info.name == "char" and not type_info.is_pointer and not type_info.is_array:
            return "stvb"
        return "stvw"

    def _type_size(self, type_info: TypeInfo) -> int:
        """Retorna el tamano en bytes de un tipo materializado."""

        if type_info.is_pointer:
            return WORD_SIZE
        if type_info.is_array:
            # Al indexar una matriz, cada fila ocupa el tamano total del subarreglo.
            return max(type_info.total_size(), WORD_SIZE)
        if type_info.name == "char":
            return 1
        return WORD_SIZE

    def _is_param_register(self, operand: str) -> bool:
        """Indica si un operando pertenece al banco de parametros/regulares."""

        return operand.startswith("p") and operand[1:].isdigit()

    def _secure_alias(self, operand: str) -> str:
        """Mapea temporales regulares a registros del banco seguro."""

        if operand in SECURE_REGS:
            return operand
        if operand.startswith("r") and operand[1:].isdigit():
            index = int(operand[1:])
            if 0 <= index < len(WRITABLE_SECURE_REGS):
                return WRITABLE_SECURE_REGS[index]
        return operand

    def _secure_memory_operand(self, operand: str) -> str:
        """Ajusta la base de un operando memoria al banco seguro si aplica."""

        match = re.match(r"^([+-]?\d+)\(([^)]+)\)$", operand)
        if not match:
            return operand
        offset, base = match.groups()
        return f"{offset}({self._secure_alias(base)})"

    def _resolve_secure_render(
        self,
        op: str,
        args: List[str],
    ) -> tuple[str, List[str], bool]:
        """Traduce una instruccion marcada como secure a su variante S/T."""

        if op in {"ldvw", "ldvh", "ldvb", "stvw", "stvh", "stvb"} and len(args) == 2:
            mapped_reg = self._secure_alias(args[0])
            mapped_mem = self._secure_memory_operand(args[1])
            return (op, [mapped_reg, mapped_mem], True)

        if op in {"paddadd", "pxorxor", "pslladd", "psrladd"} and len(args) == 4:
            mapped_args = [self._secure_alias(arg) for arg in args]
            if all(arg in SECURE_REGS for arg in mapped_args):
                return (op, mapped_args, True)
            return (op, args, False)

        if op == "mov" and len(args) == 2:
            dst, src = args
            mapped_dst = self._secure_alias(dst)
            mapped_src = self._secure_alias(src)
            if src == "zero" and mapped_dst in SECURE_REGS:
                return ("pmovi", [mapped_dst, "0"], True)
            if mapped_dst in SECURE_REGS and mapped_src in SECURE_REGS:
                return ("pmov", [mapped_dst, mapped_src], True)
            if mapped_dst in SECURE_REGS and mapped_src not in SECURE_REGS:
                return ("send", [mapped_dst, src], True)
            if mapped_src in SECURE_REGS and mapped_dst not in SECURE_REGS:
                return ("recv", [dst, mapped_src], True)
            return (op, args, False)

        if op == "li" and len(args) == 2:
            mapped_dst = self._secure_alias(args[0])
            if mapped_dst in SECURE_REGS:
                return ("pmovi", [mapped_dst, args[1]], True)
            return (op, args, False)

        if op == "seqz" and len(args) == 2:
            dst, src = args
            mapped_dst = self._secure_alias(dst)
            mapped_src = self._secure_alias(src)
            if mapped_dst in SECURE_REGS and mapped_src in SECURE_REGS:
                return ("pseqi", [mapped_dst, mapped_src, "0"], True)
            return (op, args, False)

        if op == "seq" and len(args) == 3:
            mapped_args = [self._secure_alias(arg) for arg in args]
            if all(arg in SECURE_REGS for arg in mapped_args):
                return ("pseq", mapped_args, True)
            return (op, args, False)

        if op == "seqi" and len(args) == 3:
            dst, src, imm = args
            mapped_dst = self._secure_alias(dst)
            mapped_src = self._secure_alias(src)
            if mapped_dst in SECURE_REGS and mapped_src in SECURE_REGS:
                return ("pseqi", [mapped_dst, mapped_src, imm], True)
            return (op, args, False)

        if op == "addi" and len(args) == 3:
            dst, src, imm = args
            mapped_dst = self._secure_alias(dst)
            mapped_src = self._secure_alias(src)
            if mapped_dst not in SECURE_REGS or mapped_src not in SECURE_REGS:
                return (op, args, False)
            try:
                value = int(imm)
            except ValueError:
                return ("paddi", [mapped_dst, mapped_src, imm], True)
            if value < 0:
                return ("psubi", [mapped_dst, mapped_src, str(abs(value))], True)
            return ("paddi", [mapped_dst, mapped_src, str(value)], True)

        if op == "subi" and len(args) == 3:
            dst, src, imm = args
            mapped_dst = self._secure_alias(dst)
            mapped_src = self._secure_alias(src)
            if mapped_dst in SECURE_REGS and mapped_src in SECURE_REGS:
                return ("psubi", [mapped_dst, mapped_src, imm], True)
            return (op, args, False)

        secure_imm_op_map = {
            "muli": "pmuli",
            "divi": "pdivi",
            "modi": "pmodi",
            "andi": "pandi",
            "orri": "porri",
            "xori": "pxori",
        }
        if op in secure_imm_op_map and len(args) == 3:
            dst, src, imm = args
            mapped_dst = self._secure_alias(dst)
            mapped_src = self._secure_alias(src)
            if mapped_dst in SECURE_REGS and mapped_src in SECURE_REGS:
                return (secure_imm_op_map[op], [mapped_dst, mapped_src, imm], True)
            return (op, args, False)

        secure_op_map = {
            "add": "padd",
            "sub": "psub",
            "mul": "pmul",
            "div": "pdiv",
            "mod": "pmod",
            "and": "pand",
            "orr": "porr",
            "xor": "pxor",
        }
        if op in secure_op_map and len(args) >= 3:
            mapped_args = [self._secure_alias(arg) for arg in args]
            if all(arg in SECURE_REGS for arg in mapped_args[:3]):
                return (secure_op_map[op], mapped_args, True)
        return (op, args, False)

    def _local_slot_offset(self, symbol: Symbol) -> int:
        """Calcula el offset real de una variable local dentro del frame."""

        if symbol.offset is None:
            return self.current_saved_area
        return self.current_saved_area + (self.current_local_size - abs(symbol.offset))

    def _parameter_shadow_offset(self, symbol: Symbol) -> Optional[int]:
        """Retorna el offset de home slot de un parametro si existe."""

        return self.current_param_shadow_offsets.get(symbol.name)

    def _ensure_parameter_home(self, symbol: Symbol):
        """Materializa en stack un parametro que necesita direccion estable."""

        shadow_offset = self._parameter_shadow_offset(symbol)
        if shadow_offset is None or symbol.name in self.current_homed_params:
            return
        if symbol.register is None or symbol.type_info is None:
            return
        self._emit_user(
            self._type_store_op(symbol.type_info),
            symbol.register,
            self._format_memory_operand(shadow_offset, "sp", symbol),
        )
        self.current_homed_params.add(symbol.name)

    def _is_array_reference_symbol(self, symbol: Symbol) -> bool:
        """Indica si un simbolo de arreglo guarda una direccion, no datos propios."""

        return bool(
            symbol.type_info is not None
            and symbol.type_info.is_array
            and symbol.segment == "stack"
            and (symbol.type_info.has_unknown_size or symbol.extra.get("array_reference"))
        )

    def _collect_parameter_homes(self, body: BlockNode) -> set[str]:
        """Detecta parametros que deben copiarse a stack por uso de direccion."""

        if self.current_function is None:
            return set()

        param_names = {param.name for param in self.current_function.params}
        homes: set[str] = set()

        def visit(current):
            """Recorre el nodo para encontrar usos de &parametro."""

            if current is None:
                return
            if isinstance(current, UnaryOpNode):
                if current.operator == "&" and isinstance(current.operand, IdentifierNode) and current.operand.name in param_names:
                    homes.add(current.operand.name)
                visit(current.operand)
                return
            if isinstance(current, BinaryOpNode):
                visit(current.left)
                visit(current.right)
                return
            if isinstance(current, CallNode):
                visit(current.callee)
                for arg in current.arguments:
                    visit(arg)
                return
            if isinstance(current, IndexAccessNode):
                visit(current.target)
                visit(current.index)
                return
            if isinstance(current, AssignmentNode):
                visit(current.target)
                visit(current.value)
                return
            if isinstance(current, VarDeclNode):
                for declarator in current.declarators:
                    visit(declarator.initializer)
                    for dim in declarator.dimensions:
                        visit(dim)
                return
            if isinstance(current, ExpressionStmtNode):
                visit(current.expression)
                return
            if isinstance(current, ReturnNode):
                visit(current.value)
                return
            if isinstance(current, IfNode):
                visit(current.condition)
                visit(current.then_block)
                for branch in current.elif_branches:
                    visit(branch.condition)
                    visit(branch.block)
                visit(current.else_block)
                return
            if isinstance(current, WhileNode):
                visit(current.condition)
                visit(current.body)
                return
            if isinstance(current, ForNode):
                visit(current.initializer)
                visit(current.condition)
                visit(current.increment)
                visit(current.body)
                return
            if isinstance(current, BlockNode):
                for stmt in current.statements:
                    visit(stmt)

        visit(body)
        return homes

    def _emit_load_symbol(self, symbol: Symbol, target_reg: str):
        """Carga el valor actual de un simbolo en un registro."""

        if symbol.type_info is None:
            return

        if symbol.segment == "global":
            addr_reg = self._alloc_temp(symbol)
            self._emit_user("la", addr_reg, AddressRef(symbol.name))
            self._emit_user(self._type_load_op(symbol.type_info), target_reg, self._format_memory_operand(0, addr_reg, symbol))
            self._free_temp(addr_reg)
            return

        if symbol.segment == "register":
            self._emit_user("mov", target_reg, symbol.register or symbol.name)
            return

        if symbol.segment == "vault":
            addr_reg = self._alloc_temp(symbol)
            self._emit_load_immediate_user(addr_reg, symbol.address or 0)
            self._emit_user(self._vault_load_op(symbol.type_info.element_type()), target_reg, self._format_memory_operand(0, addr_reg, symbol))
            self._free_temp(addr_reg)
            return

        if symbol.segment == "stack":
            self._emit_user(
                self._type_load_op(symbol.type_info),
                target_reg,
                self._format_memory_operand(self._local_slot_offset(symbol), "sp", symbol),
            )
            return

        if symbol.segment == "param":
            shadow_offset = self._parameter_shadow_offset(symbol)
            if shadow_offset is not None and symbol.name in self.current_homed_params:
                self._emit_user(
                    self._type_load_op(symbol.type_info),
                    target_reg,
                    self._format_memory_operand(shadow_offset, "sp", symbol),
                )
            elif symbol.register is not None:
                self._emit_user("mov", target_reg, symbol.register)
            elif shadow_offset is not None:
                self._emit_user(
                    self._type_load_op(symbol.type_info),
                    target_reg,
                    self._format_memory_operand(shadow_offset, "sp", symbol),
                )
            return

        self.error(symbol, "unsupported_symbol_segment", f'no se puede cargar el simbolo "{symbol.name}".')

    def _emit_store_symbol(self, symbol: Symbol, value_reg: str):
        """Almacena un registro en la ubicacion de un simbolo."""

        if symbol.type_info is None:
            return

        if symbol.segment == "global":
            addr_reg = self._alloc_temp(symbol)
            self._emit_user("la", addr_reg, AddressRef(symbol.name))
            self._emit_user(self._type_store_op(symbol.type_info), value_reg, self._format_memory_operand(0, addr_reg, symbol))
            self._free_temp(addr_reg)
            return

        if symbol.segment == "register":
            self.error(symbol, "readonly_register_store", f'no se puede escribir en el registro de solo lectura "{symbol.name}".')
            return

        if symbol.segment == "vault":
            addr_reg = self._alloc_temp(symbol)
            self._emit_load_immediate_user(addr_reg, symbol.address or 0)
            self._emit_user(self._vault_store_op(symbol.type_info.element_type()), value_reg, self._format_memory_operand(0, addr_reg, symbol))
            self._free_temp(addr_reg)
            return

        if symbol.segment == "stack":
            self._emit_user(
                self._type_store_op(symbol.type_info),
                value_reg,
                self._format_memory_operand(self._local_slot_offset(symbol), "sp", symbol),
            )
            return

        if symbol.segment == "param":
            if symbol.register is not None:
                self._emit_user("mov", symbol.register, value_reg)
            shadow_offset = self._parameter_shadow_offset(symbol)
            if shadow_offset is not None and (symbol.name in self.current_homed_params or symbol.register is None):
                self._emit_user(
                    self._type_store_op(symbol.type_info),
                    value_reg,
                    self._format_memory_operand(shadow_offset, "sp", symbol),
                )
            return

        self.error(symbol, "unsupported_symbol_segment", f'no se puede almacenar el simbolo "{symbol.name}".')

    def _is_data_mem_index_access(self, node) -> bool:
        """Reconoce accesos directos data_mem[byte_offset]."""

        return (
            isinstance(node, IndexAccessNode)
            and isinstance(node.target, IdentifierNode)
            and node.target.name == BUILTIN_DATA_MEMORY
        )

    # PROGRAMA

    def _emit_program(self, program: ProgramNode):
        """Emite el punto de entrada y luego todas las funciones del programa."""

        if self.emit_entrypoint:
            main_symbol = self.symbol_table.global_scope.symbols.get("main")
            if main_symbol is None or main_symbol.kind != "function":
                self.diagnostics.append(
                    CodegenDiagnostic(
                        line=program.line,
                        column=program.column,
                        code="missing_main_entrypoint",
                        message='no se encontro una funcion "main" para generar el punto de entrada.',
                    )
                )
                return

            self._emit_label("__init__")
            self._emit("li", "sp", StackBaseRef())

            for decl in program.declarations:
                if isinstance(decl, VarDeclNode):
                    self._emit_global_initializers(decl)

            self._emit("mov", "p0", "zero", comment="resultado de programa por defecto")
            self._emit("call", LabelRef("main"), comment="entrada principal")
            self._emit("end", comment="fin real del programa tras retornar de main")
            self._emit_label("__end_fallback__")
            self._emit("jmp", LabelRef("__end_fallback__"), comment="respaldo si end se interpreta como nop")

        for decl in program.declarations:
            if isinstance(decl, FunctionDeclNode):
                self._emit_function(decl)

        if not self.emit_entrypoint:
            # Sin __init__, end queda al final fisico del stream generado.
            self._emit("end")

    def _emit_global_initializers(self, node: VarDeclNode):
        """Genera el codigo de inicializacion para globales con valor."""

        previous_scope = self.current_scope
        self.current_scope = self.symbol_table.global_scope
        self._reset_temp_pool()

        for declarator in node.declarators:
            if declarator.initializer is None:
                continue

            symbol = self.symbol_table.global_scope.symbols.get(declarator.name)
            if symbol is None or symbol.type_info is None:
                continue

            if not self._ensure_codegen_type(symbol.type_info, declarator, f'global "{declarator.name}"'):
                continue

            value_reg = self._emit_expression(declarator.initializer)
            self._emit_store_symbol(symbol, value_reg)
            self._free_temp(value_reg)

        self.current_scope = previous_scope

    # FUNCIONES

    def _emit_function_cleanup(self, node: FunctionDeclNode, total_frame: int):
        """Restaura estado de funcion y emite el retorno final."""

        if self.current_function_secure:
            self._emit("quit")

        self._emit_program_result_store_if_main(node)

        for index, register in reversed(list(enumerate(SAVE_REGS))):
            self._emit("ldw", register, self._format_memory_operand(index * WORD_SIZE, "sp", node))

        self._emit_sp_adjust(-total_frame)
        self._emit("ret")

    def _emit_program_result_store_if_main(self, node: FunctionDeclNode):
        """Guarda p0 en la celda de resultado cuando retorna main."""

        if not self.emit_entrypoint or node.name != "main":
            return
        if PROGRAM_RESULT_SYMBOL not in self.symbol_table.global_scope.symbols:
            return
        self._emit("la", "r0", AddressRef(PROGRAM_RESULT_SYMBOL), comment="celda de resultado del programa")
        self._emit("stw", "p0", self._format_memory_operand(0, "r0", node), comment="guardar resultado final")

    def _emit_function(self, node: FunctionDeclNode):
        """Genera el ensamblador completo de una funcion."""

        function_symbol = self.symbol_table.global_scope.symbols.get(node.name)
        if function_symbol is None:
            return

        return_type = function_symbol.return_type
        if (
            return_type is not None
            and not return_type.is_void
            and not self._ensure_codegen_type(return_type, node, f'retorno de "{node.name}"')
        ):
            return

        for param, param_type in zip(node.params, function_symbol.params):
            if param_type is not None and not self._ensure_codegen_type(param_type, param, f'parametro "{param.name}"'):
                return

        previous_scope = self._push_scope(f"function:{node.name}")
        previous_function = self.current_function
        previous_function_symbol = self.current_function_symbol
        previous_secure = self.current_function_secure
        previous_secure_exit_label = self.current_secure_exit_label
        previous_homed_params = self.current_homed_params

        self.current_function = node
        self.current_function_symbol = function_symbol
        self.current_function_secure = node.secure is not None
        self.current_secure_exit_label = self._new_label("secure_exit") if node.secure is not None else None
        self.current_loop_stack = []
        self.current_call_spill_max = 0
        self.current_homed_params = set()
        self._reset_temp_pool()

        self.current_local_size = function_symbol.extra.get("local_size", 0)
        homed_params = self._collect_parameter_homes(node.body)
        self.current_param_shadow_offsets = {
            param.name: self.current_saved_area + self.current_local_size + (index * WORD_SIZE)
            for index, param in enumerate([param for param in node.params if param.name in homed_params])
        }
        total_frame = self.current_saved_area + self.current_local_size + (len(homed_params) * WORD_SIZE)

        self._emit_label(node.name)
        self._emit_sp_adjust(total_frame)

        for index, register in enumerate(SAVE_REGS):
            self._emit("stw", register, self._format_memory_operand(index * WORD_SIZE, "sp", node))

        if self.current_function_secure:
            if not self._validate_secure_literal(node):
                self.current_param_shadow_offsets = {}
                self.current_function = previous_function
                self.current_function_symbol = previous_function_symbol
                self.current_function_secure = previous_secure
                self.current_secure_exit_label = previous_secure_exit_label
                self.current_homed_params = previous_homed_params
                self._pop_scope(previous_scope)
                return
            if return_type is not None and not return_type.is_void:
                self._emit("mov", "p0", "zero")
            self._emit("login", node.secure.value)
            self._emit("beqz", "lr", LabelRef(self.current_secure_exit_label))

        self._emit_block(node.body, create_scope=True)

        if self.current_secure_exit_label is not None:
            self._emit_label(self.current_secure_exit_label)
            self._emit_function_cleanup(node, total_frame)
        elif not self._block_guarantees_return(node.body):
            # Solo dejamos una limpieza implicita si el cuerpo puede caer al final.
            self._emit_function_cleanup(node, total_frame)

        self.current_param_shadow_offsets = {}
        function_symbol.extra["call_spill_size"] = self.current_call_spill_max
        function_symbol.extra["param_home_count"] = len(homed_params)
        self.current_function = previous_function
        self.current_function_symbol = previous_function_symbol
        self.current_function_secure = previous_secure
        self.current_secure_exit_label = previous_secure_exit_label
        self.current_homed_params = previous_homed_params
        self._pop_scope(previous_scope)

    # BLOQUES Y SENTENCIAS

    def _emit_block(self, node: BlockNode, create_scope: bool):
        """Emite todas las sentencias de un bloque."""

        previous_scope = None
        if create_scope:
            previous_scope = self._push_scope(f"block:{id(node)}")

        for stmt in node.statements:
            self._emit_statement(stmt)

        if create_scope:
            self._pop_scope(previous_scope)

    def _block_guarantees_return(self, node: BlockNode) -> bool:
        """Determina si un bloque siempre termina retornando."""

        for statement in node.statements:
            if self._statement_guarantees_return(statement):
                return True
        return False

    def _statement_guarantees_return(self, node) -> bool:
        """Evalua si una sentencia garantiza la salida inmediata de la funcion."""

        if isinstance(node, ReturnNode):
            return True
        if isinstance(node, BlockNode):
            return self._block_guarantees_return(node)
        if isinstance(node, IfNode):
            if node.then_block is None or not self._block_guarantees_return(node.then_block):
                return False
            if node.else_block is None or not self._block_guarantees_return(node.else_block):
                return False
            return all(self._block_guarantees_return(branch.block) for branch in node.elif_branches)
        return False

    def _emit_statement(self, node):
        """Despacha la generacion segun el tipo de sentencia."""

        if isinstance(node, VarDeclNode):
            self._emit_var_decl(node)
            return

        if isinstance(node, AssignmentNode):
            self._emit_assignment(node)
            return

        if isinstance(node, IfNode):
            self._emit_if(node)
            return

        if isinstance(node, WhileNode):
            self._emit_while(node)
            return

        if isinstance(node, ForNode):
            self._emit_for(node)
            return

        if isinstance(node, ReturnNode):
            self._emit_return(node)
            return

        if isinstance(node, ContinueNode):
            if self.current_loop_stack:
                self._emit_user("jmp", LabelRef(self.current_loop_stack[-1]["continue"]))
            return

        if isinstance(node, BreakNode):
            if self.current_loop_stack:
                self._emit_user("jmp", LabelRef(self.current_loop_stack[-1]["break"]))
            return

        if isinstance(node, ExpressionStmtNode):
            if isinstance(node.expression, CallNode):
                result_reg = self._emit_call(node.expression, discard_result=True)
                if result_reg is not None:
                    self._free_temp(result_reg)
            elif node.expression is not None:
                value_reg = self._emit_expression(node.expression)
                self._free_temp(value_reg)
            return

        if isinstance(node, BlockNode):
            self._emit_block(node, create_scope=True)

    def _emit_var_decl(self, node: VarDeclNode):
        """Genera inicializacion de variables locales declaradas."""

        for declarator in node.declarators:
            symbol = self._resolve_symbol(declarator.name)
            if symbol is None or symbol.type_info is None:
                continue

            if not self._ensure_codegen_type(symbol.type_info, declarator, f'variable "{declarator.name}"'):
                continue

            if declarator.initializer is None:
                continue

            value_reg = self._emit_expression(declarator.initializer)
            self._emit_store_symbol(symbol, value_reg)
            self._free_temp(value_reg)

    def _emit_assignment(self, node: AssignmentNode):
        """Genera asignaciones simples y compuestas."""

        target_type = self._infer_type(node.target)
        if target_type is None or not self._ensure_codegen_type(target_type, node.target, "destino de asignacion"):
            return

        value_reg = self._emit_expression(node.value)

        if node.operator == "=":
            self._emit_store_target(node.target, target_type, value_reg)
            self._free_temp(value_reg)
            return

        current_reg = self._emit_load_target(node.target, target_type)
        compound_operator = node.operator[:-1] if node.operator.endswith("=") else node.operator
        result_reg = self._emit_binary_arithmetic(
            BinaryOpNode(
                operator=compound_operator,
                left=None,
                right=None,
                line=node.line,
                column=node.column,
            ),
            current_reg,
            value_reg,
        )
        self._emit_store_target(node.target, target_type, result_reg)
        self._free_temp(value_reg)
        self._free_temp(result_reg)

    def _emit_if(self, node: IfNode):
        """Genera saltos y bloques asociados a una estructura if."""

        end_label = self._new_label("if_end")
        next_label = self._new_label("if_else")

        self._emit_branch_if_false(node.condition, next_label)
        self._emit_block(node.then_block, create_scope=True)
        self._emit_user("jmp", LabelRef(end_label))

        self._emit_label(next_label)
        for index, elif_branch in enumerate(node.elif_branches):
            branch_next = self._new_label(f"elif_next_{index}")
            self._emit_branch_if_false(elif_branch.condition, branch_next)
            self._emit_block(elif_branch.block, create_scope=True)
            self._emit_user("jmp", LabelRef(end_label))
            self._emit_label(branch_next)

        if node.else_block is not None:
            self._emit_block(node.else_block, create_scope=True)

        self._emit_label(end_label)

    def _emit_while(self, node: WhileNode):
        """Genera un ciclo while con labels de continue y break."""

        loop_label = self._new_label("while_cond")
        end_label = self._new_label("while_end")

        self.current_loop_stack.append({"continue": loop_label, "break": end_label})

        self._emit_label(loop_label)
        self._emit_branch_if_false(node.condition, end_label)
        self._emit_block(node.body, create_scope=True)
        self._emit_user("jmp", LabelRef(loop_label))
        self._emit_label(end_label)

        self.current_loop_stack.pop()

    def _emit_for(self, node: ForNode):
        """Genera un ciclo for respetando init, condicion y update."""

        previous_scope = self._push_scope(f"for:{id(node)}")
        cond_label = self._new_label("for_cond")
        update_label = self._new_label("for_update")
        end_label = self._new_label("for_end")

        if node.initializer is not None:
            self._emit_statement(node.initializer)

        self.current_loop_stack.append({"continue": update_label, "break": end_label})

        self._emit_label(cond_label)
        self._emit_branch_if_false(node.condition, end_label)
        self._emit_block(node.body, create_scope=True)
        self._emit_label(update_label)
        if node.increment is not None:
            self._emit_statement(node.increment)
        self._emit_user("jmp", LabelRef(cond_label))
        self._emit_label(end_label)

        self.current_loop_stack.pop()
        self._pop_scope(previous_scope)

    def _emit_return(self, node: ReturnNode):
        """Genera un retorno directo, incluyendo limpieza del frame."""

        if node.value is not None:
            needs_load_delay = self._return_value_needs_load_delay(node.value)
            value_reg = self._emit_expression(node.value)
            if needs_load_delay:
                self._emit("nop", comment="espera load-use antes de mover retorno")
                self._emit("nop", comment="espera load-use antes de mover retorno")
            self._emit_user("mov", "p0", value_reg)
            self._free_temp(value_reg)
        total_frame = self.current_saved_area + self.current_local_size + (len(self.current_param_shadow_offsets) * WORD_SIZE)
        self._emit_function_cleanup(self.current_function, total_frame)

    def _return_value_needs_load_delay(self, node) -> bool:
        """Indica si el retorno quedara como carga de memoria seguida de mov a p0."""

        if isinstance(node, IndexAccessNode):
            return True
        if isinstance(node, IdentifierNode):
            symbol = self._resolve_symbol(node.name)
            if symbol is None or symbol.type_info is None or symbol.type_info.is_array:
                return False
            if symbol.segment in {"global", "stack", "vault"}:
                return True
            if symbol.segment == "param":
                shadow_offset = self._parameter_shadow_offset(symbol)
                return symbol.register is None or (
                    shadow_offset is not None and symbol.name in self.current_homed_params
                )
        if isinstance(node, UnaryOpNode) and node.operator == "*":
            return True
        return False

    # LVALUES

    def _emit_load_target(self, node, target_type: TypeInfo) -> str:
        """Carga el valor de un lvalue en un registro temporal."""

        if isinstance(node, IdentifierNode):
            symbol = self._resolve_symbol(node.name)
            result_reg = self._alloc_temp(node)
            if symbol is not None:
                self._emit_load_symbol(symbol, result_reg)
            return result_reg

        if isinstance(node, IndexAccessNode):
            addr_reg = self._emit_address(node)
            result_reg = self._alloc_temp(node)
            target_base_type = self._infer_type(node.target)
            load_op = (
                self._vault_load_op(target_type)
                if target_base_type is not None and target_base_type.name == "vault"
                else self._type_load_op(target_type)
            )
            self._emit_user(load_op, result_reg, self._format_memory_operand(0, addr_reg))
            self._free_temp(addr_reg)
            return result_reg

        self.error(node, "unsupported_assignment_target", "el destino de asignacion no puede traducirse a ensamblador.")
        return self._alloc_temp(node)

    def _emit_store_target(self, node, target_type: TypeInfo, value_reg: str):
        """Almacena un registro en el lvalue destino indicado."""

        if isinstance(node, IdentifierNode):
            symbol = self._resolve_symbol(node.name)
            if symbol is not None:
                self._emit_store_symbol(symbol, value_reg)
            return

        if isinstance(node, IndexAccessNode):
            addr_reg = self._emit_address(node)
            target_base_type = self._infer_type(node.target)
            store_op = (
                self._vault_store_op(target_type)
                if target_base_type is not None and target_base_type.name == "vault"
                else self._type_store_op(target_type)
            )
            self._emit_user(store_op, value_reg, self._format_memory_operand(0, addr_reg))
            self._free_temp(addr_reg)
            return

        self.error(node, "unsupported_assignment_target", "el destino de asignacion no puede traducirse a ensamblador.")

    def _emit_address(self, node) -> str:
        """Calcula la direccion efectiva de un identificador o acceso indexado."""

        if isinstance(node, IdentifierNode):
            symbol = self._resolve_symbol(node.name)
            result_reg = self._alloc_temp(node)
            if symbol is None or symbol.type_info is None:
                return result_reg

            if symbol.segment == "global":
                self._emit_user("la", result_reg, AddressRef(symbol.name))
                return result_reg

            if symbol.segment == "vault":
                self._emit_load_immediate_user(result_reg, symbol.address or 0)
                return result_reg

            if symbol.segment == "stack":
                if self._is_array_reference_symbol(symbol):
                    self._emit_user(
                        "ldw",
                        result_reg,
                        self._format_memory_operand(self._local_slot_offset(symbol), "sp", symbol),
                    )
                    return result_reg
                self._emit_add_immediate_user(result_reg, "sp", self._local_slot_offset(symbol))
                return result_reg

            if symbol.segment == "param":
                if symbol.type_info.is_array:
                    if symbol.register is not None:
                        self._emit_user("mov", result_reg, symbol.register)
                        return result_reg
                    shadow_offset = self._parameter_shadow_offset(symbol)
                    if shadow_offset is not None:
                        self._emit_user(
                            self._type_load_op(symbol.type_info),
                            result_reg,
                            self._format_memory_operand(shadow_offset, "sp", symbol),
                        )
                        return result_reg
                    self.error(node, "unsupported_array_parameter_address", f'no se pudo resolver la referencia de "{node.name}".')
                    return result_reg

                shadow_offset = self._parameter_shadow_offset(symbol)
                if shadow_offset is not None:
                    self._ensure_parameter_home(symbol)
                    self._emit_add_immediate_user(result_reg, "sp", shadow_offset)
                    return result_reg
                self.error(node, "unsupported_parameter_address", f'no se pudo resolver la direccion de "{node.name}".')
                return result_reg

        if isinstance(node, IndexAccessNode):
            if self._is_data_mem_index_access(node):
                base_reg = self._alloc_temp(node)
                index_reg = self._emit_expression(node.index)
                self._emit_load_immediate_user(base_reg, 0)
                self._emit_user("add", base_reg, base_reg, index_reg)
                self._free_temp(index_reg)
                return base_reg

            target_type = self._infer_type(node.target)
            if target_type is None:
                return self._alloc_temp(node)

            if target_type.is_array:
                base_reg = self._emit_address(node.target)
            else:
                base_reg = self._emit_expression(node.target)

            index_reg = self._emit_expression(node.index)

            element_type = (
                target_type.element_type()
                if target_type.is_array
                else TypeInfo(target_type.name, vault_inner=target_type.vault_inner)
            )
            element_size = self._type_size(element_type)

            if element_size > 1:
                self._emit_user("muli", index_reg, index_reg, element_size)

            self._emit_user("add", base_reg, base_reg, index_reg)
            self._free_temp(index_reg)
            return base_reg

        self.error(node, "unsupported_address_expression", "no se puede calcular la direccion solicitada.")
        return self._alloc_temp(node)

    # EXPRESIONES

    def _emit_expression(self, node) -> str:
        """Genera el valor de una expresion en un registro temporal."""

        if isinstance(node, IdentifierNode):
            symbol = self._resolve_symbol(node.name)
            result_reg = self._alloc_temp(node)
            if symbol is None or symbol.type_info is None:
                return result_reg

            if not self._ensure_codegen_type(symbol.type_info, node, f'referencia "{node.name}"'):
                return result_reg

            if symbol.type_info.is_array:
                self._free_temp(result_reg)
                return self._emit_address(node)

            self._emit_load_symbol(symbol, result_reg)
            return result_reg

        if isinstance(node, LiteralNode):
            literal_type = self._infer_type(node)
            result_reg = self._alloc_temp(node)
            if literal_type is None or not self._ensure_codegen_type(literal_type, node, "literal"):
                return result_reg

            if node.literal_type == "string":
                self.error(node, "unsupported_string_literal_codegen", "los literales string aun no se soportan en generacion de ensamblador.")
                return result_reg

            self._emit_load_immediate_user(result_reg, self._literal_value(node))
            return result_reg

        if isinstance(node, UnaryOpNode):
            return self._emit_unary(node)

        if isinstance(node, BinaryOpNode):
            return self._emit_binary(node)

        if isinstance(node, CallNode):
            return self._emit_call(node)

        if isinstance(node, IndexAccessNode):
            target_type = self._infer_type(node)
            result_reg = self._alloc_temp(node)
            if target_type is None or not self._ensure_codegen_type(target_type, node, "acceso indexado"):
                return result_reg
            addr_reg = self._emit_address(node)
            base_type = self._infer_type(node.target)
            load_op = (
                self._vault_load_op(target_type)
                if base_type is not None and base_type.name == "vault"
                else self._type_load_op(target_type)
            )
            self._emit_user(load_op, result_reg, self._format_memory_operand(0, addr_reg))
            self._free_temp(addr_reg)
            return result_reg

        self.error(node, "unsupported_expression_codegen", "la expresion no puede traducirse a ensamblador.")
        return self._alloc_temp(node)

    def _emit_unary(self, node: UnaryOpNode) -> str:
        """Genera una operacion unaria."""

        operand_type = self._infer_type(node.operand)
        if operand_type is None or not self._ensure_codegen_type(operand_type, node.operand, "operando unario"):
            return self._alloc_temp(node)

        if node.operator == "&":
            return self._emit_address(node.operand)

        operand_reg = self._emit_expression(node.operand)

        if node.operator == "-":
            self._emit_user("sub", operand_reg, "zero", operand_reg)
            return operand_reg

        if node.operator == "!":
            self._emit_user("seqz", operand_reg, operand_reg)
            return operand_reg

        if node.operator == "*":
            pointee_type = TypeInfo(operand_type.name, vault_inner=operand_type.vault_inner)
            result_reg = self._alloc_temp(node)
            self._emit_user(self._type_load_op(pointee_type), result_reg, self._format_memory_operand(0, operand_reg))
            self._free_temp(operand_reg)
            return result_reg

        self.error(node, "unsupported_unary_operator", f'el operador "{node.operator}" no esta soportado en ensamblador.')
        return operand_reg

    def _emit_binary(self, node: BinaryOpNode) -> str:
        """Genera una operacion binaria o comparacion."""

        result_type = self._infer_type(node)
        if result_type is None or not self._ensure_codegen_type(result_type, node, f'operacion "{node.operator}"'):
            return self._alloc_temp(node)

        if self.current_function_secure:
            fused_result = self._emit_secure_fused_binary(node)
            if fused_result is not None:
                return fused_result

        if node.operator == "~":
            self.error(node, "unsupported_operator_codegen", 'la ISA actual no define una instruccion para el operador "~".')
            return self._alloc_temp(node)

        if node.operator in BRANCH_TRUE_OPS:
            return self._emit_compare_value(node)

        left_reg = self._emit_expression(node.left)
        immediate_value = self._immediate_operand(node.right)
        if immediate_value is not None and node.operator in ARITHMETIC_IMM_OPS:
            op_name = ARITHMETIC_IMM_OPS[node.operator]
            self._emit_user(op_name, left_reg, left_reg, str(immediate_value))
            return left_reg

        if node.operator in {"+", "*", "&", "|", "^"}:
            immediate_value = self._immediate_operand(node.left)
            if immediate_value is not None and node.operator in ARITHMETIC_IMM_OPS:
                right_reg = self._emit_expression(node.right)
                op_name = ARITHMETIC_IMM_OPS[node.operator]
                self._emit_user(op_name, right_reg, right_reg, str(immediate_value))
                self._free_temp(left_reg)
                return right_reg

        right_reg = self._emit_expression(node.right)
        result_reg = self._emit_binary_arithmetic(node, left_reg, right_reg)
        self._free_temp(right_reg)
        return result_reg

    def _emit_binary_arithmetic(self, node: BinaryOpNode, left_reg: str, right_reg: str) -> str:
        """Emite la instruccion ALU correspondiente a una operacion aritmetica."""

        if node.operator not in ARITHMETIC_OPS:
            self.error(node, "unsupported_operator_codegen", f'el operador "{node.operator}" no esta soportado en ensamblador.')
            return left_reg

        op_name = ARITHMETIC_OPS[node.operator]
        self._emit_user(op_name, left_reg, left_reg, right_reg)
        return left_reg

    def _emit_secure_fused_binary(self, node: BinaryOpNode) -> Optional[str]:
        """Aprovecha instrucciones PR de cuatro operandos cuando la forma coincide."""

        if not isinstance(node.left, BinaryOpNode):
            return None

        if node.operator == "^" and node.left.operator == "^":
            first_reg = self._emit_expression(node.left.left)
            second_reg = self._emit_expression(node.left.right)
            third_reg = self._emit_expression(node.right)
            self._emit("pxorxor", first_reg, first_reg, second_reg, third_reg, secure=True)
            self._free_temp(third_reg)
            self._free_temp(second_reg)
            return first_reg

        if node.operator == "+" and node.left.operator == "+":
            first_reg = self._emit_expression(node.left.left)
            second_reg = self._emit_expression(node.left.right)
            third_reg = self._emit_expression(node.right)
            self._emit("paddadd", first_reg, first_reg, second_reg, third_reg, secure=True)
            self._free_temp(third_reg)
            self._free_temp(second_reg)
            return first_reg

        if node.operator == "+" and node.left.operator == "<<":
            first_reg = self._emit_expression(node.left.left)
            second_reg = self._emit_expression(node.left.right)
            third_reg = self._emit_expression(node.right)
            self._emit("pslladd", first_reg, first_reg, second_reg, third_reg, secure=True)
            self._free_temp(third_reg)
            self._free_temp(second_reg)
            return first_reg

        if node.operator == "+" and node.left.operator == ">>":
            first_reg = self._emit_expression(node.left.left)
            second_reg = self._emit_expression(node.left.right)
            third_reg = self._emit_expression(node.right)
            self._emit("psrladd", first_reg, first_reg, second_reg, third_reg, secure=True)
            self._free_temp(third_reg)
            self._free_temp(second_reg)
            return first_reg

        return None

    def _emit_compare_value(self, node: BinaryOpNode) -> str:
        """Materializa una comparacion booleana en 0 o 1."""

        left_reg = self._emit_expression(node.left)
        result_reg = self._alloc_temp(node)
        if node.operator in {"==", "!="}:
            immediate_value = self._immediate_operand(node.right)
            if immediate_value is not None:
                self._emit_user("seqi", result_reg, left_reg, str(immediate_value))
            else:
                right_reg = self._emit_expression(node.right)
                self._emit_user("seq", result_reg, left_reg, right_reg)
                self._free_temp(right_reg)

            if node.operator == "!=":
                self._emit_user("seqz", result_reg, result_reg)

            self._free_temp(left_reg)
            return result_reg

        right_reg = self._emit_expression(node.right)
        true_label = self._new_label("cmp_true")
        end_label = self._new_label("cmp_end")

        self._emit_load_immediate_user(result_reg, 0)
        self._emit_user(BRANCH_TRUE_OPS[node.operator], left_reg, right_reg, LabelRef(true_label))
        self._emit_user("jmp", LabelRef(end_label))
        self._emit_label(true_label)
        self._emit_load_immediate_user(result_reg, 1)
        self._emit_label(end_label)

        self._free_temp(right_reg)
        self._free_temp(left_reg)
        return result_reg

    def _emit_call(self, node: CallNode, discard_result: bool = False) -> Optional[str]:
        """Genera una llamada directa, moviendo argumentos y retorno."""

        if not isinstance(node.callee, IdentifierNode):
            self.error(node, "unsupported_indirect_call_codegen", "solo se soportan llamadas directas a funciones.")
            return self._alloc_temp(node)

        callee_symbol = self._resolve_symbol(node.callee.name)
        if callee_symbol is None or callee_symbol.return_type is None:
            return self._alloc_temp(node)

        if (
            not callee_symbol.return_type.is_void
            and not self._ensure_codegen_type(callee_symbol.return_type, node, f'retorno de "{node.callee.name}"')
        ):
            return self._alloc_temp(node)

        arg_regs: List[str] = []
        for index, arg in enumerate(node.arguments):
            arg_type = self._infer_type(arg)
            if arg_type is None or not self._ensure_codegen_type(arg_type, arg, f'argumento {index + 1}'):
                continue
            arg_regs.append(self._emit_expression(arg))

        for index, reg in enumerate(arg_regs):
            self._emit_user("mov", f"p{index}", reg)

        live_regs = [reg for reg in self._current_live_temp_regs() if reg not in arg_regs]
        spill_size = len(live_regs) * WORD_SIZE
        if spill_size > 0:
            self.current_call_spill_max = max(self.current_call_spill_max, spill_size)
            self._emit_add_immediate_user("sp", "sp", spill_size)
            for index, reg in enumerate(live_regs):
                self._emit_user("stw", reg, self._format_memory_operand(index * WORD_SIZE, "sp", node))

        self._emit_user("call", LabelRef(node.callee.name))

        if spill_size > 0:
            for index, reg in reversed(list(enumerate(live_regs))):
                self._emit_user("ldw", reg, self._format_memory_operand(index * WORD_SIZE, "sp", node))
            self._emit_add_immediate_user("sp", "sp", -spill_size)

        for reg in arg_regs:
            self._free_temp(reg)

        if callee_symbol.return_type.is_void:
            if discard_result:
                return None
            result_reg = self._alloc_temp(node)
            self._emit_user("mov", result_reg, "zero")
            return result_reg

        if discard_result:
            return None

        result_reg = self._alloc_temp(node)
        self._emit("nop", comment="espera retorno de call antes de leer p0")
        self._emit_user("mov", result_reg, "p0")
        return result_reg

    def _emit_branch_if_false(self, expression, target_label: str):
        """Genera el salto de una condicion evaluada como falsa."""

        if isinstance(expression, BinaryOpNode) and expression.operator in BRANCH_FALSE_OPS:
            left_reg = self._emit_expression(expression.left)
            right_reg = self._emit_expression(expression.right)
            self._emit_user(BRANCH_FALSE_OPS[expression.operator], left_reg, right_reg, LabelRef(target_label))
            self._free_temp(right_reg)
            self._free_temp(left_reg)
            return

        cond_reg = self._emit_expression(expression)
        self._emit_user("beqz", cond_reg, LabelRef(target_label))
        self._free_temp(cond_reg)

    def _literal_value(self, node: LiteralNode) -> int:
        """Convierte un literal AST a su valor entero materializable."""

        if node.literal_type == "hex":
            return int(str(node.value), 0)
        if node.literal_type == "char":
            text = str(node.value)
            if len(text) >= 2 and text[0] == "'" and text[-1] == "'":
                body = text[1:-1]
                if body.startswith("\\"):
                    escape_map = {"n": "\n", "t": "\t", "r": "\r", "b": "\b", "\\": "\\", "'": "'", '"': '"'}
                    body = escape_map.get(body[1:], body[1:])
                return ord(body)
            return ord(text[0])
        if node.literal_type == "bool":
            return 1 if bool(node.value) else 0
        if node.literal_type == "int":
            return int(str(node.value), 10)
        return 0

    def _immediate_operand(self, node) -> Optional[int]:
        """Extrae un inmediato entero simple util para variantes tipo I."""

        if not isinstance(node, LiteralNode):
            return None
        if node.literal_type not in {"int", "hex", "char", "bool"}:
            return None
        return self._literal_value(node)

    def _validate_secure_literal(self, node: FunctionDeclNode) -> bool:
        """Valida que la contrasena de @secure cumpla el formato esperado."""

        if node.secure is None:
            return True

        try:
            secure_value = int(str(node.secure.value), 0)
        except ValueError:
            self.error(
                node,
                "invalid_secure_literal",
                f'la anotacion secure de "{node.name}" debe usar un literal hexadecimal valido.',
            )
            return False

        if secure_value < 0 or secure_value > 0xFFFFF:
            self.error(
                node,
                "invalid_secure_literal",
                f'la anotacion secure de "{node.name}" debe usar una contrasena hex de 5 digitos como maximo.',
            )
            return False

        return True

    def _immediate_load_size(self, value: int) -> int:
        """Estima cuantas instrucciones requiere cargar un inmediato."""

        if SIGNED_IMMEDIATE_MIN <= value <= SIGNED_IMMEDIATE_MAX:
            return 1
        return 1 + len([chunk for chunk in self._split_signed_immediate(value) if chunk != 0])

    def _instruction_size(self, item: Instruction) -> int:
        """Calcula el tamano final de una instruccion tras expandir pseudos."""

        if item.op == "la" and len(item.args) >= 2 and isinstance(item.args[1], AddressRef):
            if self.symbol_table is None:
                return 1
            symbol = self.symbol_table.global_scope.symbols.get(item.args[1].symbol_name)
            if symbol is None or symbol.address is None:
                return 1
            return self._immediate_load_size(symbol.address)
        if item.op == "li" and len(item.args) >= 2 and isinstance(item.args[1], StackBaseRef):
            return self._immediate_load_size(self.stack_base_address)
        return 1

    def _finalize_memory_layout(self, code_size: int) -> tuple[int, int]:
        """Fija direcciones finales de codigo, datos y base del stack."""

        if self.symbol_table is None:
            return (0, 0)

        if code_size > MEMORY_SIZE:
            self.diagnostics.append(
                CodegenDiagnostic(
                    line=0,
                    column=0,
                    code="code_segment_overflow",
                    message=(
                        f"el codigo generado ocupa {code_size} bytes y excede la memoria total de 64KB "
                        f"({MEMORY_SIZE} bytes)."
                    ),
                )
            )
            return (0, 0)

        # La microarquitectura usa memorias separadas para instrucciones y datos.
        # Por eso los simbolos globales viven desde DATA_BASE dentro de data_memory,
        # no despues del segmento de instrucciones cargado en imem.
        relocated_data_base = DATA_BASE
        global_data_size = max(0, self.symbol_table.next_global_address - DATA_BASE)
        data_end = relocated_data_base + global_data_size
        self.stack_base_address = self._align(data_end, WORD_SIZE)
        if data_end > MEMORY_SIZE:
            self.diagnostics.append(
                CodegenDiagnostic(
                    line=0,
                    column=0,
                    code="data_segment_overflow",
                    message=(
                        f"los datos globales ocupan hasta la direccion 0x{data_end - 1:04X} y exceden "
                        f"la memoria total de 64KB."
                    ),
                )
            )
            return (relocated_data_base, data_end)

        relocation_delta = relocated_data_base - DATA_BASE
        for symbol in self.symbol_table.global_scope.symbols.values():
            if symbol.segment != "global" or symbol.address is None:
                continue
            original_address = symbol.extra.setdefault("_provisional_address", symbol.address)
            symbol.address = original_address + relocation_delta
            if symbol.address + symbol.size > MEMORY_SIZE:
                self.diagnostics.append(
                    CodegenDiagnostic(
                        line=symbol.line,
                        column=symbol.column,
                        code="global_symbol_out_of_memory",
                        message=(
                            f'la variable global "{symbol.name}" excede el espacio de memoria disponible '
                            f"de 64KB."
                        ),
                    )
                )

        if self.diagnostics:
            return (relocated_data_base, data_end)

        max_frame_size = 0
        for symbol in self.symbol_table.global_scope.symbols.values():
            if symbol.kind != "function":
                continue
            local_size = int(symbol.extra.get("local_size", 0))
            param_shadow_size = int(symbol.extra.get("param_home_count", 0)) * WORD_SIZE
            call_spill_size = int(symbol.extra.get("call_spill_size", 0))
            frame_size = self.current_saved_area + local_size + param_shadow_size + call_spill_size
            max_frame_size = max(max_frame_size, frame_size)

        if self.stack_base_address + max_frame_size > MEMORY_SIZE:
            self.diagnostics.append(
                CodegenDiagnostic(
                    line=0,
                    column=0,
                    code="stack_space_exhausted",
                    message=(
                        "no hay suficiente espacio entre codigo/datos y el stack para alojar el frame "
                        f"mas grande ({max_frame_size} bytes) dentro de 64KB."
                    ),
                )
            )
        return (relocated_data_base, data_end)

    def _validate_relative_immediate(
        self,
        item: Instruction,
        offset: int,
        current_index: int,
    ):
        """Verifica que un salto relativo quepa en el inmediato de la ISA."""

        if item.op in RELATIVE_BRANCH_OPS:
            minimum = -(1 << (BRANCH_IMMEDIATE_BITS - 1))
            maximum = (1 << (BRANCH_IMMEDIATE_BITS - 1)) - 1
            if offset < minimum or offset > maximum:
                self.diagnostics.append(
                    CodegenDiagnostic(
                        line=0,
                        column=0,
                        code="branch_offset_out_of_range",
                        message=(
                            f'el salto relativo "{item.op}" en la instruccion {current_index} requiere '
                            f"offset {offset}, fuera del rango de {minimum} a {maximum}."
                        ),
                    )
                )
        elif item.op in RELATIVE_JUMP_OPS:
            minimum = -(1 << (JUMP_IMMEDIATE_BITS - 1))
            maximum = (1 << (JUMP_IMMEDIATE_BITS - 1)) - 1
            if offset < minimum or offset > maximum:
                self.diagnostics.append(
                    CodegenDiagnostic(
                        line=0,
                        column=0,
                        code="jump_offset_out_of_range",
                        message=(
                            f'el salto relativo "{item.op}" en la instruccion {current_index} requiere '
                            f"offset {offset}, fuera del rango de {minimum} a {maximum}."
                        ),
                    )
                )

    # RENDER

    def _remove_redundant_fallthrough_jumps(self):
        """Elimina saltos a etiquetas que ya son la siguiente instruccion real."""

        optimized: List[Union[Instruction, LabelMarker, str]] = []

        for index, item in enumerate(self.items):
            if (
                isinstance(item, Instruction)
                and (item.op == "jmp" or item.op in RELATIVE_BRANCH_OPS)
                and item.args
                and isinstance(item.args[-1], LabelRef)
            ):
                target = item.args[-1].name
                for following in self.items[index + 1:]:
                    if isinstance(following, LabelMarker):
                        if following.name == target:
                            break
                        continue
                    if isinstance(following, str):
                        continue
                    optimized.append(item)
                    break
                else:
                    optimized.append(item)
                continue

            optimized.append(item)

        self.items = optimized

    def _render_items(self) -> List[str]:
        """Resuelve labels, direcciones y pseudos para producir texto final."""

        self._remove_redundant_fallthrough_jumps()

        last_signature = None
        item_sizes: List[int] = []
        label_to_index: Dict[str, int] = {}

        for _ in range(8):
            item_sizes = []
            label_to_index = {}
            current_index = 0
            for item in self.items:
                if isinstance(item, LabelMarker):
                    label_to_index[item.name] = current_index
                    item_sizes.append(0)
                elif isinstance(item, Instruction):
                    size = self._instruction_size(item)
                    item_sizes.append(size)
                    current_index += size
                else:
                    item_sizes.append(0)

            code_size = current_index * WORD_SIZE
            self._finalize_memory_layout(code_size)
            if self.diagnostics:
                return []

            address_signature = []
            if self.symbol_table is not None:
                for symbol in self.symbol_table.global_scope.symbols.values():
                    if symbol.segment == "global":
                        address_signature.append((symbol.name, symbol.address))
            signature = (tuple(item_sizes), tuple(address_signature))
            if signature == last_signature:
                break
            last_signature = signature
        else:
            self.diagnostics.append(
                CodegenDiagnostic(
                    line=0,
                    column=0,
                    code="layout_resolution_failed",
                    message="no se pudo estabilizar el layout final de codigo y datos.",
                )
            )
            return []

        if self.symbol_table is not None:
            for symbol in self.symbol_table.global_scope.symbols.values():
                if symbol.kind == "function" and symbol.name in label_to_index:
                    symbol.address = label_to_index[symbol.name] * WORD_SIZE

        lines: List[str] = []
        current_index = 0
        for item, size in zip(self.items, item_sizes):
            if isinstance(item, str):
                lines.append(item)
                continue

            if isinstance(item, LabelMarker):
                label_address = label_to_index.get(item.name, 0) * WORD_SIZE
                lines.append(f"{item.name}:    # addr={label_address}")
                continue

            rendered_args = []
            expanded_immediate_lines = None
            resolved_targets: List[str] = []
            for arg in item.args:
                if isinstance(arg, LabelRef):
                    if arg.name not in label_to_index:
                        self.diagnostics.append(
                            CodegenDiagnostic(
                                line=0,
                                column=0,
                                code="unresolved_label",
                                message=f'no se pudo resolver la etiqueta "{arg.name}" en ensamblador.',
                            )
                        )
                        rendered_args.append("0")
                        continue
                    target_index = label_to_index[arg.name]
                    # Los saltos relativos se calculan desde la instruccion
                    # siguiente (PC + 4), no desde la instruccion actual.
                    relative_offset = target_index - (current_index + 1)
                    self._validate_relative_immediate(item, relative_offset, current_index)
                    rendered_args.append(str(relative_offset))
                    resolved_targets.append(f"{arg.name} @ {target_index * WORD_SIZE}")
                elif isinstance(arg, AddressRef):
                    if self.symbol_table is None:
                        self.diagnostics.append(
                            CodegenDiagnostic(
                                line=0,
                                column=0,
                                code="unresolved_address",
                                message=f'no se pudo resolver la direccion global "{arg.symbol_name}".',
                            )
                        )
                        rendered_args.append("0")
                        continue
                    symbol = self.symbol_table.global_scope.symbols.get(arg.symbol_name)
                    if symbol is None or symbol.address is None:
                        self.diagnostics.append(
                            CodegenDiagnostic(
                                line=0,
                                column=0,
                                code="unresolved_address",
                                message=f'no se pudo resolver la direccion global "{arg.symbol_name}".',
                            )
                        )
                        rendered_args.append("0")
                        continue
                    if item.op == "la":
                        expanded_immediate_lines = self._render_load_immediate_lines(
                            item.args[0],
                            symbol.address,
                            item.secure,
                            item.comment,
                            pseudo_name="la",
                        )
                    else:
                        rendered_args.append(str(symbol.address))
                elif isinstance(arg, StackBaseRef):
                    if item.op == "li":
                        expanded_immediate_lines = self._render_load_immediate_lines(
                            item.args[0],
                            self.stack_base_address,
                            item.secure,
                            item.comment,
                            pseudo_name="li",
                        )
                    else:
                        rendered_args.append(str(self.stack_base_address))
                else:
                    rendered_args.append(str(arg))

            if expanded_immediate_lines is not None:
                lines.extend(expanded_immediate_lines)
                current_index += size
                continue

            op = item.op
            if item.secure:
                op, rendered_args, translated = self._resolve_secure_render(op, rendered_args)
                if not translated:
                    op = f"@{op}"
            args_text = ", ".join(rendered_args)
            line = f"    {op}"
            if args_text:
                line += f" {args_text}"
            comment_parts = []
            if item.comment:
                comment_parts.append(item.comment)
            if resolved_targets:
                comment_parts.append("-> " + ", ".join(resolved_targets))
            if comment_parts:
                line += f"    # {' | '.join(comment_parts)}"
            lines.append(line)
            current_index += size

        if self.diagnostics:
            return []

        return lines

    def _render_load_immediate_lines(
        self,
        target: str,
        value: int,
        secure: bool,
        comment: Optional[str],
        pseudo_name: str,
    ) -> List[str]:
        """Expande la carga de inmediatos grandes en varias instrucciones."""

        lines: List[str] = []
        if secure:
            immediate_op = "pmovi"
            add_op_positive = "paddi"
            add_op_negative = "psubi"
        else:
            immediate_op = pseudo_name
            add_op_positive = "addi"
            add_op_negative = "subi"

        if SIGNED_IMMEDIATE_MIN <= value <= SIGNED_IMMEDIATE_MAX:
            line = f"    {immediate_op} {target}, {value}"
            if comment:
                line += f"    # {comment}"
            lines.append(line)
            return lines

        first_line = f"    {immediate_op} {target}, 0"
        if comment:
            first_line += f"    # {comment}"
        lines.append(first_line)
        for chunk in self._split_signed_immediate(value):
            if chunk == 0:
                continue
            if chunk < 0:
                lines.append(f"    {add_op_negative} {target}, {target}, {abs(chunk)}")
            else:
                lines.append(f"    {add_op_positive} {target}, {target}, {chunk}")
        return lines
