module UART_tx (
    input clk, rst_n,
    input queue_not_empty,
    input [7:0] tx_data,
    input [12:0] baud,
    output ready,
    output reg tx_started,
    output reg TX
);

logic [3:0] bit_cnt;
logic unsigned [12:0] baud_cnt;
logic [8:0] tx_shift_reg;

// SM/control signals
logic init, shift, transmitting;

// bit counter (counts to 10), increments after every bit
always_ff @(posedge clk) 
    case ({init,shift})
        2'b00 : bit_cnt <= bit_cnt;
        2'b01 : bit_cnt <= bit_cnt + 1;
        default : bit_cnt <= 3'h0; // 10 or 11
    endcase

// counts from baud to 0
always_ff @(posedge clk) 
    case ({init|shift,transmitting})
        2'b00 : baud_cnt <= baud_cnt;
        2'b01 : baud_cnt <= baud_cnt - 1;
        default : baud_cnt <= baud; // 10 or 11
    endcase

// initialize as tx_data with a zero at the end for start of transmission
// then shift register repeatedly for each TX bit until all bits are transmitted
always_ff @(posedge clk,negedge rst_n)
    if (!rst_n)
        tx_shift_reg <= 9'h1ff; // set
    else
        case ({init,shift})
            2'b00 : tx_shift_reg <= tx_shift_reg;
            2'b01 : tx_shift_reg <= {1'b1,tx_shift_reg[8:1]};
            default : tx_shift_reg <= {tx_data[7:0],1'b0}; // 10 or 11
        endcase

// synchronous SR flop logic for tx_started signal
// this is asserted once we have started the transaction so
// the queue knows when to decrement old pointer
always_ff @(posedge clk,negedge rst_n)
    if (!rst_n)
        tx_started <= 1'b0;
    else if (init)
        tx_started <= 1'b1;
    else
        tx_started <= 1'b0;

// TX is LSB of shifting register
assign TX = tx_shift_reg[0];
// shift goes high when count has reached 0
assign shift = baud_cnt == 0;

// STATE MACHINE LOGIC

typedef enum reg {IDLE, TRAN} TX_state_t;
TX_state_t state, nxt_state;

// sequential logic
always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;

// combinational logic (next state and output ctrl)
always_comb begin
    nxt_state = IDLE;
    init = 0;
    transmitting = 0;

    case (state) 
        IDLE:
        // as long as the queue is not empty we will keep consuming
        if (queue_not_empty) begin
            nxt_state = TRAN;
            init = 1;
        end
        default: begin
        // stay in TRAN until we have counted to 10 bits,
        // then transmission is over and we go to IDLE
        if (bit_cnt == 4'hA) begin
            nxt_state = IDLE;
        end else begin
            nxt_state = TRAN;
            transmitting = 1;
        end
        end
    endcase
end

assign ready = (state == IDLE);
    
endmodule