// i2s_tx.v — I2S Transmitter (sends PCM audio to PAM8403)
`timescale 1ns/1ps

module i2s_tx #(
    parameter DW = 16
)(
    input wire clk,
    input wire rst_n,
    input wire bclk,
    input wire ws,
    input wire signed [DW-1:0] pcm_in,
    input wire pcm_valid,
    output reg sdata
);

// Synchronize bclk and ws to system clock
reg bclk_r1, bclk_r2;
reg ws_r1, ws_r2, ws_r3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bclk_r1 <= 0; bclk_r2 <= 0;
        ws_r1 <= 0; ws_r2 <= 0; ws_r3 <= 0;
    end else begin
        bclk_r1 <= bclk; bclk_r2 <= bclk_r1;
        ws_r1 <= ws; ws_r2 <= ws_r1; ws_r3 <= ws_r2;
    end
end

wire bclk_fall = !bclk_r1 &&  bclk_r2;  // falling edge of BCLK
wire ws_fall = !ws_r2 && ws_r3; // falling edge of WS (start of left)
wire ws_rise = ws_r2 && !ws_r3; // rising edge of WS (start of right)

// Shift register — load on WS edge, shift out on BCLK falling edge
reg [DW-1:0] shift_reg;
reg [4:0] bit_cnt; // 0..15
reg [DW-1:0] latch; // latched PCM sample

// Latch incoming PCM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) latch <= 0;
    else if (pcm_valid) latch <= pcm_in;
end

// Shift out
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        shift_reg <= 0;
        bit_cnt <= 0;
        sdata <= 0;
    end else begin
        // Load shift register at start of each channel
        if (ws_fall || ws_rise) begin
            shift_reg <= latch;
            bit_cnt <= 0;
        end else if (bclk_fall && bit_cnt < DW) begin
            sdata <= shift_reg[DW-1];
            shift_reg <= shift_reg << 1;
            bit_cnt <= bit_cnt + 1;
        end else if (bit_cnt >= DW) begin
            sdata <= 0;  // dead bits after 16
        end
    end
end

endmodule