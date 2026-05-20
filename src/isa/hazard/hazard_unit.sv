module hazard_unit #(
    parameter int INSTR_WIDTH = 32
)(
    input  logic [INSTR_WIDTH-1:0] IDInstr,
    input  logic [INSTR_WIDTH-1:0] EXInstr,
    input  logic [INSTR_WIDTH-1:0] MEMInstr,
    input  logic [INSTR_WIDTH-1:0] WBInstr,

    input  logic [INSTR_WIDTH-1:0] RD1PipeEX,
    input  logic [INSTR_WIDTH-1:0] RD2PipeEX,
    input  logic [INSTR_WIDTH-1:0] RD3PipeEX,
    input  logic [INSTR_WIDTH-1:0] ALUOut,
    input  logic [INSTR_WIDTH-1:0] DataOutWB,

    input  logic branch_taken,
    input  logic mem_busy,
    input  logic wb_busy,

    output logic StallIF,
    output logic FlushIF,

    output logic StallID,
    output logic FlushID,

    output logic StallEX,
    output logic FlushEX,

    output logic StallMEM,
    output logic FlushMEM,

    output logic StallWB,

    output logic [1:0] RD1SrcEX,
    output logic [1:0] RD2SrcEX,
    output logic [1:0] RD3SrcEX,

    output logic [INSTR_WIDTH-1:0] RD1FwdEX,
    output logic [INSTR_WIDTH-1:0] RD2FwdEX,
    output logic [INSTR_WIDTH-1:0] RD3FwdEX
);

    // Codigos para seleccionar la fuente de forwarding hacia EX.
    localparam logic [1:0] SRC_PIPE = 2'b00;
    localparam logic [1:0] SRC_ALU  = 2'b01;
    localparam logic [1:0] SRC_WB   = 2'b10;

    // Registro cero usado para ignorar dependencias falsas.
    localparam logic [4:0] REG_ZERO  = 5'd0;
    localparam logic [4:0] LR_REG    = 5'd4;
    localparam logic [4:0] DELTA_REG = 5'd30;
    localparam logic [4:0] MAX_REG   = 5'd31;

    localparam logic [2:0] AX_ZERO   = 3'd0;

    // Instrucciones nop invalida
    localparam logic [31:0] nop = 32'h00000080;

    // Opcodes segun la tabla de encodificacion del ISA.md
    localparam logic [4:0] OP_R    = 5'b00000; // add
    localparam logic [4:0] OP_I    = 5'b00001; // addi
    localparam logic [4:0] OP_PR   = 5'b00010; // padd
    localparam logic [4:0] OP_PI   = 5'b00011; // paddi
    localparam logic [4:0] OP_M_LD = 5'b00100; // ldw, ldh, ldb
    localparam logic [4:0] OP_M_ST = 5'b00101; // stw, sth, stb
    localparam logic [4:0] OP_V_LD = 5'b00110; // ldvw, ldvh, ldvb
    localparam logic [4:0] OP_V_ST = 5'b00111; // stvw, stvh, stvb
    localparam logic [4:0] OP_B    = 5'b01000; // beq and branch conditions
    localparam logic [4:0] OP_JF   = 5'b01001; // jal
    localparam logic [4:0] OP_T    = 5'b10000; // send, recv
    localparam logic [4:0] OP_S    = 5'b10001; // login, quit

    // Codigos func4 para operaciones de ALU primaria.
    localparam logic [3:0] ALU_SLL = 4'b0000;
    localparam logic [3:0] ALU_SRL = 4'b0001;
    localparam logic [3:0] ALU_ADD = 4'b0010;
    localparam logic [3:0] ALU_SUB = 4'b0011;
    localparam logic [3:0] ALU_MUL = 4'b0100;
    localparam logic [3:0] ALU_DIV = 4'b0101;
    localparam logic [3:0] ALU_MOD = 4'b0110;
    localparam logic [3:0] ALU_AND = 4'b0111;
    localparam logic [3:0] ALU_OR  = 4'b1000;
    localparam logic [3:0] ALU_XOR = 4'b1001;
    localparam logic [3:0] ALU_SEQ = 4'b1010;

    // Codigos func4 para instrucciones de transferencia.
    localparam logic [3:0] T_SEND  = 4'b0000;
    localparam logic [3:0] T_RECV  = 4'b0001;

    // Indica si cada etapa tiene una instruccion real.
    logic        id_valid;
    logic        ex_valid;
    logic        mem_valid;
    logic        wb_valid;

    // Indicar si cada etapa tiene una instruccion tipo S
    logic       id_session;
    logic       ex_session;
    logic       mem_session;
    logic       wb_session;

    // Bit P extraido del formato de instruccion.
    logic        id_p;
    logic        ex_p;
    logic        mem_p;
    logic        wb_p;

    // Opcode decodificado por etapa.
    logic [4:0]  id_opcode;
    logic [4:0]  ex_opcode;
    logic [4:0]  mem_opcode;
    logic [4:0]  wb_opcode;

    // Campo func4 o condicion de salto decodificado por etapa.
    logic [3:0]  id_func4;
    logic [3:0]  ex_func4;
    logic [3:0]  mem_func4;
    logic [3:0]  wb_func4;

    // Registros normales extraidos del formato R/I/M/B/JF/T.
    logic [4:0]  id_rd;
    logic [4:0]  id_rn;
    logic [4:0]  id_rm;
    logic [4:0]  ex_rd;
    logic [4:0]  ex_rn;
    logic [4:0]  ex_rm;
    logic [4:0]  mem_rd;
    logic [4:0]  mem_rn;
    logic [4:0]  wb_rd;
    logic [4:0]  wb_rn;

    // Registros seguros extraidos del formato V/PR/PI/T.
    logic [2:0]  id_sd;
    logic [2:0]  id_sn;
    logic [2:0]  id_sm;
    logic [2:0]  id_sf;
    logic [2:0]  ex_sd;
    logic [2:0]  ex_sn;
    logic [2:0]  ex_sm;
    logic [2:0]  ex_sf;
    logic [2:0]  mem_sd;
    logic [2:0]  wb_sd;

    // Fuentes normales leidas por la instruccion en ID.
    logic        id_nsrc1_valid;
    logic        id_nsrc2_valid;
    logic [4:0]  id_nsrc1;
    logic [4:0]  id_nsrc2;

    // Fuentes normales leidas por la instruccion en EX.
    logic        ex_nsrc1_valid;
    logic        ex_nsrc2_valid;
    logic [4:0]  ex_nsrc1;
    logic [4:0]  ex_nsrc2;

    // Fuentes seguras leidas por la instruccion en ID.
    logic        id_ssrc1_valid;
    logic        id_ssrc2_valid;
    logic        id_ssrc3_valid;
    logic [2:0]  id_ssrc1;
    logic [2:0]  id_ssrc2;
    logic [2:0]  id_ssrc3;

    // Fuentes seguras leidas por la instruccion en EX.
    logic        ex_ssrc1_valid;
    logic        ex_ssrc2_valid;
    logic        ex_ssrc3_valid;
    logic [2:0]  ex_ssrc1;
    logic [2:0]  ex_ssrc2;
    logic [2:0]  ex_ssrc3;

    // Destinos producidos por instrucciones en MEM y WB.
    logic        mem_writes_normal;
    logic        wb_writes_normal;
    logic        mem_writes_secure;
    logic        wb_writes_secure;
    logic        mem_can_forward_normal;
    logic        mem_can_forward_secure;
    logic [4:0]  mem_normal_dst;
    logic [4:0]  wb_normal_dst;
    logic [2:0]  mem_secure_dst;
    logic [2:0]  wb_secure_dst;
    logic        mem_normal_writeable_dst;
    logic        mem_secure_writeable_dst;
    logic        wb_normal_writeable_dst;
    logic        wb_secure_writeable_dst;

    // Hazards load-use detectados entre ID y EX.
    logic        load_use_hazard;
    logic        secure_load_use_hazard;
    logic        mem_load_wait_hazard;
    logic        mem_secure_load_wait_hazard;
    logic        ex_load_wait_hazard;
    logic        ex_secure_load_wait_hazard;
    logic        ex_store_data_wait_hazard;
    logic        ex_secure_store_data_wait_hazard;

    // Una instruccion cero se trata como NOP.
    assign id_valid  = (IDInstr  != nop);
    assign ex_valid  = (EXInstr  != nop);
    assign mem_valid = (MEMInstr != nop);
    assign wb_valid  = (WBInstr  != nop);

    // El bit P ocupa el bit menos significativo.
    assign id_p       = IDInstr[0];
    assign ex_p       = EXInstr[0];
    assign mem_p      = MEMInstr[0];
    assign wb_p       = WBInstr[0];

    // El opcode ocupa los bits [5:1].
    assign id_opcode  = IDInstr[5:1];
    assign ex_opcode  = EXInstr[5:1];
    assign mem_opcode = MEMInstr[5:1];
    assign wb_opcode  = WBInstr[5:1];

    // Una instruccion se trata como LOGIN o QUIT.
    assign id_session  = (id_opcode  == OP_S);
    assign ex_session  = (ex_opcode  == OP_S);
    assign mem_session = (mem_opcode == OP_S);
    assign wb_session  = (wb_opcode  == OP_S);

    // func4 y cond comparten los bits [9:6].
    assign id_func4   = IDInstr[9:6];
    assign ex_func4   = EXInstr[9:6];
    assign mem_func4  = MEMInstr[9:6];
    assign wb_func4   = WBInstr[9:6];

    // Campos de registros normales segun el formato de encodificacion.
    assign id_rd      = IDInstr[14:10];
    assign id_rn      = IDInstr[19:15];
    assign id_rm      = IDInstr[24:20];
    assign ex_rd      = EXInstr[14:10];
    assign ex_rn      = EXInstr[19:15];
    assign ex_rm      = EXInstr[24:20];
    assign mem_rd     = MEMInstr[14:10];
    assign mem_rn     = MEMInstr[19:15];
    assign wb_rd      = WBInstr[14:10];
    assign wb_rn      = WBInstr[19:15];

    // Campos de registros seguros segun el formato de encodificacion.
    assign id_sd      = IDInstr[12:10];
    assign id_sn      = IDInstr[15:13];
    assign id_sm      = IDInstr[18:16];
    assign id_sf      = IDInstr[21:19];
    assign ex_sd      = EXInstr[12:10];
    assign ex_sn      = EXInstr[15:13];
    assign ex_sm      = EXInstr[18:16];
    assign ex_sf      = EXInstr[21:19];
    assign mem_sd     = MEMInstr[12:10];
    assign wb_sd      = WBInstr[12:10];

    function automatic logic writes_normal_reg(
        input logic       valid,
        input logic [4:0] opcode,
        input logic [3:0] func4
    );
        begin
            // Determina si la instruccion escribe un registro normal.
            case (opcode)
                OP_R,
                OP_I,
                OP_M_LD: writes_normal_reg = valid;
                OP_JF:   writes_normal_reg = valid;
                OP_T:    writes_normal_reg = valid && (func4 == T_RECV);
                default: writes_normal_reg = 1'b0;
            endcase
        end
    endfunction

    function automatic logic [4:0] normal_dst_reg(
        input logic [4:0] opcode,
        input logic [4:0] rd
    );
        begin
            // Obtiene el registro normal destino de la instruccion.
            case (opcode)
                OP_R,
                OP_I,
                OP_M_LD: normal_dst_reg = rd;
                OP_JF:   normal_dst_reg = rd;
                OP_T:    normal_dst_reg = rd;
                default: normal_dst_reg = REG_ZERO;
            endcase
        end
    endfunction

    function automatic logic writes_secure_reg(
        input logic       valid,
        input logic [4:0] opcode,
        input logic [3:0] func4
    );
        begin
            // Determina si la instruccion escribe un registro seguro.
            case (opcode)
                OP_PR,
                OP_PI,
                OP_V_LD: writes_secure_reg = valid;
                OP_T:    writes_secure_reg = valid && (func4 == T_SEND);
                default: writes_secure_reg = 1'b0;
            endcase
        end
    endfunction

    function automatic logic [2:0] secure_dst_reg(
        input logic [4:0] opcode,
        input logic [2:0] sd
    );
        begin
            // Obtiene el registro seguro destino de la instruccion.
            case (opcode)
                OP_PR,
                OP_PI,
                OP_V_LD,
                OP_T:    secure_dst_reg = sd;
                default: secure_dst_reg = 3'd0;
            endcase
        end
    endfunction

    function automatic logic is_load_normal(
        input logic       valid,
        input logic [4:0] opcode
    );
        begin
            // Las cargas normales producen el dato despues de EX.
            is_load_normal = valid && (opcode == OP_M_LD);
        end
    endfunction

    function automatic logic is_load_secure(
        input logic       valid,
        input logic [4:0] opcode
    );
        begin
            // Las cargas seguras producen el dato despues de EX.
            is_load_secure = valid && (opcode == OP_V_LD);
        end
    endfunction

    function automatic logic has_normal_writeable_dst (
        input logic [4:0] dest
    );
        begin 
            case (dest)
                REG_ZERO,
                LR_REG,
                DELTA_REG,
                MAX_REG: has_normal_writeable_dst = 1'b0;
                default: has_normal_writeable_dst = 1'b1;
            endcase
        end
    endfunction

    function automatic logic has_secure_writeable_dst (
        input logic [2:0] dest
    );
        begin 
            case (dest)
                AX_ZERO: has_secure_writeable_dst = 1'b0;
                default: has_secure_writeable_dst = 1'b1;
            endcase
        end
    endfunction

    always_comb begin
        // Decodifica las fuentes que lee la instruccion en ID.
        id_nsrc1_valid = 1'b0;
        id_nsrc2_valid = 1'b0;
        id_nsrc1 = REG_ZERO;
        id_nsrc2 = REG_ZERO;

        id_ssrc1_valid = 1'b0;
        id_ssrc2_valid = 1'b0;
        id_ssrc3_valid = 1'b0;
        id_ssrc1 = 3'd0;
        id_ssrc2 = 3'd0;
        id_ssrc3 = 3'd0;

        if (id_valid) begin
            case (id_opcode)
                OP_R: begin
                    id_nsrc1_valid = 1'b1;
                    id_nsrc2_valid = 1'b1;
                    id_nsrc1 = id_rn;
                    id_nsrc2 = id_rm;
                end
                OP_I: begin
                    id_nsrc1_valid = 1'b1;
                    id_nsrc1 = id_rn;
                end
                OP_M_LD: begin
                    id_nsrc1_valid = 1'b1;
                    id_nsrc1 = id_rn;
                end
                OP_M_ST: begin
                    id_nsrc1_valid = 1'b1;
                    id_nsrc2_valid = 1'b1;
                    id_nsrc1 = id_rn;
                    id_nsrc2 = id_rd;
                end
                OP_B: begin
                    id_nsrc1_valid = 1'b1;
                    id_nsrc2_valid = 1'b1;
                    id_nsrc1 = id_rn;
                    id_nsrc2 = id_rm;
                end
                OP_PR: begin
                    // PR usa tres operandos seguros, incluido el de la ALU secundaria.
                    id_ssrc1_valid = 1'b1;
                    id_ssrc2_valid = 1'b1;
                    id_ssrc3_valid = 1'b1;
                    id_ssrc1 = id_sn;
                    id_ssrc2 = id_sm;
                    id_ssrc3 = id_sf;
                end
                OP_PI: begin
                    id_ssrc1_valid = 1'b1;
                    id_ssrc1 = id_sn;
                end
                OP_V_LD: begin
                    id_ssrc1_valid = 1'b1;
                    id_ssrc1 = id_sn;
                end
                OP_V_ST: begin
                    id_ssrc1_valid = 1'b1;
                    id_ssrc2_valid = 1'b1;
                    id_ssrc1 = id_sn;
                    id_ssrc2 = id_sd;
                end
                OP_T: begin
                    case (id_func4)
                        T_SEND: begin
                            id_nsrc1_valid = 1'b1;
                            id_nsrc1 = id_rn;
                        end
                        T_RECV: begin
                            id_ssrc2_valid = 1'b1;
                            id_ssrc2 = id_sm;
                        end
                        default: begin
                        end
                    endcase
                end
                default: begin
                end
            endcase
        end
    end

    always_comb begin
        // Decodifica las fuentes que lee la instruccion en EX.
        ex_nsrc1_valid = 1'b0;
        ex_nsrc2_valid = 1'b0;
        ex_nsrc1 = REG_ZERO;
        ex_nsrc2 = REG_ZERO;

        ex_ssrc1_valid = 1'b0;
        ex_ssrc2_valid = 1'b0;
        ex_ssrc3_valid = 1'b0;
        ex_ssrc1 = 3'd0;
        ex_ssrc2 = 3'd0;
        ex_ssrc3 = 3'd0;

        if (ex_valid) begin
            case (ex_opcode)
                OP_R: begin
                    ex_nsrc1_valid = 1'b1;
                    ex_nsrc2_valid = 1'b1;
                    ex_nsrc1 = ex_rn;
                    ex_nsrc2 = ex_rm;
                end
                OP_I: begin
                    ex_nsrc1_valid = 1'b1;
                    ex_nsrc1 = ex_rn;
                end
                OP_M_LD: begin
                    ex_nsrc1_valid = 1'b1;
                    ex_nsrc1 = ex_rn;
                end
                OP_M_ST: begin
                    ex_nsrc1_valid = 1'b1;
                    ex_nsrc2_valid = 1'b1;
                    ex_nsrc1 = ex_rn;
                    ex_nsrc2 = ex_rd;
                end
                OP_B: begin
                    ex_nsrc1_valid = 1'b1;
                    ex_nsrc2_valid = 1'b1;
                    ex_nsrc1 = ex_rn;
                    ex_nsrc2 = ex_rm;
                end
                OP_PR: begin
                    // RD3SrcEX cubre el tercer operando seguro de PR.
                    ex_ssrc1_valid = 1'b1;
                    ex_ssrc2_valid = 1'b1;
                    ex_ssrc3_valid = 1'b1;
                    ex_ssrc1 = ex_sn;
                    ex_ssrc2 = ex_sm;
                    ex_ssrc3 = ex_sf;
                end
                OP_PI: begin
                    ex_ssrc1_valid = 1'b1;
                    ex_ssrc1 = ex_sn;
                end
                OP_V_LD: begin
                    ex_ssrc1_valid = 1'b1;
                    ex_ssrc1 = ex_sn;
                end
                OP_V_ST: begin
                    ex_ssrc1_valid = 1'b1;
                    ex_ssrc2_valid = 1'b1;
                    ex_ssrc1 = ex_sn;
                    ex_ssrc2 = ex_sd;
                end
                OP_T: begin
                    case (ex_func4)
                        T_SEND: begin
                            ex_nsrc1_valid = 1'b1;
                            ex_nsrc1 = ex_rn;
                        end
                        T_RECV: begin
                            ex_ssrc2_valid = 1'b1;
                            ex_ssrc2 = ex_sm;
                        end
                        default: begin
                        end
                    endcase
                end
                default: begin
                end
            endcase
        end
    end

    // Calcula destinos disponibles para forwarding desde MEM y WB.
    assign mem_writes_normal = writes_normal_reg(mem_valid, mem_opcode, mem_func4);
    assign wb_writes_normal  = writes_normal_reg(wb_valid, wb_opcode, wb_func4);
    assign mem_writes_secure = writes_secure_reg(mem_valid, mem_opcode, mem_func4);
    assign wb_writes_secure  = writes_secure_reg(wb_valid, wb_opcode, wb_func4);
    assign mem_can_forward_normal = mem_writes_normal && !is_load_normal(mem_valid, mem_opcode);
    assign mem_can_forward_secure = mem_writes_secure && !is_load_secure(mem_valid, mem_opcode);

    assign mem_normal_dst = normal_dst_reg(mem_opcode, mem_rd);
    assign wb_normal_dst  = normal_dst_reg(wb_opcode, wb_rd);
    assign mem_secure_dst = secure_dst_reg(mem_opcode, mem_sd);
    assign wb_secure_dst  = secure_dst_reg(wb_opcode, wb_sd);

    assign mem_normal_writeable_dst = has_normal_writeable_dst(mem_normal_dst);
    assign mem_secure_writeable_dst = has_secure_writeable_dst(mem_secure_dst);
    assign wb_normal_writeable_dst = has_normal_writeable_dst(wb_normal_dst);
    assign wb_secure_writeable_dst = has_secure_writeable_dst(wb_secure_dst);

    // Detecta load-use cuando ID necesita el destino normal que aun esta en EX.
    assign load_use_hazard =
        is_load_normal(ex_valid, ex_opcode) &&
        (
            (id_nsrc1_valid && (id_nsrc1 == ex_rd) && (ex_rd != REG_ZERO)) ||
            (id_nsrc2_valid && (id_nsrc2 == ex_rd) && (ex_rd != REG_ZERO))
        );

    // Detecta load-use seguro cuando ID necesita el destino seguro que aun esta en EX.
    assign secure_load_use_hazard =
        is_load_secure(ex_valid, ex_opcode) &&
        (
            (id_ssrc1_valid && (id_ssrc1 == ex_sd)) ||
            (id_ssrc2_valid && (id_ssrc2 == ex_sd)) ||
            (id_ssrc3_valid && (id_ssrc3 == ex_sd))
        );

    // Como el forwarding desde MEM usa ALUOut, una carga en MEM aun no puede
    // abastecer el dato leido. El consumidor debe esperar hasta WB.
    assign mem_load_wait_hazard =
        is_load_normal(mem_valid, mem_opcode) &&
        (
            (id_nsrc1_valid && (id_nsrc1 == mem_rd) && (mem_rd != REG_ZERO)) ||
            (id_nsrc2_valid && (id_nsrc2 == mem_rd) && (mem_rd != REG_ZERO))
        );

    assign mem_secure_load_wait_hazard =
        is_load_secure(mem_valid, mem_opcode) &&
        (
            (id_ssrc1_valid && (id_ssrc1 == mem_sd)) ||
            (id_ssrc2_valid && (id_ssrc2 == mem_sd)) ||
            (id_ssrc3_valid && (id_ssrc3 == mem_sd))
        );

    // Si el consumidor ya entro a EX y el productor es un load en MEM, el
    // operando correcto aun no existe hasta WB. Hay que congelar EX.
    assign ex_load_wait_hazard =
        is_load_normal(mem_valid, mem_opcode) &&
        (
            (ex_nsrc1_valid && (ex_nsrc1 == mem_rd) && (mem_rd != REG_ZERO)) ||
            (ex_nsrc2_valid && (ex_nsrc2 == mem_rd) && (mem_rd != REG_ZERO))
        );

    assign ex_secure_load_wait_hazard =
        is_load_secure(mem_valid, mem_opcode) &&
        (
            (ex_ssrc1_valid && (ex_ssrc1 == mem_sd)) ||
            (ex_ssrc2_valid && (ex_ssrc2 == mem_sd)) ||
            (ex_ssrc3_valid && (ex_ssrc3 == mem_sd))
        );

    // El dato de un store se consume mas tarde, cuando la instruccion ya esta
    // saliendo de EX hacia MEM. Si depende del productor inmediato en MEM,
    // se congela EX para esperar a que el valor llegue a WB.
    assign ex_store_data_wait_hazard =
        mem_writes_normal &&
        (mem_normal_dst != REG_ZERO) &&
        (ex_opcode == OP_M_ST) &&
        (mem_normal_dst == ex_rd);

    assign ex_secure_store_data_wait_hazard =
        mem_writes_secure &&
        (ex_opcode == OP_V_ST) &&
        (mem_secure_dst == ex_sd);

    always_comb begin
        // Valores por defecto: el pipeline avanza sin forwarding ni flush.
        StallIF  = 1'b0;
        FlushIF  = 1'b0;
        StallID  = 1'b0;
        FlushID  = 1'b0;
        StallEX  = 1'b0;
        FlushEX  = 1'b0;
        StallMEM = 1'b0;
        FlushMEM = 1'b0;
        StallWB  = 1'b0;

        RD1SrcEX = SRC_PIPE;
        RD2SrcEX = SRC_PIPE;
        RD3SrcEX = SRC_PIPE;

        // MEM tiene prioridad sobre WB para forwarding normal, pero solo
        // cuando ALUOut ya representa el dato final adelantable.
        if (mem_can_forward_normal && mem_normal_writeable_dst) begin
            if (ex_nsrc1_valid && (mem_normal_dst == ex_nsrc1)) begin
                RD1SrcEX = SRC_ALU;
            end
            if (ex_nsrc2_valid && (mem_normal_dst == ex_nsrc2)) begin
                RD2SrcEX = SRC_ALU;
            end
        end

        // WB se usa solo si MEM no cubrio la dependencia normal.
        if (wb_writes_normal && wb_normal_writeable_dst) begin
            if (ex_nsrc1_valid && (wb_normal_dst == ex_nsrc1) && (RD1SrcEX == SRC_PIPE)) begin
                RD1SrcEX = SRC_WB;
            end
            if (ex_nsrc2_valid && (wb_normal_dst == ex_nsrc2) && (RD2SrcEX == SRC_PIPE)) begin
                RD2SrcEX = SRC_WB;
            end
        end

        // MEM tiene prioridad sobre WB para forwarding seguro bajo la misma
        // regla: ALUOut debe contener el valor final y no una direccion.
        if (mem_can_forward_secure && mem_secure_writeable_dst) begin
            if (ex_ssrc1_valid && (mem_secure_dst == ex_ssrc1)) begin
                RD1SrcEX = SRC_ALU;
            end
            if (ex_ssrc2_valid && (mem_secure_dst == ex_ssrc2)) begin
                RD2SrcEX = SRC_ALU;
            end
            if (ex_ssrc3_valid && (mem_secure_dst == ex_ssrc3)) begin
                RD3SrcEX = SRC_ALU;
            end
        end

        // WB se usa solo si MEM no cubrio la dependencia segura.
        if (wb_writes_secure && wb_secure_writeable_dst) begin
            if (ex_ssrc1_valid && (wb_secure_dst == ex_ssrc1) && (RD1SrcEX == SRC_PIPE)) begin
                RD1SrcEX = SRC_WB;
            end
            if (ex_ssrc2_valid && (wb_secure_dst == ex_ssrc2) && (RD2SrcEX == SRC_PIPE)) begin
                RD2SrcEX = SRC_WB;
            end
            if (ex_ssrc3_valid && (wb_secure_dst == ex_ssrc3) && (RD3SrcEX == SRC_PIPE)) begin
                RD3SrcEX = SRC_WB;
            end
        end

        // Los selectores anteriores controlan desde que bus se rescata el dato.
        // SRC_ALU toma ALUOut desde MEM; SRC_WB toma DataOutWB desde WB.
        case (RD1SrcEX)
            SRC_ALU:  RD1FwdEX = ALUOut;
            SRC_WB:   RD1FwdEX = DataOutWB;
            default:  RD1FwdEX = RD1PipeEX;
        endcase

        case (RD2SrcEX)
            SRC_ALU:  RD2FwdEX = ALUOut;
            SRC_WB:   RD2FwdEX = DataOutWB;
            default:  RD2FwdEX = RD2PipeEX;
        endcase

        case (RD3SrcEX)
            SRC_ALU:  RD3FwdEX = ALUOut;
            SRC_WB:   RD3FwdEX = DataOutWB;
            default:  RD3FwdEX = RD3PipeEX;
        endcase

        // Prioridad de control: stalls estructurales, branch, sesiones de admin, load-use.
        if (mem_busy) begin
            StallIF  = 1'b1;
            StallID  = 1'b1;
            StallEX  = 1'b1;
            StallMEM = 1'b1;
        end else if (wb_busy) begin
            StallIF  = 1'b1;
            StallID  = 1'b1;
            StallEX  = 1'b1;
            StallMEM = 1'b1;
            StallWB  = 1'b1;
        end else if (branch_taken) begin
            // Si el branch se confirma en MEM, tambien hay una instruccion
            // especulativa ocupando EX que debe invalidarse.
            FlushIF = 1'b0;
            FlushID = 1'b1;
            FlushEX = 1'b1;
            FlushMEM = 1'b1;
        end else if (id_session) begin
            // Si hay una instruccion S en el pipeline se debe detener el ingreso de
            // de nuevas instrucciones hasta que se determine si fue exitoso o no
            StallIF = 1'b1;
            FlushID = 1'b1;
        end else if (ex_session) begin
            // Si hay una instruccion S en el pipeline se debe detener el ingreso de
            // de nuevas instrucciones hasta que se determine si fue exitoso o no
            StallIF = 1'b1;
            StallID = 1'b1;
            FlushEX = 1'b1;
        end else if (mem_session) begin
            // Si hay una instruccion S en el pipeline se debe detener el ingreso de
            // de nuevas instrucciones hasta que se determine si fue exitoso o no
            StallIF = 1'b1;
            StallID = 1'b1;
            StallEX = 1'b1;
            FlushMEM = 1'b1;
        end else if (load_use_hazard || secure_load_use_hazard) begin
            StallIF = 1'b1;
            StallID = 1'b1;
            FlushEX = 1'b1;
        end else if (ex_store_data_wait_hazard || ex_secure_store_data_wait_hazard) begin
            StallIF = 1'b1;
            StallID = 1'b1;
            StallEX = 1'b1;
        end else if (ex_load_wait_hazard || ex_secure_load_wait_hazard) begin
            StallIF = 1'b1;
            StallID = 1'b1;
            StallEX = 1'b1;
        end else if (mem_load_wait_hazard || mem_secure_load_wait_hazard) begin
            // La instruccion consumidora se mantiene en ID hasta que el load
            // llegue a WB, donde ya existe un bus de forwarding valido.
            //StallIF = 1'b1;
            //StallID = 1'b1;
        end
    end

endmodule