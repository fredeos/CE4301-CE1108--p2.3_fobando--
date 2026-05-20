"""Analisis semantico, chequeo de tipos y construccion de etiquetas."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional, List
import re

from ast_nodes import (
    ProgramNode,
    ImportNode,
    FunctionDeclNode,
    BlockNode,
    VarDeclNode,
    VarDeclaratorNode,
    AssignmentNode,
    IfNode,
    WhileNode,
    ForNode,
    ReturnNode,
    ContinueNode,
    BreakNode,
    ExpressionStmtNode,
    IdentifierNode,
    LiteralNode,
    UnaryOpNode,
    BinaryOpNode,
    CallNode,
    IndexAccessNode,
    MemberAccessNode,
)

from symbol_table import (
    PARAM_REGISTER_LIMIT,
    SymbolTable,
    Symbol,
    TypeInfo,
    SemanticDiagnostic,
)


VALID_BASE_TYPES = {"int", "float", "bool", "char", "void", "vault"}
BUILTIN_READONLY_REGISTERS = {"zero", "delta", "max"}
BUILTIN_DATA_MEMORY = "data_mem"
ARITHMETIC_PROMOTING_OPERATORS = {"+", "-", "*", "/", "~"}
INTEGRAL_ONLY_OPERATORS = {"%", "<<", ">>"}
BITWISE_OPERATORS = {"&", "|", "^"}
EQUALITY_OPERATORS = {"==", "!="}
RELATIONAL_OPERATORS = {"<", "<=", ">", ">="}


@dataclass
class LabelInfo:
    """Describe una etiqueta semantica asociada a control de flujo."""

    name: str
    kind: str
    function_name: str
    address: Optional[int] = None
    target: Optional[str] = None


@dataclass
class SemanticResult:
    """Empaqueta diagnosticos, tabla de simbolos y labels generados."""

    diagnostics: List[SemanticDiagnostic] = field(default_factory=list)
    symbol_table: Optional[SymbolTable] = None
    labels: List[LabelInfo] = field(default_factory=list)

    @property
    def has_errors(self) -> bool:
        """Indica si el analisis semantico produjo errores."""

        return len(self.diagnostics) > 0


class SemanticAnalyzer:
    """Recorre el AST y valida significado, tipos, ambitos y memoria."""

    def __init__(self):
        """Inicializa estado de analisis, tabla de simbolos y contadores."""

        self.symbol_table = SymbolTable()
        self.diagnostics: List[SemanticDiagnostic] = []
        self.labels: List[LabelInfo] = []

        self.current_function: Optional[Symbol] = None
        self.loop_depth = 0
        self.label_counter = 0
        self.loop_label_stack: List[dict] = []

    # API PRINCIPAL

    def analyze(self, program: ProgramNode) -> SemanticResult:
        """Ejecuta el registro inicial y el recorrido semantico completo."""

        self._register_top_level(program)
        self._analyze_top_level(program)

        return SemanticResult(
            diagnostics=self.diagnostics,
            symbol_table=self.symbol_table,
            labels=self.labels,
        )

    # UTILIDADES

    def error(self, line: int, column: int, code: str, **details):
        """Agrega un diagnostico semantico al resultado actual."""

        self.diagnostics.append(
            SemanticDiagnostic(
                line=line,
                column=column,
                code=code,
                details=details,
            )
        )

    def new_label(self, kind: str, target: Optional[str] = None) -> str:
        """Crea y registra una etiqueta semantica para control de flujo."""

        self.label_counter += 1
        function_name = self.current_function.name if self.current_function else "global"
        label_name = f"{function_name}_{kind}_{self.label_counter}"
        address = self.symbol_table.allocate_label()

        label = LabelInfo(
            name=label_name,
            kind=kind,
            function_name=function_name,
            address=address,
            target=target,
        )
        self.labels.append(label)

        label_symbol = Symbol(
            name=label_name,
            kind="label",
            type_info=None,
            scope_name=self.symbol_table.global_scope.name,
            line=0,
            column=0,
            segment="label",
            address=address,
            extra={"function": function_name, "kind": kind, "target": target},
        )
        self.symbol_table.define_global(label_symbol)

        return label_name

    def parse_type_string(self, raw: str, dims: Optional[List[int]] = None) -> TypeInfo:
        """Convierte una representacion textual de tipo en un TypeInfo."""

        dims = dims or []
        working = raw.strip()
        vault_inner: Optional[int] = None

        vault_match = re.match(r"vault\[(.*?)\]", working)
        if vault_match:
            vault_raw = vault_match.group(1).strip()
            vault_inner = int(vault_raw) if vault_raw.isdigit() else 0
            working = "vault" + working[vault_match.end():]

        raw_dims: List[int] = []

        for content in re.findall(r"\[(.*?)\]", working):
            value = content.strip()
            raw_dims.append(int(value) if value.isdigit() else 0)

        without_arrays = re.sub(r"\[.*?\]", "", working)
        pointer_count = without_arrays.count("*")
        base = without_arrays.replace("*", "").strip()

        return TypeInfo(
            name=base,
            is_pointer=pointer_count > 0,
            array_dims=raw_dims + dims,
            vault_inner=vault_inner,
        )

    def is_assignable(self, target: TypeInfo, source: TypeInfo) -> bool:
        """Indica si un valor de source puede asignarse a target."""

        if target.is_void or source.is_void:
            return False

        if target.same_shape(source):
            return True

        if target.is_array or source.is_array:
            if not (target.is_array and source.is_array):
                return False
            if target.name != source.name or target.is_pointer != source.is_pointer:
                return False
            if target.vault_inner != source.vault_inner:
                return False
            if len(target.array_dims) != len(source.array_dims):
                return False

            for target_dim, source_dim in zip(target.array_dims, source.array_dims):
                if target_dim > 0 and target_dim != source_dim:
                    return False
            return True

        if target.is_pointer or source.is_pointer:
            return (
                target.name == source.name
                and target.is_pointer == source.is_pointer
                and target.vault_inner == source.vault_inner
            )

        if target.name == "float" and source.name in {"int", "char"}:
            return True

        # Solo se permite promocion segura char -> int. bool no se promueve a int.
        if target.name == "int" and source.name == "char":
            return True

        return False

    def require_declared(self, name: str, line: int, column: int) -> Optional[Symbol]:
        """Resuelve un simbolo o reporta que la referencia no existe."""

        symbol = self.symbol_table.resolve(name)
        if symbol is None and name in BUILTIN_READONLY_REGISTERS:
            return Symbol(
                name=name,
                kind="register",
                type_info=TypeInfo("int"),
                scope_name="builtin",
                line=line,
                column=column,
                segment="register",
                register=name,
                extra={"readonly": True},
            )
        if symbol is None and name == BUILTIN_DATA_MEMORY:
            return Symbol(
                name=name,
                kind="memory",
                type_info=TypeInfo("int", is_pointer=True),
                scope_name="builtin",
                line=line,
                column=column,
                segment="data_mem",
                address=0,
                extra={"readonly": True, "byte_indexed": True},
            )
        if symbol is None:
            self.error(line, column, "undeclared_reference", name=name)
        return symbol

    def _validate_type(
        self,
        type_info: TypeInfo,
        line: int,
        column: int,
        usage: str,
        name: str,
        allow_unsized_array: bool = False,
    ):
        """Valida que un tipo sea legal para el contexto donde aparece."""

        if type_info.name not in VALID_BASE_TYPES:
            self.error(line, column, "invalid_type", type_name=type_info.name, name=name)
            return

        if (
            type_info.name == "vault"
            and (
                type_info.vault_inner is None
                or type_info.vault_inner <= 0
                or type_info.is_pointer
                or len(type_info.array_dims) > 0
            )
        ):
            self.error(line, column, "invalid_vault_type", name=name, type_name=str(type_info))
            return

        if usage in {"variable", "parameter"} and type_info.is_void:
            self.error(line, column, "invalid_void_declaration", usage=usage, name=name)

        if type_info.name == "void" and (type_info.is_pointer or type_info.is_array):
            self.error(line, column, "invalid_void_type", name=name, type_name=str(type_info))

        if type_info.is_array and type_info.has_unknown_size and not allow_unsized_array:
            self.error(line, column, "array_dimension_missing", name=name, type_name=str(type_info))

    # REGISTRO DE ALTO NIVEL

    def _register_top_level(self, program: ProgramNode):
        """Registra funciones y globales antes del recorrido semantico fino."""

        for decl in program.declarations:
            if isinstance(decl, FunctionDeclNode):
                self._register_function_symbol(decl)
            elif isinstance(decl, VarDeclNode):
                self._register_global_var_decl(decl)
            elif isinstance(decl, ImportNode):
                # En esta version no se resuelven imports semanticos profundos.
                pass

    def _register_function_symbol(self, node: FunctionDeclNode):
        """Crea la entrada global de una funcion y su firma."""

        param_types = [self.parse_type_string(param.param_type) for param in node.params]
        return_type = self.parse_type_string(node.return_type)
        self._validate_type(return_type, node.line, node.column, "return", node.name)
        if node.name == "main" and len(node.params) > 0:
            self.error(
                node.line,
                node.column,
                "main_with_parameters",
            )

        signature = ", ".join(str(param_type) for param_type in param_types)
        function_symbol = Symbol(
            name=node.name,
            kind="function",
            type_info=None,
            scope_name="global",
            line=node.line,
            column=node.column,
            params=param_types,
            return_type=return_type,
            extra={
                "secure": node.secure.value if node.secure else None,
                "arity": len(param_types),
                "signature": f"{node.name}({signature}) -> {return_type}",
            },
        )

        if len(node.params) > PARAM_REGISTER_LIMIT:
            self.error(
                node.line,
                node.column,
                "too_many_parameters",
                function_name=node.name,
                limit=PARAM_REGISTER_LIMIT,
            )

        if not self.symbol_table.define_global(function_symbol):
            self.error(
                node.line,
                node.column,
                "redeclared_function",
                name=node.name,
            )
            return

        self.symbol_table.assign_function_address(function_symbol)

    def _register_global_var_decl(self, node: VarDeclNode):
        """Registra variables globales y les asigna direccion inicial."""

        for declarator in node.declarators:
            dims = self._extract_dimensions(declarator)
            type_info = self.parse_type_string(node.var_type, dims)
            self._validate_type(
                type_info,
                declarator.line,
                declarator.column,
                "variable",
                declarator.name,
            )

            symbol = Symbol(
                name=declarator.name,
                kind="variable",
                type_info=type_info,
                scope_name="global",
                line=declarator.line,
                column=declarator.column,
            )

            if not self.symbol_table.define_global(symbol):
                self.error(
                    declarator.line,
                    declarator.column,
                    "redeclared_global_variable",
                    name=declarator.name,
                )
                continue

            self.symbol_table.assign_global_address(symbol)

    # ANALISIS DE ALTO NIVEL

    def _analyze_top_level(self, program: ProgramNode):
        """Analiza el contenido semantico de funciones y globales."""

        for decl in program.declarations:
            if isinstance(decl, FunctionDeclNode):
                self._analyze_function(decl)
            elif isinstance(decl, VarDeclNode):
                self._analyze_global_initializers(decl)

    def _analyze_global_initializers(self, node: VarDeclNode):
        """Valida inicializadores de variables globales."""

        for declarator in node.declarators:
            if declarator.initializer is None:
                continue

            symbol = self.symbol_table.global_scope.symbols.get(declarator.name)
            if symbol is None or symbol.type_info is None:
                continue

            self._validate_vault_expression_rules(declarator.initializer)
            init_type = self._infer_expression_type(declarator.initializer)
            if init_type and not self.is_assignable(symbol.type_info, init_type):
                self.error(
                    declarator.line,
                    declarator.column,
                    "assignment_type_mismatch",
                    source_type=str(init_type),
                    target_type=str(symbol.type_info),
                )

    # FUNCIONES

    def _analyze_function(self, node: FunctionDeclNode):
        """Analiza una funcion completa dentro de su propio ambito."""

        function_symbol = self.symbol_table.global_scope.symbols.get(node.name)
        if function_symbol is None:
            return

        self.current_function = function_symbol
        self.symbol_table.start_function_frame(node.name)
        self.symbol_table.enter_scope(f"function:{node.name}", "function")

        for index, param in enumerate(node.params):
            type_info = self.parse_type_string(param.param_type)
            self._validate_type(
                type_info,
                param.line,
                param.column,
                "parameter",
                param.name,
                allow_unsized_array=True,
            )

            symbol = Symbol(
                name=param.name,
                kind="parameter",
                type_info=type_info,
                scope_name=self.symbol_table.current_scope.name,
                line=param.line,
                column=param.column,
            )

            if not self.symbol_table.define(symbol):
                self.error(
                    param.line,
                    param.column,
                    "duplicated_parameter",
                    name=param.name,
                )
                continue

            self.symbol_table.assign_parameter_location(symbol, index)

            if index >= PARAM_REGISTER_LIMIT:
                self.error(
                    param.line,
                    param.column,
                    "parameter_out_of_register_range",
                    name=param.name,
                )

        body_returns = self._analyze_block(node.body, create_scope=True)

        expected = function_symbol.return_type
        if node.name == "main" and expected is not None and not expected.is_void and not body_returns:
            self.error(
                node.line,
                node.column,
                "main_missing_return",
            )
        if expected is not None and not expected.is_void and not body_returns and node.name != "main":
            self.error(
                node.line,
                node.column,
                "function_missing_return",
                function_name=node.name,
                expected_type=str(expected),
            )

        frame = self.symbol_table.finish_function_frame()
        if frame is not None:
            function_symbol.extra["frame_size"] = frame.frame_size
            function_symbol.extra["local_size"] = frame.local_size
            function_symbol.extra["parameter_registers"] = list(frame.parameter_registers)

        self.symbol_table.exit_scope()
        self.current_function = None

    # BLOQUES Y SENTENCIAS

    def _analyze_block(self, node: BlockNode, create_scope: bool) -> bool:
        """Analiza un bloque y reporta si retorna en forma garantizada."""

        if create_scope:
            self.symbol_table.enter_scope(f"block:{id(node)}", "block")

        definitely_returns = False
        for stmt in node.statements:
            stmt_returns = self._analyze_statement(stmt)
            definitely_returns = definitely_returns or stmt_returns

        if create_scope:
            self.symbol_table.exit_scope()

        return definitely_returns

    def _analyze_statement(self, node) -> bool:
        """define el analisis segun el tipo de sentencia."""

        if isinstance(node, VarDeclNode):
            self._analyze_var_decl(node)
            return False
        if isinstance(node, AssignmentNode):
            self._analyze_assignment(node)
            return False
        if isinstance(node, IfNode):
            return self._analyze_if(node)
        if isinstance(node, WhileNode):
            self._analyze_while(node)
            return False
        if isinstance(node, ForNode):
            self._analyze_for(node)
            return False
        if isinstance(node, ReturnNode):
            self._analyze_return(node)
            return True
        if isinstance(node, ContinueNode):
            self._analyze_continue(node)
            return False
        if isinstance(node, BreakNode):
            self._analyze_break(node)
            return False
        if isinstance(node, ExpressionStmtNode):
            if node.expression is not None:
                self._validate_vault_expression_rules(node.expression)
                self._infer_expression_type(node.expression)
            return False
        if isinstance(node, BlockNode):
            return self._analyze_block(node, create_scope=True)
        return False

    def _analyze_var_decl(self, node: VarDeclNode):
        """Registra y valida variables locales con sus inicializadores."""

        for declarator in node.declarators:
            dims = self._extract_dimensions(declarator)
            type_info = self.parse_type_string(node.var_type, dims)
            self._validate_type(
                type_info,
                declarator.line,
                declarator.column,
                "variable",
                declarator.name,
            )

            symbol = Symbol(
                name=declarator.name,
                kind="variable",
                type_info=type_info,
                scope_name=self.symbol_table.current_scope.name,
                line=declarator.line,
                column=declarator.column,
            )

            if not self.symbol_table.define(symbol):
                self.error(
                    declarator.line,
                    declarator.column,
                    "redeclared_variable",
                    name=declarator.name,
                )
                continue

            self.symbol_table.assign_local_offset(symbol)

            if declarator.initializer is not None:
                self._validate_vault_expression_rules(declarator.initializer)
                init_type = self._infer_expression_type(declarator.initializer)
                if init_type and not self.is_assignable(type_info, init_type):
                    self.error(
                        declarator.line,
                        declarator.column,
                        "assignment_type_mismatch",
                        source_type=str(init_type),
                        target_type=str(type_info),
                    )

    def _analyze_assignment(self, node: AssignmentNode):
        """Valida compatibilidad de tipos en asignaciones simples y compuestas."""

        target_type = self._infer_lvalue_type(node.target)
        self._validate_vault_assignment_rules(node)
        self._validate_vault_expression_rules(node.value)
        value_type = self._infer_expression_type(node.value)

        if target_type is None or value_type is None:
            return

        if node.operator == "=":
            if not self.is_assignable(target_type, value_type):
                self.error(
                    node.line,
                    node.column,
                    "assignment_type_mismatch",
                    source_type=str(value_type),
                    target_type=str(target_type),
                )
            return

        if node.operator in {"+=", "-=", "*=", "/="}:
            if not target_type.is_numeric or not value_type.is_numeric:
                self.error(
                    node.line,
                    node.column,
                    "compound_assignment_type_mismatch",
                    operator=node.operator,
                    target_type=str(target_type),
                    source_type=str(value_type),
                )
            elif not self.is_assignable(target_type, value_type):
                self.error(
                    node.line,
                    node.column,
                    "assignment_type_mismatch",
                    source_type=str(value_type),
                    target_type=str(target_type),
                )
            return

        if node.operator == "%=":
            if not target_type.is_integral or not value_type.is_integral:
                self.error(
                    node.line,
                    node.column,
                    "compound_assignment_type_mismatch",
                    operator=node.operator,
                    target_type=str(target_type),
                    source_type=str(value_type),
                )
            elif not self.is_assignable(target_type, value_type):
                self.error(
                    node.line,
                    node.column,
                    "assignment_type_mismatch",
                    source_type=str(value_type),
                    target_type=str(target_type),
                )
            return

        if node.operator in {"&=", "|=", "^="}:
            numeric_pair = target_type.is_integral and value_type.is_integral
            bool_pair = target_type.is_bool and value_type.is_bool
            if not numeric_pair and not bool_pair:
                self.error(
                    node.line,
                    node.column,
                    "compound_assignment_type_mismatch",
                    operator=node.operator,
                    target_type=str(target_type),
                    source_type=str(value_type),
                )

    def _analyze_if(self, node: IfNode) -> bool:
        """Valida un if y determina si todas sus ramas retornan."""

        self._require_bool_condition(node.condition, "if")

        self.new_label("if_else", target="else")
        self.new_label("if_end", target="end")

        then_returns = self._analyze_block(node.then_block, create_scope=True)
        elif_returns = []

        for elif_branch in node.elif_branches:
            self._require_bool_condition(elif_branch.condition, "elif")
            elif_returns.append(self._analyze_block(elif_branch.block, create_scope=True))

        else_returns = False
        if node.else_block is not None:
            else_returns = self._analyze_block(node.else_block, create_scope=True)

        return node.else_block is not None and then_returns and all(elif_returns) and else_returns

    def _analyze_while(self, node: WhileNode):
        """Valida un ciclo while y registra sus etiquetas semanticas."""

        self._require_bool_condition(node.condition, "while")

        start_label = self.new_label("while_start", target="continue")
        end_label = self.new_label("while_end", target="break")

        self.loop_depth += 1
        self.loop_label_stack.append({"continue": start_label, "break": end_label})
        self._analyze_block(node.body, create_scope=True)
        self.loop_label_stack.pop()
        self.loop_depth -= 1

    def _analyze_for(self, node: ForNode):
        """Valida un ciclo for con su ambito, init, condicion e incremento."""

        start_label = self.new_label("for_start", target="continue")
        end_label = self.new_label("for_end", target="break")

        self.symbol_table.enter_scope(f"for:{id(node)}", "block")
        self.loop_depth += 1
        self.loop_label_stack.append({"continue": start_label, "break": end_label})

        if node.initializer is not None:
            if isinstance(node.initializer, VarDeclNode):
                self._analyze_var_decl(node.initializer)
            else:
                self._analyze_statement(node.initializer)

        if node.condition is not None:
            self._require_bool_condition(node.condition, "for")

        if node.increment is not None:
            self._analyze_statement(node.increment)

        self._analyze_block(node.body, create_scope=True)

        self.loop_label_stack.pop()
        self.loop_depth -= 1
        self.symbol_table.exit_scope()

    def _analyze_return(self, node: ReturnNode):
        """Valida que un retorno coincida con la firma de la funcion."""

        if self.current_function is None:
            self.error(node.line, node.column, "return_outside_function")
            return

        expected = self.current_function.return_type
        if expected is None:
            return
        if expected.is_void:
            if node.value is not None:
                self.error(node.line, node.column, "void_function_return_forbidden")
            return

        if node.value is None:
            self.error(
                node.line,
                node.column,
                "missing_return_expression",
                function_name=self.current_function.name,
                expected_type=str(expected),
            )
            return

        self._validate_vault_expression_rules(node.value)
        actual = self._infer_expression_type(node.value)
        if actual and not self.is_assignable(expected, actual):
            self.error(
                node.line,
                node.column,
                "return_type_mismatch",
                actual_type=str(actual),
                expected_type=str(expected),
            )

    def _analyze_continue(self, node: ContinueNode):
        """Verifica que continue aparezca dentro de un ciclo."""

        if self.loop_depth <= 0:
            self.error(node.line, node.column, "continue_outside_loop")

    def _analyze_break(self, node: BreakNode):
        """Verifica que break aparezca dentro de un ciclo."""

        if self.loop_depth <= 0:
            self.error(node.line, node.column, "break_outside_loop")

    # INFERENCIA DE TIPOS

    def _require_bool_condition(self, expression, construct: str):
        """Exige que una condicion sea de tipo bool."""

        self._validate_vault_expression_rules(expression)
        condition_type = self._infer_expression_type(expression)
        if condition_type is not None and not condition_type.is_bool:
            self.error(
                expression.line,
                expression.column,
                "condition_type_mismatch",
                construct=construct,
                actual_type=str(condition_type),
            )

    def _validate_vault_expression_rules(self, expression):
        """Aplica restricciones especiales sobre lecturas desde vault."""

        if expression is None:
            return

        if self._is_vault_access(expression):
            self.error(
                expression.line,
                expression.column,
                "direct_vault_value_forbidden",
            )

        self._walk_vault_expression_rules(expression)

    def _walk_vault_expression_rules(self, node):
        """Recorre expresiones para detectar comparaciones o neutros con vault."""

        if node is None:
            return

        if isinstance(node, BinaryOpNode):
            left_has_vault = self._contains_vault_access(node.left)
            right_has_vault = self._contains_vault_access(node.right)

            if node.operator in EQUALITY_OPERATORS | RELATIONAL_OPERATORS:
                if left_has_vault or right_has_vault:
                    self.error(
                        node.line,
                        node.column,
                        "vault_comparison_forbidden",
                        operator=node.operator,
                    )

            if self._is_neutral_vault_operation(node, left_has_vault, right_has_vault):
                self.error(
                    node.line,
                    node.column,
                    "neutral_vault_operation",
                    operator=node.operator,
                )

            self._walk_vault_expression_rules(node.left)
            self._walk_vault_expression_rules(node.right)
            return

        if isinstance(node, UnaryOpNode):
            if self._is_vault_access(node.operand):
                self.error(
                    node.operand.line,
                    node.operand.column,
                    "direct_vault_value_forbidden",
                )
            self._walk_vault_expression_rules(node.operand)
            return

        if isinstance(node, CallNode):
            self._walk_vault_expression_rules(node.callee)
            for arg in node.arguments:
                if self._is_vault_access(arg):
                    self.error(
                        arg.line,
                        arg.column,
                        "direct_vault_value_forbidden",
                    )
                self._walk_vault_expression_rules(arg)
            return

        if isinstance(node, IndexAccessNode):
            if self._contains_vault_access(node.index):
                self.error(
                    node.index.line,
                    node.index.column,
                    "vault_index_expression_forbidden",
                )
            self._walk_vault_expression_rules(node.target)
            self._walk_vault_expression_rules(node.index)
            return

    def _validate_vault_assignment_rules(self, node: AssignmentNode):
        """Aplica restricciones especiales a asignaciones sobre vault[i]."""

        if not self._is_vault_access(node.target):
            return

        if self._contains_vault_access(node.target.index):
            self.error(
                node.target.index.line,
                node.target.index.column,
                "vault_index_expression_forbidden",
            )

        neutral_map = {
            "+=": 0,
            "-=": 0,
            "|=": 0,
            "^=": 0,
            "<<=": 0,
            ">>=": 0,
            "*=": 1,
            "/=": 1,
            "%=": 1,
        }
        neutral = neutral_map.get(node.operator)
        if neutral is not None and self._is_neutral_literal(node.value, neutral):
            self.error(
                node.line,
                node.column,
                "neutral_vault_operation",
                operator=node.operator,
            )

    def _contains_vault_access(self, node) -> bool:
        """Indica si una expresion contiene al menos un acceso vault[i]."""

        if node is None:
            return False
        if self._is_vault_access(node):
            return True
        if isinstance(node, UnaryOpNode):
            return self._contains_vault_access(node.operand)
        if isinstance(node, BinaryOpNode):
            return self._contains_vault_access(node.left) or self._contains_vault_access(node.right)
        if isinstance(node, CallNode):
            return self._contains_vault_access(node.callee) or any(
                self._contains_vault_access(arg) for arg in node.arguments
            )
        if isinstance(node, IndexAccessNode):
            return self._contains_vault_access(node.target) or self._contains_vault_access(node.index)
        return False

    def _is_vault_access(self, node) -> bool:
        """Reconoce si un nodo representa una lectura o escritura sobre vault."""

        if not isinstance(node, IndexAccessNode):
            return False
        target_type = self._infer_expression_type(node.target)
        return target_type is not None and target_type.name == "vault"

    def _is_neutral_literal(self, node, expected: int) -> bool:
        """Indica si un literal entero/hex coincide con un valor concreto."""

        if not isinstance(node, LiteralNode):
            return False
        if node.literal_type not in {"int", "hex"}:
            return False
        return int(str(node.value), 0) == expected

    def _is_neutral_vault_operation(self, node: BinaryOpNode, left_has_vault: bool, right_has_vault: bool) -> bool:
        """Detecta usos de vault[i] combinados con elementos neutros."""

        if node.operator in {"+", "-", "|", "^", "<<", ">>"}:
            return (
                (left_has_vault and self._is_neutral_literal(node.right, 0))
                or (right_has_vault and self._is_neutral_literal(node.left, 0))
            )

        if node.operator in {"*", "/", "%"}:
            return (
                (left_has_vault and self._is_neutral_literal(node.right, 1))
                or (right_has_vault and self._is_neutral_literal(node.left, 1))
            )

        return False

    def _is_addressable(self, node) -> bool:
        """Indica si una expresion puede tomar direccion con '&'."""

        return isinstance(node, (IdentifierNode, IndexAccessNode))

    def _infer_lvalue_type(self, node) -> Optional[TypeInfo]:
        """Infiere el tipo del lado izquierdo de una asignacion."""

        if isinstance(node, IdentifierNode):
            symbol = self.require_declared(node.name, node.line, node.column)
            if symbol is None:
                return None
            if symbol.kind == "function":
                self.error(node.line, node.column, "assignment_to_function", name=node.name)
                return None
            if symbol.extra.get("readonly"):
                self.error(node.line, node.column, "assignment_to_readonly_register", name=node.name)
                return None
            if symbol.type_info is not None and symbol.type_info.is_array:
                self.error(
                    node.line,
                    node.column,
                    "assignment_to_array",
                    name=node.name,
                    target_type=str(symbol.type_info),
                )
                return None
            return symbol.type_info

        if isinstance(node, IndexAccessNode):
            indexed_type = self._infer_expression_type(node)
            if indexed_type is not None and indexed_type.is_array:
                self.error(
                    node.line,
                    node.column,
                    "assignment_to_array",
                    name="array element",
                    target_type=str(indexed_type),
                )
                return None
            return indexed_type

        if isinstance(node, MemberAccessNode):
            self._infer_expression_type(node)
            return None

        self._infer_expression_type(node)
        self.error(node.line, node.column, "invalid_assignment_target")
        return None

    def _infer_expression_type(self, node) -> Optional[TypeInfo]:
        """Infiere el tipo de una expresion y reporta errores asociados."""

        if isinstance(node, IdentifierNode):
            symbol = self.require_declared(node.name, node.line, node.column)
            if symbol is None:
                return None
            if symbol.kind == "function":
                self.error(node.line, node.column, "function_used_as_value", name=node.name)
                return None
            return symbol.type_info

        if isinstance(node, LiteralNode):
            if node.literal_type == "int":
                return TypeInfo("int")
            if node.literal_type == "float":
                return TypeInfo("float")
            if node.literal_type == "hex":
                return TypeInfo("int")
            if node.literal_type == "string":
                return TypeInfo("char", is_pointer=True)
            if node.literal_type == "char":
                return TypeInfo("char")
            if node.literal_type == "bool":
                return TypeInfo("bool")
            return None

        if isinstance(node, UnaryOpNode):
            return self._infer_unary_type(node)

        if isinstance(node, BinaryOpNode):
            return self._infer_binary_type(node)

        if isinstance(node, CallNode):
            return self._infer_call_type(node)

        if isinstance(node, IndexAccessNode):
            return self._infer_index_type(node)

        if isinstance(node, MemberAccessNode):
            self._infer_expression_type(node.target)
            self.error(
                node.line,
                node.column,
                "invalid_member_access",
                member=node.member,
            )
            return None

        return None

    def _infer_unary_type(self, node: UnaryOpNode) -> Optional[TypeInfo]:
        """Infiere y valida el tipo resultante de una operacion unaria."""

        operand_type = self._infer_expression_type(node.operand)
        if operand_type is None:
            return None

        if node.operator == "!":
            if not operand_type.is_bool:
                self.error(
                    node.line,
                    node.column,
                    "invalid_unary_operand",
                    operator=node.operator,
                    operand_type=str(operand_type),
                    expected_type="bool",
                )
                return None
            return TypeInfo("bool")

        if node.operator == "-":
            if not operand_type.is_numeric:
                self.error(
                    node.line,
                    node.column,
                    "invalid_unary_operand",
                    operator=node.operator,
                    operand_type=str(operand_type),
                    expected_type='int, char o float',
                )
                return None
            if operand_type.name == "float":
                return TypeInfo("float")
            return TypeInfo("int")

        if node.operator == "&":
            if operand_type.is_void or not self._is_addressable(node.operand):
                self.error(
                    node.line,
                    node.column,
                    "invalid_unary_operand",
                    operator=node.operator,
                    operand_type=str(operand_type),
                    expected_type="valor direccionable",
                )
                return None
            return TypeInfo(operand_type.name, is_pointer=True, vault_inner=operand_type.vault_inner)

        if node.operator == "*":
            if not operand_type.is_pointer:
                self.error(
                    node.line,
                    node.column,
                    "invalid_unary_operand",
                    operator=node.operator,
                    operand_type=str(operand_type),
                    expected_type="puntero",
                )
                return None
            return TypeInfo(operand_type.name, vault_inner=operand_type.vault_inner)

        return operand_type

    def _infer_binary_type(self, node: BinaryOpNode) -> Optional[TypeInfo]:
        """Infiere y valida el tipo resultante de una operacion binaria."""

        left = self._infer_expression_type(node.left)
        right = self._infer_expression_type(node.right)

        if left is None or right is None:
            return None

        if node.operator in EQUALITY_OPERATORS:
            if left.is_numeric and right.is_numeric:
                return TypeInfo("bool")
            if self.is_assignable(left, right) or self.is_assignable(right, left):
                return TypeInfo("bool")
            self.error(
                node.line,
                node.column,
                "invalid_comparison",
                operator=node.operator,
                left_type=str(left),
                right_type=str(right),
            )
            return TypeInfo("bool")

        if node.operator in RELATIONAL_OPERATORS:
            if left.is_numeric and right.is_numeric:
                return TypeInfo("bool")
            self.error(
                node.line,
                node.column,
                "invalid_comparison",
                operator=node.operator,
                left_type=str(left),
                right_type=str(right),
            )
            return TypeInfo("bool")

        if node.operator in ARITHMETIC_PROMOTING_OPERATORS:
            if left.is_numeric and right.is_numeric:
                if left.name == "float" or right.name == "float":
                    return TypeInfo("float")
                return TypeInfo("int")
            self.error(
                node.line,
                node.column,
                "invalid_operation",
                operator=node.operator,
                left_type=str(left),
                right_type=str(right),
            )
            return None

        if node.operator in INTEGRAL_ONLY_OPERATORS:
            if left.is_integral and right.is_integral:
                return TypeInfo("int")
            self.error(
                node.line,
                node.column,
                "invalid_operation",
                operator=node.operator,
                left_type=str(left),
                right_type=str(right),
            )
            return None

        if node.operator in BITWISE_OPERATORS:
            if left.is_bool and right.is_bool:
                return TypeInfo("bool")
            if left.is_integral and right.is_integral:
                return TypeInfo("int")
            self.error(
                node.line,
                node.column,
                "invalid_operation",
                operator=node.operator,
                left_type=str(left),
                right_type=str(right),
            )
            return None

        self.error(
            node.line,
            node.column,
            "invalid_operation",
            operator=node.operator,
            left_type=str(left),
            right_type=str(right),
        )
        return None

    def _infer_index_type(self, node: IndexAccessNode) -> Optional[TypeInfo]:
        """Infiere el tipo de un acceso indexado y valida el indice."""

        target_type = self._infer_expression_type(node.target)
        index_type = self._infer_expression_type(node.index)

        if index_type is not None and index_type.name != "int":
            self.error(
                node.index.line,
                node.index.column,
                "array_index_type_mismatch",
                actual_type=str(index_type),
            )

        if target_type is None:
            return None

        if target_type.is_array:
            self._check_literal_index_bounds(node, target_type)
            return target_type.element_type()

        if target_type.is_pointer:
            return TypeInfo(name=target_type.name, vault_inner=target_type.vault_inner)

        self.error(
            node.line,
            node.column,
            "invalid_indexing",
            target_type=str(target_type),
        )
        return None

    def _check_literal_index_bounds(self, node: IndexAccessNode, target_type: TypeInfo):
        """Detecta indices literales fuera de rango en arreglos conocidos."""

        if not isinstance(node.index, LiteralNode):
            return
        if node.index.literal_type not in {"int", "hex"}:
            return
        if not target_type.array_dims and not (
            target_type.name == "vault" and target_type.vault_inner is not None
        ):
            return

        index_value = int(str(node.index.value), 0)
        first_dim = (
            target_type.array_dims[0]
            if target_type.array_dims
            else int(target_type.vault_inner)
        )
        if first_dim > 0 and (index_value < 0 or index_value >= first_dim):
            self.error(
                node.index.line,
                node.index.column,
                "array_index_out_of_bounds",
                index=index_value,
                size=first_dim,
            )

    def _infer_call_type(self, node: CallNode) -> Optional[TypeInfo]:
        """Infiere el tipo de retorno de una llamada y valida argumentos."""

        if isinstance(node.callee, IdentifierNode):
            symbol = self.require_declared(
                node.callee.name,
                node.callee.line,
                node.callee.column,
            )
            if symbol is None:
                for arg in node.arguments:
                    self._infer_expression_type(arg)
                return None

            if symbol.kind != "function":
                self.error(
                    node.line,
                    node.column,
                    "not_a_function",
                    name=node.callee.name,
                    actual_kind=symbol.kind,
                )
                for arg in node.arguments:
                    self._infer_expression_type(arg)
                return None

            expected_params = symbol.params
            actual_args = node.arguments

            if len(expected_params) != len(actual_args):
                self.error(
                    node.line,
                    node.column,
                    "wrong_argument_count",
                    name=symbol.name,
                    expected=len(expected_params),
                    actual=len(actual_args),
                )

            for index, arg in enumerate(actual_args):
                actual = self._infer_expression_type(arg)
                if actual is None or index >= len(expected_params):
                    continue

                expected = expected_params[index]
                if not self.is_assignable(expected, actual):
                    self.error(
                        arg.line,
                        arg.column,
                        "incompatible_argument",
                        function_name=symbol.name,
                        position=index + 1,
                        expected_type=str(expected),
                        actual_type=str(actual),
                    )

            return symbol.return_type

        if node.callee is not None:
            callee_type = self._infer_expression_type(node.callee)
            self.error(
                node.line,
                node.column,
                "unsupported_indirect_call",
                callee_type=str(callee_type) if callee_type else "desconocido",
            )
        for arg in node.arguments:
            self._infer_expression_type(arg)
        return None

    # DIMENSIONES DE ARREGLO

    def _extract_dimensions(self, declarator: VarDeclaratorNode) -> List[int]:
        """Extrae dimensiones de arreglo y valida que sean literales enteros."""

        dims: List[int] = []

        for dim_expr in declarator.dimensions:
            if dim_expr is None:
                self.error(
                    declarator.line,
                    declarator.column,
                    "array_dimension_missing",
                    name=declarator.name,
                    type_name="arreglo",
                )
                dims.append(0)
                continue

            if isinstance(dim_expr, LiteralNode) and dim_expr.literal_type in {"int", "hex"}:
                value = int(str(dim_expr.value), 0)
                if value <= 0:
                    self.error(
                        dim_expr.line,
                        dim_expr.column,
                        "array_dimension_must_be_positive",
                        value=value,
                    )
                dims.append(value)
                continue

            self.error(
                dim_expr.line,
                dim_expr.column,
                "array_dimension_must_be_int_literal",
            )
            dims.append(0)

        return dims
