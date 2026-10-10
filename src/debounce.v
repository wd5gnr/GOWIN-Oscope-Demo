// --------------------------------------------------------------------
// Pushbutton synchronizer and debounce filter
//
// A mechanical pushbutton presents two separate problems:
//
//   1. The button is asynchronous to the FPGA clock. Sampling an
//      asynchronous signal directly can result in metastability.
//
//   2. Mechanical switch contacts bounce, producing several transitions
//      from what was intended to be a single press or release.
//
// The first two flip-flops form a conventional two-stage synchronizer.
//
// After synchronization, the input must remain different from the
// current debounced output for DEBOUNCE_MS before the new state is
// accepted. This filters bounce on both press and release.
// --------------------------------------------------------------------

module debounce #(
    parameter integer CLOCK_FREQUENCY = 27_000_000,
    parameter integer DEBOUNCE_MS     = 10
) (
    input  wire Clock,
    input  wire reset,
    input  wire noisy_button,
    output reg  clean_button
);

    // Number of clocks for which the new state must remain stable.
    //
    // Divide before multiplying to avoid overflowing a normal 32-bit
    // Verilog integer at typical FPGA clock frequencies.
    localparam integer DEBOUNCE_COUNT =
        (CLOCK_FREQUENCY / 1000) * DEBOUNCE_MS;

    localparam integer DEBOUNCE_BITS =
        $clog2(DEBOUNCE_COUNT + 1);


    // Two-stage synchronizer.
    reg sync_ff1;
    reg sync_ff2;

    // Counts how long the synchronized input has disagreed with the
    // current debounced output.
    reg [DEBOUNCE_BITS-1:0] debounce_count;


    // Synchronize the asynchronous input to Clock.
    always @(posedge Clock) begin
        if (reset) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= noisy_button;
            sync_ff2 <= sync_ff1;
        end
    end


    // Debounce the synchronized input.
    always @(posedge Clock) begin
        if (reset) begin
            clean_button  <= 1'b0;
            debounce_count <= 0;

        end else if (sync_ff2 == clean_button) begin

            // The input agrees with the current debounced state, so
            // there is no pending state change.
            debounce_count <= 0;

        end else if (debounce_count == DEBOUNCE_COUNT - 1) begin

            // The input has remained at its new value for the entire
            // debounce interval. Accept the new state.
            clean_button   <= sync_ff2;
            debounce_count <= 0;

        end else begin

            // The input disagrees with the current output, but it has
            // not remained stable long enough yet.
            debounce_count <= debounce_count + 1'b1;
        end
    end

endmodule