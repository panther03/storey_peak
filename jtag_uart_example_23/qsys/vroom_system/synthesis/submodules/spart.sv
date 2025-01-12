module spart2
(
    input clk,				      // 50MHz clk
    input rst_n,			      // asynch active low reset

    // Slave Input
    input wire [4:0] bus_burstcount,
    input wire [31:0] bus_writedata,
    input wire [29:0] bus_address,
    input wire bus_write,
    input wire bus_read,
    input wire [3:0] bus_byteenable,

    // Slave output
    output wire s_waitrequest,
    output wire [31:0] s_readdata,
    output wire s_readdatavalid,
    output wire s_writeresponsevalid,
    output wire [1:0] s_response,

    output all_done,

    output TX,				      // UART TX line
    input RX				      // UART RX line
);
/*
    reg [7:0] cmd_port_addr = 0;
    reg cmd_en = 0;
    reg cmd_wr = 0;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cmd_port_addr <= 8'h0;  
            cmd_en <= 1'b0;
            cmd_wr <= 1'b0;
        end else begin
            cmd_port_addr <= bus_addrData_i[9:2];
            // only enable when already disabled
            cmd_en <= ~cmd_en & bus_beginTransaction_i & (bus_addrData_i[23:20] == 4'hF);
            cmd_wr <= ~bus_readNWrite_i;
        end
    end

    localparam ADDR_DATABUF = 2'h0;
    localparam ADDR_DIVBUF = 2'h1;
    localparam ADDR_STATUS = 2'h2;
    localparam ADDR_LED = 2'h3;

    // Decode read/write request
    wire databuffer_reg_write = cmd_en && reg_addr == ADDR_DATABUF && cmd_wr;
    wire databuffer_reg_read = cmd_en && reg_addr == ADDR_DATABUF && ~cmd_wr;
    wire status_reg_read = cmd_en && reg_addr == ADDR_STATUS;
    wire divbuffer_reg_write = cmd_en && reg_addr == ADDR_DIVBUF && cmd_wr;
    wire led_write = cmd_en && (reg_addr ==  ADDR_LED) && cmd_wr;

    */

    // Flip Flop to store baud rate
    logic [12:0]DB;
    always_ff @(posedge clk,negedge rst_n) begin 
    if (!rst_n) 
        // configured for a 50mhz clock
        DB <= 13'h1B2;
    //else if (divbuffer_reg_write) begin // Write low bit
    //    DB <= bus_addrData_i[12:0];
    //end 
    else
        DB <= DB;
    end

    reg tx_enq_rw;
    reg tx_enq_r;
    reg rx_deq_rw;

    always @(posedge clk)
        if (!rst_n)
            tx_enq_r <= 0;
        else
            tx_enq_r <= tx_enq_rw;

// --------------- UART TX -------------------------
    wire tx_q_empty_n;
    wire rx_q_full_n;

    // Outgoing TX data
    logic [7:0] tx_data;

    // Specifies when TX has consumed data so old pointer can be incremented
    logic tx_started;
    logic tx_ready;

    // Instantiate UART TX
    UART_tx uart_tx (
    .clk(clk), .rst_n(rst_n), // input
    .queue_not_empty(tx_q_empty_n), // input
    .tx_data(tx_data), // input
    .baud(DB), // input
    .ready(tx_ready), // output
    .tx_started(tx_started), // output
    .TX(TX) // output
    );

    // Instantiate memory for TX queue
    logic [3:0] tx_old_ptr;
    logic [3:0] tx_new_ptr;
    queue tx_queue (.clk(clk), .enable(tx_enq_rw), .raddr(tx_old_ptr[2:0]), .waddr(tx_new_ptr[2:0]), .wdata(bus_writedata[31:24]), .rdata(tx_data));
    
    // New TX pointer register
    always_ff @(posedge clk,negedge rst_n)
        if (!rst_n) begin
            tx_new_ptr <= 4'h0;
        end else if (tx_enq_r) begin // Increment new pointer on write
            tx_new_ptr <= tx_new_ptr + 1;
        end else begin
            tx_new_ptr <= tx_new_ptr;
        end


    // TX old pointer register
    always_ff @(posedge clk,negedge rst_n)
        if (!rst_n) begin
            tx_old_ptr <= 4'h0;
        end else if (tx_started && tx_q_empty_n) begin // Increment old pointer after transmitting
            tx_old_ptr <= tx_old_ptr + 1;
        end else begin
            tx_old_ptr <= tx_old_ptr; 
        end
// --------------- END UART TX ---------------------


