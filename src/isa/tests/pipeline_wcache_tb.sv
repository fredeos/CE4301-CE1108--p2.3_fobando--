`timescale 1ms / 1ps

module pipeline_wcache_tb ();
    logic clk, rst;

    int cycles = 1000;
    int factor = 500;
    logic [31:0] cycle;
    logic [31:0] pmu_val;
    // Declarar 'i' correctamente
    int i = 0;
    int j = 0;
    int secure_ending_cycles = 100;


    int cache_l1_accesses = 0;
    int cache_l1_misses = 0;

    int cache_l2_accesses = 0;
    int cache_l2_misses = 0;

    int miss_rate_l1 = 0;
    int miss_rate_l2 = 0;
    int amat = 0;




    always #5 clk = ~clk;
    always_ff @(posedge clk) cycle <= cycle + 1;

    // Asegúrate de que el módulo instanciado sea el correcto
    pipeline_wcache _cpu (
        .clk(clk), 
        .rst(rst)
    );

    initial begin 
        $dumpfile("./gen/pipeline.vcd");
        $dumpvars(0, pipeline_wcache_tb); 
        
        clk = 0; 
        cycle = 0;
        rst = 1;
        #20; rst = 0; // Un poco más de tiempo para el reset

        // Esperar un par de ciclos antes de entrar al while
        repeat(5) @(posedge clk);


        // El while ahora depende de una condición de tiempo y del valor
        while (_cpu.WB_INSTR[31:0] != 32'h1E000080 && i < cycles) begin
            @(posedge clk);
            i++;
        end

        if (_cpu.WB_INSTR[31:0] == 32'h1E000080) begin
             $display("\n[SISTEMA] Instruccion end encontrada.");
        end


        
        // El while ahora depende de una condición de tiempo y del valor
        while (j < secure_ending_cycles) begin
            @(posedge clk);
            j++;
        end


        // --- Volcado final de las memorias ---
        $display("[SISTEMA] Generando archivos de salida corregidos...");

        $writememh("./output/data_mem_exit.hex", _cpu._packed_mem._mem_dut.RAM);
        $display("[SISTEMA] Archivo para memoria de datos generado exitosamente.");

        $writememh("./output/vault_exit.hex", _cpu._vault.RAM);
        $display("[SISTEMA] Archivo para boveda generado exitosamente.");

        $writememh("./output/regfile_exit.hex", _cpu._register_file.regfile_mem);
        $display("[SISTEMA] Archivo para banco de registros generado exitosamente.");

        $writememh("./output/secmem_exit.hex", _cpu._secure_memory.mem);
        $display("[SISTEMA] Archivo para memoria segura generado exitosamente.");

        $display("\n--- Reporte de Desempeño (PMU) ---");

        $display("\n--- Cache L1 ---");

        force _cpu._pmu.read_addr = 5'd8; #10; pmu_val = _cpu._pmu.read_data;
        cache_l1_accesses = _cpu._pmu.read_data;

        $display("Total L1 Accesses : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd2; #10; pmu_val = _cpu._pmu.read_data;
        $display("Total L1 Misses : %0d", pmu_val);
        cache_l1_misses = _cpu._pmu.read_data;
        
        force _cpu._pmu.read_addr = 5'd3; #10; pmu_val = _cpu._pmu.read_data;
        $display("L1 Miss Read  : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd4; #10; pmu_val = _cpu._pmu.read_data;
        $display("L1 Miss Write  : %0d", pmu_val);

        miss_rate_l1 = cache_l1_misses / cache_l1_accesses;
        $display("Miss Rate L1 : %0d", miss_rate_l1);


        $display("\n--- Cache L2 ---");

        force _cpu._pmu.read_addr = 5'd9; #10; pmu_val = _cpu._pmu.read_data;
        $display("Total L2 Accesses : %0d", pmu_val);
        cache_l2_accesses = _cpu._pmu.read_data;
        
        force _cpu._pmu.read_addr = 5'd5; #10; pmu_val = _cpu._pmu.read_data;
        $display("Total L2 Misses : %0d", pmu_val);
        cache_l2_misses = _cpu._pmu.read_data;

        
        force _cpu._pmu.read_addr = 5'd6; #10; pmu_val = _cpu._pmu.read_data;
        $display("L2 Miss Read  : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd7; #10; pmu_val = _cpu._pmu.read_data;
        $display("L2 Miss Write  : %0d", pmu_val);

        miss_rate_l2 = cache_l2_misses / cache_l2_accesses;
        $display("Miss Rate L2 : %0d", miss_rate_l2);

        $display("\n--- General ---");

        force _cpu._pmu.read_addr = 5'd1; #10; pmu_val = _cpu._pmu.read_data;
        $display("Total Misses  : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd0; #10; pmu_val = _cpu._pmu.read_data - secure_ending_cycles;
        $display("Total Cycles  : %0d", pmu_val);

        amat = (_cpu._packed_mem.L1_LATENCY + miss_rate_l1 * (_cpu._packed_mem.L2_LATENCY + miss_rate_l2 * _cpu._packed_mem.MEM_LATENCY));
        $display("AMAT  : %0d", amat);



        // Liberamos el force para devolver el control al diseño normal
        release _cpu._pmu.read_addr;

        $display("----------------------------------");
        $display("[Final del testbench]");
        $finish;
    end
endmodule