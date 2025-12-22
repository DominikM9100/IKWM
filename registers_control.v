`resetall
`timescale 1ns / 1ps
// `default_nettype none


module registers_control #(
  parameter        REGS_NUM    = 4,                              // liczba rejestrow
  parameter        REG_WIDTH   = 32,                             // szerokosc rejestrow (w bitach)
  parameter [31:0] IP_ADRESS   = {8'd192, 8'd168, 8'd1, 8'd128}, // adres IP komputera
  parameter [15:0] PORT_NUMBER = 16'd1234                        // numer portu
)(
  input  wire i_clk,
  input  wire i_rst,

  input  wire [7:0] i_rx_udp_payload_axis_tdata,
  input  wire       i_rx_udp_payload_axis_tvalid,
  input  wire       i_rx_udp_payload_axis_tlast,
  output  reg       o_rx_udp_payload_axis_tready,

  output  reg [7:0] o_tx_udp_payload_axis_tdata,
  output wire       o_tx_udp_payload_axis_tvalid,
  output wire       o_tx_udp_payload_axis_tlast,
  input  wire       i_tx_udp_payload_axis_tready,

  input  wire [15:0] i_port_nbr,
  input  wire [31:0] i_ip_adr,

  output wire [REG_WIDTH-1:0] o_reg_0,
  output wire [REG_WIDTH-1:0] o_reg_1,
  output wire [REG_WIDTH-1:0] o_reg_2,
  output wire [REG_WIDTH-1:0] o_reg_3
);


reg [REG_WIDTH-1:0] registers [0:REGS_NUM-1];

assign o_reg_0 = registers[0];
assign o_reg_1 = registers[1];
assign o_reg_2 = registers[2];
assign o_reg_3 = registers[3];

localparam [2:0] S_WAIT_COLON    = 3'd0;
localparam [2:0] S_PARSE_REG_NBR = 3'd1;
localparam [2:0] S_PARSE_CMD     = 3'd2;
localparam [2:0] S_WRITE_REG     = 3'd3;
localparam [2:0] S_WRITE_DONE    = 3'd4;
localparam [2:0] S_READ_REG      = 3'd5;

localparam [7:0] ASCII_NBR_BASE = 8'h30;
localparam [7:0] ASCII_W_UPPER  = 8'h57;
localparam [7:0] ASCII_W_LOWER  = 8'h77;
localparam [7:0] ASCII_R_UPPER  = 8'h52;
localparam [7:0] ASCII_R_LOWER  = 8'h72;
localparam [7:0] ASCII_COLON    = 8'h3A;

reg           [2:0] r_state;
reg           [2:0] r_reg_number;
reg [REG_WIDTH-1:0] r_write_data;
reg           [2:0] r_write_byte_cnt;
reg [REG_WIDTH-1:0] r_read_data;
reg           [2:0] r_read_byte_cnt;
reg                 r_tx_udp_payload_axis_tvalid;
reg                 r_tx_udp_payload_axis_tlast;

wire    en;
integer i;


assign en = (i_ip_adr==IP_ADRESS && i_port_nbr==PORT_NUMBER) ? 1'b1 : 1'b0;


