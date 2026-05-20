module sALU #(parameter WIDTH = 32)
            (input logic [WIDTH-1:0] A, B,
             input logic op, // solo son dos ops
             output logic [WIDTH-1:0] Y);

    /* Decodificacion de operaciones
    0 ADD
    1 XOR*/
    logic [WIDTH-1:0] add_res, xor_res;

    assign add_res = $signed(A) + $signed(B);
    assign xor_res = A ^ B;

    assign Y = op ? xor_res : add_res;

endmodule
