`timescale 1ns/1ps

module vault_tb;

    logic        CLK, RST, WE;
    logic [31:0] A, WD, RD;
    logic [3:0] ASM;

    vault #(.NUM_WORDS(16)) DUT (.CLK(CLK), .RST(RST),
                                  .A(A), .WE(WE), .ASM(ASM),
                                  .WD(WD), .RD(RD));

    // Clock 10ns
    always #5 CLK = ~CLK;

    task automatic check(input string name, input logic [31:0] exp);
        #1;
        if (RD === exp)
            $display("[PASS] %s | RD=%h", name, RD);
        else
            $display("[FAIL] %s | got=%h  exp=%h", name, RD, exp);
    endtask

    initial begin
        $dumpfile("./output/wave.vcd");   // nombre del archivo
        $dumpvars(0, vault_tb);         // qué señales guardar
        CLK = 0; RST = 0; WE = 0;
        A = 0; WD = 0; ASM = 4'b0000;
        @(posedge CLK); #1;
        RST = 0;

        // -----------------------------------------------
        // LW (ASM=0000) — leer palabras completas
        // -----------------------------------------------
        $display("--- LW ---");
        
        task_read(32'h00000000, 4'b1111); check("LW RAM[0]",  32'hAABBCCDD);
        task_read(32'h00000004, 4'b1111); check("LW RAM[1]",  32'h0000000A);
        task_read(32'h00000008, 4'b1111); check("LW RAM[2]",  32'hCAFEBABE);
        task_read(32'h0000003C, 4'b1111); check("LW RAM[15]", 32'h0000000D);

        // -----------------------------------------------
        // LB (ASM=0001) — leer byte por offset
        // -----------------------------------------------
        $display("--- LB ---");

        // RAM[0] = 0xAABBCCDD
        task_read(32'h00000000, 4'b0001); check("LB RAM[0] byte0", 32'h000000DD); // [7:0]
        task_read(32'h00000001, 4'b0001); check("LB RAM[0] byte1", 32'h000000CC); // [15:8]
        task_read(32'h00000002, 4'b0001); check("LB RAM[0] byte2", 32'h000000BB); // [23:16]
        task_read(32'h00000003, 4'b0001); check("LB RAM[0] byte3", 32'h000000AA); // [31:24]


        // -----------------------------------------------
        // LH (ASM=0010) — leer halfword por offset
        // -----------------------------------------------
        $display("--- LH ---");

        // LH — RAM[0] = 0xAABBCCDD
        task_read(32'h00000000, 4'b0011); check("LH RAM[0] low",  32'h0000CCDD); // [15:0]
        task_read(32'h00000002, 4'b0011); check("LH RAM[0] high", 32'h0000AABB); // [31:16]

        // -----------------------------------------------
        // SW — escribir y leer de vuelta
        // -----------------------------------------------
        $display("--- SW ---");
        // Escribir 0x12345678 en RAM[5] (A=0x14)
        task_write(32'h00000014, 32'h12345678, 4'b1111);
        @(posedge CLK); #1;
        task_read(32'h00000014, 4'b1111); check("SW RAM[5] full word", 32'h12345678);

        $display("--- SH ---");
        // Escribir solo byte bajo en RAM[6] (A=0x18)
        task_write(32'h0000001C, 32'h1234FAAA, 4'b0011);
        @(posedge CLK); #1;
        task_read(32'h0000001C, 4'b0011); check("SB RAM[7] half word = FAAA", 32'h0000FAAA);

        $display("--- SB ---");
        // Escribir solo byte bajo en RAM[6] (A=0x18)
        task_write(32'h00000018, 32'hAABBCCDD, 4'b0001);
        @(posedge CLK); #1;
        task_read(32'h00000018, 4'b0001); check("SB RAM[6] byte0 = DD", 32'h000000DD);

        // --- 6. GUARDAR RESULTADOS ---
        $display("\n[SISTEMA] Guardando volcado de memoria final...");
        // Asegúrate de que la carpeta ./src/output/ exista físicamente
        $writememh("./output/vault_exit.hex", DUT.RAM);
        
        $display("[SISTEMA] Archivo generado exitosamente.");

        $display("--- FIN ---");
        $finish;
    end

    task task_write(input [31:0] addr, input [31:0] data, input [3:0] mask);
        begin
            @(posedge CLK);
            #1; // Delay crucial: cambiamos señales justo después del flanco
            A = addr;
            WD = data;
            WE = 1;
            ASM = mask;
            @(posedge CLK);
            #1; // Esperamos a que el dato se capture
            WE = 0;
            ASM = 4'b0000;
        end
    endtask

    task task_read(input [31:0] addr, input [3:0] mask);
        begin
            #1; // Fuera de flanco
            A = addr;
            ASM = mask;
            #2; // Tiempo para always_comb
        end
    endtask

endmodule