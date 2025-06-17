`timescale 1ns / 1ps

module moving_average_v9 #(
    parameter DATA_WIDTH = 16
) (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire data_refresh,
    input wire [2:0] mode,
    input wire signed [DATA_WIDTH-1:0] din,
    output reg signed [DATA_WIDTH-1:0] dout,
    output reg output_pulse
);

// Ultra area-optimized design
localparam SUM_WIDTH = DATA_WIDTH + 8; // Only 8 guard bits
reg signed [SUM_WIDTH-1:0] sum;
reg signed [DATA_WIDTH-1:0] prev_din; // Only 1-level history
reg [3:0] cnt;

// Symmetric weighted averaging coefficients
localparam COEFF_2PT = 1;   // 1/2
localparam COEFF_3PT = 1;    // 1/4, 2/4, 1/4

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= {SUM_WIDTH{1'b0}};
        cnt <= 4'b0;
        prev_din <= {DATA_WIDTH{1'b0}};
        dout <= {DATA_WIDTH{1'b0}};
        output_pulse <= 1'b0;
    end else if (enable && data_refresh) begin
        // Simplified data path
        prev_din <= din;
        cnt <= cnt + 1;
        
        // Optimized accumulation
        case (mode)
            3'b000: sum <= $signed(din) << 8; // No averaging
            3'b001: sum <= sum + ($signed(din) << 7); // 2-point
            3'b010: sum <= sum + ($signed(din) << 6); // 3-point 
            default: sum <= sum + ($signed(din) << 5); // Others
        endcase

        // Output generation
        case (mode)
            3'b000: dout <= din;
            3'b001: dout <= ($signed(prev_din) + $signed(din)) >>> 1;
            3'b010: dout <= (($signed(prev_din) >>> 2) + 
                           ($signed(din) >>> 1) + 
                           ($signed(din) >>> 2);
            3'b011: dout <= sum[SUM_WIDTH-1:8];
            3'b100: dout <= sum[SUM_WIDTH-1:8];
            3'b101: dout <= sum[SUM_WIDTH-1:8];
            default: dout <= din;
        endcase

        // Simplified output pulse
        output_pulse <= (mode == 3'b000) ? 1'b1 : cnt[0];
    end
end

endmodule
