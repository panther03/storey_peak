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

module intel_lw_uart_regs #(
  parameter dataBits        = 8,
  parameter useCtsRts       = 0,
  parameter useEopRegister  = 0,
  parameter useRegTXFIFO    = 0,
  parameter derivedTxfifoDepth = 8,
  parameter txfifoWidthu    = 3,
  parameter rxfifoWidthu    = 3,
  parameter fixedBaud       = 1,
  parameter divisorConstant = 433,
  parameter DIVISOR_WIDTH   = 9,
  parameter simTrueBaud     = 0
) (
  input                             clk,
  input                             clk_en,
  input                             reset_n,
                                    //AVMM
  input [2: 0]                      address,
  input                             write,
  input [15: 0]                     writedata,
  input                             read,
  output logic [15: 0]              readdata,
                                    //RS-232
  input                             cts_n,
  output logic                      rts_n,
                                    //IRQ
  output logic                      irq,

  input                             do_load_shifter,
  input                             shift_done,
  input                             break_detect,
  input                             framing_error,
  input                             parity_error,
  input                             rx_char_ready,
  input [dataBits-1: 0]             rx_data,
  input                             rxfifo_underrun,
  input                             rxfifo_overrun,
  input [rxfifoWidthu-1: 0]         rxfifo_usedw,
  input                             rxfifo_full,
  input                             rxfifo_almostfull,
  input                             txfifo_overrun,
  input                             tx_ready,
  input                             tx_empty,
  output logic                      txfifo_empty,
  output logic                      txfifo_full,
  output logic                      get_txfifo,
  output logic [DIVISOR_WIDTH-1: 0] baud_divisor,
  output logic                      do_force_break,
  output logic                      rx_rd_strobe,
  output logic                      status_wr_strobe,
  output logic [dataBits-1: 0]      tx_data,
  output logic                      tx_wr_strobe
);

  logic any_error, control_wr_strobe, do_write_char;
  logic delayed_tx_ready;
  logic ie_any_error, ie_break_detect, ie_framing_error, ie_parity_error;
  logic ie_dcts, rts_control_bit, ie_eop;
  logic ie_rx_char_ready, ie_rxfifo_underrun, ie_rxfifo_overrun, ie_txfifo_overrun, ie_tx_ready, ie_tx_empty, ie_rxfifo_full, ie_rxfifo_almostfull;
  logic cts_status_bit, dcts_status_bit, eop_status_bit;
  logic qualified_irq, qualified_irq_dcts, qualified_irq_eop;
  logic wrdata_eop;
  logic [1:0] wrdata_rtscts;
  logic [15: 0] selected_read_data, selected_read_data_baud_divisor, selected_read_data_eop_char_reg;
  logic [15: 0] status_reg, control_reg;
  logic [txfifoWidthu-1: 0] TXFIFO_LVL_reg, txfifo_usedw;
  logic [rxfifoWidthu-1: 0] RXFIFO_LVL_reg;
  logic [DIVISOR_WIDTH-1: 0] divisor_constant;


  assign rx_rd_strobe      = read  && (address == 3'd0);
  assign tx_wr_strobe      = write && (address == 3'd1);
  assign status_wr_strobe  = write && (address == 3'd2);
  assign control_wr_strobe = write && (address == 3'd3);


  localparam TXFIFO_USE_EAB = useRegTXFIFO? "OFF" : "ON";

//TXFIFO
  scfifo txfifo
  (
      .clock        (clk),
      .aclr         (~reset_n),
      .wrreq        (tx_wr_strobe),
      .data         (writedata[dataBits-1 : 0]),
      .rdreq        (get_txfifo),
      .q            (tx_data),
      .usedw        (txfifo_usedw),
      .full         (txfifo_full),
      .empty        (txfifo_empty)
  );
  defparam
      txfifo.lpm_width         = dataBits,
      txfifo.lpm_numwords      = derivedTxfifoDepth,
      txfifo.lpm_widthu        = txfifoWidthu,
      txfifo.lpm_showahead     = "OFF",
      txfifo.use_eab           = TXFIFO_USE_EAB,
      txfifo.ram_block_type    = "AUTO";


  assign any_error = txfifo_overrun || rxfifo_overrun || rxfifo_underrun || parity_error || framing_error || break_detect;

//status_reg
  assign status_reg = {rxfifo_almostfull,
                       rxfifo_full,
                       rxfifo_underrun,
                       eop_status_bit,
                       cts_status_bit,
                       dcts_status_bit,
                       1'b0,
                       any_error,
                       rx_char_ready,
                       tx_ready,
                       tx_empty,
                       txfifo_overrun,
                       rxfifo_overrun,
                       break_detect,
                       framing_error,
                       parity_error};


//control_reg
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          control_reg <= 0;
      else if (control_wr_strobe)
          control_reg <= {writedata[15 : 13], wrdata_eop, wrdata_rtscts, writedata[9 : 0]};
  end

  assign {ie_rxfifo_almostfull,
          ie_rxfifo_full,
          ie_rxfifo_underrun,               //ie_: interrupt enable
          ie_eop,
          rts_control_bit,
          ie_dcts,
          do_force_break,
          ie_any_error,
          ie_rx_char_ready,
          ie_tx_ready,
          ie_tx_empty,
          ie_txfifo_overrun,
          ie_rxfifo_overrun,
          ie_break_detect,
          ie_framing_error,
          ie_parity_error} = control_reg;


generate
//baud_divisor reg
if (fixedBaud == 0) begin
  logic divisor_wr_strobe;

  assign divisor_wr_strobe = write && (address == 3'd4);
  assign selected_read_data_baud_divisor = ({16 {(address == 3'd4)}} & baud_divisor);

  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          baud_divisor <= divisor_constant;
      else if (divisor_wr_strobe)
          baud_divisor <= writedata[15 : 0];
  end
end
else begin
  assign selected_read_data_baud_divisor = 16'b0;
  assign baud_divisor = divisor_constant;
end


//eop_char_reg
if (useEopRegister) begin
  logic [dataBits-1: 0] eop_char_reg;
  logic eop_char_wr_strobe;

  assign eop_char_wr_strobe = write && (address == 3'd5);
  assign selected_read_data_eop_char_reg = ({16 {(address == 3'd5)}} & eop_char_reg);
  assign qualified_irq_eop = (ie_eop && eop_status_bit);
  assign wrdata_eop = writedata[12];

  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          eop_char_reg <= 0;
      else if (eop_char_wr_strobe)
          eop_char_reg <= writedata[dataBits-1 : 0];
  end

//Status: eop_status_bit
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          eop_status_bit <= 0;
      else if (clk_en)
          if (status_wr_strobe)
              eop_status_bit <= 0;
          else if ( (rx_rd_strobe && (eop_char_reg == rx_data)) ||
                    (tx_wr_strobe && (eop_char_reg == writedata[dataBits-1 : 0])) )
              eop_status_bit <= 1'b1;
  end
end
else begin
  assign selected_read_data_eop_char_reg = 16'b0;
  assign qualified_irq_eop = 1'b0;
  assign eop_status_bit = 1'b0;
  assign wrdata_eop = 1'b0;
end


//RXFIFO_LVL reg
assign RXFIFO_LVL_reg = rxfifo_usedw;

//TXFIFO_LVL reg
assign TXFIFO_LVL_reg = txfifo_usedw;


if (useCtsRts) begin
  logic cts_edge, delayed_cts_status_bit;

  assign get_txfifo = ~cts_n & ~do_load_shifter & (~txfifo_empty) & shift_done;

  assign qualified_irq_dcts = (ie_dcts && dcts_status_bit);
  assign wrdata_rtscts = writedata[11:10];

//Status: cts_status_bit
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          cts_status_bit <= 1;
      else if (clk_en)
          cts_status_bit <= ~cts_n;
  end

  //cts_status_bit edge detection
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          delayed_cts_status_bit <= 0;
      else if (clk_en)
          delayed_cts_status_bit <= cts_status_bit;
  end

  assign cts_edge = (cts_status_bit) ^ (delayed_cts_status_bit);

//Status: dcts_status_bit
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          dcts_status_bit <= 0;
      else if (clk_en)
          if (status_wr_strobe)
              dcts_status_bit <= 0;
          else if (cts_edge)
              dcts_status_bit <= 1'b1;
  end

//output: rts_n
  assign rts_n = (rxfifo_almostfull)? 1'b1: ~rts_control_bit;
end
else begin
  assign get_txfifo = ~do_load_shifter & (~txfifo_empty) & shift_done;

  assign qualified_irq_dcts = 1'b0;
  assign cts_status_bit  = 0;
  assign dcts_status_bit = 0;
  assign rts_n = 1'b1;
  assign wrdata_rtscts = 2'b00;
end
endgenerate


  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          readdata <= 0;
      else if (clk_en)
          readdata <= selected_read_data & {16{read}};
  end


  assign selected_read_data = ({16 {(address == 3'd0)}} & rx_data) |
//                            ({16 {(address == 3'd1)}} & tx_data) |
                              ({16 {(address == 3'd2)}} & status_reg) |
                              ({16 {(address == 3'd3)}} & control_reg) |
                              selected_read_data_baud_divisor |
                              selected_read_data_eop_char_reg |
                              ({16 {(address == 3'd6)}} & RXFIFO_LVL_reg) |
                              ({16 {(address == 3'd7)}} & TXFIFO_LVL_reg) ;


//output: irq
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          irq <= 0;
      else if (clk_en)
          irq <= qualified_irq;
  end

  assign qualified_irq =(ie_rxfifo_almostfull && rxfifo_almostfull ) ||
                        (ie_rxfifo_full     && rxfifo_full    ) ||
                        (ie_rxfifo_underrun && rxfifo_underrun) ||
                         qualified_irq_eop  ||
                         qualified_irq_dcts ||
                         (ie_any_error      && any_error      ) ||
                         (ie_rx_char_ready  && rx_char_ready  ) ||
                         (ie_tx_ready       && tx_ready       ) ||
                         (ie_tx_empty       && tx_empty       ) ||
                         (ie_txfifo_overrun && txfifo_overrun ) ||
                         (ie_rxfifo_overrun && rxfifo_overrun ) ||
                         (ie_break_detect   && break_detect   ) ||
                         (ie_framing_error  && framing_error  ) ||
                         (ie_parity_error   && parity_error   );


//synthesis translate_off
//////////////// SIMULATION-ONLY CONTENTS
generate
if (simTrueBaud) begin
  assign divisor_constant = divisorConstant;
end
else begin
  assign divisor_constant = 4;
end
endgenerate
//////////////// END SIMULATION-ONLY CONTENTS


//synthesis translate_on
//synthesis read_comments_as_HDL on
//  assign divisor_constant = divisorConstant;
//synthesis read_comments_as_HDL off


endmodule