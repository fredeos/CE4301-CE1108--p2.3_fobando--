`timescale 1ms / 1ps

module pipeline_wcache_tb ();
    logic clk, rst;

    int cycles = 120000;
    int factor = 10000;
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
        $dumpfile("./gen/pipeline.vcd");
        $dumpvars(0, pipeline_wcache_tb);
        $display("[Inicio del testbench]");
        
        cycle = '0;
        clk = 1;
        rst = 1;
        #5; rst = 0; #5;

        for (int i = 1; i < cycles; i++) begin 
            #10;
            if (_cpu.MEM_INSTR[5:1] == 5'b00100)
                $display("Ciclo %0d: LOAD  addr=0x%08h", i, _cpu.MEM_ALUOut);
            if (_cpu.MEM_INSTR[5:1] == 5'b00101)
                $display("Ciclo %0d: STORE addr=0x%08h", i, _cpu.MEM_ALUOut);
            if ((i % factor) == 0) $display("Ciclo [%0d]", i);
        end

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