// --------------- UART RX -------------------------

    // Write to RX queue when new data is recieved and queue is not full
    logic new_data_ready;
    logic rx_queue_write;
    assign rx_queue_write = new_data_ready && rx_q_full_n;

    // Incoming RX Data
    logic [7:0] rx_data;

    // Instantiate UART RX
    UART_rx uart_rx (
    .clk(clk), .rst_n(rst_n), // input
    .RX(RX), // input
    .baud(DB), // input
    .rx_data(rx_data), // output
    .rdy(new_data_ready) // output
    );

    // Instantiate memory for RX queue
    logic [3:0] rx_old_ptr;
    logic [3:0] rx_new_ptr;
    logic [7:0] rx_queue_out;
    queue rx_queue (.clk(clk), .enable(rx_queue_write), .raddr(rx_old_ptr[2:0]), .waddr(rx_new_ptr[2:0]), .wdata(rx_data), .rdata(rx_queue_out));

    // RX new pointer register
    always_ff @(posedge clk,negedge rst_n)
        if (!rst_n) begin
            rx_new_ptr <= 4'h0;
        end else if (rx_queue_write) begin // Increment new pointer when new byte is available from ART
            rx_new_ptr <= rx_new_ptr + 1;
        end else begin
            rx_new_ptr <= rx_new_ptr;
        end



    // RX old pointer register
    always_ff @(posedge clk,negedge rst_n)
        if (!rst_n) begin
            rx_old_ptr <= 4'h0;
        end else if (rx_deq_rw) begin // Increment old pointer when data is read from SPART
            rx_old_ptr <= rx_old_ptr + 1;
        end else begin
            rx_old_ptr <= rx_old_ptr; 
        end


// --------------- END UART RX ---------------------

    // Track status of queue based on pointers
    wire tx_q_full  = (tx_old_ptr[2:0] == tx_new_ptr[2:0] && tx_old_ptr != tx_new_ptr);
    assign tx_q_empty_n = ~(tx_new_ptr[2:0] == tx_new_ptr[2:0] && tx_old_ptr == tx_new_ptr);
    wire rx_q_empty = (rx_old_ptr[2:0] == rx_new_ptr[2:0] && rx_old_ptr == rx_new_ptr);
    assign rx_q_full_n  = ~(rx_old_ptr[2:0] == rx_new_ptr[2:0] && rx_old_ptr != rx_new_ptr);


    // Fill status register
    logic [7:0] status_reg;
    assign status_reg[7:4] = tx_q_full ? 0 : 8 - (tx_new_ptr - tx_old_ptr); // Number of entries remaining in tx queue
    assign status_reg[3:0] = rx_q_empty ? 0 : rx_new_ptr - rx_old_ptr; // Number of entries filled in rq queue

    //reg led_r = 1'b0;
//
    //always @(posedge clk) begin
    //    led_r <= (rst_n) ? (led_write ? (bus_addrData_i[0]) : led_r) : 1'b0;
    //end
	// assign led = ~led_r;

    reg s_responsevalid_rw;
    reg s_responsevalid_r;

    reg [31:0] s_readdata_rw;
    reg [31:0] s_readdata_r;

    reg s_respsel_rw;
    reg s_respsel_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            s_responsevalid_r <= 0;
            s_readdata_r <= 0;
            s_respsel_r <= 0;
        end else begin
            s_responsevalid_r <= s_responsevalid_rw;
            s_readdata_r <= s_readdata_rw;
            s_respsel_r <= s_respsel_rw;
        end
    end

    wire is_my_transaction = bus_address[29:8] == 22'h3e0000;
    wire start_transaction = (bus_read || bus_write);

    always @(*) begin
        s_responsevalid_rw = 0;
        s_readdata_rw = 0;
        s_respsel_rw = 0;

        tx_enq_rw = 0;
        rx_deq_rw = 0;

        if (is_my_transaction && start_transaction) begin
            s_responsevalid_rw = 1'b1;
            if (bus_read) begin
                case (bus_address[7:0])
                    8'h10, 8'h12: begin
                        s_readdata_rw = {7'h0, tx_q_full, 24'h0};
                    end
                    8'h11, 8'h13: begin
                        if (rx_q_empty) begin
                            s_readdata_rw = {16'hffff, 16'h0};
                        end else begin
                            s_respsel_rw = 1'b1;
                            rx_deq_rw = 1'b1;
                        end
                    end
                    default: begin
                        s_readdata_rw = 0;
                    end
                endcase
            end else begin
                case (bus_address[7:0])
                    8'h11, 8'h13: begin
                        tx_enq_rw = ~tx_q_full;
                    end
                    default: begin end
                endcase
            end
        end
    end

    assign s_waitrequest = 1'b0;
    assign s_response = 2'h0;
    assign s_readdata = s_respsel_r ? {rx_data, 24'h0} : s_readdata_r;
    assign s_readdatavalid = s_responsevalid_r;
    assign s_writeresponsevalid = s_responsevalid_r;
    assign all_done = (~tx_q_empty_n) && tx_ready;
				   
endmodule
