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
        
        // Pre-fill
        for (i=0; i<256; i=i+1) begin
            u_subsystem.u_sram0.mem[i] = {4{32'hAAAA_0000 + i}};
            u_subsystem.u_sram1.mem[i] = {4{32'hBBBB_0000 + i}};
            u_subsystem.u_dram0.mem[i] = {4{32'hCCCC_0000 + i}};
            u_subsystem.u_dram1.mem[i] = {4{32'hDDDD_0000 + i}};
        end

        #50 r_resetn = 1; #50;

        // ---------------------------------------------------------
        // Test Case 1: Mixed Memory Type Transfers
        // ---------------------------------------------------------
        $display("\n[TEST] Case 1: Mixed Memory Type Transfers");
        apb_write(32'h00, 32'h0000_0000); apb_write(32'h04, 32'h1000_0080); apb_write(32'h08, 32'h0000_0010); 
        apb_write(32'h40, 32'h2000_0000); apb_write(32'h44, 32'h3000_0080); apb_write(32'h48, 32'h0000_0010); 
        apb_write(32'h80, 32'h1000_0000); apb_write(32'h84, 32'h2000_0080); apb_write(32'h88, 32'h0000_0010); 
        apb_write(32'hC0, 32'h3000_0000); apb_write(32'hC4, 32'h0000_0080); apb_write(32'hC8, 32'h0000_0010); 
        
        // Start them
        apb_write(32'h0C, 32'h0001); apb_write(32'h4C, 32'h0001); apb_write(32'h8C, 32'h0001); apb_write(32'hCC, 32'h0001);

        wait(u_subsystem.u_xdmac.r_ch_done[0] && u_subsystem.u_xdmac.r_ch_done[1] && 
             u_subsystem.u_xdmac.r_ch_done[2] && u_subsystem.u_xdmac.r_ch_done[3]);
        $display("[TEST] Case 1 Finished.");

        #200;

        // ---------------------------------------------------------
        // Test Case 2: Priority Arbitration Storm (SIMULTANEOUS trigger)
        // ---------------------------------------------------------
        $display("\n[TEST] Case 2: Priority Arbitration Storm (CH0,1,2,3 Simultaneous)");
        // Setup new transfers at different offsets
        apb_write(32'h00, 32'h0000_0020); apb_write(32'h04, 32'h1000_00A0); apb_write(32'h08, 32'h0000_0010); 
        apb_write(32'h40, 32'h1000_0020); apb_write(32'h44, 32'h0000_00A0); apb_write(32'h48, 32'h0000_0010); 
        apb_write(32'h80, 32'h0000_0040); apb_write(32'h84, 32'h1000_00C0); apb_write(32'h88, 32'h0000_0010); 
        apb_write(32'hC0, 32'h1000_0040); apb_write(32'hC4, 32'h0000_00C0); apb_write(32'hC8, 32'h0000_0010); 

        // Backdoor Trigger: Force all START bits to 1 in the same cycle
        @(posedge r_clk);
        force u_subsystem.u_xdmac.u_apb_slave.o_ch_ctrl_start = 4'b1111;
        @(posedge r_clk);
        release u_subsystem.u_xdmac.u_apb_slave.o_ch_ctrl_start;

        $display("[TEST] All channels triggered simultaneously. Arbiter should pick CH3 first.");
        
        // Wait for all to finish
        wait(u_subsystem.u_xdmac.r_ch_done[0] && u_subsystem.u_xdmac.r_ch_done[1] && 
             u_subsystem.u_xdmac.r_ch_done[2] && u_subsystem.u_xdmac.r_ch_done[3]);
        
        $display("\n--- Final Verification ---");
        // Check data at destination offsets
        if (u_subsystem.u_sram1.mem[10] == {4{32'hAAAA_0002}}) $display("CH0 Final Success!");
        if (u_subsystem.u_sram0.mem[10] == {4{32'hBBBB_0002}}) $display("CH1 Final Success!");
        if (u_subsystem.u_sram1.mem[12] == {4{32'hAAAA_0004}}) $display("CH2 Final Success!");
        if (u_subsystem.u_sram0.mem[12] == {4{32'hBBBB_0004}}) $display("CH3 Final Success!");

        #100 $finish;
    end

    initial begin
        $dumpfile("xdmac.vcd");
        $dumpvars(0, tb_xdmac);
    end

endmodule
