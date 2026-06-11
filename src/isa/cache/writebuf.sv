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
    logic [4:0]  enables [0:size-1]; // [valid][ASM]

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


    // --- Lookup logic (asynchronous) ---
    // NOTE: similarly to how its done in cache and memory it is required to obtain byte offset
    // and the address of the inmediate nearest lower word and the next one to check if both exist
    // on this buffer

    // 1. Obtain byte offset
    wire [1:0] lk_byte_offset = A[1:0];

    // 2. Obtain address
    logic [29:0] lk_idx [0:1]; // [0]: nearest word, [1]: next word
    assign lk_idx[0] = A[31:2];
    assign lk_idx[1] = lk_idx[0] + 1;

    // 3. Boundary crossing bits
    wire [7:0] lk_boundbits = get_boundary_bits(lk_byte_offset, BM);

    logic [1:0][3:0] lk_wordbits; // [0]: nearest word, [1]: next word
    assign lk_wordbits[0] = lk_boundbits[3:0];
    assign lk_wordbits[1] = lk_boundbits[7:0];

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

    // + Extract data from buffer
    logic [1:0]  bf_byte_offset [0:size-1];
    logic [29:0] bf_idx [0:size-1][0:1]; // [0]: nearest word, [1]: next word
    logic bf_valid [0:size-1];
    logic [3:0] bf_bm [0:size-1];
    logic [7:0] bf_boundbits [0:size-1];
    logic [1:0][3:0] bf_wordbits [0:size-1]; // [0]: nearest word, [1]: next word
    generate;
        genvar i;
        for (i = 0; i < size; i++) begin 
            // + Get byte offset
            assign bf_byte_offset[i] = address[i][1:0];
            // + Get index's
            assign bf_idx[i][0] = address[i][31:2];
            assign bf_idx[i][1] = bf_idx[i][0] + 1;
            // + Get valid and BM bits
            assign bf_valid[i] = enables[i][4];
            assign bf_bm[i] = enables[i][3:0];
            // + Get boundary bits
            assign bf_boundbits[i] = get_boundary_bits(bf_byte_offset[i], bf_bm[i]);
            assign bf_wordbits[i][0] = bf_boundbits[i][3:0];
            assign bf_wordbits[i][1] = bf_boundbits[i][7:4]; 
        end
    endgenerate

    // + Identify which content from buffer provides updated data
    logic [1:0][3:0] bit_overlap [0:size-1];
    logic [7:0] bf_selbits   [0:size-1];
    logic [7:0] lk_selbits   [0:size-1];
    logic [1:0] word_overlap [0:size-1];
    always_comb begin
        for (int i = 0; i < size; i++) begin
            bit_overlap[i][0] = 4'b0000;
            bit_overlap[i][1] = 4'b0000;
            word_overlap[i] = 2'b00;
            bf_selbits[i] = '0;
            lk_selbits[i] = '0;
            if ((lk_idx[0] == bf_idx[i][0]) && bf_valid[i]) begin 
                bit_overlap[i][0] = lk_wordbits[0] & bf_wordbits[i][0];
                bit_overlap[i][1] = lk_wordbits[1] & bf_wordbits[i][1];
                word_overlap[i] = 2'b01;
                bf_selbits[i] = {bit_overlap[i][1], bit_overlap[i][0]};
                lk_selbits[i] = {bit_overlap[i][1], bit_overlap[i][0]};
            end
            else if ((lk_idx[1] == bf_idx[i][0]) && bf_valid[i]) begin
                bit_overlap[i][0] = 4'b0000;
                bit_overlap[i][1] = lk_wordbits[1] & bf_wordbits[i][0];
                word_overlap[i] = 2'b10;
                bf_selbits[i] = {bit_overlap[i][0], bit_overlap[i][1]};
                lk_selbits[i] = {bit_overlap[i][1], bit_overlap[i][0]};
            end
            else if ((lk_idx[0] == bf_idx[i][1]) && bf_valid[i]) begin
                bit_overlap[i][0] = lk_wordbits[0] & bf_wordbits[i][1];
                bit_overlap[i][1] = 4'b0000;
                word_overlap[i] = 2'b11;
                bf_selbits[i] = {bit_overlap[i][0], bit_overlap[i][1]};
                lk_selbits[i] = {bit_overlap[i][1], bit_overlap[i][0]};
            end
            
        end
    end

    // + Obtain the selected bytes from the matching written data
    logic [3:0] bf_sel  [0:size-1];
    logic bf_sels       [0:size-1][0:3];
    logic [3:0] lk_hits [0:size-1];
    logic [3:0][7:0] bf_bytes [0:size-1];
    generate 
        for (i = 0; i < size; i++) begin
            assign bf_sel[i] = get_selection(bf_byte_offset[i], bf_boundbits[i], bf_selbits[i]);
            assign bf_sels[i][0] = bf_sel[i][0];
            assign bf_sels[i][1] = bf_sel[i][1];
            assign bf_sels[i][2] = bf_sel[i][2];
            assign bf_sels[i][3] = bf_sel[i][3];
            assign lk_hits[i] = get_selection(lk_byte_offset, lk_boundbits, lk_selbits[i]);
            assign bf_bytes[i][0] = (bf_sels[i][0]) ? data[i][7:0]   : '0;
            assign bf_bytes[i][1] = (bf_sels[i][1]) ? data[i][15:8]  : '0;
            assign bf_bytes[i][2] = (bf_sels[i][2]) ? data[i][23:16] : '0;
            assign bf_bytes[i][3] = (bf_sels[i][3]) ? data[i][31:24] : '0;
        end
    endgenerate

    // + Select each updated byte according for outputing
    logic [3:0] lk_thits [0:size-1];
    always_comb begin
        RD[0] = '0; RD[1] = '0; RD[2] = '0; RD[3] = '0; 
        for (int i = 0; i < size; i++) begin
            if (i == 0) lk_thits[i] = lk_hits[i];
            else lk_thits[i] = lk_thits[i-1] | lk_hits[i];
            case (bf_byte_offset[i]) 
                2'b00: begin 
                    case (lk_byte_offset)
                        2'b00: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[0] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[1] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[2] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[3] = bf_bytes[i][3];
                            end
                        end
                        2'b01: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][1]) RD[0] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[1] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[2] = bf_bytes[i][3];
                            end
                            if (word_overlap[i] == 2'b10) begin
                                if (bf_sels[i][0]) RD[3] = bf_bytes[i][0];
                            end
                        end
                        2'b10: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][2]) RD[0] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[1] = bf_bytes[i][3];
                            end
                            if (word_overlap[i] == 2'b10) begin
                                if (bf_sels[i][0]) RD[2] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[3] = bf_bytes[i][1];
                            end
                        end
                        2'b11: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][3]) RD[0] = bf_bytes[i][3];
                            end
                            if (word_overlap[i] == 2'b10) begin
                                if (bf_sels[i][0]) RD[1] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[2] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[3] = bf_bytes[i][2];
                            end
                        end
                    endcase
                end

                2'b01: begin 
                    case (lk_byte_offset) 
                        2'b00: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[1] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[2] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[3] = bf_bytes[i][2];
                            end
                            if (word_overlap[i] == 2'b11) begin
                                if (bf_sels[i][3]) RD[0] = bf_bytes[i][3];
                            end
                        end
                        2'b01: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[0] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[1] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[2] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[3] = bf_bytes[i][3];
                            end
                        end
                        2'b10: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][1]) RD[0] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[1] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[2] = bf_bytes[i][3];
                            end
                            if (word_overlap[i] == 2'b10) begin
                                if (bf_sels[i][0]) RD[3] = bf_bytes[i][0];
                            end
                        end
                        2'b11: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][2]) RD[0] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[1] = bf_bytes[i][3];
                            end
                            if (word_overlap[i] == 2'b10) begin
                                if (bf_sels[i][0]) RD[2] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[3] = bf_bytes[i][1];
                            end
                        end
                    endcase
                end

                2'b10: begin 
                    case (lk_byte_offset) 
                        2'b00: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[2] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[3] = bf_bytes[i][1];
                            end
                            if (word_overlap[i] == 2'b11) begin
                                if (bf_sels[i][2]) RD[0] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[1] = bf_bytes[i][3];
                            end
                        end
                        2'b01: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[1] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[2] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[3] = bf_bytes[i][2];
                            end
                            if (word_overlap[i] == 2'b11) begin
                                if (bf_sels[i][3]) RD[0] = bf_bytes[i][3];
                            end
                        end
                        2'b10: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[0] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[1] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[2] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[3] = bf_bytes[i][3];
                            end
                        end
                        2'b11: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][1]) RD[0] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[1] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[2] = bf_bytes[i][3];
                            end
                            if (word_overlap[i] == 2'b10) begin
                                if (bf_sels[i][0]) RD[3] = bf_bytes[i][0];
                            end
                        end
                    endcase
                end

                2'b11: begin 
                    case (lk_byte_offset) 
                        2'b00: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[3] = bf_bytes[i][0];
                            end
                            if (word_overlap[i] == 2'b11) begin
                                if (bf_sels[i][1]) RD[0] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[1] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[2] = bf_bytes[i][3];
                            end
                        end
                        2'b01: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[2] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[3] = bf_bytes[i][1];
                            end
                            if (word_overlap[i] == 2'b11) begin
                                if (bf_sels[i][2]) RD[0] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[1] = bf_bytes[i][3];
                            end
                        end
                        2'b10: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[1] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[2] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[3] = bf_bytes[i][2];
                            end
                            if (word_overlap[i] == 2'b11) begin
                                if (bf_sels[i][3]) RD[0] = bf_bytes[i][3];
                            end
                        end
                        2'b11: begin 
                            if (word_overlap[i] == 2'b01) begin
                                if (bf_sels[i][0]) RD[0] = bf_bytes[i][0];
                                if (bf_sels[i][1]) RD[1] = bf_bytes[i][1];
                                if (bf_sels[i][2]) RD[2] = bf_bytes[i][2];
                                if (bf_sels[i][3]) RD[3] = bf_bytes[i][3];
                            end
                        end
                    endcase
                end
            endcase
        end
    end
    assign hits = lk_thits[size-1];

    // --- Writing logic (synchronous) ---
    logic [31:0] idx, next_idx;
    wire queue_possible = queue & (idx < size);
    wire dequeue_possible = dequeue & (idx > 0);
    always_comb begin
        next_idx = idx;
        if (queue_possible) next_idx = idx + 1;
        if (dequeue_possible) next_idx = idx - 1;
        if (queue_possible && dequeue_possible) next_idx = idx;
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
                address[idx] <= addr_in;
                data[idx] <= data_in;
                enables[idx] <= {1'b1, bm_in};
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