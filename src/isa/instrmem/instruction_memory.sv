module instruction_memory #(
    parameter int MEM_SIZE_KB = 64  // Default size: 64 KB
)(
    input  logic [31:0] A,  // Program Counter (PC) from Fetch Stage
    output logic [31:0] RD  // Instruction fetched from memory
);
    // --- Dynamic Parameter Calculation ---
    // Calculate total 32-bit words based on KB size
    localparam int NUM_WORDS = (MEM_SIZE_KB * 1024) / 4;
    
    // Calculate bits needed to index the memory array
    localparam int ADDR_WIDTH = $clog2(NUM_WORDS);

    // --- Memory Storage ---
    // [31:0] Packed dimension: Defines word width (32-bit)
    // [0:NUM_WORDS-1] Unpacked dimension: Defines the addressable depth
    logic [31:0] INSTRUCTIONS [0:NUM_WORDS-1];

    // --- Address Mapping ---
    // Convert byte address (A) to word index (word_idx)
    // We ignore A[1:0] because instructions must be word-aligned (4-byte boundary)
    logic [ADDR_WIDTH-1:0] word_idx;
    assign word_idx = A[ADDR_WIDTH+1:2];

    // --- Memory Initialization ---
    initial begin
        // Initialize memory with NOPs (add x0, x0, x0) to avoid undefined behavior
        for (int i = 0; i < NUM_WORDS; i++) begin
            INSTRUCTIONS[i] = 32'h00000080; // nop
        end
        // Load the program from the HEX file
        $readmemh("./src/instrmem/instr_mem.hex", INSTRUCTIONS);
    end

    // --- Asynchronous Instruction Fetch ---
    // Continuous assignment ensures RD updates immediately when the PC changes.
    // This reduces latency in the Fetch stage of the pipeline.
    assign RD = INSTRUCTIONS[word_idx];

endmodule