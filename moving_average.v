`timescale 1ns / 1ps

module moving_average #(
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

// Final simplified design
localparam SUM_WIDTH = DATA_WIDTH + 4; // Extra 4 bits for accumulation
reg signed [SUM_WIDTH-1:0] sum;   // Accumulator (stores 16 history samples, signed)
reg [3:0] cnt;           // Data counter
reg [DATA_WIDTH-1:0] prev_din;     // Previous input value
reg [DATA_WIDTH-1:0] prev_prev_din; // Second previous input value
reg [DATA_WIDTH-1:0] init_din;     // Initial din value when cnt==0

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= 20'b0;
        cnt <= 4'b0;
        prev_din <= 16'b0;
        prev_prev_din <= 16'b0;
        dout <= 16'b0;
    end else if (enable) begin
        // Only work when enabled
        if (data_refresh) begin
            // Store last two inputs for weighted average
            prev_prev_din <= prev_din;
            prev_din <= din;
            
            if (cnt == 0) begin
                // First cycle: store initial value
                init_din <= din;
                sum <= $signed({{4{din[DATA_WIDTH-1]}}, din});  // din<<4 (sign extension)
                cnt <= cnt + 1;
            end else if (cnt < 15) begin
                // Initialization phase: simplified sliding update
                sum <= sum - $signed(init_din) + $signed(din);
                cnt <= cnt + 1;
            end else begin
                // Normal sliding window update after full initialization
                sum <= sum + $signed(din) - $signed(sum[SUM_WIDTH-1:DATA_WIDTH]); // Subtract oldest data (equivalent to sum/16), add new data (signed operation)
                cnt <= cnt + 1;
            end
        end
        
        // Output pulse control
        output_pulse <= 1'b0;
        if (enable && data_refresh) begin
            if (output_refresh_mode) begin
                // Mode 1: output pulse every calculation
                output_pulse <= 1'b1;
            end else begin
                // Mode 0: output pulse by average count
                case (mode)
                    3'b000: output_pulse <= 1'b1;  // No average: every refresh
                    3'b001: output_pulse <= (cnt[0] == 1'b1);  // 2-point: every 2
                    3'b010: output_pulse <= (cnt[1:0] == 2'b10); // 3-point weighted: every 3
                    3'b011: output_pulse <= (cnt[1:0] == 2'b11); // 4-point: every 4
                    3'b100: output_pulse <= (cnt == 4'b0111);    // 8-point: every 8
                    3'b101: output_pulse <= (cnt == 4'b1111);    // 16-point: every 16
                    default: output_pulse <= 1'b1;
                endcase
            end
        end

        // Select output based on mode
        if (enable) begin
            case (mode)
                3'b000: dout <= din;         // No averaging
                3'b001: dout <= ($signed(prev_din) + $signed(din)) >>> 1;  // 2-point average (signed shift)
                3'b010: dout <= ($signed(prev_prev_din) + $signed(prev_din) + $signed({din,1'b0})) >>> 2; // Weighted average (25%+25%+50%)(signed shift)
                3'b011: dout <= ($signed(prev_prev_din) + $signed(prev_din) + $signed(din) + $signed(sum[19:4])) >>> 2;  // 4-point average (signed shift)
                3'b100: dout <= sum[SUM_WIDTH-1:4];   // 16-point average
                3'b101: dout <= sum[SUM_WIDTH-1:4];   // 16-point average
                default: dout <= din;        // Default no averaging
            endcase
        end
    end else begin
        // Keep output unchanged when module disabled
        dout <= dout;
    end
end

endmodule
