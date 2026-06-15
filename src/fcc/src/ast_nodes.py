"""Definicion de nodos del AST usados por parser, semantica y codegen."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, List, Optional


@dataclass
class ASTNode:
    """Nodo base con informacion de ubicacion en el codigo fuente."""

    line: int = 0
    column: int = 0


@dataclass
class ProgramNode(ASTNode):
    """Nodo raiz que agrupa todas las declaraciones del programa."""

    declarations: List[ASTNode] = field(default_factory=list)


@dataclass
class ImportNode(ASTNode):
    """Representa una sentencia traigase."""

    path: str = ""


@dataclass
class SecureAnnotationNode(ASTNode):
    """Guarda la anotacion @secure asociada a una funcion."""

    value: str = ""


@dataclass
class ParameterNode(ASTNode):
    """Representa un parametro formal dentro de una firma de funcion."""

    param_type: str = ""
    name: str = ""


@dataclass
class FunctionDeclNode(ASTNode):
    """Representa una funcion con firma, cuerpo y pragma secure opcional."""

    return_type: str = ""
    name: str = ""
    params: List[ParameterNode] = field(default_factory=list)
    body: Optional["BlockNode"] = None
    secure: Optional[SecureAnnotationNode] = None


@dataclass
class BlockNode(ASTNode):
    """Agrupa una secuencia de sentencias dentro de un bloque."""

    statements: List[ASTNode] = field(default_factory=list)


@dataclass
class VarDeclaratorNode(ASTNode):
    """Describe una variable declarada, sus dimensiones e inicializador."""

    name: str = ""
    dimensions: List[Optional[ASTNode]] = field(default_factory=list)
    initializer: Optional[ASTNode] = None


@dataclass
class VarDeclNode(ASTNode):
    """Representa una declaracion de una o varias variables del mismo tipo."""

    var_type: str = ""
    declarators: List[VarDeclaratorNode] = field(default_factory=list)


@dataclass
class AssignmentNode(ASTNode):
    """Representa una asignacion simple o compuesta."""

    target: Optional[ASTNode] = None
    operator: str = ""
    value: Optional[ASTNode] = None


@dataclass
class IfNode(ASTNode):
    """Representa una estructura if con ramas elif y else opcionales."""

    condition: Optional[ASTNode] = None
    then_block: Optional[BlockNode] = None
    elif_branches: List["ElifNode"] = field(default_factory=list)
    else_block: Optional[BlockNode] = None


@dataclass
class ElifNode(ASTNode):
    """Representa una rama elif intermedia."""

    condition: Optional[ASTNode] = None
    block: Optional[BlockNode] = None


@dataclass
class WhileNode(ASTNode):
    """Representa un ciclo while."""

    condition: Optional[ASTNode] = None
    body: Optional[BlockNode] = None


@dataclass
class ForNode(ASTNode):
    """Representa un ciclo for con init, update y condicion."""

    initializer: Optional[ASTNode] = None
    increment: Optional[ASTNode] = None
    condition: Optional[ASTNode] = None
    body: Optional[BlockNode] = None


@dataclass
class ReturnNode(ASTNode):
    """Representa una sentencia ret con valor opcional."""

    value: Optional[ASTNode] = None


@dataclass
class ContinueNode(ASTNode):
    """Representa una sentencia continue."""

    pass


@dataclass
class BreakNode(ASTNode):
    """Representa una sentencia break."""

    pass


@dataclass
class ExpressionStmtNode(ASTNode):
    """Envuelve una expresion usada como sentencia."""

    expression: Optional[ASTNode] = None


@dataclass
class IdentifierNode(ASTNode):
    """Referencia a un identificador del programa."""

    name: str = ""


@dataclass
class LiteralNode(ASTNode):
    """Literal del lenguaje con su valor crudo y categoria."""

    value: Any = None
    literal_type: str = ""


@dataclass
class UnaryOpNode(ASTNode):
    """Operacion unaria como -, !, & o *."""

    operator: str = ""
    operand: Optional[ASTNode] = None


@dataclass
class BinaryOpNode(ASTNode):
    """Operacion binaria respetando precedencia y asociatividad."""

    operator: str = ""
    left: Optional[ASTNode] = None
    right: Optional[ASTNode] = None


@dataclass
class CallNode(ASTNode):
    """Invocacion de funcion con lista de argumentos."""

    callee: Optional[ASTNode] = None
    arguments: List[ASTNode] = field(default_factory=list)


@dataclass
class IndexAccessNode(ASTNode):
    """Acceso indexado sobre arreglos o punteros."""

    target: Optional[ASTNode] = None
    index: Optional[ASTNode] = None


@dataclass
class MemberAccessNode(ASTNode):
    """Acceso a miembro usando notacion con punto."""

    target: Optional[ASTNode] = None
    member: str = ""
