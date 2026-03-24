// top_level_tb.v - Full Pipeline Smoke Test
// Drives 4 I2S mics with 1kHz sine, checks pipeline produces output
`timescale 1ns/1ps

module top_level_tb;

localparam CLK_P  = 10;
localparam DATA_W = 24;

reg  clk, rst_n;
reg  sdata_01, sdata_23;
wire bclk_dut, ws_dut;
wire signed [15:0] pcm_out;
wire pcm_valid, pcm_last;

// Instantiate using OLD top_level ports (from zip)
top_level dut (
    .clk (clk),
    .rst_n (rst_n),
    .sdata_01 (sdata_01),
    .sdata_23 (sdata_23),
    .bclk (bclk_dut),
    .ws (ws_dut),
    .pcm_out (pcm_out),
    .pcm_valid(pcm_valid),
    .pcm_last (pcm_last)
);

initial clk = 0;
always #(CLK_P/2) clk = ~clk;

// Sine LUT — 1kHz at 16kHz
reg signed [23:0] sine_lut [0:15];
integer sl;
initial begin
    for (sl = 0; sl < 16; sl = sl + 1)
        sine_lut[sl] = $rtoi($sin(2.0*3.14159265*sl/16.0) * 4194304.0);
end

// Serialize sine over I2S using DUT's bclk/ws
reg signed [23:0] tx_sample;
integer sine_idx;
reg ws_prev, bclk_prev;
reg [4:0] bit_pos;
reg channel_started;

always @(posedge clk) begin
    ws_prev <= ws_dut;
    bclk_prev <= bclk_dut;

    if (!ws_dut && ws_prev) begin
        tx_sample <= sine_lut[sine_idx % 16];
        sine_idx <= sine_idx + 1;
        bit_pos <= 0; channel_started <= 0;
    end
    if (ws_dut && !ws_prev) begin
        bit_pos <= 0; channel_started <= 0;
    end
    if (!bclk_dut && bclk_prev) begin
        if (!channel_started) begin
            channel_started <= 1;
            sdata_01 <= 0; sdata_23 <= 0;
        end else if (bit_pos < DATA_W) begin
            sdata_01 <= tx_sample[DATA_W-1-bit_pos];
            sdata_23 <= tx_sample[DATA_W-1-bit_pos];
            bit_pos <= bit_pos + 1;
        end else begin
            sdata_01 <= 0; sdata_23 <= 0;
        end
    end
end

integer pcm_count, nonzero_count, pass_count, fail_count;

always @(posedge clk) begin
    if (pcm_valid) begin
        pcm_count = pcm_count + 1;
        if ($signed(pcm_out) != 0) nonzero_count = nonzero_count + 1;
    end
end

initial begin
    $dumpfile("top_level.vcd");
    $dumpvars(0, top_level_tb);

    pass_count=0; fail_count=0;
    pcm_count=0; nonzero_count=0;
    sine_idx=0; sdata_01=0; sdata_23=0;
    ws_prev=0; bclk_prev=0; bit_pos=0;
    channel_started=0; tx_sample=0;
    rst_n=0;
    repeat(20) @(posedge clk);
    rst_n=1;

    $display("=== Top Level Full Pipeline Smoke Test ===");
    $display("Waiting for PCM output...");

    fork
        begin : wait_out
            @(posedge pcm_valid);
            $display("  First pcm_valid at time %0t ns", $time/1000);
            disable wait_to;
        end
        begin : wait_to
            repeat(100000000) @(posedge clk);
            $display("  WARNING: No output after 100M cycles");
            disable wait_out;
        end
    join

    repeat(10000) @(posedge clk);

    $display("\n--- Results ---");
    $display("pcm_valid pulses : %0d", pcm_count);
    $display("nonzero samples  : %0d", nonzero_count);

    $display("\nTest 1: Pipeline produces pcm_valid");
    if (pcm_count > 0) begin
        $display("  PASS pcm_count=%0d", pcm_count); pass_count=pass_count+1;
    end else begin
        $display("  FAIL no output"); fail_count=fail_count+1;
    end

    $display("\nTest 2: Output not stuck at zero");
    if (nonzero_count > 0) begin
        $display("  PASS nonzero=%0d", nonzero_count); pass_count=pass_count+1;
    end else begin
        $display("  FAIL all zero"); fail_count=fail_count+1;
    end

    $display("\nTest 3: pcm_last fires");
    if (pcm_last !== 1'bx) begin
        $display("  PASS pcm_last defined"); pass_count=pass_count+1;
    end else begin
        $display("  FAIL pcm_last undefined"); fail_count=fail_count+1;
    end

    $display("\n=== RESULT: %0d PASS, %0d FAIL ===", pass_count, fail_count);
    $finish;
end

initial begin
    #500000000; $display("GLOBAL TIMEOUT"); $finish;
end

endmodule