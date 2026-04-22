module xdmac_axi_master (
    input  wire         i_aclk,
    input  wire         i_aresetn,

    // AXI AW Channel
    output reg  [31:0]  o_awaddr,
    output reg  [7:0]   o_awlen,
    output wire [2:0]   o_awsize,
    output wire [1:0]   o_awburst,
    output reg          o_awvalid,
    input  wire         i_awready,

    // AXI W Channel
    output reg  [127:0] o_wdata,
    output wire [15:0]  o_wstrb,
    output reg          o_wlast,
    output reg          o_wvalid,
    input  wire         i_wready,

    // AXI B Channel
    input  wire [1:0]   i_bresp,
    input  wire         i_bvalid,
    output wire         o_bready,

    // AXI AR Channel
    output reg  [31:0]  o_araddr,
    output reg  [7:0]   o_arlen,
    output wire [2:0]   o_arsize,
    output wire [1:0]   o_arburst,
    output reg          o_arvalid,
    input  wire         i_arready,

    // AXI R Channel
    input  wire [127:0] i_rdata,
    input  wire [1:0]   i_rresp,
    input  wire         i_rlast,
    input  wire         i_rvalid,
    output wire         o_rready,

    // Master Control Interface
    input  wire         i_m_req,
    input  wire [31:0]  i_m_addr,
    input  wire [7:0]   i_m_len,
    input  wire         i_m_is_write,
    output reg          o_m_ack,
    output reg [127:0]  o_m_rdata,
    input  wire [127:0] i_m_wdata,
    output reg          o_m_burst_done
);

    assign o_awsize  = 3'b100; 
    assign o_arsize  = 3'b100;
    assign o_awburst = 2'b01;
    assign o_arburst = 2'b01;
    assign o_wstrb   = 16'hFFFF;
    assign o_bready  = 1'b1;
    assign o_rready  = (r_state == S_READ_R);

    localparam S_IDLE      = 3'd0;
    localparam S_ADDR      = 3'd1;
    localparam S_READ_R    = 3'd2;
    localparam S_WRITE_W   = 3'd3;
    localparam S_WRITE_B   = 3'd4;
    localparam S_DONE      = 3'd5;

    reg [2:0] r_state;
    reg [7:0] r_beat_cnt;

    always @(posedge i_aclk or negedge i_aresetn) begin
        if (!i_aresetn) begin
            r_state <= S_IDLE;
            o_m_ack <= 0;
            o_m_burst_done <= 0;
            o_arvalid <= 0;
            o_awvalid <= 0;
            o_wvalid <= 0;
            o_wlast <= 0;
            r_beat_cnt <= 0;
        end else begin
            case (r_state)
                S_IDLE: begin
                    o_m_burst_done <= 0;
                    if (i_m_req && !o_m_ack) begin
                        o_m_ack <= 1;
                        r_state <= S_ADDR;
                        if (i_m_is_write) begin
                            $display("[LOG %0t] [AXI_MASTER] Write Req: Addr=0x%h, Len=%0d", $time, i_m_addr, i_m_len);
                            o_awaddr  <= i_m_addr;
                            o_awlen   <= i_m_len;
                            o_awvalid <= 1;
                        end else begin
                            $display("[LOG %0t] [AXI_MASTER] Read Req: Addr=0x%h, Len=%0d", $time, i_m_addr, i_m_len);
                            o_araddr  <= i_m_addr;
                            o_arlen   <= i_m_len;
                            o_arvalid <= 1;
                        end
                    end else if (!i_m_req) begin
                        o_m_ack <= 0;
                    end
                end

                S_ADDR: begin
                    if (o_arvalid && i_arready) begin
                        o_arvalid <= 0;
                        r_state <= S_READ_R;
                        r_beat_cnt <= 0;
                    end else if (o_awvalid && i_awready) begin
                        o_awvalid <= 0;
                        r_state <= S_WRITE_W;
                        r_beat_cnt <= 0;
                        o_wvalid <= 1;
                        o_wdata  <= i_m_wdata;
                        o_wlast  <= (i_m_len == 0);
                    end
                end

                S_READ_R: begin
                    if (i_rvalid) begin
                        $display("[LOG %0t] [AXI_MASTER] Read Data: %h (Last=%b)", $time, i_rdata, i_rlast);
                        o_m_rdata <= i_rdata;
                        if (i_rlast) begin
                            o_m_burst_done <= 1;
                            r_state <= S_DONE;
                        end
                    end
                end

                S_WRITE_W: begin
                    if (i_wready) begin
                        $display("[LOG %0t] [AXI_MASTER] Write Data: %h (Last=%b)", $time, o_wdata, o_wlast);
                        if (o_wlast) begin
                            o_wvalid <= 0;
                            o_wlast  <= 0;
                            r_state  <= S_WRITE_B;
                        end else begin
                            r_beat_cnt <= r_beat_cnt + 1;
                            o_wdata <= i_m_wdata;
                            o_wlast <= (r_beat_cnt + 1 == o_awlen);
                        end
                    end
                end

                S_WRITE_B: begin
                    if (i_bvalid) begin
                        $display("[LOG %0t] [AXI_MASTER] Write Response (B) Received", $time);
                        o_m_burst_done <= 1;
                        r_state <= S_DONE;
                    end
                end

                S_DONE: begin
                    o_m_burst_done <= 0;
                    r_state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
