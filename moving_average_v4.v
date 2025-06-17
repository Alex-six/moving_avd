`timescale 1ns / 1ps

module moving_average_v4 #(
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

// Original implementation with 16 buffers
reg signed [DATA_WIDTH-1:0] history [0:15];
reg [3:0] ptr;
reg full_flag;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ptr <= 4'b0;
        full_flag <= 1'b0;
        for (integer i=0; i<16; i=i+1) begin
            history[i] <= 16'b0;
        end
        dout <= 16'b0;
        output_pulse <= 1'b0;
    end
    else if (enable) begin
        if (data_refresh) begin
            // Update history
            history[ptr] <= din;
            ptr <= ptr + 1;
            if (ptr == 4'b1111) full_flag <= 1'b1;
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
            3'b001: dout <= (history[(ptr < 1) ? (16 + ptr - 1) : (ptr - 1)] + din) >>> 1;
            3'b010: dout <= (history[(ptr < 2) ? (16 + ptr - 2) : (ptr - 2)] + 
                          history[(ptr < 1) ? (16 + ptr - 1) : (ptr - 1)] + din) >>> 2;
            3'b011: dout <= (history[(ptr < 3) ? (16 + ptr - 3) : (ptr - 3)] + 
                          history[(ptr < 2) ? (16 + ptr - 2) : (ptr - 2)] + 
                          history[(ptr < 1) ? (16 + ptr - 1) : (ptr - 1)] + din) >>> 2;
            3'b100: begin
                // 8-point average
                localparam SUM8_WIDTH = DATA_WIDTH + 3;
                reg signed [SUM8_WIDTH-1:0] sum8;
                sum8 = history[(ptr < 7) ? (16 + ptr - 7) : (ptr - 7)] + 
                       history[(ptr < 6) ? (16 + ptr - 6) : (ptr - 6)] + 
                       history[(ptr < 5) ? (16 + ptr - 5) : (ptr - 5)] + 
                       history[(ptr < 4) ? (16 + ptr - 4) : (ptr - 4)] + 
                       history[(ptr < 3) ? (16 + ptr - 3) : (ptr - 3)] + 
                       history[(ptr < 2) ? (16 + ptr - 2) : (ptr - 2)] + 
                       history[(ptr < 1) ? (16 + ptr - 1) : (ptr - 1)] + 
                       din;
                dout <= sum8[SUM8_WIDTH-1:3];
            end
            3'b101: begin
                // 16-point average
                localparam SUM16_WIDTH = DATA_WIDTH + 4;
                reg signed [SUM16_WIDTH-1:0] sum16;
                sum16 = history[0] + history[1] + history[2] + history[3] +
                         history[4] + history[5] + history[6] + history[7] +
                         history[8] + history[9] + history[10] + history[11] +
                         history[12] + history[13] + history[14] + history[15];
                dout <= sum16[SUM16_WIDTH-1:4];
            end
            default: dout <= din;
        endcase
    end
end

endmodule
