module cycles_counter #(
    parameter COUNTER_WIDTH = 32 // Contador de 32 bits
)(
    input  logic clk,
    input  logic rst_n, // Reset asíncrono activo en bajo

    output logic [COUNTER_WIDTH-1:0] total_cycles
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_cycles <= '0; // Resetea todos los bits a 0
        end else begin
            total_cycles <= total_cycles + 1'b1; // Asignación no bloqueante
        end
    end

endmodule