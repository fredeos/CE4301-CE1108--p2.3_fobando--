// ============================================================================
// Módulo : pmu (Performance Monitoring Unit)
// Archivo: pmu.sv
// ============================================================================
//
// DESCRIPCIÓN GENERAL
// -------------------
// Unidad de Monitoreo de Desempeño (PMU) para el procesador pipeline F32IS.
// Contabiliza eventos de caché en tiempo de simulación y expone los contadores
// a través de una interfaz de lectura por dirección.
//
// DETECCIÓN DE FLANCO DE SUBIDA — APLICADA A TODAS LAS SEÑALES DE EVENTO
// -----------------------------------------------------------------------
// Todas las señales de entrada provenientes de packed_mem y del pipeline son
// señales de NIVEL, no pulsos de un solo ciclo:
//
//   - write_miss / read_miss pueden permanecer activas durante múltiples ciclos
//     mientras la FSM de packed_mem navega los estados de búsqueda y mientras
//     el pipeline está stallado.
//   - write_access / read_access en L2 permanecen activos durante la latencia
//     configurada en el módulo cache (L2_LATENCY ciclos).
//   - wb_en / wb_end_program permanecen constantes durante ciclos de stall del
//     pipeline, lo que sin detección de flanco causaría contar la misma
//     instrucción N veces.
//
// Solución: registrar el estado previo de cada señal (prev_*) y contar
// únicamente en el primer ciclo que la señal pasa de 0 a 1 (flanco de
// subida). Los ciclos subsiguientes con la señal en 1 son ignorados.
//
//   Ejemplo para una señal que dura 4 ciclos:
//
//   Ciclo │ señal │ prev │ rise │ Contador
//   ──────┼───────┼──────┼──────┼─────────
//     N   │   0   │  0   │  0   │   0
//    N+1  │   1   │  0   │  1   │   1   ← se cuenta
//    N+2  │   1   │  1   │  0   │   1   ← ignorado
//    N+3  │   1   │  1   │  0   │   1   ← ignorado
//    N+4  │   0   │  1   │  0   │   1
//
// PROBLEMA DE MÚLTIPLES <= AL MISMO REGISTRO EN always_ff
// --------------------------------------------------------
// Se usan acumuladores combinacionales (delta_*) para evitar que múltiples
// asignaciones no bloqueantes al mismo registro en el mismo ciclo se
// sobreescriban mutuamente.
//
// INTERFAZ DE LECTURA
// -------------------
// Mapa de registros (read_addr):
//   0  → Total de ciclos
//   1  → Total de misses (L1 + L2)
//   2  → Total de misses L1 (R + W)
//   3  → Misses de lectura  L1
//   4  → Misses de escritura L1
//   5  → Total de misses L2 (R + W)
//   6  → Misses de lectura  L2
//   7  → Misses de escritura L2
//   8  → Accesos totales L1
//   9  → Accesos totales L2
//   10 → Accesos totales a Memoria
//   11 → Instrucciones totales ejecutadas
//   12 → Ciclos de stall por control (branches)
//
// ============================================================================

