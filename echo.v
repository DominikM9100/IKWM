`resetall
`timescale 1ns / 1ps
`default_nettype none

module echo # (
    parameter TARGET = "GENERIC"
)(
    input  wire        clk,
    input  wire        rst,
    output wire  [8:0] ledg,

    input  wire        i_rx_udp_payload_axis_tvalid,
    output wire        o_rx_udp_payload_axis_tready,
    input  wire        i_rx_udp_payload_axis_tlast,
    input  wire        i_rx_udp_payload_axis_tuser,
    input  wire  [7:0] i_rx_udp_payload_axis_tdata,

    output wire        o_tx_udp_payload_axis_tvalid,
    input  wire        i_tx_udp_payload_axis_tready,
    output wire        o_tx_udp_payload_axis_tlast,
    output wire        o_tx_udp_payload_axis_tuser,
    output wire  [7:0] o_tx_udp_payload_axis_tdata
);

wire  [7:0] tx_fifo_udp_payload_axis_tdata;
wire        tx_fifo_udp_payload_axis_tvalid;
wire        tx_fifo_udp_payload_axis_tready;
wire        tx_fifo_udp_payload_axis_tlast;
wire        tx_fifo_udp_payload_axis_tuser;

wire  [7:0] rx_fifo_udp_payload_axis_tdata;
wire        rx_fifo_udp_payload_axis_tvalid;
wire        rx_fifo_udp_payload_axis_tready;
wire        rx_fifo_udp_payload_axis_tlast;
wire         rx_fifo_udp_payload_axis_tuser;

// UDP frame connections
wire        rx_udp_payload_axis_tvalid;
wire        rx_udp_payload_axis_tready;
wire        rx_udp_payload_axis_tlast;
wire        rx_udp_payload_axis_tuser;
wire  [7:0] rx_udp_payload_axis_tdata;

wire        tx_udp_payload_axis_tvalid;
wire        tx_udp_payload_axis_tready;
wire        tx_udp_payload_axis_tlast;
wire        tx_udp_payload_axis_tuser;
wire  [7:0] tx_udp_payload_axis_tdata;

wire        tx_eth_hdr_ready = 1'b1;
wire        rx_udp_hdr_valid = 1'b1;
wire        rx_udp_hdr_ready = 1'b1;
wire [15:0] rx_udp_dest_port = 1234;

wire tx_udp_hdr_valid;
wire [31:0] tx_udp_ip_dest_ip = {8'd10, 8'd2, 8'd160, 8'd101};

// Loop back UDP
wire match_cond = rx_udp_dest_port == 1234;
wire no_match = !match_cond;

reg match_cond_reg = 0;
reg no_match_reg = 0;

always @(posedge clk) begin
  if (rst) begin
    match_cond_reg <= 0;
    no_match_reg <= 0;
  end else begin
    if (rx_udp_payload_axis_tvalid) begin
      if ((!match_cond_reg && !no_match_reg) ||
          (rx_udp_payload_axis_tvalid && rx_udp_payload_axis_tready && rx_udp_payload_axis_tlast)) begin
        match_cond_reg <= match_cond;
        no_match_reg <= no_match;
      end
    end else begin
      match_cond_reg <= 0;
      no_match_reg <= 0;
    end
  end 
end

assign rx_udp_payload_axis_tvalid   = i_rx_udp_payload_axis_tvalid;
assign o_rx_udp_payload_axis_tready = rx_udp_payload_axis_tready;
assign rx_udp_payload_axis_tlast    = i_rx_udp_payload_axis_tlast;
assign rx_udp_payload_axis_tuser    = i_rx_udp_payload_axis_tuser;
assign rx_udp_payload_axis_tdata    = i_rx_udp_payload_axis_tdata;

assign o_tx_udp_payload_axis_tvalid = tx_udp_payload_axis_tvalid;
assign tx_udp_payload_axis_tready   = i_tx_udp_payload_axis_tready;
assign o_tx_udp_payload_axis_tlast  = tx_udp_payload_axis_tlast;
assign o_tx_udp_payload_axis_tuser  = tx_udp_payload_axis_tuser;
assign o_tx_udp_payload_axis_tdata  = tx_udp_payload_axis_tdata;

assign tx_udp_hdr_valid = rx_udp_hdr_valid && match_cond;
assign rx_udp_hdr_ready = (tx_eth_hdr_ready && match_cond) || no_match;

assign tx_udp_payload_axis_tdata = tx_fifo_udp_payload_axis_tdata;
assign tx_udp_payload_axis_tvalid = tx_fifo_udp_payload_axis_tvalid;
assign tx_fifo_udp_payload_axis_tready = tx_udp_payload_axis_tready;
assign tx_udp_payload_axis_tlast = tx_fifo_udp_payload_axis_tlast;
assign tx_udp_payload_axis_tuser = tx_fifo_udp_payload_axis_tuser;

assign rx_fifo_udp_payload_axis_tdata = rx_udp_payload_axis_tdata;
assign rx_fifo_udp_payload_axis_tvalid = rx_udp_payload_axis_tvalid && match_cond_reg;
assign rx_udp_payload_axis_tready = (rx_fifo_udp_payload_axis_tready && match_cond_reg) || no_match_reg;
assign rx_fifo_udp_payload_axis_tlast = rx_udp_payload_axis_tlast;
assign rx_fifo_udp_payload_axis_tuser = rx_udp_payload_axis_tuser;

// Place first payload byte onto LEDs
reg valid_last = 0;
reg [7:0] led_reg = 0;

always @(posedge clk) begin
  if (tx_udp_payload_axis_tvalid) begin
    if (!valid_last) begin
      led_reg <= tx_fifo_udp_payload_axis_tdata;
      valid_last <= 1'b1;
    end
    if (tx_udp_payload_axis_tlast) begin
      valid_last <= 1'b0;
    end
  end

  if (rst) begin
    led_reg <= 0;
  end
end

// place dest IP onto 7 segment displays
reg [31:0] dest_ip_reg = 0;

always @(posedge clk) begin
    if (tx_udp_hdr_valid) begin
        dest_ip_reg <= tx_udp_ip_dest_ip;
    end

    if (rst) begin
        dest_ip_reg <= 0;
    end
end

assign ledg = led_reg;


axis_fifo #(
    .DEPTH(8192),
    .DATA_WIDTH(8),
    .KEEP_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .FRAME_FIFO(0)
)
udp_payload_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(rx_fifo_udp_payload_axis_tdata),
    .s_axis_tkeep(0),
    .s_axis_tvalid(rx_fifo_udp_payload_axis_tvalid),
    .s_axis_tready(rx_fifo_udp_payload_axis_tready),
    .s_axis_tlast(rx_fifo_udp_payload_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(rx_fifo_udp_payload_axis_tuser),

    // AXI output
    .m_axis_tdata(tx_fifo_udp_payload_axis_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(tx_fifo_udp_payload_axis_tvalid),
    .m_axis_tready(tx_fifo_udp_payload_axis_tready),
    .m_axis_tlast(tx_fifo_udp_payload_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(tx_fifo_udp_payload_axis_tuser),

    // Status
    .status_overflow(),
    .status_bad_frame(),
    .status_good_frame()
);



endmodule

`resetall