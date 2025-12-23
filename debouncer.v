`timescale 1ns / 1ps


module debouncer (
  input  wire i_clk,
  input  wire i_async,
  output wire o_sync
);


reg [17:0] cnt; initial cnt = 0;
reg  [2:0] d;   initial d = 0;


always @(posedge i_clk) cnt <= cnt + 1;
always @(posedge i_clk)  if (cnt == 18'b11_1111_1111_1111_1111) d <= {d[1:0], i_async};


assign o_sync = d[2] && d[1] && d[0];


endmodule; // debouncer