/* Associative cache memory module for 32 bit architectures.
// Number of sets is infered from SIZE, words per line (WPL), and associativity(WAYS)
// Cache blocks reading upon a miss. Cache can be unlocked by setting CLR=1
// Write policy: Write-through (write buffer)
// Replacement policy: FIFO (queue-like shifting of data blocks) */
module cache #(
    parameter int SIZE = 32,    // Cache memory SIZE (in bytes) [default: 32 bytes]
    parameter int WPL  = 2,     // words-per-line               [default: 2 (min)]
    parameter int WAYS = 2,     // Cache memory number of WAYS per set [default: 2 (min)]
    parameter int LATENCY = 1,  // Cache memory LATENCY simulation (number of CLK cycles) [default: 1 (min)]
    parameter bit REPLACEMENT_MODE = 0 // Replacement policy mode: 0 for FIFO, 1 for Random [default: 0]
)( 
    // + Sequential logic inputs
    input  logic CLK,        // clock signal pulse
    input  logic RST,        // reset module
    input  logic ignore,     // ignore misses
    // + Write logic signals
    input  logic WE,         // write enable
    input  logic [3:0]  WBM, // write byte mode (byte selection)
    input  logic [31:0] WA,  // write address
    input  logic [31:0] WD,  // write data
    // + Read  logic signals
    input  logic RE,         // read enable
    input  logic [3:0]  RBM, // read byte mode (byte selection)
    input  logic [31:0] RA,  // read address
    output logic [31:0] RD,  // read data
    // + Output control signals
    output logic [1:0] hit,   // cache hit
    output logic [1:0] ready, // cache ready
    output logic locked,      // cache locked (only for reading)
    // + Miss logic input signals
    input  logic fill,  // fill missing lines
    input  logic [31:0] in_addr_burst1, // input burst 1 address
    input  logic [31:0] in_addr_burst2, // input burst 2 address
    input  logic [WPL-1:0][31:0] in_burst1, // input burst 1
    input  logic [WPL-1:0][31:0] in_burst2, // input burst 2
    // + Miss logic output signals
    output logic [31:0] out_addr_burst1, // output burst 1 address
    output logic [31:0] out_addr_burst2, // output burst 2 address
    output logic [WPL-1:0][31:0] out_burst1, // output burst 1
    output logic [WPL-1:0][31:0] out_burst2, // output burst 2
    // + Write-through output signals
    output logic queue,      // write buffer queue
    output logic dequeue,    // write buffer dequeue
    output logic [3:0] pWBM, // propagate WBM
    output logic [31:0] pWA, // propagate write address
    output logic [31:0] pWD  // propagate write data
);
// --- Dynamic parameter calculation ---
localparam int BLOCKS = SIZE/(WPL*4);   // number of cache memory blocks
localparam int SETS = BLOCKS/WAYS;      // number of cache memory sets

localparam int block_bits = $clog2(WPL); // required bits from address for block offset
localparam int set_bits = $clog2(SETS);  // required bits from address for set selection
localparam int way_bits = $clog2(WAYS);  // required bits for way selection
localparam int tag_bits = 32 - set_bits - block_bits - 2; // required bits from address for tag selection

localparam int block_to_set = block_bits + set_bits; // range of bits from block offset end to set selection end

// --- Cache array instantiation ---
logic [31:0] data [0:SETS-1][0:WAYS-1][0:WPL-1]; // array for data blocks => [wordN]...[word0]
logic [tag_bits:0] tags [0:SETS-1][0:WAYS-1];    // array for tags => [valid][tag]

// --- Cache initialization ---
initial begin 
    for (int i = 0; i < SETS; i++) begin
        for (int j = 0; j < WAYS; j++) begin
            tags[i][j] = '0;
            // if (i == 0 && j == 1)      tags[i][j] = {1'b1, 28'd0};
            // else if (i == 0 && j == 0) tags[i][j] = {1'b1, 28'd1};
            // else if (i == 1 && j == 0) tags[i][j] = {1'b1, 28'd0};
            for (int k = 0; k < WPL; k++) begin
                data[i][j][k] = '0;
                // if (i == 0 && j == 1 && k == 0)      data[i][j][k] = 32'h000010A2; // 0x0
                // else if (i == 0 && j == 1 && k == 1) data[i][j][k] = 32'hDEADBEEF; // 0x4
                // else if (i == 0 && j == 0 && k == 0) data[i][j][k] = 32'd1;        // 0x16
                // else if (i == 0 && j == 0 && k == 1) data[i][j][k] = 32'd2;        // 0x20
                // else if (i == 1 && j == 0 && k == 0) data[i][j][k] = 32'h12345678; // 0x8
                // else if (i == 1 && j == 0 && k == 1) data[i][j][k] = 32'h0ABCDEF1; // 0x12
            end
        end
    end
