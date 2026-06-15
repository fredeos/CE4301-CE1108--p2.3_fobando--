module packed_mem_tb ();
    logic clk, rst, re, we, halt;
    logic [1:0]  ready;
    logic [3:0]  bm;
    logic [31:0] addr, rd, wd;

    localparam LAT1 = 1;
    localparam LAT2 = 2;
    localparam LAT3 = 4;

    packed_mem #(
        .L1_LATENCY(LAT1), .L2_LATENCY(LAT2), .MEM_LATENCY(LAT3),
        .L1_SIZE(32), .L2_SIZE(64), .MEM_SIZE(256),
        .L1_ASO(2), .L2_ASO(4),
        .WPL(2),
        .L1_MODE(0), .L2_MODE(0),
        .BUF1_SIZE(4), .BUF2_SIZE(4), .BUF3_SIZE(2)
    ) _mem (
        .CLK(clk), .RST(rst),
        .RE(re), .WE(we),
        .BM(bm), .A(addr),
        .WD(wd),
        .RD(rd),
        .ready(ready), .halt(halt)
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
        #5;

        // --- Pruebas de lectura ---
        $display("\n-------------------[Pruebas de lectura]-------------------");
        // 1. Lectura de un dato con miss
        $display("\tLectura de un dato con miss");
        task_read(32'd4, 4'b1111);
        // 2. Lectura de un dato sin miss
        $display("\tLectura de un dato sin miss");
        task_read(32'd0, 4'b1111);
        // 3. Lectura desfasada con un miss
        $display("\tLectura desfasada con miss");
        task_read(32'd6, 4'b1111);
        // 4. Lectura parcial con miss
        $display("\tLectura parcial con miss");
        task_read(32'd15, 4'b0011);
        // 5. Lectura parcial sin miss
        $display("\tLectura parcial sin miss");
        task_read(32'd18, 4'b0111);
        // 6. Lectura con miss forzado para reemplazo de linea
        $display("\tLectura con miss forzado para reemplazo de linea");
        task_read(32'd32, 4'b1111);

        // --- Pruebas de escritura ---
        $display("\n-------------------[Pruebas de escritura]-------------------");
        // 1. Escritura propagada en todos los niveles (en una direccion que no este en cache)
        $display("\tEscritura propagada a una direccion que no ha sido mapeada");
        task_write(32'd28, 4'b0111, 32'hFFEEBBAA, 20);
        // 2. Escritura propagada en todos los nivles (pero esta en cache)
        $display("\tEscritura propagada a una direccion mapeada");
        task_write(32'd4, 4'b1111, 32'hCACA0000, 20); // solo mapeado en L2 y MEM
        task_write(32'd8, 4'b0001, 32'h000000AA, 1); // mapeado en L1, L2 y MEM
        // 3. Escritura adelantada desde el buffer de memoria
        $display("\tEscritura adelantada desde el buffer de memoria");
        task_write(32'd24, 4'b0011, 32'hFFFFFFFF, 1);
        task_read(32'd24, 4'b1111); // aqui el dato aun no se ha esrito (estaria en el buffer)
        task_read(32'd28, 4'b1111); // aqui ya el dato estaria escrito entonces se completa la linea en L1 y L2
        // 4. Sobrecarga de escrituras a memoria principal para llenar el buffer
        $display("\tSobrecarga de escrituras a memoria principal para llenar un buffer");
        task_write(32'd40, 4'b1111, 32'd1, 1);
        task_write(32'd44, 4'b1111, 32'd2, 1);
        task_write(32'd48, 4'b1111, 32'd3, 1);
        task_write(32'd52, 4'b1111, 32'd4, 1);
        task_write(32'd56, 4'b1111, 32'd5, 1);
        task_wait(50);

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
        int i;
        bit found;
        begin
            $display("+ TASK_READ: A[0x%0d], BM[%b]", address, mask);
            re = 1'b1;
            addr = address;
            bm = mask;
            found = 0; i = 0;
            while (!found) begin
                #10;
                if (ready[0]) $display("[%0d] Data found! RD[%h]", i+1, rd); 
                else $display("[%0d] Looking for data...", i+1);
                found = ready[0];
                i = i + 1;
            end
            addr = '0;
            bm = 4'b0000;
            re = 1'b0;
        end
    endtask

    task task_write(input [31:0] address, input [3:0] mask, input [31:0] data, input int cycles);
        int i;
        bit done;
        bit stall;
        begin
            $display("+ TASK_WRITE: A[0x%0d], BM[%b], WD[%h]", address, mask, data);
            we = 1'b1;
            addr = address;
            bm = mask;
            wd = data;
            i = 0; stall = 0; done = 0;
            while (stall || i < cycles || !done) begin
                #10;
                if (ready[1]) begin
                    $display("[%0d] Data write complete!", i+1);
                    we = 1'b0;
                    done = 1'b1;
                end
                else begin 
                    if (halt) $display("[%0d] Writing on memory is halted", i+1);
                    else $display("[%0d] Writing data...", i+1);
                end
                stall = halt;
                i = i + 1;
            end
            we = 1'b0;
            addr = '0;
            bm = 4'b0000;
            wd = '0;
        end 
    endtask

    task task_wait(input int cycles);
    begin 
        for (int i = 0; i < cycles; i++) begin 
            #10;
        end
    end
    endtask
endmodule