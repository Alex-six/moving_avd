`timescale 1ns / 1ps

module moving_average_v5 #(
    parameter DATA_WIDTH = 16
) (
    input wire clk,
    input wire rst_n, 
    input wire enable,
    input wire data_refresh,
    input wire output_refresh_mode,
    input wire signed [DATA_WIDTH-1:0] din,
    input wire [2:0] mode,
    output reg signed [DATA_WIDTH-1:0] dout,
    output reg output_pulse
);

// Original implementation with pre-scaling
localparam SUM_WIDTH = DATA_WIDTH + 4; // Extra 4 bits for accumulation
reg signed [SUM_WIDTH-1:0] sum; // Accumulator
reg signed [DATA_WIDTH-1:0] scaled_history [0:15]; // Scaled history
reg [3:0] ptr;
reg full_flag;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= 20'b0;
        ptr <= 4'b0;
        full_flag <= 1'b0;
        for (integer i=0; i<16; i=i+1) begin
            scaled_history[i] <= 16'b0;
        end
        dout <= 16'b0;
        output_pulse <= 1'b0;
    end
    else if (enable) begin
        if (data_refresh) begin
            // Update history and pointer
            scaled_history[ptr] <= $signed({{4{din[DATA_WIDTH-1]}}, din}); // Pre-scale input
            ptr <= ptr + 1;
            
            // Update sum
            if (!full_flag) begin
                sum <= sum + $signed({{4{din[DATA_WIDTH-1]}}, din});
                if (ptr == 4'b1111) full_flag <= 1'b1;
            end
            else begin
                sum <= sum + $signed({{4{din[DATA_WIDTH-1]}}, din}) - scaled_history[ptr];
                cnt <= cnt + 1;
            end
        end

        // Output control
        output_pulse <= 1'b0;
        if (data_refresh && enable) begin
            if (output_refresh_mode) begin
                output_pulse <= 1'b1;
            end
            else begin
                case (mode)
                    3'b000: output_pulse <= 1'b1;
                    3'b001: output_pulse <= (ptr[0] == 1'b1);
                    3'b010: output_pulse <= (ptr[1:0] == 2'b10);
                    3'b011: output_pulse <= (ptr[1:0] == 2'b11);
                    3'b100: output_pulse <= (ptr[2:0] == 3'b111);
                    3'b101: output_pulse <= (ptr == 4'b1111);
                    default: output_pulse <= 1'b1;
                endcase
            end
        end

        // Output calculation
        case (mode)
            3'b000: dout <= din;
            3'b001: dout <= (scaled_history[(ptr < 1) ? (16 + ptr - 1) : (ptr - 1)] + $signed({{4{din[DATA_WIDTH-1]}}, din})) >>> 1;
            3'b010: dout <= (scaled_history[(ptr < 2) ? (16 + ptr - 2) : (ptr - 2)] + 
                          scaled_history[(ptr < 1) ? (16 + ptr - 1) : (ptr - 1)] + 
                          $signed({{4{din[DATA_WIDTH-1]}}, din})) >>> 2;
            3'b011: dout <= (scaled_history[(ptr < 3) ? (16 + ptr - 3) : (ptr - 3)] + 
                          scaled_history[(ptr < 2) ? (16 + ptr - 2) : (ptr - 2)] + 
                          scaled_history[(ptr < 1) ? (16 + ptr - 1) : (ptr - 1)] + 
                          $signed({{4{din[DATA_WIDTH-1]}}, din})) >>> 2;
            3'b100: dout <= sum[SUM_WIDTH-1:4]; // 8-point avg
            3'b101: dout <= sum[SUM_WIDTH-1:4]; // 16-point avg
            default: dout <= din;
        endcase
    end
end

endmodule