end

// --- Random replacement policy (if selected) ---
logic [way_bits-1:0] randway [0:1];
generate;
    if (REPLACEMENT_MODE == 1) begin 
        logic [31:0] randnums [0:1];

        randgen #(.WIDTH(32)) randgen1 (
            .clk(CLK), .rst(RST), 
            .seed(32'hDEADBEEF), 
            .random(randnums[0])
        );
        assign randway[0] = randnums[0][3 +: way_bits];
        
        randgen #(.WIDTH(32)) randgen2 (
            .clk(CLK), .rst(RST), 
            .seed(32'hC0FFEE00), 
            .random(randnums[1])
        );
        assign randway[1] = randnums[1][1 +: way_bits];
    end
endgenerate

// --- Auxiliary functions/decoders ----
// 1. Address decoding
typedef struct packed {
    logic [tag_bits-1:0] tag;
    logic [set_bits-1:0] set;
    logic [block_bits-1:0] block_offset;
} addr_deco_t; // decoded address structure for cache

function automatic addr_deco_t decode_address ( // auxiliary decoder for address
    input logic [29:0] idx
);
    addr_deco_t d;
    
    d.block_offset = idx[block_bits-1:0];
    d.set = idx[block_to_set-1:block_bits];
    d.tag = idx[29:block_to_set];

    return d;
endfunction

// 2. Boundary crossing
// + Verifies if the given address and byte selection generates conflict with boundary crossing,
// which has potential to access invalid cache data blocks
function automatic logic is_crossing (  // auxiliary decoder for crossing detection
    input logic [1:0] byte_offset, // byte offset
    input logic [3:0] bm           // byte mode
);  
    logic ilegal;

    ilegal = 1'b0;
    case (byte_offset)
        2'b00: ilegal = 1'b0;
        2'b01: if (bm == 4'b1111) ilegal = 1'b1;
        2'b10: if (bm == 4'b1111 || bm == 4'b0111) ilegal = 1'b1;
        2'b11: if (bm != 4'b0001) ilegal = 1'b1;
    endcase

    return ilegal;
endfunction

// 3. Hit detection
// + Checks if the given tag correctly maps to tag on cache (ctag). This requires
// checking individually for each way of the set
function automatic logic hit_detect( // auxiliary decoder for detecting hit on a given tag
    input logic [tag_bits-1:0] tag,
    input logic valid_bit,
    input logic [tag_bits-1:0] ctag
); 
    logic hit;
    hit = valid_bit & (ctag == tag);
    return hit;
endfunction

// --- Synchronous read (load) ---
// 1. Address decode
// ISSUE #1: What happens if i access half words? For example address 0x02 maps to 
// upper half of word 0 and lower half of word 1
// SOLUTION #1: (a) cache must decode to the inmediate nearest lower word and the next one to check if both
// map to a set in cache, if one is not available throw a miss. (b) use signals byte_offset and
// BM to determine correct byte mapping for buffered output RD 
logic [1:0]  rd_byte_offset;     // read byte offset
assign rd_byte_offset = RA[1:0];

logic [29:0] rd_word_idx [0:1];                // [0]: nearest word, [1]: next word
assign rd_word_idx[0] = RA[31:2];
assign rd_word_idx[1] = rd_word_idx[0] + 1;

logic [block_bits-1:0] rd_block_offset [0:1];  // [0]: nearest word, [1]: next word
logic [set_bits-1:0]   rd_set [0:1];           // [0]: nearest word, [1]: next word
logic [tag_bits-1:0]   rd_tag [0:1];           // [0]: nearest word, [1]: next word
assign {rd_tag[0], rd_set[0], rd_block_offset[0]} = decode_address(rd_word_idx[0]);
assign {rd_tag[1], rd_set[1], rd_block_offset[1]} = decode_address(rd_word_idx[1]);

// 2. Check boundary crossing
wire rd_is_crossing = is_crossing(rd_byte_offset, RBM);
wire rd_diff_sets   = rd_is_crossing & (rd_set[0] != rd_set[1]);

