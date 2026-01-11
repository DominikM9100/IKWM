`resetall
`timescale 1ns / 1ps

module nowy #(
  parameter        REGS_NUM    = 4,
  parameter        REG_WIDTH   = 32,
  parameter [31:0] IP_ADRESS   = {8'd192, 8'd168, 8'd1, 8'd128},
  parameter [15:0] PORT_NUMBER = 16'd1234
)(
  input  wire i_clk,
  input  wire i_rst,

  input  wire [7:0] i_rx_udp_payload_axis_tdata,
  input  wire       i_rx_udp_payload_axis_tvalid,
  input  wire       i_rx_udp_payload_axis_tlast,
  output wire       o_rx_udp_payload_axis_tready,

  output wire [7:0] o_tx_udp_payload_axis_tdata,
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

// ========== REJESTRY ==========
reg [REG_WIDTH-1:0] registers [0:REGS_NUM-1];

assign o_reg_0 = registers[0];
assign o_reg_1 = registers[1];
assign o_reg_2 = registers[2];
assign o_reg_3 = registers[3];

// ========== STANY ==========
localparam [2:0] S_IDLE          = 3'd0;
localparam [2:0] S_WAIT_COLON    = 3'd1;
localparam [2:0] S_PARSE_REG_NBR = 3'd2;
localparam [2:0] S_PARSE_CMD     = 3'd3;
localparam [2:0] S_WRITE_REG     = 3'd4;
localparam [2:0] S_READ_REG      = 3'd5;

// ========== STAŁE ASCII ==========
localparam [7:0] ASCII_0        = 8'h30;  // '0'
localparam [7:0] ASCII_3        = 8'h33;  // '3'
localparam [7:0] ASCII_W_UPPER  = 8'h57;  // 'W'
localparam [7:0] ASCII_W_LOWER  = 8'h77;  // 'w'
localparam [7:0] ASCII_R_UPPER  = 8'h52;  // 'R'
localparam [7:0] ASCII_R_LOWER  = 8'h72;  // 'r'
localparam [7:0] ASCII_COLON    = 8'h3A;  // ':'

// ========== REJESTRY STERUJĄCE ==========
reg           [2:0] r_state, next_state;
reg           [1:0] r_reg_number, next_reg_number;
reg [REG_WIDTH-1:0] r_write_data, next_write_data;
reg           [1:0] r_write_byte_cnt, next_write_byte_cnt;
reg [REG_WIDTH-1:0] r_read_data, next_read_data;
reg           [1:0] r_send_byte_cnt, next_send_byte_cnt;
reg                 r_send_active, next_send_active;
reg                 r_write_en, next_write_en;

// ========== REJESTRY WYJŚCIOWE TX ==========
reg [7:0] r_tx_data;
reg       r_tx_last;
reg       r_tx_valid;

// ========== FLAGA EN ==========
wire en;
assign en = (i_ip_adr == IP_ADRESS && i_port_nbr == PORT_NUMBER);

// ========== INICJALIZACJA REJESTRÓW ==========
integer i;
always @(posedge i_clk) begin
  if (i_rst) begin
    for (i = 0; i < REGS_NUM; i = i + 1) begin
      registers[i] <= 0;
    end
  end
end

// ========== FSM - REJESTRY ==========
always @(posedge i_clk) begin
  if (i_rst) begin
    r_state          <= S_IDLE;
    r_reg_number     <= 0;
    r_write_data     <= 0;
    r_write_byte_cnt <= 0;
    r_read_data      <= 0;
    r_send_byte_cnt  <= 0;
    r_send_active    <= 0;
    r_write_en       <= 0;
    r_tx_data        <= 0;
    r_tx_last        <= 0;
    r_tx_valid       <= 0;
  end else if (en) begin
    r_state          <= next_state;
    r_reg_number     <= next_reg_number;
    r_write_data     <= next_write_data;
    r_write_byte_cnt <= next_write_byte_cnt;
    r_read_data      <= next_read_data;
    r_send_byte_cnt  <= next_send_byte_cnt;
    r_send_active    <= next_send_active;
    r_write_en       <= next_write_en;
  end else begin
    // Jeśli nie en, resetuj stany
    r_state          <= S_IDLE;
    r_write_en       <= 0;
  end
end

// ========== FSM - LOGIKA KOMBINACYJNA ==========
always @(*) begin
  next_state          = r_state;
  next_reg_number     = r_reg_number;
  next_write_data     = r_write_data;
  next_write_byte_cnt = r_write_byte_cnt;
  next_read_data      = r_read_data;
  next_send_byte_cnt  = r_send_byte_cnt;
  next_send_active    = r_send_active;
  next_write_en       = r_write_en;
  
  if (!en) begin
    next_state    = S_IDLE;
    next_write_en = 0;
  end else begin
    case (r_state)
      S_IDLE: begin
        next_state          = S_WAIT_COLON;
        next_write_byte_cnt = 0;
        next_write_data     = 0;
        next_write_en       = 0;
      end
      
      S_WAIT_COLON: begin
        if (i_rx_udp_payload_axis_tvalid) begin
          if (i_rx_udp_payload_axis_tdata == ASCII_COLON) begin
            next_state = S_PARSE_REG_NBR;
          end
        end
      end
      
      S_PARSE_REG_NBR: begin
        if (i_rx_udp_payload_axis_tvalid) begin
          if (i_rx_udp_payload_axis_tdata >= ASCII_0 && 
              i_rx_udp_payload_axis_tdata <= ASCII_3
          ) begin
            next_state      = S_PARSE_CMD;
            next_reg_number = i_rx_udp_payload_axis_tdata - ASCII_0; // '0'->0, '1'->1, '2'->2, '3'->3
          end else begin
            next_state      = S_IDLE;
          end
        end
      end
      
      S_PARSE_CMD: begin
        if (i_rx_udp_payload_axis_tvalid) begin
          if (i_rx_udp_payload_axis_tdata == ASCII_W_UPPER || 
              i_rx_udp_payload_axis_tdata == ASCII_W_LOWER
          ) begin
            next_state          = S_WRITE_REG;
            next_write_data     = 0;
            next_write_byte_cnt = 0;
            next_write_en       = 0;
          end else if (i_rx_udp_payload_axis_tdata == ASCII_R_UPPER || 
                       i_rx_udp_payload_axis_tdata == ASCII_R_LOWER
          ) begin
            next_state          = S_READ_REG;
            next_read_data      = registers[r_reg_number];
            next_send_byte_cnt  = 0;
            next_send_active    = 1'b1;
          end else begin
            next_state          = S_IDLE;
          end
        end
      end
      
      S_WRITE_REG: begin
        if (i_rx_udp_payload_axis_tvalid) begin
          next_write_data     = {r_write_data[23:0], i_rx_udp_payload_axis_tdata};
          next_write_byte_cnt = r_write_byte_cnt + 1;
          
          // Sprawdź czy zebrano 4 bajty
          if (r_write_byte_cnt == 3) begin
            next_write_en     = 1'b1;
            next_state        = S_IDLE;
          end
          
          // Jeśli koniec pakietu przed zebraniem 4 bajtów
          if (i_rx_udp_payload_axis_tlast) begin
            if (r_write_byte_cnt < 3) begin
              next_state = S_IDLE;
            end
          end
        end
      end
      
      S_READ_REG: begin
        if (r_send_active) begin
          if (i_tx_udp_payload_axis_tready) begin
            if (r_send_byte_cnt < 3) begin
              next_send_byte_cnt = r_send_byte_cnt + 1;
            end else begin
              next_send_active   = 1'b0;
              next_state         = S_IDLE;
            end
          end
        end
      end
      
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end
end

// ========== ZAPIS DO REJESTRU ==========
always @(posedge i_clk) begin
  if (en) begin
    // Wykonaj zapis jeśli flaga zapisu jest ustawiona
    if (r_write_en) begin
      registers[r_reg_number] <= r_write_data;
    end
  end
end

// ========== WYSYŁANIE ODPOWIEDZI ==========
always @(posedge i_clk) begin
  if (i_rst) begin
    r_tx_data  <= 0;
    r_tx_last  <= 0;
    r_tx_valid <= 0;
  end else if (en) begin
    if (r_state == S_READ_REG && r_send_active) begin
      if (i_tx_udp_payload_axis_tready) begin
        r_tx_valid <= 1'b1;
        case (r_send_byte_cnt)
          2'd0: r_tx_data <= r_read_data[31:24];
          2'd1: r_tx_data <= r_read_data[23:16];
          2'd2: r_tx_data <= r_read_data[15:8];
          2'd3: begin
            r_tx_data <= r_read_data[7:0];
            r_tx_last <= 1'b1;
          end
        endcase
      end
    end else begin
      r_tx_valid <= 1'b0;
      r_tx_last  <= 1'b0;
    end
  end else begin
    r_tx_valid <= 1'b0;
    r_tx_last  <= 1'b0;
  end
end

// ========== PRZYPISANIA WYJŚĆ ==========
assign o_rx_udp_payload_axis_tready = (r_state == S_WAIT_COLON) || 
                                      (r_state == S_PARSE_REG_NBR) || 
                                      (r_state == S_PARSE_CMD) || 
                                      (r_state == S_WRITE_REG);

assign o_tx_udp_payload_axis_tvalid = r_tx_valid;
assign o_tx_udp_payload_axis_tdata  = r_tx_data;
assign o_tx_udp_payload_axis_tlast  = r_tx_last;

endmodule