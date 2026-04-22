module xdmac_top (
    input  wire         clk,
    input  wire         resetn,

    // APB Slave Interface
    input  wire [31:0]  paddr,
    input  wire         psel,
    input  wire         penable,
    input  wire         pwrite,
    input  wire [31:0]  pwdata,
    output wire [31:0]  prdata,
    output wire         pready,
    output wire         pslverr,

    // Hardware Handshaking
    input  wire [3:0]   i_hw_req,

    // AXI Master Interface
    output wire [31:0]  awaddr,
    output wire [7:0]   awlen,
    output wire [2:0]   awsize,
    output wire [1:0]   awburst,
    output wire         awvalid,
    input  wire         awready,
    output wire [127:0] wdata,
    output wire [15:0]  wstrb,
    output wire         wlast,
    output wire         wvalid,
    input  wire         wready,
    input  wire [1:0]   bresp,
    input  wire         bvalid,
    output wire         bready,
    output wire [31:0]  araddr,
    output wire [7:0]   arlen,
    output wire [2:0]   arsize,
    output wire [1:0]   arburst,
    output wire         arvalid,
    input  wire         arready,
    input  wire [127:0] rdata,
    input  wire [1:0]   rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready
);

    // Channel Registers
    wire [127:0] w_ch_src_flat, w_ch_dst_flat, w_ch_len_flat, w_ch_desc_ptr_flat;
    wire [31:0]  w_ch_src [0:3], w_ch_dst [0:3], w_ch_len [0:3], w_ch_desc_ptr [0:3];
    wire [3:0]   w_ch_ctrl_start, w_ch_ctrl_desc_en, w_ch_soft_reset;
    reg  [3:0]   r_ch_busy, r_ch_done;

    xdmac_apb_slave u_apb_slave (
        .i_pclk(clk), .i_presetn(resetn), .i_paddr(paddr), .i_psel(psel), .i_penable(penable), .i_pwrite(pwrite), .i_pwdata(pwdata),
        .o_prdata(prdata), .o_pready(pready), .o_pslverr(pslverr),
        .o_ch_src(w_ch_src_flat), .o_ch_dst(w_ch_dst_flat), .o_ch_len(w_ch_len_flat), .o_ch_desc_ptr(w_ch_desc_ptr_flat),
        .o_ch_ctrl_start(w_ch_ctrl_start), .o_ch_ctrl_desc_en(w_ch_ctrl_desc_en),
        .i_ch_status_busy(r_ch_busy), .i_ch_status_done(r_ch_done), .o_ch_soft_reset(w_ch_soft_reset)
    );

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : unpack_ch
            assign w_ch_src[i]      = w_ch_src_flat[i*32 +: 32];
            assign w_ch_dst[i]      = w_ch_dst_flat[i*32 +: 32];
            assign w_ch_len[i]      = w_ch_len_flat[i*32 +: 32];
            assign w_ch_desc_ptr[i] = w_ch_desc_ptr_flat[i*32 +: 32];
        end
    endgenerate

    reg [2:0]   r_ch_state [0:3];
    reg [31:0]  r_ch_curr_src [0:3];
    reg [31:0]  r_ch_curr_dst [0:3];
    reg [31:0]  r_ch_curr_len [0:3];
    reg [31:0]  r_ch_curr_desc [0:3];
    reg [127:0] r_ch_buf [0:3];
    
    localparam CH_IDLE      = 3'd0;
    localparam CH_FETCH     = 3'd1;
    localparam CH_READ      = 3'd2;
    localparam CH_WRITE     = 3'd3;
    localparam CH_DONE      = 3'd4;

    wire [3:0] w_ch_req;
    assign w_ch_req[0] = (r_ch_state[0] != CH_IDLE && r_ch_state[0] != CH_DONE);
    assign w_ch_req[1] = (r_ch_state[1] != CH_IDLE && r_ch_state[1] != CH_DONE);
    assign w_ch_req[2] = (r_ch_state[2] != CH_IDLE && r_ch_state[2] != CH_DONE);
    assign w_ch_req[3] = (r_ch_state[3] != CH_IDLE && r_ch_state[3] != CH_DONE);

    reg [1:0] r_active_ch;
    reg       r_master_busy;
    
    wire [1:0] w_best_ch = w_ch_req[3] ? 2'd3 :
                           w_ch_req[2] ? 2'd2 :
                           w_ch_req[1] ? 2'd1 : 2'd0;

    reg         r_m_req;
    reg [31:0]  r_m_addr;
    reg [7:0]   r_m_len;
    reg         r_m_is_write;
    wire        w_m_ack;
    wire [127:0] w_m_rdata;
    wire        w_m_burst_done;

    xdmac_axi_master u_master (
        .i_aclk(clk), .i_aresetn(resetn),
        .o_awaddr(awaddr), .o_awlen(awlen), .o_awsize(awsize), .o_awburst(awburst), .o_awvalid(awvalid), .i_awready(awready),
        .o_wdata(wdata), .o_wstrb(wstrb), .o_wlast(wlast), .o_wvalid(wvalid), .i_wready(wready),
        .i_bresp(bresp), .i_bvalid(bvalid), .o_bready(bready),
        .o_araddr(araddr), .o_arlen(arlen), .o_arsize(arsize), .o_arburst(arburst), .o_arvalid(arvalid), .i_arready(arready),
        .i_rdata(rdata), .i_rresp(rresp), .i_rlast(rlast), .i_rvalid(rvalid), .o_rready(rready),
        .i_m_req(r_m_req), .i_m_addr(r_m_addr), .i_m_len(r_m_len), .i_m_is_write(r_m_is_write),
        .o_m_ack(w_m_ack), .o_m_rdata(w_m_rdata), .i_m_wdata(r_ch_buf[r_active_ch]), .o_m_burst_done(w_m_burst_done)
    );

    integer c;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            r_active_ch <= 0; r_master_busy <= 0; r_m_req <= 0;
            for (c = 0; c < 4; c = c + 1) begin
                r_ch_state[c] <= CH_IDLE; r_ch_busy[c] <= 0; r_ch_done[c] <= 0;
            end
        end else begin
            // Channel Kickoff
            for (c = 0; c < 4; c = c + 1) begin
                if (r_ch_state[c] == CH_IDLE && (w_ch_ctrl_start[c] || i_hw_req[c])) begin
                    $display("[LOG %0t] [DMA_TOP] CH%0d Started (SW:%b HW:%b)", $time, c, w_ch_ctrl_start[c], i_hw_req[c]);
                    r_ch_busy[c] <= 1; r_ch_done[c] <= 0;
                    if (w_ch_ctrl_desc_en[c]) begin
                        $display("[LOG %0t] [DMA_TOP] CH%0d Scatter-Gather Mode Enabled. Fetching Descriptor at 0x%h", $time, c, w_ch_desc_ptr[c]);
                        r_ch_state[c] <= CH_FETCH; r_ch_curr_desc[c] <= w_ch_desc_ptr[c];
                    end else begin
                        $display("[LOG %0t] [DMA_TOP] CH%0d Direct Mode. SRC=0x%h, DST=0x%h, LEN=%0d", $time, c, w_ch_src[c], w_ch_dst[c], w_ch_len[c]);
                        r_ch_state[c] <= CH_READ;
                        r_ch_curr_src[c] <= w_ch_src[c]; r_ch_curr_dst[c] <= w_ch_dst[c]; r_ch_curr_len[c] <= w_ch_len[c];
                    end
                end
            end

            // Arbiter
            if (!r_master_busy) begin
                if (|w_ch_req) begin
                    r_active_ch <= w_best_ch; r_master_busy <= 1;
                    $display("[LOG %0t] [DMA_TOP] Arbiter: Granting Bus to CH%0d (State:%0d)", $time, w_best_ch, r_ch_state[w_best_ch]);
                    case (r_ch_state[w_best_ch])
                        CH_FETCH: begin r_m_req <= 1; r_m_addr <= r_ch_curr_desc[w_best_ch]; r_m_len <= 8'h0; r_m_is_write <= 0; end
                        CH_READ:  begin r_m_req <= 1; r_m_addr <= r_ch_curr_src[w_best_ch];  r_m_len <= 8'h0; r_m_is_write <= 0; end
                        CH_WRITE: begin r_m_req <= 1; r_m_addr <= r_ch_curr_dst[w_best_ch];  r_m_len <= 8'h0; r_m_is_write <= 1; end
                    endcase
                end
            end else begin
                if (r_m_req && w_m_ack) r_m_req <= 0;
                
                if (w_m_burst_done) begin
                    r_master_busy <= 0;
                    case (r_ch_state[r_active_ch])
                        CH_FETCH: begin
                            $display("[LOG %0t] [DMA_TOP] CH%0d Descriptor Loaded: SRC=0x%h, DST=0x%h, LEN=%0d", $time, r_active_ch, w_m_rdata[31:0], w_m_rdata[63:32], w_m_rdata[95:64]);
                            r_ch_state[r_active_ch] <= CH_READ;
                            r_ch_curr_src[r_active_ch] <= w_m_rdata[31:0];
                            r_ch_curr_dst[r_active_ch] <= w_m_rdata[63:32];
                            r_ch_curr_len[r_active_ch] <= w_m_rdata[95:64];
                        end
                        CH_READ:  begin 
                            $display("[LOG %0t] [DMA_TOP] CH%0d Data Read Done. Preparing Write to 0x%h", $time, r_active_ch, r_ch_curr_dst[r_active_ch]);
                            r_ch_buf[r_active_ch] <= w_m_rdata; 
                            r_ch_state[r_active_ch] <= CH_WRITE; 
                        end
                        CH_WRITE: begin
                            if (r_ch_curr_len[r_active_ch] <= 16) begin
                                $display("[LOG %0t] [DMA_TOP] CH%0d Transfer Fully Completed.", $time, r_active_ch);
                                r_ch_state[r_active_ch] <= CH_DONE;
                            end else begin
                                r_ch_curr_len[r_active_ch] <= r_ch_curr_len[r_active_ch] - 16;
                                r_ch_curr_src[r_active_ch] <= r_ch_curr_src[r_active_ch] + 16;
                                r_ch_curr_dst[r_active_ch] <= r_ch_curr_dst[r_active_ch] + 16;
                                r_ch_state[r_active_ch] <= CH_READ;
                            end
                        end
                    endcase
                end
            end

            // Cleanup Done
            for (c = 0; c < 4; c = c + 1) begin
                if (r_ch_state[c] == CH_DONE) begin
                    r_ch_busy[c] <= 0; r_ch_done[c] <= 1; r_ch_state[c] <= CH_IDLE;
                end
            end
        end
    end

endmodule