// 3. Hit detection
// + Check hits on each way of the mapped set
logic [WAYS-1:0] rd_hits [0:1]; // [0]: nearest word, [1]: next word
generate;
    for (genvar i = 0; i < WAYS; i++) begin
        assign rd_hits[0][i] = hit_detect(rd_tag[0], tags[rd_set[0]][i][tag_bits], tags[rd_set[0]][i][tag_bits-1:0]);
        assign rd_hits[1][i] = hit_detect(rd_tag[1], tags[rd_set[1]][i][tag_bits], tags[rd_set[1]][i][tag_bits-1:0]);
    end
endgenerate

// + Identify the way that has a hit (one-hot to binary decoder)
logic [way_bits-1:0] rd_way [0:1];
always_comb begin
    rd_way[0] = '0; rd_way[1] = '0;
    for (int i = 0; i < WAYS; i++) begin
        if (rd_hits[0][i]) rd_way[0] = i;
        if (rd_hits[1][i]) rd_way[1] = i;
    end
end

// + Determine if both words are required
logic [1:0] rd_hit;
assign rd_hit[0] = |rd_hits[0];
assign rd_hit[1] = |rd_hits[1];
wire rd_pre_hit = (rd_is_crossing) ? (rd_hit[0] & rd_hit[1]) :  rd_hit[0];

// 4. Read byte selections
wire rd_byte1_sel = RBM[0];
wire rd_byte2_sel = RBM[1];
wire rd_byte3_sel = RBM[2];
wire rd_byte4_sel = RBM[3];

// 5. Read bytes
logic [7:0] rd_bytes  [0:7];
assign rd_bytes[0] = data[rd_set[0]][rd_way[0]][rd_block_offset[0]][7:0];
assign rd_bytes[1] = data[rd_set[0]][rd_way[0]][rd_block_offset[0]][15:8];
assign rd_bytes[2] = data[rd_set[0]][rd_way[0]][rd_block_offset[0]][23:16];
assign rd_bytes[3] = data[rd_set[0]][rd_way[0]][rd_block_offset[0]][31:24];
assign rd_bytes[4] = data[rd_set[1]][rd_way[1]][rd_block_offset[1]][7:0];
assign rd_bytes[5] = data[rd_set[1]][rd_way[1]][rd_block_offset[1]][15:8];
assign rd_bytes[6] = data[rd_set[1]][rd_way[1]][rd_block_offset[1]][23:16];
assign rd_bytes[7] = data[rd_set[1]][rd_way[1]][rd_block_offset[1]][31:24];

// 6. Read data assigning
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

// 7. Reading latency simulation
logic [31:0] read_counter;
wire rd_done = (read_counter == LATENCY-1);

// 8. Miss logic FSM
// NOTE #1: this FSM is necessary for controlling the reading behavior of the cache
// whenever a miss is detected. It relies heavily on using the output signal 'locked'.
// The FSM only has 2 states: locked (locked = 1) and unlocked (locked = 0)
logic [1:0] line_is_filled;
logic [1:0] miss;
logic [31:0] MA1, MA2; // Miss Address 1 & 2

wire miss1_complete = ~miss[0] | line_is_filled[0];
wire miss2_complete = ~miss[1] | line_is_filled[1];

// 9. Flip-Flop register (reading)
wire rd_post_results = RE & rd_done & rd_pre_hit;
wire rd_post_misses = RE & rd_done & ~rd_pre_hit;

