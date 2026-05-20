module tb_register_file;

    logic        clk;
    logic        reset;
    logic        we;

    logic [4:0]  ra1;
    logic [4:0]  ra2;
    logic [4:0]  wa;

    logic [31:0] wd;
    logic [31:0] pc_in;

    logic [31:0] rd1;
    logic [31:0] rd2;
    logic [31:0] pc_out;

    register_file dut (
        .clk(clk),
        .reset(reset),
        .we(we),
        .ra1(ra1),
        .ra2(ra2),
        .wa(wa),
        .wd(wd),
        .pc_in(pc_in),
        .rd1(rd1),
        .rd2(rd2),
        .pc_out(pc_out)
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
        $dumpvars(0, tb_register_file);

        clk    = 0;
        reset  = 1;
        we     = 0;
        ra1    = 5'd0;
        ra2    = 5'd0;
        wa     = 5'd0;
        wd     = 32'd0;
        pc_in  = 32'h00000004;

        #12;
        reset = 0;

        // Verifica registros especiales
        ra1 = 5'd0;
        ra2 = 5'd30;
        #1;
        check_equal(rd1, 32'h00000000, "zero constante");
        check_equal(rd2, 32'h9E3779B9, "delta constante");

        ra1 = 5'd31;
        ra2 = 5'd3;
        #1;
        check_equal(rd1, 32'hFFFFFFFF, "max constante");
        check_equal(rd2, 32'h00000004, "pc desde pc_in");
        check_equal(pc_out, 32'h00000004, "pc_out refleja pc_in");

        ra1 = 5'd4;
        #1;
        check_equal(rd1, 32'h00000000, "lr reset");

        // Escritura válida en registro general
        @(negedge clk);
        wa = 5'd14;
        wd = 32'h12345678;
        we = 1'b1;

        @(posedge clk);
        #1;
        we  = 1'b0;
        ra1 = 5'd14;
        #1;
        check_equal(rd1, 32'h12345678, "write/read r14");

        // Otra escritura válida
        @(negedge clk);
        wa = 5'd20;
        wd = 32'hCAFEBABE;
        we = 1'b1;

        @(posedge clk);
        #1;
        we  = 1'b0;
        ra2 = 5'd20;
        #1;
        check_equal(rd2, 32'hCAFEBABE, "write/read r20");

        // we=0 no modifica
        @(negedge clk);
        wa = 5'd14;
        wd = 32'hAAAAAAAA;
        we = 1'b0;

        @(posedge clk);
        #1;
        ra1 = 5'd14;
        #1;
        check_equal(rd1, 32'h12345678, "we=0 no write");

        // Bloquea escritura en zero
        @(negedge clk);
        wa = 5'd0;
        wd = 32'h11111111;
        we = 1'b1;

        @(posedge clk);
        #1;
        we  = 1'b0;
        ra1 = 5'd0;
        #1;
        check_equal(rd1, 32'h00000000, "write bloqueado en zero");

        // Bloquea escritura en pc
        @(negedge clk);
        wa = 5'd3;
        wd = 32'h22222222;
        we = 1'b1;

        @(posedge clk);
        #1;
        we  = 1'b0;
        ra1 = 5'd3;
        #1;
        check_equal(rd1, 32'h00000004, "write bloqueado en pc");

        // Bloquea escritura en lr
        @(negedge clk);
        wa = 5'd4;
        wd = 32'h55555555;
        we = 1'b1;

        @(posedge clk);
        #1;
        we  = 1'b0;
        ra1 = 5'd4;
        #1;
        check_equal(rd1, 32'h00000000, "write bloqueado en lr");

        // Bloquea escritura en delta
        @(negedge clk);
        wa = 5'd30;
        wd = 32'h33333333;
        we = 1'b1;

        @(posedge clk);
        #1;
        we  = 1'b0;
        ra1 = 5'd30;
        #1;
        check_equal(rd1, 32'h9E3779B9, "write bloqueado en delta");

        // Bloquea escritura en max
        @(negedge clk);
        wa = 5'd31;
        wd = 32'h44444444;
        we = 1'b1;

        @(posedge clk);
        #1;
        we  = 1'b0;
        ra1 = 5'd31;
        #1;
        check_equal(rd1, 32'hFFFFFFFF, "write bloqueado en max");

        // Cambia pc_in dinámicamente
        pc_in = 32'h00000024;
        ra2   = 5'd3;
        #1;
        check_equal(rd2, 32'h00000024, "pc cambia con pc_in");
        check_equal(pc_out, 32'h00000024, "pc_out cambia con pc_in");

        // Lectura simultánea
        ra1 = 5'd14;
        ra2 = 5'd20;
        #1;
        check_equal(rd1, 32'h12345678, "lectura simultanea rd1");
        check_equal(rd2, 32'hCAFEBABE, "lectura simultanea rd2");

        #20;
        $finish;
    end

endmodule
