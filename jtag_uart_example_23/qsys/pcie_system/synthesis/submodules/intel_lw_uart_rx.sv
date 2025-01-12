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

module intel_lw_uart_rx #(
    parameter parity          = "NONE",
    parameter dataBits        = 8,
    parameter stopBits        = 1,
    parameter syncRegDepth    = 2,
    parameter useRegRXFIFO    = 0,
    parameter derivedRxfifoDepth = 8,
    parameter derivedRxfifoAlmostFullValue = 7,
    parameter rxfifoWidthu    = 3,
    parameter DIVISOR_WIDTH   = 9
) (
    input                        clk,
    input                        clk_en,
    input                        reset_n,
    input                        rxd,               //RS-232
    input [DIVISOR_WIDTH-1: 0]   baud_divisor,
    input                        rx_rd_strobe,
    input                        status_wr_strobe,
    output logic                 break_detect,
    output logic                 framing_error,
    output logic                 parity_error,
    output logic                 rx_char_ready,
    output logic [dataBits-1: 0] rx_data,
    output logic                 rxfifo_overrun,
    output logic                 rxfifo_underrun,
    output logic                 rxfifo_full,
    output logic                 rxfifo_almostfull,
    output logic [rxfifoWidthu-1 :0] rxfifo_usedw
);

  localparam PARITYBITS = (parity == "NONE")? 0 : 1;
  localparam RXFIFO_USE_EAB = useRegRXFIFO? "OFF" : "ON";
  //UART will always terminate a recieve-transaction at the first stop bit
  localparam RX_FRAME_SIZE = 1 + dataBits + PARITYBITS + 1;

  logic baud_clk_en, baud_rate_counter_is_zero, do_start_rx, got_new_char;
  logic delayed_sync_rxd, delayed_sync_rxd2, delayed_rx_in_process;
  logic is_break, is_framing_error;
  logic parity_bit;
  logic rxfifo_empty;
  logic rx_in_process, rxd_edge, rxd_falling;
  logic sample_enable, shift_reg_start_bit_n, source_rxd, stop_bit, sync_rxd, unused_start_bit;
  logic [DIVISOR_WIDTH-1: 0] baud_load_value, baud_rate_counter;
  logic [DIVISOR_WIDTH-2: 0] half_bit_cell_divisor;
  logic [dataBits-1: 0] raw_data_in, rxfifo_q;
  logic [RX_FRAME_SIZE-1: 0] rxd_shift_reg, rx_shift_register_contents_in, rx_shift_register_contents_out;


  altera_std_synchronizer the_altera_std_synchronizer
  (
      .clk (clk),
      .din (rxd),
      .dout (sync_rxd),
      .reset_n (reset_n)
  );
  defparam the_altera_std_synchronizer.depth = syncRegDepth;


  //detect failing edge of sync_rxd
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          delayed_sync_rxd <= 0;
      else if (clk_en)
          delayed_sync_rxd <= sync_rxd;
    end

  assign rxd_falling = ~(sync_rxd) &  (delayed_sync_rxd);

  //sync_rxd edge detection
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          delayed_sync_rxd2 <= 0;
      else if (clk_en)
          delayed_sync_rxd2 <= sync_rxd;
  end

  assign rxd_edge = (sync_rxd) ^  (delayed_sync_rxd2);


  assign half_bit_cell_divisor = baud_divisor[DIVISOR_WIDTH-1: 1];
  assign baud_load_value = (rxd_edge)? half_bit_cell_divisor : baud_divisor;

  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          baud_rate_counter <= 0;
      else if (clk_en)
          if (baud_rate_counter_is_zero || rxd_edge)
              baud_rate_counter <= baud_load_value;
          else
            baud_rate_counter <= baud_rate_counter - {{DIVISOR_WIDTH-1{1'b0}}, 1'b1};
  end

  assign baud_rate_counter_is_zero = (baud_rate_counter == 0);

  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          baud_clk_en <= 0;
      else if (clk_en)
          if (rxd_edge)
              baud_clk_en <= 0;
          else
            baud_clk_en <= baud_rate_counter_is_zero;
  end


  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          do_start_rx <= 0;
      else if (clk_en)
          if (~rx_in_process && rxd_falling)  //detect start bit
              do_start_rx <= 1;
          else
            do_start_rx <= 0;
  end

  assign sample_enable = baud_clk_en && rx_in_process;

  assign rx_shift_register_contents_in = (do_start_rx)? {RX_FRAME_SIZE{1'b1}} :
                                         (sample_enable)? {sync_rxd, rx_shift_register_contents_out[RX_FRAME_SIZE-1 : 1]} :
                                         rx_shift_register_contents_out;

  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          rx_shift_register_contents_out <= 0;
      else if (clk_en)
          rx_shift_register_contents_out <= rx_shift_register_contents_in;
  end

  assign rxd_shift_reg = rx_shift_register_contents_out;
  assign shift_reg_start_bit_n = rx_shift_register_contents_out[0];
  assign rx_in_process = shift_reg_start_bit_n;

generate
if (parity == "NONE") begin
  assign {stop_bit,
          raw_data_in,
          unused_start_bit} = rxd_shift_reg;
end
else begin
  assign {stop_bit,
          parity_bit,
          raw_data_in,
          unused_start_bit} = rxd_shift_reg;
end
endgenerate


  //detect failing edge of rx_in_process -> sign that a new character has arrived.
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          delayed_rx_in_process <= 0;
      else if (clk_en)
          delayed_rx_in_process <= rx_in_process;
  end

  assign got_new_char = ~(rx_in_process) &  (delayed_rx_in_process);

//RXFIFO
  scfifo rxfifo
  (   .clock (clk),
      .aclr  (~reset_n),
      .wrreq (got_new_char),
      .data  (raw_data_in),
      .rdreq (rx_rd_strobe),
      .q     (rxfifo_q),
      .usedw (rxfifo_usedw),
      .full  (rxfifo_full),
      .almost_full  (rxfifo_almostfull),
      .empty (rxfifo_empty)
  );
  defparam
      rxfifo.lpm_width = dataBits,
      rxfifo.lpm_numwords = derivedRxfifoDepth,
      rxfifo.almost_full_value = derivedRxfifoAlmostFullValue,
      rxfifo.lpm_widthu = rxfifoWidthu,
      rxfifo.lpm_showahead = "ON",
      rxfifo.use_eab  = RXFIFO_USE_EAB,
      rxfifo.ram_block_type = "AUTO";


//Status: Rx Character Ready (RRDY)
assign rx_char_ready = ~rxfifo_empty;

//Status: RXFIFO Overrun Error (ROE)
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          rxfifo_overrun <= 0;
      else if (clk_en)
          if (status_wr_strobe)                   //clear status
              rxfifo_overrun <= 0;
          else if (got_new_char && rxfifo_full)
              rxfifo_overrun <= 1'b1;
  end

//Status: RXFIFO Underrun Error (RUE)
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          rxfifo_underrun <= 0;
      else if (clk_en)
          if (status_wr_strobe)
              rxfifo_underrun <= 0;
          else if (rx_rd_strobe && rxfifo_empty)
              rxfifo_underrun <= 1'b1;
  end
  //reading default value 0x0F when RXFIFO Underrun Error occur
  assign rx_data = (rx_rd_strobe && rxfifo_empty)? {{dataBits-4{1'b0}},4'hF} : rxfifo_q;

//Status: Break Detect (BRK)
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          break_detect <= 0;
      else if (clk_en)
          if (status_wr_strobe)
              break_detect <= 0;
          else if (got_new_char && is_break)
              break_detect <= 1'b1;
  end

  assign is_break = ~(|rxd_shift_reg);
  assign is_framing_error = ~stop_bit && ~is_break;

//Status: Framing Error (FE)
  always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
          framing_error <= 0;
      else if (clk_en)
          if (status_wr_strobe)
              framing_error <= 0;
          else if (got_new_char && is_framing_error)
              framing_error <= 1'b1;
  end

//Status: Parity Error (PE)
generate
if (parity == "NONE") begin
    assign parity_error = 0;
end
else begin
    logic correct_parity, is_parity_error;

    if (parity == "EVEN") begin
        assign correct_parity = ^raw_data_in;
    end
    else if (parity == "ODD") begin
        assign correct_parity = ~(^raw_data_in);
    end

    assign is_parity_error = (correct_parity != parity_bit) && ~is_break;

    always @(posedge clk or negedge reset_n) begin
        if (reset_n == 0)
            parity_error <= 0;
        else if (clk_en)
            if (status_wr_strobe)
                parity_error <= 0;
            else if (got_new_char && is_parity_error)
                parity_error <= 1'b1;
    end
end
endgenerate


endmodule