`define JTAG_UART

module top(
    input  wire     clk,
    output reg      led0,
    output reg      led1,
    output reg      led2,

    input           CLK_PCIE1,
    input           CLK_PCIE2,

    // PCIe 1
    input  wire          PCIE1_PERSTN,
    input  wire [ 7:0]   PCIE1_SERIAL_RX,
    output wire [ 7:0]   PCIE1_SERIAL_TX,

    // PCIe 2
    input  wire          PCIE2_PERSTN,
    input  wire [ 7:0]   PCIE2_SERIAL_RX,
    output wire [ 7:0]   PCIE2_SERIAL_TX
);

    wire button = 1'b0;
    // When changing this value, checkout ./sw/Makefile for a list of 
    // all other files that must be changed as well.
    localparam mem_size_bytes   = 2048;

    // $clog2 is only supported by Verilog-2005 and later.
    // If your synthesis tool doesn't like it, just replace the expression
    // below by 11...
    localparam mem_addr_bits    = $clog2(mem_size_bytes);   

    localparam periph_addr_bits = 12;

    wire                iBus_cmd_valid;
    wire                iBus_cmd_ready;
    wire  [31:0]        iBus_cmd_payload_pc;

    reg                 iBus_rsp_valid;
    wire                iBus_rsp_payload_error;
    reg   [31:0]        iBus_rsp_payload_inst;

    wire                dBus_cmd_valid;
    wire                dBus_cmd_ready;
    wire                dBus_cmd_payload_wr;
    wire  [31:0]        dBus_cmd_payload_address;
    wire  [31:0]        dBus_cmd_payload_data;
    wire  [1:0]         dBus_cmd_payload_size;

    wire                dBus_rsp_ready;
    wire                dBus_rsp_error;
    wire  [31:0]        dBus_rsp_data;

    reg   [7:0]         reset_vec = 8'hff;
    reg                 reset_enable = 1'b0;
    reg                 go_r = 1'b0;
    wire                reset;

    wire spart_readdatavalid;
    wire [31:0] spart_readdata;
    wire spart_tx;
    wire spart_rx = 1'b1;

    // 8 clock cycles of active-high reset.
    always @(posedge clk) begin
        reset_vec       <= reset_enable ? 8'hff : { reset_vec[6:0], 1'b0 };     
    end

    assign reset = reset_vec[7];

    VexRiscvTop u_vex (
            .clk                        (clk),
            .reset                      (reset),

            .io_iBus_cmd_valid          (iBus_cmd_valid),
            .io_iBus_cmd_ready          (iBus_cmd_ready),
            .io_iBus_cmd_payload_pc     (iBus_cmd_payload_pc),

            .io_iBus_rsp_valid          (iBus_rsp_valid),
            .io_iBus_rsp_payload_error  (iBus_rsp_payload_error),
            .io_iBus_rsp_payload_inst   (iBus_rsp_payload_inst),

            .io_dBus_cmd_valid          (dBus_cmd_valid),
            .io_dBus_cmd_ready          (dBus_cmd_ready),
            .io_dBus_cmd_payload_wr     (dBus_cmd_payload_wr),
            .io_dBus_cmd_payload_address(dBus_cmd_payload_address),
            .io_dBus_cmd_payload_data   (dBus_cmd_payload_data),
            .io_dBus_cmd_payload_size   (dBus_cmd_payload_size),

            .io_dBus_rsp_ready          (dBus_rsp_ready),
            .io_dBus_rsp_error          (dBus_rsp_error),
            .io_dBus_rsp_data           (dBus_rsp_data),

            .io_timerInterrupt          (1'b0),
            .io_externalInterrupt       (1'b0)
        );

    always @(posedge clk) begin
        iBus_rsp_valid  <= iBus_cmd_valid;
    end

    assign iBus_cmd_ready           = 1'b1;
    assign iBus_rsp_payload_error   = 1'b0;

`ifdef JTAG_UART
    assign dBus_cmd_ready           = jtag_uart_sel ? jtag_uart_dBus_cmd_ready : 1'b1;
