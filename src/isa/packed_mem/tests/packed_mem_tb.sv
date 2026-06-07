module packed_mem_tb ();
    logic clk, rst, ready, we;
    logic [3:0]  bm;
    logic [31:0] addr, rd, wd;

    localparam LAT1 = 1;
    localparam LAT2 = 2;
    localparam LAT3 = 4;

    packed_mem #(
        .L1_LATENCY(LAT1), .L2_LATENCY(LAT2), .MEM_LATENCY(LAT3),
        .L1_SIZE(32), .L2_SIZE(64), .MEM_SIZE(256),
        .L1_ASO(2), .L2_ASO(4),
        .WPL(2)
    ) _mem (
        .CLK(clk), .RST(rst),
        .WE(we), .BM(bm), .A(addr),
        .WD(wd),
        .RD(rd),
        .ready(ready)
    );

    always #5 clk = ~clk;

    // --- Estimulación de entradas ---
    initial begin
        $dumpfile("./gen/packed_mem.vcd");
        $dumpvars(0, packed_mem_tb);
        $display("[Inicio del testbench]");

        // --- Inicializar señales ---
        addr = '0;
        wd = '0;
        bm = 4'b0000;
        we = 0;
        clk = 0; rst = 1;
        #10;
        rst = 0;

        // --- Pruebas de lectura ---
        task_read(32'd0, 4'b1111);
        task_read(32'd4, 4'b1111);

        // --- Volcado de memoria ---
        $display("\n[SISTEMA] Generando archivos de salida...");
        $writememh("./output/cache_l1_data_exit.hex", _mem._l1_dut.data);
        $writememh("./output/cache_l1_tags_exit.hex", _mem._l1_dut.tags);
        $display("[SISTEMA] Archivos de cache L1 generados exitosamente!");
        $writememh("./output/cache_l2_data_exit.hex", _mem._l2_dut.data);
        $writememh("./output/cache_l2_tags_exit.hex", _mem._l2_dut.tags);
        $display("[SISTEMA] Archivos de cache L2 generados exitosamente!");
        $writememh("./output/data_mem_exit.hex", _mem._mem_dut.RAM);
        $display("[SISTEMA] Archivo de memoria de datos generado exitosamente!");
        $display("[Final del testbench]");
        $finish;
    end

    // --- Tareas para interactuar con la memoria ---
    task task_read(input [31:0] address, input [3:0] mask);
        bit found; 
        begin
            $display("+ TASK_READ: A[0x%0d], BM[%b]", address, mask);
            found = 0;
            addr = address;
            bm = mask;
            for (int i = 0; i < LAT1+LAT2+LAT3+5 && !found; i++) begin
                #10;
                if (ready) begin 
                    $display("[%0d] Data found! RD[%h]", i+1, rd); 
                    found = 1;
                end
                else $display("[%0d] Looking for data...", i+1);
            end
            addr = '0;
            bm = 4'b0000;
        end
    endtask
endmodule