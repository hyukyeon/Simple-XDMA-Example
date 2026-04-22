module axi_slave_mem #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 128,
    parameter STRB_WIDTH = DATA_WIDTH/8,
    parameter MEM_SIZE   = 4096, // 4KB (in 128-bit words)
    parameter LATENCY    = 1     // Default low latency
)(
    input  wire                   clk,
    input  wire                   resetn,

    // AXI AW
    input  wire [ADDR_WIDTH-1:0]  awaddr,
    input  wire [7:0]             awlen,
    input  wire [2:0]             awsize,
    input  wire [1:0]             awburst,
    input  wire                   awvalid,
    output reg                    awready,

    // AXI W
    input  wire [DATA_WIDTH-1:0]  wdata,
    input  wire [STRB_WIDTH-1:0]  wstrb,
    input  wire                   wlast,
    input  wire                   wvalid,
    output reg                    wready,

    // AXI B
    output reg  [1:0]             bresp,
    output reg                    bvalid,
    input  wire                   bready,

    // AXI AR
    input  wire [ADDR_WIDTH-1:0]  araddr,
    input  wire [7:0]             arlen,
    input  wire [2:0]             arsize,
    input  wire [1:0]             arburst,
    input  wire                   arvalid,
    output reg                    arready,

    // AXI R
    output reg  [DATA_WIDTH-1:0]  rdata,
    output reg  [1:0]             rresp,
    output reg                    rlast,
    output reg                    rvalid,
    input  wire                   rready
);

    reg [DATA_WIDTH-1:0] mem [0:MEM_SIZE-1];

    // Read Logic with Latency
    reg [ADDR_WIDTH-1:0] r_addr_latched;
    reg [7:0]            r_len_latched;
    reg [7:0]            r_cnt;
    reg [7:0]            r_lat_cnt;

    localparam R_IDLE = 2'd0, R_LAT  = 2'd1, R_DATA = 2'd2;
    reg [1:0] r_state;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            arready <= 1; rvalid <= 0; rlast <= 0; r_state <= R_IDLE;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (arvalid && arready) begin
                        arready <= 0;
                        r_addr_latched <= araddr;
                        r_len_latched  <= arlen;
                        r_cnt <= 0;
                        r_lat_cnt <= 0;
                        r_state <= R_LAT;
                    end
                end
                R_LAT: begin
                    if (r_lat_cnt >= LATENCY) begin
                        r_state <= R_DATA;
                        rvalid <= 1;
                        rdata <= mem[r_addr_latched[15:4]]; // Simplified addressing
                        rlast <= (r_len_latched == 0);
                    end else begin
                        r_lat_cnt <= r_lat_cnt + 1;
                    end
                end
                R_DATA: begin
                    if (rvalid && rready) begin
                        if (rlast) begin
                            rvalid <= 0;
                            arready <= 1;
                            r_state <= R_IDLE;
                        end else begin
                            r_cnt <= r_cnt + 1;
                            rdata <= mem[r_addr_latched[15:4] + r_cnt + 1];
                            rlast <= (r_cnt + 1 == r_len_latched);
                        end
                    end
                end
            endcase
        end
    end

    // Write Logic
    localparam W_IDLE = 2'd0, W_DATA = 2'd1, W_RESP = 2'd2;
    reg [1:0] w_state;
    reg [ADDR_WIDTH-1:0] w_addr_latched;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            awready <= 1; wready <= 0; bvalid <= 0; w_state <= W_IDLE;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (awvalid && awready) begin
                        awready <= 0;
                        wready <= 1;
                        w_addr_latched <= awaddr;
                        w_state <= W_DATA;
                    end
                end
                W_DATA: begin
                    if (wvalid && wready) begin
                        mem[w_addr_latched[15:4]] <= wdata; // Simplified write
                        if (wlast) begin
                            wready <= 0;
                            bvalid <= 1;
                            bresp <= 2'b00;
                            w_state <= W_RESP;
                        end
                    end
                end
                W_RESP: begin
                    if (bvalid && bready) begin
                        bvalid <= 0;
                        awready <= 1;
                        w_state <= W_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
