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

    // AXI Interface
    wire [31:0] w_awaddr;
    wire [7:0]  w_awlen;
    wire [2:0]  w_awsize;
    wire [1:0]  w_awburst;
    wire        w_awvalid;
    wire        w_awready;
    wire [127:0] w_wdata;
    wire [15:0]  w_wstrb;
    wire        w_wlast;
    wire        w_wvalid;
    wire        w_wready;
    wire [1:0]  w_bresp;
    wire        w_bvalid;
    wire        w_bready;
    wire [31:0] w_araddr;
    wire [7:0]  w_arlen;
    wire [2:0]  w_arsize;
    wire [1:0]  w_arburst;
    wire        w_arvalid;
    wire        w_arready;
    wire [127:0] w_rdata;
    wire [1:0]  w_rresp;
    wire        w_rlast;
    wire        w_rvalid;
    wire        w_rready;

    // Instantiate XDMAC
    xdmac_top u_dut (
        .clk(r_clk), .resetn(r_resetn),
        .paddr(r_paddr), .psel(r_psel), .penable(r_penable), .pwrite(r_pwrite), .pwdata(r_pwdata), .prdata(w_prdata), .pready(w_pready), .pslverr(w_pslverr),
        .i_hw_req(r_hw_req),
        .awaddr(w_awaddr), .awlen(w_awlen), .awsize(w_awsize), .awburst(w_awburst), .awvalid(w_awvalid), .awready(w_awready),
        .wdata(w_wdata), .wstrb(w_wstrb), .wlast(w_wlast), .wvalid(w_wvalid), .wready(w_wready),
        .bresp(w_bresp), .bvalid(w_bvalid), .bready(w_bready),
        .araddr(w_araddr), .arlen(w_arlen), .arsize(w_arsize), .arburst(w_arburst), .arvalid(w_arvalid), .arready(w_arready),
        .rdata(w_rdata), .rresp(w_rresp), .rlast(w_rlast), .rvalid(w_rvalid), .rready(w_rready)
    );

    // Memory Models
    reg [127:0] mem [0:1023]; // Shared memory 16KB
    
    assign w_arready = 1'b1;
    assign w_awready = 1'b1;
    assign w_wready  = 1'b1;
    assign w_bvalid  = 1'b1;
    assign w_bresp   = 2'b00;

    reg r_rvalid;
    reg [127:0] r_rdata;
    reg [7:0] r_rbeat_cnt;
    reg [31:0] r_araddr_latched;
    assign w_rvalid = r_rvalid;
    assign w_rdata  = r_rdata;
    assign w_rlast  = (r_rbeat_cnt == w_arlen);
    assign w_rresp  = 2'b00;

    always @(posedge r_clk) begin
        if (!r_resetn) begin
            r_rvalid <= 0;
            r_rbeat_cnt <= 0;
        end else begin
            if (w_arvalid && w_arready) begin
                r_rvalid <= 1;
                r_rbeat_cnt <= 0;
                r_araddr_latched <= w_araddr;
                r_rdata <= mem[w_araddr[13:4]];
            end else if (w_rvalid && w_rready) begin
                if (w_rlast) r_rvalid <= 0;
                else begin
                    r_rbeat_cnt <= r_rbeat_cnt + 1;
                    r_rdata <= mem[r_araddr_latched[13:4] + r_rbeat_cnt + 1];
                end
            end
        end
    end

    always @(posedge r_clk) begin
        if (r_resetn && w_wvalid && w_wready) begin
            mem[w_awaddr[13:4]] <= w_wdata; // Simplified write for single beats
        end
    end

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
        for (i=0; i<1024; i=i+1) mem[i] = {4{i[31:0]}};
        
        // Descriptor for CH3 at 0x300 (mem index 0x30)
        // Order: [127:96] Next, [95:64] Len, [63:32] Dst, [31:0] Src
        mem[16'h0300 >> 4][31:0]   = 32'h00000400; // SRC
        mem[16'h0300 >> 4][63:32]  = 32'h00000500; // DST
        mem[16'h0300 >> 4][95:64]  = 32'h00000010; // LEN
        mem[16'h0300 >> 4][127:96] = 32'h00000000; // NEXT

        #50 r_resetn = 1; #50;

        $display("--- Starting CH0 (Low Priority, Long Transfer) ---");
        apb_write(32'h00, 32'h0000); // SRC: 0x000
        apb_write(32'h04, 32'h0100); // DST: 0x100
        apb_write(32'h08, 32'h0040); // LEN: 64 bytes
        apb_write(32'h0C, 32'h0001); // START

        #200;
        $display("--- !!! Triggering CH3 HW REQ (High Priority, Scatter-Gather) !!! ---");
        apb_write(32'hD0, 32'h0300); // CH3 DESC_PTR: 0x300
        apb_write(32'hCC, 32'h0004); // CH3 CTRL: Enable Descriptor
        #50;
        r_hw_req[3] = 1;
        #20 r_hw_req[3] = 0;

        wait(u_dut.r_ch_done[0]);
        $display("--- All Transfers Done ---");

        // Verify CH3 (High priority)
        // mem[0x500 >> 4] should match mem[0x400 >> 4]
        if (mem[16'h500 >> 4] == mem[16'h400 >> 4]) $display("CH3 (SG) Success!");
        else begin
            $display("CH3 (SG) Failure!");
            $display("Src (0x400): %h", mem[16'h400 >> 4]);
            $display("Dst (0x500): %h", mem[16'h500 >> 4]);
        end

        // Verify CH0 (Low priority)
        if (mem[16'h130 >> 4] == mem[16'h030 >> 4]) $display("CH0 (Resumed) Success!");
        else $display("CH0 (Resumed) Failure!");

        #100 $finish;
    end

    initial begin
        $dumpfile("xdmac.vcd");
        $dumpvars(0, tb_xdmac);
    end

endmodule
