# Generated from fcc/grammar/FCCParser.g4 by ANTLR 4.13.2
from antlr4 import *
if "." in __name__:
    from .FCCParser import FCCParser
else:
    from FCCParser import FCCParser

# This class defines a complete listener for a parse tree produced by FCCParser.
class FCCParserListener(ParseTreeListener):

    # Enter a parse tree produced by FCCParser#program.
    def enterProgram(self, ctx:FCCParser.ProgramContext):
        pass

    # Exit a parse tree produced by FCCParser#program.
    def exitProgram(self, ctx:FCCParser.ProgramContext):
        pass


    # Enter a parse tree produced by FCCParser#topLevelDecl.
    def enterTopLevelDecl(self, ctx:FCCParser.TopLevelDeclContext):
        pass

    # Exit a parse tree produced by FCCParser#topLevelDecl.
    def exitTopLevelDecl(self, ctx:FCCParser.TopLevelDeclContext):
        pass


    # Enter a parse tree produced by FCCParser#importStmt.
    def enterImportStmt(self, ctx:FCCParser.ImportStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#importStmt.
    def exitImportStmt(self, ctx:FCCParser.ImportStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#secureFunctionDecl.
    def enterSecureFunctionDecl(self, ctx:FCCParser.SecureFunctionDeclContext):
        pass

    # Exit a parse tree produced by FCCParser#secureFunctionDecl.
    def exitSecureFunctionDecl(self, ctx:FCCParser.SecureFunctionDeclContext):
        pass


    # Enter a parse tree produced by FCCParser#secureAnnotation.
    def enterSecureAnnotation(self, ctx:FCCParser.SecureAnnotationContext):
        pass

    # Exit a parse tree produced by FCCParser#secureAnnotation.
    def exitSecureAnnotation(self, ctx:FCCParser.SecureAnnotationContext):
        pass


    # Enter a parse tree produced by FCCParser#functionName.
    def enterFunctionName(self, ctx:FCCParser.FunctionNameContext):
        pass

    # Exit a parse tree produced by FCCParser#functionName.
    def exitFunctionName(self, ctx:FCCParser.FunctionNameContext):
        pass


    # Enter a parse tree produced by FCCParser#functionDecl.
    def enterFunctionDecl(self, ctx:FCCParser.FunctionDeclContext):
        pass

    # Exit a parse tree produced by FCCParser#functionDecl.
    def exitFunctionDecl(self, ctx:FCCParser.FunctionDeclContext):
        pass


    # Enter a parse tree produced by FCCParser#globalVarDecl.
    def enterGlobalVarDecl(self, ctx:FCCParser.GlobalVarDeclContext):
        pass

    # Exit a parse tree produced by FCCParser#globalVarDecl.
    def exitGlobalVarDecl(self, ctx:FCCParser.GlobalVarDeclContext):
        pass


    # Enter a parse tree produced by FCCParser#parameterList.
    def enterParameterList(self, ctx:FCCParser.ParameterListContext):
        pass

    # Exit a parse tree produced by FCCParser#parameterList.
    def exitParameterList(self, ctx:FCCParser.ParameterListContext):
        pass


    # Enter a parse tree produced by FCCParser#parameter.
    def enterParameter(self, ctx:FCCParser.ParameterContext):
        pass

    # Exit a parse tree produced by FCCParser#parameter.
    def exitParameter(self, ctx:FCCParser.ParameterContext):
        pass


    # Enter a parse tree produced by FCCParser#typeRule.
    def enterTypeRule(self, ctx:FCCParser.TypeRuleContext):
        pass

    # Exit a parse tree produced by FCCParser#typeRule.
    def exitTypeRule(self, ctx:FCCParser.TypeRuleContext):
        pass


    # Enter a parse tree produced by FCCParser#baseType.
    def enterBaseType(self, ctx:FCCParser.BaseTypeContext):
        pass

    # Exit a parse tree produced by FCCParser#baseType.
    def exitBaseType(self, ctx:FCCParser.BaseTypeContext):
        pass


    # Enter a parse tree produced by FCCParser#vaultType.
    def enterVaultType(self, ctx:FCCParser.VaultTypeContext):
        pass

    # Exit a parse tree produced by FCCParser#vaultType.
    def exitVaultType(self, ctx:FCCParser.VaultTypeContext):
        pass


    # Enter a parse tree produced by FCCParser#arraySuffix.
    def enterArraySuffix(self, ctx:FCCParser.ArraySuffixContext):
        pass

    # Exit a parse tree produced by FCCParser#arraySuffix.
    def exitArraySuffix(self, ctx:FCCParser.ArraySuffixContext):
        pass


    # Enter a parse tree produced by FCCParser#block.
    def enterBlock(self, ctx:FCCParser.BlockContext):
        pass

    # Exit a parse tree produced by FCCParser#block.
    def exitBlock(self, ctx:FCCParser.BlockContext):
        pass


    # Enter a parse tree produced by FCCParser#statement.
    def enterStatement(self, ctx:FCCParser.StatementContext):
        pass

    # Exit a parse tree produced by FCCParser#statement.
    def exitStatement(self, ctx:FCCParser.StatementContext):
        pass


    # Enter a parse tree produced by FCCParser#varDecl.
    def enterVarDecl(self, ctx:FCCParser.VarDeclContext):
        pass

    # Exit a parse tree produced by FCCParser#varDecl.
    def exitVarDecl(self, ctx:FCCParser.VarDeclContext):
        pass


    # Enter a parse tree produced by FCCParser#variableDeclaratorList.
    def enterVariableDeclaratorList(self, ctx:FCCParser.VariableDeclaratorListContext):
        pass

    # Exit a parse tree produced by FCCParser#variableDeclaratorList.
    def exitVariableDeclaratorList(self, ctx:FCCParser.VariableDeclaratorListContext):
        pass


    # Enter a parse tree produced by FCCParser#variableDeclarator.
    def enterVariableDeclarator(self, ctx:FCCParser.VariableDeclaratorContext):
        pass

    # Exit a parse tree produced by FCCParser#variableDeclarator.
    def exitVariableDeclarator(self, ctx:FCCParser.VariableDeclaratorContext):
        pass


    # Enter a parse tree produced by FCCParser#initializer.
    def enterInitializer(self, ctx:FCCParser.InitializerContext):
        pass

    # Exit a parse tree produced by FCCParser#initializer.
    def exitInitializer(self, ctx:FCCParser.InitializerContext):
        pass


    # Enter a parse tree produced by FCCParser#assignmentStmt.
    def enterAssignmentStmt(self, ctx:FCCParser.AssignmentStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#assignmentStmt.
    def exitAssignmentStmt(self, ctx:FCCParser.AssignmentStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#assignment.
    def enterAssignment(self, ctx:FCCParser.AssignmentContext):
        pass

    # Exit a parse tree produced by FCCParser#assignment.
    def exitAssignment(self, ctx:FCCParser.AssignmentContext):
        pass


    # Enter a parse tree produced by FCCParser#assignmentOperator.
    def enterAssignmentOperator(self, ctx:FCCParser.AssignmentOperatorContext):
        pass

    # Exit a parse tree produced by FCCParser#assignmentOperator.
    def exitAssignmentOperator(self, ctx:FCCParser.AssignmentOperatorContext):
        pass


    # Enter a parse tree produced by FCCParser#assignable.
    def enterAssignable(self, ctx:FCCParser.AssignableContext):
        pass

    # Exit a parse tree produced by FCCParser#assignable.
    def exitAssignable(self, ctx:FCCParser.AssignableContext):
        pass


    # Enter a parse tree produced by FCCParser#returnStmt.
    def enterReturnStmt(self, ctx:FCCParser.ReturnStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#returnStmt.
    def exitReturnStmt(self, ctx:FCCParser.ReturnStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#continueStmt.
    def enterContinueStmt(self, ctx:FCCParser.ContinueStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#continueStmt.
    def exitContinueStmt(self, ctx:FCCParser.ContinueStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#breakStmt.
    def enterBreakStmt(self, ctx:FCCParser.BreakStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#breakStmt.
    def exitBreakStmt(self, ctx:FCCParser.BreakStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#exprStmt.
    def enterExprStmt(self, ctx:FCCParser.ExprStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#exprStmt.
    def exitExprStmt(self, ctx:FCCParser.ExprStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#ifStmt.
    def enterIfStmt(self, ctx:FCCParser.IfStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#ifStmt.
    def exitIfStmt(self, ctx:FCCParser.IfStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#elifBranch.
    def enterElifBranch(self, ctx:FCCParser.ElifBranchContext):
        pass

    # Exit a parse tree produced by FCCParser#elifBranch.
    def exitElifBranch(self, ctx:FCCParser.ElifBranchContext):
        pass


    # Enter a parse tree produced by FCCParser#elseBranch.
    def enterElseBranch(self, ctx:FCCParser.ElseBranchContext):
        pass

    # Exit a parse tree produced by FCCParser#elseBranch.
    def exitElseBranch(self, ctx:FCCParser.ElseBranchContext):
        pass


    # Enter a parse tree produced by FCCParser#whileStmt.
    def enterWhileStmt(self, ctx:FCCParser.WhileStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#whileStmt.
    def exitWhileStmt(self, ctx:FCCParser.WhileStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#forStmt.
    def enterForStmt(self, ctx:FCCParser.ForStmtContext):
        pass

    # Exit a parse tree produced by FCCParser#forStmt.
    def exitForStmt(self, ctx:FCCParser.ForStmtContext):
        pass


    # Enter a parse tree produced by FCCParser#forInitializer.
    def enterForInitializer(self, ctx:FCCParser.ForInitializerContext):
        pass

    # Exit a parse tree produced by FCCParser#forInitializer.
    def exitForInitializer(self, ctx:FCCParser.ForInitializerContext):
        pass


    # Enter a parse tree produced by FCCParser#forIncrement.
    def enterForIncrement(self, ctx:FCCParser.ForIncrementContext):
        pass

    # Exit a parse tree produced by FCCParser#forIncrement.
    def exitForIncrement(self, ctx:FCCParser.ForIncrementContext):
        pass


    # Enter a parse tree produced by FCCParser#forCondition.
    def enterForCondition(self, ctx:FCCParser.ForConditionContext):
        pass

    # Exit a parse tree produced by FCCParser#forCondition.
    def exitForCondition(self, ctx:FCCParser.ForConditionContext):
        pass


    # Enter a parse tree produced by FCCParser#varDeclNoSemi.
    def enterVarDeclNoSemi(self, ctx:FCCParser.VarDeclNoSemiContext):
        pass

    # Exit a parse tree produced by FCCParser#varDeclNoSemi.
    def exitVarDeclNoSemi(self, ctx:FCCParser.VarDeclNoSemiContext):
        pass


    # Enter a parse tree produced by FCCParser#expression.
    def enterExpression(self, ctx:FCCParser.ExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#expression.
    def exitExpression(self, ctx:FCCParser.ExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#bitwiseOrExpression.
    def enterBitwiseOrExpression(self, ctx:FCCParser.BitwiseOrExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#bitwiseOrExpression.
    def exitBitwiseOrExpression(self, ctx:FCCParser.BitwiseOrExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#bitwiseXorExpression.
    def enterBitwiseXorExpression(self, ctx:FCCParser.BitwiseXorExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#bitwiseXorExpression.
    def exitBitwiseXorExpression(self, ctx:FCCParser.BitwiseXorExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#bitwiseAndExpression.
    def enterBitwiseAndExpression(self, ctx:FCCParser.BitwiseAndExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#bitwiseAndExpression.
    def exitBitwiseAndExpression(self, ctx:FCCParser.BitwiseAndExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#equalityExpression.
    def enterEqualityExpression(self, ctx:FCCParser.EqualityExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#equalityExpression.
    def exitEqualityExpression(self, ctx:FCCParser.EqualityExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#relationalExpression.
    def enterRelationalExpression(self, ctx:FCCParser.RelationalExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#relationalExpression.
    def exitRelationalExpression(self, ctx:FCCParser.RelationalExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#shiftExpression.
    def enterShiftExpression(self, ctx:FCCParser.ShiftExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#shiftExpression.
    def exitShiftExpression(self, ctx:FCCParser.ShiftExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#additiveExpression.
    def enterAdditiveExpression(self, ctx:FCCParser.AdditiveExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#additiveExpression.
    def exitAdditiveExpression(self, ctx:FCCParser.AdditiveExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#multiplicativeExpression.
    def enterMultiplicativeExpression(self, ctx:FCCParser.MultiplicativeExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#multiplicativeExpression.
    def exitMultiplicativeExpression(self, ctx:FCCParser.MultiplicativeExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#unaryExpression.
    def enterUnaryExpression(self, ctx:FCCParser.UnaryExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#unaryExpression.
    def exitUnaryExpression(self, ctx:FCCParser.UnaryExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#postfixExpression.
    def enterPostfixExpression(self, ctx:FCCParser.PostfixExpressionContext):
        pass

    # Exit a parse tree produced by FCCParser#postfixExpression.
    def exitPostfixExpression(self, ctx:FCCParser.PostfixExpressionContext):
        pass


    # Enter a parse tree produced by FCCParser#postfixSuffix.
    def enterPostfixSuffix(self, ctx:FCCParser.PostfixSuffixContext):
        pass

    # Exit a parse tree produced by FCCParser#postfixSuffix.
    def exitPostfixSuffix(self, ctx:FCCParser.PostfixSuffixContext):
        pass


    # Enter a parse tree produced by FCCParser#argumentList.
    def enterArgumentList(self, ctx:FCCParser.ArgumentListContext):
        pass

    # Exit a parse tree produced by FCCParser#argumentList.
    def exitArgumentList(self, ctx:FCCParser.ArgumentListContext):
        pass


    # Enter a parse tree produced by FCCParser#primary.
    def enterPrimary(self, ctx:FCCParser.PrimaryContext):
        pass

    # Exit a parse tree produced by FCCParser#primary.
    def exitPrimary(self, ctx:FCCParser.PrimaryContext):
        pass


    # Enter a parse tree produced by FCCParser#literal.
    def enterLiteral(self, ctx:FCCParser.LiteralContext):
        pass

    # Exit a parse tree produced by FCCParser#literal.
    def exitLiteral(self, ctx:FCCParser.LiteralContext):
        pass



del FCCParser