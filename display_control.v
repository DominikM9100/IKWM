`timescale 1ns / 1ps


module display_control #(
  parameter REG_WIDTH = 32
)(
  input  wire                 i_clk,
  input  wire                 i_rst,
  input  wire           [3:0] i_sw,
  input  wire          [31:0] i_dest_ip_adr,
  input  wire [REG_WIDTH-1:0] i_reg_0,
  input  wire [REG_WIDTH-1:0] i_reg_1,
  input  wire [REG_WIDTH-1:0] i_reg_2,
  input  wire [REG_WIDTH-1:0] i_reg_3,
  output  reg          [31:0] o_hex_disp
);


always @(posedge i_clk)
begin: SWITCH_HEX_DISPLAY
  if (i_rst) begin
    o_hex_disp <= 32'h66666666; // cokolwiek innego co pozwoli zobaczyc roznice
  end else begin
    case (i_sw)
      4'b0001: o_hex_disp <= i_reg_0;
      4'b0010: o_hex_disp <= i_reg_1;
      4'b0100: o_hex_disp <= i_reg_2;
      4'b1000: o_hex_disp <= i_reg_3;
      default: o_hex_disp <= i_dest_ip_adr;
    endcase // i_sw
  end
end // SWITCH_HEX_DISPLAY


endmodule // display_control