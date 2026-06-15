// Synchronous data memory for 32 bit architecture
module data_memory #(
    parameter int SIZE    = 64,  // Data memory SIZE (in bytes) [default:64 bytes]
    parameter int LATENCY = 8,   // Data memory LATENCY simulation (in CLK cycles) [default:8]
    parameter int WPL = 2        // words-per-line for cache data line retrieval [default: 2(min)]
)(
    // + Sequential logic signals
    input  logic CLK,
    input  logic RST,
    // + Write logic signals
    input  logic WE,        // write-enable
    input  logic [3:0] WBM, // write byte-mode (byte selection)
    input  logic [31:0] WA, // write address
    input  logic [31:0] WD, // write data
    // + Read logic signals
    input  logic RE,        // read enable
    input  logic [3:0] RBM, // read byte-mode (byte selection)
    input  logic [31:0] RA, // read address
    output logic [31:0] RD, // read data
    // + Ouput control signals
    output logic [1:0] ready,
    // + Cache back-feed burst-lines
    output logic [31:0] burst1_addr,     // burst 1 address
    output logic [31:0] burst2_addr,     // burst 2 address
    output logic [WPL-1:0][31:0] burst1, // data burst for block of given RA
    output logic [WPL-1:0][31:0] burst2  // data burst for relative block of given RA (next block)
);

    // --- Dynamic Parameter Calculation ---
    // 1. Calculate total words:
    localparam int NUM_WORDS = SIZE/4;
    
    // 2. Calculate address bits needed for the array index: log2(NUM_WORDS)
    // $clog2 is a system function that computes the ceiling of the log base 2
    localparam int ADDR_WIDTH = $clog2(NUM_WORDS);

    // 3. Calculate addess bits needed to the access the block in which data is contained
    // Also, for adjacent for blocks
    localparam int BLOCK_WIDTH = $clog2(WPL);

    // --- Memory Storage ---
    // [31:0] is the PACKED dimension: defines the 32-bit width of each word (MSB to LSB).
    // [0:NUM_WORDS-1] is the UNPACKED dimension: defines the addressable range.
    // We use [0:N] instead of [N:0] so that the first line of the .hex file 
    // correctly maps to the lowest address (index 0) during $readmemh.
    logic [31:0] RAM [0:NUM_WORDS-1];

    // --- Initialization ---
    initial begin
        for (int i = 0; i < NUM_WORDS-1; i++) begin
            RAM[i] = 32'h0;
        end
        $readmemh("./src/isa/datamem/data_mem.hex", RAM);
    end

    // --- Address Mapping ---
    // 1. Byte offset (useful analizing boundary crossing)
    logic [1:0] rd_byte_offset, wd_byte_offset;
    assign rd_byte_offset = RA[1:0];
    assign wd_byte_offset = WA[1:0];

    // 2. Extract the word index using the calculated width
    // ISSUE #1: byte addressing allows accesing data from two different words,
    // for example reading/writing a full word at address 0x2 requires two upper bytes
    // from 0x0 and two lower bytes from 0x4
    // SOLUTION #2: access both the inmediate lower word and the next one after it
    // to map correctly the bytes to read and write
    logic [ADDR_WIDTH-1:0] rd_word_idx [0:1];
    assign rd_word_idx[0] = RA[2 +: ADDR_WIDTH];
    assign rd_word_idx[1] = rd_word_idx[0] + 1;

    logic [ADDR_WIDTH-1:0] wd_word_idx [0:1];
    assign wd_word_idx[0] = WA[2 +: ADDR_WIDTH];
    assign wd_word_idx[1] = wd_word_idx[0] + 1;

    // 3. Extract the index of data block start for burst retrieval
    logic [ADDR_WIDTH-1:0] rd_block_idx [0:1];
    assign rd_block_idx[0] = {rd_word_idx[0][BLOCK_WIDTH +: ADDR_WIDTH], {BLOCK_WIDTH{1'b0}}};
    assign rd_block_idx[1] = {rd_word_idx[1][BLOCK_WIDTH +: ADDR_WIDTH], {BLOCK_WIDTH{1'b0}}};

    logic [31:0] rd_burst_addr [0:1];
    assign rd_burst_addr[0] = {RA[31:ADDR_WIDTH], rd_block_idx[0], 2'b00};
    assign rd_burst_addr[1] = {RA[31:ADDR_WIDTH], rd_block_idx[1], 2'b00};

    // --- Synchronous read (load) ---
    // + Read
    logic [7:0] rd_bytes [0:7];
    assign rd_bytes[0] = RAM[rd_word_idx[0]][7:0];
    assign rd_bytes[1] = RAM[rd_word_idx[0]][15:8];
    assign rd_bytes[2] = RAM[rd_word_idx[0]][23:16];
    assign rd_bytes[3] = RAM[rd_word_idx[0]][31:24];
    assign rd_bytes[4] = RAM[rd_word_idx[1]][7:0];
    assign rd_bytes[5] = RAM[rd_word_idx[1]][15:8];
    assign rd_bytes[6] = RAM[rd_word_idx[1]][23:16];
    assign rd_bytes[7] = RAM[rd_word_idx[1]][31:24];
    
    // + Read byte selections
    wire rd_byte1_sel = RBM[0];
    wire rd_byte2_sel = RBM[1];
    wire rd_byte3_sel = RBM[2];
    wire rd_byte4_sel = RBM[3];

    // + Read logic
    logic [7:0] read_data [0:3];
    always_comb begin
        read_data[0] = '0; read_data[1] = '0; read_data[2] = '0; read_data[3] = '0;
        case (rd_byte_offset)
            2'b00: begin 
                if (rd_byte1_sel) read_data[0] = rd_bytes[0];
                if (rd_byte2_sel) read_data[1] = rd_bytes[1];
                if (rd_byte3_sel) read_data[2] = rd_bytes[2];
                if (rd_byte4_sel) read_data[3] = rd_bytes[3];
            end

            2'b01: begin 
                if (rd_byte1_sel) read_data[0] = rd_bytes[1];
                if (rd_byte2_sel) read_data[1] = rd_bytes[2];
                if (rd_byte3_sel) read_data[2] = rd_bytes[3];
                if (rd_byte4_sel) read_data[3] = rd_bytes[4];
            end

            2'b10: begin 
                if (rd_byte1_sel) read_data[0] = rd_bytes[2];
                if (rd_byte2_sel) read_data[1] = rd_bytes[3];
                if (rd_byte3_sel) read_data[2] = rd_bytes[4];
                if (rd_byte4_sel) read_data[3] = rd_bytes[5];
            end

            2'b11: begin 
                if (rd_byte1_sel) read_data[0] = rd_bytes[3];
                if (rd_byte2_sel) read_data[1] = rd_bytes[4];
                if (rd_byte3_sel) read_data[2] = rd_bytes[5];
                if (rd_byte4_sel) read_data[3] = rd_bytes[6];
            end
        endcase
    end

    // + Latency simulation
    logic [31:0] read_counter;
    wire rd_done = (read_counter == LATENCY-1);
    always_ff @(posedge CLK, posedge RST) begin 
        if (RST) begin
            read_counter <= '0;
            ready[0] <= 0;
            RD <= '0;
            burst1_addr <= '0;
            burst2_addr <= '0;
            for (int i = 0; i < WPL; i++) begin
                burst1[i] <= '0;
                burst2[i] <= '0;
            end
        end else begin
            // >> Counter update logic <<
            if (RE) begin 
                if (rd_done) read_counter <= '0;      // search complete
                else read_counter <= read_counter + 1;// standby (searching)
            end else read_counter <= '0;              // idle (not searching)
            ready[0] <= rd_done & RE;
            // >> Read logic <<
            if (RE && rd_done) begin 
                // Read data
                RD <= {read_data[3], read_data[2], read_data[1], read_data[0]};
                // Read bursts
                burst1_addr <= rd_burst_addr[0];
                burst2_addr <= rd_burst_addr[1];
                for (int i = 0; i < WPL; i++) begin
                    burst1[i] <= RAM[rd_block_idx[0]+i];
                    burst2[i] <= RAM[rd_block_idx[1]+i];
                end
            end
        end
    end

    // --- Synchronous write (store) ---
    // + Write bytes
    logic [7:0] wd_bytes [0:3];
    assign wd_bytes[0] = WD[7:0];
    assign wd_bytes[1] = WD[15:8];
    assign wd_bytes[2] = WD[23:16];
    assign wd_bytes[3] = WD[31:24];

    // + Write byte selections
    wire wd_byte1_sel = WBM[0];
    wire wd_byte2_sel = WBM[1];
    wire wd_byte3_sel = WBM[2];
    wire wd_byte4_sel = WBM[3];

    // + Latency simulation
    logic [31:0] write_counter;
    wire wd_done = (write_counter == LATENCY-1);
    always_ff @(negedge CLK, posedge RST) begin 
        if (RST) begin
            write_counter <= '0;
            ready[1] <= 0;
        end else begin
            // >> Counter update logic <<
            if (WE) begin 
                if (wd_done) write_counter <= '0;       // search complete
                else write_counter <= write_counter + 1;// standby (searching)
            end else write_counter <= '0;               // idle (not searching)
            ready[1] <= wd_done & WE;
            // >> Write logic <<
            if (WE && wd_done) begin
                case (wd_byte_offset)
                    2'b00: begin
                        if (wd_byte1_sel) RAM[wd_word_idx[0]][7:0]   <= wd_bytes[0];
                        if (wd_byte2_sel) RAM[wd_word_idx[0]][15:8]  <= wd_bytes[1];
                        if (wd_byte3_sel) RAM[wd_word_idx[0]][23:16] <= wd_bytes[2];
                        if (wd_byte4_sel) RAM[wd_word_idx[0]][31:24] <= wd_bytes[3];
                    end

                    2'b01: begin
                        if (wd_byte1_sel) RAM[wd_word_idx[0]][15:8]  <= wd_bytes[0];
                        if (wd_byte2_sel) RAM[wd_word_idx[0]][23:16] <= wd_bytes[1];
                        if (wd_byte3_sel) RAM[wd_word_idx[0]][31:24] <= wd_bytes[2];
                        if (wd_byte4_sel) RAM[wd_word_idx[1]][7:0]   <= wd_bytes[3];
                    end

                    2'b10: begin
                        if (wd_byte1_sel) RAM[wd_word_idx[0]][23:16] <= wd_bytes[0];
                        if (wd_byte2_sel) RAM[wd_word_idx[0]][31:24] <= wd_bytes[1];
                        if (wd_byte3_sel) RAM[wd_word_idx[1]][7:0]   <= wd_bytes[2];
                        if (wd_byte4_sel) RAM[wd_word_idx[1]][15:8]  <= wd_bytes[3];
                    end

                    2'b11: begin
                        if (wd_byte1_sel) RAM[wd_word_idx[0]][31:24] <= wd_bytes[0];
                        if (wd_byte2_sel) RAM[wd_word_idx[1]][7:0]   <= wd_bytes[1];
                        if (wd_byte3_sel) RAM[wd_word_idx[1]][15:8]  <= wd_bytes[2];
                        if (wd_byte4_sel) RAM[wd_word_idx[1]][23:16] <= wd_bytes[3];
                    end
                endcase
            end
        end
    end

endmodule