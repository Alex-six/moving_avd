`timescale 1ns / 1ps

module moving_average_v7 #(
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

// Optimized design (improved ADC performance)
localparam SUM_WIDTH = DATA_WIDTH + 8; // 8-bit for overflow and precision
reg signed [SUM_WIDTH-1:0] sum;    // Extended accumulator width
reg signed [DATA_WIDTH-1:0] init_din; // Initial din value
reg [3:0] cnt;           // Data counter
reg signed [DATA_WIDTH-1:0] prev_din;     // Previous input data
reg signed [DATA_WIDTH-1:0] prev_prev_din; // Second previous input data
reg init_flag;           // Initialization flag

// Remove multipliers, use only add/sub operations
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= {SUM_WIDTH{1'b0}};
        cnt <= 4'b0;
        prev_din <= {DATA_WIDTH{1'b0}};
        prev_prev_din <= {DATA_WIDTH{1'b0}};
        init_flag <= 1'b0;
        dout <= {DATA_WIDTH{1'b0}};
        output_pulse <= 1'b0;
    end else if (enable) begin
        // Only work when enabled
        if (data_refresh) begin
            // Update history data
            prev_prev_din <= prev_din;
            prev_din <= din;
            
            if (!init_flag) begin
                // Optimized initialization process
                if (cnt == 0) begin
                    init_din <= din;
                    sum <= $signed(din) << 8;  // Higher precision initialization
                end else if (cnt <= 15) begin
                    sum <= sum - $signed(init_din) + $signed(din);  // Maintain high precision calculation
                end
                if (cnt == 15) begin
                    init_flag <= 1'b1;
                end
                cnt <= cnt + 1;
            end else begin
                // Improved sliding window calculation
                sum <= sum + ($signed(din) << 4) - ($signed(sum[SUM_WIDTH-1:4]) << 4);  // Maintain high precision
                cnt <= cnt + 1;
            end
        end
        
        // Output pulse control (same as v3)
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

        // Optimized output calculation (symmetric weighting)
        if (enable) begin
            case (mode)
                3'b000: dout <= din;
                3'b001: dout <= ($signed(prev_din) + $signed(din)) >>> 1;
                3'b010: dout <= (($signed(prev_prev_din) >>> 2) +  // 25%
                               ($signed(prev_din) >>> 2) +       // 25% weight
                               ($signed(din) >>> 1));            // 50% weight
                3'b011: dout <= ($signed(prev_prev_din) + $signed(prev_din) + 
                               $signed(din) + $signed(sum[SUM_WIDTH-1:4])) >>> 2;
                3'b100: dout <= sum[SUM_WIDTH-1:8];   // 16-point average (higher precision)
                3'b101: dout <= sum[SUM_WIDTH-1:8];   // 16-point average
                default: dout <= din;
            endcase
        end
    end
end

endmodule
