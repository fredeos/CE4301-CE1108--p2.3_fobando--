// Associative cache memory module for 32 bit architectures.
// Number of sets is infered from SIZE and WAYS
// Write policy: Write-through (write buffer)
// Replacement policy: FIFO (queue-like shifting of data blocks)
module cache #(
    parameter int SIZE = 32,    // Cache memory SIZE (in bytes) [default: 32 bytes]
    parameter int WPL  = 2,     // words-per-line               [default: 2 (min)]
    parameter int WAYS = 2,     // Cache memory number of WAYS per line [default: 2 (min)]
    parameter int LATENCY = 1   // Cache memory LATENCY simulation (number of CLK cycles) [default: 1 (min)]
)( 
    // + Sequential logic inputs
    input  logic CLK,
    input  logic RST,
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
    // + Write-through output signals
    output logic queue,   // write buffer queue
    output logic dequeue, // write buffer dequeue
    output logic [3:0] pWBM, // propagate WBM
    output logic [31:0] pWA, // propagate write address
    output logic [31:0] pWD  // propagate write data
    // + Miss output signals
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
            if (i == 0 && j == 1)      tags[i][j] = {1'b1, 28'd0};
            else if (i == 0 && j == 0) tags[i][j] = {1'b1, 28'd1};
            else if (i == 1 && j == 0) tags[i][j] = {1'b1, 28'd0};
            for (int k = 0; k < WPL; k++) begin
                data[i][j][k] = '0;
                if (i == 0 && j == 1 && k == 0)      data[i][j][k] = 32'h000010A2; // 0x0
                else if (i == 0 && j == 1 && k == 1) data[i][j][k] = 32'hDEADBEEF; // 0x4
                else if (i == 0 && j == 0 && k == 0) data[i][j][k] = 32'd1;        // 0x16
                else if (i == 0 && j == 0 && k == 1) data[i][j][k] = 32'd2;        // 0x20
                else if (i == 1 && j == 0 && k == 0) data[i][j][k] = 32'h12345678; // 0x8
                else if (i == 1 && j == 0 && k == 1) data[i][j][k] = 32'h0ABCDEF1; // 0x12
            end
        end
    end
end

// --- Address decoding ---
// ISSUE #1: What happens if i access half words? For example address 0x02 maps to 
// upper half of word 0 and lower half of word 1
// SOLUTION #1: (a) cache must decode to the inmediate lower word and the next one to check if both
// map to a set in cache, if one is not available throw a miss. (b) use signals byte_offset and
// ASM to determine correct byte mapping for buffered output RD 
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

// 1. Read address decoding
logic [1:0]  rd_byte_offset;
logic [29:0] rd_word_idx1, rd_word_idx2;
logic [block_bits-1:0] rd_block_offset1, rd_block_offset2;
logic [set_bits-1:0]   rd_set1, rd_set2;
logic [tag_bits-1:0]   rd_tag1, rd_tag2;

assign rd_byte_offset = RA[1:0];

assign rd_word_idx1 = RA[31:2];
assign {rd_tag1, rd_set1, rd_block_offset1} = decode_address(rd_word_idx1);

assign rd_word_idx2 = rd_word_idx1 + 1;
assign {rd_tag2, rd_set2, rd_block_offset2} = decode_address(rd_word_idx2);

// 2. Write address decoding
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

// --- Combinational logic (address mapping) ---
// 1. Boundary crossing tolerance
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

logic rd_is_crossing, wd_is_crossing;
assign rd_is_crossing = is_crossing(rd_byte_offset, RBM);
assign wd_is_crossing = is_crossing(wd_byte_offset, WBM);

// 2. Hit detection
// + Checks the tags array to verify if the address is mapped on this cache; check each way of the correspoding set
// and verify if tags match and if valid/dirty bits indicate a valid data block. There is chance both words map to
// the same set and even to the same way
function logic [WAYS-1:0] hit_detect ( // auxilary decoder for hit detection
    input logic [set_bits-1:0] set,
    input logic [tag_bits-1:0] tag
);
    logic [WAYS-1:0] hits;
    
    logic [tag_bits:0] mapped_tag [0:WAYS-1]; // mapped tags for set
    logic [tag_bits-1:0]     ctag [0:WAYS-1]; // tags on cache for each way in set
    logic [WAYS-1:0] valid;                   // valid bit on each way in set
    for (int i = 0; i < WAYS; i++) begin
        mapped_tag[i] = tags[set][i];
        {valid[i], ctag[i]} = mapped_tag[i];
        if (valid[i] && ctag[i] == tag) hits[i] = 1'b1;
        else hits[i] = 1'b0;
    end 

    return hits;
endfunction

logic [WAYS-1:0] rd_hits1, rd_hits2;
assign rd_hits1 = hit_detect(rd_set1, rd_tag1);
assign rd_hits2 = hit_detect(rd_set2, rd_tag2);

logic [WAYS-1:0] wd_hits1, wd_hits2;
assign wd_hits1 = hit_detect(wd_set1, wd_tag1);
assign wd_hits2 = hit_detect(wd_set2, wd_tag2);

// + Throws miss signal to prompt next memory level to start searching for results
logic [1:0] rd_hit;
logic [way_bits-1:0] rd_way1, rd_way2;

logic [1:0] wd_hit;
logic [way_bits-1:0] wd_way1, wd_way2;

always_comb begin
    rd_way1 = '0; rd_way2 = '0;
    wd_way1 = '0; wd_way2 = '0;
    for (int i = 0; i < WAYS; i++) begin
        if (rd_hits1[i]) rd_way1 = i;
        if (rd_hits2[i]) rd_way2 = i;
        if (wd_hits1[i]) wd_way1 = i;
        if (wd_hits2[i]) wd_way2 = i;
    end
end

assign rd_hit[0] = |rd_hits1;
assign rd_hit[1] = |rd_hits2;
wire rd_pre_hit = (!rd_is_crossing) ? rd_hit[0] : (rd_hit[0] & rd_hit[1]);

assign wd_hit[0] = |wd_hits1;
assign wd_hit[1] = |wd_hits2;
wire wd_pre_hit = (!wd_is_crossing) ? wd_hit[0] : (wd_hit[0] & wd_hit[1]);

// 3. Read & write byte decodings (+ data bypass)
// ISSUE #2: The innate behavior of memory hierarchy and latency allows potential cases
// when data that is being accessed is also currently being written
// SOLUTION #2: Allow data bypass if write is enabled and the write and read address match

logic [7:0] wd_bytes [0:3];
assign wd_bytes[0] = WD[7:0];
assign wd_bytes[1] = WD[15:8];
assign wd_bytes[2] = WD[23:16];
assign wd_bytes[3] = WD[31:24];

logic [7:0] rd_bytes  [0:7];
assign rd_bytes[0] = data[rd_set1][rd_way1][rd_block_offset1][7:0];
assign rd_bytes[1] = data[rd_set1][rd_way1][rd_block_offset1][15:8];
assign rd_bytes[2] = data[rd_set1][rd_way1][rd_block_offset1][23:16];
assign rd_bytes[3] = data[rd_set1][rd_way1][rd_block_offset1][31:24];
assign rd_bytes[4] = data[rd_set2][rd_way2][rd_block_offset2][7:0];
assign rd_bytes[5] = data[rd_set2][rd_way2][rd_block_offset2][15:8];
assign rd_bytes[6] = data[rd_set2][rd_way2][rd_block_offset2][23:16];
assign rd_bytes[7] = data[rd_set2][rd_way2][rd_block_offset2][31:24];

// --- Synchronous write (store) ---
// + Write byte selections
wire wd_byte1_sel = WBM[0];
wire wd_byte2_sel = WBM[1];
wire wd_byte3_sel = WBM[2];
wire wd_byte4_sel = WBM[3];

// + Flip-Flop
logic [31:0] read_counter, write_counter;
always_ff @(negedge CLK, posedge RST) begin
    if (RST) begin 
        write_counter <= '0;
        ready[1] <= '0; hit[1] <= '0;
        queue <= 1'b0; dequeue <= 1'b0; pWBM <= '0; pWA <= '0; pWD <= '0;
    end 
    else if (WE) begin
        if (write_counter == (LATENCY-1)) begin // post results
            ready[1] <= 1'b1;
            // >> Miss logic <<
            hit[1] <= wd_pre_hit;
            // >> Write-through logic <<
            queue <= 1'b1; dequeue <= 1'b1;
            pWBM <= WBM;
            pWA <= WA;
            pWD <= WD;
            // >> Write logic <<
            if (wd_pre_hit) begin
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
            write_counter <= '0;
        end else begin  // standby cycles (waiting for results)
            write_counter <= write_counter + 1;
            ready[1] <= '0; hit[1] <= '0;
            queue <= 1'b0; dequeue <= 1'b0; pWBM <= '0; pWA <= '0; pWD <= '0;
        end
    end 
    else begin
        write_counter <= '0;
        ready[1] <= '0; hit[1] <= '0;
        queue <= 1'b0; dequeue <= 1'b0; pWBM <= '0; pWA <= '0; pWD <= '0;
    end
end

// --- Synchronous read (load) ---
// + Read byte selections
wire rd_byte1_sel = RBM[0];
wire rd_byte2_sel = RBM[1];
wire rd_byte3_sel = RBM[2];
wire rd_byte4_sel = RBM[3];

// + Synchronous read
logic [7:0] read_data [0:3];
assign RD = {read_data[3], read_data[2], read_data[1], read_data[0]};
always_ff @(posedge CLK, posedge RST) begin
    if (RST) begin
        // Reset logic
        read_counter <= '0;
        ready[0] <= '0; hit[0] <= '0;
        read_data[0] <= '0; read_data[1] <= '0; read_data[2] <= '0; read_data[3] <= '0;
    end 
    else if (RE) begin
        if (read_counter == (LATENCY-1)) begin // post results
            ready[0] <= 1'b1;
            // >> Miss logic <<
            hit[0]  <= rd_pre_hit;
            // >> Read logic <<
            read_data[0] <= '0; read_data[1] <= '0; read_data[2] <= '0; read_data[3] <= '0;
            if (rd_pre_hit) begin
                case (rd_byte_offset)
                    2'b00: begin 
                        if (rd_byte1_sel) read_data[0] <= rd_bytes[0];
                        if (rd_byte2_sel) read_data[1] <= rd_bytes[1];
                        if (rd_byte3_sel) read_data[2] <= rd_bytes[2];
                        if (rd_byte4_sel) read_data[3] <= rd_bytes[3];
                    end

                    2'b01: begin 
                        if (rd_byte1_sel) read_data[0] <= rd_bytes[1];
                        if (rd_byte2_sel) read_data[1] <= rd_bytes[2];
                        if (rd_byte3_sel) read_data[2] <= rd_bytes[3];
                        if (rd_byte4_sel) read_data[3] <= rd_bytes[4];
                    end

                    2'b10: begin 
                        if (rd_byte1_sel) read_data[0] <= rd_bytes[2];
                        if (rd_byte2_sel) read_data[1] <= rd_bytes[3];
                        if (rd_byte3_sel) read_data[2] <= rd_bytes[4];
                        if (rd_byte4_sel) read_data[3] <= rd_bytes[5];
                    end

                    2'b11: begin 
                        if (rd_byte1_sel) read_data[0] <= rd_bytes[3];
                        if (rd_byte2_sel) read_data[1] <= rd_bytes[4];
                        if (rd_byte3_sel) read_data[2] <= rd_bytes[5];
                        if (rd_byte4_sel) read_data[3] <= rd_bytes[6];
                    end
                endcase
            end
            read_counter <= '0;
        end else begin // standby cycles (waiting for results)
            read_counter <= read_counter + 1;
            ready[0] <= '0; hit[0] <= '0;
            read_data[0] <= '0; read_data[1] <= '0; read_data[2] <= '0; read_data[3] <= '0;
        end
    end 
    else begin 
        read_counter <= '0;
        ready[0] <= '0; hit[0] <= '0;
        read_data[0] <= '0; read_data[1] <= '0; read_data[2] <= '0; read_data[3] <= '0;
    end
end

endmodule