`else
    assign dBus_cmd_ready           = 1'b1;
`endif
    assign dBus_rsp_error           = 1'b0;

    wire [31:0] dBus_wdata;
    assign dBus_wdata = dBus_cmd_payload_data;

    wire [3:0] dBus_be;
    assign dBus_be    = (dBus_cmd_payload_size == 2'd0) ? (4'b0001 << dBus_cmd_payload_address[1:0]) : 
                        (dBus_cmd_payload_size == 2'd1) ? (4'b0011 << dBus_cmd_payload_address[1:0]) : 
                                                           4'b1111;

    reg [31:0] mem_rdata;

    wire [3:0] mem_wr;
    assign mem_wr = {4{dBus_cmd_valid && !dBus_cmd_payload_address[31] && dBus_cmd_payload_wr}} & dBus_be;

    // Instead of inferring 1 32-bit wide RAM with 4 byte enables, infer
    // 4 8-bit wide RAMs. Many synthesis tools have issues with inferring RAMs with byte enables. 
    // Quartus, for example, only supports them with SystemVerilog, not
    // regular Verilog.

    reg [7:0] mem0[0:mem_size_bytes/4-1];
    reg [7:0] mem1[0:mem_size_bytes/4-1];
    reg [7:0] mem2[0:mem_size_bytes/4-1];
    reg [7:0] mem3[0:mem_size_bytes/4-1];

    initial begin
        $readmemh("../sw/progmem0.hex", mem0);
        $readmemh("../sw/progmem1.hex", mem1);
        $readmemh("../sw/progmem2.hex", mem2);
        $readmemh("../sw/progmem3.hex", mem3);
    end

    ////////////
    // VROOM //
    //////////
    wire vroom_uart_rx;
    wire vroom_uart_tx;
    vroom_system u0 (
		.clk_clk                    (clk),                    //             clk.clk
		.reset_reset_n              (!reset & go_r),              //           reset.reset_n
		.vroom_0_uart_rx_new_signal (vroom_uart_rx), // vroom_0_uart_rx.new_signal
		.vroom_0_uart_tx_new_signal (vroom_uart_tx)  // vroom_0_uart_tx.new_signal
	);

//==============================================================================
// PCIe

wire [31:0] pcie_test_in;
assign pcie_test_in[0] = 1'b0;
assign pcie_test_in[4:1] = 4'b1000;
assign pcie_test_in[5] = 1'b0;
assign pcie_test_in[31:6] = 26'h2;

wire pcie_cpu_npor;

