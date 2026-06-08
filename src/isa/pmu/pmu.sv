module pmu #(
    parameter COUNTER_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    
    input  logic event_cache_l1_miss_read,
    input  logic event_cache_l1_miss_write,
    input  logic event_cache_l2_miss_read,
    input  logic event_cache_l2_miss_write,
    input  logic cache_search_ready,
 
    input  logic [4:0]  read_addr,
    output logic [COUNTER_WIDTH-1:0] read_data
);
 
    logic [COUNTER_WIDTH-1:0] val_total_cycles;
    logic [COUNTER_WIDTH-1:0] val_total_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l1_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l2_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l1_read_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l1_write_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l2_read_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l2_write_misses;
 
    // Flags de miss pendiente — se activan cuando ocurre el miss
    // y se confirman/limpian cuando cache_search_ready sube
    logic pending_l1r, pending_l1w, pending_l2r, pending_l2w;
 
    // --- Instanciación del Contador de Ciclos ---
    cycles_counter #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) u_cycles_counter (
        .clk         (clk),
        .rst_n       (rst_n),
        .total_cycles(val_total_cycles)
    );
 
    // --- Lógica de Contadores de Eventos ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            val_total_misses          <= '0;
            val_total_l1_misses       <= '0;
            val_total_l1_read_misses  <= '0;
            val_total_l1_write_misses <= '0;
            val_total_l2_misses       <= '0;
            val_total_l2_read_misses  <= '0;
            val_total_l2_write_misses <= '0;
            pending_l1r <= 1'b0;
            pending_l1w <= 1'b0;
            pending_l2r <= 1'b0;
            pending_l2w <= 1'b0;
        end else begin
 
            // Capturar misses en cuanto ocurren (independiente de ready)
            // SET: se activa cuando llega la señal de miss
            // CLEAR: se limpia cuando ready confirma que el acceso completó
            if (event_cache_l1_miss_read)  pending_l1r <= 1'b1;
            if (event_cache_l1_miss_write) pending_l1w <= 1'b1;
            if (event_cache_l2_miss_read)  pending_l2r <= 1'b1;
            if (event_cache_l2_miss_write) pending_l2w <= 1'b1;
 
            // Cuando ready sube: confirmar pendientes y limpiar
            if (cache_search_ready) begin
                if (pending_l1r) begin
                    val_total_l1_read_misses <= val_total_l1_read_misses + 1'b1;
                    val_total_l1_misses      <= val_total_l1_misses      + 1'b1;
                    val_total_misses         <= val_total_misses          + 1'b1;
                    pending_l1r <= 1'b0;
                end
 
                if (pending_l1w) begin
                    val_total_l1_write_misses <= val_total_l1_write_misses + 1'b1;
                    val_total_l1_misses       <= val_total_l1_misses       + 1'b1;
                    val_total_misses          <= val_total_misses           + 1'b1;
                    pending_l1w <= 1'b0;
                end
 
                if (pending_l2r) begin
                    val_total_l2_read_misses <= val_total_l2_read_misses + 1'b1;
                    val_total_l2_misses      <= val_total_l2_misses      + 1'b1;
                    val_total_misses         <= val_total_misses          + 1'b1;
                    pending_l2r <= 1'b0;
                end
 
                if (pending_l2w) begin
                    val_total_l2_write_misses <= val_total_l2_write_misses + 1'b1;
                    val_total_l2_misses       <= val_total_l2_misses       + 1'b1;
                    val_total_misses          <= val_total_misses           + 1'b1;
                    pending_l2w <= 1'b0;
                end
            end
 
        end
    end
 
    // --- Interfaz de Lectura (Multiplexor) ---
    always_comb begin
        case (read_addr)
            5'd0: read_data = val_total_cycles;
            5'd1: read_data = val_total_misses;
            5'd2: read_data = val_total_l1_misses;
            5'd3: read_data = val_total_l1_read_misses;
            5'd4: read_data = val_total_l1_write_misses;
            5'd5: read_data = val_total_l2_misses;
            5'd6: read_data = val_total_l2_read_misses;
            5'd7: read_data = val_total_l2_write_misses;
            default: read_data = '0;
        endcase
    end
 
endmodule