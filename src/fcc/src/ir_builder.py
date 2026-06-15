from __future__ import annotations

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
    MemberAccessNode,
    ProgramNode,
    ReturnNode,
    UnaryOpNode,
    VarDeclNode,
    WhileNode,
)
from ir_nodes import IRFunction, IRInstruction, IRProgram


class IRBuilder:
    """Convierte AST en TAC.

    Entradas: ProgramNode ya validado semanticamente.
    Salida: IRProgram lineal por funcion.
    Uso: ir_driver.build_ir, optimizador y backend IR.
    """

    def __init__(self):
        """Entradas: ninguna. Salida: builder con estado limpio. Uso: build."""
        self.program = IRProgram()
        self.current: IRFunction | None = None
        self.temp_counter = 0
        self.label_counter = 0
        self.loop_stack: list[dict[str, str]] = []

    def build(self, ast: ProgramNode) -> IRProgram:
        """Entradas: AST. Salida: IRProgram. Uso: ir_driver.build_ir."""
        self.program = IRProgram()
        # Primero se registran globales; no se emite codigo para ellas aqui.
        for declaration in ast.declarations:
            if isinstance(declaration, VarDeclNode):
                for declarator in declaration.declarators:
                    self.program.globals.append(declarator.name)

        for declaration in ast.declarations:
            if isinstance(declaration, FunctionDeclNode):
                # Luego se emiten solo funciones ejecutables.
                self._emit_function(declaration)
        return self.program

    def _new_temp(self) -> str:
        """Entradas: ninguna. Salida: temporal tN. Uso: expresiones TAC."""
        self.temp_counter += 1
        return f"t{self.temp_counter}"

    def _new_label(self, prefix: str) -> str:
        """Entradas: prefijo. Salida: label unico por funcion. Uso: if/while/for."""
        self.label_counter += 1
        function_name = self.current.name if self.current else "global"
        return f"{function_name}_{prefix}_{self.label_counter}"

    def _emit(self, op: str, dest: str | None = None, args: list[str] | None = None, target: str | None = None, extra: str | None = None, node=None):
        """Entradas: campos TAC y nodo fuente. Salida: instruccion en funcion actual. Uso: todo el builder."""
        if self.current is None:
            # Sin funcion activa no hay destino valido para TAC.
            return
        # line/column viajan hasta diagnosticos del backend IR.
        self.current.emit(
            IRInstruction(
                op=op,
                dest=dest,
                args=args or [],
                target=target,
                extra=extra,
                line=getattr(node, "line", 0),
                column=getattr(node, "column", 0),
            )
        )

    def _emit_label(self, label: str):
        """Entradas: label. Salida: instruccion label. Uso: estructuras de control."""
        self._emit("label", dest=label)

    def _emit_function(self, node: FunctionDeclNode):
        """Entradas: FunctionDeclNode. Salida: IRFunction agregada. Uso: build."""
        self.temp_counter = 0
        self.loop_stack = []
        function = IRFunction(
            name=node.name,
            params=[param.name for param in node.params],
            return_type=node.return_type,
        )
        self.current = function
        self._emit_block(node.body)
        if not self._ends_with_return(function):
            # La IR siempre cierra la funcion para que el backend no caiga fuera.
            self._emit("return", node=node)
        self.program.functions.append(function)
        self.current = None

    def _ends_with_return(self, function: IRFunction) -> bool:
        """Entradas: IRFunction. Salida: True si termina con return. Uso: _emit_function."""
        return bool(function.instructions and function.instructions[-1].op == "return")

    def _emit_block(self, node: BlockNode | None):
        """Entradas: bloque AST opcional. Salida: TAC por sentencia. Uso: funciones/control."""
        if node is None:
            # Bloques ausentes no emiten TAC.
            return
        for statement in node.statements:
            self._emit_statement(statement)

    def _emit_statement(self, node):
        """Entradas: sentencia AST. Salida: TAC equivalente. Uso: _emit_block."""
        if isinstance(node, VarDeclNode):
            for declarator in node.declarators:
                if declarator.initializer is not None:
                    # Declaraciones sin inicializador ya fueron reservadas por semantica.
                    value = self._emit_expression(declarator.initializer)
                    self._emit("assign", dest=declarator.name, args=[value], node=declarator)
            return

        if isinstance(node, AssignmentNode):
            # Asignaciones centralizan lvalue: variable, arreglo o puntero.
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
            # Return sin valor se representa con args vacio.
            args = [self._emit_expression(node.value)] if node.value is not None else []
            self._emit("return", args=args, node=node)
            return

        if isinstance(node, ContinueNode):
            if self.loop_stack:
                # Continue apunta al label propio del loop activo.
                self._emit("goto", target=self.loop_stack[-1]["continue"], node=node)
            return

        if isinstance(node, BreakNode):
            if self.loop_stack:
                # Break cae al label final del loop activo.
                self._emit("goto", target=self.loop_stack[-1]["break"], node=node)
            return

        if isinstance(node, ExpressionStmtNode):
            if node.expression is not None:
                # Llamadas pueden tener efectos aunque se descarte el resultado.
                self._emit_expression(node.expression, discard_result=True)
            return

        if isinstance(node, BlockNode):
            self._emit_block(node)

    def _emit_assignment(self, node: AssignmentNode):
        """Entradas: asignacion AST. Salida: assign/store TAC. Uso: _emit_statement."""
        value = self._emit_expression(node.value)

        if node.operator != "=":
            # x += y se baja como: tmp = x + y; x = tmp.
            current = self._emit_lvalue_load(node.target)
            op = node.operator[:-1]
            result = self._new_temp()
            self._emit("binop", dest=result, args=[current, value], extra=op, node=node)
            value = result

        self._emit_lvalue_store(node.target, value, node)

    def _emit_lvalue_load(self, node) -> str:
        """Entradas: lvalue AST. Salida: nombre con valor actual. Uso: asignaciones compuestas."""
        if isinstance(node, IdentifierNode):
            return node.name
        if isinstance(node, IndexAccessNode):
            base = self._emit_expression(node.target)
            index = self._emit_expression(node.index)
            result = self._new_temp()
            self._emit("load_index", dest=result, args=[base, index], node=node)
            return result
        if isinstance(node, UnaryOpNode) and node.operator == "*":
            pointer = self._emit_expression(node.operand)
            result = self._new_temp()
            self._emit("deref", dest=result, args=[pointer], node=node)
            return result
        return self._emit_expression(node)

    def _emit_lvalue_store(self, target, value: str, node):
        """Entradas: destino, valor IR y nodo fuente. Salida: escritura TAC. Uso: asignaciones."""
        if isinstance(target, IdentifierNode):
            # x = value se modela como assign directo.
            self._emit("assign", dest=target.name, args=[value], node=node)
            return
        if isinstance(target, IndexAccessNode):
            # a[i] = value conserva base, indice y valor separados.
            base = self._emit_expression(target.target)
            index = self._emit_expression(target.index)
            self._emit("store_index", args=[base, index, value], node=node)
            return
        if isinstance(target, UnaryOpNode) and target.operator == "*":
            pointer = self._emit_expression(target.operand)
            self._emit("store_deref", args=[pointer, value], node=node)

    def _emit_if(self, node: IfNode):
        """Entradas: IfNode. Salida: labels y branches TAC. Uso: _emit_statement."""
        end_label = self._new_label("if_end")
        next_label = self._new_label("if_next")

        condition = self._emit_expression(node.condition)
        # Se salta al siguiente brazo cuando la condicion materializada vale 0.
        self._emit("if_false", args=[condition], target=next_label, node=node.condition)
        self._emit_block(node.then_block)
        self._emit("goto", target=end_label, node=node)
        self._emit_label(next_label)

        for branch in node.elif_branches:
            # Cada elif tiene su propio punto de caida.
            branch_next = self._new_label("elif_next")
            condition = self._emit_expression(branch.condition)
            self._emit("if_false", args=[condition], target=branch_next, node=branch.condition)
            self._emit_block(branch.block)
            self._emit("goto", target=end_label, node=branch)
            self._emit_label(branch_next)

        if node.else_block is not None:
            # Else cae naturalmente despues de todos los elif fallidos.
            self._emit_block(node.else_block)

        self._emit_label(end_label)

    def _emit_while(self, node: WhileNode):
        """Entradas: WhileNode. Salida: loop label-cond-body-goto. Uso: _emit_statement."""
        cond_label = self._new_label("while_cond")
        end_label = self._new_label("while_end")

        # continue vuelve a evaluar condicion; break cae despues del loop.
        self.loop_stack.append({"continue": cond_label, "break": end_label})
        self._emit_label(cond_label)
        condition = self._emit_expression(node.condition)
        self._emit("if_false", args=[condition], target=end_label, node=node.condition)
        self._emit_block(node.body)
        self._emit("goto", target=cond_label, node=node)
        self._emit_label(end_label)
        # Al salir se restaura el loop externo.
        self.loop_stack.pop()

    def _emit_for(self, node: ForNode):
        """Entradas: ForNode. Salida: init-cond-body-update-goto. Uso: _emit_statement."""
        if node.initializer is not None:
            self._emit_statement(node.initializer)

        cond_label = self._new_label("for_cond")
        update_label = self._new_label("for_update")
        end_label = self._new_label("for_end")

        # El update tiene label propio: continue debe ejecutar incremento antes de probar.
        self.loop_stack.append({"continue": update_label, "break": end_label})
        self._emit_label(cond_label)
        if node.condition is not None:
            condition = self._emit_expression(node.condition)
            self._emit("if_false", args=[condition], target=end_label, node=node.condition)
        self._emit_block(node.body)
        self._emit_label(update_label)
        if node.increment is not None:
            self._emit_statement(node.increment)
        self._emit("goto", target=cond_label, node=node)
        self._emit_label(end_label)
        # Fin del for: break/continue vuelven al contexto anterior.
        self.loop_stack.pop()

    def _emit_expression(self, node, discard_result: bool = False) -> str:
        """Entradas: expresion AST y descarte. Salida: nombre IR resultante. Uso: sentencias."""
        if node is None:
            return "void"

        if isinstance(node, IdentifierNode):
            return node.name

        if isinstance(node, LiteralNode):
            result = self._new_temp()
            # Los literales se materializan primero como constantes TAC.
            self._emit("const", dest=result, extra=str(node.value), node=node)
            return result

        if isinstance(node, UnaryOpNode):
            operand = self._emit_expression(node.operand)
            if node.operator == "&":
                # addr conserva direccion; el backend decide stack/global.
                result = self._new_temp()
                self._emit("addr", dest=result, args=[operand], node=node)
                return result
            result = self._new_temp()
            self._emit("unop", dest=result, args=[operand], extra=node.operator, node=node)
            return result

        if isinstance(node, BinaryOpNode):
            # Toda operacion binaria produce un temporal TAC explicito.
            left = self._emit_expression(node.left)
            right = self._emit_expression(node.right)
            result = self._new_temp()
            self._emit("binop", dest=result, args=[left, right], extra=node.operator, node=node)
            return result

        if isinstance(node, CallNode):
            args = [self._emit_expression(arg) for arg in node.arguments]
            callee = self._callee_name(node.callee)
            for arg in args:
                # param conserva el orden de argumentos hasta que aparece call.
                self._emit("param", args=[arg], node=node)
            result = None if discard_result else self._new_temp()
            self._emit("call", dest=result, args=args, extra=callee, node=node)
            return result or "_"

        if isinstance(node, IndexAccessNode):
            base = self._emit_expression(node.target)
            index = self._emit_expression(node.index)
            result = self._new_temp()
            self._emit("load_index", dest=result, args=[base, index], node=node)
            return result

        if isinstance(node, MemberAccessNode):
            target = self._emit_expression(node.target)
            result = self._new_temp()
            # member queda explicito aunque el backend actual lo soporte parcialmente.
            self._emit("member", dest=result, args=[target], extra=node.member, node=node)
            return result

        return "_"

    def _callee_name(self, node) -> str:
        """Entradas: callee AST. Salida: nombre de funcion. Uso: llamadas."""
        if isinstance(node, IdentifierNode):
            return node.name
        return self._emit_expression(node)