always_ff @(posedge CLK, posedge RST) begin
    if (RST) begin
        // Reset logic
        read_counter <= '0;
        ready[0] <= '0; hit[0] <= '0;
        RD <= '0;

        out_addr_burst1 <= '0;
        out_addr_burst2 <= '0;
        for (int i = 0; i < WPL; i++) begin 
            out_burst1[i] <= '0;
            out_burst2[i] <= '0;
        end

        miss <= '0;
        MA1 <= '0; MA2 <= '0;
        locked <= 1'b0;
    end else if (!locked) begin // Unlocked cache behavior
        // >> Counter update logic <<
        if (RE) begin 
            if (rd_done) read_counter <= '0;       // search complete
            else read_counter <= read_counter + 1; // standby (searching)
        end else read_counter <= '0;               // idle (not searching)
        // >> Post results <<
        ready[0] <= rd_done & RE;
        hit[0] <= rd_pre_hit & RE;
        // >> Read logic <<
        if (rd_post_results) begin // post results
            // Read data
            RD <= {read_data[3], read_data[2], read_data[1], read_data[0]};
            // Read bursts
            out_addr_burst1 <= {rd_tag[0], rd_set[0], {block_bits+2{1'b0}}};
            out_addr_burst2 <= {rd_tag[1], rd_set[1], {block_bits+2{1'b0}}};
            for (int i = 0; i < WPL; i++) begin 
                out_burst1[i] <= data[rd_set[0]][rd_way[0]][i];
                out_burst2[i] <= data[rd_set[1]][rd_way[1]][i];
            end
        end
        // >> Miss logic <<
        miss[0] <= ~rd_hit[0] & rd_done & RE & ~ignore;
        miss[1] <= ~rd_hit[1] & rd_done & RE & rd_diff_sets & ~ignore;
        MA1 <= (~rd_hit[0] & rd_done & RE & ~ignore) ? {rd_word_idx[0], 2'b00} : '0;
        MA2 <= (~rd_hit[1] & rd_done & RE & rd_diff_sets & ~ignore) ? {rd_word_idx[1], 2'b00} : '0;
        if (rd_post_misses & ~ignore) begin 
            locked <= 1'b1;
        end
    end else if (locked) begin // Locked cache behavior
        // >> Post results <<
        // >> Miss logic <<
        if (line_is_filled[0] | ignore) begin 
            miss[0] <= 0;
            MA1 <= '0;
        end
        if (line_is_filled[1] | ignore) begin
            miss[1] <= 0;
            MA2 <= '0;
        end
        if ((miss1_complete & miss2_complete) | ignore) begin
            ready[0] <= 1'b0;
            hit[0] <= '0;
            locked <= 1'b0;
        end
    end
end

// --- Synchronous write (store) ---
// 1. Address decode
// ISSUE #1: What happens if i access half words? For example address 0x02 maps to 
// upper half of word 0 and lower half of word 1
// SOLUTION #1: (a) cache must decode to the inmediate nearest lower word and the next one to check if both
// map to a set in cache, if one is not available throw a miss. (b) use signals byte_offset and
// BM to determine correct byte mapping for buffered output RD 
// 1.1. Decode the write address
logic [1:0]  wd_byte_offset; // write byte offset
assign wd_byte_offset = WA[1:0];

logic [29:0] wd_word_idx [0:1]; // [0]: nearest word, [1]: next word
assign wd_word_idx[0] = WA[31:2];
assign wd_word_idx[1] = wd_word_idx[0] + 1;

logic [block_bits-1:0] wd_block_offset [0:1]; // [0]: nearest word, [1]: next word
logic [set_bits-1:0]   wd_set [0:1]; // [0]: nearest word, [1]: next word
logic [tag_bits-1:0]   wd_tag [0:1]; // [0]: nearest word, [1]: next word
assign {wd_tag[0], wd_set[0], wd_block_offset[0]} = decode_address(wd_word_idx[0]);
assign {wd_tag[1], wd_set[1], wd_block_offset[1]} = decode_address(wd_word_idx[1]);

// 1.2. Decode the input burst address'
logic [block_bits-1:0] burst_block_offset [0:1]; // [0]: burst1, [1]: burst2
logic [set_bits-1:0]   burst_set [0:1];          // [0]: burst1, [1]: burst2
logic [tag_bits-1:0]   burst_tag [0:1];          // [0]: burst1, [1]: burst2

assign {burst_tag[0], burst_set[0], burst_block_offset[0]} = decode_address(in_addr_burst1[31:2]);
assign {burst_tag[1], burst_set[1], burst_block_offset[1]} = decode_address(in_addr_burst2[31:2]);

// 1.2. Decode the missing address'
logic [block_bits-1:0] miss_block_offset [0:1]; // [0]: miss1, [1]: miss2
logic [set_bits-1:0]   miss_set [0:1]; // [0]: miss1, [1]: miss2
logic [tag_bits-1:0]   miss_tag [0:1]; // [0]: miss1, [1]: miss2

assign {miss_tag[0], miss_set[0], miss_block_offset[0]} = decode_address(MA1[31:2]);
assign {miss_tag[1], miss_set[1], miss_block_offset[1]} = decode_address(MA2[31:2]);

// 2. Check boundary crossing
logic wd_is_crossing;
assign wd_is_crossing = is_crossing(wd_byte_offset, WBM);

// 3. Write byte selections
wire wd_byte1_sel = WBM[0];
wire wd_byte2_sel = WBM[1];
wire wd_byte3_sel = WBM[2];
wire wd_byte4_sel = WBM[3];

// 4. Write bytes
logic [7:0] wd_bytes [0:3];
assign wd_bytes[0] = WD[7:0];
assign wd_bytes[1] = WD[15:8];
assign wd_bytes[2] = WD[23:16];
assign wd_bytes[3] = WD[31:24];

// 5. Writing latency simulation
logic [31:0] write_counter;
wire wd_done = (write_counter == LATENCY-1);

// 6. Hit detection
// + Check if data exists on any way of the mapped set
logic [WAYS-1:0] wd_hits [0:1]; // [0]: nearest word, [1]: next word

generate
    for (genvar j = 0; j < WAYS; j++) begin
        assign wd_hits[0][j] = hit_detect(wd_tag[0], tags[wd_set[0]][j][tag_bits], tags[wd_set[0]][j][tag_bits-1:0]);
        assign wd_hits[1][j] = hit_detect(wd_tag[1], tags[wd_set[1]][j][tag_bits], tags[wd_set[1]][j][tag_bits-1:0]);
    end
endgenerate

// + Detect CLK alignment
wire clk_align = wd_done & fill;

// + Detect if input burst matches with missing address
wire addr1_match = miss[0] & (burst_tag[0] == miss_tag[0]) & (burst_set[0] == miss_set[0]);
wire addr2_match = miss[1] & (burst_tag[1] == miss_tag[1]) & (burst_set[1] == miss_set[1]);

// + Detect if bursts are different
wire diff_bursts = (burst_set[0] != burst_set[1]);

// + Detect if the writing address' match with any of the input bursts
logic [1:0] wd_match [0:1]; // [0]: nearest word, [1]: next word

assign wd_match[0][0] = addr1_match & (wd_tag[0] == burst_tag[0]) & (wd_set[0] == burst_set[0]); // match with burst 1
assign wd_match[0][1] = addr2_match & (wd_tag[0] == burst_tag[1]) & (wd_set[0] == burst_set[1]); // match with burst 2

assign wd_match[1][0] = addr1_match & (wd_tag[1] == burst_tag[0]) & (wd_set[0] == burst_set[0]); // match with burst 1
assign wd_match[1][1] = addr2_match & (wd_tag[1] == burst_tag[1]) & (wd_set[0] == burst_set[1]); // match with burst 2

wire wd1_correction = clk_align & (wd_match[0][0] | wd_match[0][1]);
wire wd2_correction = clk_align & (wd_match[1][0] | wd_match[1][1]);

// + Map the hits to a way (one-hot to binary encoder) or if a new burst has the data
logic [way_bits-1:0] wd_way [0:1]; // [0]: nearest word, [1]: next word
always_comb begin
    wd_way[0] = '0; wd_way[1] = '0;
    for (int i = 0; i < WAYS; i++) begin
        if (wd_hits[0][i]) wd_way[0] = i;
        if (wd_hits[1][i]) wd_way[1] = i;
    end
    if (wd1_correction) wd_way[0] = '0; // way correction if burst 1 or 2 provides new data
    if (wd2_correction) wd_way[1] = '0; // way correction if burst 1 or 2 provides new data
end

// + Determine if both words are nearest
logic [1:0] wd_hit; // [0]: nearest word, [1]: next word
assign wd_hit[0] = (|wd_hits[0]) | wd1_correction; // confirm hit for write-data word1 if (any way on set has the content) or (feedback burst provide the content) 
assign wd_hit[1] = (|wd_hits[1]) | wd2_correction; // confirm hit for write-data word2 if (any way on set has the content) or (feedback burst provide the content)
wire wd_pre_hit = (!wd_is_crossing) ? wd_hit[0] : (wd_hit[0] & wd_hit[1]);

// 7. Flip-Flop register
wire wd_post_results = WE & wd_done & wd_pre_hit;
always_ff @(negedge CLK, posedge RST) begin
    if (RST) begin 
        write_counter <= '0;
        ready[1] <= '0; hit[1] <= '0;
        queue <= 1'b0; dequeue <= 1'b0; pWBM <= '0; pWA <= '0; pWD <= '0;
        line_is_filled <= '0;
    end else begin 
        // >> Counter update logic <<
        if (WE) begin
            if (wd_done) write_counter <= '0;        // search complete
            else write_counter <= write_counter + 1; // standby (searching)
        end else write_counter <= '0;                // idle (not searching)
        // >> Post results <<
        ready[1] <= wd_done & WE;
        hit[1] <= wd_pre_hit & WE;
        // >> Write logic <<
        // + Replacement logic (on every clock negedge)[FIFO policy]
        line_is_filled[0] <= addr1_match & fill;
        line_is_filled[1] <= addr2_match & fill;
        if (REPLACEMENT_MODE == 0) begin          // FIFO
            for (int i = 0; i < WAYS; i++) begin
                // Update tags
                // Burst 1
                if (fill && addr1_match) begin 
                    if (i == 0) tags[burst_set[0]][i] <= {1'b1, burst_tag[0]};
                    else tags[burst_set[0]][i] <= tags[burst_set[0]][i-1];
                end
                // Burst 2
                if (fill && addr2_match && diff_bursts) begin
                    if (i == 0) tags[burst_set[1]][i] <= {1'b1, burst_tag[1]};
                    else tags[burst_set[1]][i] <= tags[burst_set[1]][i-1];
                end
                // Update data
                for (int j = 0; j < WPL; j++) begin
                    // Burst 1
                    if (fill && addr1_match) begin
                        if (i == 0) data[burst_set[0]][i][j] <= in_burst1[j];
                        else data[burst_set[0]][i][j] <= data[burst_set[0]][i-1][j];
                    end
                    // Burst 2
                    if (fill && addr2_match && diff_bursts) begin
                        if (i == 0) data[burst_set[1]][i][j] <= in_burst2[j];
                        else data[burst_set[1]][i][j] <= data[burst_set[1]][i-1][j];
                    end
                end
            end
        end else if (REPLACEMENT_MODE == 1) begin // RANDOM
            // Update tags
            // Burst 1
            if (fill && addr1_match) tags[burst_set[0]][randway[0]] <= {1'b1, burst_tag[0]};
            // Burst 2
            if (fill && addr2_match && diff_bursts) tags[burst_set[1]][randway[1]] <= {1'b1, burst_tag[1]};
            // Update data
            for (int i = 0; i < WPL; i++) begin 
                // Burst 1
                if (fill && addr1_match) data[burst_set[0]][randway[0]][i] <= in_burst1[i];
                // Burst 2
                if (fill && addr2_match && diff_bursts) data[burst_set[1]][randway[1]][i] <= in_burst2[i];
            end
        end
        // + Write data (only during post results stages)
        if (wd_post_results) begin
                case (wd_byte_offset)
                    2'b00: begin
                        if (wd_byte1_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][7:0]   <= wd_bytes[0];
                        if (wd_byte2_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][15:8]  <= wd_bytes[1];
                        if (wd_byte3_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][23:16] <= wd_bytes[2];
                        if (wd_byte4_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][31:24] <= wd_bytes[3];
                    end

                    2'b01: begin
                        if (wd_byte1_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][15:8]  <= wd_bytes[0];
                        if (wd_byte2_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][23:16] <= wd_bytes[1];
                        if (wd_byte3_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][31:24] <= wd_bytes[2];
                        if (wd_byte4_sel) data[wd_set[1]][wd_way[1]][wd_block_offset[1]][7:0]   <= wd_bytes[3];
                    end

                    2'b10: begin
                        if (wd_byte1_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][23:16] <= wd_bytes[0];
                        if (wd_byte2_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][31:24] <= wd_bytes[1];
                        if (wd_byte3_sel) data[wd_set[1]][wd_way[1]][wd_block_offset[1]][7:0]   <= wd_bytes[2];
                        if (wd_byte4_sel) data[wd_set[1]][wd_way[1]][wd_block_offset[1]][15:8]  <= wd_bytes[3];
                    end

                    2'b11: begin
                        if (wd_byte1_sel) data[wd_set[0]][wd_way[0]][wd_block_offset[0]][31:24] <= wd_bytes[0];
                        if (wd_byte2_sel) data[wd_set[1]][wd_way[1]][wd_block_offset[1]][7:0]   <= wd_bytes[1];
                        if (wd_byte3_sel) data[wd_set[1]][wd_way[1]][wd_block_offset[1]][15:8]  <= wd_bytes[2];
                        if (wd_byte4_sel) data[wd_set[1]][wd_way[1]][wd_block_offset[1]][23:16] <= wd_bytes[3];
                    end
                endcase
            end
        // >> Write-through <<
        queue <= WE & wd_done; dequeue <= WE & wd_done;
        pWBM <= WBM;
        pWA <= WA;
        pWD <= WD;
    end
end

endmodule