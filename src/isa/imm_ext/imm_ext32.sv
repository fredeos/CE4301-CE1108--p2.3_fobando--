module imm_ext32 (
    input  logic [25:0] source,
    input  logic [2:0]  sel,
    output logic [31:0] ext
);

// --- Logica combinacional ---
wire sign = source[25];

wire [11:0] imm12a = source[25:14];
wire [11:0] imm12b = {source[25:19], source[8:4]};
wire [20:0] imm21  = {source[25:9], source[3:0]};
wire [19:0] imm20  = source[25:6];
wire [15:0] imm16  = source[25:10];

always_comb begin
    // 1. Decodificador de tipo de extension(con signo) de inmediatos
    case (sel)
        3'b001: begin   // Extension tipo 1: inmediatos 12 bits (I/M)
            ext = { {20{sign}}, imm12a};
        end

        3'b010: begin   // Extension tipo 2: inmediatos 12 bits con corte (B)
            ext = { {20{sign}}, imm12b};
        end

        3'b011: begin   // Extension tipo 3: inmediatos 21 bits con corte (J/F)
            ext = { {11{sign}}, imm21};
        end

        3'b100: begin   // Extension tipo 4: inmediatos 20 bits (S)
            ext = { {12{1'b0}}, imm20};
        end

        3'b101: begin   // Extension tipo 5: inmediatos 16 bits (PI/V)
            ext = { {16{sign}}, imm16};
        end
        
        default: begin  // Cualquier otro caso
            ext = 32'b0;
        end
    endcase
end

endmodule