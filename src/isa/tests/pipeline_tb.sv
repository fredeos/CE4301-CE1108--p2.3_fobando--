`timescale 1ms / 1ps

module pipeline_tb ();
    logic clk, rst;

    int cycles = 100000;
    int factor = 500;
    logic [31:0] cycle;
    logic [31:0] pmu_val;
    // Declarar 'i' correctamente
    int i = 0;
    int j = 0;
    int secure_ending_cycles = 100;
    int total_instr       = 0;
    int total_cycles      = 0;
    real ipc               = 0;
    int amat = 0;




    always #5 clk = ~clk;
    always_ff @(posedge clk) cycle <= cycle + 1;

    // Asegúrate de que el módulo instanciado sea el correcto
    pipeline _cpu (
        .clk(clk), 
        .rst(rst)
    );

    initial begin 
        $dumpfile("./gen/pipeline.vcd");
        $dumpvars(0, pipeline_tb); 
        
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

        $writememh("./output/data_mem_exit.hex", _cpu._ram.RAM);
        $display("[SISTEMA] Archivo para memoria de datos generado exitosamente.");

        //$display("\n--- Reporte de Desempeño (PMU) ---");

        $display("\n--- General ---");

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

        amat = _cpu._ram.LATENCY;
        $display("AMAT  : %0d", amat);



        // // Liberamos el force para devolver el control al diseño normal
        // release _cpu._pmu.read_addr;

        $display("----------------------------------");
        $display("[Final del testbench]");
        $finish;
    end
endmodule