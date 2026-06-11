module packed_mem_tb ();
    logic clk, rst, ready, re, we;
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
        .RE(re), .WE(we),
        .BM(bm), .A(addr),
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
        we = 0; re = 0;
        clk = 0; rst = 1;
        #10;
        rst = 0;

        // --- Pruebas de lectura ---
        $display("-------------------[Pruebas de lectura]-------------------");
        // 1. Lectura de un dato con miss
        $display("\n Lectura de un dato con miss");
        task_read(32'd4, 4'b1111);
        // 2. Lectura de un dato sin miss
        $display("\n Lectura de un dato sin miss");
        task_read(32'd0, 4'b1111);
        // 3. Lectura desfasada con un miss
        $display("\n Lectura desfasada con miss");
        task_read(32'd6, 4'b1111);
        // 4. Lectura parcial con miss
        $display("\n Lectura parcial con miss");
        task_read(32'd15, 4'b0011);
        // 5. Lectura parcial sin miss
        $display("\n Lectura de un dato sin miss");
        task_read(32'd18, 4'b0111);

        // --- Pruebas de escritura ---
        $display("-------------------[Pruebas de escritura]-------------------");
        // 1. Escritura propagada en todos los niveles (en una direccion que no este en cache)
        $display("\n Escritura propagada a una direccion que no ha sido mapeada");
        task_write(32'd28, 4'b0111, 32'hFFEEBBAA, 20);
        // 2. Escritura propagada en todos los nivles (pero esta en cache)
        $display("\n Escritura propagada a un direccion mapeada");
        task_write(32'd4, 4'b1111, 32'hCACA0000, 20);
        // 3. Escritura adelantada desde el buffer de memoria
        $display("\n Escritura adelantada desde el buffer de memoria");
        task_write(32'd24, 4'b0011, 32'hFFFFFFFF, 1);
        task_read(32'd24, 4'b1111);
        task_read(32'd28, 4'b1111);

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
        int i;
        begin
            $display("+ TASK_READ: A[0x%0d], BM[%b]", address, mask);
            re = 1'b1;
            addr = address;
            bm = mask;
            found = 0; i = 0;
            while (!found) begin
                #10;
                if (ready) $display("[%0d] Data found! RD[%h]", i+1, rd); 
                else $display("[%0d] Looking for data...", i+1);
                found = ready;
                i = i + 1;
            end
            addr = '0;
            bm = 4'b0000;
            re = 1'b0;
        end
    endtask

    task task_write(input [31:0] address, input [3:0] mask, input [31:0] data, input int cycles);
        begin
            $display("+ TASK_WRITE: A[0x%0d], BM[%b], WD[%h]", address, mask, data);
            #5;
            we = 1'b1;
            addr = address;
            bm = mask;
            wd = data;
            for (int i = 0; i < cycles; i++) begin 
                #10;
                if (we) we = 1'b0;
                $display("[%0d] Data is being written...", i+1);
            end
            we = 1'b0;
            addr = '0;
            bm = 4'b0000;
            wd = '0;
            #5;
        end 
    endtask
endmodule