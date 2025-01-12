	component pcie_system is
		port (
			pcie1_refclk_clk              : in  std_logic                     := 'X';             -- clk
			pcie1_npor_npor               : in  std_logic                     := 'X';             -- npor
			pcie1_npor_pin_perst          : in  std_logic                     := 'X';             -- pin_perst
			clk_125_clk                   : in  std_logic                     := 'X';             -- clk
			rst_125_reset_n               : in  std_logic                     := 'X';             -- reset_n
			pcie1_hip_ctrl_test_in        : in  std_logic_vector(31 downto 0) := (others => 'X'); -- test_in
			pcie1_hip_ctrl_simu_mode_pipe : in  std_logic                     := 'X';             -- simu_mode_pipe
			pcie1_hip_serial_rx_in0       : in  std_logic                     := 'X';             -- rx_in0
			pcie1_hip_serial_rx_in1       : in  std_logic                     := 'X';             -- rx_in1
			pcie1_hip_serial_rx_in2       : in  std_logic                     := 'X';             -- rx_in2
			pcie1_hip_serial_rx_in3       : in  std_logic                     := 'X';             -- rx_in3
			pcie1_hip_serial_rx_in4       : in  std_logic                     := 'X';             -- rx_in4
			pcie1_hip_serial_rx_in5       : in  std_logic                     := 'X';             -- rx_in5
			pcie1_hip_serial_rx_in6       : in  std_logic                     := 'X';             -- rx_in6
			pcie1_hip_serial_rx_in7       : in  std_logic                     := 'X';             -- rx_in7
			pcie1_hip_serial_tx_out0      : out std_logic;                                        -- tx_out0
			pcie1_hip_serial_tx_out1      : out std_logic;                                        -- tx_out1
			pcie1_hip_serial_tx_out2      : out std_logic;                                        -- tx_out2
			pcie1_hip_serial_tx_out3      : out std_logic;                                        -- tx_out3
			pcie1_hip_serial_tx_out4      : out std_logic;                                        -- tx_out4
			pcie1_hip_serial_tx_out5      : out std_logic;                                        -- tx_out5
			pcie1_hip_serial_tx_out6      : out std_logic;                                        -- tx_out6
			pcie1_hip_serial_tx_out7      : out std_logic;                                        -- tx_out7
			pcie2_refclk_clk              : in  std_logic                     := 'X';             -- clk
			pcie2_npor_npor               : in  std_logic                     := 'X';             -- npor
			pcie2_npor_pin_perst          : in  std_logic                     := 'X';             -- pin_perst
			pcie2_hip_serial_rx_in0       : in  std_logic                     := 'X';             -- rx_in0
			pcie2_hip_serial_rx_in1       : in  std_logic                     := 'X';             -- rx_in1
			pcie2_hip_serial_rx_in2       : in  std_logic                     := 'X';             -- rx_in2
			pcie2_hip_serial_rx_in3       : in  std_logic                     := 'X';             -- rx_in3
			pcie2_hip_serial_rx_in4       : in  std_logic                     := 'X';             -- rx_in4
			pcie2_hip_serial_rx_in5       : in  std_logic                     := 'X';             -- rx_in5
			pcie2_hip_serial_rx_in6       : in  std_logic                     := 'X';             -- rx_in6
			pcie2_hip_serial_rx_in7       : in  std_logic                     := 'X';             -- rx_in7
			pcie2_hip_serial_tx_out0      : out std_logic;                                        -- tx_out0
			pcie2_hip_serial_tx_out1      : out std_logic;                                        -- tx_out1
			pcie2_hip_serial_tx_out2      : out std_logic;                                        -- tx_out2
			pcie2_hip_serial_tx_out3      : out std_logic;                                        -- tx_out3
			pcie2_hip_serial_tx_out4      : out std_logic;                                        -- tx_out4
			pcie2_hip_serial_tx_out5      : out std_logic;                                        -- tx_out5
			pcie2_hip_serial_tx_out6      : out std_logic;                                        -- tx_out6
			pcie2_hip_serial_tx_out7      : out std_logic;                                        -- tx_out7
			pcie2_hip_ctrl_test_in        : in  std_logic_vector(31 downto 0) := (others => 'X'); -- test_in
			pcie2_hip_ctrl_simu_mode_pipe : in  std_logic                     := 'X';             -- simu_mode_pipe
			uart_conduit_rxd              : in  std_logic                     := 'X';             -- rxd
			uart_conduit_txd              : out std_logic                                         -- txd
		);
	end component pcie_system;

	u0 : component pcie_system
		port map (
			pcie1_refclk_clk              => CONNECTED_TO_pcie1_refclk_clk,              --     pcie1_refclk.clk
			pcie1_npor_npor               => CONNECTED_TO_pcie1_npor_npor,               --       pcie1_npor.npor
			pcie1_npor_pin_perst          => CONNECTED_TO_pcie1_npor_pin_perst,          --                 .pin_perst
			clk_125_clk                   => CONNECTED_TO_clk_125_clk,                   --          clk_125.clk
			rst_125_reset_n               => CONNECTED_TO_rst_125_reset_n,               --          rst_125.reset_n
			pcie1_hip_ctrl_test_in        => CONNECTED_TO_pcie1_hip_ctrl_test_in,        --   pcie1_hip_ctrl.test_in
			pcie1_hip_ctrl_simu_mode_pipe => CONNECTED_TO_pcie1_hip_ctrl_simu_mode_pipe, --                 .simu_mode_pipe
			pcie1_hip_serial_rx_in0       => CONNECTED_TO_pcie1_hip_serial_rx_in0,       -- pcie1_hip_serial.rx_in0
			pcie1_hip_serial_rx_in1       => CONNECTED_TO_pcie1_hip_serial_rx_in1,       --                 .rx_in1
			pcie1_hip_serial_rx_in2       => CONNECTED_TO_pcie1_hip_serial_rx_in2,       --                 .rx_in2
			pcie1_hip_serial_rx_in3       => CONNECTED_TO_pcie1_hip_serial_rx_in3,       --                 .rx_in3
			pcie1_hip_serial_rx_in4       => CONNECTED_TO_pcie1_hip_serial_rx_in4,       --                 .rx_in4
			pcie1_hip_serial_rx_in5       => CONNECTED_TO_pcie1_hip_serial_rx_in5,       --                 .rx_in5
			pcie1_hip_serial_rx_in6       => CONNECTED_TO_pcie1_hip_serial_rx_in6,       --                 .rx_in6
			pcie1_hip_serial_rx_in7       => CONNECTED_TO_pcie1_hip_serial_rx_in7,       --                 .rx_in7
			pcie1_hip_serial_tx_out0      => CONNECTED_TO_pcie1_hip_serial_tx_out0,      --                 .tx_out0
			pcie1_hip_serial_tx_out1      => CONNECTED_TO_pcie1_hip_serial_tx_out1,      --                 .tx_out1
			pcie1_hip_serial_tx_out2      => CONNECTED_TO_pcie1_hip_serial_tx_out2,      --                 .tx_out2
			pcie1_hip_serial_tx_out3      => CONNECTED_TO_pcie1_hip_serial_tx_out3,      --                 .tx_out3
			pcie1_hip_serial_tx_out4      => CONNECTED_TO_pcie1_hip_serial_tx_out4,      --                 .tx_out4
			pcie1_hip_serial_tx_out5      => CONNECTED_TO_pcie1_hip_serial_tx_out5,      --                 .tx_out5
			pcie1_hip_serial_tx_out6      => CONNECTED_TO_pcie1_hip_serial_tx_out6,      --                 .tx_out6
			pcie1_hip_serial_tx_out7      => CONNECTED_TO_pcie1_hip_serial_tx_out7,      --                 .tx_out7
			pcie2_refclk_clk              => CONNECTED_TO_pcie2_refclk_clk,              --     pcie2_refclk.clk
			pcie2_npor_npor               => CONNECTED_TO_pcie2_npor_npor,               --       pcie2_npor.npor
			pcie2_npor_pin_perst          => CONNECTED_TO_pcie2_npor_pin_perst,          --                 .pin_perst
			pcie2_hip_serial_rx_in0       => CONNECTED_TO_pcie2_hip_serial_rx_in0,       -- pcie2_hip_serial.rx_in0
			pcie2_hip_serial_rx_in1       => CONNECTED_TO_pcie2_hip_serial_rx_in1,       --                 .rx_in1
			pcie2_hip_serial_rx_in2       => CONNECTED_TO_pcie2_hip_serial_rx_in2,       --                 .rx_in2
			pcie2_hip_serial_rx_in3       => CONNECTED_TO_pcie2_hip_serial_rx_in3,       --                 .rx_in3
			pcie2_hip_serial_rx_in4       => CONNECTED_TO_pcie2_hip_serial_rx_in4,       --                 .rx_in4
			pcie2_hip_serial_rx_in5       => CONNECTED_TO_pcie2_hip_serial_rx_in5,       --                 .rx_in5
			pcie2_hip_serial_rx_in6       => CONNECTED_TO_pcie2_hip_serial_rx_in6,       --                 .rx_in6
			pcie2_hip_serial_rx_in7       => CONNECTED_TO_pcie2_hip_serial_rx_in7,       --                 .rx_in7
			pcie2_hip_serial_tx_out0      => CONNECTED_TO_pcie2_hip_serial_tx_out0,      --                 .tx_out0
			pcie2_hip_serial_tx_out1      => CONNECTED_TO_pcie2_hip_serial_tx_out1,      --                 .tx_out1
			pcie2_hip_serial_tx_out2      => CONNECTED_TO_pcie2_hip_serial_tx_out2,      --                 .tx_out2
			pcie2_hip_serial_tx_out3      => CONNECTED_TO_pcie2_hip_serial_tx_out3,      --                 .tx_out3
			pcie2_hip_serial_tx_out4      => CONNECTED_TO_pcie2_hip_serial_tx_out4,      --                 .tx_out4
			pcie2_hip_serial_tx_out5      => CONNECTED_TO_pcie2_hip_serial_tx_out5,      --                 .tx_out5
			pcie2_hip_serial_tx_out6      => CONNECTED_TO_pcie2_hip_serial_tx_out6,      --                 .tx_out6
			pcie2_hip_serial_tx_out7      => CONNECTED_TO_pcie2_hip_serial_tx_out7,      --                 .tx_out7
			pcie2_hip_ctrl_test_in        => CONNECTED_TO_pcie2_hip_ctrl_test_in,        --   pcie2_hip_ctrl.test_in
			pcie2_hip_ctrl_simu_mode_pipe => CONNECTED_TO_pcie2_hip_ctrl_simu_mode_pipe, --                 .simu_mode_pipe
			uart_conduit_rxd              => CONNECTED_TO_uart_conduit_rxd,              --     uart_conduit.rxd
			uart_conduit_txd              => CONNECTED_TO_uart_conduit_txd               --                 .txd
		);

