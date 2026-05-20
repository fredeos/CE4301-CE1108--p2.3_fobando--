module register_file #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 5,
    parameter int DEPTH      = 1 << ADDR_WIDTH
)(
    input  logic clk,   // Reloj del sistema
    input  logic rst_n, // Reset síncrono (activo en bajo)
    input  logic we,    // Enable de escritura

    input  logic [ADDR_WIDTH-1:0] ra1,   // Dirección de lectura 1
    input  logic [ADDR_WIDTH-1:0] ra2,   // Dirección de lectura 2
    input  logic [ADDR_WIDTH-1:0] wa,    // Dirección de escritura

    input  logic [DATA_WIDTH-1:0] wd,    // Dato de escritura
    input  logic [DATA_WIDTH-1:0] pc_in, // Valor actual del PC
    input  logic [DATA_WIDTH-1:0] lr_in, // Valor actual del LR

    output logic [DATA_WIDTH-1:0] rd1,   // Dato leído 1
    output logic [DATA_WIDTH-1:0] rd2,   // Dato leído 2
    output logic [DATA_WIDTH-1:0] pc_out // Salida del PC
);

    logic [DATA_WIDTH-1:0] regfile_mem [0:DEPTH-1]; // Banco de registros
    integer i;                                      // Índice de reset

    localparam logic [ADDR_WIDTH-1:0] ZERO_REG  = 5'd0;
    localparam logic [ADDR_WIDTH-1:0] PC_REG    = 5'd3;
    localparam logic [ADDR_WIDTH-1:0] LR_REG    = 5'd4;
    localparam logic [ADDR_WIDTH-1:0] DELTA_REG = 5'd30;
    localparam logic [ADDR_WIDTH-1:0] MAX_REG   = 5'd31;

    localparam logic [DATA_WIDTH-1:0] DELTA_CONST   = 32'h9E3779B9; // Constante TEA
    localparam logic [DATA_WIDTH-1:0] MAX_CONST     = 32'hFFFFFFFF; // Constante fija

    // --- Asignacion directa de registros ---
    assign pc_out = (we && (wa == PC_REG)) ? wd : pc_in;

    // --- Logica secuencial (escritura) ---
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            // Limpia todos los registros internos
            for (i = 0; i < DEPTH; i = i + 1) begin
                regfile_mem[i] <= '0;
            end
        end
        else if (we) begin
            // Bloquea escritura en registros especiales
            if ((wa != ZERO_REG) &&
                (wa != PC_REG) &&
                (wa != LR_REG) &&
                (wa != DELTA_REG) &&
                (wa != MAX_REG)) begin
                regfile_mem[wa] <= wd;
            end
        end
    end

    // --- Logica combinacional (lectura) ---
    always_comb begin
        // Lectura del primer operando
        case (ra1)
            ZERO_REG:  rd1 = '0;          // zero
            PC_REG:    rd1 = pc_out;      // pc
            LR_REG:    rd1 = lr_in;       // lr
            DELTA_REG: rd1 = DELTA_CONST; // delta
            MAX_REG:   rd1 = MAX_CONST;   // max
            default: rd1 = (we && (ra1 == wa)) ? wd : regfile_mem[ra1];
        endcase

        // Lectura del segundo operando
        case (ra2)
            ZERO_REG:  rd2 = '0;          // zero
            PC_REG:    rd2 = pc_out;      // pc
            LR_REG:    rd2 = lr_in;       // lr
            DELTA_REG: rd2 = DELTA_CONST; // delta
            MAX_REG:   rd2 = MAX_CONST;   // max
            default: rd2 = (we && (ra2 == wa)) ? wd : regfile_mem[ra2];
        endcase
    end

endmodule