module tb_admin_unit ();
    localparam W = 8;

    logic clk, rst, logout, login, zero, session, refresh;
    logic [W-1:0] lifetime, timeout, maxAttempts;

    admin_unit #(.width(8)) _admin_unit (
        .clk(clk), .rst(rst),
        .logout(logout), .signal(zero), .login(login), .refresh(refresh),
        .tSes(lifetime), .tOut(timeout), .max(maxAttempts),
        .session(session)
    );

    always #5 clk = ~clk;
    initial begin
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, tb_admin_unit);
        $display("[Inicio del testbench]");

        // Configuracion de la unidad de administrador
        lifetime = 8'd5;
        timeout = 8'd10;
        maxAttempts = 8'd3;
        login = 0;
        logout = 0;
        refresh = 0;
        zero = 0;
        clk = 0;
        rst = 1;

        #5;
        rst = 0;
        #5;
        
        // 1. Sobrecargar intentos (contraseña incorrecta)
        $display("--------------------------[Sobrecarga de intentos de inicio de session]--------------------------");
        for (int i = 0; i < 4; i++) begin
            login = 1;
            if (i == 3) zero = 1; // Contrasena correcta
            else zero = 0; // Contrasena incorrecta
            #10;
            if (session) $display("Inicio de session exitoso");
            else $display("Inicio de session fallado (%0d)", i);
        end

        // 2. Contar tiempo de espera (contrasena correcta)
        login = 1;
        zero = 1; // contrasena correcta
        $display("--------------------------[Tiempo de espera para iniciar session]--------------------------");
        for (int i = 0; i < 11; i++) begin
            #10;
            if (session) $display("Inicio de session exitoso");
            else $display("Inicio de session fallado (%0d)", i);
        end

        // 3. Tiempo de vida maximo de la sesion
        login = 0; // 'ejecutando' otras instrucciones
        zero = 0; 
        $display("--------------------------[Tiempo de vida de una session activa]--------------------------");
        for (int i = 0; i < 11; i++) begin
            if (i == 4) refresh = 1; // refrescar session
            else refresh = 0;
            #10;
            if (session) $display("Session de admin activa (%0d)", i);
            else $display("Session finalizada");
        end

        // 4. Iniciar y cerrar una session manualmente
        #10;
        $display("--------------------------[Inicio y cierra de session]--------------------------");
        for (int i = 0; i < 2; i++) begin
            if (i == 0) begin  // Iniciar session
                login = 1;
                zero = 1;
            end else begin // Cerrar sesion
                login = 0;
                logout = 1;
                zero = 0;
            end
            #10;
            if (session) $display("Inicio de session exitoso");
            else $display("Cierre de session");
        end

        $display("[Final del testbench]");
        $finish;
    end
endmodule