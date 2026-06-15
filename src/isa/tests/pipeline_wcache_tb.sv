`timescale 1ms / 1ps

module pipeline_wcache_tb ();
    logic clk, rst;

    int cycles = 1000;
    int factor = 500;
    logic [31:0] cycle;
    logic [31:0] pmu_val;

    int i = 0;
    int j = 0;
    int secure_ending_cycles = 100;

    int cache_l1_accesses = 0;
    int cache_l1_misses   = 0;
    int cache_l2_accesses = 0;
    int cache_l2_misses   = 0;
    int total_instr       = 0;
    int total_cycles      = 0;

    // ── Cambio principal: usar 'real' en lugar de 'int' ──
    real miss_rate_l1 = 0.0;
    real miss_rate_l2 = 0.0;
    real amat         = 0.0;
    real ipc          = 0.0;

    always #5 clk = ~clk;
    always_ff @(posedge clk) cycle <= cycle + 1;

    pipeline_wcache _cpu (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        $dumpfile("./gen/pipeline_wcache.vcd");
        $dumpvars(0, pipeline_wcache_tb);

        clk = 0;
        cycle = 0;
        rst = 1;
        #20; rst = 0;

        repeat(5) @(posedge clk);

        while (_cpu.WB_INSTR[31:0] != 32'h1E000080 && i < cycles) begin
            @(posedge clk);
            i++;
        end

        if (_cpu.WB_INSTR[31:0] == 32'h1E000080)
            $display("\n[SISTEMA] Instruccion end encontrada.");

        while (j < secure_ending_cycles) begin
            @(posedge clk);
            j++;
        end

        // --- Volcado final de las memorias ---
        $display("[SISTEMA] Generando archivos de salida corregidos...");

        $writememh("./output/data_mem_exit.hex",  _cpu._packed_mem._mem_dut.RAM);
        $display("[SISTEMA] Archivo para memoria de datos generado exitosamente.");

        $writememh("./output/vault_exit.hex",      _cpu._vault.RAM);
        $display("[SISTEMA] Archivo para boveda generado exitosamente.");

        $writememh("./output/regfile_exit.hex",   _cpu._register_file.regfile_mem);
        $display("[SISTEMA] Archivo para banco de registros generado exitosamente.");

        $writememh("./output/secmem_exit.hex",    _cpu._secure_memory.mem);
        $display("[SISTEMA] Archivo para memoria segura generado exitosamente.");

        $display("\n--- Reporte de Desempeño (PMU) ---");

        // ── Cache L1 ──
        $display("\n--- Cache L1 ---");

        force _cpu._pmu.read_addr = 5'd8; @(posedge clk); #1;
        pmu_val           = _cpu._pmu.read_data;
        cache_l1_accesses = int'(_cpu._pmu.read_data);
        $display("Total L1 Accesses         : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd2; @(posedge clk); #1;
        pmu_val         = _cpu._pmu.read_data;
        cache_l1_misses = int'(_cpu._pmu.read_data);
        $display("Total L1 Misses           : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd3; @(posedge clk); #1;
        pmu_val = _cpu._pmu.read_data;
        $display("L1 Miss Read              : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd4; @(posedge clk); #1;
        pmu_val = _cpu._pmu.read_data;
        $display("L1 Miss Write             : %0d", pmu_val);

        // División en punto flotante
        if (cache_l1_accesses > 0)
            miss_rate_l1 = real'(cache_l1_misses) / real'(cache_l1_accesses);
        else
            miss_rate_l1 = 0.0;

        $display("Hit Rate L1               : %.4f", 1 - miss_rate_l1);
        $display("Miss Rate L1              : %.4f", miss_rate_l1);

        // ── Cache L2 ──
        $display("\n--- Cache L2 ---");

        force _cpu._pmu.read_addr = 5'd9; @(posedge clk); #1; #10;
        pmu_val           = _cpu._pmu.read_data;
        cache_l2_accesses = int'(_cpu._pmu.read_data);
        $display("Total L2 Accesses         : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd5; @(posedge clk); #1; #10;
        pmu_val         = _cpu._pmu.read_data;
        cache_l2_misses = int'(_cpu._pmu.read_data);
        $display("Total L2 Misses           : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd6; @(posedge clk); #1; #10;
        pmu_val = _cpu._pmu.read_data;
        $display("L2 Miss Read              : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd7; @(posedge clk); #1; #10;
        pmu_val = _cpu._pmu.read_data;
        $display("L2 Miss Write             : %0d", pmu_val);

        // División en punto flotante
        if (cache_l2_accesses > 0)
            miss_rate_l2 = real'(cache_l2_misses) / real'(cache_l2_accesses);
        else
            miss_rate_l2 = 0.0;
        $display("Hit Rate L2               : %.4f", 1 - miss_rate_l2);
        $display("Miss Rate L2              : %.4f", miss_rate_l2);

        // ── General ──
        $display("\n--- General ---");

        force _cpu._pmu.read_addr = 5'd1; @(posedge clk); #1;
        pmu_val = _cpu._pmu.read_data;
        $display("Total Misses              : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd0; @(posedge clk); #1;
        pmu_val = _cpu._pmu.read_data - secure_ending_cycles;
        total_cycles = int'(_cpu._pmu.read_data);
        $display("Total Cycles              : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd11; @(posedge clk); #1;
        pmu_val = _cpu._pmu.read_data;
        total_instr = int'(_cpu._pmu.read_data);
        $display("Total Instructions        : %0d", pmu_val);

        ipc = real'(total_instr) / real'(total_cycles);
        $display("IPC                       : %0.3f", ipc);

        force _cpu._pmu.read_addr = 5'd12; @(posedge clk); #1;
        pmu_val = _cpu._pmu.read_data;
        $display("Total Stalls for control  : %0d", pmu_val);

        force _cpu._pmu.read_addr = 5'd10; @(posedge clk); #1;
        pmu_val = _cpu._pmu.read_data;
        $display("Total Memory Accesses     : %0d", pmu_val);

        // AMAT en punto flotante
        amat = real'(_cpu._packed_mem.L1_LATENCY)
             + miss_rate_l1 * (real'(_cpu._packed_mem.L2_LATENCY)
             + miss_rate_l2 *  real'(_cpu._packed_mem.MEM_LATENCY));
        $display("AMAT                      : %.4f", amat);

        release _cpu._pmu.read_addr;

        $display("----------------------------------");
        $display("[Final del testbench]");
        $finish;
    end
endmodule