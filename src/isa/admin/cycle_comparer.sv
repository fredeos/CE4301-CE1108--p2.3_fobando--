module cycle_comparer #(parameter width = 32)(
    input  logic clk, en, rst, clr,
    input  logic [width-1:0] tol,
    output logic state
);

logic [width-1:0] cycles, inc;
assign inc = { {width-1{1'b0}} ,1'b1};

always_ff @(posedge clk, posedge rst) begin
    if (rst || clr) cycles <= 0;
    else if (en) cycles <= cycles + inc;
end

assign state = (cycles >= tol);

endmodule