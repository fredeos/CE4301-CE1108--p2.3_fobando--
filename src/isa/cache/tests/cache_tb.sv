module cache_tb ();

    localparam LAT = 2;

    logic clk, rst;
    logic we, re;
    logic w_hit, r_hit, w_ready, r_ready;
    logic [3:0] bm;
    logic [31:0] addr, wd, rd;

    logic queue, dequeue;
    logic [3:0]  wbuff_bm_in, wbuff_bm_out;
    logic [31:0] wbuff_addr_in, wbuff_wd_in, wbuff_addr_out, wbuff_wd_out;

    always #5 clk = ~clk;

    cache #(.SIZE(32), .WPL(2), .WAYS(2), .LATENCY(LAT)) _dut (
        .CLK(clk), .RST(rst),
        .WE(we), .WBM(bm), .WA(addr), .WD(wd),
        .RE(re), .RBM(bm), .RA(addr), .RD(rd),
        .hit({w_hit, r_hit}), .ready({w_ready, r_ready}),
        .queue(queue), .dequeue(),
        .pWBM(wbuff_bm_in), .pWA(wbuff_addr_in), .pWD(wbuff_wd_in)  
    );

    writebuf #(.size(2)) _bin (
        .CLK(clk), .RST(rst),
        .queue(queue), .dequeue(dequeue),
        .addr_in(wbuff_addr_in), .data_in(wbuff_wd_in), .bm_in(wbuff_bm_in),
        .addr_out(wbuff_addr_out), .data_out(wbuff_wd_out), .bm_out(wbuff_bm_out),
        .valid(valid), .hold(hold)
    );

    // --- Estimulación de entradas ---
    initial begin
        $dumpfile("./gen/cache.vcd");
        $dumpvars(0, cache_tb);
        $display("[Inicio del testbench]");

        // --- Inicialización de señales ---
        addr = '0; wd = '0;
        bm  = 4'b0000;
        re = 0; we = 0;
        clk = 0; rst = 1;
        dequeue = 0;
        #10;
        rst = 0;

        // --- Pruebas de lectura ---
        $display("\n-------------------[Pruebas de lectura]-------------------");
        // 1. Lectura de palabra completa
        $display("\n<< Lectura de palabra completa >>");
        task_read(32'd0, 4'b1111);
        // 2. Lectura de media palabra
        $display("\n<< Lectura de media palabra >>");
        task_read(32'd4, 4'b0011);
        // 3. Lectura de byte
        $display("\n<< Lectura de byte >>");
        task_read(32'd6, 4'b0001);
        // 4. Lectura desfasada en mismo bloque
        $display("\n<< Lectura desfasada en mismo bloque >>");
        task_read(32'd2, 4'b1111);
        // 5. Lectura desfasada en bloques distintos
        $display("\n<< Lectura desfasada en bloques distintos >>");
        task_read(32'd7, 4'b0111);
        // 6. Lectura en bloque invalido
        $display("\n<< Lectura en bloque invalido >>");
        task_read(32'd28, 4'b0111);

        // --- Pruebas de escritura ---
        $display("\n-------------------[Pruebas de escritura]-------------------");
        task_check_writebuf(1'b0);
        // 1. Escritura de palabra completa
        $display("\n<< Escritura de palabra completa >>");
        task_write(32'd16, 32'd1024, 4'b1111);
        task_read(32'd16, 4'b1111);
        task_check_writebuf(1'b0);
        // 2. Escritura de media palabra
        $display("\n<< Escritura de media palabra >>");
        task_write(32'd20, 32'hAAAAAAAA, 4'b0011);
        task_read(32'd20, 4'b1111);
        task_check_writebuf(1'b0);
        // 3. Escritura de byte
        $display("\n<< Escritura de byte >>");
        task_write(32'd23, 32'd11, 4'b0001);
        task_read(32'd20, 4'b1111);
        task_check_writebuf(1'b1);
        // 4. Escritura desfasada en mismo bloque
        $display("\n<< Escritura desfasada en mismo bloque>>");
        task_write(32'd18, 32'hFFFF1111, 4'b0111);
        task_read(32'd16, 4'b1111);
        task_read(32'd20, 4'b1111);
        task_check_writebuf(1'b1);
        // 5. Escritura desfasada en bloques distintos
        $display("\n<< Escritura desfasada en bloques distintos >>");
        task_write(32'd6, 32'hdeadbeef, 4'b1111);
        task_read(32'd4, 4'b1111);
        task_read(32'd8, 4'b1111);
        task_check_writebuf(1'b1);
        // 6. Escritura en bloque invalido
        $display("\n<< Escritura en bloque invalido >>");
        task_write(32'd28, 32'd67, 4'b1111);
        task_read(32'd28, 4'b1111);
        task_check_writebuf(1'b1);

        // --- Volcado de memoria ---
        $display("\n[SISTEMA] Generando archivo de salida...");
        $writememh("./output/cache_data_exit.hex", _dut.data);
        $writememh("./output/cache_tags_exit.hex", _dut.tags);
        $display("[Final del testbench]");
        $finish;
    end

    // --- Tareas para interacción con la memoria cache ---
    task task_read(input [31:0] address, input [3:0] mask);
        begin
            $display("+ TASK_READ: A[0x%0d], BM[%b]", address, mask);
            addr = address;
            wd = '0;
            re = 1'b1; we = 1'b0;
            bm = mask;
            for (int i = 0; i < LAT; i++) begin
                #10;
                if (r_hit && r_ready) $display("[%0d] Hit  detected! Content found: %h",i+1, rd);
                else if (!r_hit && r_ready) $display("[%0d] Miss detected! Content was not found",i+1);
                else     $display("[%0d] Cache is still searching...",i+1);
            end
            addr = '0;
            wd = '0;
            re = 1'b0; we = 1'b0;
            bm = 4'b0000;
        end
    endtask
    
    task task_write(input [31:0] address, input [31:0] data, input [3:0] mask);
        begin
            $display("+ TASK_WRITE: A[0x%0d], WD[%h], BM[%b]", address, data, mask);
            #5;
            addr = address;
            wd = data;
            re = 1'b0; we = 1'b1;
            bm = mask;
            for (int i = 0; i < LAT; i++) begin
                #10;
                if (w_hit && w_ready) $display("[%0d] Hit  detected! Content was written correctly",i+1);
                else if (!w_hit && w_ready) $display("[%0d] Miss detected! Content was not written",i+1);
                else     $display("[%0d] Content is being written...",i+1);
            end
            addr = '0;
            wd = '0;
            re = 1'b0; we = 1'b0;
            bm = 4'b0000;
            #5;
        end
    endtask

    task task_check_writebuf(input rm);
        begin 
            $display("+ TASK_CHECK_WRITEBUF: A[0x%0d], WD[%h], ASM[%b], VALID[%b]", wbuff_addr_out, wbuff_wd_out, wbuff_bm_out, valid);
            if (hold) $display("[WRITEBUF: full] Dequeue data");
            else $display("[WRITEBUF: not full] Buffer still has some space");
            dequeue = rm;
            #10;
            dequeue = 1'b0;
        end
    endtask

endmodule