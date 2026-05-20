module alu_decoder (
    input  logic [4:0] opcode,
    input  logic [3:0] func4,
    input  logic [2:0] func3,
    input  logic [6:0] func7,
    output logic [3:0] pALUControl,
    output logic       sALUControl
);

logic Mfunc4;
assign Mfunc4 = func4[0];

// --- Logica combinancional ---
// (Decodificadores)
always_comb begin
    // 1. Decodificar para ALU principal
    case (func4)
        4'b0000: begin // SLL (<<)
            pALUControl = 4'b0000;
        end

        4'b0001: begin // SRL (>>)
            pALUControl = 4'b0001;
        end

        4'b0010: begin // ADD (+)
            pALUControl = 4'b0010;
        end

        4'b0011: begin // SUB (-)
            pALUControl = 4'b0011;
        end

        4'b0100: begin // MUL (*)
            pALUControl = 4'b0100;
        end

        4'b0101: begin // DIV (/)
            pALUControl = 4'b0101;
        end

        4'b0110: begin // MOD (%)
            pALUControl = 4'b0110;
        end

        4'b0111: begin // AND (&)
            pALUControl = 4'b0111;
        end

        4'b1000: begin // ORR (|)
            pALUControl = 4'b1000;
        end

        4'b1001: begin // XOR (^)
            pALUControl = 4'b1001;
        end

        4'b1010: begin // SEQ
            pALUControl = 4'b1010;
        end

        default: begin 
            pALUControl = 4'b0010;
        end
        
    endcase

    // 2. Decodificador para ALU secundaria
    case (func3)
        3'b000: begin // ADD (+)
            sALUControl = 1'b0;
        end

        3'b001: begin // XOR (-)
            sALUControl = 1'b1;
        end

        default: begin
            sALUControl = 1'b0;
        end
    endcase

    // 3. Casos de instrucciones de memoria y branch
    if (opcode == 5'b00100 || opcode == 5'b00101) pALUControl = (Mfunc4) ? 4'b0011 : 4'b0010;      // Tipo M
    else if (opcode == 5'b00110 || opcode == 5'b00111) pALUControl = (Mfunc4) ? 4'b0011 : 4'b0010; // Tipo V
    else if (opcode == 5'b01000 || opcode == 5'b01001) pALUControl = 4'b0011;                      // Tipos B,F,J
    else if (opcode == 5'b10000) pALUControl = 4'b0010; // Tipo T
    else if (opcode == 5'b10001) pALUControl = 4'b0011; // Tipo S

end

endmodule