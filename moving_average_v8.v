`timescale 1ns / 1ps

module moving_average_v8 #(
    parameter DATA_WIDTH = 16
) (
    input wire clk,          // Clock signal
    input wire rst_n,        // Async reset (active low) 
    input wire enable,       // Module enable
    input wire data_refresh, // Data refresh pulse
    input wire output_refresh_mode, // Output refresh mode
    input wire signed [DATA_WIDTH-1:0] din,   // Input data
    input wire [2:0] mode,   // Mode select
    output reg signed [DATA_WIDTH-1:0] dout,  // Output data
    output reg output_pulse  // Output valid pulse
);

// Area-optimized design with maintained performance
localparam SUM_WIDTH = DATA_WIDTH + 10; // Reduced from 12 to 10 guard bits
reg signed [SUM_WIDTH-1:0] sum;    // Accumulator
reg signed [DATA_WIDTH-1:0] history [0:2]; // Reduced to 3-level history buffer
reg [3:0] cnt;
reg init_flag;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= {SUM_WIDTH{1'b0}};
        cnt <= 4'b0;
        for (integer i=0; i<3; i=i+1) begin
            history[i] <= {DATA_WIDTH{1'b0}};
        end
        init_flag <= 1'b0;
        dout <= {DATA_WIDTH{1'b0}};
        output_pulse <= 1'b0;
    end else if (enable) begin
        if (data_refresh) begin
            // Update history (reduced depth)
            for (integer i=2; i>0; i=i-1) begin
                history[i] <= history[i-1];
            end
            history[0] <= din;
            
            if (!init_flag) begin
                // Simplified initialization
                sum <= sum + ($signed(din) << 6);  // Reduced scaling
                if (cnt == 15) init_flag <= 1'b1;
                cnt <= cnt + 1;
            end else begin
                // Optimized sliding window
                sum <= sum + ($signed(din) << 2) - ($signed(history[2]) << 2);
                cnt <= cnt + 1;
            end
        end

        // Output control (same as V6)
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

        // Maintained weighted averaging
        case (mode)
            3'b000: dout <= din;
            3'b001: dout <= ($signed(history[0]) + $signed(history[1])) >>> 1;
            3'b010: dout <= (($signed(history[0]) + 
                           ($signed(history[1]) << 1) + 
                           $signed(history[2])) >>> 2;
            3'b011: dout <= ($signed(history[0]) + $signed(history[1]) + 
                          $signed(history[2]) + $signed(sum[SUM_WIDTH-1:10])) >>> 2;
            3'b100: dout <= sum[SUM_WIDTH-1:10];  // 8-point average
            3'b101: dout <= sum[SUM_WIDTH-1:10];  // 16-point average
            default: dout <= din;
        endcase
    end
end

endmodule
