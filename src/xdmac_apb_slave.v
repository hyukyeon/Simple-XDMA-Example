module xdmac_apb_slave (
    input  wire        i_pclk,
    input  wire        i_presetn,
    input  wire [31:0] i_paddr,
    input  wire        i_psel,
    input  wire        i_penable,
    input  wire        i_pwrite,
    input  wire [31:0] i_pwdata,
    output reg  [31:0] o_prdata,
    output wire        o_pready,
    output wire        o_pslverr,

    // 4 Channels - Flattened ports for standard Verilog
    output wire [127:0] o_ch_src,
    output wire [127:0] o_ch_dst,
    output wire [127:0] o_ch_len,
    output wire [127:0] o_ch_desc_ptr,
    output wire [3:0]   o_ch_ctrl_start,
    output wire [3:0]   o_ch_ctrl_desc_en,
    input  wire [3:0]   i_ch_status_busy,
    input  wire [3:0]   i_ch_status_done,
    output wire [3:0]   o_ch_soft_reset
);

    assign o_pready  = 1'b1;
    assign o_pslverr = 1'b0;

    reg [31:0] r_src [0:3];
    reg [31:0] r_dst [0:3];
    reg [31:0] r_len [0:3];
    reg [31:0] r_desc_ptr [0:3];
    reg [3:0]  r_ctrl_start;
    reg [3:0]  r_ctrl_desc_en;
    reg [3:0]  r_ctrl_reset;

    assign o_ch_src      = {r_src[3], r_src[2], r_src[1], r_src[0]};
    assign o_ch_dst      = {r_dst[3], r_dst[2], r_dst[1], r_dst[0]};
    assign o_ch_len      = {r_len[3], r_len[2], r_len[1], r_len[0]};
    assign o_ch_desc_ptr = {r_desc_ptr[3], r_desc_ptr[2], r_desc_ptr[1], r_desc_ptr[0]};
    assign o_ch_ctrl_start = r_ctrl_start;
    assign o_ch_ctrl_desc_en = r_ctrl_desc_en;
    assign o_ch_soft_reset = r_ctrl_reset;

    wire [1:0] w_sel_ch = i_paddr[7:6];
    wire [5:0] w_reg_off = i_paddr[5:0];

    integer i;
    always @(posedge i_pclk or negedge i_presetn) begin
        if (!i_presetn) begin
            for (i = 0; i < 4; i = i + 1) begin
                r_src[i] <= 32'h0; r_dst[i] <= 32'h0; r_len[i] <= 32'h0; r_desc_ptr[i] <= 32'h0;
            end
            r_ctrl_start <= 4'h0; r_ctrl_desc_en <= 4'h0; r_ctrl_reset <= 4'h0;
        end else begin
            if (i_psel && i_penable && i_pwrite) begin
                case (w_reg_off)
                    6'h00: r_src[w_sel_ch]      <= i_pwdata;
                    6'h04: r_dst[w_sel_ch]      <= i_pwdata;
                    6'h08: r_len[w_sel_ch]      <= i_pwdata;
                    6'h0C: begin
                        r_ctrl_start[w_sel_ch]   <= i_pwdata[0];
                        r_ctrl_reset[w_sel_ch]   <= i_pwdata[1];
                        r_ctrl_desc_en[w_sel_ch] <= i_pwdata[2];
                    end
                    6'h10: r_desc_ptr[w_sel_ch] <= i_pwdata;
                    default: ;
                endcase
            end else begin
                r_ctrl_start <= r_ctrl_start & ~i_ch_status_busy;
            end
        end
    end

    always @(*) begin
        case (w_reg_off)
            6'h00: o_prdata = r_src[w_sel_ch];
            6'h04: o_prdata = r_dst[w_sel_ch];
            6'h08: o_prdata = r_len[w_sel_ch];
            6'h0C: o_prdata = {29'h0, r_ctrl_desc_en[w_sel_ch], r_ctrl_reset[w_sel_ch], r_ctrl_start[w_sel_ch]};
            6'h10: o_prdata = r_desc_ptr[w_sel_ch];
            6'h14: o_prdata = {30'h0, i_ch_status_done[w_sel_ch], i_ch_status_busy[w_sel_ch]};
            default: o_prdata = 32'h0;
        endcase
    end

endmodule
