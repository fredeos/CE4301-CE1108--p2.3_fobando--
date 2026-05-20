`timescale 1ns/1ps

module sALU_tb;
    localparam WIDTH = 32;

    logic [WIDTH-1:0] A, B, Y;
    logic op;

    sALU #(.WIDTH(WIDTH)) DUT (.A(A), .B(B), .Y(Y), .op(op));

    initial begin
        $dumpfile("salu.vcd");   // nombre del archivo
        $dumpvars(0, sALU_tb);         // qué señales guardar
        $display("--- ADD (op=0) ---");
        op = 0;

        A = 32'd10;  B = 32'd20;  #1;
        $display("10 + 20 = %0d %s", $signed(Y), (Y === 32'd30)   ? "[PASS]" : "[FAIL]");

        A = -32'd5;  B = -32'd3;  #1;
        $display("-5 + -3 = %0d %s", $signed(Y), (Y === -32'd8)   ? "[PASS]" : "[FAIL]");

        A = 32'd0;   B = 32'd0;   #1;
        $display(" 0 +  0 = %0d %s", $signed(Y), (Y === 32'd0)    ? "[PASS]" : "[FAIL]");

        $display("--- OR  (op=1) ---");
        op = 1;

        A = 32'hFF00_0000; B = 32'h00FF_FFFF; #1;
        $display("0xFF000000 | 0x00FFFFFF = %h %s", Y, (Y === 32'hFFFF_FFFF) ? "[PASS]" : "[FAIL]");

        A = 32'h0000_0000; B = 32'h0000_0000; #1;
        $display("0x00000000 | 0x00000000 = %h %s", Y, (Y === 32'h0000_0000) ? "[PASS]" : "[FAIL]");

        A = 32'h00A0_0000; B = 32'h0B00_00A0; #1;
        $display("0x00000000 | 0x00000000 = %h %s", Y, (Y === 32'h0BA0_00A0) ? "[PASS]" : "[FAIL]");

        $finish;
    end

endmodule