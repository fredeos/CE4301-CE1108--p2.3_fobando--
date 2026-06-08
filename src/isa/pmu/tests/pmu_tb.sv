`timescale 1ns / 1ps

module tb_pmu;

    // Parámetros
    parameter WIDTH = 32;

    // Señales (Inputs del DUT)
    logic clk;
    logic rst_n;
    logic event_cache_l1_miss_read;
    logic event_cache_l1_miss_write;
    logic event_cache_l2_miss_read;
    logic event_cache_l2_miss_write;
    logic cache_search_ready;
    logic [4:0] read_addr;

    // Salidas (del DUT)
    logic [WIDTH-1:0] read_data;

    // Instancia del módulo PMU
    pmu #(.COUNTER_WIDTH(WIDTH)) dut (.*);

    // Generador de reloj
    always #5 clk = ~clk;

    // Tarea para leer un registro de la PMU
    task automatic read_pmu(input logic [4:0] addr);
        begin
            @(posedge clk);
            read_addr = addr;
            #1; // Pequeño delay para ver el dato después de la dirección
            $display("Reg[%0d] = %d", addr, read_data);
        end
    endtask

    initial begin
        // Inicialización
        clk = 0;
        rst_n = 0;
        event_cache_l1_miss_read = 0;
        event_cache_l1_miss_write = 0;
        event_cache_l2_miss_read = 0;
        event_cache_l2_miss_write = 0;
        cache_search_ready = 1; // Caché lista
        read_addr = 0;

        // Reset
        #20 rst_n = 1;
        
        // --- Escenario 1: Simular 3 fallos de L1 Read ---
        repeat(3) begin
            @(posedge clk);
            event_cache_l1_miss_read = 1;
            @(posedge clk);
            event_cache_l1_miss_read = 0;
        end

        // --- Escenario 2: Simular un fallo de caché NO LISTO (no debe contar) ---
        cache_search_ready = 0;
        @(posedge clk);
        event_cache_l1_miss_write = 1; // Este no debe contarse
        @(posedge clk);
        event_cache_l1_miss_write = 0;
        cache_search_ready = 1;

        // --- Verificación ---
        read_pmu(5'd0); // Ciclos totales
        read_pmu(5'd1); // Total misses (debería ser 3)
        read_pmu(5'd2); // Total L1 misses (debería ser 3)
        read_pmu(5'd3); // L1 read misses (debería ser 3)
        read_pmu(5'd4); // L1 write misses (debería ser 0)

        #20 $finish;
    end

endmodule