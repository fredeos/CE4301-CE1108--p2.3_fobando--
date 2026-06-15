// ============================================================================
// Módulo : pmu (Performance Monitoring Unit)
// Archivo: pmu.sv
// ============================================================================
//
// DESCRIPCIÓN GENERAL
// -------------------
// Unidad de Monitoreo de Desempeño (PMU) para el procesador pipeline F32IS.
// Contabiliza eventos de caché en tiempo de simulación y expone los contadores
// a través de una interfaz de lectura por dirección, permitiendo que el
// testbench o el software de sistema consulten las métricas de desempeño al
// final de la ejecución.
//
// Los eventos monitoreados son:
//   - Misses de lectura  en L1 (caché de datos nivel 1)
//   - Misses de escritura en L1
//   - Misses de lectura  en L2 (caché de datos nivel 2)
//   - Misses de escritura en L2
//   - Total de ciclos ejecutados
//
// PROBLEMA DE DISEÑO: SEÑALES DE NIVEL vs. PULSOS
// ------------------------------------------------
// Las señales de miss que llegan al PMU desde packed_mem son señales
// COMBINACIONALES DE NIVEL, no pulsos de un solo ciclo. Esto ocurre porque:
//
//   1. La caché L1 produce write_miss = ~hit & rdy, que permanece activa
//      todos los ciclos que WE=1 con la misma dirección (incluyendo ciclos
//      de stall del pipeline).
//
//   2. Similarmente, read_miss permanece activa mientras RE=1 y la FSM de
//      packed_mem navega los estados de búsqueda en L2 y memoria principal.
//
// Si el PMU contara directamente estas señales, un solo STORE que provoca
// un stall de 10 ciclos generaría 10 misses en lugar de 1.
//
// SOLUCIÓN: DETECCIÓN DE FLANCO DE SUBIDA
// ----------------------------------------
// El PMU registra el estado de cada señal en el ciclo anterior (prev_*) y
// cuenta el miss únicamente en el primer ciclo que la señal pasa de 0 a 1
// (flanco de subida). Los ciclos subsiguientes donde la señal permanece en 1
// son ignorados.
//
//   Ejemplo para un STORE con stall de 3 ciclos:
//
//   Ciclo │ event_l1_miss_write │ prev_l1w │ rise_l1w │ Contador
//   ──────┼─────────────────────┼──────────┼──────────┼─────────
//     N   │          0          │    0     │    0     │    0
//    N+1  │          1          │    0     │    1     │    1   ← se cuenta
//    N+2  │          1          │    1     │    0     │    1   ← ignorado
//    N+3  │          1          │    1     │    0     │    1   ← ignorado
//    N+4  │          0          │    1     │    0     │    1
//
// PROBLEMA DE DISEÑO: MÚLTIPLES <= AL MISMO REGISTRO EN always_ff
// ----------------------------------------------------------------
// En SystemVerilog, si un bloque always_ff contiene múltiples asignaciones
// no bloqueantes (<=) al mismo registro dentro de ramas if independientes,
// solo sobrevive la última asignación evaluada en ese delta de simulación.
//
//   Ejemplo del bug:
//     if (rise_l1r) val_total_misses <= val_total_misses + 1; // asignación A
//     if (rise_l1w) val_total_misses <= val_total_misses + 1; // asignación B
//     // Si ambas condiciones son true, solo B tiene efecto. Se pierde A.
//
// SOLUCIÓN: ACUMULADORES COMBINACIONALES (delta_*)
// -------------------------------------------------
// Los deltas de incremento se calculan previamente en un bloque always_comb,
// sumando la contribución de todos los eventos que ocurren en el mismo ciclo.
// El always_ff realiza una única escritura por registro usando ese delta.
//
//   Ejemplo corregido:
//     // En always_comb:
//     if (rise_l1r) delta_total_misses = delta_total_misses + 1;
//     if (rise_l1w) delta_total_misses = delta_total_misses + 1;
//     // En always_ff: una sola escritura, delta ya tiene el total correcto
//     if (delta_total_misses > 0) val_total_misses <= val_total_misses + delta_total_misses;
//
// INTERFAZ DE LECTURA
// -------------------
// Los contadores se exponen mediante un multiplexor direccionado por read_addr.
// El mapa de registros es:
//
//   Addr │ Registro
//   ─────┼──────────────────────────────
//    0   │ Total de ciclos
//    1   │ Total de misses (L1 + L2)
//    2   │ Total de misses L1 (R + W)
//    3   │ Misses de lectura  L1
//    4   │ Misses de escritura L1
//    5   │ Total de misses L2 (R + W)
//    6   │ Misses de lectura  L2
//    7   │ Misses de escritura L2
//
// PARÁMETROS
// ----------
//   COUNTER_WIDTH : Ancho en bits de todos los contadores (default: 32).
//                   Con 32 bits se pueden contabilizar hasta 4,294,967,295
//                   eventos antes de desbordarse.
//
// PUERTOS
// -------
//   clk                     : Reloj del sistema (flanco de subida activo)
//   rst_n                   : Reset asíncrono activo en bajo
//   event_cache_l1_miss_read : Nivel alto cuando hay miss de lectura en L1
//   event_cache_l1_miss_write: Nivel alto cuando hay miss de escritura en L1
//   event_cache_l2_miss_read : Nivel alto cuando hay miss de lectura en L2
//   event_cache_l2_miss_write: Nivel alto cuando hay miss de escritura en L2
//   cache_search_ready       : Señal de ready de packed_mem (no usada para
//                              conteo, disponible para extensiones futuras)
//   read_addr [4:0]          : Dirección del contador a leer
//   read_data [COUNTER_WIDTH-1:0]: Valor del contador seleccionado
//
// DEPENDENCIAS
// ------------
//   cycles_counter : Submódulo que cuenta ciclos de reloj de forma continua.
//
// ============================================================================

