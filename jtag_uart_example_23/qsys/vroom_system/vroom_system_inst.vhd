	component vroom_system is
		port (
			clk_clk                    : in  std_logic := 'X'; -- clk
			reset_reset_n              : in  std_logic := 'X'; -- reset_n
			vroom_0_uart_rx_new_signal : in  std_logic := 'X'; -- new_signal
			vroom_0_uart_tx_new_signal : out std_logic         -- new_signal
		);
	end component vroom_system;

	u0 : component vroom_system
		port map (
			clk_clk                    => CONNECTED_TO_clk_clk,                    --             clk.clk
			reset_reset_n              => CONNECTED_TO_reset_reset_n,              --           reset.reset_n
			vroom_0_uart_rx_new_signal => CONNECTED_TO_vroom_0_uart_rx_new_signal, -- vroom_0_uart_rx.new_signal
			vroom_0_uart_tx_new_signal => CONNECTED_TO_vroom_0_uart_tx_new_signal  -- vroom_0_uart_tx.new_signal
		);

