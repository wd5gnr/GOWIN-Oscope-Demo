
`default_nettype none

// This is simply to generate a 16X baud clock so we can watch the serial ports

module debug_clock(input wire clk, output wire baudclk);
reg [6:0] div;
// We use syn_keep to prevent the optimizer from deleting this
reg gao_clk /* synthesis syn_keep = 1 */;  

assign baudclk=gao_clk;

localparam integer RATE=87;

always @(posedge clk) begin
    if (div == RATE) begin
        div     <= 0;
        gao_clk <= ~gao_clk;
    end else begin
        div <= div + 1'b1;
    end
end

endmodule

`default_nettype wire

