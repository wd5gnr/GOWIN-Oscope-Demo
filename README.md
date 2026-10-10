# GOWIN Oscilloscope Demo

This is a simple demo project for the **Sipeed Tang Nano 20K** intended to demonstrate the **GOWIN Analyzer Oscilloscope (GAO)** built into the GOWIN FPGA development tools.

The design is deliberately small and easy to probe. It includes a few useful signals and peripherals so you can experiment with GAO triggers and captured waveforms without needing a complicated FPGA design first.

The example includes:

- The Tang Nano 20K's 27 MHz system clock
- Onboard LEDs
- Onboard pushbuttons
- Pushbutton synchronization and debouncing
- A simple counter/timer
- The GOWIN UART Master IP
- A UART echo example that can optionally add one to received characters
- GAO configuration files for observing internal signals

The project is meant primarily as a demonstration and companion to the Hackaday article and video below, rather than as a general-purpose design.

## More Information

- **Hackaday post:** https://wp.me/paBn4l-4SO4
- **YouTube video:** https://youtu.be/lCpx0hGkbnA

## Hardware

- Sipeed Tang Nano 20K

## Tools

- GOWIN FPGA Designer
- GOWIN Analyzer Oscilloscope

Open `gowin_blink.gprj` in the GOWIN IDE to load the project.
