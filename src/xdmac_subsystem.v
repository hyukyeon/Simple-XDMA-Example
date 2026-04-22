module xdmac_subsystem (
    input  wire         clk,
    input  wire         resetn,

    // APB Slave Interface (from top)
    input  wire [31:0]  paddr,
    input  wire         psel,
    input  wire         penable,
    input  wire         pwrite,
    input  wire [31:0]  pwdata,
    output wire [31:0]  prdata,
    output wire         pready,
    output wire         pslverr,

    // Hardware Handshaking
    input  wire [3:0]   i_hw_req
);

    // XDMAC Master Signals
    wire [31:0]  m_awaddr;
    wire [7:0]   m_awlen;
    wire [2:0]   m_awsize;
    wire [1:0]   m_awburst;
    wire         m_awvalid;
    wire         m_awready;
    wire [127:0] m_wdata;
    wire [15:0]  m_wstrb;
    wire         m_wlast;
    wire         m_wvalid;
    wire         m_wready;
    wire [1:0]   m_bresp;
    wire         m_bvalid;
    wire         m_bready;
    wire [31:0]  m_araddr;
    wire [7:0]   m_arlen;
    wire [2:0]   m_arsize;
    wire [1:0]   m_arburst;
    wire         m_arvalid;
    wire         m_arready;
    wire [127:0] m_rdata;
    wire [1:0]   m_rresp;
    wire         m_rlast;
    wire         m_rvalid;
    wire         m_rready;

    // Instantiate XDMAC Top
    xdmac_top u_xdmac (
        .clk(clk), .resetn(resetn),
        .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .i_hw_req(i_hw_req),
        .awaddr(m_awaddr), .awlen(m_awlen), .awsize(m_awsize), .awburst(m_awburst), .awvalid(m_awvalid), .awready(m_awready),
        .wdata(m_wdata), .wstrb(m_wstrb), .wlast(m_wlast), .wvalid(m_wvalid), .wready(m_wready),
        .bresp(m_bresp), .bvalid(m_bvalid), .bready(m_bready),
        .araddr(m_araddr), .arlen(m_arlen), .arsize(m_arsize), .arburst(m_arburst), .arvalid(m_arvalid), .arready(m_arready),
        .rdata(m_rdata), .rresp(m_rresp), .rlast(m_rlast), .rvalid(m_rvalid), .rready(m_rready)
    );

    // Slave Interface Arrays (Flattened for easier connection if needed, but Verilog-2001 doesn't support arrays in ports easily)
    wire [31:0]  s_awaddr  [0:3];
    wire [7:0]   s_awlen   [0:3];
    wire [2:0]   s_awsize  [0:3];
    wire [1:0]   s_awburst [0:3];
    wire [3:0]   s_awvalid;
    wire [3:0]   s_awready;

    wire [127:0] s_wdata   [0:3];
    wire [15:0]  s_wstrb   [0:3];
    wire [3:0]   s_wlast;
    wire [3:0]   s_wvalid;
    wire [3:0]   s_wready;

    wire [1:0]   s_bresp   [0:3];
    wire [3:0]   s_bvalid;
    wire [3:0]   s_bready;

    wire [31:0]  s_araddr  [0:3];
    wire [7:0]   s_arlen   [0:3];
    wire [2:0]   s_arsize  [0:3];
    wire [1:0]   s_arburst [0:3];
    wire [3:0]   s_arvalid;
    wire [3:0]   s_arready;

    wire [127:0] s_rdata   [0:3];
    wire [1:0]   s_rresp   [0:3];
    wire [3:0]   s_rlast;
    wire [3:0]   s_rvalid;
    wire [3:0]   s_rready;

    // Instantiate Interconnect
    axi_interconnect_1x4 u_interconnect (
        .clk(clk), .resetn(resetn),
        .m_awaddr(m_awaddr), .m_awlen(m_awlen), .m_awsize(m_awsize), .m_awburst(m_awburst), .m_awvalid(m_awvalid), .m_awready(m_awready),
        .m_wdata(m_wdata), .m_wstrb(m_wstrb), .m_wlast(m_wlast), .m_wvalid(m_wvalid), .m_wready(m_wready),
        .m_bresp(m_bresp), .m_bvalid(m_bvalid), .m_bready(m_bready),
        .m_araddr(m_araddr), .m_arlen(m_arlen), .m_arsize(m_arsize), .m_arburst(m_arburst), .m_arvalid(m_arvalid), .m_arready(m_arready),
        .m_rdata(m_rdata), .m_rresp(m_rresp), .m_rlast(m_rlast), .m_rvalid(m_rvalid), .m_rready(m_rready),
        
        .s_awaddr(s_awaddr), .s_awlen(s_awlen), .s_awsize(s_awsize), .s_awburst(s_awburst), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wlast(s_wlast), .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bresp(s_bresp), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arlen(s_arlen), .s_arsize(s_arsize), .s_arburst(s_arburst), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rlast(s_rlast), .s_rvalid(s_rvalid), .s_rready(s_rready)
    );

    // Memory Instances
    // SRAM 0: 0x0... (Latency 1)
    axi_slave_mem #(.LATENCY(1)) u_sram0 (
        .clk(clk), .resetn(resetn),
        .awaddr(s_awaddr[0]), .awlen(s_awlen[0]), .awsize(s_awsize[0]), .awburst(s_awburst[0]), .awvalid(s_awvalid[0]), .awready(s_awready[0]),
        .wdata(s_wdata[0]), .wstrb(s_wstrb[0]), .wlast(s_wlast[0]), .wvalid(s_wvalid[0]), .wready(s_wready[0]),
        .bresp(s_bresp[0]), .bvalid(s_bvalid[0]), .bready(s_bready[0]),
        .araddr(s_araddr[0]), .arlen(s_arlen[0]), .arsize(s_arsize[0]), .arburst(s_arburst[0]), .arvalid(s_arvalid[0]), .arready(s_arready[0]),
        .rdata(s_rdata[0]), .rresp(s_rresp[0]), .rlast(s_rlast[0]), .rvalid(s_rvalid[0]), .rready(s_rready[0])
    );

    // SRAM 1: 0x1... (Latency 1)
    axi_slave_mem #(.LATENCY(1)) u_sram1 (
        .clk(clk), .resetn(resetn),
        .awaddr(s_awaddr[1]), .awlen(s_awlen[1]), .awsize(s_awsize[1]), .awburst(s_awburst[1]), .awvalid(s_awvalid[1]), .awready(s_awready[1]),
        .wdata(s_wdata[1]), .wstrb(s_wstrb[1]), .wlast(s_wlast[1]), .wvalid(s_wvalid[1]), .wready(s_wready[1]),
        .bresp(s_bresp[1]), .bvalid(s_bvalid[1]), .bready(s_bready[1]),
        .araddr(s_araddr[1]), .arlen(s_arlen[1]), .arsize(s_arsize[1]), .arburst(s_arburst[1]), .arvalid(s_arvalid[1]), .arready(s_arready[1]),
        .rdata(s_rdata[1]), .rresp(s_rresp[1]), .rlast(s_rlast[1]), .rvalid(s_rvalid[1]), .rready(s_rready[1])
    );

    // DRAM 0: 0x2... (Latency 15)
    axi_slave_mem #(.LATENCY(15)) u_dram0 (
        .clk(clk), .resetn(resetn),
        .awaddr(s_awaddr[2]), .awlen(s_awlen[2]), .awsize(s_awsize[2]), .awburst(s_awburst[2]), .awvalid(s_awvalid[2]), .awready(s_awready[2]),
        .wdata(s_wdata[2]), .wstrb(s_wstrb[2]), .wlast(s_wlast[2]), .wvalid(s_wvalid[2]), .wready(s_wready[2]),
        .bresp(s_bresp[2]), .bvalid(s_bvalid[2]), .bready(s_bready[2]),
        .araddr(s_araddr[2]), .arlen(s_arlen[2]), .arsize(s_arsize[2]), .arburst(s_arburst[2]), .arvalid(s_arvalid[2]), .arready(s_arready[2]),
        .rdata(s_rdata[2]), .rresp(s_rresp[2]), .rlast(s_rlast[2]), .rvalid(s_rvalid[2]), .rready(s_rready[2])
    );

    // DRAM 1: 0x3... (Latency 20)
    axi_slave_mem #(.LATENCY(20)) u_dram1 (
        .clk(clk), .resetn(resetn),
        .awaddr(s_awaddr[3]), .awlen(s_awlen[3]), .awsize(s_awsize[3]), .awburst(s_awburst[3]), .awvalid(s_awvalid[3]), .awready(s_awready[3]),
        .wdata(s_wdata[3]), .wstrb(s_wstrb[3]), .wlast(s_wlast[3]), .wvalid(s_wvalid[3]), .wready(s_wready[3]),
        .bresp(s_bresp[3]), .bvalid(s_bvalid[3]), .bready(s_bready[3]),
        .araddr(s_araddr[3]), .arlen(s_arlen[3]), .arsize(s_arsize[3]), .arburst(s_arburst[3]), .arvalid(s_arvalid[3]), .arready(s_arready[3]),
        .rdata(s_rdata[3]), .rresp(s_rresp[3]), .rlast(s_rlast[3]), .rvalid(s_rvalid[3]), .rready(s_rready[3])
    );

endmodule