//==============================================================================
// qsys

    pcie_system u1 (
		.pcie1_refclk_clk              (CLK_PCIE1),              //     pcie1_refclk.clk
		.pcie1_npor_npor               (PCIE1_PERSTN),               //       pcie1_npor.npor
		.pcie1_npor_pin_perst          (PCIE1_PERSTN),          //                 .pin_perst
		.clk_125_clk                   (clk),                   //          clk_125.clk
		.rst_125_reset_n               (!reset),               //          rst_125.reset_n
		.pcie1_hip_ctrl_test_in        (pcie_test_in),        //   pcie1_hip_ctrl.test_in
		.pcie1_hip_ctrl_simu_mode_pipe (), //                 .simu_mode_pipe
		.pcie1_hip_serial_rx_in0       (PCIE1_SERIAL_RX[0]),       // pcie1_hip_serial.rx_in0
		.pcie1_hip_serial_rx_in1       (PCIE1_SERIAL_RX[1]),       //                 .rx_in1
		.pcie1_hip_serial_rx_in2       (PCIE1_SERIAL_RX[2]),       //                 .rx_in2
		.pcie1_hip_serial_rx_in3       (PCIE1_SERIAL_RX[3]),       //                 .rx_in3
		.pcie1_hip_serial_rx_in4       (PCIE1_SERIAL_RX[4]),       //                 .rx_in4
		.pcie1_hip_serial_rx_in5       (PCIE1_SERIAL_RX[5]),       //                 .rx_in5
		.pcie1_hip_serial_rx_in6       (PCIE1_SERIAL_RX[6]),       //                 .rx_in6
		.pcie1_hip_serial_rx_in7       (PCIE1_SERIAL_RX[7]),       //                 .rx_in7
		.pcie1_hip_serial_tx_out0      (PCIE1_SERIAL_TX[0]),      //                 .tx_out0
		.pcie1_hip_serial_tx_out1      (PCIE1_SERIAL_TX[1]),      //                 .tx_out1
		.pcie1_hip_serial_tx_out2      (PCIE1_SERIAL_TX[2]),      //                 .tx_out2
		.pcie1_hip_serial_tx_out3      (PCIE1_SERIAL_TX[3]),      //                 .tx_out3
		.pcie1_hip_serial_tx_out4      (PCIE1_SERIAL_TX[4]),      //                 .tx_out4
		.pcie1_hip_serial_tx_out5      (PCIE1_SERIAL_TX[5]),      //                 .tx_out5
		.pcie1_hip_serial_tx_out6      (PCIE1_SERIAL_TX[6]),      //                 .tx_out6
		.pcie1_hip_serial_tx_out7      (PCIE1_SERIAL_TX[7]),      //                 .tx_out7
        .pcie2_refclk_clk              (CLK_PCIE2),              //     pcie2_refclk.clk
		.pcie2_npor_npor               (PCIE2_PERSTN),               //       pcie2_npor.npor
		.pcie2_npor_pin_perst          (PCIE2_PERSTN),          //                 .pin_perst
		.pcie2_hip_ctrl_test_in        (pcie_test_in),        //   pcie2_hip_ctrl.test_in
		.pcie2_hip_ctrl_simu_mode_pipe (), //                 .simu_mode_pipe
		.pcie2_hip_serial_rx_in0       (PCIE2_SERIAL_RX[0]),       // pcie2_hip_serial.rx_in0
		.pcie2_hip_serial_rx_in1       (PCIE2_SERIAL_RX[1]),       //                 .rx_in1
		.pcie2_hip_serial_rx_in2       (PCIE2_SERIAL_RX[2]),       //                 .rx_in2
		.pcie2_hip_serial_rx_in3       (PCIE2_SERIAL_RX[3]),       //                 .rx_in3
		.pcie2_hip_serial_rx_in4       (PCIE2_SERIAL_RX[4]),       //                 .rx_in4
		.pcie2_hip_serial_rx_in5       (PCIE2_SERIAL_RX[5]),       //                 .rx_in5
		.pcie2_hip_serial_rx_in6       (PCIE2_SERIAL_RX[6]),       //                 .rx_in6
		.pcie2_hip_serial_rx_in7       (PCIE2_SERIAL_RX[7]),       //                 .rx_in7
		.pcie2_hip_serial_tx_out0      (PCIE2_SERIAL_TX[0]),      //                 .tx_out0
		.pcie2_hip_serial_tx_out1      (PCIE2_SERIAL_TX[1]),      //                 .tx_out1
		.pcie2_hip_serial_tx_out2      (PCIE2_SERIAL_TX[2]),      //                 .tx_out2
		.pcie2_hip_serial_tx_out3      (PCIE2_SERIAL_TX[3]),      //                 .tx_out3
		.pcie2_hip_serial_tx_out4      (PCIE2_SERIAL_TX[4]),      //                 .tx_out4
		.pcie2_hip_serial_tx_out5      (PCIE2_SERIAL_TX[5]),      //                 .tx_out5
		.pcie2_hip_serial_tx_out6      (PCIE2_SERIAL_TX[6]),      //                 .tx_out6
		.pcie2_hip_serial_tx_out7      (PCIE2_SERIAL_TX[7]),      //                 .tx_out7
		.uart_conduit_rxd              (vroom_uart_tx),              //     uart_conduit.rxd
		.uart_conduit_txd              (vroom_uart_rx)               //                 .txd
	);


    //============================================================
    // CPU memory instruction read port
    //============================================================

    always @(posedge clk) begin 
        iBus_rsp_payload_inst[ 7: 0]  <= mem0[iBus_cmd_payload_pc[mem_addr_bits-1:2]];
        iBus_rsp_payload_inst[15: 8]  <= mem1[iBus_cmd_payload_pc[mem_addr_bits-1:2]];
        iBus_rsp_payload_inst[23:16]  <= mem2[iBus_cmd_payload_pc[mem_addr_bits-1:2]];
        iBus_rsp_payload_inst[31:24]  <= mem3[iBus_cmd_payload_pc[mem_addr_bits-1:2]];
    end

    //============================================================
    // CPU memory data read/write port
    //============================================================

    // Quartus can be very picky about how RTL should structured to infer a true dual-ported RAM...
    always @(posedge clk) begin
        if (mem_wr[0]) begin
            mem0[dBus_cmd_payload_address[mem_addr_bits-1:2]]    <= dBus_wdata[ 7: 0];
            mem_rdata[ 7: 0]  <= dBus_wdata[ 7: 0];
        end
        else 
            mem_rdata[ 7: 0]  <= mem0[dBus_cmd_payload_address[mem_addr_bits-1:2]];

        if (mem_wr[1]) begin
            mem1[dBus_cmd_payload_address[mem_addr_bits-1:2]]    <= dBus_wdata[15: 8];
            mem_rdata[15: 8]  <= dBus_wdata[15: 8];
        end
        else 
            mem_rdata[15: 8]  <= mem1[dBus_cmd_payload_address[mem_addr_bits-1:2]];

        if (mem_wr[2]) begin
            mem2[dBus_cmd_payload_address[mem_addr_bits-1:2]]    <= dBus_wdata[23:16];
            mem_rdata[23:16]  <= dBus_wdata[23:16];
        end
        else 
            mem_rdata[23:16]  <= mem2[dBus_cmd_payload_address[mem_addr_bits-1:2]];

        if (mem_wr[3]) begin
            mem3[dBus_cmd_payload_address[mem_addr_bits-1:2]]    <= dBus_wdata[31:24];
            mem_rdata[31:24]  <= dBus_wdata[31:24];
        end
        else 
            mem_rdata[31:24]  <= mem3[dBus_cmd_payload_address[mem_addr_bits-1:2]];
    end

    //============================================================
    // Non-memory data accesses
    //============================================================

    wire periph_sel;
    assign periph_sel       =  dBus_cmd_valid && (dBus_cmd_payload_address[31:28] == 4'h8);

`ifdef JTAG_UART
    wire jtag_uart_sel;
    assign jtag_uart_sel    =  dBus_cmd_valid && (dBus_cmd_payload_address[31:28] == 4'h9);
`endif

    //============================================================
    // Peripherals
    //============================================================

    reg [31:0]  periph_rdata;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            led0            <= 1'b1;
            led1            <= 1'b1;
            led2            <= 1'b1;
            periph_rdata    <= 32'd0;
            reset_enable <= 1'b0;
        end
        else if (periph_sel) begin

            // LED register
            if (dBus_cmd_payload_address[periph_addr_bits-1:2] == (12'h000 >> 2)) begin
                if (dBus_cmd_payload_wr) begin
                    // LEDs are active low...
                    led0        <= !dBus_wdata[0];
                    led1        <= !dBus_wdata[1];
                    led2        <= !dBus_wdata[2];
                end
                else begin
                    periph_rdata        <= 'd0;
                    periph_rdata[0]     <= !led0;
                    periph_rdata[1]     <= !led1;
                    periph_rdata[2]     <= !led2;
                end
            end

            // Status register
            if (dBus_cmd_payload_address[periph_addr_bits-1:2] == (12'h004 >> 2)) begin
                if (!dBus_cmd_payload_wr) begin
                    periph_rdata[0]     <= button_sync[1];

                    // I don't want to compile different 2 SW version for
                    // simulation and HW, so this status bit can be used by 
                    // the SW on which platform it's running.
`ifdef SIMULATION
                    periph_rdata[1]     <= 1'b1;
`else
                    periph_rdata[1]     <= 1'b0;
`endif

`ifdef JTAG_UART
                    periph_rdata[2]     <= 1'b1;
`else
                    periph_rdata[2]     <= 1'b0;
`endif
                end
            end
        end
    end

    always @(posedge clk) begin
        // System reset register
        go_r <= (periph_sel && (dBus_cmd_payload_address[periph_addr_bits-1:2] == (12'h008 >> 2))) ? 1'b1 : go_r;
    end

    reg periph_rd_done;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            periph_rd_done  <= 1'b0;
        end
        else begin
            // Peripherals don't have a wait state, so rdata is always the
            // cycle after the request.
            periph_rd_done  <= periph_sel && !dBus_cmd_payload_wr;
        end
    end

    reg [1:0] button_sync;

    always @(posedge clk) begin
        // double FF synchronizer
        button_sync <= { button_sync[0], button };
    end

    //============================================================
    // Merge read paths
    //============================================================

    reg mem_rd_done;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_rd_done     <= 1'b0;
        end
        else begin
`ifdef JTAG_UART
            mem_rd_done     <= dBus_cmd_valid && !dBus_cmd_payload_wr && !(periph_sel || jtag_uart_sel);
`else
            mem_rd_done     <= dBus_cmd_valid && !dBus_cmd_payload_wr && !(periph_sel);
`endif
        end
    end

    assign dBus_rsp_ready  = mem_rd_done || periph_rd_done || jtag_uart_rd_done || spart_readdatavalid;

    assign dBus_rsp_data = periph_rd_done    ? periph_rdata : 
                           jtag_uart_rd_done ? jtag_uart_rdata :
                           spart_readdatavalid ? spart_readdata :
                                               mem_rdata;

    //============================================================
    // Optional JTAG UART
    //============================================================

    reg         jtag_uart_rd_done;
    reg [31:0]  jtag_uart_rdata;

`ifdef JTAG_UART
    wire        jtag_uart_cs;
    wire        jtag_uart_addr;
    wire        jtag_uart_waitrequest;
    wire        jtag_uart_write;
    wire [31:0] jtag_uart_wdata;
    wire        jtag_uart_read;
    wire [31:0] jtag_uart_readdata;

    wire        jtag_uart_dBus_cmd_ready;

    // JTAG UART has only 2 addresses. Map it to addresses 0x08 and 0x0C
    // Notice how I check the address down to bit 3 instead of bit 2 for 
    // the other registers!
    assign jtag_uart_cs         = jtag_uart_sel;
    assign jtag_uart_addr       = dBus_cmd_payload_address[2];
    assign jtag_uart_read       = !dBus_cmd_payload_wr;
    assign jtag_uart_write      = dBus_cmd_payload_wr;
    assign jtag_uart_wdata      = dBus_cmd_payload_data;

    assign jtag_uart_dBus_cmd_ready = !jtag_uart_waitrequest;

    always @(posedge clk) begin
        jtag_uart_rd_done <= 1'b0;
        if (jtag_uart_cs && jtag_uart_read && !jtag_uart_waitrequest) begin
            jtag_uart_rdata     <= jtag_uart_readdata;
            jtag_uart_rd_done   <= 1'b1;
        end
    end

	jtag_uart u_jtag_uart (
		.clk_clk        (clk),
		.reset_reset_n  (!reset),
		.av_chipselect  (jtag_uart_cs),
		.av_waitrequest (jtag_uart_waitrequest),
		.av_address     (jtag_uart_addr),
		.av_read_n      (!jtag_uart_read),
		.av_readdata    (jtag_uart_readdata),
		.av_write_n     (!jtag_uart_write),
		.av_writedata   (jtag_uart_wdata),
		.irq_irq        ()
	);
`else
    always @(dBus_cmd_valid) begin
        jtag_uart_rd_done = 1'b0;
        jtag_uart_rdata   = 32'd0;
    end
`endif

    //============================================================
    // SPART
    //============================================================
    spart iSPART (
        .clk(clk),
        .rst_n(!reset),
        .s_waitrequest(), // unused
        .s_readdata(spart_readdata),
        .s_readdatavalid(spart_readdatavalid),
        .s_response(), // unused
        .s_writeresponsevalid(), // unused
        .bus_burstcount(5'h0),
        .bus_writedata(dBus_cmd_payload_data),
        .bus_address(dBus_cmd_payload_address[31:2]),
        .bus_write(dBus_cmd_payload_wr),
        .bus_read(!dBus_cmd_payload_wr),
        .bus_byteenable(4'hF),
        .TX(),
        .RX(vroom_uart_tx),
        .all_done()
    );

endmodule

