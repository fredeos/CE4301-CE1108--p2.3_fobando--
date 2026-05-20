`timescale 1ns / 1ps

module data_memory_tb();

    // Parámetros
    localparam int MEM_SIZE_KB = 1; 
    
    // Señales del DUT
    logic        CLK;
    logic        RST;
    logic [31:0] A;
    logic        WE;
    logic [3:0]  ASM;
    logic [31:0] WD;
    logic [31:0] RD;

    // Instancia del módulo (DUT)
    data_memory #(
        .MEM_SIZE_KB(MEM_SIZE_KB)
    ) dut (
        .CLK(CLK), .RST(RST), .A(A), .WE(WE), .ASM(ASM), .WD(WD), .RD(RD)
    );

    // Reloj a 100MHz
    always #5 CLK = (CLK === 1'b0);

    initial begin
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, data_memory_tb);
        // --- 1. Reset y Estabilización ---
        CLK = 0;
        RST = 1;
        A = 0; WE = 0; ASM = 0; WD = 0;
        #20 RST = 0;
        
        $display("Iniciando Testbench Corregido...");

        // --- 2. TEST 1: Escritura Completa (Word) ---
        // Escribimos en 0x04. Word_idx debería ser 1.
        task_write(32'h00000004, 32'hDEADBEEF, 4'b1111);
        
        // --- 3. TEST 2: Escritura Parcial (Half-word) ---
        // Escribimos en 0x08. Word_idx debería ser 2.
        // Usamos la tarea de Byte Replicado para probar seguridad
        task_write(32'h00000008, 16'hABCD, 4'b0011);

        // --- 4. TEST 3: Escritura Parcial (byte) ---
        // Escribimos en 0x08. Word_idx debería ser 2.
        // Usamos la tarea de Byte Replicado para probar seguridad
        task_write(32'h0000000a, 16'h77, 4'b0001);

        // --- 5. Verificación de Lectura ---
        #10;
        task_read(32'h00000004, 4'b1111);
        $display("[READ] Address 0x04: %h (Expected: DEADBEEF)", RD);
        
        task_read(32'h00000008, 4'b1111);
        $display("[READ] Address 0x08: %h (Expected: 0077ABCD)", RD);

        // --- 6. Volcado Final ---
        #20;
        $display("\n[SISTEMA] Generando archivo de salida corregido...");
        $writememh("./output/data_mem_exit.hex", dut.RAM);
        $display("[SISTEMA] Archivo generado exitosamente.");
        $finish;
    end

    // --- Tareas Corregidas con Delays de Estabilización ---

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

    task EscribirMediaPalabra(input [31:0] addr, input [15:0] data, input [3:0] mask);
        begin
            @(posedge CLK);
            #1;
            A = addr;
            WE = 1;
            ASM = mask;
            WD = {16'h0, data}; // Colocamos la media palabra en la base
            @(posedge CLK);
            #1;
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