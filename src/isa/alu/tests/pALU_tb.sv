`timescale 1ns/1ps
 
module pALU_tb;
 
    // -------------------------------------------------------------------------
    // Parámetros
    // -------------------------------------------------------------------------
    localparam WIDTH = 32;
 
    // Opcodes
    localparam OP_SLL = 4'b0000;
    localparam OP_SRL = 4'b0001;
    localparam OP_ADD = 4'b0010;
    localparam OP_SUB = 4'b0011;
    localparam OP_MUL = 4'b0100;
    localparam OP_DIV = 4'b0101;
    localparam OP_MOD = 4'b0110;
    localparam OP_AND = 4'b0111;
    localparam OP_OR  = 4'b1000;
    localparam OP_XOR = 4'b1001;
    localparam OP_SEQ = 4'b1010;
 
    // Valores para probar signed
    localparam signed [WIDTH-1:0] MAX_POS =  (1 << (WIDTH-1)) - 1; // 0x7FFF_FFFF
    localparam signed [WIDTH-1:0] MIN_NEG = -(1 << (WIDTH-1));     // 0x8000_0000
    localparam signed [WIDTH-1:0] NEG_ONE = -1;
 
    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] A, B, Y;
    logic [3:0]       op;
    logic [3:0]       flags;
 
    // Flags desempaquetadas
    logic N, Z, C, V;
    assign {N, Z, C, V} = flags;
 
    pALU #(.WIDTH(WIDTH)) DUT (.A(A),
                               .B(B),
                               .Y(Y),
                               .op(op),
                               .flags(flags));
 
    // ---- Tarea de verificación ---
    task automatic check(
        input string         test_name,
        input logic [WIDTH-1:0] exp_Y,
        input logic          exp_N, exp_Z, exp_C, exp_V
    );
        // ops lógicas y de shift: SLL, SRL, AND, OR, XOR, SEQ
        logic is_logical;
        is_logical = (op == OP_SLL || op == OP_SRL ||
                    op == OP_AND || op == OP_OR  ||
                    op == OP_XOR || op == OP_SEQ);

        #1;
        if (Y === exp_Y && N === exp_N && Z === exp_Z && C === exp_C && V === exp_V) begin
            $display("[PASS] %s", test_name);
            if (is_logical)
                $display("       A=%h B=%h op=%b | Y=%h (N=%b Z=%b C=%b V=%b)",
                        A, B, op, Y, N, Z, C, V);
            else
                $display("       A=%0d B=%0d op=%b | Y=%0d (N=%b Z=%b C=%b V=%b)",
                        $signed(A), $signed(B), op, $signed(Y), N, Z, C, V);
        end else begin
            $display("[FAIL] %s", test_name);
            if (is_logical)
                $display("       A=%h B=%h op=%b", A, B, op);
            else
                $display("       A=%0d B=%0d op=%b", $signed(A), $signed(B), op);

            if (Y !== exp_Y) begin
                if (is_logical)
                    $display("       Y:  got=%h  exp=%h", Y, exp_Y);
                else
                    $display("       Y:  got=%0d  exp=%0d  [hex: got=%h exp=%h]",
                            $signed(Y), $signed(exp_Y), Y, exp_Y);
            end
            if (N !== exp_N) $display("       N:  got=%b  exp=%b", N, exp_N);
            if (Z !== exp_Z) $display("       Z:  got=%b  exp=%b", Z, exp_Z);
            if (C !== exp_C) $display("       C:  got=%b  exp=%b", C, exp_C);
            if (V !== exp_V) $display("       V:  got=%b  exp=%b", V, exp_V);
        end
        $display("");
    endtask
 
    // -------------------- TESTS --------------------------
    initial begin
        $dumpfile("palu.vcd");   // nombre del archivo
        $dumpvars(0, pALU_tb);         // qué señales guardar
        $display(" TB pALU - WIDTH=%0d", WIDTH);
 
        // SLL — Shift Left Logical
        $display("--- SLL ---");
        op = OP_SLL;
 
        A = 32'h0000_0001; B = 32'd4;
        check("SLL: 1 << 4 = 16", 32'd16, 0, 0, 0, 0);
 
        A = 32'h8000_0001; B = 32'd1;
        check("SLL: 0x80000001 << 1 = 2 (MSB desplazado)", 32'h0000_0002, 0, 0, 0, 0);
 
        A = 32'hFFFF_FFFF; B = 32'd0;
        check("SLL: shift by 0 = mismo valor", 32'hFFFF_FFFF, 1, 0, 0, 0);
 
        A = 32'h0000_0001; B = 32'd31;
        check("SLL: 1 << 31 = 0x80000000 (N=1)", 32'h8000_0000, 1, 0, 0, 0);
 
        // =================================================================
        // SRL — Shift Right Logical
        // =================================================================
        $display("--- SRL ---");
        op = OP_SRL;
 
        A = 32'h8000_0000; B = 32'd1;
        check("SRL: 0x80000000 >> 1 = 0x40000000 (lógico, rellena con 0)", 32'h4000_0000, 0, 0, 0, 0);
 
        A = 32'h0000_00FF; B = 32'd4;
        check("SRL: 255 >> 4 = 15", 32'd15, 0, 0, 0, 0);
 
        A = 32'hFFFF_FFFF; B = 32'd31;
        check("SRL: 0xFFFFFFFF >> 31 = 1", 32'd1, 0, 0, 0, 0);

        // ADD
        $display("--- ADD ---");
        op = OP_ADD;
 
        A = 32'd10; B = 32'd20;
        check("ADD: 10+20=30", 32'd30, 0, 0, 0, 0);
 
        A = 32'd0; B = 32'd0;
        check("ADD: 0+0=0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
        // Overflow positivo: MAX_POS + 1 → negativo
        A = MAX_POS; B = 32'd1;
        check("ADD: MAX_POS+1 overflow (V=1,N=1)", MIN_NEG, 1, 0, 0, 1);
 
        // Overflow negativo: MIN_NEG + (-1) → positivo
        A = MIN_NEG; B = NEG_ONE;
        check("ADD: MIN_NEG+(-1) overflow (V=1)", MAX_POS, 0, 0, 1, 1);
 
        // Carry: 0xFFFFFFFF + 1 → C=1, Y=0
        A = 32'hFFFF_FFFF; B = 32'd1;
        check("ADD: 0xFFFFFFFF+1 carry (C=1, Z=1)", 32'd0, 0, 1, 1, 0);
 
        // Normal negativo
        A = -32'd5; B = -32'd3;
        check("ADD: (-5)+(-3)=-8", -32'd8, 1, 0, 1, 0);

        // SUB
        $display("--- SUB ---");
        op = OP_SUB;
 
        A = 32'd30; B = 32'd10;
        check("SUB: 30-10=20", 32'd20, 0, 0, 0, 0);
 
        A = 32'd5; B = 32'd5;
        check("SUB: 5-5=0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
        // Borrow: A < B (unsigned)
        A = 32'd3; B = 32'd10;
        check("SUB: 3-10=-7 (C=1/borrow, N=1)", -32'd7, 1, 0, 1, 0);
 
        // MIN_NEG - 1: no borrow porque 0x80000000 > 0x00000001
        A = MIN_NEG; B = 32'd1;
        check("SUB: MIN_NEG-1 overflow (V=1)", MAX_POS, 0, 0, 0/*C=0*/, 1);

        // MAX_POS - (-1): hay borrow porque 0x7FFFFFFF < 0xFFFFFFFF
        A = MAX_POS; B = NEG_ONE;
        check("SUB: MAX_POS-(-1) overflow (V=1,N=1)", MIN_NEG, 1, 0, 1/*C=1*/, 1);
 
        // MUL
        $display("--- MUL ---");
        op = OP_MUL;
 
        A = 32'd6; B = 32'd7;
        check("MUL: 6*7=42", 32'd42, 0, 0, 0, 0);
 
        A = -32'd6; B = 32'd7;
        check("MUL: (-6)*7=-42", -32'd42, 1, 0, 0, 0);
 
        A = -32'd6; B = -32'd7;
        check("MUL: (-6)*(-7)=42", 32'd42, 0, 0, 0, 0);
 
        A = 32'd0; B = 32'd9999;
        check("MUL: 0*9999=0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
        // Truncamiento: resultado > 32 bits
        A = 32'h0001_0000; B = 32'h0001_0000; // 65536 * 65536 = 2^32 → truncado a 0
        check("MUL: 65536*65536 truncado a 0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
        // DIV
        $display("--- DIV ---");
        op = OP_DIV;
 
        A = 32'd42; B = 32'd6;
        check("DIV: 42/6=7", 32'd7, 0, 0, 0, 0);
 
        A = -32'd42; B = 32'd6;
        check("DIV: (-42)/6=-7", -32'd7, 1, 0, 0, 0);
 
        A = -32'd42; B = -32'd6;
        check("DIV: (-42)/(-6)=7", 32'd7, 0, 0, 0, 0);
 
        A = 32'd10; B = 32'd3;
        check("DIV: 10/3=3 (truncado hacia 0)", 32'd3, 0, 0, 0, 0);
 
        // División por cero → 0
        A = 32'd100; B = 32'd0;
        check("DIV: 100/0=0 (div by zero)", 32'd0, 0, 1, 0, 0);
 
        // MOD
        $display("--- MOD ---");
        op = OP_MOD;
 
        A = 32'd10; B = 32'd3;
        check("MOD: 10%3=1", 32'd1, 0, 0, 0, 0);
 
        A = -32'd10; B = 32'd3;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
        check("MOD: (-10)%3=-1", -32'd1, 1, 0, 0, 0);
 
        A = 32'd9; B = 32'd3;
        check("MOD: 9%3=0 (Z=1)", 32'd0, 0, 1, 0, 0);

        A = 32'd3; B = 32'd5;
        check("MOD: 3%5=0", 32'd3, 0, 0, 0, 0);
 
        // Módulo por cero → 0
        A = 32'd10; B = 32'd0;
        check("MOD: 10%0=0 (mod by zero)", 32'd0, 0, 1, 0, 0);
 
        // AND
        $display("--- AND ---");
        op = OP_AND;
 
        A = 32'hFF00_FF00; B = 32'h0FF0_0FF0;
        check("AND: 0xFF00FF00 & 0x0FF00FF0", 32'h0F00_0F00, 0, 0, 0, 0);
 
        A = 32'hFFFF_FFFF; B = 32'h0000_0000;
        check("AND: all-ones & all-zeros = 0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
        A = 32'hFFFF_FFFF; B = 32'hFFFF_FFFF;
        check("AND: all-ones & all-ones = 0xFFFFFFFF (N=1)", 32'hFFFF_FFFF, 1, 0, 0, 0);
 
        // OR
        $display("--- OR ---");
        op = OP_OR;
 
        A = 32'hFF00_0000; B = 32'h00FF_FFFF;
        check("OR: 0xFF000000 | 0x00FFFFFF = 0xFFFFFFFF (N=1)", 32'hFFFF_FFFF, 1, 0, 0, 0);
 
        A = 32'd0; B = 32'd0;
        check("OR: 0|0=0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
        // XOR
        $display("--- XOR ---");
        op = OP_XOR;
 
        A = 32'hAAAA_AAAA; B = 32'h5555_5555;
        check("XOR: 0xAAAAAAAA ^ 0x55555555 = 0xFFFFFFFF (N=1)", 32'hFFFF_FFFF, 1, 0, 0, 0);
 
        A = 32'hDAAD_FEAB; B = 32'hDAAD_FEAB;
        check("XOR: X^X=0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
        // SEQ
        $display("--- SEQ ---");
        op = OP_SEQ;
 
        A = 32'd42; B = 32'd42;
        check("SEQ: 42==42 -> Y=1", 32'd1, 0, 0, 0, 0);
 
        A = 32'd42; B = 32'd43;
        check("SEQ: 42==43 -> Y=0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
        A = NEG_ONE; B = NEG_ONE;
        check("SEQ: -1==-1 -> Y=1", 32'd1, 0, 0, 0, 0);
 
        // =================================================================
        // Opcode por defecto
        // =================================================================
        $display("--- DEFAULT ---");
        op = 4'b1111;
        A = 32'hDEAD_BEEF; B = 32'hCAFE_BABE;
        check("DEFAULT: op invalido -> Y=0 (Z=1)", 32'd0, 0, 1, 0, 0);
 
 
        $finish;
    end
 
endmodule