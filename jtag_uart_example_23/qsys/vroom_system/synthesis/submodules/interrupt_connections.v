// dumb qsys workaround

module interrupt_connections (
    input clk,
    output wire [63:0] irqs
);

assign irqs = 64'h0;
endmodule