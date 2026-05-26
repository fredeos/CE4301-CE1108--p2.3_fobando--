module cache_tb ();

    localparam LAT = 2;

    logic clk, rst, hit, we;
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
        // 1. Lectura de palabra completa
        task_read(32'd0, 4'b1111);
        // 2. Lectura de media palabra
        task_read(32'd4, 4'b0011);
        // 3. Lectura de byte
        task_read(32'd6, 4'b0001);
        // --- Pruebas de escritura ---
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
            addr = address;
            wd = data;
            we = 1'b1;
            asm = mask;
            for (int i = 0; i < LAT; i++) begin
                #10;
                if (hit) $display("[%0d] Hit  detected! Content was written correctly",i+1);
                else     $display("[%0d] Miss detected! Content is being written",i+1);
            end
            addr = '0;
            wd = '0;
            we = 1'b0;
            asm = 4'b0000;
        end
    endtask
    
    task task_read(input [31:0] address, input [3:0] mask);
        begin
            addr = address;
            wd = '0;
            we = 1'b0;
            asm = mask;
            for (int i = 0; i < LAT; i++) begin
                #10;
                if (hit) $display("[%0d] Hit  detected! Content found: %h",i+1, rd);
                else     $display("[%0d] Miss detected! Cache is still searching",i+1);
            end
            addr = '0;
            wd = '0;
            we = 1'b0;
            asm = 4'b0000;
        end
    endtask

endmodule