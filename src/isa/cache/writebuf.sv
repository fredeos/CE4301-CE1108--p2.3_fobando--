// FIFO write buffer to propagate content between memory levels
module writebuf #(
    parameter size = 4 // cantidad de palabras en el buffer
)(
    input  logic CLK,
    input  logic RST,
    input  logic queue,
    input  logic dequeue,
    input  logic [31:0] addr_in,
    input  logic [31:0] data_in,
    input  logic [3:0]  bm_in,
    output logic [31:0] addr_out,
    output logic [31:0] data_out,
    output logic [3:0]  bm_out,
    output logic valid,
    output logic hold
);
    logic [31:0]    data [0:size-1];
    logic [31:0] address [0:size-1];
    logic [4:0]  enables [0:size-1]; // [valid][ASM]

    initial begin
        for (int i=0; i < size; i++) begin
            data[i] = '0;
            address[i] = '0;
            enables[i] = '0;
        end
    end

    logic [31:0] idx;
    always_ff @(negedge CLK, posedge RST) begin
        if (RST) begin
            idx <= '0;
            hold <= 1'b0;
            for (int i=0; i < size; i++) begin
                data[i] = '0;
                address[i] = '0;
                enables[i] = '0;
            end
        end else begin
            hold <= (idx == size);
            if (dequeue) begin
                for (int i = 0; i < size; i++) begin 
                    if (i == size-1) begin 
                        data[i] = '0;
                        address[i] = '0;
                        enables[i] = '0;
                    end else begin
                        data[i] = data[i+1];
                        address[i] = address[i+1];
                        enables[i] = enables[i+1];
                    end
                end
                idx <= idx - 1;
            end
            if (queue) begin
                if (idx < size) begin 
                    address[idx] <= addr_in;
                    data[idx] <= data_in;
                    enables[idx] <= {1'b1, bm_in};
                    idx <= idx + 1;
                end
            end
        end
    end

    assign addr_out = address[0];
    assign data_out = data[0];
    assign bm_out   = enables[0][3:0];
    assign valid    = enables[0][4];
endmodule