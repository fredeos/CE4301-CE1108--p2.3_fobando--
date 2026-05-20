module tb_cond_unit ();
    logic [2:0] cond;
    logic nf, zf, cf, vf, pcmod, binstr;
    logic [1:0] PCSrc;

    cond_unit _cond_unit (
        .Branch({cond, pcmod, binstr}),
        .flags({nf, zf, cf, vf}),
        .PCSrc(PCSrc)
    );

    initial begin
        $dumpfile("./output/wave.vcd");
        $dumpvars(0, tb_cond_unit);
        $display("[Inicio del testbench]");

        nf = 0; zf = 0; cf = 0; vf = 0;
        cond = 3'b100; // GE
        pcmod = 0; binstr = 0;
        #10;
        $display("-----------------------------------------------------");
        $display("Cond = %b", cond);
        $display("Flags = %b%b%b%b", nf, zf, cf, vf);
        $display("PCmod = %b, Binstr = %b", pcmod, binstr);
        $display("PCSrc = %b", PCSrc);

        nf = 0; zf = 1; cf = 0; vf = 0;
        cond = 3'b001; // NE
        pcmod = 0; binstr = 1;
        #10;
        $display("-----------------------------------------------------");
        $display("Cond = %b", cond);
        $display("Flags = %b%b%b%b", nf, zf, cf, vf);
        $display("PCmod = %b, Binstr = %b", pcmod, binstr);
        $display("PCSrc = %b", PCSrc);

        nf = 0; zf = 0; cf = 0; vf = 0;
        cond = 3'b001; // NE
        pcmod = 0; binstr = 1;
        #10;
        $display("-----------------------------------------------------");
        $display("Cond = %b", cond);
        $display("Flags = %b%b%b%b", nf, zf, cf, vf);
        $display("PCmod = %b, Binstr = %b", pcmod, binstr);
        $display("PCSrc = %b", PCSrc);

        nf = 0; zf = 1; cf = 0; vf = 0;
        cond = 3'b010; // GT
        pcmod = 0; binstr = 1;
        #10;
        $display("-----------------------------------------------------");
        $display("Cond = %b", cond);
        $display("Flags = %b%b%b%b", nf, zf, cf, vf);
        $display("PCmod = %b, Binstr = %b", pcmod, binstr);
        $display("PCSrc = %b", PCSrc);

        nf = 0; zf = 0; cf = 0; vf = 0;
        cond = 3'b010; // GT
        pcmod = 0; binstr = 1;
        #10;
        $display("-----------------------------------------------------");
        $display("Cond = %b", cond);
        $display("Flags = %b%b%b%b", nf, zf, cf, vf);
        $display("PCmod = %b, Binstr = %b", pcmod, binstr);
        $display("PCSrc = %b", PCSrc);

        nf = 1; zf = 0; cf = 1; vf = 0;
        cond = 3'b110; // UNC
        pcmod = 1; binstr = 1;
        #10;
        $display("-----------------------------------------------------");
        $display("Cond = %b", cond);
        $display("Flags = %b%b%b%b", nf, zf, cf, vf);
        $display("PCmod = %b, Binstr = %b", pcmod, binstr);
        $display("PCSrc = %b", PCSrc);

        nf = 0; zf = 1; cf = 0; vf = 0;
        cond = 3'b000; // EQ
        pcmod = 1; binstr = 0;
        #10;
        $display("-----------------------------------------------------");
        $display("Cond = %b", cond);
        $display("Flags = %b%b%b%b", nf, zf, cf, vf);
        $display("PCmod = %b, Binstr = %b", pcmod, binstr);
        $display("PCSrc = %b", PCSrc);

        $display("[Final del testbench]");
        $finish;
    end
endmodule