module pmu #(
    parameter COUNTER_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // ------------------------------------------------------------------
    // Eventos de caché — señales de NIVEL provenientes de packed_mem.
    // Pueden permanecer activas durante múltiples ciclos consecutivos
    // mientras el pipeline está stallado por un miss. El PMU convierte
    // internamente cada nivel en un flanco de subida para contabilizar
    // exactamente un miss por operación real de memoria.
    // ------------------------------------------------------------------
    input  logic event_cache_l1_miss_read,   // Miss de lectura  activo en L1
    input  logic event_cache_l1_miss_write,  // Miss de escritura activo en L1
    input  logic event_cache_l2_miss_read,   // Miss de lectura  activo en L2
    input  logic event_cache_l2_miss_write,  // Miss de escritura activo en L2
    input  logic event_cache_l1_write_access,
    input  logic event_cache_l1_read_access,      
    input  logic event_cache_l2_write_access,
    input  logic event_cache_l2_read_access,
    input  logic event_mem_write_access,
    input  logic event_mem_read_access,    
    // Señal de finalización de búsqueda en caché. No se utiliza actualmente
    // para el conteo (la detección de flanco lo hace innecesario), pero se
    // mantiene en la interfaz para posibles extensiones futuras como medir
    // latencia de miss o contabilizar hits.
    input  logic cache_search_ready,

    // --- Señales para contar instrucciones ---
    input [31:0] wb_instr,
    input wb_en,
    input wb_end_program,


    // ------------------------------------------------------------------
    // Interfaz de lectura de contadores.
    // read_addr selecciona qué contador exponer en read_data.
    // La lectura es puramente combinacional (sin latencia).
    // ------------------------------------------------------------------
    input  logic [4:0]  read_addr,
    output logic [COUNTER_WIDTH-1:0] read_data
);

    // ================================================================
    // CONTADORES INTERNOS
    // ================================================================
    // Todos los contadores son registros síncronos de COUNTER_WIDTH bits.
    // Se inicializan a cero en reset y solo incrementan, nunca decrementan.

    logic [COUNTER_WIDTH-1:0] val_total_cycles;        // Ciclos totales de ejecución
    logic [COUNTER_WIDTH-1:0] val_total_misses;        // Suma de todos los misses (L1 + L2)
    logic [COUNTER_WIDTH-1:0] val_total_l1_misses;     // Misses totales en L1 (R + W)
    logic [COUNTER_WIDTH-1:0] val_total_l2_misses;     // Misses totales en L2 (R + W)
    logic [COUNTER_WIDTH-1:0] val_total_l1_read_misses;  // Misses de lectura  en L1
    logic [COUNTER_WIDTH-1:0] val_total_l1_write_misses; // Misses de escritura en L1
    logic [COUNTER_WIDTH-1:0] val_total_l2_read_misses;  // Misses de lectura  en L2
    logic [COUNTER_WIDTH-1:0] val_total_l2_write_misses; // Misses de escritura en L2
    logic [COUNTER_WIDTH-1:0] val_total_l1_accesses;    // Accessos en L1
    logic [COUNTER_WIDTH-1:0] val_total_l2_accesses;    // Accessos en L2
    logic [COUNTER_WIDTH-1:0] val_total_mem_accesses;    // Accessos a Memoria
    logic [COUNTER_WIDTH-1:0] val_total_inst_count;       //Instrucciones totales

    // ================================================================
    // DETECCIÓN DE FLANCO DE SUBIDA
    // ================================================================
    // Cada señal de evento tiene su propio registro de estado previo,
    // completamente independiente de los demás. Esto es crítico:
    // si se compartiera un único registro prev, eventos simultáneos
    // sobre distintas señales podrían enmascararse mutuamente.
    //
    // prev_l1r rastrea exclusivamente event_cache_l1_miss_read
    // prev_l1w rastrea exclusivamente event_cache_l1_miss_write
    // prev_l2r rastrea exclusivamente event_cache_l2_miss_read
    // prev_l2w rastrea exclusivamente event_cache_l2_miss_write
    // prev_l1_write_acc / prev_l1_read_acc rastrean event_cache_l1_write/read_access
    // prev_l2_write_acc / prev_l2_read_acc rastrean event_cache_l2_write/read_access

    logic prev_l1r;  // Estado de event_cache_l1_miss_read  en el ciclo anterior
    logic prev_l1w;  // Estado de event_cache_l1_miss_write en el ciclo anterior
    logic prev_l2r;  // Estado de event_cache_l2_miss_read  en el ciclo anterior
    logic prev_l2w;  // Estado de event_cache_l2_miss_write en el ciclo anterior
    logic prev_l1_write_acc;   // Estado de event_cache_l1_write_access en el ciclo anterior
    logic prev_l1_read_acc;    // Estado de event_cache_l1_read_access  en el ciclo anterior
    logic prev_l2_write_acc;   // Estado de event_cache_l2_write_access en el ciclo anterior
    logic prev_l2_read_acc;    // Estado de event_cache_l2_read_access  en el ciclo anterior
    logic prev_mem_write_acc;  // Estado de event_mem_write_access en el ciclo anterior
    logic prev_mem_read_acc;   // Estado de event_mem_read_access  en el ciclo anterior

    // Flancos de subida (rise = rising edge):
    // rise_XY = 1 únicamente el primer ciclo que event_XY pasa de 0 a 1.
    // Todos los ciclos posteriores donde event_XY permanece en 1 producen
    // rise_XY = 0, ya que prev_XY también será 1.
    wire rise_l1r = event_cache_l1_miss_read  & ~prev_l1r;
    wire rise_l1w = event_cache_l1_miss_write & ~prev_l1w;
    wire rise_l2r = event_cache_l2_miss_read  & ~prev_l2r;
    wire rise_l2w = event_cache_l2_miss_write & ~prev_l2w;


    // Flancos de subida para señales de acceso a caché.
    // Permiten contabilizar exactamente un acceso por operación aunque la
    // señal permanezca alta varios ciclos durante un stall.
    wire rise_l1_write_acc  = event_cache_l1_write_access & ~prev_l1_write_acc;
    wire rise_l1_read_acc   = event_cache_l1_read_access  & ~prev_l1_read_acc;
    wire rise_l2_write_acc  = event_cache_l2_write_access & ~prev_l2_write_acc;
    wire rise_l2_read_acc   = event_cache_l2_read_access  & ~prev_l2_read_acc;
    wire rise_mem_write_acc = event_mem_write_access       & ~prev_mem_write_acc;
    wire rise_mem_read_acc  = event_mem_read_access        & ~prev_mem_read_acc;
    

    // ================================================================
    // ACUMULADORES COMBINACIONALES DE DELTA
    // ================================================================
    // Calculan cuánto debe incrementar cada contador agregado en este ciclo,
    // considerando todos los eventos que ocurran simultáneamente.
    //
    // Por qué son necesarios:
    //   En SystemVerilog, si un bloque always_ff asigna el mismo registro
    //   varias veces con <=, solo la última asignación tiene efecto. Si en
    //   el mismo ciclo rise_l1r=1 y rise_l1w=1, ambos intentarían hacer:
    //     val_total_l1_misses <= val_total_l1_misses + 1  (por rise_l1r)
    //     val_total_l1_misses <= val_total_l1_misses + 1  (por rise_l1w)
    //   Solo la segunda asignación sobreviviría, perdiendo un miss.
    //
    //   Con delta_l1, ambas contribuciones se suman primero en lógica
    //   combinacional (delta_l1 = 2) y luego se aplican con una sola <=.
    //
    // delta_total_misses : incremento para val_total_misses    (todos los niveles)
    // delta_l1           : incremento para val_total_l1_misses (solo misses L1)
    // delta_l2           : incremento para val_total_l2_misses (solo misses L2)
    // delta_l1_accesses  : incremento para val_total_l1_accesses (accesos a L1)
    // delta_l2_accesses  : incremento para val_total_l2_accesses (accesos a L2)

    logic [COUNTER_WIDTH-1:0] delta_total_misses;
    logic [COUNTER_WIDTH-1:0] delta_l1;
    logic [COUNTER_WIDTH-1:0] delta_l2;
    logic [COUNTER_WIDTH-1:0] delta_l1_accesses;
    logic [COUNTER_WIDTH-1:0] delta_l2_accesses;
    logic [COUNTER_WIDTH-1:0] delta_mem_accesses;

    always_comb begin
        // Inicializar a cero; se suma solo si el flanco correspondiente está activo
        delta_total_misses   = '0;
        delta_l1             = '0;
        delta_l2             = '0;
        delta_l1_accesses    = '0;
        delta_l2_accesses    = '0;
        delta_mem_accesses   = '0;

        // Los accesos también se detectan por flanco de subida para evitar
        // contar múltiples veces el mismo acceso durante ciclos de stall.
        if (rise_l1r) begin
            delta_total_misses = delta_total_misses + 1;
            delta_l1    = delta_l1    + 1;
        end

        if (rise_l1w) begin
            delta_total_misses = delta_total_misses + 1;
            delta_l1    = delta_l1    + 1;
        end

        if (rise_l2r) begin
            delta_total_misses = delta_total_misses + 1;
            delta_l2    = delta_l2    + 1;
        end

        if (rise_l2w) begin
            delta_total_misses = delta_total_misses + 1;
            delta_l2    = delta_l2    + 1;
        end

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
    // cycles_counter es un contador libre que incrementa en cada flanco
    // de subida del reloj mientras rst_n=1. Se instancia como submódulo
    // separado para mantener la claridad del diseño y permitir que el
    // contador de ciclos tenga su propia lógica de reset si fuera necesario.

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
    // Reset asíncrono activo en bajo (negedge rst_n):
    //   Todos los contadores y registros de estado previo se ponen a 0.
    //
    // En operación normal (posedge clk):
    //   1. Se actualizan los registros prev_* con el estado actual de
    //      cada señal de evento, para que en el próximo ciclo se pueda
    //      calcular correctamente el flanco de subida.
    //
    //   2. Los contadores individuales (por tipo de miss) se incrementan
    //      directamente cuando su flanco correspondiente está activo.
    //      No hay riesgo de colisión porque cada contador tiene una sola
    //      señal rise_* que lo puede activar.
    //
    //   3. Los contadores agregados (total_misses, l1_misses, l2_misses)
    //      se incrementan usando los deltas combinacionales, garantizando
    //      una única escritura por registro por ciclo.

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset de todos los contadores de eventos
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

            // Reset de registros de estado previo para la detección de flanco.
            // Se ponen a 0 para que si la señal ya está en 1 al salir del
            // reset, se detecte correctamente como flanco de subida.
            prev_l1r <= 1'b0;
            prev_l1w <= 1'b0;
            prev_l2r <= 1'b0;
            prev_l2w <= 1'b0;
            prev_l1_write_acc  <= 1'b0;
            prev_l1_read_acc   <= 1'b0;
            prev_l2_write_acc  <= 1'b0;
            prev_l2_read_acc   <= 1'b0;
            prev_mem_write_acc <= 1'b0;
            prev_mem_read_acc  <= 1'b0;

        end else begin

            // --------------------------------------------------------------
            // Paso 1: Capturar estado actual en registros previos.
            // Estos valores serán usados en el PRÓXIMO ciclo para calcular
            // los flancos de subida. Se actualizan siempre, independientemente
            // de si hubo un flanco o no.
            // --------------------------------------------------------------
            prev_l1r <= event_cache_l1_miss_read;
            prev_l1w <= event_cache_l1_miss_write;
            prev_l2r <= event_cache_l2_miss_read;
            prev_l2w <= event_cache_l2_miss_write;

            prev_l1_write_acc  <= event_cache_l1_write_access;
            prev_l1_read_acc   <= event_cache_l1_read_access;
            prev_l2_write_acc  <= event_cache_l2_write_access;
            prev_l2_read_acc   <= event_cache_l2_read_access;
            prev_mem_write_acc <= event_mem_write_access;
            prev_mem_read_acc  <= event_mem_read_access;

            // --------------------------------------------------------------
            // Paso 2: Incrementar contadores individuales de miss.
            // Cada contador hoja (por tipo de miss) tiene una única señal
            // rise_* que lo puede activar, por lo que no hay riesgo de
            // colisión entre asignaciones <=.
            // Los contadores de acceso (L1/L2) no están aquí: se actualizan
            // exclusivamente vía delta en el Paso 3, porque rise_l1_write_acc
            // y rise_l1_read_acc pueden ser ambos 1 en el mismo ciclo y
            // ambos modificarían val_total_l1_accesses → solo sobreviviría
            // la segunda asignación. El delta resuelve esto.
            // --------------------------------------------------------------
            if (rise_l1r) val_total_l1_read_misses  <= val_total_l1_read_misses  + 1'b1;
            if (rise_l1w) val_total_l1_write_misses <= val_total_l1_write_misses + 1'b1;
            if (rise_l2r) val_total_l2_read_misses  <= val_total_l2_read_misses  + 1'b1;
            if (rise_l2w) val_total_l2_write_misses <= val_total_l2_write_misses + 1'b1;

            // --------------------------------------------------------------
            // Paso 3: Incrementar contadores agregados usando deltas.
            // Los deltas fueron calculados combinacionalmente antes del flanco
            // de reloj, considerando todos los eventos del ciclo actual.
            // La condición "> 0" evita escrituras innecesarias cuando no hubo
            // ningún evento, aunque el resultado sería idéntico sin ella.
            // --------------------------------------------------------------
            if (delta_total_misses > 0) val_total_misses    <= val_total_misses    + delta_total_misses;
            if (delta_l1    > 0) val_total_l1_misses <= val_total_l1_misses + delta_l1;
            if (delta_l2    > 0) val_total_l2_misses <= val_total_l2_misses + delta_l2;

            if (delta_l1_accesses  > 0) val_total_l1_accesses  <= val_total_l1_accesses  + delta_l1_accesses;
            if (delta_l2_accesses  > 0) val_total_l2_accesses  <= val_total_l2_accesses  + delta_l2_accesses;
            if (delta_mem_accesses > 0) val_total_mem_accesses <= val_total_mem_accesses + delta_mem_accesses;

        end
    end


    // Lógica del contador interna en la PMU
    always_ff @(posedge clk or posedge rst_n) begin
        if (!rst_n) begin
            val_total_inst_count <= '0;
        end else begin
            if ((wb_instr != 32'h00000080) && (~wb_en) && (!wb_end_program)) begin
                val_total_inst_count <= val_total_inst_count + 1;
            end
        end
    end

    // ================================================================
    // INTERFAZ DE LECTURA: MULTIPLEXOR DE CONTADORES
    // ================================================================
    // Lectura puramente combinacional: sin latencia desde que se presenta
    // read_addr hasta que read_data refleja el valor correspondiente.
    //
    // Mapa de registros:
    //   0 → val_total_cycles         (ciclos totales)
    //   1 → val_total_misses         (todos los misses L1 + L2)
    //   2 → val_total_l1_misses      (misses L1, lectura + escritura)
    //   3 → val_total_l1_read_misses (misses de lectura  en L1)
    //   4 → val_total_l1_write_misses(misses de escritura en L1)
    //   5 → val_total_l2_misses      (misses L2, lectura + escritura)
    //   6 → val_total_l2_read_misses (misses de lectura  en L2)
    //   7 → val_total_l2_write_misses(misses de escritura en L2)
    //   8 → val_total_l1_accesses    (Accesos a L1)
    //   9 → val_total_l2_accesses    (Accesos a L2)
    //   default → 0 (dirección no definida, retorna cero)

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
            5'd8: read_data = val_total_l1_accesses;
            5'd9:  read_data = val_total_l2_accesses;
            5'd10: read_data = val_total_mem_accesses;
            5'd11: read_data = val_total_inst_count;
            default: read_data = '0;
        endcase
    end

endmodule