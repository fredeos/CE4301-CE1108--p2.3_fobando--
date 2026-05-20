module tb_ssu ();
    localparam N = 6;

    logic [31:0] instructions [N-1:0];
    logic [31:0] instr;

    logic login, P, ignore, is_secure;
    logic [4:0] opcode;

    ssu _ssu (
        .login(login), .P(P),
        .opcode(opcode),
        .ignore(ignore),
        .is_secure(is_secure)
    );

    initial begin 
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, tb_ssu);
        $display("[Inicio del testbench]");
        // Configurar instrucciones
        instructions[0] = 32'h00708d03; // @muli pc, ra, 7
        instructions[1] = 32'h01181480; // add p0, r2, r3
        instructions[2] = 32'h00022144; // pdiv  ax, bx, cx
        instructions[3] = 32'h0051A085; // @paddxor ax, fx, bx, cx
        instructions[4] = 32'h00088820; // send cx, r3
        instructions[5] = 32'h00000512; // jal ra, 11

        // Probar cuando no hay un inicio de sesion
        login = 1;
        #10;
        for (int j = 0; j < 2; j++) begin 
            login = ~login;
            #10;
            $display(">>> ALTERNANDO LOGIN <<<");
            for (int i = 0; i < N; i++) begin 
                instr = instructions[i];
                P = instr[0];
                opcode = instr[5:1];
                #10;
                $display("-----------------------------[INSTR[%0d] = 0x%h]-----------------------------", i, instr);
                $display("LOGIN = %b", login);
                if (P) $display("Instruccion protegida (@)? Si");
                else $display("Instruccion protegida (@)? No");

                if (ignore) $display("Omitir? Si");
                else $display("Omitir? No");

                if(is_secure) $display("Requiere hardware seguro? Si");
                else $display("Requiere hardware seguro? No");
            end
        end

        $display("[Final del testbench]");
        $finish;
    end
endmodule