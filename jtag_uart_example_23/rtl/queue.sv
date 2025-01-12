module queue (
   input         clk,
   input         enable,
   input  [2:0]  raddr,
   input  [2:0]  waddr,
   input  [7:0]  wdata,
   output [7:0]  rdata
);
   
   reg [7:0] mem [7:0];
   reg [7:0] rdata_r;

   integer i;

   initial begin
      for (i = 0; i < 8; i += 1) begin
         mem[i] = 8'h0;
      end
   end

   always @(posedge clk) begin
      if (enable) begin
         mem[waddr] <= wdata;
      end
      rdata_r <= mem[raddr];
   end


   assign rdata = rdata_r;

endmodule