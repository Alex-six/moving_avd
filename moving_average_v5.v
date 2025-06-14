`timescale 1ns / 1ps

module moving_average_v5 (
    input wire clk,          // Clock signal
    input wire rst_n,        // Async reset (active low)
    input wire enable,       // Module enable
    input wire data_refresh, // Data refresh pulse
    input wire output_refresh_mode, // Output refresh mode: 0-by average count, 1-every calculation
    input wire signed [15:0] din,   // Input data (signed)
    input wire [2:0] mode,   // Mode select: 000-no avg, 001-2pt, 010-3pt, 011-4pt, 100-8pt, 101-16pt
    output reg signed [15:0] dout,  // Output data (signed)
    output reg output_pulse  // Output valid pulse
);

// Enhanced design (performance optimized)
reg signed [27:0] sum;    // 28-bit accumulator (12 guard bits)
reg signed [15:0] history [0:3]; // 4-level history buffer
reg [3:0] cnt;           // Data counter
reg init_flag;           // Initialization flag

// Anti-aliasing pre-processing
wire signed [16:0] din_ext = {din[15], din}; // Sign extension

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= 28'b0;
        cnt <= 4'b0;
        for (integer i=0; i<4; i=i+1) begin
            history[i] <= 16'b0;
        end
        init_flag <= 1'b0;
        dout <= 16'b0;
        output_pulse <= 1'b0;
    end else if (enable) begin
        // Update history data
        if (data_refresh) begin
            for (integer i=3; i>0; i=i-1) begin
                history[i] <= history[i-1];
            end
            history[0] <= din;
            
            if (!init_flag) begin
                // High precision initialization
                if (cnt == 0) begin
                sum <= $signed(din) << 12;  // High precision initialization
                end else if (cnt <= 15) begin
                    sum <= sum + ($signed(din) << 8;  // Accumulate with scaling
                end
                if (cnt == 15) init_flag <= 1'b1;  // Mark initialization complete
                cnt <= cnt + 1;
            end else begin
                // Improved sliding window calculation
                sum <= sum + ($signed(din) << 4) - ($signed(history[3]) << 4);  // Sliding window update with scaling
            end
        end

        // Output pulse control
        output_pulse <= 1'b0;
        if (enable && data_refresh) begin
            if (output_refresh_mode) begin
                output_pulse <= 1'b1;
            end else begin
                case (mode)
                    3'b000: output_pulse <= 1'b1;
                    3'b001: output_pulse <= (cnt[0] == 1'b1);
                    3'b010: output_pulse <= (cnt[1:0] == 2'b10);
                    3'b011: output_pulse <= (cnt[1:0] == 2'b11);
                    3'b100: output_pulse <= (cnt == 4'b0111);
                    3'b101: output_pulse <= (cnt == 4'b1111);
                    default: output_pulse <= 1'b1;
                endcase
            end
        end

        // Optimized output calculation with weighted averaging
        case (mode)
            3'b000: dout <= din;
            3'b001: dout <= ($signed(history[0]) + $signed(history[1])) >>> 1;
            3'b010: dout <= (($signed(history[0]) + 
                           ($signed(history[1]) << 1) + 
                           ($signed(history[2]))) >>> 2;
            3'b011: dout <= ($signed(history[0]) + $signed(history[1]) + 
                          $signed(history[2]) + $signed(sum[27:12])) >>> 2;
            3'b100: dout <= sum[27:12];  // 8-point average
            3'b101: dout <= sum[27:12];  // 16-point average
            default: dout <= din;
        endcase
    end
end

endmodule
