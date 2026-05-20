`timescale 1ns/1ps

module instruction_memory_tb();

    // Parameters
    parameter int MEM_SIZE_KB = 64;
    parameter int CLK_PERIOD  = 10;

    // Testbench Signals
    logic [31:0] PC;
    logic [31:0] Instruction;

    // Unit Under Test (UUT)
    instruction_memory #(
        .MEM_SIZE_KB(MEM_SIZE_KB)
    ) uut (
        .A(PC),
        .RD(Instruction)
    );

    // Initial Block for Stimulus
    initial begin
        // --- 1. System Setup ---
        $display("\n=== INSTRUCTION MEMORY VERIFICATION SYSTEM ===");
        $dumpfile("./src/output/instruction_memory_tb.vcd");
        $dumpvars(0, instruction_memory_tb);

        // Start at address 0
        PC = 32'h0;
        #5; // Brief delay to allow $readmemh to complete

        // --- 2. Sequential Fetch Test (First 5 Instructions) ---
        $display("\n--- [TEST 1] Sequential Execution Flow ---");
        
        // Expected values based on the .hex file provided
        // 0: 00000013, 4: 00500293, 8: 00a00313, c: 006283b3, 10: 00742023
        
        repeat (5) begin
            $display("[FETCH] PC: 0x%h | Instruction: 0x%h", PC, Instruction);
            #CLK_PERIOD;
            PC = PC + 4; 
        end

        // --- 3. Jump/Branch Test (Target 0x20) ---
        $display("\n--- [TEST 2] Jump Target Verification ---");
        PC = 32'h0000_0020; 
        #5; 
        if (Instruction == 32'h0000_00ef)
            $display("[SUCCESS] PC 0x20 correctly fetched Jump instruction: 0x%h", Instruction);
        else
            $display("[ERROR] PC 0x20 expected 0x000000ef, but got: 0x%h", Instruction);

        // --- 4. Out of Bounds / NOP Test ---
        $display("\n--- [TEST 3] Uninitialized Memory Access ---");
        PC = 32'h0000_0050; // Address far beyond our hex file data
        #5;
        $display("[INFO] PC: 0x%h | Instruction: 0x%h (Should be NOP 00000013)", PC, Instruction);

        $display("\n=== VERIFICATION FINISHED ===");
        $finish;
    end

endmodule