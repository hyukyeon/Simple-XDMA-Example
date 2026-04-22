module axi_interconnect_1x4 (
    input  wire         clk,
    input  wire         resetn,

    // Master Interface (connected to XDMAC)
    input  wire [31:0]  m_awaddr,
    input  wire [7:0]   m_awlen,
    input  wire [2:0]   m_awsize,
    input  wire [1:0]   m_awburst,
    input  wire         m_awvalid,
    output reg          m_awready,

    input  wire [127:0] m_wdata,
    input  wire [15:0]  m_wstrb,
    input  wire         m_wlast,
    input  wire         m_wvalid,
    output reg          m_wready,

    output reg  [1:0]   m_bresp,
    output reg          m_bvalid,
    input  wire         m_bready,

    input  wire [31:0]  m_araddr,
    input  wire [7:0]   m_arlen,
    input  wire [2:0]   m_arsize,
    input  wire [1:0]   m_arburst,
    input  wire         m_arvalid,
    output reg          m_arready,

    output reg  [127:0] m_rdata,
    output reg  [1:0]   m_rresp,
    output reg          m_rlast,
    output reg          m_rvalid,
    input  wire         m_rready,

    // Slave Interfaces (4 memories)
    output wire [31:0]  s_awaddr  [0:3],
    output wire [7:0]   s_awlen   [0:3],
    output wire [2:0]   s_awsize  [0:3],
    output wire [1:0]   s_awburst [0:3],
    output reg  [3:0]   s_awvalid,
    input  wire [3:0]   s_awready,

    output wire [127:0] s_wdata   [0:3],
    output wire [15:0]  s_wstrb   [0:3],
    output wire [3:0]   s_wlast,
    output reg  [3:0]   s_wvalid,
    input  wire [3:0]   s_wready,

    input  wire [1:0]   s_bresp   [0:3],
    input  wire [3:0]   s_bvalid,
    output reg  [3:0]   s_bready,

    output wire [31:0]  s_araddr  [0:3],
    output wire [7:0]   s_arlen   [0:3],
    output wire [2:0]   s_arsize  [0:3],
    output wire [1:0]   s_arburst [0:3],
    output reg  [3:0]   s_arvalid,
    input  wire [3:0]   s_arready,

    input  wire [127:0] s_rdata   [0:3],
    input  wire [1:0]   s_rresp   [0:3],
    input  wire [3:0]   s_rlast,
    input  wire [3:0]   s_rvalid,
    output reg  [3:0]   s_rready
);

    // Address Decoding
    wire [1:0] aw_sel = m_awaddr[29:28]; // Use bit 29:28 to select (0, 1, 2, 3)
    wire [1:0] ar_sel = m_araddr[29:28];

    // Latch target slave for data/resp phases
    reg [1:0] r_aw_sel_latched, r_ar_sel_latched;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            r_aw_sel_latched <= 0;
            r_ar_sel_latched <= 0;
        end else begin
            if (m_awvalid && m_awready) r_aw_sel_latched <= aw_sel;
            if (m_arvalid && m_arready) r_ar_sel_latched <= ar_sel;
        end
    end

    // AW Channel
    integer i;
    always @(*) begin
        s_awvalid = 4'b0000;
        m_awready = 0;
        for (i=0; i<4; i=i+1) begin
            if (aw_sel == i) begin
                s_awvalid[i] = m_awvalid;
                m_awready    = s_awready[i];
            end
        end
    end
    assign s_awaddr[0] = m_awaddr; assign s_awlen[0] = m_awlen; assign s_awsize[0] = m_awsize; assign s_awburst[0] = m_awburst;
    assign s_awaddr[1] = m_awaddr; assign s_awlen[1] = m_awlen; assign s_awsize[1] = m_awsize; assign s_awburst[1] = m_awburst;
    assign s_awaddr[2] = m_awaddr; assign s_awlen[2] = m_awlen; assign s_awsize[2] = m_awsize; assign s_awburst[2] = m_awburst;
    assign s_awaddr[3] = m_awaddr; assign s_awlen[3] = m_awlen; assign s_awsize[3] = m_awsize; assign s_awburst[3] = m_awburst;

    // W Channel
    always @(*) begin
        s_wvalid = 4'b0000;
        m_wready = 0;
        for (i=0; i<4; i=i+1) begin
            if (r_aw_sel_latched == i) begin
                s_wvalid[i] = m_wvalid;
                m_wready    = s_wready[i];
            end
        end
    end
    assign s_wdata[0] = m_wdata; assign s_wstrb[0] = m_wstrb; assign s_wlast[0] = m_wlast;
    assign s_wdata[1] = m_wdata; assign s_wstrb[1] = m_wstrb; assign s_wlast[1] = m_wlast;
    assign s_wdata[2] = m_wdata; assign s_wstrb[2] = m_wstrb; assign s_wlast[2] = m_wlast;
    assign s_wdata[3] = m_wdata; assign s_wstrb[3] = m_wstrb; assign s_wlast[3] = m_wlast;

    // B Channel
    always @(*) begin
        s_bready = 4'b0000;
        m_bvalid = 0;
        m_bresp  = 2'b00;
        for (i=0; i<4; i=i+1) begin
            if (r_aw_sel_latched == i) begin
                m_bvalid    = s_bvalid[i];
                m_bresp     = s_bresp[i];
                s_bready[i] = m_bready;
            end
        end
    end

    // AR Channel
    always @(*) begin
        s_arvalid = 4'b0000;
        m_arready = 0;
        for (i=0; i<4; i=i+1) begin
            if (ar_sel == i) begin
                s_arvalid[i] = m_arvalid;
                m_arready    = s_arready[i];
            end
        end
    end
    assign s_araddr[0] = m_araddr; assign s_arlen[0] = m_arlen; assign s_arsize[0] = m_arsize; assign s_arburst[0] = m_arburst;
    assign s_araddr[1] = m_araddr; assign s_arlen[1] = m_arlen; assign s_arsize[1] = m_arsize; assign s_arburst[1] = m_arburst;
    assign s_araddr[2] = m_araddr; assign s_arlen[2] = m_arlen; assign s_arsize[2] = m_arsize; assign s_arburst[2] = m_arburst;
    assign s_araddr[3] = m_araddr; assign s_arlen[3] = m_arlen; assign s_arsize[3] = m_arsize; assign s_arburst[3] = m_arburst;

    // R Channel
    always @(*) begin
        s_rready = 4'b0000;
        m_rvalid = 0;
        m_rdata  = 0;
        m_rresp  = 2'b00;
        m_rlast  = 0;
        for (i=0; i<4; i=i+1) begin
            if (r_ar_sel_latched == i) begin
                m_rvalid    = s_rvalid[i];
                m_rdata     = s_rdata[i];
                m_rresp     = s_rresp[i];
                m_rlast     = s_rlast[i];
                s_rready[i] = m_rready;
            end
        end
    end

endmodule
