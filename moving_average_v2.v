`timescale 1ns / 1ps

module moving_average_v2 #(
    parameter DATA_WIDTH = 16
) (
    input wire clk,          // Clock signal
    input wire rst_n,        // Async reset (active low)
    input wire enable,       // Module enable
    input wire data_refresh, // Data refresh pulse
    input wire output_refresh_mode, // Output refresh mode: 0-by average count, 1-every calculation
    input wire signed [DATA_WIDTH-1:0] din,   // Input data (signed)
    input wire [2:0] mode,   // Mode select: 000-no avg, 001-2pt, 010-3pt, 011-4pt, 100-8pt, 101-16pt
    output reg signed [DATA_WIDTH-1:0] dout,  // Output data (signed)
    output reg output_pulse  // Output valid pulse
);

// Signed number optimized version
localparam SUM_WIDTH = DATA_WIDTH + 4; // Extra 4 bits for accumulation
reg signed [SUM_WIDTH-1:0] sum;    // Accumulator (4-bit extended to prevent overflow)
reg signed [DATA_WIDTH-1:0] init_din; // Initial din value
reg [3:0] cnt;           // Data counter
reg [DATA_WIDTH-1:0] history [0:15]; // 16-level history data register
reg init_flag;           // Initialization flag
reg [DATA_WIDTH-1:0] prev_din;     // Previous input value
reg [DATA_WIDTH-1:0] prev_prev_din; // Second previous input value

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= 20'b0;
        cnt <= 4'b0;
        for (integer i=0; i<16; i=i+1) begin
            history[i] <= 16'b0;
        end
        init_flag <= 1'b0;
        dout <= 16'b0;
        output_pulse <= 1'b0;
        prev_din <= 16'b0;
        prev_prev_din <= 16'b0;
    end else if (enable) begin
        // Only work when enabled
        if (data_refresh) begin
            // Update history data
            prev_prev_din <= prev_din;
            prev_din <= din;
            
            for (integer i=15; i>0; i=i-1) begin
                history[i] <= history[i-1];
            end
            history[0] <= din;
            
            if (!init_flag) begin
                // Initialization phase optimization
                if (cnt == 0) begin
                    init_din <= din;
                    sum <= $signed({{4{din[DATA_WIDTH-1]}}, din});  // Maintain high precision initialization
                end else if (cnt <= 15) begin
                    sum <= sum - $signed(init_din) + $signed(din);  // Simplified calculation
                end
                if (cnt == 15) begin
                    init_flag <= 1'b1;
                end
                cnt <= cnt + 1;
            end else begin
                // Precise sliding window
                sum <= sum + $signed(din) - $signed(history[15]);  // Subtract data from 16 cycles ago
                cnt <= cnt + 1;
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

        // Select output based on mode
        if (enable) begin
            case (mode)
                3'b000: dout <= din;
                3'b001: dout <= ($signed(prev_din) + $signed(din)) >>> 1;
                3'b010: dout <= ($signed(prev_prev_din) + $signed(prev_din) + $signed({din,1'b0})) >>> 2;
                3'b011: dout <= ($signed(prev_prev_din) + $signed(prev_din) + $signed(din) + $signed(sum[SUM_WIDTH-1:3])) >>> 2;
                3'b100: dout <= sum[SUM_WIDTH-1:4];
                3'b101: dout <= sum[SUM_WIDTH-1:4];
                default: dout <= din;
            endcase
        end
    end
end

endmodule
