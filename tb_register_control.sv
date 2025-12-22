`timescale 1ns / 1ps

module tb_registers_control;

parameter REGS_NUM  = 4;         // liczba rejestrow
parameter REG_WIDTH = 32;        // szerokosc rejestrow (w bitach)

localparam [7:0] ASCII_NBR_BASE = 8'h30;
localparam [7:0] ASCII_W_UPPER  = 8'h57;
localparam [7:0] ASCII_W_LOWER  = 8'h77;
localparam [7:0] ASCII_R_UPPER  = 8'h52;
localparam [7:0] ASCII_R_LOWER  = 8'h72;
localparam [7:0] ASCII_COLON    = 8'h3A;

logic i_clk;
logic i_rst;

logic [7:0] i_rx_udp_payload_axis_tdata;
logic       i_rx_udp_payload_axis_tvalid;
logic       i_rx_udp_payload_axis_tlast;
logic       o_rx_udp_payload_axis_tready;

logic [7:0] o_tx_udp_payload_axis_tdata;
logic       o_tx_udp_payload_axis_tvalid;
logic       o_tx_udp_payload_axis_tlast;
logic       i_tx_udp_payload_axis_tready;

logic [REG_WIDTH-1:0] o_reg_0;
logic [REG_WIDTH-1:0] o_reg_1;
logic [REG_WIDTH-1:0] o_reg_2;
logic [REG_WIDTH-1:0] o_reg_3;

int              CLK_PERIOD = 20;
localparam [7:0] REJESTR    = 8'd2;

registers_control #(
  .REGS_NUM    (REGS_NUM),                       // liczba rejestrow
  .REG_WIDTH   (REG_WIDTH),                      // szerokosc rejestrow (w bitach)
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
  .i_port_nbr                   (16'd1234),
  .i_ip_adr                     ({8'd192, 8'd168, 8'd1, 8'd128}),
  .o_reg_0                      (o_reg_0),
  .o_reg_1                      (o_reg_1),
  .o_reg_2                      (o_reg_2),
  .o_reg_3                      (o_reg_3)
);

initial begin
  i_rx_udp_payload_axis_tvalid = 0;
// zapis do rejestru
#100;
  // znak poczatku
  i_rx_udp_payload_axis_tdata  = ASCII_COLON;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  #CLK_PERIOD;
  // nr rejestru
  i_rx_udp_payload_axis_tdata  = ASCII_NBR_BASE + REJESTR;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  #CLK_PERIOD;
  // komenda
  i_rx_udp_payload_axis_tdata  = ASCII_W_LOWER;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  #CLK_PERIOD;
  // 1 dane
  i_rx_udp_payload_axis_tdata  = 8'hAB;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  #CLK_PERIOD;
  // 2 dane
  i_rx_udp_payload_axis_tdata  = 8'hCD;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  #CLK_PERIOD;
  // 3 dane
  i_rx_udp_payload_axis_tdata  = 8'h12;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  #CLK_PERIOD;
  // 4 dane
  i_rx_udp_payload_axis_tdata  = 8'h34;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 1;
  #CLK_PERIOD;
  i_rx_udp_payload_axis_tvalid = 0;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 0;
// koniec 1-wszej ramki

// czytanie zawartosci rejestru
  #100;
  // znak poczatku
  i_rx_udp_payload_axis_tdata  = ASCII_COLON;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  // nr rejestru
  i_rx_udp_payload_axis_tdata  = ASCII_NBR_BASE + REJESTR;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  // nr rejestru
  i_rx_udp_payload_axis_tdata  = ASCII_R_UPPER;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 1;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  i_rx_udp_payload_axis_tvalid = 0;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #(CLK_PERIOD*5);
  i_rx_udp_payload_axis_tvalid = 0;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 0;
  #CLK_PERIOD;
// koniec czytania

// echo - nieznana komenda
  #100;
  i_rx_udp_payload_axis_tdata  = ASCII_COLON+6;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  // 1 dane
  i_rx_udp_payload_axis_tdata  = 8'hFE;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  // 2 dane
  i_rx_udp_payload_axis_tdata  = 8'hDC;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  // 3 dane
  i_rx_udp_payload_axis_tdata  = 8'hBA;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  // 4 dane
  i_rx_udp_payload_axis_tdata  = 8'h98;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  // 5 dane
  i_rx_udp_payload_axis_tdata  = 8'h76;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  // 6 dane
  i_rx_udp_payload_axis_tdata  = 8'h54;
  i_rx_udp_payload_axis_tvalid = 1;
  i_rx_udp_payload_axis_tlast  = 0;
  i_tx_udp_payload_axis_tready = 1;
  #CLK_PERIOD;
  i_rx_udp_payload_axis_tvalid = 1;
  i_tx_udp_payload_axis_tready = 1;
  i_rx_udp_payload_axis_tlast  = 1;
  #CLK_PERIOD;
  i_rx_udp_payload_axis_tvalid = 0;
  i_tx_udp_payload_axis_tready = 0;
  i_rx_udp_payload_axis_tlast  = 0;
end

initial begin
  i_tx_udp_payload_axis_tready = 1;
end

initial begin
  i_clk = 1;
  while(1) #(CLK_PERIOD/2) i_clk = ~i_clk;
end

initial begin
  i_rst = 0;
  #CLK_PERIOD i_rst = 1;
  #CLK_PERIOD i_rst = 0;
end

endmodule // tb_registers_control