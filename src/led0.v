module led #(
    parameter integer CLOCK_FREQUENCY = 27_000_000,
    parameter integer INTERVAL_MS     = 500
) (
    input  wire       reset,
    input  wire       Clock,
    input  wire       serialin,
    input  wire       pushbtn,

    output wire [5:0] leds,
    output wire       serialout
);


    // ----------------------------------------------------------------
    // Interval timer constants
    // ----------------------------------------------------------------

    // Maximum counter value required to obtain INTERVAL_MS.
    localparam integer COUNT_MAX = (CLOCK_FREQUENCY / 1000 ) * INTERVAL_MS + 
                                   ((CLOCK_FREQUENCY % 1000) * INTERVAL_MS) / 1000 - 1;

    // Number of bits required to represent COUNT_MAX.
    localparam integer COUNT_BITS =
        $clog2(COUNT_MAX + 1);


    // ----------------------------------------------------------------
    // Interval timer state
    // ----------------------------------------------------------------

    reg [COUNT_BITS-1:0] interval_count;

    // Asserted for one Clock cycle whenever the interval counter rolls
    // over. This is a clock-enable/strobe, not another clock.
    reg interval_tick;


    // ----------------------------------------------------------------
    // LED state
    // ----------------------------------------------------------------

    reg led_state;



    // ----------------------------------------------------------------
    // LED outputs
    //
    // Two LEDs show the slow blink state.
    // The remaining four display the high-order counter bits.
    // ----------------------------------------------------------------

    assign leds[0] = led_state;
    assign leds[1] = ~led_state;

    assign leds[5:2] =
        ~interval_count[COUNT_BITS-1:COUNT_BITS-4];




    // ----------------------------------------------------------------
    // Interval timer
    //
    // interval_tick is asserted for exactly one Clock cycle whenever
    // interval_count reaches COUNT_MAX.
    // ----------------------------------------------------------------

    always @(posedge Clock) begin
        if (reset) begin
            interval_count <= 0;
            interval_tick  <= 1'b0;

        end else if (interval_count == COUNT_MAX) begin
            interval_count <= 0;
            interval_tick  <= 1'b1;

        end else begin
            interval_count <= interval_count + 1'b1;
            interval_tick  <= 1'b0;
        end
    end

    // ----------------------------------------------------------------
    // Blink the LEDs at the interval rate.
    // ----------------------------------------------------------------

    always @(posedge Clock) begin
        if (reset)
            led_state <= 1'b0;
        else if (interval_tick)
            led_state <= ~led_state;
    end

endmodule


// Gowin-generated IP expects the normal implicit-wire behavior.
`default_nettype wire
