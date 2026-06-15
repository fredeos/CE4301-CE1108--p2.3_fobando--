// modulo de ALU primariap
module pALU #(parameter WIDTH = 32)
            (input logic [WIDTH-1:0] A, B,
             input logic [3:0] op, // igual que func4
             output logic [WIDTH-1:0] Y,
             output logic [3:0] flags);


    localparam CUT = $clog2(WIDTH); // para que icarus no se ponga triste

    /* Decodificacion de operaciones
    0000 SLL(<<)
    0001 SRL(>>)
    0010 ADD(+)
    0011 SUB(-)
    0100 MUL(*)
    0101 DIV(/)
    0110 MOD(%)
    0111 AND(&)
    1000 OR (|)
    1001 XOR(^)
    1010 SEQ
    */

    // Flags
    logic N, Z, C, V;

    // para guardar el resultado ed las operaciones
    logic [WIDTH-1:0] SLLres, SLRres, ADDres, SUBres, ANDres, ORres, XORres, MULTTRres;
    logic signed [WIDTH-1:0] DIVres, MODres;
	logic [2*WIDTH-1:0] MULres;
    logic SEQres;
    // wires signed para que icarus no pierda el signo en el ternario
    logic signed [WIDTH-1:0] A_s, B_s;
    assign A_s = A;
    assign B_s = B;

    // resultado de las operaciones
    assign SLLres = A << B[CUT-1:0];
    assign SLRres = A >>  B[CUT-1:0];
    assign ADDres = $signed(A) + $signed(B);
    assign SUBres = $signed(A) - $signed(B);
    assign MULres = $signed(A) * $signed(B);
    assign MULTTRres = MULres[WIDTH-1:0]; // multiplicacion truncada antes de dar res
    assign ANDres = A & B;
    assign ORres = A | B;
    assign XORres = A ^ B; 
    assign SEQres = (A == B);

    // always comb para / y % para evitar bug de signo con ?
    always_comb begin
        if (B_s != 0) begin      // usar B_s, no B
            DIVres = A_s / B_s;
            MODres = A_s % B_s;
        end else begin
            DIVres = '0;
            MODres = '0;
        end
    end

    always_comb begin
        case(op)
            4'b0000: Y = SLLres;
            4'b0001: Y = SLRres;
            4'b0010: Y = ADDres;
            4'b0011: Y = SUBres;
            4'b0100: Y = MULTTRres; // truncado
            4'b0101: Y = DIVres;
            4'b0110: Y = MODres;
            4'b0111: Y = ANDres;
            4'b1000: Y = ORres;
            4'b1001: Y = XORres;
            4'b1010: Y = {{(WIDTH-1){1'b0}}, SEQres};
            default: Y = {WIDTH{1'b0}};
        endcase
    end

    // resultado de las flags
    logic V_add, V_sub;
    assign V_add = (A[WIDTH-1] == B[WIDTH-1]) && (ADDres[WIDTH-1] != A[WIDTH-1]);
    assign V_sub = (A[WIDTH-1] != B[WIDTH-1]) && (SUBres[WIDTH-1] != A[WIDTH-1]);

    assign N = Y[WIDTH-1];
    assign Z = (Y == 0);
    assign C = (op == 4'b0010) ? (({1'b0, A} + {1'b0, B}) >> WIDTH) : 
               (op == 4'b0011) ? (A < B):  1'b0;
    assign V = (op == 4'b0010) ? V_add :
               (op == 4'b0011) ? V_sub : 1'b0;

    assign flags = {N, Z, C, V};

endmodule