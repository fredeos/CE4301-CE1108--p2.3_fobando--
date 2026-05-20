module datapath ( // Pipeline de 5 etapas para arquitectura RISC: F32IS
    input logic clk, rst
);
    localparam MEM_SIZE_KB = 64;
    // ########################################################################################################
    // --- Valores default del procesador ---
    localparam logic [31:0] nop = 32'h00000080; // Valor por defecto para omitir instrucciones
    localparam logic [31:0] password = 32'h000A9C1F; // Contraseña para accesos al hardware seguro
    localparam logic [31:0] lifetime = 32'd10000; // tiempo de vida (en ciclos) de session segura para operaciones criptograficas
    localparam logic [31:0] timeout = 32'd10000; // tiempo de espera (en ciclos) al exceder la cantidad de intenos de inicio de session
    localparam logic [31:0] max = 32'd4; // limite de intentos para iniciar session segura
    
    // --- Señales de interconexion entre modulos y etapas ---
    // [PC select]
    // + Señales de etapa
    logic [31:0] PC, PC_new;
    // + Señales de control

    // [Instruction Fetch (IF)]
    // + Señales de etapa
    logic [31:0] INSTR, IF_INSTR;
    logic [31:0] IF_PC, IF_PCplus4;
    // + Señales de control
    logic Login, Ignore, IF_LoginRefresh;
    // + Señales de riesgos
    logic IF_EN, IF_CLR;

    // [Instruction Decode (ID)]
    // + Señales de etapa
    logic [31:0] ID_INSTR, ID_Imm32, ID_PCplus4;
    logic [31:0] ID_Op1, ID_Op2, ID_RegRD1, ID_RegRD2, ID_SecRD1, ID_SecRD2, ID_SecRD3;
    logic [4:0]  ID_OPCODE, ID_Rd, ID_Rn, ID_Rm, Rm;
    logic [3:0]  ID_FUNC4;
    logic [2:0]  ID_Sd, ID_Sn, ID_Sm, ID_Sf, Sm;
    // + Señales de control
    logic [1:0] ID_MemToReg, ID_RegWrite, ID_MemWrite, ID_Session, ID_ALUSrcA, ID_RSel;
    logic [7:0] ID_MemBytes;
    logic [4:0] ID_Branch, ID_ALUControl;
    logic [2:0] ID_ImmSel;
    logic ID_ALUSel, ID_ALUSrcB, ID_RegSrc, ID_SecSrc, ID_LoginRefresh;
    // + Señales de riesgos
    logic ID_EN, ID_CLR;

    // [Execute (EX)]
    // + Señales de etapa
    logic [31:0] EX_INSTR, EX_pALUOut, EX_sALUOut, EX_ALUOut;
    logic [31:0] EX_Op1, EX_Op2, EX_Op3, EX_Imm32, EX_PCBranch, EX_PCplus4;
    logic [31:0] EX_Op1t, EX_Op2t, EX_Op3t;
    logic [31:0] pSrcA, pSrcB, shiftL_imm;
    logic [3:0]  EX_ALUFlags;
    logic [4:0]  EX_RWB;
    // + Señales de control
    logic [1:0] EX_MemToReg, EX_RegWrite, EX_MemWrite, EX_Session, EX_ALUSrcA;
    logic [7:0] EX_MemBytes;
    logic [4:0] EX_Branch, EX_ALUControl;
    logic EX_ALUSel, EX_ALUSrcB, EX_LoginRefresh;
    // + Señales del hazard unit
    logic [1:0]  EX_Op1Sel, EX_Op2Sel, EX_Op3Sel;
    logic [31:0] EX_Op1Fwd, EX_Op2Fwd, EX_Op3Fwd;
    // + Señales de riesgos
    logic EX_EN, EX_CLR;

    // [Memory access (MEM)]
    // + Señales de etapa
    logic [31:0] MEM_INSTR, MEM_ALUOut, MEM_VaultOut, MEM_MemOut;
    logic [31:0] MEM_PCplus4, MEM_PCBranch, MEM_Op2;
    logic [3:0]  MEM_ALUFlags;
    logic [4:0]  MEM_RWB;
    logic [1:0]  MEM_PCSrc;
    // + Señales de control
    logic [1:0] MEM_MemToReg, MEM_RegWrite, MEM_MemWrite, MEM_Session;
    logic [7:0] MEM_MemBytes;
    logic [4:0] MEM_Branch;
    logic MEM_LoginRefresh;
    // + Señales de riesgos
    logic MEM_EN, MEM_CLR;

    // [Writeback (WB)]
    // + Señales de etapa
    logic [31:0] WB_INSTR, WB_ALUOut, WB_VaultOut, WB_MemOut, WB_PCplus4;
    logic [31:0] WB_DataOut;
    logic [4:0]  WB_RWB;
    logic WB_PCSrc;
    // + Señales de control
    logic [1:0] WB_MemToReg, WB_RegWrite;
    // + Señales de riesgos
    logic WB_EN;

    // ########################################################################################################
    // --- 0. Selección del PC  ---
    assign PC = (WB_PCSrc) ? PC_new : ( (MEM_PCSrc[0]) ? MEM_PCBranch : IF_PCplus4);

    // --- 1. Instruction Fetch (IF) ---
    // + Flip-Flop para pipe IF
    always_ff @(posedge clk, posedge rst) begin
        if (rst | IF_CLR) IF_PC <= '0;
        else if (~IF_EN) IF_PC <= PC;
    end

    assign IF_PCplus4 = IF_PC + 32'd4;
    // + Memoria de instrucciones
    instruction_memory #(.MEM_SIZE_KB(64)) _rom (
        .A(IF_PC),
        .RD(INSTR)
    );

    // + Secure Selection Unit (SSU)
    ssu _ssu (
        .login(Login), .P(INSTR[0]),
        .opcode(INSTR[5:1]),
        .ignore(Ignore), .is_secure(IF_LoginRefresh)
    );

    assign IF_INSTR = (Ignore) ? nop : INSTR;

    // --- 2. Instruction Decode (ID) ---
    // + Flip-Flop para pipe ID
    always_ff @(posedge clk, posedge rst) begin
        if (rst | ID_CLR) begin 
            ID_INSTR <= nop;
            ID_PCplus4 <= '0;
            ID_LoginRefresh <= '0;
        end else if (~ID_EN) begin 
            ID_INSTR <= IF_INSTR;
            ID_PCplus4 <= IF_PCplus4;
            ID_LoginRefresh <= IF_LoginRefresh;
        end
    end

    assign ID_OPCODE = ID_INSTR[5:1];
    assign ID_FUNC4  = ID_INSTR[9:6];

    assign ID_Rd = ID_INSTR[14:10];
    assign ID_Rn = ID_INSTR[19:15];
    assign ID_Rm = ID_INSTR[24:20];
    
    assign ID_Sd = ID_INSTR[12:10];
    assign ID_Sn = ID_INSTR[15:13];
    assign ID_Sm = ID_INSTR[18:16];
    assign ID_Sf = ID_INSTR[21:19];
    // + Unidad de control 
    control_unit _control_unit (
        .opcode(ID_OPCODE),
        .func4(ID_FUNC4),
        .source(ID_INSTR[31:10]),
        .MemToReg(ID_MemToReg),
        .RegWrite(ID_RegWrite),
        .MemWrite(ID_MemWrite), .MemBytes(ID_MemBytes),
        .Branch(ID_Branch),
        .Session(ID_Session),
        .ALUSel(ID_ALUSel), .ALUControl(ID_ALUControl), .ALUSrcB(ID_ALUSrcB), .ALUSrcA(ID_ALUSrcA), 
        .RSel(ID_RSel),
        .ImmSel(ID_ImmSel),
        .RegSrc(ID_RegSrc),
        .SecSrc(ID_SecSrc)
    );

    assign Rm = (ID_RegSrc) ? ID_Rd : ID_Rm;
    assign Sm = (ID_SecSrc) ? ID_Sd : ID_Sm;
    // + Banco seguro de registros (Secure memory)
    secure_memory #(.DATA_WIDTH(32), .ADDR_WIDTH(3)) _secure_memory (
        .clk(clk), .rst_n(~rst),
        .we(WB_RegWrite[0]),
        .ra1(ID_Sn), .ra2(Sm), .ra3(ID_Sf),
        .wa(WB_RWB[2:0]),
        .wd(WB_DataOut),
        .rd1(ID_SecRD1), .rd2(ID_SecRD2), .rd3(ID_SecRD3)
    );

    // + Banco de registros (Register File)
    register_file #(.DATA_WIDTH(32), .ADDR_WIDTH(5)) _register_file (
        .clk(clk), .rst_n(~rst),
        .we(WB_RegWrite[1]),
        .ra1(ID_Rn), .ra2(Rm),
        .wa(WB_RWB),
        .wd(WB_DataOut),
        .pc_in(ID_PCplus4), .lr_in({ 31'b0, Login}),
        .rd1(ID_RegRD1), .rd2(ID_RegRD2),
        .pc_out(PC_new)
    );

    assign ID_Op1 = (ID_RSel[0]) ? ID_RegRD1 : ID_SecRD1;
    assign ID_Op2 = (ID_RSel[1]) ? ID_RegRD2 : ID_SecRD2;
    // >> Unidad de extension de inmediatos
    imm_ext32 _imm_ext (
        .source(ID_INSTR[31:6]),
        .sel(ID_ImmSel),
        .ext(ID_Imm32)
    );

    // --- 3. Execute (EX) ---
    // + Flip-Flop para pipe EX
    always_ff @(posedge clk, posedge rst) begin
        if (rst | EX_CLR) begin 
            EX_INSTR <= nop;
            EX_PCplus4 <= '0;
            EX_Op1 <= '0;
            EX_Op2 <= '0;
            EX_Op3 <= '0;
            EX_Imm32 <= '0;
            EX_RWB <= '0;

            EX_ALUControl <= 5'b00010;
            EX_ALUSrcA <= '0;
            EX_ALUSrcB <= '0;
            EX_ALUSel <=  '0;
            EX_Session <= '0;
            EX_Branch <= '0;
            EX_MemWrite <= '0;
            EX_MemBytes <= '0;
            EX_RegWrite <= '0;
            EX_MemToReg <= '0;
            EX_LoginRefresh <= '0;
        end else if (~EX_EN) begin 
            EX_INSTR <= ID_INSTR;
            EX_PCplus4 <= ID_PCplus4;
            EX_Op1 <= ID_Op1;
            EX_Op2 <= ID_Op2;
            EX_Op3 <= ID_SecRD3;
            EX_Imm32 <= ID_Imm32;
            EX_RWB <= ID_Rd;

            EX_ALUControl <= ID_ALUControl;
            EX_ALUSrcA <= ID_ALUSrcA;
            EX_ALUSrcB <= ID_ALUSrcB;
            EX_ALUSel <= ID_ALUSel;
            EX_Session <= ID_Session;
            EX_Branch <= ID_Branch;
            EX_MemWrite <= ID_MemWrite;
            EX_MemBytes <= ID_MemBytes;
            EX_RegWrite <= ID_RegWrite;
            EX_MemToReg <= ID_MemToReg;
            EX_LoginRefresh <= ID_LoginRefresh;
        end
    end

    // + ALU primaria
    // >> Adelantamientos
    assign EX_Op1t = (EX_Op1Sel != 2'b00) ? EX_Op1Fwd : EX_Op1;
    assign EX_Op2t = (EX_Op2Sel != 2'b00) ? EX_Op2Fwd : EX_Op2;
    assign EX_Op3t = (EX_Op3Sel != 2'b00) ? EX_Op3Fwd : EX_Op3;

    // >> Seleccion de entradas para ALU principal
    assign pSrcA = (EX_ALUSrcA[1]) ? ( (EX_ALUSrcA[0]) ? 32'b0 : EX_Op1t) : ( (EX_ALUSrcA[0]) ? 32'b0 : password);
    assign pSrcB = (EX_ALUSrcB) ? EX_Imm32 : EX_Op2t;
    pALU #(.WIDTH(32)) _pALU (
        .A(pSrcA), .B(pSrcB),
        .op(EX_ALUControl[3:0]),
        .Y(EX_pALUOut),
        .flags(EX_ALUFlags)
    );

    // + ALU secundaria
    sALU #(.WIDTH(32)) _sALU (
        .A(EX_pALUOut), .B(EX_Op3t),
        .op(EX_ALUControl[4]),
        .Y(EX_sALUOut)
    );

    assign EX_ALUOut = (EX_ALUSel) ? EX_pALUOut : EX_sALUOut;
    
    // + Calculo de saltos
    assign shiftL_imm = EX_Imm32 << 2;
    assign EX_PCBranch = EX_PCplus4 + shiftL_imm;

    // --- 4. Memory access (MEM) ---
    // + Flip-Flop para pipe MEM
    always_ff @(posedge clk, posedge rst) begin
        if (rst | MEM_CLR) begin
            MEM_INSTR <= nop;
            MEM_RWB <= '0;
            MEM_ALUFlags <= '0;
            MEM_ALUOut <= '0;
            MEM_PCplus4 <= '0;
            MEM_PCBranch <= '0;
            MEM_Op2 <= '0;
        
            MEM_Session <= '0;
            MEM_Branch <= '0;
            MEM_MemWrite <= '0;
            MEM_MemBytes <= '0;
            MEM_RegWrite <= '0;
            MEM_MemToReg <= '0;
            MEM_LoginRefresh <= '0;
        end else if (~MEM_EN) begin
            MEM_INSTR <= EX_INSTR;
            MEM_RWB <= EX_RWB;
            MEM_ALUFlags <= EX_ALUFlags;
            MEM_ALUOut <= EX_ALUOut;
            MEM_PCplus4 <= EX_PCplus4;
            MEM_PCBranch <= EX_PCBranch;
            MEM_Op2 <= EX_Op2t;

            MEM_Session <= EX_Session;
            MEM_Branch <= EX_Branch;
            MEM_MemWrite <= EX_MemWrite;
            MEM_MemBytes <= EX_MemBytes;
            MEM_RegWrite <= EX_RegWrite;
            MEM_MemToReg <= EX_MemToReg;
            MEM_LoginRefresh <= EX_LoginRefresh;
        end
    end

    // + Unidad de administrador
    admin_unit #(.width(32)) _admin_unit (
        .clk(clk), .rst(rst),
        .logout(MEM_Session[1]), .signal(MEM_ALUFlags[2]), .login(MEM_Session[0]),
        .refresh(MEM_LoginRefresh),
        .tSes(lifetime), .tOut(timeout), .max(max),
        .session(Login)
    );

    // + Unidad de condicionales
    cond_unit _cond_unit (
        .Branch(MEM_Branch),
        .flags(MEM_ALUFlags),
        .PCSrc(MEM_PCSrc)
    );

    // + Boveda (Vault)
    vault #(.NUM_WORDS(16)) _vault (
        .CLK(clk), .RST(rst),
        .A(MEM_ALUOut),
        .WE(MEM_MemWrite[0]),
        .ASM(MEM_MemBytes[3:0]),
        .WD(MEM_Op2),
        .RD(MEM_VaultOut)
    );

    // + Memoria de datos
    data_memory #(.MEM_SIZE_KB(MEM_SIZE_KB)) _ram (
        .CLK(clk), .RST(rst),
        .A(MEM_ALUOut),
        .WE(MEM_MemWrite[1]),
        .ASM(MEM_MemBytes[7:4]),
        .WD(MEM_Op2),
        .RD(MEM_MemOut)
    );

    // --- 5. Writeback (WB) ---
    // + Flip-Flop para pipe WB
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            WB_INSTR <= nop;
            WB_ALUOut <= '0;
            WB_MemOut <= '0;
            WB_VaultOut <= '0;
            WB_RWB <= '0;
            WB_PCplus4 <= '0;

            WB_PCSrc <= '0;
            WB_MemToReg <= '0;
            WB_RegWrite <= '0;
        end else if (~WB_EN) begin 
            WB_INSTR <= MEM_INSTR;
            WB_ALUOut <= MEM_ALUOut;
            WB_MemOut <= MEM_MemOut;
            WB_VaultOut <= MEM_VaultOut;
            WB_RWB <= MEM_RWB;
            WB_PCplus4 <= MEM_PCplus4;

            WB_PCSrc <= MEM_PCSrc[1];
            WB_MemToReg <= MEM_MemToReg;
            WB_RegWrite <= MEM_RegWrite;
        end
    end

    // + Seleccionar señales de salida
    assign WB_DataOut = (WB_MemToReg[1]) ? ( (WB_MemToReg[0]) ? WB_PCplus4 : WB_MemOut) : ( (WB_MemToReg[0]) ? WB_ALUOut : WB_VaultOut);

    // --- 6. Unidad de Riesgos (Hazard Unit) ---
    hazard_unit #(.INSTR_WIDTH(32)) _hazard_unit (
        .IDInstr(ID_INSTR),
        .EXInstr(EX_INSTR),
        .MEMInstr(MEM_INSTR),
        .WBInstr(WB_INSTR),
        .RD1PipeEX(EX_Op1), .RD2PipeEX(EX_Op2), .RD3PipeEX(EX_Op3),
        .ALUOut(MEM_ALUOut), .DataOutWB(WB_DataOut),
        .branch_taken(MEM_PCSrc[0] | MEM_PCSrc[1] | WB_PCSrc),
        .mem_busy(1'b0),
        .wb_busy(1'b0),
        .StallIF(IF_EN), .FlushIF(IF_CLR),
        .StallID(ID_EN), .FlushID(ID_CLR),
        .StallEX(EX_EN), .FlushEX(EX_CLR),
        .StallMEM(MEM_EN), .FlushMEM(MEM_CLR),
        .StallWB(WB_EN),
        .RD1SrcEX(EX_Op1Sel), .RD2SrcEX(EX_Op2Sel), .RD3SrcEX(EX_Op3Sel),
        .RD1FwdEX(EX_Op1Fwd), .RD2FwdEX(EX_Op2Fwd), .RD3FwdEX(EX_Op3Fwd)
    );
endmodule
