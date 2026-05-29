module data_memory_tb();
    localparam int LAT = 8;

    logic clk, rst;

    logic re, we, w_ready, r_ready;
    logic [3:0] bm;
    logic [31:0] addr, wd, rd;

    // Instancia del módulo (DUT)
    data_memory #(.SIZE(128), .LATENCY(8), .WPL(2)) _dut (
        .CLK(clk), .RST(rst),
        .WE(we), .WBM(bm), .WA(addr), .WD(wd),
        .RE(re), .RBM(bm), .RA(addr), .RD(rd),
        .ready({w_ready, r_ready}),
        .burst1(), .burst2()
    );

    // Reloj a 100MHz
    always #5 clk = ~clk;

    initial begin
        $dumpfile("./gen/datamem.vcd");
        $dumpvars(0, data_memory_tb);
        // --- Inicialización ---
        addr = '0; wd = '0;
        bm = 4'b0000;
        re = 1'b0; we = 1'b0;
        clk = 1'b0; 
        rst = 1'b1; #10; rst = 1'b0;
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
        task_read(32'd7, 4'b0001);
        // 4. Lectura desfasada
        $display("\n<< Lectura desfasada >>");
        task_read(32'd6, 4'b1111);

        // --- Pruebas de escritura ---
        $display("\n-------------------[Pruebas de escritura]-------------------");
        // 1. Escritura de palabra completa
        $display("\n<< Escritura de palabra completa >>");
        task_write(32'd8, 32'hFFFFAAAA, 4'b1111);
        task_read(32'd8, 4'b1111);
        // 2. Escritura de media palabra
        $display("\n<< Escritura de media palabra >>");
        task_write(32'd8, 32'h87654321, 4'b0011);
        task_read(32'd8, 4'b1111);
        // 3. Escritura de byte
        $display("\n<< Escritura de byte >>");
        task_write(32'd11, 32'hBBBBBBBB, 4'b0001);
        task_read(32'd8, 4'b1111);
        // 4. Escritura desfasada
        $display("\n<< Escritura desfasada >>");
        task_write(32'd14, 32'hdeadbeef, 4'b0111);
        task_read(32'd12, 4'b1111);
        task_read(32'd16, 4'b1111);
        // --- Volcado final ---
        $display("\n[SISTEMA] Generando archivo de salida corregido...");
        $writememh("./output/data_mem_exit.hex", _dut.RAM);
        $display("[SISTEMA] Archivo generado exitosamente.");
        $finish;
    end

    // --- Tareas para interacción con la memoria ---
    task task_read(input [31:0] address, input [3:0] mask);
        begin
            $display("+ TASK_READ: A[0x%0d], BM[%b]", address, mask);
            addr = address;
            wd = '0;
            bm = mask;
            re = 1'b1; we = 1'b0;
            for (int i = 0; i < LAT; i++) begin
                #10;
                if (r_ready) $display("[%0d] End of search! Data found: %h", i+1, rd);
                else $display("[%0d] Looking for data on memory...", i+1);
            end
            addr = '0;
            wd = '0;
            bm = 4'b0000;
            re = 1'b0; we = 1'b0;
        end
        
    endtask

    task task_write(input [31:0] address, input [31:0] data, input [3:0] mask);
        begin
            $display("+ TASK_WRITE: A[0x%0d], WD[%h], BM[%b]", address, data, mask);
            #5;
            addr = address;
            wd = data;
            bm = mask;
            re = 1'b0; we = 1'b1;
            for (int i = 0; i < LAT; i++) begin
                #10;
                if (w_ready) $display("[%0d] End of write! Data was written succesfully", i+1);
                else $display("[%0d] Writing data on memory...", i+1);
            end
            addr = '0;
            wd = '0;
            bm = 4'b0000;
            re = 1'b0; we = 1'b0;
            #5;
        end
    endtask

endmodule