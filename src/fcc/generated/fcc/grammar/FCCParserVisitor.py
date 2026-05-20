# Generated from fcc/grammar/FCCParser.g4 by ANTLR 4.13.2
from antlr4 import *
if "." in __name__:
    from .FCCParser import FCCParser
else:
    from FCCParser import FCCParser

# This class defines a complete generic visitor for a parse tree produced by FCCParser.

class FCCParserVisitor(ParseTreeVisitor):

    # Visit a parse tree produced by FCCParser#program.
    def visitProgram(self, ctx:FCCParser.ProgramContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#topLevelDecl.
    def visitTopLevelDecl(self, ctx:FCCParser.TopLevelDeclContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#importStmt.
    def visitImportStmt(self, ctx:FCCParser.ImportStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#secureFunctionDecl.
    def visitSecureFunctionDecl(self, ctx:FCCParser.SecureFunctionDeclContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#secureAnnotation.
    def visitSecureAnnotation(self, ctx:FCCParser.SecureAnnotationContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#functionName.
    def visitFunctionName(self, ctx:FCCParser.FunctionNameContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#functionDecl.
    def visitFunctionDecl(self, ctx:FCCParser.FunctionDeclContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#globalVarDecl.
    def visitGlobalVarDecl(self, ctx:FCCParser.GlobalVarDeclContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#parameterList.
    def visitParameterList(self, ctx:FCCParser.ParameterListContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#parameter.
    def visitParameter(self, ctx:FCCParser.ParameterContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#typeRule.
    def visitTypeRule(self, ctx:FCCParser.TypeRuleContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#baseType.
    def visitBaseType(self, ctx:FCCParser.BaseTypeContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#vaultType.
    def visitVaultType(self, ctx:FCCParser.VaultTypeContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#arraySuffix.
    def visitArraySuffix(self, ctx:FCCParser.ArraySuffixContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#block.
    def visitBlock(self, ctx:FCCParser.BlockContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#statement.
    def visitStatement(self, ctx:FCCParser.StatementContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#varDecl.
    def visitVarDecl(self, ctx:FCCParser.VarDeclContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#variableDeclaratorList.
    def visitVariableDeclaratorList(self, ctx:FCCParser.VariableDeclaratorListContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#variableDeclarator.
    def visitVariableDeclarator(self, ctx:FCCParser.VariableDeclaratorContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#initializer.
    def visitInitializer(self, ctx:FCCParser.InitializerContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#assignmentStmt.
    def visitAssignmentStmt(self, ctx:FCCParser.AssignmentStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#assignment.
    def visitAssignment(self, ctx:FCCParser.AssignmentContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#assignmentOperator.
    def visitAssignmentOperator(self, ctx:FCCParser.AssignmentOperatorContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#assignable.
    def visitAssignable(self, ctx:FCCParser.AssignableContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#returnStmt.
    def visitReturnStmt(self, ctx:FCCParser.ReturnStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#continueStmt.
    def visitContinueStmt(self, ctx:FCCParser.ContinueStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#breakStmt.
    def visitBreakStmt(self, ctx:FCCParser.BreakStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#exprStmt.
    def visitExprStmt(self, ctx:FCCParser.ExprStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#ifStmt.
    def visitIfStmt(self, ctx:FCCParser.IfStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#elifBranch.
    def visitElifBranch(self, ctx:FCCParser.ElifBranchContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#elseBranch.
    def visitElseBranch(self, ctx:FCCParser.ElseBranchContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#whileStmt.
    def visitWhileStmt(self, ctx:FCCParser.WhileStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#forStmt.
    def visitForStmt(self, ctx:FCCParser.ForStmtContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#forInitializer.
    def visitForInitializer(self, ctx:FCCParser.ForInitializerContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#forIncrement.
    def visitForIncrement(self, ctx:FCCParser.ForIncrementContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#forCondition.
    def visitForCondition(self, ctx:FCCParser.ForConditionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#varDeclNoSemi.
    def visitVarDeclNoSemi(self, ctx:FCCParser.VarDeclNoSemiContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#expression.
    def visitExpression(self, ctx:FCCParser.ExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#bitwiseOrExpression.
    def visitBitwiseOrExpression(self, ctx:FCCParser.BitwiseOrExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#bitwiseXorExpression.
    def visitBitwiseXorExpression(self, ctx:FCCParser.BitwiseXorExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#bitwiseAndExpression.
    def visitBitwiseAndExpression(self, ctx:FCCParser.BitwiseAndExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#equalityExpression.
    def visitEqualityExpression(self, ctx:FCCParser.EqualityExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#relationalExpression.
    def visitRelationalExpression(self, ctx:FCCParser.RelationalExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#shiftExpression.
    def visitShiftExpression(self, ctx:FCCParser.ShiftExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#additiveExpression.
    def visitAdditiveExpression(self, ctx:FCCParser.AdditiveExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#multiplicativeExpression.
    def visitMultiplicativeExpression(self, ctx:FCCParser.MultiplicativeExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#unaryExpression.
    def visitUnaryExpression(self, ctx:FCCParser.UnaryExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#postfixExpression.
    def visitPostfixExpression(self, ctx:FCCParser.PostfixExpressionContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#postfixSuffix.
    def visitPostfixSuffix(self, ctx:FCCParser.PostfixSuffixContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#argumentList.
    def visitArgumentList(self, ctx:FCCParser.ArgumentListContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#primary.
    def visitPrimary(self, ctx:FCCParser.PrimaryContext):
        return self.visitChildren(ctx)


    # Visit a parse tree produced by FCCParser#literal.
    def visitLiteral(self, ctx:FCCParser.LiteralContext):
        return self.visitChildren(ctx)



del FCCParser