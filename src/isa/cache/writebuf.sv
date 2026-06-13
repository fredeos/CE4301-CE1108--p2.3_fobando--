// FIFO write buffer to propagate content between memory levels for 32 bit architecture
// The 'queue' signal adds the content in the input to the back of the queue
// The 'dequeue' signal removes the content at the front of the queue. In the
// memory hierarchy it is to be assumed the next memory level dequeues data once
// it has been written succesfully in it.
// The buffer has the feature to look for data written in the buffer so it can be
// forwarded for correct memory readings. However it only outputs found bytes of
// the required address
module writebuf #(
    parameter int size = 4 // Max numbers of words in buffer
)(
    // + Global signals
    input  logic CLK,
    input  logic RST,
    input  logic queue,     // add input to queue
    input  logic dequeue,   // remove output from queue
    // + Input content signals
    input  logic [31:0] addr_in, // memory address of content
    input  logic [31:0] data_in, // content
    input  logic [3:0]  bm_in,   // byte-mode propagation
    // + Input lookup signals
    input  logic [31:0] A,      // address
    input  logic [3:0] BM,      // byte-mode
    output logic [3:0][7:0] RD, // updated bytes
    output logic [3:0] hits,    // hits for each byte that must be updated
    // + Output content signals
    output logic [31:0] addr_out, // memory address of content
    output logic [31:0] data_out, // content
    output logic [3:0]  bm_out,   // byte-mode propagation
    // + Control signals
    output logic valid, // valid bit: indicates output content is real data to write on memory
    output logic hold   // hold bit: indicates that the queue is full (pipes must be stalled until a slot is available)
);
    // --- Buffer instantiaton ---
    logic [31:0]    data [0:size-1];
    logic [31:0] address [0:size-1];
    logic [4:0]  enables [0:size-1]; // [valid][BM]

    // --- Buffer initialization ---
    initial begin
        for (int i=0; i < size; i++) begin
            data[i] = '0;
            address[i] = '0;
            enables[i] = '0;
        end
    end

    // --- Auxiliary functions/decoders ---
    // 1. Boundary definition
    function automatic logic [7:0] get_boundary_bits( // auxiliary decoder for detecing boundaries
        input logic [1:0] byte_offset, // byte offset
        input logic [3:0] bm           // byte mode
    );
        logic [7:0] bits;

        case (byte_offset) 
            2'b00: bits = {4'b0000, bm};
            2'b01: bits = {3'b000, bm, 1'b0};
            2'b10: bits = {2'b00, bm, 2'b00};
            2'b11: bits = {1'b0, bm, 3'b000};
        endcase

        return bits;
    endfunction

    function automatic logic [63:0] pack_bytes(
        input logic [1:0] byte_offset,
        input logic [31:0] dta
    ); 
        logic [63:0] b = 64'b0;

        b[byte_offset*8 +: 32] = dta;

        return b;
    endfunction

    // 2. Selection of found bits
    function automatic logic [3:0] get_selection( // auxiliary decoder for retrieving selected bits
        input logic [1:0] byte_offset, // byte offset
        input logic [7:0] reference,   // reference bit boundaries
        input logic [7:0] overlap      // overlapping bit boundaries
    ); 
        logic [3:0] selection;

        case (byte_offset)
            2'b00: selection = reference[3:0] & overlap[3:0];
            2'b01: selection = reference[4:1] & overlap[4:1];
            2'b10: selection = reference[5:2] & overlap[5:2];
            2'b11: selection = reference[6:3] & overlap[6:3];
        endcase

        return selection;
    endfunction

    typedef struct packed {
        logic [7:0] overlap1;
        logic [7:0] overlap2;
        logic [1:0] ovtype;
        logic valid;
        logic [1:0] start1;
        logic [2:0] start2;
    } overlap_map_t;

    function automatic overlap_map_t map_overlap ( // auxiliary decoder for byte overlap mapping
        input logic valid,
        input logic [1:0][29:0] idx1,
        input logic [7:0]  bitmap1,
        input logic [1:0]  offset1,
        input logic [1:0][29:0] idx2,
        input logic [7:0]  bitmap2,
        input logic [1:0]  offset2
    ); 
        overlap_map_t m;

        logic [2:0] pos1 = {1'b0, offset1};
        logic [2:0] pos2 = {1'b0, offset2};
        if ((idx1[0] == idx2[0]) && valid) begin    // overlap type 1: word[0] from 1st matches word[0] from 2nd
            m.overlap1 = bitmap1 & bitmap2;
            m.overlap2 = bitmap1 & bitmap2;
            m.ovtype = 2'b01;
            m.valid = 1'b1;
            if (offset1 <= offset2) begin 
                m.start1 = offset2 - offset1;
                m.start2 = pos2;
            end else begin
                m.start1 = 2'b00;
                m.start2 = pos1;
            end
        end
        else if ((idx1[1] == idx2[0]) && valid) begin // overlap type 2: word[1] from 1st matches word[0] from 2nd
            m.overlap1 = {bitmap1[7:4] & bitmap2[3:0], 4'b0000};
            m.overlap2 = {4'b0000, bitmap1[7:4] & bitmap2[3:0]};
            m.ovtype = 2'b10;
            if (offset1 <= offset2) begin 
                m.valid = 1'b0;
                m.start1 = '0;
                m.start2 = '0;
            end else begin 
                m.valid = 1'b1;
                m.start1 = offset2 - offset1;
                m.start2 = pos2;
            end
        end
        else if ((idx1[0] == idx2[1]) && valid) begin // overlap type 3: word[0] from 1st matches word[1] from 2nd
            m.overlap1 = {4'b0000, bitmap1[3:0] & bitmap2[7:4]};
            m.overlap2 = {bitmap1[3:0] & bitmap2[7:4], 4'b0000};
            m.ovtype = 2'b11;
            if (offset2 > offset1) begin 
                m.valid = 1'b1;
                m.start1 = 2'b00;
                m.start2 = 4 + pos1;
            end else begin 
                m.valid = 1'b0;
                m.start1 = '0;
                m.start2 = '0;
            end
        end
        else begin // overlap type 0: no matching bytes
            m.overlap1 = '0;
            m.overlap2 = '0;
            m.ovtype = 2'b00;
            m.valid = 1'b0;
            m.start1 = '0;
            m.start2 = '0;
        end

        return m;
    endfunction

    function automatic logic [31:0] set_bytes (
        logic [31:0] base,
        logic [63:0] pack,
        logic [1:0]  map_type,
        logic valid_map,
        logic [7:0]  map,
        logic [1:0]  idx,
        logic [2:0]  pos
    );
        logic [31:0] prod = base;
        
        logic [1:0] idx1 = idx;
        logic [1:0] idx2 = idx + 1;
        logic [1:0] idx3 = idx + 2;
        logic [1:0] idx4 = idx + 3;

        logic [2:0] pos1 = pos;
        logic [2:0] pos2 = pos + 1;
        logic [2:0] pos3 = pos + 2;
        logic [2:0] pos4 = pos + 3;

        case (map_type) 
            2'b01: begin 
                if (valid_map) begin 
                    if (map[pos1]) prod[(idx1*8) +: 8] = pack[(pos1*8) +: 8];
                    if (map[pos2] && (idx < 3)) prod[(idx2*8) +: 8] = pack[(pos2*8) +: 8];
                    if (map[pos3] && (idx < 2)) prod[(idx3*8) +: 8] = pack[(pos3*8) +: 8];
                    if (map[pos4] && (idx < 1)) prod[(idx4*8) +: 8] = pack[(pos4*8) +: 8];
                end
            end

            2'b10: begin 
                if (valid_map) begin 
                    if (map[pos1]) prod[(idx1*8) +: 8] = pack[(pos1*8) +: 8];
                    if (map[pos2] && (idx < 3)) prod[(idx2*8) +: 8] = pack[(pos2*8) +: 8];
                    if (map[pos3] && (idx < 2)) prod[(idx3*8) +: 8] = pack[(pos3*8) +: 8];
                end
            end

            2'b11: begin 
                if (valid_map) begin 
                    if (map[pos1]) prod[(idx1*8) +: 8] = pack[(pos1*8) +: 8];
                    if (map[pos2] && (pos < 6)) prod[(idx2*8) +: 8] = pack[(pos2*8) +: 8];
                    if (map[pos3] && (pos < 5)) prod[(idx3*8) +: 8] = pack[(pos3*8) +: 8];
                end
            end
        endcase

        return prod;
    endfunction


    // --- Lookup logic (asynchronous) ---
    // NOTE: similarly to how its done in cache and memory it is required to obtain byte offset
    // and the address of the inmediate nearest lower word and the next one to check if both exist
    // on this buffer

    // 1. Obtain byte offset
    wire [1:0] lk_byte_offset = A[1:0];

    // 2. Obtain address
    logic [1:0][29:0] lk_idx; // [0]: nearest word, [1]: next word
    assign lk_idx[0] = A[31:2];
    assign lk_idx[1] = lk_idx[0] + 1;

    // 3. Boundary bits
    wire [7:0] lk_boundbits = get_boundary_bits(lk_byte_offset, BM);

    // 4. Lookup across the buffer for both words
    // ISSUE #1: Memory reading can be outdated if written data is still on the buffer, but
    // hasn't been written to the following memory level. This requires correction of whichever
    // bytes of the write data are to be updated
    // SOLUTION #1: The buffer must look for the bytes required by the given address A and
    // byte-mode BM, as such the buffer must output which bytes of the word where found 
    // and their values.
    // NOTE #2: It is to be assumed that if content is written on two different positions in
    // the buffer, the content further to the back of the queue is the most updated data and
    // therefore has precedence

    logic [31:0] lk_data [0:size-1];
    logic [3:0]  lk_hits [0:size-1];
    generate;
        for (genvar i = 0; i < size; i++) begin
            // + Get byte offset from data on buffer
            logic [1:0] bf_byte_offset;
            assign bf_byte_offset = address[i][1:0];
            // + Get index's for data on buffer
            logic [1:0][29:0] bf_idx;
            assign bf_idx[0] = address[i][31:2];
            assign bf_idx[1] = bf_idx[0] + 1;
            // + Get the byte-mode and valid bit on buffer
            logic is_valid;
            logic [3:0] bf_bm;
            assign {is_valid, bf_bm} = enables[i];
            // + Get the boundary bits
            logic [7:0] bf_boundbits;
            assign bf_boundbits = get_boundary_bits(bf_byte_offset, bf_bm);
            // + Pack data bytes
            logic [63:0] bf_data;
            assign bf_data = pack_bytes(bf_byte_offset, data[i]);
            // + Generate overlap map
            overlap_map_t tmp_map;
            assign tmp_map = map_overlap(
                is_valid,
                lk_idx, lk_boundbits, lk_byte_offset,
                bf_idx, bf_boundbits, bf_byte_offset
            );
            // + Identify byte hits with lookup data
            logic [3:0] bf_hits;
            assign bf_hits = get_selection(lk_byte_offset, lk_boundbits, tmp_map.overlap1);
            // + Use map to override bytes for look up data
            if (i == 0) begin
                assign lk_hits[i] = bf_hits;
                assign lk_data[i] = set_bytes(
                    32'b0,
                    bf_data,
                    tmp_map.ovtype,
                    tmp_map.valid,
                    tmp_map.overlap2,
                    tmp_map.start1,
                    tmp_map.start2
                );
            end else begin 
                assign lk_hits[i] = lk_hits[i-1] | bf_hits;
                assign lk_data[i] = set_bytes(
                    lk_data[i-1],
                    bf_data,
                    tmp_map.ovtype,
                    tmp_map.valid,
                    tmp_map.overlap2,
                    tmp_map.start1,
                    tmp_map.start2
                );
            end
        end
    endgenerate

    assign hits = lk_hits[size-1];
    assign RD   = lk_data[size-1];

    // --- Writing logic (synchronous) ---
    logic [31:0] idx, next_idx, in_idx;
    wire dequeue_possible = dequeue & (idx > 0);
    wire queue_possible = queue & ((idx < size) | dequeue_possible);
    always_comb begin
        next_idx = idx;
        in_idx = idx;
        if (queue_possible) next_idx = idx + 1;
        if (dequeue_possible) next_idx = idx - 1;
        if (queue_possible && dequeue_possible) begin 
            next_idx = idx;
            in_idx = idx - 1;
        end
    end

    always_ff @(negedge CLK, posedge RST) begin
        if (RST) begin
            idx <= '0;
            for (int i=0; i < size; i++) begin
                data[i] <= '0;
                address[i] <= '0;
                enables[i] <= '0;
            end
        end else begin
            idx <= next_idx;
            if (dequeue_possible) begin
                for (int i = 0; i < size; i++) begin 
                    if (i == size-1) begin 
                        data[i] <= '0;
                        address[i] <= '0;
                        enables[i] <= '0;
                    end else begin
                        data[i] <= data[i+1];
                        address[i] <= address[i+1];
                        enables[i] <= enables[i+1];
                    end
                end
            end
            if (queue_possible) begin
                address[in_idx] <= addr_in;
                data[in_idx] <= data_in;
                enables[in_idx] <= {1'b1, bm_in};
            end
        end
    end

    // --- Content output logic ---
    assign hold = (idx == size);
    assign addr_out = address[0];
    assign data_out = data[0];
    assign bm_out   = enables[0][3:0];
    assign valid    = enables[0][4];
endmodule