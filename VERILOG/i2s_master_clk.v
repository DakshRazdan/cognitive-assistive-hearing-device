// i2s_master_clk.v  -  I2S Master Clock Generator

module i2s_master_clk #(
    parameter SYS_CLK_FREQ = 100_000_000,  // System clock frequency (Hz)
    parameter BCLK_FREQ = 1_024_000,    // Target BCLK frequency (Hz)
    parameter BITS_PER_CH = 32            // Bits per channel (32 = standard)
)(
    input wire clk,      // System clock
    input wire rst_n,

    output reg bclk,     // Bit clock → all 4 INMP441 BCLK pins
    output reg ws,       // Word select / LRCLK → all 4 INMP441 WS pins
    output wire mclk    // Master clock (optional, some boards need it)
);

// BCLK divider
localparam BCLK_DIV = SYS_CLK_FREQ / BCLK_FREQ / 2;  // Half period counter

// WS divider: WS toggles every BITS_PER_CH BCLK cycles
localparam WS_DIV = BITS_PER_CH;

reg [$clog2(BCLK_DIV)-1:0] bclk_cnt;
reg [$clog2(WS_DIV)-1:0] ws_cnt;
reg bclk_rise_pulse;

// BCLK generation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bclk <= 1'b0;
        bclk_cnt <= 0;
        bclk_rise_pulse <= 1'b0;
    end else begin
        bclk_rise_pulse <= 1'b0;
        if (bclk_cnt == BCLK_DIV - 1) begin
            bclk_cnt <= 0;
            bclk <= ~bclk;
            if (!bclk)  // About to go HIGH
                bclk_rise_pulse <= 1'b1;
        end else begin
            bclk_cnt <= bclk_cnt + 1'b1;
        end
    end
end

// WS generation: toggle every BITS_PER_CH BCLK rising edges
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ws <= 1'b0;
        ws_cnt <= 0;
    end else if (bclk_rise_pulse) begin
        if (ws_cnt == WS_DIV - 1) begin
            ws_cnt <= 0;
            ws <= ~ws;
        end else begin
            ws_cnt <= ws_cnt + 1'b1;
        end
    end
end

assign mclk = clk;  

endmodule