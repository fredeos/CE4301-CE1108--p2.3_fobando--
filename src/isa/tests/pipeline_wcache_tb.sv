`timescale 1ms / 1ps

module pipeline_wcache_tb ();
    logic clk, rst;

    int cycles = 1000;
    int factor = 500;
    logic [31:0] cycle;
    logic [31:0] pmu_val;

    always #5 clk = ~clk;
    always_ff @(posedge clk) cycle <= cycle + 1;

    // Asegúrate de que el módulo instanciado sea el correcto
    pipeline_wcache _cpu (
        .clk(clk), 
        .rst(rst)
    );

    initial begin 
       // 1. Asegurar que las carpetas existan (debes hacerlo en la terminal: mkdir -p gen output)
        $dumpfile("./gen/pipeline.vcd");
        
        // 2. IMPORTANTE: Indicar explícitamente el módulo raíz
        $dumpvars(0, pipeline_wcache_tb); 
        
        $display("[Inicio del testbench]");
        
        // 3. Inicialización correcta
        clk = 0; 
        cycle = '0;
        rst = 1;
        #10; rst = 0;

        for (int i = 1; i < cycles; i++) begin 
            #10;

            // --- DEBUG PMU: ver comportamiento de write_miss durante STOREs ---
            if (_cpu.MEM_INSTR[5:1] == 5'b00101) begin
                $display("Ciclo %0d: STORE addr=0x%08h | WE=%b | write_miss[0]=%b | ready=%b | state=%b",
                    i,
                    _cpu.MEM_ALUOut,
                    _cpu._packed_mem.WE,         // write enable que llega a packed_mem
                    _cpu._packed_mem.write_miss[0], // L1 write miss
                    _cpu._packed_mem.ready,
                    _cpu._packed_mem.state       // estado de la FSM
                );
            end
            
            if ((i % factor) == 0) $display("Ciclo [%0d]", i);
        end

        // --- Volcado final de las memorias ---
        $display("\n[SISTEMA] Generando archivos de salida corregidos...");

        $writememh("./output/data_mem_exit.hex", _cpu._packed_mem._mem_dut.RAM);
        $display("[SISTEMA] Archivo para memoria de datos generado exitosamente.");

        $writememh("./output/vault_exit.hex", _cpu._vault.RAM);
        $display("[SISTEMA] Archivo para boveda generado exitosamente.");

        $writememh("./output/regfile_exit.hex", _cpu._register_file.regfile_mem);
        $display("[SISTEMA] Archivo para banco de registros generado exitosamente.");

        $writememh("./output/secmem_exit.hex", _cpu._secure_memory.mem);
        $display("[SISTEMA] Archivo para memoria segura generado exitosamente.");

        $display("\n--- Reporte de Desempeño (PMU) ---");


        force _cpu._pmu.read_addr = 5'd0; #10; pmu_val = _cpu._pmu.read_data;
        $display("Total Cycles  : %0d", pmu_val);
        
        force _cpu._pmu.read_addr = 5'd1; #10; pmu_val = _cpu._pmu.read_data;
        $display("Total Misses  : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd2; #10; pmu_val = _cpu._pmu.read_data;
        $display("Total L1 Misses : %0d", pmu_val);
        
        force _cpu._pmu.read_addr = 5'd3; #10; pmu_val = _cpu._pmu.read_data;
        $display("L1 Miss Read  : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd4; #10; pmu_val = _cpu._pmu.read_data;
        $display("L1 Miss Write  : %0d", pmu_val);
        
        force _cpu._pmu.read_addr = 5'd5; #10; pmu_val = _cpu._pmu.read_data;
        $display("Total L2 Misses : %0d", pmu_val);
        
        force _cpu._pmu.read_addr = 5'd6; #10; pmu_val = _cpu._pmu.read_data;
        $display("L2 Miss Read  : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd7; #10; pmu_val = _cpu._pmu.read_data;
        $display("L2 Miss Write  : %0d", pmu_val);

        // Liberamos el force para devolver el control al diseño normal
        release _cpu._pmu.read_addr;

        $display("Ciclos Totales: %0d", cycle);
        $display("----------------------------------");
        $display("[Final del testbench]");
        $finish;
    end
endmodule