module tb_imm_ext ();
    localparam N = 9;
    logic [31:0] instructions [N-1:0];
    logic [31:0] instr;
    logic signed [31:0] imm;
    logic [25:0] source;

    logic [2:0] sel;


    imm_ext32 _imm_ext (
        .source(source),
        .sel(sel),
        .ext(imm)
    );

    initial begin 
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, tb_imm_ext);
        $display("[Inicio del testbench]");

        // 1. Definir conjunto de instrucciones de prueba

        instructions[0] = 32'h00708d03; // @muli pc, ra, 7
        instructions[1] = 32'h003138c8; // ldb r0,- 3(sp)
        instructions[2] = 32'h00414e0a; // stw r5,+ 4(sp)
        instructions[3] = 32'hff59f110; // bge r5, r7, -4
        instructions[4] = 32'h000006d2; // jal ra, 11
        instructions[5] = 32'hbeef0022; // login 0xBEEF0
        instructions[6] = 32'h00061406; // pslli fx, ax, 6
        instructions[7] = 32'hfffe650c; // ldvh bx,+ -2(dx)
        instructions[8] = 32'hfffb68ce; // stvb cx,- -5(dx)

        // 2. Inicializar señales
        instr = 32'b0;
        source = instr[31:6];
        sel = 3'b000;
        #10;

        // 3. Generar pruebas de manera iterativa
        for (int i = 0; i < N; i++) begin 
            instr = instructions[i];
            source = instr[31:6];

            if (i <= 2) sel = 3'b001;
            else if (i == 3) sel = 3'b010;
            else if (i == 4) sel = 3'b011;
            else if (i == 5) sel = 3'b100;
            else if (i >= 6) sel = 3'b101;
            #10;
            $display("------------------[INSTR(%0d)]------------------", i);
            $display("Instruccion = 0x%h", instr);
            $display("Inmediato (32) = %0d", imm);
        end

        $display("[Final del testbench]");
        $finish;
    end

endmodule