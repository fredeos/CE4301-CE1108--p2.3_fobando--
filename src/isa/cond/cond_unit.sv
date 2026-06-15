module cond_unit (
    input  logic [4:0] Branch,
    input  logic [3:0] flags,
    output logic [1:0] PCSrc
);

logic [2:0] cond;
logic zf, cf, nf, vf, ge, comp;

assign cond = Branch[4:2];
assign {nf, zf, cf, vf} = flags;
assign ge = ~(nf ^ vf);

always_comb begin
    // 1. Decodificar tipo de comparacion
    case (cond)
        3'b000: begin   // EQ
            comp = zf;
        end

        3'b001: begin   // NE
            comp = ~zf;
        end

        3'b010: begin   // GT
            comp = ~zf & ge;
        end

        3'b011: begin   // LT
            comp = ~ge;
        end

        3'b100: begin   // GE
            comp = ge;
        end

        3'b101: begin   // LE
            comp = zf | ~ge;
        end

        3'b110: begin   // UNC
            comp = 1'b1;
        end

        3'b111: begin   // IGNORE
            comp = 1'b0;
        end
        
        default: begin // Default case: ignore
            comp = 1'b0;
        end
    endcase

end

assign PCSrc[0] = (Branch[0]) ? comp : 1'b0;
assign PCSrc[1] = Branch[1] & ~Branch[0];

endmodule