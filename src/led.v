// Simple Tang Nano 20K example showing:
//
//   - Driving the onboard LEDs
//   - Reading an onboard pushbutton
//   - Synchronizing and debouncing an asynchronous input
//   - Using the Gowin UART Master IP
//   - Several simple sequential state machines
//
// The LEDs blink/count continuously.
//
// The bottom button (the end with the "TANG NANO 20K" silkscreen)
// resets the design.
//
// The other button:
//   - Sends '*' on the serial port
//   - Toggles an offset between 0 and 1
//
// Characters received through the UART are echoed back after adding
// the current offset. Therefore:
//
//      offset = 0:  'A' -> 'A'
//      offset = 1:  'A' -> 'B'
//
// For example, typing A three times, pressing the button, and then
// typing A three more times produces:
//
//      AAA*BBB
//
//
// Normally Verilog will happily accept a typo in a signal name and
// silently create a new implicit wire. For example, "clock" instead
// of "Clock" could compile successfully but create an undriven net.
//
// Disable implicit nets while compiling our code so these mistakes
// become errors.
//
// Gowin-generated IP assumes the normal Verilog default of implicit
// wire nets, so we restore `default_nettype wire at the end of this
// file.
//
// Note that this directive appears to affect the complete compilation,
// not merely the module in which it appears.

`default_nettype none

`define DEBUG




// --------------------------------------------------------------------
// Main example
//
// The CST file maps these top-level signals to the physical pins on
// the Tang Nano 20K.
// --------------------------------------------------------------------

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


// remove for production
`ifdef DEBUG
    wire bclock /* synthesis syn_keep = 1 */;  
    debug_clock(Clock,bclock);
// Stop removing
`endif 
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
    // UART state
    // ----------------------------------------------------------------

    // Character presented to the UART transmit holding register.
    reg [7:0] tx_char;

    // Pulsed high for one Clock cycle to write tx_char to the UART.
    reg tx_strobe;

    // Data returned by the UART read interface.
    wire [7:0] uart_rx_data;

    // UART receive-ready indication.
    wire uart_rx_ready_n;


    // ----------------------------------------------------------------
    // Pushbutton and echo state
    // ----------------------------------------------------------------

    // When set, add one to each received character before echoing it.
    reg add_offset;

    // Debounced pushbutton state.
    wire button;

    // Previous debounced pushbutton state, used for edge detection.
    reg button_prev;


    // ----------------------------------------------------------------
    // LED state
    // ----------------------------------------------------------------

    reg led_state;


    // ----------------------------------------------------------------
    // Synchronize and debounce the pushbutton
    // ----------------------------------------------------------------

    debounce #(
        .CLOCK_FREQUENCY (CLOCK_FREQUENCY),
        .DEBOUNCE_MS     (10)
    ) button_filter (
        .Clock        (Clock),
        .reset        (reset),
        .noisy_button (pushbtn),
        .clean_button (button)
    );


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
    // Gowin UART Master IP
    //
    // This UART block is intended to look like a peripheral accessed
    // by a processor through an SRAM-style register interface. For this
    // simple example, we bypass most of that interface.
    //
    // Both addresses are permanently set to zero:
    //
    //      write address 0 -> transmit holding register
    //      read  address 0 -> receive buffer register
    //
    // We also continuously read register zero and use RxRDYn to decide
    // when to process the receive data. This is not really the way the
    // register-oriented interface was intended to be used, but it keeps
    // this example simple.
    // ----------------------------------------------------------------

    UART_MASTER_Top uart (
        .I_CLK      (Clock),
        .I_RESETN   (~reset),

        // Transmit interface.
        .I_TX_EN    (tx_strobe),
        .I_WADDR    (3'b000),
        .I_WDATA    (tx_char),

        // Receive interface.
        .I_RX_EN    (~reset),
        .I_RADDR    (3'b000),
        .O_RDATA    (uart_rx_data),

        // Serial pins.
        .SIN        (serialin),
        .SOUT       (serialout),

        // Receive indication.
        .RxRDYn     (uart_rx_ready_n),

        // Unused UART/modem outputs.
        .TxRDYn     (),
        .DDIS       (),
        .INTR       (),
        .DTRn       (),
        .RTSn       (),

        // Hold unused modem inputs asserted.
        .CTSn       (1'b0),
        .DSRn       (1'b0),
        .RIn        (1'b0),
        .DCDn       (1'b0)
    );


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
    // UART transmit and pushbutton state
    //
    // tx_strobe normally remains low. When we have a character to send,
    // it goes high for one Clock cycle.
    //
    // A rising edge on the debounced pushbutton:
    //
    //      - toggles add_offset
    //      - sends '*'
    //
    // A received UART character is echoed after adding the current
    // offset.
    //
    // For simplicity, we assume the user will not press the button at
    // exactly the same time a serial character arrives, and will not
    // send characters fast enough to overrun this simple logic.
    // ----------------------------------------------------------------

    always @(posedge Clock) begin
        if (reset) begin
            tx_char     <= 8'h00;
            tx_strobe   <= 1'b0;
            add_offset  <= 1'b0;
            button_prev <= 1'b0;

        end else begin

            // Default state: do not write the UART.
            // Either condition below may override this for one cycle.
            tx_strobe <= 1'b0;


            // Detect a rising edge on the debounced pushbutton.
            if (button && !button_prev) begin
                add_offset <= ~add_offset;

                tx_char   <= 8'h2A;       // ASCII '*'
                tx_strobe <= 1'b1;
            end


            // Echo a received character, optionally adding one.
            if (!uart_rx_ready_n) begin
                tx_char <= uart_rx_data +
                           (add_offset ? 8'd1 : 8'd0);

                tx_strobe <= 1'b1;
            end


            // Save the current button state for edge detection on the
            // next Clock cycle.
            button_prev <= button;
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