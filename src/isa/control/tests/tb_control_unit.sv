module tb_control_unit ();
    localparam N = 16;
    logic [31:0] instructions [N-1:0];
    logic [31:0] instr;

    logic [7:0] MemBytes;
    logic [4:0] Branch, ALUControl;
    logic [2:0] ImmSel;
    logic [1:0] MemToReg, RegWrite, MemWrite, Session, ALUSrcA, RSel;
    logic ALUSel, ALUSrcB, RegSrc, SecSrc;

    logic clk;
    always #5 clk = ~clk;

    control_unit _control_unit (
        .opcode(instr[5:1]),
        .func4(instr[9:6]),
        .source(instr[31:10]),
        .MemToReg(MemToReg),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite), .MemBytes(MemBytes),
        .Branch(Branch),
        .Session(Session),
        .ALUSel(ALUSel), .ALUControl(ALUControl), .ALUSrcB(ALUSrcB), .ALUSrcA(ALUSrcA), 
        .RSel(RSel),
        .ImmSel(ImmSel),
        .RegSrc(RegSrc),
        .SecSrc(SecSrc)
    );

    // Testbench
    initial begin 
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, tb_control_unit);

        clk = 0;
        // Configurar instrucciones en la memoria
        instructions[0] = 32'h00000080; // nop
        instructions[1] = 32'h01181480; // add p0, r2, r3
        instructions[2] = 32'h00708d03; // @muli pc, ra, 7
        instructions[3] = 32'hff59f110; // blt r5, r7, -4
        instructions[4] = 32'h003138c8; // ldb r0,- 3(sp)
        instructions[5] = 32'h00414e0a; // stw r5,+ 4(sp)
        instructions[6] = 32'h000006d2; // jal ra, 11
        instructions[7] = 32'hbeef0022; // login 0xBEEF0
        instructions[8] = 32'h00000062; // quit
        instructions[9] = 32'h00022144; // pdiv  ax, bx, cx
        instructions[10] = 32'h00061406;// pslli fx, ax, 6
        instructions[11] = 32'h0051A085;// @paddxor ax, fx, bx, cx
        instructions[12] = 32'hfffe650c;// ldvh bx,+ -2(dx)
        instructions[13] = 32'hfffb68ce;// stvb cx,- -5(dx)
        instructions[14] = 32'h00088820;// send cx, r3
        instructions[15] = 32'h00053860;// recv r0, fx

        // Iteracion sobre las instrucciones
        $display("[Inicio del testbench]");
        for (int i = 0; i < N; i++) begin
            instr = instructions[i];
            #10;
            $display("-----------------------[INSTR[%0d]:0x%h]-----------------------", i, instr);
            $display("MemToReg(WB mux) = %b", MemToReg);
            $display("RegFile WE = %b", RegWrite[1]);
            $display("SecMem WE = %b", RegWrite[0]);
            $display("Data Memory: WE = %b, Bytes = %b", MemWrite[1], MemBytes[7:4]);
            $display("Vault: WE = %b, Bytes = %b", MemWrite[0], MemBytes[3:0]);
            $display("Branch: cond = %b, pcmod = %b, binstr = %b", Branch[4:2], Branch[1], Branch[0]);
            $display("Session: login = %b, logout = %b", Session[0], Session[1]);
            $display("ALU selection: %b", ALUSel);
            $display("Primary ALU operation: %b", ALUControl[3:0]);
            $display("Secondary ALU operation: %b", ALUControl[4]);
            $display("ALUSrcA = %b, ALUSrcB = %b", ALUSrcA, ALUSrcB);
            $display("R1Sel = %b, R2Sel = %b", RSel[0], RSel[1]);
            $display("RegSrc (rm/rd swap mux) = %b", RegSrc);
            $display("SecSec (sm/sd swap mux) = %b", SecSrc);
            $display("Imm Ext op = %b", ImmSel);
        end
        $display("[Final del testbench]");
        $finish;
    end

endmodule