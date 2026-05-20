"""Estructuras de tipos, simbolos y asignacion de memoria semantica."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


WORD_SIZE = 4
MEMORY_SIZE = 0x10000
DATA_BASE = 0x0000
CODE_BASE = 0x0000
PARAM_REGISTER_LIMIT = 9


@dataclass
class SemanticDiagnostic:
    """Representa un error o advertencia detectado en analisis semantico."""

    line: int
    column: int
    code: str
    details: dict


@dataclass
class TypeInfo:
    """Describe un tipo base junto con punteros y dimensiones de arreglo."""

    name: str
    is_pointer: bool = False
    array_dims: List[int] = field(default_factory=list)
    vault_inner: Optional[int] = None

    def __str__(self) -> str:
        """Convierte el tipo a una forma legible para mensajes."""

        base_name = self.name
        if self.name == "vault" and self.vault_inner:
            base_name = f"vault[{self.vault_inner}]"

        suffix = ""
        if self.is_pointer:
            suffix += "*"
        for dim in self.array_dims:
            suffix += f"[{dim if dim > 0 else ''}]"
        return f"{base_name}{suffix}"

    @property
    def is_array(self) -> bool:
        """Indica si el tipo representa un arreglo."""

        return len(self.array_dims) > 0 or (
            self.name == "vault" and self.vault_inner is not None and not self.is_pointer
        )

    @property
    def is_void(self) -> bool:
        """Indica si el tipo es exactamente void escalar."""

        return self.name == "void" and not self.is_pointer and not self.is_array

    @property
    def is_bool(self) -> bool:
        """Indica si el tipo es exactamente bool escalar."""

        return self.name == "bool" and not self.is_pointer and not self.is_array

    @property
    def is_numeric(self) -> bool:
        """Indica si el tipo participa en operaciones numericas."""

        return self.name in {"int", "char", "float"} and not self.is_pointer and not self.is_array

    @property
    def is_integral(self) -> bool:
        """Indica si el tipo pertenece al subconjunto entero."""

        return self.name in {"int", "char"} and not self.is_pointer and not self.is_array

    @property
    def has_unknown_size(self) -> bool:
        """Indica si alguna dimension del arreglo no fue especificada."""

        if self.name == "vault" and self.vault_inner is not None and not self.is_pointer:
            return self.vault_inner <= 0
        return any(dim <= 0 for dim in self.array_dims)

    def same_shape(self, other: "TypeInfo") -> bool:
        """Compara tipo base, punteros y dimensiones de dos tipos."""

        return (
            self.name == other.name
            and self.is_pointer == other.is_pointer
            and self.array_dims == other.array_dims
            and self.vault_inner == other.vault_inner
        )

    def base_scalar_size(self) -> int:
        """Retorna el tamano base del tipo sin multiplicar dimensiones."""

        if self.is_pointer:
            return WORD_SIZE
        if self.name == "int":
            return WORD_SIZE
        if self.name == "float":
            return WORD_SIZE
        if self.name == "bool":
            return WORD_SIZE
        if self.name == "char":
            return 1
        if self.name == "void":
            return 0
        if self.name == "vault":
            return WORD_SIZE
        return WORD_SIZE

    def total_size(self) -> int:
        """Calcula el tamano total del tipo considerando arreglos."""

        base = self.base_scalar_size()
        if self.name == "vault" and self.vault_inner is not None and not self.is_pointer and not self.array_dims:
            return base * max(self.vault_inner, 1)

        if not self.array_dims:
            return base

        total_elems = 1
        for dim in self.array_dims:
            total_elems *= max(dim, 1)
        return base * total_elems

    def element_type(self) -> "TypeInfo":
        """Devuelve el tipo de un elemento al indexar arreglo o puntero."""

        if self.name == "vault" and self.vault_inner is not None and not self.is_pointer:
            return TypeInfo(name="int")

        if self.is_array:
            return TypeInfo(
                name=self.name,
                is_pointer=self.is_pointer,
                array_dims=self.array_dims[1:],
                vault_inner=self.vault_inner,
            )
        if self.is_pointer:
            return TypeInfo(name=self.name, vault_inner=self.vault_inner)
        return self


@dataclass
class Symbol:
    """Representa una entrada de la tabla de simbolos."""

    name: str
    kind: str
    type_info: Optional[TypeInfo]
    scope_name: str
    line: int
    column: int
    segment: Optional[str] = None
    address: Optional[int] = None
    offset: Optional[int] = None
    register: Optional[str] = None
    size: int = 0
    alignment: int = WORD_SIZE
    params: List[TypeInfo] = field(default_factory=list)
    return_type: Optional[TypeInfo] = None
    extra: Dict[str, Any] = field(default_factory=dict)


@dataclass
class Scope:
    """Representa un ambito con simbolos locales y jerarquia."""

    name: str
    kind: str
    parent: Optional["Scope"] = None
    symbols: Dict[str, Symbol] = field(default_factory=dict)
    children: List["Scope"] = field(default_factory=list)

    def define(self, symbol: Symbol) -> bool:
        """Inserta un simbolo si no existe otro con el mismo nombre."""

        if symbol.name in self.symbols:
            return False
        self.symbols[symbol.name] = symbol
        return True

    def resolve_local(self, name: str) -> Optional[Symbol]:
        """Busca un simbolo solo dentro del ambito actual."""

        return self.symbols.get(name)


@dataclass
class FunctionFrame:
    """Resume la distribucion de memoria local de una funcion."""

    name: str
    local_size: int = 0
    parameter_size: int = 0
    frame_size: int = 0
    max_local_offset: int = 0
    parameter_registers: List[str] = field(default_factory=list)
    stack_parameters: int = 0


class SymbolTable:
    """Administra ambitos, simbolos y asignacion de memoria semantica."""

    def __init__(self):
        """Inicializa el ambito global y los contadores de memoria."""

        self.global_scope = Scope(name="global", kind="global")
        self.current_scope = self.global_scope
        self.scope_stack: List[Scope] = [self.global_scope]
        self.all_scopes: List[Scope] = [self.global_scope]

        # Contadores de memoria y estado del frame actual.
        self.next_global_address = DATA_BASE
        self.next_vault_address = 0
        self.next_code_address = CODE_BASE
        self.current_stack_offset = 0
        self.current_parameter_offset = 0
        self.current_function_frame: Optional[FunctionFrame] = None
        self.function_frames: Dict[str, FunctionFrame] = {}

    def enter_scope(self, name: str, kind: str) -> Scope:
        """Crea y activa un nuevo ambito hijo."""

        new_scope = Scope(name=name, kind=kind, parent=self.current_scope)
        self.current_scope.children.append(new_scope)
        self.scope_stack.append(new_scope)
        self.all_scopes.append(new_scope)
        self.current_scope = new_scope
        return new_scope

    def exit_scope(self) -> Scope:
        """Cierra el ambito actual y vuelve al padre."""

        if len(self.scope_stack) == 1:
            return self.current_scope

        popped = self.scope_stack.pop()
        self.current_scope = self.scope_stack[-1]
        return popped

    def reset_function_stack(self):
        """Reinicia offsets temporales antes de analizar una funcion."""

        self.current_stack_offset = 0
        self.current_parameter_offset = 0

    def start_function_frame(self, name: str):
        """Abre el frame que recibira locales y parametros de una funcion."""

        self.reset_function_stack()
        frame = FunctionFrame(name=name)
        self.function_frames[name] = frame
        self.current_function_frame = frame

    def finish_function_frame(self) -> Optional[FunctionFrame]:
        """Cierra el frame actual y fija sus tamanos finales."""

        frame = self.current_function_frame
        if frame is not None:
            frame.local_size = abs(frame.max_local_offset)
            frame.frame_size = self._align(frame.local_size + frame.parameter_size, WORD_SIZE)
        self.current_function_frame = None
        return frame

    def resolve(self, name: str) -> Optional[Symbol]:
        """Busca un simbolo siguiendo la cadena de ambitos activos."""

        scope = self.current_scope
        while scope is not None:
            symbol = scope.resolve_local(name)
            if symbol is not None:
                return symbol
            scope = scope.parent
        return None

    def define(self, symbol: Symbol) -> bool:
        """Define un simbolo en el ambito actual."""

        return self.current_scope.define(symbol)

    def define_global(self, symbol: Symbol) -> bool:
        """Define un simbolo directamente en el ambito global."""

        return self.global_scope.define(symbol)

    def _align(self, size: int, alignment: int = WORD_SIZE) -> int:
        """Alinea un tamano al multiplo requerido."""

        if size <= 0:
            return 0
        return ((size + alignment - 1) // alignment) * alignment

    def allocate_global(self, size: int) -> int:
        """Reserva espacio en el segmento global y retorna su direccion."""

        aligned = self._align(size, WORD_SIZE)
        addr = self.next_global_address
        self.next_global_address += aligned
        return addr

    def allocate_vault(self, size: int) -> int:
        """Reserva una ventana de direcciones dentro de la boveda segura."""

        aligned = self._align(size, WORD_SIZE)
        addr = self.next_vault_address
        self.next_vault_address += aligned
        return addr

    def allocate_local(self, size: int) -> int:
        """Reserva espacio para una variable local dentro del frame actual."""

        aligned = self._align(size, WORD_SIZE)
        self.current_stack_offset -= aligned
        if self.current_function_frame is not None:
            self.current_function_frame.max_local_offset = min(
                self.current_function_frame.max_local_offset,
                self.current_stack_offset,
            )
        return self.current_stack_offset

    def allocate_code(self) -> int:
        """Reserva una direccion del segmento de codigo."""

        address = self.next_code_address
        self.next_code_address += WORD_SIZE
        return address

    def allocate_label(self) -> int:
        """Reserva una direccion para una etiqueta semantica."""

        return self.allocate_code()

    def assign_function_address(self, symbol: Symbol):
        """Asigna direccion de codigo a una funcion registrada."""

        symbol.segment = "code"
        symbol.address = self.allocate_code()

    def assign_global_address(self, symbol: Symbol):
        """Asigna direccion absoluta a una variable global."""

        if symbol.type_info is None:
            return
        symbol.size = symbol.type_info.total_size()
        symbol.alignment = WORD_SIZE
        if symbol.type_info.name == "vault" and not symbol.type_info.is_pointer:
            symbol.segment = "vault"
            symbol.address = self.allocate_vault(symbol.size)
            return
        symbol.segment = "global"
        symbol.address = self.allocate_global(symbol.size)

    def assign_local_offset(self, symbol: Symbol):
        """Asigna offset de stack a una variable local."""

        if symbol.type_info is None:
            return
        symbol.size = symbol.type_info.total_size()
        symbol.alignment = WORD_SIZE
        symbol.segment = "stack"
        symbol.offset = self.allocate_local(symbol.size)

    def assign_parameter_location(self, symbol: Symbol, index: int):
        """Ubica un parametro en registro o stack segun su posicion."""

        if symbol.type_info is not None:
            symbol.size = WORD_SIZE if symbol.type_info.is_array else symbol.type_info.total_size()
            symbol.alignment = WORD_SIZE

        symbol.segment = "param"
        if index < PARAM_REGISTER_LIMIT:
            symbol.register = f"p{index}"
            if self.current_function_frame is not None:
                self.current_function_frame.parameter_registers.append(symbol.register)
        else:
            symbol.register = None
            aligned = self._align(symbol.size or WORD_SIZE, WORD_SIZE)
            symbol.offset = self.current_parameter_offset
            self.current_parameter_offset += aligned
            if self.current_function_frame is not None:
                self.current_function_frame.stack_parameters += 1
                self.current_function_frame.parameter_size += aligned

    def current_function_scope(self) -> Optional[Scope]:
        """Retorna el ambito de funcion mas cercano al contexto actual."""

        scope = self.current_scope
        while scope is not None:
            if scope.kind == "function":
                return scope
            scope = scope.parent
        return None
