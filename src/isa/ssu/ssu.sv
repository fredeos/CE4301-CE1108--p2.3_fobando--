module ssu (
    input  logic       login, P,
    input  logic [4:0] opcode,
    output logic       ignore,
    output logic       is_secure
);
logic secure_instr;

// --- Logica combinacional ---
always_comb begin
    // 1. Decodificar tipo de instruccion
    case (opcode)
        5'b00010: begin // Tipo PR: instrucciones aritmeticas o logicas protegidas registro-registro
            ignore = ~login;
            secure_instr = 1'b1;
        end

        5'b00011: begin // Tipo PI: instrucciones aritmeticas o logicas protegidas registro-inmediato
            ignore = ~login;
            secure_instr = 1'b1;
        end

        5'b00110: begin // Tipo V (load)
            ignore = ~login;
            secure_instr = 1'b1;
        end

        5'b00111: begin // Tipo V (store)
            ignore = ~login;
            secure_instr = 1'b1;
        end

        5'b10000: begin // Tipo T: instrucciones de traslado de datos entre banco de registros y banco seguro
            ignore = ~login;
            secure_instr = 1'b1;
        end
        
        default: begin
            ignore = P & ~login;
            secure_instr = P;
        end
    endcase
end

assign is_secure = secure_instr & ~ignore;

endmodule