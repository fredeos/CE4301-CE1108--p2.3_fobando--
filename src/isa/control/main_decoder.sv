module main_decoder (
    input  logic [4:0] opcode,
    input  logic [3:0] func4,
    // Señales de control de salida en WB
    output logic  [1:0] MemToReg,
    // Señales de control de escritura en WB
    output logic  [1:0] RegWrite, // write enable = [0]: secure memory, [1]: register file
    // Señales de control en MEM
    output logic  [1:0] MemWrite, // write enable = [0]: vault, [1]: data memory
    output logic  [7:0] MemBytes, // seleccion de bytes para lectura o escritura = [3:0] vault, [7:4] data memory
    // Señales de control de session
    output logic  [1:0] Session,  // [0]: login, [1]: logout (quit)
    // Señales de control para EX
    output logic        ALUSel,    // salida de ALU (pALU | sALU)
    output logic        ALUSrcB,   // selección de operando B para pALU
    output logic  [1:0] ALUSrcA,   // selección de operando A para pALU
    // Señales de control para ID
    output logic  [1:0] RSel,     // selección de registros = [0]: (rn | sn), [1]: ((rm | rd) | (sm | sd))
    output logic  [2:0] ImmSel,   // selección de extensión de inmediatos
    output logic        RegSrc,   // selección de registro 2 (rm | rd)
    output logic        SecSrc    // seleccion de registro 2 (sm | sd)
);

logic [26:0] control;
logic [2:0] Mfunc4;

assign Mfunc4 = func4[3:1];

// --- Logica combinacional ---
always_comb begin
    // 1. Decodificacion de senales de control
    case (opcode)
        5'b00000: begin // Tipo R
            control = 27'b0110_00_00000000_00_1010_1100_000;
        end

        5'b00001: begin // Tipo I
            control = 27'b0110_00_00000000_00_1110_1100_001;
        end

        5'b00010: begin // Tipo PR
            control = 27'b0101_00_00000000_00_0010_0000_000;
        end

        5'b00011: begin // Tipo PI
            control = 27'b0101_00_00000000_00_1110_0000_101;
        end

        5'b00100: begin // Tipo M (load)
            control = 27'b1010_00_00000000_00_1110_1100_001; // Caso por defecto
            if (Mfunc4 == 3'b100)      control = 27'b1010_00_11110000_00_1110_1100_001; // ldw
            else if (Mfunc4 == 3'b010) control = 27'b1010_00_00110000_00_1110_1100_001; // ldh
            else if (Mfunc4 == 3'b001) control = 27'b1010_00_00010000_00_1110_1100_001; // ldb
        end

        5'b00101: begin // Tipo M (store)
            control = 27'b1000_10_00000000_00_1110_1110_001; // Caso por defecto
            if (Mfunc4 == 3'b100)      control = 27'b1000_10_11110000_00_1110_1110_001; // stw
            else if (Mfunc4 == 3'b010) control = 27'b1000_10_00110000_00_1110_1110_001; // sth
            else if (Mfunc4 == 3'b001) control = 27'b1000_10_00010000_00_1110_1110_001; // stb
        end

        5'b00110: begin // Tipo V (load)
            control = 27'b0001_00_00000000_00_1110_0000_101; // Caso por defecto
            if (Mfunc4 == 3'b100)      control = 27'b0001_00_00001111_00_1110_0000_101; // ldvw
            else if (Mfunc4 == 3'b010) control = 27'b0001_00_00000011_00_1110_0000_101; // ldvh
            else if (Mfunc4 == 3'b001) control = 27'b0001_00_00000001_00_1110_0000_101; // ldvb
        end

        5'b00111: begin // Tipo V (store)
            control = 27'b0000_01_00000000_00_1110_0001_101;
            if (Mfunc4 == 3'b100)      control = 27'b0000_01_00001111_00_1110_0001_101; // stvw
            else if (Mfunc4 == 3'b010) control = 27'b0000_01_00000011_00_1110_0001_101; // stvh
            else if (Mfunc4 == 3'b001) control = 27'b0000_01_00000001_00_1110_0001_101; // stvb
        end

        5'b01000: begin // Tipo B
            control = 27'b0100_00_00000000_00_1010_1100_010;
        end

        5'b01001: begin // Tipo J/F
            control = 27'b1110_00_00000000_00_1010_1100_011;
        end

        5'b10000: begin // Tipo T
            control = 27'b0100_00_00000000_00_1001_0000_000;
            if (func4 == 4'b0000)      control = 27'b0101_00_00000000_00_1010_1100_000; // send
            else if (func4 == 4'b0001) control = 27'b0110_00_00000000_00_1001_0100_000; // recv
        end

        5'b10001: begin // Tipo S
            control = 27'b0100_00_00000000_00_1100_1100_100;
            if (func4 == 4'b0000)      control = 27'b0100_00_00000000_01_1100_1100_100; // login
            else if (func4 == 4'b0001)  control = 27'b0100_00_00000000_10_1100_1100_100; // quit
        end
        
        default: begin  // Default
            control = 27'b0000_00_00000000_00_0000_0000_000;
        end
    endcase
end

assign {MemToReg, RegWrite, MemWrite, MemBytes, Session, ALUSel, ALUSrcB, ALUSrcA, RSel, RegSrc, SecSrc, ImmSel} = control;

endmodule