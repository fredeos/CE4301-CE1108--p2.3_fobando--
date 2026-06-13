// Memory hierarchy compact module for 32 bit architecture (data only)
// > L1 Cache: associative cache memory
//  + Replacement policy: FIFO
//  + Write policy: write-through (FIFO write buffer)
// > l2 Cache: associative cache memory
//  + Replacement policy: FIFO
//  + Write policy: write-through (FIFO write buffer)
// > Main memory
module packed_mem #(
    parameter int L1_LATENCY  = 1, // L1 cache latency simulation (CLK cycles)    [default: 1(min)]
    parameter int L2_LATENCY  = 4, // L2 cache latency simulation (CLK cycles)    [default: 4]
    parameter int MEM_LATENCY = 8, // Data memory latency simulation (CLK cycles) [default: 8]
    parameter int L1_SIZE  = 32,   // L1 cache size (in bytes)                    [default: 32 bytes]
    parameter int L2_SIZE  = 64,   // L2 cache size (in bytes)                    [default: 64 bytes]
    parameter int MEM_SIZE = 256,  // Data memory size (in bytes)                 [default: 256 bytes]
    parameter int L1_ASO   = 2,    // L1 associatiavity (number of ways)          [default: 2(min)]
    parameter int L2_ASO   = 4,    // l2 associatiavity (number of ways)          [default: 4]
    parameter int WPL = 2,         // Memory-wide words-per-line                  [default: 2(min)]
    parameter int BUF1_SIZE = 4,   // Write buffer 1 size (number of words)       [default: 4]
    parameter int BUF2_SIZE = 8,   // Write buffer 2 size (number of words)       [default: 4]
    parameter int BUF3_SIZE = 8    // Write buffer 3 size (number of words)       [default: 4]
)(
    // + Global signals
    input  logic CLK,
    input  logic RST,
    // + Memory signals
    input  logic RE,        // read-enable
    input  logic WE,        // write-enable
    input  logic [3:0]  BM, // byte-mode (byte selection)
    input  logic [31:0] A,  // read/write address
    input  logic [31:0] WD, // write data
    output logic [31:0] RD, // read data
    // + Output control signals
    output logic [1:0] ready,      // read ready signal
    output logic halt,             // write halt signal
    output logic [1:0] read_miss,  // [0]: L1, [1]: L2
    output logic [1:0] write_miss  // [0]: L1, [1]: L2
);
    // --- Internal signals ---
    // 1. Control signals
    logic [1:0] L1_hits, L2_hits; // (READ&WRITE HITS) [0]: read, [1]: write
    logic [1:0] locked;           // ($ LOCK STATUS)   [0]: L1,   [1]: L2
    logic [1:0] ignore;           // ($ MISS IGNORE)   [0]: L1,   [1]: L2
    logic [1:0] L1_rdy, L2_rdy;   // (READY STATUS)    [0]: read, [1]: write
    logic [1:0] M_rdy;            // (READY STATUS)    [0]: read, [1]: write

    wire L1_read_hit  = L1_hits[0] & L1_rdy[0]; // true hit
    wire L1_write_hit = L1_hits[1] & L1_rdy[1]; // true hit

    wire L1_read_miss  = ~L1_hits[0] & L1_rdy[0]; // true miss
    wire L1_write_miss = ~L1_hits[1] & L1_rdy[1]; // true miss

    wire L2_read_hit  = L2_hits[0] & L2_rdy[0]; // true hit
    wire L2_write_hit = L2_hits[1] & L2_rdy[1]; // true hit

    wire L2_read_miss  = ~L2_hits[0] & L2_rdy[0]; // true miss
    wire L2_write_miss = ~L2_hits[1] & L2_rdy[1]; // true miss

    wire M_read_hit  = M_rdy[0]; // true hit 
    wire M_write_hit = M_rdy[1]; // true miss

    assign read_miss = {L2_read_miss, L1_read_miss};
    assign write_miss = {L2_write_miss, L1_write_miss};

    // 2. Data signals
    logic [31:0] read_data [0:2];   // (READ DATA) [0]: L1, [1]: L2, [2]: MEM
    logic [3:0][7:0] rd_bytes [0:2];

    generate
        genvar i;
        for (i = 0; i < 3; i++) begin
            assign rd_bytes[i][0] = read_data[i][7:0];
            assign rd_bytes[i][1] = read_data[i][15:8];
            assign rd_bytes[i][2] = read_data[i][23:16];
            assign rd_bytes[i][3] = read_data[i][31:24];
        end
    endgenerate

    // 3. Burst signals
    logic [31:0] burst_addr [0:1];       // [0]: burst1, [1]: burst2
    logic [WPL-1:0][31:0] burst [0:1];   // [0]: burst1, [1]: burst2

    logic [31:0] L2_burst_addr [0:1];    // [0]: burst1, [1]: burst2
    logic [WPL-1:0][31:0] L2_burst [0:1];// [0]: burst1, [1]: burst2

    logic [31:0] M_burst_addr [0:1];     // [0]: burst1, [1]: burst2
    logic [WPL-1:0][31:0] M_burst [0:1]; // [0]: burst1, [1]: burst2

    // 4. Write-through buffer signals
    logic [2:0] queue, dequeue; // [0]: IN, [1]: L1, [2]: L2
    logic [2:0] valid, full;    // [0]: IN, [1]: L1, [2]: L2

    assign dequeue[2] = M_rdy[1];

    logic [3:0]  IN_bm_L1   [0:1]; // (L1-L2 byte mode) [0]: input, [1]: output
    logic [31:0] IN_addr_L1 [0:1]; // (L1-L2 address)   [0]: input, [1]: output
    logic [31:0] IN_wd_L1   [0:1]; // (L1-L2 write data)[0]: input, [1]: output

    assign IN_bm_L1[0] = BM;
    assign IN_addr_L1[0] = A;
    assign IN_wd_L1[0] = WD;

    logic [3:0]  L1_bm_L2   [0:1]; // (L1-L2 byte mode) [0]: input, [1]: output
    logic [31:0] L1_addr_L2 [0:1]; // (L1-L2 address)   [0]: input, [1]: output
    logic [31:0] L1_wd_L2   [0:1]; // (L1-L2 write data)[0]: input, [1]: output

    logic [3:0]  L2_bm_M   [0:1]; // (L2-M byte mode) [0]: input, [1]: output
    logic [31:0] L2_addr_M [0:1]; // (L2-M address)   [0]: input, [1]: output
    logic [31:0] L2_wd_M   [0:1]; // (L2-M write data)[0]: input, [1]: output

    logic [3:0][7:0] IN_rd_L1;
    logic [3:0] IN_hits_L1;

    wire IN_hit1_L1 = IN_hits_L1[0];
    wire IN_hit2_L1 = IN_hits_L1[1];
    wire IN_hit3_L1 = IN_hits_L1[2];
    wire IN_hit4_L1 = IN_hits_L1[3];

    logic [3:0][7:0] L1_rd_L2;
    logic [3:0] L1_hits_L2;

    wire L1_hit1_L2 = L1_hits_L2[0];
    wire L1_hit2_L2 = L1_hits_L2[1];
    wire L1_hit3_L2 = L1_hits_L2[2];
    wire L1_hit4_L2 = L1_hits_L2[3];

    logic [3:0][7:0] L2_rd_M;
    logic [3:0] L2_hits_M;

    wire L2_hit1_M = L2_hits_M[0];
    wire L2_hit2_M = L2_hits_M[1];
    wire L2_hit3_M = L2_hits_M[2];
    wire L2_hit4_M = L2_hits_M[3];

    // --- Memory reading FSM ---
    // NOTE #1: This finite state machine allows controlling the memory for initiating data reading
    // and filling missing lines (miss penalty)

    // 1. FSM state update logic
    logic [3:0] rd_state, rd_next_state;
    always_ff @(posedge CLK, posedge RST) begin 
        if (RST) begin
            rd_state <= 4'b0000;
        end else begin
            rd_state <= rd_next_state;
        end
    end

    // 2. FSM combinational logic
    assign ready[0] = (rd_state == 4'b1001);
    always_comb begin
        rd_next_state = rd_state;
        ignore = 2'b00;
        case (rd_state)
            4'b0000: begin // IDLE
                if (RE) rd_next_state = 4'b0001; // go to L1
            end

            4'b0001: begin // REQUEST L1
                if (L1_read_hit) rd_next_state = 4'b0010; // retrieve results from L1
                if (L1_read_miss)rd_next_state = 4'b0011; // go to L2
            end

            4'b0010: begin // ASSERT L1
                rd_next_state = 4'b1001; // DONE
            end

            4'b0011: begin // REQUEST L2
                if (L2_read_hit) rd_next_state = 4'b0100; // retrieve results from L2
                if (L2_read_miss)rd_next_state = 4'b0101; // go to MEM
            end

            4'b0100: begin // ASSERT L2
                if (|L1_hits_L2) begin 
                    ignore = 2'b01; // ignore missing lines on L1
                    rd_next_state = 4'b1001;  // DONE
                end
                else rd_next_state = 4'b0111; // fill missing lines on L1
            end

            4'b0101: begin // REQUEST MEM
                if (M_read_hit) rd_next_state = 4'b0110; // retrieve results from MEM
            end

            4'b0110: begin // ASSERT MEM
                if (|L2_hits_M) begin
                    ignore = 2'b11; // ignore missing lines on L1 and L2
                    rd_next_state = 4'b1001;  // DONE
                end
                else rd_next_state = 4'b1000; // fill missing lines on L1 and L2
            end

            4'b0111: begin // FILL L1
                rd_next_state = 4'b1001; // DONE
            end

            4'b1000: begin // FILL L2
                rd_next_state = 4'b0111; // fill missing lines on L1
            end

            4'b1001: begin // DONE
                rd_next_state = 4'b0000; // go back to idle
            end
        endcase
    end

    // + Set read enable bits
    wire L1_RE = (rd_state == 4'b0001);
    wire L2_RE = (rd_state == 4'b0011);
    wire M_RE  = (rd_state == 4'b0101);

    // + Set burst valid bits
    wire L1_fml = (rd_state == 4'b0111); // fill missing lines for L1
    wire L2_fml = (rd_state == 4'b1000); // fill missing lines for L2

    // 3. FSM output logic
    always_ff @(posedge CLK, posedge RST) begin
        if (RST) begin
            RD <= '0;
            burst_addr[0] <= '0;
            burst_addr[1] <= '0;
            for (int i = 0; i < WPL; i++) begin 
                burst[0][i] <= '0;
                burst[1][i] <= '0;
            end
        end else begin
            case (rd_state)
                4'b0010: begin // ASSERT L1: save register results
                    //RD <= read_data[0];
                    RD[7:0]   <= (IN_hit1_L1) ? IN_rd_L1[0] : rd_bytes[0][0];
                    RD[15:8]  <= (IN_hit2_L1) ? IN_rd_L1[1] : rd_bytes[0][1];
                    RD[23:16] <= (IN_hit3_L1) ? IN_rd_L1[2] : rd_bytes[0][2];
                    RD[31:24] <= (IN_hit4_L1) ? IN_rd_L1[3] : rd_bytes[0][3];
                end

                4'b0100: begin // ASSERT L2: save register results
                    //RD <= read_data[1];
                    RD[7:0]   <= (L1_hit1_L2) ? L1_rd_L2[0] : rd_bytes[1][0];
                    RD[15:8]  <= (L1_hit2_L2) ? L1_rd_L2[1] : rd_bytes[1][1];
                    RD[23:16] <= (L1_hit3_L2) ? L1_rd_L2[2] : rd_bytes[1][2];
                    RD[31:24] <= (L1_hit4_L2) ? L1_rd_L2[3] : rd_bytes[1][3];
                    burst_addr[0] <= L2_burst_addr[0];
                    burst_addr[1] <= L2_burst_addr[1];
                    for (int i = 0; i < WPL; i++) begin 
                        burst[0][i] <= L2_burst[0][i];
                        burst[1][i] <= L2_burst[1][i];
                    end
                end

                4'b0110: begin // ASSERT MEM: save register results
                    //RD <= read_data[2];
                    RD[7:0]   <= (L2_hit1_M) ? L2_rd_M[0] : rd_bytes[2][0];
                    RD[15:8]  <= (L2_hit2_M) ? L2_rd_M[1] : rd_bytes[2][1];
                    RD[23:16] <= (L2_hit3_M) ? L2_rd_M[2] : rd_bytes[2][2];
                    RD[31:24] <= (L2_hit4_M) ? L2_rd_M[3] : rd_bytes[2][3];
                    burst_addr[0] <= M_burst_addr[0];
                    burst_addr[1] <= M_burst_addr[1];
                    for (int i = 0; i < WPL; i++) begin 
                        burst[0][i] <= M_burst[0][i];
                        burst[1][i] <= M_burst[1][i];
                    end
                end
            endcase
        end
    end

    // --- Memory writing FSM ---
    // + The objective of this FSM is to control the 'halt' signal to garantee that data is able to written
    // to the write buffers
    // NOTE #2: Writing on memory is controlled by the write buffers which handle propagating data
    // to higher memory levels

    // 1. FSM state update logic
    logic [1:0] wd_state, wd_next_state;
    logic [1:0] wd_prev_state;

    always_ff @(posedge CLK, posedge RST) begin 
        if (RST) begin
            wd_state <= 2'b00;
        end else begin 
            wd_state <= wd_next_state;
        end
    end

    // 2. FSM combinational logic
    wire write_path_full = full[0] | full[1] | full[2];
    assign halt = write_path_full & (wd_state == 2'b01);
    assign ready[1] = (wd_state == 2'b11);
    always_comb begin
        wd_next_state = wd_state;
        case (wd_state)
            2'b00: begin // IDLE
                if (WE) wd_next_state = 2'b01; // check if buffers are ready
            end
            
            2'b01: begin // WAIT
                if (!write_path_full) wd_next_state = 2'b10; // ready to write
            end

            2'b10: begin // WRITE
                wd_next_state = 2'b11; // done
            end

            2'b11: begin // DONE
                wd_next_state = 2'b00; // go back to idle
            end
        endcase
    end

    // 3. Queue data on first buffer
    assign queue[0] = (wd_state == 2'b10);

    // --- L1 Cache ---
    // + Write buffer IN-L1
    writebuf #(.size(BUF1_SIZE)) _in_writebuf (
        // + Sequential logic signals
        .CLK(CLK), .RST(RST),
        // + Control signals
        .queue(queue[0]), .dequeue(dequeue[0]),
        // + Input write content
        .addr_in(IN_addr_L1[0]), .data_in(IN_wd_L1[0]), .bm_in(IN_bm_L1[0]),
        // + Lookup signals
        .A(A), .BM(BM), .RD(IN_rd_L1), .hits(IN_hits_L1),
        // + Output write content
        .addr_out(IN_addr_L1[1]), .data_out(IN_wd_L1[1]), .bm_out(IN_bm_L1[1]),
        // + Output control signals
        .valid(valid[0]), .hold(full[0])
    );

    // + Cache module
    cache #(.SIZE(L1_SIZE), .WPL(WPL), .WAYS(L1_ASO), .LATENCY(L1_LATENCY)) _l1_dut (
        // + Sequential logic signals
        .CLK(CLK), .RST(RST), .ignore(ignore[0]),
        // + Write signals
        .WE(valid[0]), .WBM(IN_bm_L1[1]), .WA(IN_addr_L1[1]), .WD(IN_wd_L1[1]),
        // + Read signals
        .RE(L1_RE), .RBM(BM), .RA(A), .RD(read_data[0]),
        // + Control signals
        .hit(L1_hits), .ready(L1_rdy), .locked(locked[0]),
        // + Input  burst signals
        .fill(L1_fml),
        .in_addr_burst1(burst_addr[0]), .in_addr_burst2(burst_addr[1]),
        .in_burst1(burst[0]), .in_burst2(burst[1]),
        // + Output burst signals
        .out_addr_burst1(), .out_addr_burst2(),
        .out_burst1(), .out_burst2(),
        // + Write-through signals
        .queue(queue[1]), .dequeue(dequeue[0]),
        .pWBM(L1_bm_L2[0]), .pWA(L1_addr_L2[0]), .pWD(L1_wd_L2[0])
    );

    // + Write buffer L1-L2
    writebuf #(.size(BUF2_SIZE)) _l1_writebuf (
        // + Sequential logic signals
        .CLK(CLK), .RST(RST),
        // + Control signals
        .queue(queue[1]), .dequeue(dequeue[1]),
        // + Input write content
        .addr_in(L1_addr_L2[0]), .data_in(L1_wd_L2[0]), .bm_in(L1_bm_L2[0]),
        // + Lookup signals
        .A(A), .BM(BM), .RD(L1_rd_L2), .hits(L1_hits_L2),
        // + Output write content
        .addr_out(L1_addr_L2[1]), .data_out(L1_wd_L2[1]), .bm_out(L1_bm_L2[1]),
        // + Output control signals
        .valid(valid[1]), .hold(full[1])
    );

    // --- L2 Cache ---
    // + Cache module
    cache #(.SIZE(L2_SIZE), .WPL(WPL), .WAYS(L2_ASO), .LATENCY(L2_LATENCY)) _l2_dut (
        // + Sequential logic signals
        .CLK(CLK), .RST(RST), .ignore(ignore[1]),
        // + Write signals
        .WE(valid[1]), .WBM(L1_bm_L2[1]), .WA(L1_addr_L2[1]), .WD(L1_wd_L2[1]),
        // + Read signals
        .RE(L2_RE), .RBM(BM), .RA(A), .RD(read_data[1]),
        // + Control signals
        .hit(L2_hits), .ready(L2_rdy), .locked(locked[1]),
        // + Input  burst signals
        .fill(L2_fml),
        .in_addr_burst1(burst_addr[0]), .in_addr_burst2(burst_addr[1]),
        .in_burst1(burst[0]), .in_burst2(burst[1]),
        // + Output burst signals
        .out_addr_burst1(L2_burst_addr[0]), .out_addr_burst2(L2_burst_addr[1]),
        .out_burst1(L2_burst[0]), .out_burst2(L2_burst[1]),
        // + Write-through signals
        .queue(queue[2]), .dequeue(dequeue[1]),
        .pWBM(L2_bm_M[0]), .pWA(L2_addr_M[0]), .pWD(L2_wd_M[0])
    );

    // + Write buffer L2-M
    writebuf #(.size(BUF3_SIZE)) _l2_writebuf (
        // + Sequential logic signals
        .CLK(CLK), .RST(RST),
        // + Control signals
        .queue(queue[2]), .dequeue(dequeue[2]),
        // + Input write content
        .addr_in(L2_addr_M[0]), .data_in(L2_wd_M[0]), .bm_in(L2_bm_M[0]),
        // + Lookup signals
        .A(A), .BM(BM), .RD(L2_rd_M), .hits(L2_hits_M),
        // + Output write content
        .addr_out(L2_addr_M[1]), .data_out(L2_wd_M[1]), .bm_out(L2_bm_M[1]),
        // + Output control signals
        .valid(valid[2]), .hold(full[2])
    );

    // --- Memory ---
    data_memory #(.SIZE(MEM_SIZE), .LATENCY(MEM_LATENCY), .WPL(WPL)) _mem_dut (
        // + Sequential logic signals
        .CLK(CLK), .RST(RST),
        // + Write signals
        .WE(valid[2]), .WBM(L2_bm_M[1]), .WA(L2_addr_M[1]), .WD(L2_wd_M[1]),
        // + Read signals
        .RE(M_RE), .RBM(BM), .RA(A), .RD(read_data[2]),
        // + Control signals
        .ready(M_rdy),
        // + Output burst signals
        .burst1_addr(M_burst_addr[0]), .burst2_addr(M_burst_addr[1]),
        .burst1(M_burst[0]), .burst2(M_burst[1])
    );

endmodule