module randgen #(
    parameter int WIDTH = 32
)(
    input  logic clk,
    input  logic rst,
    input  logic [WIDTH-1:0] seed,
    output logic [WIDTH-1:0] random
);

    logic feedback;

    assign feedback = random[WIDTH-1] ^ random[WIDTH/2-1] ^ random[1] ^ random[0];

    always_ff @(posedge clk, posedge rst) begin 
        if (rst) random <= seed;
        else random <= {random[WIDTH-2:0], feedback};
    end
    
endmodule