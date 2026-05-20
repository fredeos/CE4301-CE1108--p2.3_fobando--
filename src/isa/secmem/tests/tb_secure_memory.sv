module tb_secure_memory;

    logic clk;
    logic rst_n;
    logic we;

    logic [2:0] ra1;
    logic [2:0] ra2;
    logic [2:0] ra3;
    logic [2:0] wa;
    logic [31:0] wd;

    logic [31:0] rd1;
    logic [31:0] rd2;
    logic [31:0] rd3;

    secure_memory dut (
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .ra1(ra1),
        .ra2(ra2),
        .ra3(ra3),
        .wa(wa),
        .wd(wd),
        .rd1(rd1),
        .rd2(rd2),
        .rd3(rd3)
    );

    always #5 clk = ~clk;

    task check_equal;
        input [31:0] got;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            if (got === expected) begin
                $display("[PASS] %0s -> got = %h", test_name, got);
            end else begin
                $display("[FAIL] %0s -> got = %h, expected = %h", test_name, got, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, tb_secure_memory);

        clk  = 0;
        rst_n = 0;
        we   = 0;
        ra1  = 3'd0;
        ra2  = 3'd0;
        ra3  = 3'd0;
        wa   = 3'd0;
        wd   = 32'd0;

        #12;
        rst_n = 1;

        // Verifica reset
        ra1 = 3'd0;
        ra2 = 3'd1;
        ra3 = 3'd7;
        #1;
        check_equal(rd1, 32'h00000000, "reset reg0");
        check_equal(rd2, 32'h00000000, "reset reg1");
        check_equal(rd3, 32'h00000000, "reset reg7");

        // ax/reg0 es solo lectura y siempre devuelve 0
        @(negedge clk);
        wa = 3'd0;
        wd = 32'hFFFFFFFF;
        ra1 = 3'd0;
        we = 1'b1;
        #1;
        check_equal(rd1, 32'h00000000, "ax write-first stays zero");

        @(posedge clk);
        #1;
        we = 1'b0;
        ra1 = 3'd0;
        #1;
        check_equal(rd1, 32'h00000000, "ax ignores write");

        // Escritura en reg1
        @(negedge clk);
        wa = 3'd1;
        wd = 32'hAAAA5555;
        we = 1'b1;

        @(posedge clk);
        #1;
        we = 1'b0;
        ra1 = 3'd1;
        #1;
        check_equal(rd1, 32'hAAAA5555, "write/read reg1");

        // Escritura en reg3
        @(negedge clk);
        wa = 3'd3;
        wd = 32'h12345678;
        we = 1'b1;

        @(posedge clk);
        #1;
        we = 1'b0;
        ra2 = 3'd3;
        #1;
        check_equal(rd2, 32'h12345678, "write/read reg3");

        // Escritura en reg7
        @(negedge clk);
        wa = 3'd7;
        wd = 32'hDEADBEEF;
        we = 1'b1;

        @(posedge clk);
        #1;
        we = 1'b0;
        ra3 = 3'd7;
        #1;
        check_equal(rd3, 32'hDEADBEEF, "write/read reg7");

        // WE=0 no debe modificar
        @(negedge clk);
        wa = 3'd1;
        wd = 32'hFFFFFFFF;
        we = 1'b0;

        @(posedge clk);
        #1;
        ra1 = 3'd1;
        #1;
        check_equal(rd1, 32'hAAAA5555, "we=0 no write");

        // Lecturas múltiples simultáneas
        ra1 = 3'd1;
        ra2 = 3'd3;
        ra3 = 3'd7;
        #1;
        check_equal(rd1, 32'hAAAA5555, "multi-read rd1");
        check_equal(rd2, 32'h12345678, "multi-read rd2");
        check_equal(rd3, 32'hDEADBEEF, "multi-read rd3");

        // Write-first: leer y escribir misma dirección
        @(negedge clk);
        wa  = 3'd4;
        wd  = 32'hCAFEBABE;
        ra1 = 3'd4;
        we  = 1'b1;
        #1;
        check_equal(rd1, 32'hCAFEBABE, "write-first same addr before clock");

        @(posedge clk);
        #1;
        we = 1'b0;
        ra1 = 3'd4;
        #1;
        check_equal(rd1, 32'hCAFEBABE, "write-first same addr after clock");

        #20;
        $finish;
    end

endmodule
