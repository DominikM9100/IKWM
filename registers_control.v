module REG_CTRL #(
    parameter REGS_NUM  = 4, // liczba rejestrow
    parameter REG_WIDTH = 32 // szerokosc rejestrow (w bitach)
)(
    input  wire                   i_clk,
    input  wire                   i_rst,
    input  wire [7:0]             i_rx_udp_payload_axis_tdata,
    input  wire                   i_rx_udp_payload_axis_tvalid,
    input  wire                   i_rx_udp_payload_axis_tlast,
    output wire                   o_rx_udp_payload_axis_tready,
    
    output reg  [7:0]             o_tx_udp_payload_axis_tdata,
    output reg                    o_tx_udp_payload_axis_tvalid,
    output reg                    o_tx_udp_payload_axis_tlast,
    input  wire                   i_tx_udp_payload_axis_tready,
    
    output wire [REG_WIDTH-1:0]   o_reg_0,
    output wire [REG_WIDTH-1:0]   o_reg_1,
    output wire [REG_WIDTH-1:0]   o_reg_2,
    output wire [REG_WIDTH-1:0]   o_reg_3
);

    // Parametry FSM
    localparam [2:0] S_WAIT_COLON    = 3'd0;
    localparam [2:0] S_PARSE_REG_NBR = 3'd1;
    localparam [2:0] S_PARSE_CMD     = 3'd2;
    localparam [2:0] S_WRITE_REG     = 3'd3;
    localparam [2:0] S_WRITE_DONE    = 3'd4;
    localparam [2:0] S_READ_REG      = 3'd5;

    // Kody ASCII
    localparam [7:0] ASCII_NBR_BASE = 8'h30;
    localparam [7:0] ASCII_W_UPPER  = 8'h57;
    localparam [7:0] ASCII_W_LOWER  = 8'h77;
    localparam [7:0] ASCII_R_UPPER  = 8'h52;
    localparam [7:0] ASCII_R_LOWER  = 8'h72;
    localparam [7:0] ASCII_COLON    = 8'h3A;

    // Rejestry wewnętrzne
    reg [REG_WIDTH-1:0] registers [0:REGS_NUM-1];
    reg [2:0]           state;
    reg [1:0]           reg_idx;       // Indeks wybranego rejestru
    reg [3:0]           byte_cnt;      // Licznik bajtów danych
    reg [REG_WIDTH-1:0] write_shifter; // Rejestr przesuwny dla zapisu

    // Przypisanie wyjść rejestrów
    assign o_reg_0 = registers[0];
    assign o_reg_1 = registers[1];
    assign o_reg_2 = registers[2];
    assign o_reg_3 = registers[3];

    // Funkcja pomocnicza: ASCII Hex -> 4-bit Value
    function [3:0] ascii2hex;
        input [7:0] ascii;
        begin
            if (ascii >= 8'h30 && ascii <= 8'h39)      // 0-9
                ascii2hex = ascii - 8'h30;
            else if (ascii >= 8'h41 && ascii <= 8'h46) // A-F
                ascii2hex = ascii - 8'h37;
            else if (ascii >= 8'h61 && ascii <= 8'h66) // a-f
                ascii2hex = ascii - 8'h57;
            else
                ascii2hex = 4'h0;
        end
    endfunction

    // Funkcja pomocnicza: 4-bit Value -> ASCII Hex
    function [7:0] hex2ascii;
        input [3:0] hex;
        begin
            if (hex <= 4'h9)
                hex2ascii = hex + 8'h30;
            else
                hex2ascii = hex + 8'h37; // A-F
        end
    endfunction

    // Logika wyboru rejestru do odczytu
    wire [REG_WIDTH-1:0] read_val = registers[reg_idx];
    // Wyciągnięcie odpowiedniej "czwórki" bitów (nibble) do konwersji na ASCII
    // Dla licznika 0 -> bity [31:28], dla licznika 7 -> bity [3:0]
    wire [3:0] current_read_nibble = read_val[(7-byte_cnt)*4 +: 4];

    // --- Maszyna stanów i logika sterująca ---
    
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= S_WAIT_COLON;
            byte_cnt <= 0;
            reg_idx <= 0;
            write_shifter <= 0;
            // Reset rejestrów
            registers[0] <= 0;
            registers[1] <= 0;
            registers[2] <= 0;
            registers[3] <= 0;
        end else begin
            case (state)
                S_WAIT_COLON: begin
                    // Oczekujemy na dwukropek
                    if (i_rx_udp_payload_axis_tvalid && i_tx_udp_payload_axis_tready) begin
                        if (i_rx_udp_payload_axis_tdata == ASCII_COLON)
                            state <= S_PARSE_REG_NBR;
                    end
                end

                S_PARSE_REG_NBR: begin
                    // Pobieramy numer rejestru (0-3)
                    if (i_rx_udp_payload_axis_tvalid && i_tx_udp_payload_axis_tready) begin
                        reg_idx <= i_rx_udp_payload_axis_tdata[1:0]; // Prosta konwersja z ASCII '0'-'3'
                        state <= S_PARSE_CMD;
                    end
                end

                S_PARSE_CMD: begin
                    // Sprawdzamy komendę 'w'/'W' lub 'r'/'R'
                    if (i_rx_udp_payload_axis_tvalid && i_tx_udp_payload_axis_tready) begin
                        if (i_rx_udp_payload_axis_tdata == ASCII_W_UPPER || i_rx_udp_payload_axis_tdata == ASCII_W_LOWER) begin
                            state <= S_WRITE_REG;
                            byte_cnt <= 0;
                        end else if (i_rx_udp_payload_axis_tdata == ASCII_R_UPPER || i_rx_udp_payload_axis_tdata == ASCII_R_LOWER) begin
                            state <= S_READ_REG;
                            byte_cnt <= 0;
                        end else begin
                            // Błędna komenda - powrót do szukania dwukropka
                            state <= S_WAIT_COLON;
                        end
                    end
                end

                S_WRITE_REG: begin
                    // Pobieramy 8 znaków hex (32 bity)
                    if (i_rx_udp_payload_axis_tvalid && i_tx_udp_payload_axis_tready) begin
                        // Wsuwamy nowy nibble na pozycję LSB
                        write_shifter <= {write_shifter[REG_WIDTH-5:0], ascii2hex(i_rx_udp_payload_axis_tdata)};
                        
                        if (byte_cnt == 7) begin
                            state <= S_WRITE_DONE;
                            // Aktualizacja rejestru dopiero po odebraniu całości
                            registers[reg_idx] <= {write_shifter[REG_WIDTH-5:0], ascii2hex(i_rx_udp_payload_axis_tdata)};
                        end else begin
                            byte_cnt <= byte_cnt + 1;
                        end
                    end
                end

                S_READ_REG: begin
                    // Wysyłamy 8 bajtów (ASCII Hex) reprezentujących wartość rejestru
                    // W tym stanie ignorujemy wejście (RX), generujemy tylko wyjście (TX)
                    if (i_tx_udp_payload_axis_tready) begin
                        if (byte_cnt == 7) begin
                            state <= S_WRITE_DONE; 
                        end else begin
                            byte_cnt <= byte_cnt + 1;
                        end
                    end
                end

                S_WRITE_DONE: begin
                    // Stan końcowy - można tu czekać na tlast pakietu lub wrócić do początku
                    if (i_rx_udp_payload_axis_tvalid && i_tx_udp_payload_axis_tready) begin
                       if (i_rx_udp_payload_axis_tlast)
                           state <= S_WAIT_COLON;
                       else if (i_rx_udp_payload_axis_tdata == ASCII_COLON)
                           state <= S_PARSE_REG_NBR; // Obsługa wielu komend w jednym pakiecie
                    end
                end
            endcase
            
            // Bezwarunkowy powrót do stanu początkowego na końcu pakietu
            if (i_rx_udp_payload_axis_tvalid && i_rx_udp_payload_axis_tlast && i_tx_udp_payload_axis_tready) begin
                state <= S_WAIT_COLON;
            end
        end
    end

    // --- Logika wyjść AXI Stream (Data Path) ---

    // Ready do wejścia:
    // W stanie S_READ_REG my generujemy dane, więc nie odbieramy nowych z RX (backpressure).
    // W pozostałych stanach przepuszczamy ready z FIFO (TX) do RX.
    assign o_rx_udp_payload_axis_tready = (state == S_READ_REG) ? 1'b0 : i_tx_udp_payload_axis_tready;

    // Logika wyjścia TDATA/TVALID/TLAST (Kombinacyjna lub rejestrowa)
    always @(*) begin
        if (state == S_READ_REG) begin
            // Generowanie odpowiedzi (Odczyt)
            o_tx_udp_payload_axis_tdata  = hex2ascii(current_read_nibble);
            o_tx_udp_payload_axis_tvalid = 1'b1;
            // Jeśli to ostatni bajt odpowiedzi i jednocześnie przyszło tlast z wejścia (opcjonalnie)
            // Tutaj upraszczamy: w trybie READ wstawiamy dane w środek strumienia.
            o_tx_udp_payload_axis_tlast  = (byte_cnt == 7) ? i_rx_udp_payload_axis_tlast : 1'b0; 
        end else begin
            // Echo (Passthrough) dla zapisu i innych stanów
            o_tx_udp_payload_axis_tdata  = i_rx_udp_payload_axis_tdata;
            o_tx_udp_payload_axis_tvalid = i_rx_udp_payload_axis_tvalid;
            o_tx_udp_payload_axis_tlast  = i_rx_udp_payload_axis_tlast;
        end
    end

endmodule







// `resetall
// `timescale 1ns / 1ps
// // `default_nettype none


// module registers_control #(
//   parameter        REGS_NUM    = 4,                              // liczba rejestrow
//   parameter        REG_WIDTH   = 32,                             // szerokosc rejestrow (w bitach)
//   parameter [31:0] IP_ADRESS   = {8'd192, 8'd168, 8'd1, 8'd128}, // adres IP komputera
//   parameter [15:0] PORT_NUMBER = 16'd1234                        // numer portu
// )(
//   input  wire                 i_clk,
//   input  wire                 i_rst,
//   input  wire           [7:0] i_rx_udp_payload_axis_tdata,
//   input  wire                 i_rx_udp_payload_axis_tvalid,
//   input  wire                 i_rx_udp_payload_axis_tlast,
//   output  reg                 o_rx_udp_payload_axis_tready,
//   output  reg           [7:0] o_tx_udp_payload_axis_tdata,
//   output wire                 o_tx_udp_payload_axis_tvalid,
//   output wire                 o_tx_udp_payload_axis_tlast,
//   input  wire                 i_tx_udp_payload_axis_tready,
//   input  wire          [15:0] i_port_nbr,
//   input  wire          [31:0] i_ip_adr,
//   output wire [REG_WIDTH-1:0] o_reg_0,
//   output wire [REG_WIDTH-1:0] o_reg_1,
//   output wire [REG_WIDTH-1:0] o_reg_2,
//   output wire [REG_WIDTH-1:0] o_reg_3
// );


// reg [REG_WIDTH-1:0] registers [0:REGS_NUM-1];

// localparam [2:0] S_WAIT_COLON    = 3'd0;
// localparam [2:0] S_PARSE_REG_NBR = 3'd1;
// localparam [2:0] S_PARSE_CMD     = 3'd2;
// localparam [2:0] S_WRITE_REG     = 3'd3;
// localparam [2:0] S_WRITE_DONE    = 3'd4;
// localparam [2:0] S_READ_REG      = 3'd5;

// localparam [7:0] ASCII_NBR_BASE = 8'h30;
// localparam [7:0] ASCII_W_UPPER  = 8'h57;
// localparam [7:0] ASCII_W_LOWER  = 8'h77;
// localparam [7:0] ASCII_R_UPPER  = 8'h52;
// localparam [7:0] ASCII_R_LOWER  = 8'h72;
// localparam [7:0] ASCII_COLON    = 8'h3A;

// reg           [2:0] r_state;
// reg           [2:0] r_reg_number;
// reg [REG_WIDTH-1:0] r_write_data;
// reg           [2:0] r_write_byte_cnt;
// reg [REG_WIDTH-1:0] r_read_data;
// reg           [2:0] r_read_byte_cnt;
// reg                 r_tx_udp_payload_axis_tvalid;
// reg                 r_tx_udp_payload_axis_tlast;

// wire    en;
// integer i;


// assign en = (i_ip_adr==IP_ADRESS && i_port_nbr==PORT_NUMBER) ? 1'b1 : 1'b0;


// always @(posedge i_clk)
// begin: REGISTERS_CONTROL_FSM
//   if (i_rst) begin
//     for (i = 0; i < REGS_NUM; i = i + 1) begin
//       registers[i]               <= 0;
//     end
//     r_state                      <= S_WAIT_COLON;
//     r_write_byte_cnt             <= 0;
//     r_read_byte_cnt              <= 0;
//     r_reg_number                 <= 0;
//     r_write_data                 <= 0;
//     r_read_data                  <= 0;
//     o_tx_udp_payload_axis_tdata  <= 0;
//     r_tx_udp_payload_axis_tvalid <= 0;
//     o_rx_udp_payload_axis_tready <= 0;

//   end else if (en) begin
//     case (r_state)
//       S_WAIT_COLON: begin
//         o_rx_udp_payload_axis_tready <= 1;
//         if (i_rx_udp_payload_axis_tvalid &&
//             !i_rx_udp_payload_axis_tlast &&
//             i_rx_udp_payload_axis_tdata == ASCII_COLON
//             ) begin // czy odebrany znak to ':'?
//           r_state <= S_PARSE_REG_NBR;
//         end
//       end // S_WAIT_COLON

//       S_PARSE_REG_NBR: begin
//         if (i_rx_udp_payload_axis_tvalid) begin
//           if (!i_rx_udp_payload_axis_tlast &&
//               i_rx_udp_payload_axis_tdata >= ASCII_NBR_BASE &&
//               i_rx_udp_payload_axis_tdata < (ASCII_NBR_BASE+REGS_NUM)
//               ) begin // czy numer rejestru jest w zakresie?
//             r_state      <= S_PARSE_CMD;
//             r_reg_number <= i_rx_udp_payload_axis_tdata - ASCII_NBR_BASE;
//           end else begin
//             r_state      <= S_WAIT_COLON;
//           end
//         end
//       end // S_PARSE_REG_NBR

//       S_PARSE_CMD: begin
//         if (i_rx_udp_payload_axis_tvalid) begin
//           if (!i_rx_udp_payload_axis_tlast &&
//               (i_rx_udp_payload_axis_tdata==ASCII_W_UPPER ||
//               i_rx_udp_payload_axis_tdata==ASCII_W_LOWER)
//               ) begin // czy modyfiakcja zawartosci rejestru?
//             r_state                      <= S_WRITE_REG;
//             r_write_byte_cnt             <= 0;
//           end else if (i_rx_udp_payload_axis_tlast &&
//                        (i_rx_udp_payload_axis_tdata == ASCII_R_UPPER ||
//                        i_rx_udp_payload_axis_tdata == ASCII_R_LOWER)
//                        ) begin // czy odczyt z rejestru?
//             r_state                      <= S_READ_REG;
//             // o_rx_udp_payload_axis_tready <= 0;
//             r_read_byte_cnt              <= 0;
//             r_read_data                  <= registers[r_reg_number];
//           end else begin // czy komenda nieznana?
//             r_state                      <=  S_WAIT_COLON;
//           end
//         end
//       end // S_PARSE_CMD

//       S_WRITE_REG: begin
//         if (i_rx_udp_payload_axis_tvalid) begin
//           r_write_data         <= (r_write_data << 8) | i_rx_udp_payload_axis_tdata;
//           if (r_write_byte_cnt < (REG_WIDTH/8)-1) begin // czy wysylac?
//             if (!i_rx_udp_payload_axis_tlast) begin // czy wysylane sa dane 32-bitowe?
//               r_write_byte_cnt <= r_write_byte_cnt + 1;
//             end else begin // czy przeslano mniej niz 32 bity?
//               r_write_byte_cnt <= 0;
//               r_state          <= S_WAIT_COLON;
//             end
//           end else begin // czy wyslano wszystko?
//             if (i_rx_udp_payload_axis_tlast) begin // czy otrzymano sygnal konca wiadomosci?
//               r_state          <= S_WRITE_DONE;
//             end
//           end
//         end
//       end // S_WRITE_REG

//       S_WRITE_DONE: begin
//         r_write_byte_cnt        <= 0;
//         registers[r_reg_number] <= r_write_data;
//         r_state                 <= S_WAIT_COLON;
//       end // S_WRITE_DONE

//       S_READ_REG: begin
//         r_tx_udp_payload_axis_tvalid <= 1;
//         o_rx_udp_payload_axis_tready <= 0;
//         if (i_tx_udp_payload_axis_tready) begin
//           if (r_read_byte_cnt < (REG_WIDTH/8)-1) begin // czy nie wyslano wszystkiego?
//             case (r_read_byte_cnt)
//               0:       o_tx_udp_payload_axis_tdata <= r_read_data[31:24];
//               1:       o_tx_udp_payload_axis_tdata <= r_read_data[23:16];
//               2:       o_tx_udp_payload_axis_tdata <= r_read_data[15: 8];
//               default: o_tx_udp_payload_axis_tdata <= r_read_data[ 7: 0];
//             endcase // r_read_byte_cnt
//             r_read_byte_cnt              <= r_read_byte_cnt + 1;
//           end else begin // czy wyslano cala zawartosc?
//             o_tx_udp_payload_axis_tdata  <= r_read_data[ 7: 0];
//             r_read_byte_cnt              <= 0;
//             r_state                      <= S_WAIT_COLON;
//             r_tx_udp_payload_axis_tvalid <= 0;
//             // o_rx_udp_payload_axis_tready <= 1;
//           end
//         end
//       end // S_READ_REG

//     endcase // state_reg
//   end
// end // REGISTERS_CONTROL_FSM


// always @(posedge i_clk)
// begin: REG_O_TX_TLAST
//   if (r_read_byte_cnt == (REG_WIDTH/8)-1) begin
//     r_tx_udp_payload_axis_tlast <= 1;
//   end else begin
//     r_tx_udp_payload_axis_tlast <= 0;
//   end
// end // REG_O_TX_TLAST


// assign o_tx_udp_payload_axis_tlast = r_tx_udp_payload_axis_tlast;
// assign o_tx_udp_payload_axis_tvalid = r_tx_udp_payload_axis_tvalid || r_tx_udp_payload_axis_tlast;


// assign o_reg_0 = registers[0];
// assign o_reg_1 = registers[1];
// assign o_reg_2 = registers[2];
// assign o_reg_3 = registers[3];


// endmodule // registers_control