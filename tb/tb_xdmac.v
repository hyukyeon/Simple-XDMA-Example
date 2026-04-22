`timescale 1ns/1ps

module tb_xdmac;

    reg r_clk;
    reg r_resetn;

    // APB Interface
    reg [31:0] r_paddr;
    reg        r_psel;
    reg        r_penable;
    reg        r_pwrite;
    reg [31:0] r_pwdata;
    wire [31:0] w_prdata;
    wire        w_pready;
    wire        w_pslverr;

    // Hardware Request
    reg [3:0] r_hw_req;

    // Instantiate Subsystem
    xdmac_subsystem u_subsystem (
        .clk(r_clk), .resetn(r_resetn),
        .paddr(r_paddr), .psel(r_psel), .penable(r_penable), .pwrite(r_pwrite), .pwdata(r_pwdata), 
        .prdata(w_prdata), .pready(w_pready), .pslverr(w_pslverr),
        .i_hw_req(r_hw_req)
    );

    // Clock
    initial begin
        r_clk = 0; forever #5 r_clk = ~r_clk;
    end

    // APB Task
    task apb_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge r_clk);
            r_paddr = addr; r_pwdata = data; r_psel = 1; r_pwrite = 1;
            @(posedge r_clk);
            r_penable = 1;
            while (!w_pready) @(posedge r_clk);
            @(posedge r_clk);
            r_psel = 0; r_penable = 0;
        end
    endtask

    integer i;
    initial begin
        r_resetn = 0; r_hw_req = 0; r_psel = 0; r_penable = 0;
        
        // Pre-fill some data in memories via backdoor
        // SRAM 0 (0x0...): Fill with 0xAAAA...
        for (i=0; i<100; i=i+1) u_subsystem.u_sram0.mem[i] = {4{32'hAAAA_0000 + i}};
        // SRAM 1 (0x1...): Fill with 0xBBBB...
        for (i=0; i<100; i=i+1) u_subsystem.u_sram1.mem[i] = {4{32'hBBBB_0000 + i}};
        // DRAM 0 (0x2...): Fill with 0xCCCC...
        for (i=0; i<100; i=i+1) u_subsystem.u_dram0.mem[i] = {4{32'hCCCC_0000 + i}};
        // DRAM 1 (0x3...): Fill with 0xDDDD...
        for (i=0; i<100; i=i+1) u_subsystem.u_dram1.mem[i] = {4{32'hDDDD_0000 + i}};

        #50 r_resetn = 1; #50;

        $display("--- Configuring All Channels for Mixed Memory Transfers ---");
        // CH0: SRAM0 -> DRAM0 (0x0... -> 0x2...)
        apb_write(32'h00, 32'h0000_0000); // SRC: SRAM0 offset 0
        apb_write(32'h04, 32'h2000_0000); // DST: DRAM0 offset 0
        apb_write(32'h08, 32'h0000_0010); // LEN: 16 bytes

        // CH1: SRAM1 -> DRAM1 (0x1... -> 0x3...)
        apb_write(32'h40, 32'h1000_0000); // SRC: SRAM1 offset 0
        apb_write(32'h44, 32'h3000_0000); // DST: DRAM1 offset 0
        apb_write(32'h48, 32'h0000_0010); // LEN: 16 bytes

        // CH2: DRAM0 -> SRAM1 (0x2... -> 0x1...)
        apb_write(32'h80, 32'h2000_0010); // SRC: DRAM0 offset 0x10
        apb_write(32'h84, 32'h1000_0010); // DST: SRAM1 offset 0x10
        apb_write(32'h88, 32'h0000_0010); // LEN: 16 bytes

        // CH3: DRAM1 -> SRAM0 (0x3... -> 0x0...)
        apb_write(32'hC0, 32'h3000_0010); // SRC: DRAM1 offset 0x10
        apb_write(32'hC4, 32'h0000_0010); // DST: SRAM0 offset 0x10
        apb_write(32'hC8, 32'h0000_0010); // LEN: 16 bytes

        $display("--- Triggering All Channels Simultaneously ---");
        apb_write(32'h0C, 32'h0001); // Start CH0
        apb_write(32'h4C, 32'h0001); // Start CH1
        apb_write(32'h8C, 32'h0001); // Start CH2
        apb_write(32'hCC, 32'h0001); // Start CH3

        $display("--- Waiting for all channels to complete ---");
        wait(u_subsystem.u_xdmac.r_ch_done[0] && 
             u_subsystem.u_xdmac.r_ch_done[1] && 
             u_subsystem.u_xdmac.r_ch_done[2] && 
             u_subsystem.u_xdmac.r_ch_done[3]);

        #100;
        $display("--- Verification ---");
        // Verify CH0 (SRAM0 index 0 -> DRAM0 index 0)
        if (u_subsystem.u_dram0.mem[0] == {4{32'hAAAA_0000}}) $display("CH0 Success!");
        else $display("CH0 Failure! Got %h", u_subsystem.u_dram0.mem[0]);

        // Verify CH1 (SRAM1 index 0 -> DRAM1 index 0)
        if (u_subsystem.u_dram1.mem[0] == {4{32'hBBBB_0000}}) $display("CH1 Success!");
        else $display("CH1 Failure! Got %h", u_subsystem.u_dram1.mem[0]);

        // Verify CH2 (DRAM0 index 1 -> SRAM1 index 1)
        if (u_subsystem.u_sram1.mem[1] == {4{32'hCCCC_0001}}) $display("CH2 Success!");
        else $display("CH2 Failure! Got %h", u_subsystem.u_sram1.mem[1]);

        // Verify CH3 (DRAM1 index 1 -> SRAM0 index 1)
        if (u_subsystem.u_sram0.mem[1] == {4{32'hDDDD_0001}}) $display("CH3 Success!");
        else $display("CH3 Failure! Got %h", u_subsystem.u_sram0.mem[1]);

        #100 $finish;
    end

    initial begin
        $dumpfile("xdmac.vcd");
        $dumpvars(0, tb_xdmac);
    end

endmodule
