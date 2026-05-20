module tb_hazard_unit;

    localparam int INSTR_WIDTH = 32;

    localparam logic [1:0] SRC_PIPE = 2'b00;
    localparam logic [1:0] SRC_ALU  = 2'b01;
    localparam logic [1:0] SRC_WB   = 2'b10;

    localparam logic [4:0] OP_R    = 5'b00000;
    localparam logic [4:0] OP_I    = 5'b00001;
    localparam logic [4:0] OP_PR   = 5'b00010;
    localparam logic [4:0] OP_PI   = 5'b00011;
    localparam logic [4:0] OP_M_LD = 5'b00100;
    localparam logic [4:0] OP_M_ST = 5'b00101;
    localparam logic [4:0] OP_V_LD = 5'b00110;
    localparam logic [4:0] OP_V_ST = 5'b00111;
    localparam logic [4:0] OP_B    = 5'b01000;
    localparam logic [4:0] OP_JF   = 5'b01001;
    localparam logic [4:0] OP_T    = 5'b10000;

    localparam logic [3:0] ALU_ADD = 4'b0010;
    localparam logic [3:0] ALU_SUB = 4'b0011;
    localparam logic [3:0] COND_BEQ = 4'b0000;
    localparam logic [3:0] T_SEND  = 4'b0000;
    localparam logic [3:0] T_RECV  = 4'b0001;

    logic [INSTR_WIDTH-1:0] IDInstr;
    logic [INSTR_WIDTH-1:0] EXInstr;
    logic [INSTR_WIDTH-1:0] MEMInstr;
    logic [INSTR_WIDTH-1:0] WBInstr;

    logic branch_taken;
    logic mem_busy;
    logic wb_busy;

    logic StallIF;
    logic FlushIF;
    logic StallID;
    logic FlushID;
    logic FlushEX;
    logic StallMEM;
    logic StallWB;

    logic [1:0] RD1SrcEX;
    logic [1:0] RD2SrcEX;
    logic [1:0] RD3SrcEX;

    int pass_count;

    hazard_unit dut (
        .IDInstr(IDInstr),
        .EXInstr(EXInstr),
        .MEMInstr(MEMInstr),
        .WBInstr(WBInstr),
        .branch_taken(branch_taken),
        .mem_busy(mem_busy),
        .wb_busy(wb_busy),
        .StallIF(StallIF),
        .FlushIF(FlushIF),
        .StallID(StallID),
        .FlushID(FlushID),
        .FlushEX(FlushEX),
        .StallMEM(StallMEM),
        .StallWB(StallWB),
        .RD1SrcEX(RD1SrcEX),
        .RD2SrcEX(RD2SrcEX),
        .RD3SrcEX(RD3SrcEX)
    );

    function automatic logic [31:0] enc_normal(
        input logic [4:0] opcode,
        input logic [3:0] func4,
        input logic [4:0] rd,
        input logic [4:0] rn,
        input logic [4:0] rm
    );
        begin
            enc_normal = '0;
            enc_normal[0]     = 1'b0;
            enc_normal[5:1]   = opcode;
            enc_normal[9:6]   = func4;
            enc_normal[14:10] = rd;
            enc_normal[19:15] = rn;
            enc_normal[24:20] = rm;
        end
    endfunction

    function automatic logic [31:0] enc_secure(
        input logic [4:0] opcode,
        input logic [3:0] func4,
        input logic [2:0] sd,
        input logic [2:0] sn,
        input logic [2:0] sm,
        input logic [2:0] sf
    );
        begin
            enc_secure = '0;
            enc_secure[0]     = 1'b1;
            enc_secure[5:1]   = opcode;
            enc_secure[9:6]   = func4;
            enc_secure[12:10] = sd;
            enc_secure[15:13] = sn;
            enc_secure[18:16] = sm;
            enc_secure[21:19] = sf;
        end
    endfunction

    function automatic logic [31:0] enc_t_send(
        input logic [2:0] sd,
        input logic [4:0] rn
    );
        begin
            enc_t_send = '0;
            enc_t_send[0]     = 1'b1;
            enc_t_send[5:1]   = OP_T;
            enc_t_send[9:6]   = T_SEND;
            enc_t_send[12:10] = sd;
            enc_t_send[19:15] = rn;
        end
    endfunction

    function automatic logic [31:0] enc_t_recv(
        input logic [4:0] rd,
        input logic [2:0] sm
    );
        begin
            enc_t_recv = '0;
            enc_t_recv[0]     = 1'b1;
            enc_t_recv[5:1]   = OP_T;
            enc_t_recv[9:6]   = T_RECV;
            enc_t_recv[14:10] = rd;
            enc_t_recv[18:16] = sm;
        end
    endfunction

    task automatic clear_inputs;
        begin
            IDInstr = '0;
            EXInstr = '0;
            MEMInstr = '0;
            WBInstr = '0;
            branch_taken = 1'b0;
            mem_busy = 1'b0;
            wb_busy = 1'b0;
            #1;
        end
    endtask

    task automatic check_outputs(
        input logic exp_stall_if,
        input logic exp_flush_if,
        input logic exp_stall_id,
        input logic exp_flush_id,
        input logic exp_flush_ex,
        input logic exp_stall_mem,
        input logic exp_stall_wb,
        input logic [1:0] exp_rd1,
        input logic [1:0] exp_rd2,
        input logic [1:0] exp_rd3,
        input string test_name
    );
        begin
            if ((StallIF !== exp_stall_if) ||
                (FlushIF !== exp_flush_if) ||
                (StallID !== exp_stall_id) ||
                (FlushID !== exp_flush_id) ||
                (FlushEX !== exp_flush_ex) ||
                (StallMEM !== exp_stall_mem) ||
                (StallWB !== exp_stall_wb) ||
                (RD1SrcEX !== exp_rd1) ||
                (RD2SrcEX !== exp_rd2) ||
                (RD3SrcEX !== exp_rd3)) begin

                $display("[FAIL] %s", test_name);
                $display("  Got      StallIF=%0b FlushIF=%0b StallID=%0b FlushID=%0b FlushEX=%0b StallMEM=%0b StallWB=%0b RD1=%02b RD2=%02b RD3=%02b",
                         StallIF, FlushIF, StallID, FlushID, FlushEX, StallMEM, StallWB, RD1SrcEX, RD2SrcEX, RD3SrcEX);
                $display("  Expected StallIF=%0b FlushIF=%0b StallID=%0b FlushID=%0b FlushEX=%0b StallMEM=%0b StallWB=%0b RD1=%02b RD2=%02b RD3=%02b",
                         exp_stall_if, exp_flush_if, exp_stall_id, exp_flush_id, exp_flush_ex, exp_stall_mem, exp_stall_wb, exp_rd1, exp_rd2, exp_rd3);
                $fatal(1);
            end else begin
                pass_count++;
                $display("[PASS] %s", test_name);
            end
        end
    endtask

    initial begin
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, tb_hazard_unit);

        pass_count = 0;
        $display("Iniciando pruebas de hazard_unit");

        clear_inputs();
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "sin_hazard");

        clear_inputs();
        EXInstr  = enc_normal(OP_R, ALU_ADD, 5'd9, 5'd3, 5'd4);
        MEMInstr = enc_normal(OP_I, ALU_ADD, 5'd3, 5'd1, 5'd0);
        WBInstr  = enc_normal(OP_I, ALU_ADD, 5'd4, 5'd2, 5'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_ALU, SRC_WB, SRC_PIPE,
                      "forward_normal_mem_rd1_y_wb_rd2");

        clear_inputs();
        EXInstr  = enc_normal(OP_R, ALU_ADD, 5'd9, 5'd8, 5'd3);
        MEMInstr = enc_normal(OP_I, ALU_ADD, 5'd3, 5'd1, 5'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_ALU, SRC_PIPE,
                      "forward_normal_mem_rd2");

        clear_inputs();
        EXInstr  = enc_normal(OP_R, ALU_ADD, 5'd9, 5'd3, 5'd7);
        MEMInstr = enc_normal(OP_I, ALU_ADD, 5'd3, 5'd1, 5'd0);
        WBInstr  = enc_normal(OP_I, ALU_ADD, 5'd3, 5'd2, 5'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_ALU, SRC_PIPE, SRC_PIPE,
                      "prioridad_forward_mem_sobre_wb");

        clear_inputs();
        EXInstr  = enc_normal(OP_R, ALU_ADD, 5'd9, 5'd3, 5'd4);
        MEMInstr = enc_normal(OP_M_ST, '0, 5'd3, 5'd1, 5'd0);
        WBInstr  = enc_normal(OP_M_ST, '0, 5'd4, 5'd2, 5'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "store_no_genera_forward");

        clear_inputs();
        EXInstr  = enc_normal(OP_R, ALU_ADD, 5'd9, 5'd0, 5'd4);
        MEMInstr = enc_normal(OP_I, ALU_ADD, 5'd0, 5'd1, 5'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "zero_no_genera_forward");

        clear_inputs();
        EXInstr  = enc_secure(OP_PR, ALU_ADD, 3'd6, 3'd1, 3'd2, 3'd3);
        MEMInstr = enc_secure(OP_PR, ALU_ADD, 3'd1, 3'd4, 3'd5, 3'd0);
        WBInstr  = enc_secure(OP_PI, ALU_ADD, 3'd2, 3'd7, 3'd0, 3'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_ALU, SRC_WB, SRC_PIPE,
                      "forward_seguro_mem_rd1_y_wb_rd2");

        clear_inputs();
        EXInstr  = enc_secure(OP_PR, ALU_ADD, 3'd6, 3'd1, 3'd2, 3'd3);
        MEMInstr = enc_secure(OP_PR, ALU_ADD, 3'd3, 3'd4, 3'd5, 3'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_ALU,
                      "forward_seguro_mem_rd3");

        clear_inputs();
        EXInstr  = enc_secure(OP_PR, ALU_ADD, 3'd6, 3'd1, 3'd2, 3'd3);
        WBInstr  = enc_secure(OP_PI, ALU_ADD, 3'd3, 3'd0, 3'd0, 3'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_WB,
                      "forward_seguro_wb_rd3");

        clear_inputs();
        EXInstr  = enc_secure(OP_PR, ALU_ADD, 3'd6, 3'd1, 3'd2, 3'd3);
        MEMInstr = enc_secure(OP_PR, ALU_ADD, 3'd1, 3'd0, 3'd0, 3'd0);
        WBInstr  = enc_secure(OP_PI, ALU_ADD, 3'd1, 3'd0, 3'd0, 3'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_ALU, SRC_PIPE, SRC_PIPE,
                      "prioridad_forward_seguro_mem_sobre_wb");

        clear_inputs();
        EXInstr  = enc_secure(OP_PR, ALU_ADD, 3'd6, 3'd1, 3'd2, 3'd3);
        MEMInstr = enc_secure(OP_V_ST, '0, 3'd1, 3'd4, 3'd0, 3'd0);
        WBInstr  = enc_secure(OP_V_ST, '0, 3'd2, 3'd5, 3'd0, 3'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "vault_store_no_genera_forward");

        clear_inputs();
        EXInstr = enc_normal(OP_M_LD, '0, 5'd5, 5'd1, 5'd0);
        IDInstr = enc_normal(OP_R, ALU_ADD, 5'd7, 5'd5, 5'd6);
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "load_use_normal_por_rn");

        clear_inputs();
        EXInstr = enc_normal(OP_M_LD, '0, 5'd5, 5'd1, 5'd0);
        IDInstr = enc_normal(OP_R, ALU_ADD, 5'd7, 5'd6, 5'd5);
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "load_use_normal_por_rm");

        clear_inputs();
        EXInstr = enc_normal(OP_M_LD, '0, 5'd5, 5'd1, 5'd0);
        IDInstr = enc_normal(OP_M_ST, '0, 5'd5, 5'd9, 5'd0);
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "load_use_normal_store_data");

        clear_inputs();
        EXInstr = enc_normal(OP_M_LD, '0, 5'd5, 5'd1, 5'd0);
        IDInstr = enc_normal(OP_I, ALU_ADD, 5'd8, 5'd5, 5'd0);
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "load_use_normal_tipo_i");

        clear_inputs();
        EXInstr = enc_normal(OP_M_LD, '0, 5'd5, 5'd1, 5'd0);
        IDInstr = enc_normal(OP_I, ALU_ADD, 5'd5, 5'd0, 5'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "sin_load_use_si_no_lee_destino");

        clear_inputs();
        EXInstr = enc_normal(OP_M_LD, '0, 5'd0, 5'd1, 5'd0);
        IDInstr = enc_normal(OP_R, ALU_ADD, 5'd7, 5'd0, 5'd6);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "load_use_ignora_registro_zero");

        clear_inputs();
        EXInstr = enc_secure(OP_V_LD, '0, 3'd2, 3'd1, 3'd0, 3'd0);
        IDInstr = enc_secure(OP_PR, ALU_ADD, 3'd5, 3'd2, 3'd3, 3'd0);
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "ldv_use_seguro_por_sn");

        clear_inputs();
        EXInstr = enc_secure(OP_V_LD, '0, 3'd2, 3'd1, 3'd0, 3'd0);
        IDInstr = enc_secure(OP_PR, ALU_ADD, 3'd5, 3'd3, 3'd2, 3'd0);
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "ldv_use_seguro_por_sm");

        clear_inputs();
        EXInstr = enc_secure(OP_V_LD, '0, 3'd2, 3'd1, 3'd0, 3'd0);
        IDInstr = enc_secure(OP_PR, ALU_ADD, 3'd5, 3'd3, 3'd4, 3'd2);
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "ldv_use_seguro_por_sf");

        clear_inputs();
        EXInstr = enc_secure(OP_V_LD, '0, 3'd2, 3'd1, 3'd0, 3'd0);
        IDInstr = enc_t_recv(5'd12, 3'd2);
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "ldv_use_recv");

        clear_inputs();
        EXInstr = enc_secure(OP_V_LD, '0, 3'd2, 3'd1, 3'd0, 3'd0);
        IDInstr = enc_t_send(3'd2, 5'd12);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "send_no_lee_sd");

        clear_inputs();
        EXInstr = enc_normal(OP_M_LD, '0, 5'd5, 5'd1, 5'd0);
        IDInstr = enc_normal(OP_B, COND_BEQ, 5'd0, 5'd5, 5'd3);
        branch_taken = 1'b1;
        #1;
        check_outputs(1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "branch_tiene_prioridad_sobre_load_use");

        clear_inputs();
        branch_taken = 1'b1;
        mem_busy = 1'b1;
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "mem_busy_tiene_prioridad_sobre_flush");

        clear_inputs();
        wb_busy = 1'b1;
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "wb_busy_stall");

        clear_inputs();
        branch_taken = 1'b1;
        wb_busy = 1'b1;
        #1;
        check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1,
                      SRC_PIPE, SRC_PIPE, SRC_PIPE,
                      "wb_busy_tiene_prioridad_sobre_branch");

        clear_inputs();
        EXInstr  = enc_normal(OP_R, ALU_ADD, 5'd8, 5'd1, 5'd0);
        WBInstr  = enc_normal(OP_JF, '0, 5'd1, 5'd0, 5'd0);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_WB, SRC_PIPE, SRC_PIPE,
                      "jal_forward_a_ra");

        clear_inputs();
        EXInstr  = enc_normal(OP_R, ALU_ADD, 5'd8, 5'd12, 5'd0);
        WBInstr  = enc_t_recv(5'd12, 3'd6);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_WB, SRC_PIPE, SRC_PIPE,
                      "recv_forward_a_registro_normal");

        clear_inputs();
        EXInstr  = enc_secure(OP_PR, ALU_ADD, 3'd5, 3'd6, 3'd1, 3'd2);
        MEMInstr = enc_t_send(3'd6, 5'd12);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                      SRC_ALU, SRC_PIPE, SRC_PIPE,
                      "send_forward_a_registro_seguro");

        $display("Todas las pruebas de hazard_unit pasaron: %0d casos", pass_count);
        $finish;
    end

endmodule
