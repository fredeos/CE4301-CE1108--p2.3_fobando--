`timescale 1ms / 1ps

module tb_datapath ();
    logic clk, rst;

    int cycles = 120000;
    int factor = 10000;
    logic [31:0] cycle;

    always #5 clk = ~clk;
    always_ff @(posedge clk) cycle <= cycle + 1;

    datapath _cpu (
        .clk(clk), 
        .rst(rst)
    );

    initial begin 
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, tb_datapath);
        $display("[Inicio del testbench]");
        if ($value$plusargs("CYCLES=%d", cycles)) begin
            $display("[SISTEMA] Ciclos configurados por plusarg: %0d", cycles);
        end else begin
            $display("[SISTEMA] Ciclos por defecto: %0d", cycles);
        end

        // Inicializar el procesdor
        cycle = '0;
        clk = 1;
        rst = 1;
        #5; rst = 0; #5;

        // Ejecutar cantidad de ciclos deseada
        for (int i = 1; i < cycles; i++) begin 
            #10;
            if ((i % factor) == 0) begin
                $display("Ciclo [%0d]", i);
            end
        end

        // --- Volcado final de las memorias ---
        $display("\n[SISTEMA] Generando archivos de salida corregidos...");

        $writememh("./output/data_mem_exit.hex", _cpu._ram.RAM);
        $display("[SISTEMA] Archivo para memoria de datos generado exitosamente.");

        $writememh("./output/vault_exit.hex", _cpu._vault.RAM);
        $display("[SISTEMA] Archivo para boveda generado exitosamente.");

        $writememh("./output/regfile_exit.hex", _cpu._register_file.regfile_mem);
        $display("[SISTEMA] Archivo para banco de registros generado exitosamente.");

        $writememh("./output/secmem_exit.hex", _cpu._secure_memory.mem);
        $display("[SISTEMA] Archivo para memoria segura generado exitosamente.");

        $display("[Final del testbench]");
        $finish;
    end
endmodule
