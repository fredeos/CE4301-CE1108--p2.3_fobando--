// Associative cache memory module for 32 bit architectures.
// Number of sets is infered from SIZE and WAYS
// Write policy: Write-through (write buffer)
// Replacement policy: FIFO (queue-like shifting of data blocks)
module cache #(
    parameter SIZE = 32,    // Cache memory SIZE (in bytes) [default: 32 bytes]
    parameter WPL  = 2,     // words-per-line               [default: 2 (min)]
    parameter WAYS = 2,     // Cache memory number of WAYS per line [default: 2 (min)]
    parameter LATENCY = 1   // Cache memory LATENCY simulation (number of CLK cycles) [default: 1 (min)]
)( 
    // + Sequential logic inputs
    input  logic CLK,
    input  logic RST,
    // + Input control signals
    input  logic WE,
    input  logic [3:0] ASM, // address selection mode
    // + Buffered input signals
    input  logic [31:0] A,
    input  logic [31:0] WD,
    // + Output control signals
    output logic hit,   // cache hit
    output logic ready, // cache ready
    output logic queue,   // write buffer queue
    output logic dequeue, // write buffer dequeue
    output logic miss1, // miss on word 1
    output logic miss2, // miss on word 2
    output logic [3:0] pASM, // propagate ASM
    // + Buffered output signals
    output logic [31:0] RD,  // read-data
    output logic [31:0] pWA, // propagate write address
    output logic [31:0] pWD, // propagate write data
    output logic [31:0] mA1, // miss address 1
    output logic [31:0] mA2  // miss address 2
);
// --- Dynamic parameter calculation ---
localparam BLOCKS = SIZE/(WPL*4);   // number of cache memory blocks
localparam SETS = BLOCKS/WAYS;      // number of cache memory sets

localparam block_bits = $clog2(WPL); // required bits from address for block offset
localparam set_bits = $clog2(SETS);  // required bits from address for set selection
localparam way_bits = $clog2(WAYS);  // required bits for way selection
localparam tag_bits = 32 - set_bits - block_bits - 2; // required bits from address for tag selection

localparam block_to_set = block_bits + set_bits; // range of bits from block offset end to set selection end

// --- Cache array instantiation ---
logic [31:0] data [0:SETS-1][0:WAYS-1][0:WPL-1]; // array for data blocks => [wordN]...[word0]
logic [tag_bits:0] tags [0:SETS-1][0:WAYS-1];  // array for tags => [valid][tag]

initial begin
    for (int i = 0; i < SETS; i++) begin
        for (int j = 0; j < WAYS; j++) begin
            tags[i][j] = '0;
            if (i == 0 && j == 1)      tags[i][j] = {1'b1, 28'd0};
            else if (i == 0 && j == 0) tags[i][j] = {1'b1, 28'd1};
            else if (i == 1 && j == 0) tags[i][j] = {1'b1, 28'd0};
            for (int k = 0; k < WPL; k++) begin
                data[i][j][k] = '0;
                if (i == 0 && j == 1 && k == 0)      data[i][j][k] = 32'h000010A2;
                else if (i == 0 && j == 1 && k == 1) data[i][j][k] = 32'hDEADBEEF;
                else if (i == 0 && j == 0 && k == 0) data[i][j][k] = 32'd1;
                else if (i == 0 && j == 0 && k == 1) data[i][j][k] = 32'd2;
                else if (i == 1 && j == 0 && k == 0) data[i][j][k] = 32'h12345678;
                else if (i == 1 && j == 0 && k == 1) data[i][j][k] = 32'h0ABCDEF1;
            end
        end
    end
end

// --- Address decoding ---
logic [1:0] byte_offset;
// ISSUE #1: What happens if i access half words? For example address 0x02 maps to 
// upper half of word 0 and lower half of word 1
// SOLUTION #1: (a) cache must decode to the inmediate lower word and the next one to check if both
// map to a set in cache, if one is not available throw a miss. (b) use signals byte_offset and
// ASM to determine correct byte mapping for buffered output RD 
logic [29:0] word_idx1, word_idx2;
logic [block_bits-1:0] block_offset1, block_offset2;
logic [set_bits-1:0] set1, set2;
logic [tag_bits-1:0] tag1, tag2;

assign byte_offset = A[1:0];

assign word_idx1 = A[31:2];
assign block_offset1 = word_idx1[block_bits-1:0];
assign set1 = word_idx1[block_to_set-1:block_bits];
assign tag1 = word_idx1[29:block_to_set];

