/* Associative cache memory module for 32 bit architectures.
// Number of sets is infered from SIZE, words per line (WPL), and associativity(WAYS)
// Cache blocks reading upon a miss. Cache can be unlocked by setting CLR=1
// Write policy: Write-through (write buffer)
// Replacement policy: FIFO (queue-like shifting of data blocks) */
module cache #(
    parameter int SIZE = 32,    // Cache memory SIZE (in bytes) [default: 32 bytes]
    parameter int WPL  = 2,     // words-per-line               [default: 2 (min)]
    parameter int WAYS = 2,     // Cache memory number of WAYS per line [default: 2 (min)]
    parameter int LATENCY = 1   // Cache memory LATENCY simulation (number of CLK cycles) [default: 1 (min)]
)( 
    // + Sequential logic inputs
    input  logic CLK,        // clock signal pulse
    input  logic RST,        // reset module
    input  logic CLR,        // clear
    input  logic force_unlock, // force unlock the module for reading (ignore misses)
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
    input  logic valid_burst,
    input  logic [31:0] in_addr_burst1,
    input  logic [31:0] in_addr_burst2,
    input  logic [WPL-1:0][31:0] in_burst1,
    input  logic [WPL-1:0][31:0] in_burst2,
    // + Miss logic output signals
    output logic [31:0] out_addr_burst1,
    output logic [31:0] out_addr_burst2,
    output logic [WPL-1:0][31:0] out_burst1,
    output logic [WPL-1:0][31:0] out_burst2,
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
logic rd_is_crossing;
assign rd_is_crossing = is_crossing(rd_byte_offset, RBM);

// 3. Hit detection
// + Check hits on each way of the mapped set
logic [WAYS-1:0] rd_hits [0:1]; // [0]: nearest word, [1]: next word
generate
    genvar i;
    for (i = 0; i < WAYS; i++) begin
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

// 8. Flip-Flop register (reading)
wire rd_post_results = RE & rd_done & rd_pre_hit;
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
    end else if (!locked) begin // Unlocked cache behavior
        // >> Counter update logic <<
        if (RE) begin 
            if (rd_done) read_counter <= '0;       // searching complete
            else read_counter <= read_counter + 1; // standby (searching)
        end else read_counter <= '0;               // idle (not searching)
        // >> Post results <<
        ready[0] <= rd_done & RE;
        hit[0] <= rd_pre_hit;
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
    end else if (locked) begin

    end
end

// 9. Miss logic FSM
logic [1:0] miss_state;
logic [1:0] line_is_filled;
logic [1:0] miss;
logic [31:0] MA1, MA2; // Miss Address 1 & 2

wire miss1_complete = ~miss[0] | line_is_filled[0];
wire miss2_complete = ~miss[1] | line_is_filled[1];

// 10. Flip-flop register (miss logic)
wire rd_post_misses = RE & rd_done & ~rd_pre_hit;
always_ff @(posedge CLK, posedge RST) begin 
    if (RST || CLR) begin 
        miss_state <= '0;
        miss <= '0;
        MA1 <= '0; MA2 <= '0;
        locked <= 1'b0;
    end else begin 
        // >>> Miss logic FSM <<<
        // NOTE #1: This finite state machine is useful for detecting and solving read misses
        // This FSM complements itself with writing logic for cache line(burst) filling
        case (miss_state)
            2'b00: begin // No missing lines
                miss[0] <= ~rd_hit[0] & rd_done & RE;
                miss[1] <= ~rd_hit[1] & rd_done & RE & rd_is_crossing;
                MA1 <= (~rd_hit[0] & rd_done & RE) ? {rd_word_idx[0], 2'b00} : '0;
                MA2 <= (~rd_hit[1] & rd_done & RE & rd_is_crossing) ? {rd_word_idx[1], 2'b00} : '0;
                if (rd_post_misses) begin 
                    miss_state <= 2'b01; 
                    locked <= 1'b1;
                end
            end

            2'b01: begin // Missing lines (cache becomes locked for reading)
                if (line_is_filled[0] | force_unlock) begin 
                    miss[0] <= 0;
                    MA1 <= '0;
                end
                if (line_is_filled[1] | force_unlock) begin
                    miss[1] <= 0;
                    MA2 <= '0;
                end
                if ((miss1_complete & miss2_complete) | force_unlock) begin
                    miss_state <= 2'b00;
                    locked <= 1'b0;
                end
            end

            default begin 
                miss <= '0;
                MA1 <= '0;
                MA2 <= '0;
                miss_state <= 2'b00;
                locked <= 1'b0;
            end
        endcase
    end
end

// --- Synchronous write (store) ---
// 1. Address decode
// ISSUE #1: What happens if i access half words? For example address 0x02 maps to 
// upper half of word 0 and lower half of word 1
// SOLUTION #1: (a) cache must decode to the inmediate lower word and the next one to check if both
// map to a set in cache, if one is not available throw a miss. (b) use signals byte_offset and
// BM to determine correct byte mapping for buffered output RD 
// 1.1. Decode the write address
logic [1:0]  wd_byte_offset;
logic [29:0] wd_word_idx1, wd_word_idx2;
logic [block_bits-1:0] wd_block_offset1, wd_block_offset2;
logic [set_bits-1:0]   wd_set1, wd_set2;
logic [tag_bits-1:0]   wd_tag1, wd_tag2;

assign wd_byte_offset = WA[1:0];

assign wd_word_idx1 = WA[31:2];
assign {wd_tag1, wd_set1, wd_block_offset1} = decode_address(wd_word_idx1);

assign wd_word_idx2 = wd_word_idx1 + 1;
assign {wd_tag2, wd_set2, wd_block_offset2} = decode_address(wd_word_idx2);

// 1.2. Decode the input burst address'
logic [block_bits-1:0] burst1_block_offset, burst2_block_offset;
logic [set_bits-1:0]   burst1_set, burst2_set;
logic [tag_bits-1:0]   burst1_tag, burst2_tag;

assign {burst1_tag, burst1_set, burst1_block_offset} = decode_address(in_addr_burst1[31:2]);
assign {burst2_tag, burst2_set, burst2_block_offset} = decode_address(in_addr_burst2[31:2]);

// 1.2. Decode the missing address'
logic [block_bits-1:0] miss1_block_offset, miss2_block_offset;
logic [set_bits-1:0]   miss1_set, miss2_set;
logic [tag_bits-1:0]   miss1_tag, miss2_tag; 

assign {miss1_tag, miss1_set, miss1_block_offset} = decode_address(MA1[31:2]);
assign {miss2_tag, miss2_set, miss2_block_offset} = decode_address(MA2[31:2]);

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
// Check if data exists on any way of the mapped set
logic [WAYS-1:0] wd_hits1, wd_hits2;

generate
    genvar j;
    for (j = 0; j < WAYS; j++) begin
        assign wd_hits1[j] = hit_detect(wd_tag1, tags[wd_set1][j][tag_bits], tags[wd_set1][j][tag_bits-1:0]);
        assign wd_hits2[j] = hit_detect(wd_tag2, tags[wd_set2][j][tag_bits], tags[wd_set2][j][tag_bits-1:0]);
    end
endgenerate

// + Detect CLK alignment
wire clk_align = wd_done & valid_burst;

// + Detect if input burst matches with missing address
wire addr1_match = miss[0] & (burst1_tag == miss1_tag) & (burst1_set == miss1_set);
wire addr2_match = miss[1] & (burst2_tag == miss2_tag) & (burst2_set == miss2_set);

// + Detect if the writing address' match with any of the input bursts
logic [1:0] wd1_match, wd2_match;

assign wd1_match[0] = addr1_match & (wd_tag1 == burst1_tag) & (wd_set1 == burst1_set); // match with burst 1
assign wd1_match[1] = addr2_match & (wd_tag1 == burst2_tag) & (wd_set1 == burst2_set); // match with burst 2

assign wd2_match[0] = addr1_match & (wd_tag2 == burst1_tag) & (wd_set2 == burst1_set); // match with burst 1
assign wd2_match[1] = addr2_match & (wd_tag2 == burst2_tag) & (wd_set2 == burst2_set); // match with burst 2

wire wd1_correction = clk_align & (wd1_match[0] | wd1_match[1]);
wire wd2_correction = clk_align & (wd2_match[0] | wd2_match[1]);

// + Map the hits to a way (one-hot to binary encoder) or if a new burst has the data
logic [1:0] wd_hit;
logic [way_bits-1:0] wd_way1, wd_way2;
always_comb begin
    wd_way1 = '0; wd_way2 = '0;
    for (int i = 0; i < WAYS; i++) begin
        if (wd_hits1[i]) wd_way1 = i;
        if (wd_hits2[i]) wd_way2 = i;
    end
    if (wd1_correction) wd_way1 = '0; // way correction if burst 1 or 2 provides new data
    if (wd2_correction) wd_way2 = '0; // way correction if burst 1 or 2 provides new data
end

assign wd_hit[0] = (|wd_hits1) | wd1_correction; // confirm hit for write-data word1 if (any way on set has the content) or (feedback burst provide the content) 
assign wd_hit[1] = (|wd_hits2) | wd2_correction; // confirm hit for write-data word2 if (any way on set has the content) or (feedback burst provide the content)
wire wd_pre_hit = (!wd_is_crossing) ? wd_hit[0] : (wd_hit[0] & wd_hit[1]);

// 7. Flip-Flop register
wire wd_post_results = WE & wd_done & wd_pre_hit;
always_ff @(negedge CLK, posedge RST) begin
    if (RST || CLR) begin 
        write_counter <= '0;
        ready[1] <= '0; hit[1] <= '0;
        queue <= 1'b0; dequeue <= 1'b0; pWBM <= '0; pWA <= '0; pWD <= '0;
        line_is_filled <= '0;
    end else begin 
        // >> Counter update logic <<
        if (wd_done && WE) write_counter <= '0;          // post results
        else if (WE) write_counter <= write_counter + 1; // standby cycles 
        ready[1] <= wd_done;
        // >> Write logic <<
        // + Replacement logic (on every clock negedge)[FIFO policy]
        line_is_filled[0] <= addr1_match & valid_burst;
        line_is_filled[1] <= addr2_match & valid_burst;
        for (int i = 0; i < WAYS; i++) begin
            // Update tags
             // Burst 1
            if (valid_burst && addr1_match) begin 
                if (i == 0) tags[burst1_set][i] <= {1'b1, burst1_tag};
                else tags[burst1_set][i] <= tags[burst1_set][i-1];
            end
            // Burst 2
            if (valid_burst && addr2_match) begin
                if (i == 0) tags[burst2_set][i] <= {1'b1, burst2_tag};
                else tags[burst2_set][i] <= tags[burst2_set][i-1];
            end
            // Update data
            for (int j = 0; j < WPL; j++) begin
                // Burst 1
                if (valid_burst && addr1_match) begin
                    if (i == 0) data[burst1_set][i][j] <= in_burst1[j];
                    else data[burst1_set][i][j] <= data[burst1_set][i-1][j];
                end
                // Burst 2
                if (valid_burst && addr2_match) begin
                    if (i == 0) data[burst2_set][i][j] <= in_burst2[j];
                    else data[burst2_set][i][j] <= data[burst2_set][i-1][j];
                end
            end
        end
        // + Write data (only during post results stages)
        if (wd_post_results) begin
                case (wd_byte_offset)
                    2'b00: begin
                        if (wd_byte1_sel) data[wd_set1][wd_way1][wd_block_offset1][7:0]   <= wd_bytes[0];
                        if (wd_byte2_sel) data[wd_set1][wd_way1][wd_block_offset1][15:8]  <= wd_bytes[1];
                        if (wd_byte3_sel) data[wd_set1][wd_way1][wd_block_offset1][23:16] <= wd_bytes[2];
                        if (wd_byte4_sel) data[wd_set1][wd_way1][wd_block_offset1][31:24] <= wd_bytes[3];
                    end

                    2'b01: begin
                        if (wd_byte1_sel) data[wd_set1][wd_way1][wd_block_offset1][15:8]  <= wd_bytes[0];
                        if (wd_byte2_sel) data[wd_set1][wd_way1][wd_block_offset1][23:16] <= wd_bytes[1];
                        if (wd_byte3_sel) data[wd_set1][wd_way1][wd_block_offset1][31:24] <= wd_bytes[2];
                        if (wd_byte4_sel) data[wd_set2][wd_way2][wd_block_offset2][7:0]   <= wd_bytes[3];
                    end

                    2'b10: begin
                        if (wd_byte1_sel) data[wd_set1][wd_way1][wd_block_offset1][23:16] <= wd_bytes[0];
                        if (wd_byte2_sel) data[wd_set1][wd_way1][wd_block_offset1][31:24] <= wd_bytes[1];
                        if (wd_byte3_sel) data[wd_set2][wd_way2][wd_block_offset2][7:0]   <= wd_bytes[2];
                        if (wd_byte4_sel) data[wd_set2][wd_way2][wd_block_offset2][15:8]  <= wd_bytes[3];
                    end

                    2'b11: begin
                        if (wd_byte1_sel) data[wd_set1][wd_way1][wd_block_offset1][31:24] <= wd_bytes[0];
                        if (wd_byte2_sel) data[wd_set2][wd_way2][wd_block_offset2][7:0]   <= wd_bytes[1];
                        if (wd_byte3_sel) data[wd_set2][wd_way2][wd_block_offset2][15:8]  <= wd_bytes[2];
                        if (wd_byte4_sel) data[wd_set2][wd_way2][wd_block_offset2][23:16] <= wd_bytes[3];
                    end
                endcase
            end
        // >> Write-through <<
        queue <= WE & wd_done; dequeue <= WE & wd_done;
        pWBM <= WBM;
        pWA <= WA;
        pWD <= WD;
        // >> Miss logic <<
        hit[1] <= wd_done & wd_pre_hit;
    end
end

endmodule