module pmu #(
    parameter COUNTER_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // ------------------------------------------------------------------
    // Eventos de caché — señales de NIVEL provenientes de packed_mem.
    // Pueden permanecer activas durante múltiples ciclos consecutivos.
    // El PMU las convierte a flanco de subida para contar exactamente
    // una vez por operación real de memoria.
    // ------------------------------------------------------------------
    input  logic event_cache_l1_miss_read,
    input  logic event_cache_l1_miss_write,
    input  logic event_cache_l2_miss_read,
    input  logic event_cache_l2_miss_write,
    input  logic event_cache_l1_write_access,
    input  logic event_cache_l1_read_access,
    input  logic event_cache_l2_write_access,
    input  logic event_cache_l2_read_access,
    input  logic event_mem_write_access,
    input  logic event_mem_read_access,

    input  logic cache_search_ready,   // Reservado para extensiones futuras

    // --- Señales del pipeline para contar instrucciones ---
    // wb_en     : Activo (lógica dependiente del diseño) indica instrucción válida
    // wb_instr  : Instrucción presente en el stage WB
    // wb_end_program : Indica fin del programa (no contar más instrucciones)
    input  logic [31:0] wb_instr,
    input  logic        wb_en,
    input  logic        wb_end_program,

    // --- Señal de branch tomado para contar stalls de control ---
    input  logic event_branch_taken,

    // --- Interfaz de lectura ---
    input  logic [4:0]               read_addr,
    output logic [COUNTER_WIDTH-1:0] read_data
);

    // ================================================================
    // CONTADORES INTERNOS
    // ================================================================

    logic [COUNTER_WIDTH-1:0] val_total_cycles;
    logic [COUNTER_WIDTH-1:0] val_total_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l1_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l2_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l1_read_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l1_write_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l2_read_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l2_write_misses;
    logic [COUNTER_WIDTH-1:0] val_total_l1_accesses;
    logic [COUNTER_WIDTH-1:0] val_total_l2_accesses;
    logic [COUNTER_WIDTH-1:0] val_total_mem_accesses;
    logic [COUNTER_WIDTH-1:0] val_total_inst_count;
    logic [COUNTER_WIDTH-1:0] val_total_branch_stalls;

    // ================================================================
    // REGISTROS DE ESTADO PREVIO — DETECCIÓN DE FLANCO
    // ================================================================
    // Cada señal de evento tiene su propio registro prev_* independiente.
    // Esto es fundamental: registros compartidos enmascararían eventos
    // simultáneos sobre señales distintas.

    // Señales de miss de caché
    logic prev_l1r;           // prev de event_cache_l1_miss_read
    logic prev_l1w;           // prev de event_cache_l1_miss_write
    logic prev_l2r;           // prev de event_cache_l2_miss_read
    logic prev_l2w;           // prev de event_cache_l2_miss_write

    // Señales de acceso a caché y memoria
    logic prev_l1_write_acc;  // prev de event_cache_l1_write_access
    logic prev_l1_read_acc;   // prev de event_cache_l1_read_access
    logic prev_l2_write_acc;  // prev de event_cache_l2_write_access
    logic prev_l2_read_acc;   // prev de event_cache_l2_read_access
    logic prev_mem_write_acc; // prev de event_mem_write_access
    logic prev_mem_read_acc;  // prev de event_mem_read_access

    // Señal de branch tomado
    logic prev_branch_taken;

    // ----------------------------------------------------------------
    // DETECCIÓN DE FLANCO PARA INSTRUCCIONES
    // ----------------------------------------------------------------
    // valid_instr es la señal combinacional que indica "hay una
    // instrucción nueva válida para contar en el stage WB".
    // Se aplica detección de flanco de subida sobre esta señal para
    // contar exactamente una vez aunque el pipeline esté stallado y
    // mantenga la misma instrucción en WB durante N ciclos.
    //
    //   Condiciones para instrucción válida a contar:
    //   - wb_instr != 32'h00000080 : no es NOP/instrucción de relleno
    //   - ~wb_en                   : wb_en=0 indica instrucción a contar
    //   - !wb_end_program          : el programa no ha terminado
    // ----------------------------------------------------------------
    logic prev_valid_instr;   // prev del estado combinacional valid_instr

    // ================================================================
    // SEÑALES COMBINACIONALES DE FLANCO DE SUBIDA
    // ================================================================
    // rise_X = 1 ÚNICAMENTE en el primer ciclo en que la señal X pasa
    // de 0 a 1. Todos los ciclos posteriores con X=1 producen rise_X=0.

    // Misses de caché
    wire rise_l1r = event_cache_l1_miss_read  & ~prev_l1r;
    wire rise_l1w = event_cache_l1_miss_write & ~prev_l1w;
    wire rise_l2r = event_cache_l2_miss_read  & ~prev_l2r;
    wire rise_l2w = event_cache_l2_miss_write & ~prev_l2w;

    // Accesos a caché y memoria
    wire rise_l1_write_acc  = event_cache_l1_write_access & ~prev_l1_write_acc;
    wire rise_l1_read_acc   = event_cache_l1_read_access  & ~prev_l1_read_acc;
    wire rise_l2_write_acc  = event_cache_l2_write_access & ~prev_l2_write_acc;
    wire rise_l2_read_acc   = event_cache_l2_read_access  & ~prev_l2_read_acc;
    wire rise_mem_write_acc = event_mem_write_access       & ~prev_mem_write_acc;
    wire rise_mem_read_acc  = event_mem_read_access        & ~prev_mem_read_acc;

    // Branch tomado
    wire rise_branch_taken  = event_branch_taken & ~prev_branch_taken;

    // Instrucción válida en WB (con detección de flanco para evitar
    // contar la misma instrucción múltiples veces durante un stall)
    wire valid_instr      = (~wb_en) & (~wb_end_program) & (wb_instr != 32'h00000080);
    wire rise_valid_instr = valid_instr & ~prev_valid_instr;

    // ================================================================
    // ACUMULADORES COMBINACIONALES DE DELTA
    // ================================================================
    // Calculan el incremento total de cada contador en el ciclo actual,
    // sumando la contribución de todos los eventos simultáneos.
    // Necesarios porque en SystemVerilog múltiples <= al mismo registro
    // dentro del mismo always_ff dejan solo la última asignación activa.

    logic [COUNTER_WIDTH-1:0] delta_total_misses;
    logic [COUNTER_WIDTH-1:0] delta_l1;
    logic [COUNTER_WIDTH-1:0] delta_l2;
    logic [COUNTER_WIDTH-1:0] delta_l1_accesses;
    logic [COUNTER_WIDTH-1:0] delta_l2_accesses;
    logic [COUNTER_WIDTH-1:0] delta_mem_accesses;

    always_comb begin
        delta_total_misses = '0;
        delta_l1           = '0;
        delta_l2           = '0;
        delta_l1_accesses  = '0;
        delta_l2_accesses  = '0;
        delta_mem_accesses = '0;

        // Misses: solo se suman en el flanco de subida de cada señal
        if (rise_l1r) begin
            delta_total_misses = delta_total_misses + 1;
            delta_l1           = delta_l1           + 1;
        end
        if (rise_l1w) begin
            delta_total_misses = delta_total_misses + 1;
            delta_l1           = delta_l1           + 1;
        end
        if (rise_l2r) begin
            delta_total_misses = delta_total_misses + 1;
            delta_l2           = delta_l2           + 1;
        end
        if (rise_l2w) begin
            delta_total_misses = delta_total_misses + 1;
            delta_l2           = delta_l2           + 1;
        end

        // Accesos: solo se suman en el flanco de subida de cada señal
        if (rise_l1_read_acc)   delta_l1_accesses  = delta_l1_accesses  + 1;
        if (rise_l1_write_acc)  delta_l1_accesses  = delta_l1_accesses  + 1;
        if (rise_l2_read_acc)   delta_l2_accesses  = delta_l2_accesses  + 1;
        if (rise_l2_write_acc)  delta_l2_accesses  = delta_l2_accesses  + 1;
        if (rise_mem_read_acc)  delta_mem_accesses = delta_mem_accesses  + 1;
        if (rise_mem_write_acc) delta_mem_accesses = delta_mem_accesses  + 1;
    end

    // ================================================================
    // SUBMÓDULO: CONTADOR DE CICLOS
    // ================================================================
    cycles_counter #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) u_cycles_counter (
        .clk         (clk),
        .rst_n       (rst_n),
        .total_cycles(val_total_cycles)
    );

    // ================================================================
    // LÓGICA SECUENCIAL: ACTUALIZACIÓN DE CONTADORES Y REGISTROS PREV
    // ================================================================
    // Reset asíncrono activo en BAJO (negedge rst_n).
    // Todos los contadores y registros prev se inicializan a 0.
    //
    // En cada posedge clk:
    //   Paso 1 - Actualizar registros prev_* con el estado actual de
    //            cada señal (para calcular flancos en el próximo ciclo).
    //   Paso 2 - Incrementar contadores individuales de miss (un único
    //            rise_* por contador, sin riesgo de colisión).
    //   Paso 3 - Incrementar contadores agregados usando deltas.

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset de contadores
            val_total_misses          <= '0;
            val_total_l1_misses       <= '0;
            val_total_l1_read_misses  <= '0;
            val_total_l1_write_misses <= '0;
            val_total_l2_misses       <= '0;
            val_total_l2_read_misses  <= '0;
            val_total_l2_write_misses <= '0;
            val_total_l1_accesses     <= '0;
            val_total_l2_accesses     <= '0;
            val_total_mem_accesses    <= '0;
            val_total_inst_count      <= '0;
            val_total_branch_stalls   <= '0;

            // Reset de registros prev_*.
            // Se ponen a 0 para que una señal ya activa al salir del reset
            // sea detectada correctamente como flanco de subida.
            prev_l1r           <= 1'b0;
            prev_l1w           <= 1'b0;
            prev_l2r           <= 1'b0;
            prev_l2w           <= 1'b0;
            prev_l1_write_acc  <= 1'b0;
            prev_l1_read_acc   <= 1'b0;
            prev_l2_write_acc  <= 1'b0;
            prev_l2_read_acc   <= 1'b0;
            prev_mem_write_acc <= 1'b0;
            prev_mem_read_acc  <= 1'b0;
            prev_branch_taken  <= 1'b0;
            prev_valid_instr   <= 1'b0;

        end else begin

            // ----------------------------------------------------------
            // Paso 1: Capturar estado actual en registros previos.
            // Se actualizan siempre, independientemente de si hubo flanco.
            // ----------------------------------------------------------
            prev_l1r           <= event_cache_l1_miss_read;
            prev_l1w           <= event_cache_l1_miss_write;
            prev_l2r           <= event_cache_l2_miss_read;
            prev_l2w           <= event_cache_l2_miss_write;
            prev_l1_write_acc  <= event_cache_l1_write_access;
            prev_l1_read_acc   <= event_cache_l1_read_access;
            prev_l2_write_acc  <= event_cache_l2_write_access;
            prev_l2_read_acc   <= event_cache_l2_read_access;
            prev_mem_write_acc <= event_mem_write_access;
            prev_mem_read_acc  <= event_mem_read_access;
            prev_branch_taken  <= event_branch_taken;
            prev_valid_instr   <= valid_instr;  // ← Flanco para instrucciones

            // ----------------------------------------------------------
            // Paso 2: Contadores individuales de miss.
            // Cada uno tiene una única señal rise_* que lo activa;
            // no hay riesgo de colisión entre asignaciones <=.
            // ----------------------------------------------------------
            if (rise_l1r) val_total_l1_read_misses  <= val_total_l1_read_misses  + 1'b1;
            if (rise_l1w) val_total_l1_write_misses <= val_total_l1_write_misses + 1'b1;
            if (rise_l2r) val_total_l2_read_misses  <= val_total_l2_read_misses  + 1'b1;
            if (rise_l2w) val_total_l2_write_misses <= val_total_l2_write_misses + 1'b1;

            // Stalls de control: cada branch tomado genera 3 ciclos de burbuja
            if (rise_branch_taken) val_total_branch_stalls <= val_total_branch_stalls + 32'd3;

            // Instrucciones: contar solo en el primer ciclo que la instrucción
            // válida aparece en WB (flanco de subida de valid_instr).
            // Esto evita contar múltiples veces durante stalls del pipeline.
            if (rise_valid_instr) val_total_inst_count <= val_total_inst_count + 1'b1;

            // ----------------------------------------------------------
            // Paso 3: Contadores agregados usando deltas combinacionales.
            // El delta ya suma las contribuciones de todos los eventos del
            // ciclo actual; una sola escritura <= por registro es suficiente.
            // ----------------------------------------------------------
            if (delta_total_misses > 0) val_total_misses    <= val_total_misses    + delta_total_misses;
            if (delta_l1           > 0) val_total_l1_misses <= val_total_l1_misses + delta_l1;
            if (delta_l2           > 0) val_total_l2_misses <= val_total_l2_misses + delta_l2;
            if (delta_l1_accesses  > 0) val_total_l1_accesses  <= val_total_l1_accesses  + delta_l1_accesses;
            if (delta_l2_accesses  > 0) val_total_l2_accesses  <= val_total_l2_accesses  + delta_l2_accesses;
            if (delta_mem_accesses > 0) val_total_mem_accesses <= val_total_mem_accesses  + delta_mem_accesses;

        end
    end

    // ================================================================
    // INTERFAZ DE LECTURA: MULTIPLEXOR COMBINACIONAL DE CONTADORES
    // ================================================================
    always_comb begin
        case (read_addr)
            5'd0:    read_data = val_total_cycles;
            5'd1:    read_data = val_total_misses;
            5'd2:    read_data = val_total_l1_misses;
            5'd3:    read_data = val_total_l1_read_misses;
            5'd4:    read_data = val_total_l1_write_misses;
            5'd5:    read_data = val_total_l2_misses;
            5'd6:    read_data = val_total_l2_read_misses;
            5'd7:    read_data = val_total_l2_write_misses;
            5'd8:    read_data = val_total_l1_accesses;
            5'd9:    read_data = val_total_l2_accesses;
            5'd10:   read_data = val_total_mem_accesses;
            5'd11:   read_data = val_total_inst_count;
            5'd12:   read_data = val_total_branch_stalls;
            default: read_data = '0;
        endcase
    end

endmodule