`timescale 1ns / 1ps
`default_nettype none
module CoreWrapper #(
	parameter SIMULATION = 0	
)(
	input  wire clk,
	input  wire rst,
	input  wire [63:0] irqs,
	input  wire 	   av_waitrequest,
	input  wire [31:0] av_readdata,
	input  wire 	   av_readdatavalid,
	input  wire [ 1:0] av_response,
	input  wire        av_writeresponsevalid,
	output wire [ 4:0] av_burstcount,
	output wire [31:0] av_writedata,
	output wire [31:0] av_address,
	output wire        av_write,
	output wire 	   av_read,
	output wire [ 3:0] av_byteenable,
	output wire 	   uart_tx,
	input  wire 	   uart_rx
);
	reg bus_waitrequest_local;
	reg [31:0] bus_readdata_local;
	reg bus_readdatavalid_local;
	reg [1:0] bus_response_local;
	reg bus_writeresponsevalid_local;

	wire [31:0] lsic_badAddr;
	wire lsic_badAddrAck;
	wire lsic_badAddrValid;

	///////////////////
	// Bluespec CPU //
	/////////////////
	wire 		 reqValid;
	wire 		 reqReady;
	wire [3:0]   reqByteStrobe;
	wire 		 reqLineEn;
	wire [29:0]  reqAddr;
	wire [511:0] reqData;

	wire [511:0] respData;
	wire 		 respValid;
	wire 		 respReady;

	wire cpu_buserror;
	wire cpu_irq;

	mkVROOM iCORE (
		.CLK(clk),
		.RST_N(~rst),
		.EN_getBusReq(reqReady),
		.getBusReq({reqByteStrobe, reqLineEn, reqAddr, reqData}),
		.RDY_getBusReq(reqValid),
		
		.putBusResp_r(respData),
		.EN_putBusResp(respValid),
		.RDY_putBusResp(respReady),
		.putIrq_irq(cpu_irq),
		.putBusError_busError(cpu_buserror)
	);

	/////////////////////
	// CPU bus master //
	///////////////////
	wire [29:0] cpu_address;
	wire cpu_write;
	wire cpu_read;
	wire [31:0] cpu_writedata;
	wire [4:0] cpu_burstcount;
	wire [3:0] cpu_byteenable;

	CpuBusMaster iCPU_MASTER (
		.clk(clk),
		.rst_n(~rst),
		.cpu_reqValid(reqValid),
		.cpu_reqReady(reqReady),
		.cpu_reqByteStrobe(reqByteStrobe),
		.cpu_reqLineEn(reqLineEn),
		.cpu_reqAddr(reqAddr),
		.cpu_reqData(reqData),
		.cpu_respData(respData),
		.cpu_respValid(respValid),
		.cpu_respReady(respReady),
		.lsic_badAddr(lsic_badAddr),
		.lsic_badAddrValid(lsic_badAddrValid),
		.lsic_badAddrAck(lsic_badAddrAck),
		.bus_m_waitrequest(bus_waitrequest_local),
		.bus_m_readdata(bus_readdata_local),
		.bus_m_readdatavalid(bus_readdatavalid_local),
		.bus_m_writeresponsevalid(bus_writeresponsevalid_local),
		.bus_m_response(bus_response_local),
		.bus_m_burstcount(cpu_burstcount),
		.bus_m_writedata(cpu_writedata),
		.bus_m_address(cpu_address),
		.bus_m_write(cpu_write),
		.bus_m_read(cpu_read),
		.bus_m_byteenable(cpu_byteenable)
	);

	assign av_address = {cpu_address, 2'h0};
	assign av_writedata = cpu_writedata;
	assign av_write = cpu_write;
	assign av_read = cpu_read;
	assign av_byteenable = cpu_byteenable;
	assign av_burstcount = cpu_burstcount;

	/////////////////
	// LSIC slave //
	///////////////
	wire lsic_s_waitrequest;
	wire [31:0] lsic_s_readdata;
	wire lsic_s_readdatavalid;
	wire [1:0] lsic_s_response;
	wire lsic_s_writeresponsevalid;

	LSIC iLSIC (
		.clk(clk),
		.rst_n(~rst),
		.irqs(irqs),
		.badAddr(lsic_badAddr),
		.badAddrValid(lsic_badAddrValid),
		.badAddrAck(lsic_badAddrAck),
		.cpu_irq(cpu_irq),
		.cpu_buserror(cpu_buserror),
		.s_waitrequest(lsic_s_waitrequest),
		.s_readdata(lsic_s_readdata),
		.s_readdatavalid(lsic_s_readdatavalid),
		.s_response(lsic_s_response),
		.s_writeresponsevalid(lsic_s_writeresponsevalid),
		.bus_burstcount(cpu_burstcount),
		.bus_writedata(cpu_writedata),
		.bus_address(cpu_address),
		.bus_write(cpu_write),
		.bus_read(cpu_read),
		.bus_byteenable(cpu_byteenable)
	);

	/////////////////
	// UART slave //
	///////////////
	wire uart_s_waitrequest;
	wire [31:0] uart_s_readdata;
	wire uart_s_readdatavalid;
	wire [1:0] uart_s_response;
	wire uart_s_writeresponsevalid;
	wire uart_all_done;

	spart2 iSPART (
		.clk(clk),
		.rst_n(~rst),
		.s_waitrequest(uart_s_waitrequest),
		.s_readdata(uart_s_readdata),
		.s_readdatavalid(uart_s_readdatavalid),
		.s_response(uart_s_response),
		.s_writeresponsevalid(uart_s_writeresponsevalid),
		.bus_burstcount(cpu_burstcount),
		.bus_writedata(cpu_writedata),
		.bus_address(cpu_address),
		.bus_write(cpu_write),
		.bus_read(cpu_read),
		.bus_byteenable(cpu_byteenable),
		.TX(uart_tx),
		.RX(uart_rx),
		.all_done(uart_all_done)
	);

	//////////////////////////////////
	// Simulation print/exit slave //
	////////////////////////////////
	wire simdebug_s_waitrequest;
	wire [31:0] simdebug_s_readdata;
	wire simdebug_s_readdatavalid;
	wire [1:0] simdebug_s_response;
	wire simdebug_s_writeresponsevalid;
	wire simdebug_addr_check;
	generate if (SIMULATION) begin
		assign simdebug_addr_check = (av_address[31:28] == 4'hE) && ($test$plusargs("a4x") == 0);

		SimDebugSlave iDEBUG (
			.clk_i(clk),
			.rst_i(rst),
			.uart_all_done(uart_all_done),
			.bus_burstcount(cpu_burstcount),
			.bus_writedata(cpu_writedata),
			.bus_address(av_address),
			.bus_write(cpu_write),
			.bus_read(cpu_read),
			.bus_byteenable(cpu_byteenable),
			.s_readdata(simdebug_s_readdata),
			.s_readdatavalid(simdebug_s_readdatavalid),
			.s_waitrequest(simdebug_s_waitrequest),
			.s_writeresponsevalid(simdebug_s_writeresponsevalid),
			.s_response(simdebug_s_response)
		);
	end else begin
		assign simdebug_addr_check = 1'b0;
		// This is just there to make the compiler happy. 
		// A write/read to this address will deadlock the system due to lack of response!
		assign simdebug_s_waitrequest = 0;
		assign simdebug_s_readdata = 0;
		assign simdebug_s_readdatavalid = 0;
		assign simdebug_s_response = 0;
		assign simdebug_s_writeresponsevalid = 0;
	end endgenerate
	
	//////////////////////////
	// Connect bus signals //
	////////////////////////

	wire no_match_w = 
		av_address[31:15] != 17'h0 	// DRAM
		&& av_address[31:5] != {24'hf80300, 3'h0}
		&& av_address[31:16] != {16'hFFFE} // ROM
		&& av_address[31:10] != {20'hF8000, 2'b00} // Citron
		&& !simdebug_addr_check;
	reg no_match_r;

	always @(posedge clk)
		no_match_r <= no_match_w;

	always @* begin
		if (no_match_w) begin
			bus_waitrequest_local = 1'b0;
			bus_readdata_local = 0;
			bus_readdatavalid_local = 1'b1;
			bus_writeresponsevalid_local = 1'b1;
			bus_response_local = 2'b00;
		end else begin
			bus_waitrequest_local = lsic_s_waitrequest | av_waitrequest | simdebug_s_waitrequest | uart_s_waitrequest;
			bus_readdata_local = lsic_s_readdata | av_readdata | simdebug_s_readdata | uart_s_readdata;
			bus_readdatavalid_local = lsic_s_readdatavalid | av_readdatavalid | simdebug_s_readdatavalid | uart_s_readdatavalid;
			bus_response_local = lsic_s_response | av_response | simdebug_s_response | uart_s_response;
			bus_writeresponsevalid_local = lsic_s_writeresponsevalid | av_writeresponsevalid | simdebug_s_writeresponsevalid | uart_s_writeresponsevalid;
		end
	end	
endmodule

module CpuBusMaster (
	input  wire clk,
	input  wire rst_n,

	input  wire 		cpu_reqValid,
	output wire 		cpu_reqReady,
	input  wire [  3:0] cpu_reqByteStrobe,
	input  wire 		cpu_reqLineEn,
	input  wire [ 29:0] cpu_reqAddr,
	input  wire [511:0] cpu_reqData,

	output wire 		cpu_respValid,
	input  wire			cpu_respReady,
	output wire [511:0] cpu_respData,

	output wire [31:0] lsic_badAddr,
	output wire        lsic_badAddrValid,
	input  wire        lsic_badAddrAck,

	input  wire 	   bus_m_waitrequest,
	input  wire [31:0] bus_m_readdata,
	input  wire 	   bus_m_readdatavalid,
	input  wire [ 1:0] bus_m_response,
	input  wire        bus_m_writeresponsevalid,
	output wire [ 4:0] bus_m_burstcount,
	output wire [31:0] bus_m_writedata,
	output wire [29:0] bus_m_address,
	output wire 	   bus_m_write,
	output wire 	   bus_m_read,
	output wire [3:0]  bus_m_byteenable
);

	localparam [1:0] IDLE       = 2'h0;
	localparam [1:0] TRX   		= 2'h2;
	localparam [1:0] READ_RESP  = 2'h3;

	reg [1:0] state_r;
	reg [1:0] state_rw;

	reg [511:0] data_r;
	reg [511:0] data_rw;

	reg cpu_reqWe_r;
	reg cpu_reqWe_rw;

	reg reqReady_rw;
	reg respValid_rw;
	reg respValid_r;

	reg first_beat_r;
	reg first_beat_rw;

	reg badAddrValid_r;
	reg badAddrValid_rw;

	reg [4:0] outstanding_responses_r;
	reg [4:0] outstanding_responses_rw;

	reg [4:0] bus_m_burstcount_r;
	reg [29:0] bus_m_address_r;
	reg bus_m_write_r;
	reg bus_m_read_r;
	reg [3:0] bus_m_byteenable_r;

	reg [4:0] bus_m_burstcount_rw;
	reg [29:0] bus_m_address_rw;
	reg bus_m_write_rw;
	reg bus_m_read_rw;
	reg [3:0] bus_m_byteenable_rw;

	always @(posedge clk) begin
		if (!rst_n) begin
			state_r <= IDLE;
			data_r <= 0;
			cpu_reqWe_r <= 0;
			respValid_r <= 0;
			first_beat_r <= 0;
			badAddrValid_r <= 0;
			outstanding_responses_r <= 0;
		end else begin
			state_r <= state_rw;
			data_r <= data_rw;
			cpu_reqWe_r <= cpu_reqWe_rw;
			respValid_r <= respValid_rw;
			first_beat_r <= first_beat_rw;
			badAddrValid_r <= badAddrValid_rw;
			outstanding_responses_r <= outstanding_responses_rw;
		end
	end

	wire cpu_reqWe_w;
	assign cpu_reqWe_w = |cpu_reqByteStrobe;

	always @(*) begin
		state_rw = state_r;
		data_rw = data_r;
		cpu_reqWe_rw = cpu_reqWe_r;
		respValid_rw = 0;
		reqReady_rw = 0;
		
		bus_m_burstcount_rw = 0;
		bus_m_write_rw = 0;
		bus_m_read_rw = 0;
		bus_m_address_rw = bus_m_address_r;
		bus_m_byteenable_rw = bus_m_byteenable_r;

		first_beat_rw = first_beat_r;
		// Count nmuber of responses remaining.
		// Response strobe = writeresponsevalid on write, readdatavalid on read.
		outstanding_responses_rw = |outstanding_responses_r ? 
			(outstanding_responses_r - (cpu_reqWe_r ? {4'h0, bus_m_writeresponsevalid} : {4'h0,bus_m_readdatavalid}))
			: 5'h0;
		// Has the LSIC acknowledged our bus error? Reset it.
		// Otherwise we listen for any errors (bus_m_response != 0) and use that as an enable signal.
		badAddrValid_rw = lsic_badAddrAck ? 1'h0 : (badAddrValid_r | ((cpu_reqWe_r ? bus_m_writeresponsevalid : bus_m_readdatavalid) & |bus_m_response));

		case (state_r)
			IDLE: begin
				// 1. There is a request from the CPU
				// 2. We are not waiting on any responses from the previous transaction
				// 3. Any errors in the previous transaction have been acknowledged by the LSIC.
				if (cpu_reqValid & ~|outstanding_responses_r & ~badAddrValid_r) begin
					reqReady_rw = 1;
					data_rw = cpu_reqData;
					bus_m_address_rw = cpu_reqAddr;
					bus_m_byteenable_rw = ~cpu_reqWe_w ? 4'hF : cpu_reqByteStrobe;
					bus_m_burstcount_rw = cpu_reqLineEn ? 5'h10 : 5'h1;
					outstanding_responses_rw = cpu_reqWe_w ? 5'h1 : bus_m_burstcount_rw;
					bus_m_read_rw = ~cpu_reqWe_w;	
					bus_m_write_rw = cpu_reqWe_w;
					cpu_reqWe_rw = cpu_reqWe_w;
					state_rw = TRX;
					first_beat_rw = 1;
				end
			end
			TRX: begin
				// The first transaction starts whenever waitrequest is deasserted.
				if (!bus_m_waitrequest) first_beat_rw = 0;
				// If
				// 1) we are writing and waitrequest is not asserted
				// 2) we are reading, the data is valid, and we have successfully made the first handshake (waitrequest was low; can be in the same cycle)
				// then we may move to the next beat.
				if (cpu_reqWe_r ? (!bus_m_waitrequest) : (bus_m_readdatavalid & !first_beat_rw)) begin
					data_rw = {bus_m_readdata, data_r[511:32]};
					bus_m_burstcount_rw = bus_m_burstcount_r - 1;
				end else begin
					bus_m_burstcount_rw = bus_m_burstcount_r;
				end
				// If there are no more bursts we are done.
				state_rw = |bus_m_burstcount_rw ? TRX : (cpu_reqWe_r ? IDLE : READ_RESP);
				// Read needs to go as it means we are making a request. Should stop after 1st handshake.
				bus_m_read_rw = first_beat_rw & bus_m_read_r;
				// Write on the other hand acts as a strobe signal for writedata. So we should keep it high until the last burst.
				bus_m_write_rw = |bus_m_burstcount_rw & bus_m_write_r;
			end
			READ_RESP: begin
				respValid_rw = cpu_respReady;
				state_rw = cpu_respReady ? IDLE : READ_RESP;
			end
		endcase
	end

	always @(posedge clk) begin
		if (!rst_n) begin
			bus_m_burstcount_r <= 0;
			bus_m_address_r <= 0;
			bus_m_write_r <= 0;
			bus_m_read_r <= 0;
			bus_m_byteenable_r <= 0;
		end else begin
			bus_m_burstcount_r <= bus_m_burstcount_rw;
			bus_m_address_r <= bus_m_address_rw;
			bus_m_write_r <= bus_m_write_rw;
			bus_m_read_r <= bus_m_read_rw;
			bus_m_byteenable_r <= bus_m_byteenable_rw;
		end
	end

	// bluespec takes these signals as an enable signal, 
	// so there is no handshake. if we keep them on all the 
	// time it will spam the rule, which we do not want.
	assign cpu_reqReady = reqReady_rw;
	assign cpu_respData = data_r;
	assign cpu_respValid = respValid_rw;

	assign lsic_badAddr = {bus_m_address_r, 2'h0};
	assign lsic_badAddrValid = badAddrValid_r;

	// probably starts from other end?
	assign bus_m_writedata = data_r[31:0];
	assign bus_m_burstcount = bus_m_burstcount_r;
	assign bus_m_address = bus_m_address_r;
	assign bus_m_write = bus_m_write_r;
	assign bus_m_read = bus_m_read_r;
	assign bus_m_byteenable = bus_m_byteenable_r;

endmodule

`default_nettype wire
