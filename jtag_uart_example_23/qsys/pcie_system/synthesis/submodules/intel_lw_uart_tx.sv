// (C) 2001-2024 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

module intel_lw_uart_tx #(
    parameter parity          = "NONE",
    parameter dataBits        = 8,
    parameter stopBits        = 1,
    parameter DIVISOR_WIDTH   = 9
) (
    input                       clk,
    input                       clk_en,
    input                       reset_n,
    input [DIVISOR_WIDTH-1: 0]  baud_divisor,
    input                       do_force_break,
    input                       status_wr_strobe,
    input [dataBits-1: 0]       tx_data,
    input                       tx_wr_strobe,
    input                       txfifo_full,
    input                       txfifo_empty,
    input                       get_txfifo,
    output logic                do_load_shifter,
    output logic                shift_done,
    output logic                txfifo_overrun,
    output logic                tx_ready,
    output logic                tx_empty,
    output logic                txd                //RS-232
);

  localparam PARITYBITS = (parity == "NONE")? 0 : 1;
  localparam TX_FRAME_SIZE = 1 + dataBits + PARITYBITS + stopBits;

  logic baud_rate_counter_is_zero, baud_clk_en;
  logic do_shift, pre_txd;
  logic tx_shift_reg_out;
  logic [DIVISOR_WIDTH-1: 0] baud_rate_counter;
  logic [TX_FRAME_SIZE-1: 0] tx_load_val, tx_shift_register_contents,tx_shift_register_contents_in, tx_shift_register_contents_out;


generate
if (parity == "NONE") begin
  assign tx_load_val = {{stopBits{1'b1}},
                         tx_data,
                         1'b0};                       //start bit
end
else if (parity == "EVEN" ) begin
  assign tx_load_val = {{stopBits{1'b1}},
                         ^tx_data,                    //parity bit 0:even number of 1's;    1:odd  number of 1's
                         tx_data,
                         1'b0};
end
else if (parity == "ODD" ) begin
  assign tx_load_val = {{stopBits{1'b1}},
                         ~(^tx_data),                 //parity bit 0:odd number of 1's;     1:even number of 1's
                         tx_data,
                         1'b0};
end
endgenerate


//Status: Tx Ready (TRDY)
assign tx_ready = ~txfifo_full;

//Status: TX Empty (TMT)
assign tx_empty = txfifo_empty & shift_done & (~do_load_shifter);

//Status: TXFIFO Overrun Error (TOE)
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          txfifo_overrun <= 0;
      else if (clk_en)
          if (status_wr_strobe)
              txfifo_overrun <= 0;
          else if (txfifo_full && tx_wr_strobe)
              txfifo_overrun <= 1'b1;
  end


  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          baud_rate_counter <= 0;
      else if (clk_en)
          if (baud_rate_counter_is_zero || do_load_shifter)
              baud_rate_counter <= baud_divisor;
          else
            baud_rate_counter <= baud_rate_counter - {{DIVISOR_WIDTH-1{1'b0}}, 1'b1};
  end

  assign baud_rate_counter_is_zero = (baud_rate_counter == 0);

  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          baud_clk_en <= 0;
      else if (clk_en)
          if (do_load_shifter)
              baud_clk_en <= 0;
          else
              baud_clk_en <= baud_rate_counter_is_zero;
  end


  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          do_load_shifter <= 0;
      else if (clk_en)
            do_load_shifter <= get_txfifo;
  end

  assign do_shift = baud_clk_en && (~shift_done) && (~do_load_shifter);

  assign shift_done = ~(|tx_shift_register_contents);


  assign tx_shift_register_contents_in = (do_load_shifter)? tx_load_val :
                                         (do_shift)? {1'b0,tx_shift_register_contents_out[TX_FRAME_SIZE-1 : 1]} :
                                         tx_shift_register_contents_out;

  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          tx_shift_register_contents_out <= 0;
      else if (clk_en)
          tx_shift_register_contents_out <= tx_shift_register_contents_in;
  end

  assign tx_shift_register_contents = tx_shift_register_contents_out;
  assign tx_shift_reg_out = tx_shift_register_contents_out[0];

  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          pre_txd <= 1;
      else if (~shift_done)
          pre_txd <= tx_shift_reg_out;
  end

//output: txd
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          txd <= 1;
      else if (clk_en)
          txd <= pre_txd & ~do_force_break;
  end


endmodule
