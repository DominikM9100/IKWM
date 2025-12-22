`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA core logic
 */
module fpga_core #
(
  parameter        NUM_REGS    = 4,                              // liczba rejestrow
  parameter        REG_WIDTH   = 32,                             // szerokosc rejestrow (w bitach)
  parameter [31:0] IP_ADRESS   = {8'd192, 8'd168, 8'd1, 8'd128}, // adres IP komputera
  parameter [15:0] PORT_NUMBER = 16'd1234                        // numer portu
)
(
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
    output wire  [7:0] o_tx_udp_payload_axis_tdata,


  input  wire [15:0] i_port_nbr,
  input  wire [31:0] i_ip_adr,
);


wire [7:0] rx_udp_payload_axis_tdata;
wire rx_udp_payload_axis_tvalid;
wire rx_udp_payload_axis_tready;
wire rx_udp_payload_axis_tlast;
wire rx_udp_payload_axis_tuser;

wire [7:0] tx_udp_payload_axis_tdata;
wire tx_udp_payload_axis_tvalid;
wire tx_udp_payload_axis_tready;
wire tx_udp_payload_axis_tlast;
wire tx_udp_payload_axis_tuser;

wire [7:0] rx_fifo_udp_payload_axis_tdata;
wire rx_fifo_udp_payload_axis_tvalid;
wire rx_fifo_udp_payload_axis_tready;
wire rx_fifo_udp_payload_axis_tlast;
wire rx_fifo_udp_payload_axis_tuser;

wire [7:0] tx_fifo_udp_payload_axis_tdata;
wire tx_fifo_udp_payload_axis_tvalid;
wire tx_fifo_udp_payload_axis_tready;
wire tx_fifo_udp_payload_axis_tlast;
wire tx_fifo_udp_payload_axis_tuser;

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


reg_ctrl #(
  .NUM_REGS    (4),                       // liczba rejestrow
  .REG_WIDTH   (32),                      // szerokosc rejestrow (w bitach)
  .IP_ADRESS   ({8'd192, 8'd168, 8'd1, 8'd128}), // adres IP komputera
  .PORT_NUMBER (16'd1234)                        // numer portu
) uut (
  .i_clk                        (i_clk),
  .i_rst                        (i_rst),
  .i_rx_udp_payload_axis_tdata  (i_rx_udp_payload_axis_tdata),
  .i_rx_udp_payload_axis_tvalid (i_rx_udp_payload_axis_tvalid),
  .i_rx_udp_payload_axis_tlast  (i_rx_udp_payload_axis_tlast),
  .o_rx_udp_payload_axis_tready (o_rx_udp_payload_axis_tready),
  .o_tx_udp_payload_axis_tdata  (o_tx_udp_payload_axis_tdata),
  .o_tx_udp_payload_axis_tvalid (o_tx_udp_payload_axis_tvalid),
  .o_tx_udp_payload_axis_tlast  (o_tx_udp_payload_axis_tlast),
  .i_tx_udp_payload_axis_tready (i_tx_udp_payload_axis_tready),
  .i_port_nbr                   (i_port_nbr),
  .i_ip_adr                     (i_ip_adr),
  .o_reg_0                      (o_reg_0),
  .o_reg_1                      (o_reg_1),
  .o_reg_2                      (o_reg_2),
  .o_reg_3                      (o_reg_3)
);


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