module branch_decoder (
    input  logic [4:0] opcode,
    input  logic [3:0] func4,
    input  logic [4:0] rd,
    output logic [4:0] Branch
);

logic [2:0] cond;
logic pcmod, binstr;

// --- Logica combinacional ---
always_comb begin
    // 1. Decodificador para tipos de condiciones de salto
    // Instrucciones Tipo B:
    case (func4)
        4'b0001: begin // BEQ
            cond = 3'b000;
        end

        4'b0010: begin // BNE
            cond = 3'b001;
        end

        4'b0011: begin // BGT
            cond = 3'b010;
        end

        4'b0100: begin // BLT
            cond = 3'b011;
        end

        4'b0101: begin // BGE
            cond = 3'b100;
        end

        4'b0110: begin // BLE
            cond = 3'b101;
        end

        default: begin // ignorar salto
            cond = 3'b111;
        end
    endcase

    // 2. Identificar instrucciones que modifican PC
    pcmod = 1'b0;
    if (rd == 5'b00011) begin
        if (opcode == 5'b00000) pcmod = 1'b1; // Tipo R
        if (opcode == 5'b00001) pcmod = 1'b1; // Tipo I
        if (opcode == 5'b00100) pcmod = 1'b1; // Tipo M (load)
        if (opcode == 5'b01001) pcmod = 1'b1; // Tipo J
        if (opcode == 5'b10000 && func4 == 4'b0001) pcmod = 1'b1; // Tipo T (recv)
    end

    // 3. Indentificar instrucciones de branch
    binstr = (opcode == 5'b01000 || opcode == 5'b01001);
    if (opcode == 5'b01001) cond = 4'b110; // ejecucion incodicional de salto

end

assign Branch = {cond, pcmod, binstr};

endmodule