always @(posedge i_clk)
begin: REGISTERS_CONTROL_FSM
  if (i_rst) begin
    for (i = 0; i < REGS_NUM; i = i + 1) begin
      registers[i]               <= 0;
    end
    r_state                      <= S_WAIT_COLON;
    r_write_byte_cnt             <= 0;
    r_read_byte_cnt              <= 0;
    r_reg_number                 <= 0;
    r_write_data                 <= 0;
    r_read_data                  <= 0;
    o_tx_udp_payload_axis_tdata  <= 0;
    r_tx_udp_payload_axis_tvalid <= 0;
    o_rx_udp_payload_axis_tready <= 0;

  end else if (en) begin
    case (r_state)
      S_WAIT_COLON: begin
        o_rx_udp_payload_axis_tready <= 1;
        if (i_rx_udp_payload_axis_tvalid &&
            !i_rx_udp_payload_axis_tlast &&
            i_rx_udp_payload_axis_tdata == ASCII_COLON
            ) begin // czy odebrany znak to ':'?
          r_state <= S_PARSE_REG_NBR;
        end
      end // S_WAIT_COLON

      S_PARSE_REG_NBR: begin
        if (i_rx_udp_payload_axis_tvalid) begin
          if (!i_rx_udp_payload_axis_tlast &&
              i_rx_udp_payload_axis_tdata >= ASCII_NBR_BASE &&
              i_rx_udp_payload_axis_tdata < (ASCII_NBR_BASE+REGS_NUM)
              ) begin // czy numer rejestru jest w zakresie?
            r_state      <= S_PARSE_CMD;
            r_reg_number <= i_rx_udp_payload_axis_tdata - ASCII_NBR_BASE;
          end else begin
            r_state      <= S_WAIT_COLON;
          end
        end
      end // S_PARSE_REG_NBR

      S_PARSE_CMD: begin
        if (i_rx_udp_payload_axis_tvalid) begin
          if (!i_rx_udp_payload_axis_tlast &&
              (i_rx_udp_payload_axis_tdata==ASCII_W_UPPER ||
              i_rx_udp_payload_axis_tdata==ASCII_W_LOWER)
              ) begin // czy modyfiakcja zawartosci rejestru?
            r_state                      <= S_WRITE_REG;
            r_write_byte_cnt             <= 0;
          end else if (i_rx_udp_payload_axis_tlast &&
                       (i_rx_udp_payload_axis_tdata == ASCII_R_UPPER ||
                       i_rx_udp_payload_axis_tdata == ASCII_R_LOWER)
                       ) begin // czy odczyt z rejestru?
            r_state                      <= S_READ_REG;
            // o_rx_udp_payload_axis_tready <= 0;
            r_read_byte_cnt              <= 0;
            r_read_data                  <= registers[r_reg_number];
          end else begin // czy komenda nieznana?
            r_state                      <=  S_WAIT_COLON;
          end
        end
      end // S_PARSE_CMD

      S_WRITE_REG: begin
        if (i_rx_udp_payload_axis_tvalid) begin
          r_write_data         <= (r_write_data << 8) | i_rx_udp_payload_axis_tdata;
          if (r_write_byte_cnt < (REG_WIDTH/8)-1) begin // czy wysylac?
            if (!i_rx_udp_payload_axis_tlast) begin // czy wysylane sa dane 32-bitowe?
              r_write_byte_cnt <= r_write_byte_cnt + 1;
            end else begin // czy przeslano mniej niz 32 bity?
              r_write_byte_cnt <= 0;
              r_state          <= S_WAIT_COLON;
            end
          end else begin // czy wyslano wszystko?
            if (i_rx_udp_payload_axis_tlast) begin // czy otrzymano sygnal konca wiadomosci?
              // registers[r_reg_number] <= r_write_data;
              r_state                 <= S_WRITE_DONE;
            end
          end
        end
      end // S_WRITE_REG

      S_WRITE_DONE: begin
          r_write_byte_cnt        <= 0;
          registers[r_reg_number] <= r_write_data;
          r_state                 <= S_WAIT_COLON;
      end // S_WRITE_DONE

      S_READ_REG: begin
        r_tx_udp_payload_axis_tvalid <= 1;
        o_rx_udp_payload_axis_tready <= 0;
        if (i_tx_udp_payload_axis_tready) begin
          if (r_read_byte_cnt < (REG_WIDTH/8)-1) begin // czy nie wyslano wszystkiego?
            case (r_read_byte_cnt)
              0: o_tx_udp_payload_axis_tdata <= r_read_data[31:24];
              1: o_tx_udp_payload_axis_tdata <= r_read_data[23:16];
              2: o_tx_udp_payload_axis_tdata <= r_read_data[15: 8];
              3: o_tx_udp_payload_axis_tdata <= r_read_data[ 7: 0];
            endcase // r_read_byte_cnt
            r_read_byte_cnt              <= r_read_byte_cnt + 1;
          end else begin // czy wyslano cala zawartosc?
            o_tx_udp_payload_axis_tdata <= r_read_data[ 7: 0];
            r_read_byte_cnt              <= 0;
            r_state                      <= S_WAIT_COLON;
            r_tx_udp_payload_axis_tvalid <= 0;
            o_rx_udp_payload_axis_tready <= 1;
          end
        end
      end // S_READ_REG

    endcase // state_reg
  end
end // REGISTERS_CONTROL_FSM


always @(posedge i_clk)
begin: REG_O_TX_TLAST
  if (r_read_byte_cnt == (REG_WIDTH/8)-1) begin
    r_tx_udp_payload_axis_tlast <= 1;
  end else begin
    r_tx_udp_payload_axis_tlast <= 0;
  end
end // REG_O_TX_TLAST


assign o_tx_udp_payload_axis_tlast = r_tx_udp_payload_axis_tlast;
assign o_tx_udp_payload_axis_tvalid = r_tx_udp_payload_axis_tvalid || r_tx_udp_payload_axis_tlast;


endmodule // registers_control