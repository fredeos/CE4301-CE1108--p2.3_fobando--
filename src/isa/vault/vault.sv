module vault #(
    parameter int NUM_WORDS = 16  // 16 palabras por defecto
  )(input  logic        CLK,
    input  logic        RST,
    input  logic [31:0] A,    // 32-bit Address from ALUOut
    input  logic WE,          // Write Enable
    input  logic [3:0]  ASM,  // Addressing Selection Mode
    // Data signals
    input  logic [31:0] WD,   // Write Data from RD2
    output logic [31:0] RD ); // Read Data (MemOut)


    // Calculo de los bits de direccionamiento para indexar el array
    localparam int ADDR_WIDTH = $clog2(NUM_WORDS);

    // --- Memory Storage ---
    // [31:0] is the PACKED dimension: defines the 32-bit width of each word (MSB to LSB).
    // [0:NUM_WORDS-1] is the UNPACKED dimension: defines the addressable range.
    // We use [0:N] instead of [N:0] so that the first line of the .hex file 
    // correctly maps to the lowest address (index 0) during $readmemh.
    logic [31:0] RAM [0:NUM_WORDS-1];

    // --- Address Mapping ---
    // Extract the word index using the calculated width
    // We still ignore A[1:0] for word alignment
    logic [ADDR_WIDTH-1:0] word_idx [0:1];
    assign word_idx[0] = A[ADDR_WIDTH+1:2]; // nearest word
    assign word_idx[1] = word_idx[0] + 1;   // next word

    // Byte offset (useful defining word boundaries)
    logic [1:0] byte_offset;
    assign byte_offset = A[1:0];

    // Byte selection
    wire byte1 = ASM[0];
    wire byte2 = ASM[1];
    wire byte3 = ASM[2];
    wire byte4 = ASM[3];

    // --- Initialization ---
    initial begin
        for (int i = 0; i < NUM_WORDS-1; i++) begin
            RAM[i] = 32'h0;
        end
        $readmemh("./src/vault/vault_mem.hex", RAM);
    end

    // --- Synchronous Write (Store) ---
    always_ff @(posedge CLK, posedge RST) begin
        if (RST) begin
            // reset logic
        end else if (WE) begin
            case (byte_offset)
                2'b00: begin // within boundaries
                    if (byte1) RAM[word_idx[0]][7:0]   <= WD[7:0];
                    if (byte2) RAM[word_idx[0]][15:8]  <= WD[15:8];
                    if (byte3) RAM[word_idx[0]][23:16] <= WD[23:16];
                    if (byte4) RAM[word_idx[0]][31:24] <= WD[31:24]; 
                end

                2'b01: begin // boundaries exceed by 1 byte
                    if (byte1) RAM[word_idx[0]][15:8]   <= WD[7:0];
                    if (byte2) RAM[word_idx[0]][23:16]  <= WD[15:8];
                    if (byte3) RAM[word_idx[0]][31:24]  <= WD[23:16];
                    if (byte4) RAM[word_idx[1]][7:0]    <= WD[31:24];
                end

                2'b10: begin // boundaries exceed by 2 bytes
                    if (byte1) RAM[word_idx[0]][23:16]  <= WD[7:0];
                    if (byte2) RAM[word_idx[0]][31:24]  <= WD[15:8];
                    if (byte3) RAM[word_idx[1]][7:0]    <= WD[23:16];
                    if (byte4) RAM[word_idx[1]][15:8]   <= WD[31:24]; 
                end

                2'b11: begin // boundaries exceed by 3 byte
                    if (byte1) RAM[word_idx[0]][31:24] <= WD[7:0];
                    if (byte2) RAM[word_idx[1]][7:0]   <= WD[15:8];
                    if (byte3) RAM[word_idx[1]][15:8]  <= WD[23:16];
                    if (byte4) RAM[word_idx[1]][23:16] <= WD[31:24]; 
                end
            endcase
        end
    end

    // --- Asynchronous Read (Load) ---
    logic [7:0] rdbytes [7:0];
    assign rdbytes[0] = RAM[word_idx[0]][7:0];
    assign rdbytes[1] = RAM[word_idx[0]][15:8];
    assign rdbytes[2] = RAM[word_idx[0]][23:16];
    assign rdbytes[3] = RAM[word_idx[0]][31:24];
    assign rdbytes[4] = RAM[word_idx[1]][7:0];
    assign rdbytes[5] = RAM[word_idx[1]][15:8];
    assign rdbytes[6] = RAM[word_idx[1]][23:16];
    assign rdbytes[7] = RAM[word_idx[1]][31:24];

    always_comb begin
        RD = 32'b0;
        case (byte_offset)
            2'b00: begin // within boundaries
                if (byte1) RD[7:0]   = rdbytes[0];
                if (byte2) RD[15:8]  = rdbytes[1];
                if (byte3) RD[23:16] = rdbytes[2];
                if (byte4) RD[31:24] = rdbytes[3];
            end

            2'b01: begin // boundaries exceed by 1 byte
                if (byte1) RD[7:0]   = rdbytes[1];
                if (byte2) RD[15:8]  = rdbytes[2];
                if (byte3) RD[23:16] = rdbytes[3];
                if (byte4) RD[31:24] = rdbytes[4];
            end

            2'b10: begin // boundaries exceed by 2 bytes
                if (byte1) RD[7:0]   = rdbytes[2];
                if (byte2) RD[15:8]  = rdbytes[3];
                if (byte3) RD[23:16] = rdbytes[4];
                if (byte4) RD[31:24] = rdbytes[5];
            end

            2'b11: begin // boundaries exceed by 3 byte
                if (byte1) RD[7:0]   = rdbytes[3];
                if (byte2) RD[15:8]  = rdbytes[4];
                if (byte3) RD[23:16] = rdbytes[5];
                if (byte4) RD[31:24] = rdbytes[6];
            end

            default: begin
                RD = 32'b0;
            end
        endcase
    end

endmodule


