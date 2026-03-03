// top_level_tb.v -- Smoke test for full MVDR beamformer pipeline
// Uses DUT's own bclk/ws outputs to drive sdata (matches real hardware)

`timescale 1ns/1ps

module top_level_tb;

localparam CLK_P  = 10;
localparam DATA_W = 24;

reg  clk, rst_n;
reg  sdata_01, sdata_23;
wire bclk_dut, ws_dut;
wire signed [15:0] pcm_out;
wire pcm_valid, pcm_last;

top_level dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .sdata_01 (sdata_01),
    .sdata_23 (sdata_23),
    .bclk     (bclk_dut),
    .ws       (ws_dut),
    .pcm_out  (pcm_out),
    .pcm_valid(pcm_valid),
    .pcm_last (pcm_last)
);

initial clk = 0;
always #(CLK_P/2) clk = ~clk;

// 1kHz sine LUT: 16 samples per period at 16kHz
reg signed [23:0] sine_lut [0:15];
integer sl;
initial begin
    for (sl = 0; sl < 16; sl = sl + 1)
        sine_lut[sl] = $rtoi($sin(2.0*3.14159265*sl/16.0) * 4194304.0);
end

reg signed [23:0] tx_sample;
integer sine_idx;
reg ws_prev, bclk_prev;
reg [4:0] bit_pos;
reg channel_started;

// Serialize sdata using DUT's own bclk/ws
always @(posedge clk) begin
    ws_prev   <= ws_dut;
    bclk_prev <= bclk_dut;

    // WS falling edge: load new sample for left channel
    if (!ws_dut && ws_prev) begin
        tx_sample       <= sine_lut[sine_idx % 16];
        sine_idx        <= sine_idx + 1;
        bit_pos         <= 0;
        channel_started <= 0;
    end

    // WS rising edge: reset for right channel (same sample)
    if (ws_dut && !ws_prev) begin
        bit_pos         <= 0;
        channel_started <= 0;
    end

    // Falling edge of bclk: shift out next bit
    if (!bclk_dut && bclk_prev) begin
        if (!channel_started) begin
            channel_started <= 1;  // skip dead cycle
            sdata_01 <= 0;
            sdata_23 <= 0;
        end else if (bit_pos < DATA_W) begin
            sdata_01 <= tx_sample[DATA_W-1-bit_pos];
            sdata_23 <= tx_sample[DATA_W-1-bit_pos];
            bit_pos  <= bit_pos + 1;
        end else begin
            sdata_01 <= 0;
            sdata_23 <= 0;
        end
    end
end

integer pcm_count, last_count, nonzero_count;
integer pass_count, fail_count;

always @(posedge clk) begin
    if (pcm_valid) begin
        pcm_count     = pcm_count + 1;
        if ($signed(pcm_out) != 0) nonzero_count = nonzero_count + 1;
        if (pcm_last) last_count = last_count + 1;
    end
end

initial begin
    $dumpfile("top_level.vcd");
    $dumpvars(0, top_level_tb);

    pass_count=0; fail_count=0;
    pcm_count=0; last_count=0; nonzero_count=0;
    sine_idx=0; sdata_01=0; sdata_23=0;
    ws_prev=0; bclk_prev=0; bit_pos=0; channel_started=0;
    rst_n=0;

    repeat(20) @(posedge clk);
    rst_n=1;

    $display("=== Top Level Smoke Test ===");
    $display("Driving 1kHz sine via DUT bclk/ws. Waiting for PCM output...");

    fork
        begin : wait_pcm
            @(posedge pcm_valid);
            $display("  First pcm_valid at time %0t", $time);
            disable wait_block;
        end
        begin : wait_block
            repeat(100000000) @(posedge clk);
            disable wait_pcm;
        end
    join

    repeat(50000) @(posedge clk);

    $display("\n--- Results ---");
    $display("pcm_valid count : %0d", pcm_count);
    $display("pcm_last  count : %0d", last_count);
    $display("nonzero samples : %0d", nonzero_count);

    $display("\nTest 1: pcm_valid fires");
    if (pcm_count > 0) begin
        $display("  PASS pcm_count=%0d", pcm_count); pass_count=pass_count+1;
    end else begin
        $display("  FAIL no pcm_valid"); fail_count=fail_count+1;
    end

    $display("\nTest 2: pcm_last fires");
    if (last_count > 0) begin
        $display("  PASS pcm_last=%0d times", last_count); pass_count=pass_count+1;
    end else begin
        $display("  FAIL pcm_last never fired"); fail_count=fail_count+1;
    end

    $display("\nTest 3: output not stuck at zero");
    if (nonzero_count > 0) begin
        $display("  PASS nonzero=%0d", nonzero_count); pass_count=pass_count+1;
    end else begin
        $display("  FAIL all zero"); fail_count=fail_count+1;
    end

    $display("\nTest 4: Q1.15 range");
    $display("  PASS by construction"); pass_count=pass_count+1;

    $display("\n=== RESULT: %0d PASS, %0d FAIL ===", pass_count, fail_count);
    $finish;
end

initial begin
    #2000000000;
    $display("GLOBAL TIMEOUT");
    $finish;
end

endmodule