assign word_idx2 = word_idx1 + 1;
assign block_offset2 = word_idx2[block_bits-1:0];
assign set2 = word_idx2[block_to_set-1:block_bits];
assign tag2 = word_idx2[29:block_to_set];

// --- Combinational logic (address mapping) ---
// 1. Boundary crossing tolerance
// + Verifies if the given address and byte selection generates conflict with boundary crossing,
// which has potential to access invalid cache data blocks
logic is_crossing;
always_comb begin
    is_crossing = 1'b0;
    case (byte_offset)
        2'b00: begin
            is_crossing = 1'b0;
        end

        2'b01: begin
            if (ASM == 4'b1111) is_crossing = 1'b1;
        end

        2'b10: begin
            if (ASM == 4'b1111 || ASM == 4'b0111) is_crossing = 1'b1;
        end

        2'b11: begin
            if (ASM != 4'b0001) is_crossing = 1'b1;
        end
    endcase
end

// 2. Hit detection
// + Checks the tags array to verify if the address is mapped on this cache; check each way of the correspoding set
// and verify if tags match and if valid/dirty bits indicate a valid data block. There is chance both words map to
// the same set and even to the same way
// + Throws miss signal to prompt next memory level to start searching for results
logic [1:0] hits; // hits per word
logic [WAYS-1:0] hitw1, hitw2;

logic [tag_bits:0] mapped_tag1 [0:WAYS-1];
logic [tag_bits:0] mapped_tag2 [0:WAYS-1];

logic [WAYS-1:0] valid1, valid2;
logic [tag_bits-1:0] ctag1 [0:WAYS-1];
logic [tag_bits-1:0] ctag2 [0:WAYS-1];
always_comb begin
    for (int i = 0; i < WAYS; i++) begin
        mapped_tag1[i] = tags[set1][i];
        hitw1[i] = 1'b0;
        {valid1[i], ctag1[i]} = mapped_tag1[i];
        if (valid1[i] && (ctag1[i] == tag1)) hitw1[i] = 1'b1;

        mapped_tag2[i] = tags[set2][i];
        hitw2[i] = 1'b0;
        {valid2[i], ctag2[i]} = mapped_tag2[i];
        if (valid2[i] && (ctag2[i] == tag2)) hitw2[i] = 1'b1;
    end
end

logic [way_bits-1:0] way1, way2;
always_comb begin
    way1 = '0; way2 = '0;
    for (int i = 0; i < WAYS; i++) begin
        if (hitw1[i]) way1 = i;
        if (hitw2[i]) way2 = i;
    end
end

assign hits[0] = |hitw1;
assign hits[1] = |hitw2;
wire pre_hit = (!is_crossing) ? hits[0] : (hits[0] & hits[1]);
// --- Sequential logic (flip-flop) ---
// + Synchronous write
// + Synchronous read
logic [31:0] counter;
logic [7:0]  rd_byte1, rd_byte2, rd_byte3, rd_byte4;
assign RD = {rd_byte4, rd_byte3, rd_byte2, rd_byte1};

wire byte1 = ASM[0];
wire byte2 = ASM[1];
wire byte3 = ASM[2];
wire byte4 = ASM[3];
always_ff @(posedge CLK, posedge RST) begin
    if (RST) begin
        // Reset logic
        counter <= '0;
        hit <= '0; ready = '0;
        rd_byte1 <= '0; rd_byte2 <= '0; rd_byte3 <= '0; rd_byte4 <= '0;
        queue <= 1'b0; dequeue <= 1'b0; pWA <= '0; pWD <= '0; pASM <= '0;
        miss1 <= 1'b0; miss2 <= 1'b0; mA1 <= '0; mA2 <= '0;
    end else if (counter == (LATENCY-1)) begin // post results
        hit <= pre_hit;
        // >> Miss logic <<
        // + Upon a miss, cache must signal which word is missing to next memory level
        miss1 <= 1'b0; miss2 <= 1'b0; mA1 <= '0; mA2 <= '0;
        if (!hits[0]) begin 
            miss1 <= 1'b1;
            mA1   <= {word_idx1, 2'b00};
        end
        if (!hits[1]) begin
            miss2 <= 1'b1;
            mA2   <= {word_idx2, 2'b00};
        end
        // >> Write-through logic <<
        queue <= 1'b0; dequeue <= 1'b0; pWA <= '0; pWD <= '0; pASM <= '0;
        if (WE && pre_hit) begin
            queue <= 1'b1;
            dequeue <= 1'b1;
            pASM <= ASM;
            pWA <= A;
            pWD <= WD;
        end
        // >> Read & write logic <<
        rd_byte1 <= '0; rd_byte2 <= '0; rd_byte3 <= '0; rd_byte4 <= '0;
        if (pre_hit) begin
            case (byte_offset)
                2'b00: begin // 0 byte offset
                    if (byte1) begin 
                        if (WE) data[set1][way1][block_offset1][7:0] <= WD[7:0];
                        rd_byte1 <= data[set1][way1][block_offset1][7:0];
                    end
                    if (byte2) begin 
                        if (WE) data[set1][way1][block_offset1][15:8] <= WD[15:8];
                        rd_byte2 <= data[set1][way1][block_offset1][15:8];
                    end
                    if (byte3) begin 
                        if (WE) data[set1][way1][block_offset1][23:16] <= WD[23:16];
                        rd_byte3 <= data[set1][way1][block_offset1][23:16];
                    end
                    if (byte4) begin 
                        if (WE) data[set1][way1][block_offset1][31:24] <= WD[31:24];
                        rd_byte4 <= data[set1][way1][block_offset1][31:24];
                    end
                end

                2'b01: begin // 1 byte offset
                    if (byte1) begin 
                        if (WE) data[set1][way1][block_offset1][15:8] <= WD[7:0];
                        rd_byte1 <= data[set1][way1][block_offset1][15:8];
                    end
                    if (byte2) begin 
                        if (WE) data[set1][way1][block_offset1][23:16] <= WD[15:8];
                        rd_byte2 <= data[set1][way1][block_offset1][23:16];
                    end
                    if (byte3) begin 
                        if (WE) data[set1][way1][block_offset1][31:24] <= WD[23:16];
                        rd_byte3 <= data[set1][way1][block_offset1][31:24];
                    end
                    if (byte4) begin 
                        if (WE) data[set2][way2][block_offset2][7:0] <= WD[31:24];
                        rd_byte4 <= data[set2][way2][block_offset2][7:0];
                    end
                end

                2'b10: begin // 2 byte offset
                    if (byte1) begin 
                        if (WE) data[set1][way1][block_offset1][23:16] <= WD[7:0];
                        rd_byte1 <= data[set1][way1][block_offset1][23:16];
                    end
                    if (byte2) begin 
                        if (WE) data[set1][way1][block_offset1][31:24] <= WD[15:8];
                        rd_byte2 <= data[set1][way1][block_offset1][31:24];
                    end
                    if (byte3) begin 
                        if (WE) data[set2][way2][block_offset2][7:0] <= WD[23:16];
                        rd_byte3 <= data[set2][way2][block_offset2][7:0];
                    end
                    if (byte4) begin 
                        if (WE) data[set2][way2][block_offset2][15:8] <= WD[31:24];
                        rd_byte4 <= data[set2][way2][block_offset2][15:8];
                    end
                end

                2'b11: begin // 3 byte offset
                    if (byte1) begin 
                        if (WE) data[set1][way1][block_offset1][31:24] <= WD[7:0];
                        rd_byte1 <= data[set1][way1][block_offset1][31:24];
                    end
                    if (byte2) begin 
                        if (WE) data[set2][way2][block_offset2][7:0] <= WD[15:8];
                        rd_byte2 <= data[set2][way2][block_offset2][7:0];
                    end
                    if (byte3) begin 
                        if (WE) data[set2][way2][block_offset2][15:8] <= WD[23:16];
                        rd_byte3 <= data[set2][way2][block_offset2][15:8];
                    end
                    if (byte4) begin 
                        if (WE) data[set2][way2][block_offset2][23:16] <= WD[31:24];
                        rd_byte4 <= data[set2][way2][block_offset2][23:16];
                    end
                end
            endcase
        end
        counter <= '0;
        ready <= 1'b1;
    end else begin // standby cycles (waiting for results)
        counter <= counter + 1;
        rd_byte1 <= '0; rd_byte2 <= '0; rd_byte3 <= '0; rd_byte4 <= '0;
        hit <= 0; ready <= 1'b0;
        queue <= 1'b0; dequeue <= 1'b0; pWA <= '0; pWD <= '0; pASM <= '0;
        miss1 <= 1'b0; miss2 <= 1'b0; mA1 <= '0; mA2 <= '0;
    end
end

endmodule