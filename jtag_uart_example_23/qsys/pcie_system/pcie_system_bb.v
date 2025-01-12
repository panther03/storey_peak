
module pcie_system (
	pcie1_refclk_clk,
	pcie1_npor_npor,
	pcie1_npor_pin_perst,
	clk_125_clk,
	rst_125_reset_n,
	pcie1_hip_ctrl_test_in,
	pcie1_hip_ctrl_simu_mode_pipe,
	pcie1_hip_serial_rx_in0,
	pcie1_hip_serial_rx_in1,
	pcie1_hip_serial_rx_in2,
	pcie1_hip_serial_rx_in3,
	pcie1_hip_serial_rx_in4,
	pcie1_hip_serial_rx_in5,
	pcie1_hip_serial_rx_in6,
	pcie1_hip_serial_rx_in7,
	pcie1_hip_serial_tx_out0,
	pcie1_hip_serial_tx_out1,
	pcie1_hip_serial_tx_out2,
	pcie1_hip_serial_tx_out3,
	pcie1_hip_serial_tx_out4,
	pcie1_hip_serial_tx_out5,
	pcie1_hip_serial_tx_out6,
	pcie1_hip_serial_tx_out7,
	pcie2_refclk_clk,
	pcie2_npor_npor,
	pcie2_npor_pin_perst,
	pcie2_hip_serial_rx_in0,
	pcie2_hip_serial_rx_in1,
	pcie2_hip_serial_rx_in2,
	pcie2_hip_serial_rx_in3,
	pcie2_hip_serial_rx_in4,
	pcie2_hip_serial_rx_in5,
	pcie2_hip_serial_rx_in6,
	pcie2_hip_serial_rx_in7,
	pcie2_hip_serial_tx_out0,
	pcie2_hip_serial_tx_out1,
	pcie2_hip_serial_tx_out2,
	pcie2_hip_serial_tx_out3,
	pcie2_hip_serial_tx_out4,
	pcie2_hip_serial_tx_out5,
	pcie2_hip_serial_tx_out6,
	pcie2_hip_serial_tx_out7,
	pcie2_hip_ctrl_test_in,
	pcie2_hip_ctrl_simu_mode_pipe,
	uart_conduit_rxd,
	uart_conduit_txd);	

	input		pcie1_refclk_clk;
	input		pcie1_npor_npor;
	input		pcie1_npor_pin_perst;
	input		clk_125_clk;
	input		rst_125_reset_n;
	input	[31:0]	pcie1_hip_ctrl_test_in;
	input		pcie1_hip_ctrl_simu_mode_pipe;
	input		pcie1_hip_serial_rx_in0;
	input		pcie1_hip_serial_rx_in1;
	input		pcie1_hip_serial_rx_in2;
	input		pcie1_hip_serial_rx_in3;
	input		pcie1_hip_serial_rx_in4;
	input		pcie1_hip_serial_rx_in5;
	input		pcie1_hip_serial_rx_in6;
	input		pcie1_hip_serial_rx_in7;
	output		pcie1_hip_serial_tx_out0;
	output		pcie1_hip_serial_tx_out1;
	output		pcie1_hip_serial_tx_out2;
	output		pcie1_hip_serial_tx_out3;
	output		pcie1_hip_serial_tx_out4;
	output		pcie1_hip_serial_tx_out5;
	output		pcie1_hip_serial_tx_out6;
	output		pcie1_hip_serial_tx_out7;
	input		pcie2_refclk_clk;
	input		pcie2_npor_npor;
	input		pcie2_npor_pin_perst;
	input		pcie2_hip_serial_rx_in0;
	input		pcie2_hip_serial_rx_in1;
	input		pcie2_hip_serial_rx_in2;
	input		pcie2_hip_serial_rx_in3;
	input		pcie2_hip_serial_rx_in4;
	input		pcie2_hip_serial_rx_in5;
	input		pcie2_hip_serial_rx_in6;
	input		pcie2_hip_serial_rx_in7;
	output		pcie2_hip_serial_tx_out0;
	output		pcie2_hip_serial_tx_out1;
	output		pcie2_hip_serial_tx_out2;
	output		pcie2_hip_serial_tx_out3;
	output		pcie2_hip_serial_tx_out4;
	output		pcie2_hip_serial_tx_out5;
	output		pcie2_hip_serial_tx_out6;
	output		pcie2_hip_serial_tx_out7;
	input	[31:0]	pcie2_hip_ctrl_test_in;
	input		pcie2_hip_ctrl_simu_mode_pipe;
	input		uart_conduit_rxd;
	output		uart_conduit_txd;
endmodule
