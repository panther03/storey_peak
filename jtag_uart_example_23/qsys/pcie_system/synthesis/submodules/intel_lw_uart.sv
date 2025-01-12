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

module intel_lw_uart #(
  parameter parity               = "NONE",
  parameter dataBits             = 8,
  parameter stopBits             = 1,
  parameter syncRegDepth         = 2,
  parameter useCtsRts            = 0,
  parameter useEopRegister       = 0,
  parameter useRegTXFIFO         = 0,
  parameter useRegRXFIFO         = 0,
  parameter derivedTxfifoDepth   = 8,
  parameter derivedRxfifoDepth   = 8,
  parameter derivedRxfifoAlmostFullValue = 7,
  parameter txfifoWidthu         = 3,
  parameter rxfifoWidthu         = 3,
  parameter fixedBaud            = 1,
  parameter divisorConstant      = 433,
  parameter divisorConstantWidth = 9,
  parameter simTrueBaud          = 0
) (
  input                 clk,
  input                 reset_n,
                        //AVMM
  input [2: 0]          address,
  input                 read,
  input                 write,
  input [15: 0]         writedata,
  output logic [15: 0]  readdata,
                        //RS-232
  input                 rxd,
  output logic          txd,
  input                 cts_n,
  output logic          rts_n,
                        //IRQ
  output logic          irq
)
  /* synthesis altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION OFF" */ ;

  localparam DIVISOR_WIDTH = (fixedBaud)? divisorConstantWidth : 16;

  logic break_detect, clk_en, do_force_break, do_load_shifter, shift_done, framing_error, parity_error, status_wr_strobe;
  logic rx_char_ready, rxfifo_almostfull, rxfifo_full, rxfifo_overrun, rxfifo_underrun, rx_rd_strobe;
  logic get_txfifo, txfifo_overrun, txfifo_full, txfifo_empty, tx_ready, tx_empty, tx_wr_strobe;
  logic [rxfifoWidthu-1: 0] rxfifo_usedw;
  logic [DIVISOR_WIDTH-1: 0] baud_divisor;
  logic [dataBits-1: 0] rx_data, tx_data;

  assign clk_en = 1;

  intel_lw_uart_regs #(
    .dataBits         (dataBits       ),
    .useCtsRts        (useCtsRts      ),
    .useEopRegister   (useEopRegister ),
    .useRegTXFIFO     (useRegTXFIFO   ),
    .derivedTxfifoDepth(derivedTxfifoDepth),
    .txfifoWidthu     (txfifoWidthu   ),
    .rxfifoWidthu     (rxfifoWidthu   ),
    .fixedBaud        (fixedBaud      ),
    .divisorConstant  (divisorConstant),
    .DIVISOR_WIDTH    (DIVISOR_WIDTH  ),
    .simTrueBaud      (simTrueBaud    )
  ) uart_regs (
    .clk              (clk),
    .clk_en           (clk_en),
    .reset_n          (reset_n),
    .address          (address),
    .read             (read),
    .write            (write),
    .writedata        (writedata),
    .readdata         (readdata),
    .cts_n            (cts_n),
    .rts_n            (rts_n),
    .irq              (irq),
    .do_load_shifter  (do_load_shifter),
    .shift_done       (shift_done),
    .break_detect     (break_detect),
    .framing_error    (framing_error),
    .parity_error     (parity_error),
    .rx_char_ready    (rx_char_ready),
    .rx_data          (rx_data),
    .rxfifo_underrun  (rxfifo_underrun),
    .rxfifo_overrun   (rxfifo_overrun),
    .rxfifo_usedw     (rxfifo_usedw),
    .rxfifo_full      (rxfifo_full),
    .rxfifo_almostfull(rxfifo_almostfull),
    .txfifo_overrun   (txfifo_overrun),
    .tx_ready         (tx_ready),
    .tx_empty         (tx_empty),
    .txfifo_empty     (txfifo_empty),
    .txfifo_full      (txfifo_full),
    .get_txfifo       (get_txfifo),
    .baud_divisor     (baud_divisor),
    .do_force_break   (do_force_break),
    .rx_rd_strobe     (rx_rd_strobe),
    .status_wr_strobe (status_wr_strobe),
    .tx_data          (tx_data),
    .tx_wr_strobe     (tx_wr_strobe)
  );


  intel_lw_uart_tx #(
    .parity           (parity         ),
    .dataBits         (dataBits       ),
    .stopBits         (stopBits       ),
    .DIVISOR_WIDTH    (DIVISOR_WIDTH  )
  ) uart_tx (
    .clk              (clk),
    .clk_en           (clk_en),
    .reset_n          (reset_n),
    .baud_divisor     (baud_divisor),
    .do_force_break   (do_force_break),
    .status_wr_strobe (status_wr_strobe),
    .tx_data          (tx_data),
    .tx_wr_strobe     (tx_wr_strobe),
    .txfifo_full      (txfifo_full),
    .txfifo_empty     (txfifo_empty),
    .get_txfifo       (get_txfifo),
    .do_load_shifter  (do_load_shifter),
    .shift_done       (shift_done),
    .txfifo_overrun   (txfifo_overrun),
    .tx_ready         (tx_ready),
    .tx_empty         (tx_empty),
    .txd              (txd)
  );


  intel_lw_uart_rx #(
    .parity           (parity         ),
    .dataBits         (dataBits       ),
    .stopBits         (stopBits       ),
    .syncRegDepth     (syncRegDepth   ),
    .useRegRXFIFO     (useRegRXFIFO   ),
    .derivedRxfifoDepth(derivedRxfifoDepth),
    .derivedRxfifoAlmostFullValue(derivedRxfifoAlmostFullValue),
    .rxfifoWidthu     (rxfifoWidthu   ),
    .DIVISOR_WIDTH    (DIVISOR_WIDTH  )
  ) uart_rx (
    .clk              (clk),
    .clk_en           (clk_en),
    .reset_n          (reset_n),
    .rxd              (rxd),
    .baud_divisor     (baud_divisor),
    .rx_rd_strobe     (rx_rd_strobe),
    .status_wr_strobe (status_wr_strobe),
    .break_detect     (break_detect),
    .framing_error    (framing_error),
    .parity_error     (parity_error),
    .rx_char_ready    (rx_char_ready),
    .rx_data          (rx_data),
    .rxfifo_overrun   (rxfifo_overrun),
    .rxfifo_underrun  (rxfifo_underrun),
    .rxfifo_full      (rxfifo_full),
    .rxfifo_almostfull(rxfifo_almostfull),
    .rxfifo_usedw     (rxfifo_usedw)
  );


endmodule