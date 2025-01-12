`timescale 1ns / 1ps
`default_nettype none
module LSIC (
    input wire clk,
    input wire rst_n,

    input wire [63:0] irqs,

    input wire [31:0] badAddr,
    input wire badAddrValid,
    output wire badAddrAck,

    output wire cpu_irq,
    output wire cpu_buserror,

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
    output wire [1:0] s_response
);

    reg [63:0] disa_r;
    reg [63:0] disa_rw;

    reg [63:0] pend_r;
    reg [63:0] pend_rw_pre;
    reg [63:0] pend_rw;

    reg [5:0] ipl_r;
    reg [5:0] ipl_rw;

    // TODO: i am not sure what the consequences of registering the IRQ line are.
    // The ISR will clear the interrupt lines on the device. How soon after it returns from
    // the ISR and re-enables interrupts is not known but seems relevant because if there is enough
    // latency, it will erroneously pick up the same interrupt.
    reg [6:0] claim_rw;
    reg [6:0] claim_ff1_r;
    reg [6:0] claim_ff2_r;

    always @(posedge clk) begin
        if (!rst_n) begin 
            disa_r <= 0;
            pend_r <= 0;
            ipl_r <= 0;
            claim_ff1_r <= 0;
            claim_ff2_r <= 0;
        end else begin
            disa_r <= disa_rw;
            pend_r <= pend_rw;
            ipl_r <= ipl_rw;
            claim_ff1_r <= claim_rw;
            claim_ff2_r <= claim_ff1_r;
        end
    end

    // Generate mask from ipl
    wire [64:0] ipl_mask_w = ~({1'b1, 64'h0} >> ({1'b0,~ipl_r} + 1)); 
    wire [63:0] pend_masked_w = pend_r & ipl_mask_w[63:0];

    // Interrupt resolution logic
    always @* begin
        claim_rw = 0;
        for (bit [6:0] i = 0; i < 64; i = i + 1) begin
            // 6th bit stores whether there is an interrupt already
            if (!claim_rw[6] && pend_masked_w[i[5:0]] && !disa_r[i[5:0]])
                claim_rw = {1'b1, i[5:0]};
        end
    end

    reg [32:0] badAddr_r;
    reg badAddrAck_r;

    reg badAddrClear_rw;

    always @(posedge clk) begin
        if (!rst_n) begin
            badAddr_r <= 0;
            badAddrAck_r <= 0;
        end else if (badAddrValid) begin
            badAddr_r <= {1'b1, badAddr};
            badAddrAck_r <= 1;
        end else if (badAddrClear_rw) begin
            badAddr_r <= 0;
            badAddrAck_r <= 0;
        end else begin
            badAddr_r <= badAddr_r;
            badAddrAck_r <= 0;
        end
    end

    // TODO: add some check that burstcount is never > 1, because this peripheral won't handle it
    reg s_responsevalid_rw;
    reg s_responsevalid_r;

    reg [1:0] s_response_rw;
    reg [1:0] s_response_r;

    reg [31:0] s_readdata_rw;
    reg [31:0] s_readdata_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            s_responsevalid_r <= 0;
            s_readdata_r <= 0;
            s_response_r <= 0;
        end else begin
            s_responsevalid_r <= s_responsevalid_rw;
            s_readdata_r <= s_readdata_rw;
            s_response_r <= s_response_rw;
        end
    end


    // Bottom 3 bits should be 0, we only care about the first LSIC
    wire is_my_transaction = bus_address[29:3] == {24'hf80300, 3'h0};
    wire start_transaction = (bus_read || bus_write);

    always @(*) begin
        s_responsevalid_rw = 0;
        s_readdata_rw = 0;
        s_response_rw = 0;
        badAddrClear_rw = 0;

        disa_rw = disa_r;
        pend_rw_pre = pend_r;
        pend_rw = pend_rw_pre | irqs;
        ipl_rw = ipl_r;

        if (is_my_transaction && start_transaction) begin
            if (bus_read) begin
                case (bus_address[5:0])
                    6'h00: s_readdata_rw = disa_r[31:0];
                    6'h01: s_readdata_rw = disa_r[63:32];
                    6'h02: s_readdata_rw = pend_r[31:0];
                    6'h03: s_readdata_rw = pend_r[63:32];
                    6'h04: s_readdata_rw = {26'h0, claim_ff2_r[5:0]};
                    6'h05: s_readdata_rw = {26'h0, ipl_r};
                    6'h08: begin s_readdata_rw = badAddr_r[31:0]; badAddrClear_rw = 1; end
                    default: s_response_rw = 2'b11;
                endcase
            end else begin
                case (bus_address[5:0]) 
                    6'h00: disa_rw = {disa_r[63:32], bus_writedata};
                    6'h01: disa_rw = {bus_writedata, disa_r[31:0]};
                    6'h02: pend_rw_pre = {pend_r[63:32], (bus_writedata == 0) ? 32'h0 : (bus_writedata | pend_r[31:0])};
                    6'h03: pend_rw_pre = {(bus_writedata == 0) ? 32'h0 : (bus_writedata | pend_r[63:32]), pend_r[31:0]};
                    6'h04: pend_rw_pre = pend_r & ~(1<<bus_writedata[5:0]);
                    6'h05: ipl_rw = bus_writedata[5:0];
                    default: s_response_rw = 2'b11;
                endcase
            end
            s_responsevalid_rw = 1;
        end
    end


    // never busy
    assign s_waitrequest = 1'b0;
    assign s_readdatavalid = s_responsevalid_r;
    assign s_writeresponsevalid = s_responsevalid_r;
    assign s_readdata = s_readdata_r;
    assign s_response = s_response_r;

    assign cpu_irq = claim_ff2_r[6];
    assign cpu_buserror = badAddr_r[32];

    assign badAddrAck = badAddrAck_r;

endmodule

`default_nettype wire