module cache_tb ();

    localparam LAT = 2;

    logic clk, rst, hit, finished, we;
    logic [3:0] asm;
    logic [31:0] addr, rd, wd;

    always #5 clk = ~clk;

    cache #(.SIZE(32), .WPL(2), .WAYS(2), .LATENCY(LAT)) _dut (
        .CLK(clk),
        .RST(rst),
        .WE(we),
        .ASM(asm),
        .A(addr),
        .WD(wd),
        .hit(hit),
        .finished(finished),
        .RD(rd)
    );

    // --- Estimulación de entradas ---
    initial begin
        $dumpfile("./gen/cache.vcd");
        $dumpvars(0, cache_tb);
        $display("[Inicio del testbench]");

        // --- Inicialización de señales ---
        addr = '0; wd = '0;
        asm  = 4'b0000;
        clk = 0; rst = 1; we = 0;
        #10;
        rst = 0;

        // --- Pruebas de lectura ---
        $display("-------------------[Pruebas de lectura]-------------------");
        // 1. Lectura de palabra completa
        $display("<< Lectura de palabra completa >>");
        task_read(32'd0, 4'b1111);
        // 2. Lectura de media palabra
        $display("<< Lectura de media palabra >>");
        task_read(32'd4, 4'b0011);
        // 3. Lectura de byte
        $display("<< Lectura de byte >>");
        task_read(32'd6, 4'b0001);
        // 4. Lectura desfasada en mismo bloque
        $display("<< Lectura desfasada en mismo bloque >>");
        task_read(32'd2, 4'b1111);
        // 5. Lectura desfasada en bloques distintos
        $display("<< Lectura desfasada en bloques distintos >>");
        task_read(32'd7, 4'b0111);
        // 6. Lectura en bloque invalido
        $display("<< Lectura en bloque invalido >>");
        task_read(32'd28, 4'b0111);

        // --- Pruebas de escritura ---
        $display("-------------------[Pruebas de escritura]-------------------");
        // 1. Escritura de palabra completa
        $display("<< Escritura de palabra completa >>");
        task_write(32'd16, 32'd1024, 4'b1111);
        task_read(32'd16, 4'b1111);
        // 2. Escritura de media palabra
        $display("<< Escritura de media palabra >>");
        task_write(32'd20, 32'hAAAAAAAA, 4'b0011);
        task_read(32'd20, 4'b1111);
        // 3. Escritura de byte
        $display("<< Escritura de byte >>");
        task_write(32'd23, 32'd11, 4'b0001);
        task_read(32'd20, 4'b1111);
        // 4. Escritura desfasada en mismo bloque
        $display("<< Escritura desfasada en mismo bloque>>");
        task_write(32'd18, 32'hFFFF1111, 4'b0111);
        task_read(32'd16, 4'b1111);
        task_read(32'd20, 4'b1111);
        // 5. Escritura desfasada en bloques distintos
        $display("<< Escritura desfasada en bloques distintos >>");
        task_write(32'd6, 32'hdeadbeef, 4'b1111);
        task_read(32'd4, 4'b1111);
        task_read(32'd8, 4'b1111);
        // 6. Escritura en bloque invalido
        $display("<< Escritura en bloque invalido >>");
        task_write(32'd28, 32'd67, 4'b1111);
        task_read(32'd28, 4'b1111);

        // --- Volcado de memoria ---
        $display("\n[SISTEMA] Generando archivo de salida...");
        $writememh("./output/cache_data_exit.hex", _dut.data);
        $writememh("./output/cache_tags_exit.hex", _dut.tags);
        $display("[Final del testbench]");
        $finish;
    end

    // --- Tareas para interacción con la memoria cache ---
    task task_write(input [31:0] address, input [31:0] data, input [3:0] mask);
        begin
            $display("+ TASK_WRITE: A[0x%0d], WD[%h], ASM[%b]", address, data, mask);
            addr = address;
            wd = data;
            we = 1'b1;
            asm = mask;
            for (int i = 0; i < LAT; i++) begin
                #10;
                if (hit && finished) $display("[%0d] Hit  detected! Content was written correctly",i+1);
                else if (!hit && finished) $display("[%0d] Miss detected! Content was not written",i+1);
                else     $display("[%0d] Content is being written...",i+1);
            end
            addr = '0;
            wd = '0;
            we = 1'b0;
            asm = 4'b0000;
        end
    endtask
    
    task task_read(input [31:0] address, input [3:0] mask);
        begin
            $display("+ TASK_READ: A[0x%0d], ASM[%b]", address, mask);
            addr = address;
            wd = '0;
            we = 1'b0;
            asm = mask;
            for (int i = 0; i < LAT; i++) begin
                #10;
                if (hit && finished) $display("[%0d] Hit  detected! Content found: %h",i+1, rd);
                else if (!hit && finished) $display("[%0d] Miss detected! Content was not found",i+1);
                else     $display("[%0d] Cache is still searching...",i+1);
            end
            addr = '0;
            wd = '0;
            we = 1'b0;
            asm = 4'b0000;
        end
    endtask

endmodule