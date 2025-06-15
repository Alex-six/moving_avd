`timescale 1ns/1ps

module tb_moving_average;
    reg clk;
    reg rst_n;
    reg enable;
    reg data_refresh;
    reg [15:0] din;
    reg [2:0] mode;
    reg output_refresh_mode;
    wire [15:0] dout;
    wire output_pulse;

    // Instantiate DUT (moving_average_v5)
    moving_average_v4 uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .data_refresh(data_refresh),
        .output_refresh_mode(output_refresh_mode),
        .din(din),
        .mode(mode),
        .dout(dout),
        .output_pulse(output_pulse)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        enable = 0;
        data_refresh = 0;
        output_refresh_mode = 0;
        din = 0;
        mode = 0;
        #20;

        // Release reset
        rst_n = 1;
        enable = 1;
        #10;

        // Test output_refresh_mode = 1 (output every calculation)
        output_refresh_mode = 1;
        mode = 3'b000;
        for (integer i=1; i<=3; i=i+1) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Refresh Mode 1: din=%d, dout=%d, pulse=%b", din, dout, output_pulse);
        end
        output_refresh_mode = 0;
        #20;

        // Test mode 0: no averaging
        mode = 3'b000;
        for (integer i=1; i<=5; i=i+1) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Mode 0: din=%d, dout=%d", din, dout);
        end

        // Test mode 1: 2-point average
        mode = 3'b001;
        for (integer i=1; i<=5; i=i+1) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Mode 1: din=%d, dout=%d", din, dout);
        end

        // Test mode 2: weighted average (25%+25%+50%)
        mode = 3'b010;
        for (integer i=1; i<=5; i=i+1) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Mode 2: din=%d, dout=%d", din, dout);
        end

        // Test mode 3: 4-point average
        mode = 3'b011;
        for (integer i=1; i<=10; i=i+1) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Mode 3: din=%d, dout=%d", din, dout);
        end

        // Test mode 5: 16-point average (1000 points)
        mode = 3'b101;
        $display("\n16-point Moving Average Test (1000 points):");
        for (integer i=1; i<=1000; i=i+1) begin
            // Generate test pattern: ramp + noise
            din = i % 256 + ($random % 16 - 8); // Ramp 0-255 with ±8 noise
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            if (i >= 16 && (i % 50 == 0 || i > 990)) begin
                $display("Cycle %4d: din=%4d, dout=%4d (avg of %4d-%4d)", 
                         i, din, dout, i-15, i);
            end
        end

        // Test enable control
        enable = 0;
        din = 100;
        data_refresh = 1;
        #10;
        $display("Disable test: din=%d, dout=%d (should not change)", din, dout);

        $finish;
    end

    // Waveform recording
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_moving_average);
    end
endmodule
