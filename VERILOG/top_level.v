// ============================================================================
// top_level.v -- MVDR Beamformer Top Level
// ============================================================================

`timescale 1ns/1ps

module top_level (
    input wire clk,
    input wire rst_n,
    input wire sdata_01,    // mic0=LEFT, mic1=RIGHT
    input wire sdata_23,    // mic2=LEFT, mic3=RIGHT
    output wire bclk,
    output wire ws,
    output wire signed [15:0] pcm_out,
    output wire pcm_valid,
    output wire pcm_last
);

localparam N = 256;
localparam NBINS = 129;   // bins 0..128
localparam DW = 16;

// ============================================================================
// I2S CLOCK GENERATOR
// ============================================================================
wire mclk_unused;
i2s_master_clk clk_gen (
    .clk(clk), .rst_n(rst_n),
    .bclk(bclk), .ws(ws), .mclk(mclk_unused)
);

// ============================================================================
// I2S RECEIVERS
// ============================================================================
wire [23:0] mic0_raw, mic1_raw, mic2_raw, mic3_raw;
wire i2s_valid_01, i2s_valid_23;

i2s_rx rx_01 (
    .clk(clk), .rst_n(rst_n), .bclk(bclk), .ws(ws), .sdata(sdata_01),
    .left_out(mic0_raw), .right_out(mic1_raw), .valid(i2s_valid_01)
);
i2s_rx rx_23 (
    .clk(clk), .rst_n(rst_n), .bclk(bclk), .ws(ws), .sdata(sdata_23),
    .left_out(mic2_raw), .right_out(mic3_raw), .valid(i2s_valid_23)
);

// ============================================================================
// CIC DECIMATORS x4
// ============================================================================
wire [15:0] cic0_out, cic1_out, cic2_out, cic3_out;
wire cic0_valid, cic1_valid, cic2_valid, cic3_valid;

cic_decimator cic0 (.clk(clk),.rst_n(rst_n),.x_in(mic0_raw),.x_valid(i2s_valid_01),.y_out(cic0_out),.y_valid(cic0_valid));
cic_decimator cic1 (.clk(clk),.rst_n(rst_n),.x_in(mic1_raw),.x_valid(i2s_valid_01),.y_out(cic1_out),.y_valid(cic1_valid));
cic_decimator cic2 (.clk(clk),.rst_n(rst_n),.x_in(mic2_raw),.x_valid(i2s_valid_23),.y_out(cic2_out),.y_valid(cic2_valid));
cic_decimator cic3 (.clk(clk),.rst_n(rst_n),.x_in(mic3_raw),.x_valid(i2s_valid_23),.y_out(cic3_out),.y_valid(cic3_valid));

// ============================================================================
// HANN WINDOW ROM (analysis window, applied before FFT)
// ============================================================================
reg signed [DW-1:0] hann_rom [0:N-1];
integer hw;
initial begin
    for (hw = 0; hw < N; hw = hw + 1)
        hann_rom[hw] = $rtoi((0.5 - 0.5*$cos(2.0*3.14159265358979*hw/N)) * 32767.0);
end

reg [7:0] win_cnt;
reg fft_valid;

wire signed [DW-1:0] win0 = ($signed(cic0_out) * $signed(hann_rom[win_cnt])) >>> 15;
wire signed [DW-1:0] win1 = ($signed(cic1_out) * $signed(hann_rom[win_cnt])) >>> 15;
wire signed [DW-1:0] win2 = ($signed(cic2_out) * $signed(hann_rom[win_cnt])) >>> 15;
wire signed [DW-1:0] win3 = ($signed(cic3_out) * $signed(hann_rom[win_cnt])) >>> 15;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        win_cnt <= 0;
        fft_valid <= 0;
    end else begin
        fft_valid <= 0;
        if (cic0_valid) begin
            fft_valid <= 1;
            win_cnt <= (win_cnt == N-1) ? 0 : win_cnt + 1;
        end
    end
end

// ============================================================================
// FFT x4
// ============================================================================
wire signed [DW-1:0] fft0_re, fft0_im, fft1_re, fft1_im;
wire signed [DW-1:0] fft2_re, fft2_im, fft3_re, fft3_im;
wire fft0_valid, fft0_last;
wire fft1_valid, fft1_last, fft2_valid, fft2_last, fft3_valid, fft3_last;

fft_r2dit fft0 (.clk(clk),.rst_n(rst_n),.x_re(win0),.x_valid(fft_valid),.y_re(fft0_re),.y_im(fft0_im),.y_valid(fft0_valid),.y_last(fft0_last));
fft_r2dit fft1 (.clk(clk),.rst_n(rst_n),.x_re(win1),.x_valid(fft_valid),.y_re(fft1_re),.y_im(fft1_im),.y_valid(fft1_valid),.y_last(fft1_last));
fft_r2dit fft2 (.clk(clk),.rst_n(rst_n),.x_re(win2),.x_valid(fft_valid),.y_re(fft2_re),.y_im(fft2_im),.y_valid(fft2_valid),.y_last(fft2_last));
fft_r2dit fft3 (.clk(clk),.rst_n(rst_n),.x_re(win3),.x_valid(fft_valid),.y_re(fft3_re),.y_im(fft3_im),.y_valid(fft3_valid),.y_last(fft3_last));

// ============================================================================
// BIN COUNTER -- track which bin FFT is outputting
// ============================================================================
reg [7:0] bin_cnt;
reg bin_valid;  // only bins 0..128

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bin_cnt   <= 0;
        bin_valid <= 0;
    end else begin
        bin_valid <= 0;
        if (fft0_valid) begin
            bin_valid <= (bin_cnt < NBINS);
            bin_cnt   <= fft0_last ? 8'd0 : bin_cnt + 1;
        end
    end
end

// ============================================================================
// COVARIANCE ESTIMATOR
// ============================================================================
wire [7:0] cov_rd_bin;
wire [3:0] cov_rd_elem;
wire cov_rd_en;
wire signed [DW-1:0] cov_rd_re, cov_rd_im;
wire cov_rd_valid;

covariance_est cov (
    .clk(clk), .rst_n(rst_n),
    .x0_re(fft0_re), .x0_im(fft0_im),
    .x1_re(fft1_re), .x1_im(fft1_im),
    .x2_re(fft2_re), .x2_im(fft2_im),
    .x3_re(fft3_re), .x3_im(fft3_im),
    .x_bin(bin_cnt), .x_valid(bin_valid),
    .rd_bin(cov_rd_bin), .rd_elem(cov_rd_elem), .rd_en(cov_rd_en),
    .rd_re(cov_rd_re),   .rd_im(cov_rd_im),     .rd_valid(cov_rd_valid)
);

// ============================================================================
// MVDR WEIGHT SEQUENCER
// Triggers weight computation for each bin after FFT frame completes
// ============================================================================
reg [7:0] wgt_bin;
reg wgt_compute;
reg wgt_busy;

wire signed [DW-1:0] w0_re,w0_im, w1_re,w1_im, w2_re,w2_im, w3_re,w3_im;
wire [7:0] w_bin_out;
wire w_valid;

mvdr_weights wgt (
    .clk(clk), .rst_n(rst_n),
    .compute(wgt_compute), .bin_in(wgt_bin),
    .rd_bin(cov_rd_bin), .rd_elem(cov_rd_elem), .rd_en(cov_rd_en),
    .rd_re(cov_rd_re),   .rd_im(cov_rd_im),     .rd_valid(cov_rd_valid),
    .w0_re(w0_re),.w0_im(w0_im), .w1_re(w1_re),.w1_im(w1_im),
    .w2_re(w2_re),.w2_im(w2_im), .w3_re(w3_re),.w3_im(w3_im),
    .w_bin(w_bin_out), .w_valid(w_valid)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wgt_bin <= 0; wgt_compute <= 0; wgt_busy <= 0;
    end else begin
        wgt_compute <= 0;
        if (fft0_last && !wgt_busy) begin
            wgt_bin <= 0; wgt_compute <= 1; wgt_busy <= 1;
        end else if (w_valid && wgt_busy) begin
            if (wgt_bin == NBINS-1)
                wgt_busy <= 0;
            else begin
                wgt_bin <= wgt_bin + 1;
                wgt_compute <= 1;
            end
        end
    end
end

// ============================================================================
// BEAMFORMER APPLY
// ============================================================================
wire signed [DW-1:0] bf_re, bf_im;
wire [7:0] bf_bin;
wire bf_valid;

beamformer_apply bf (
    .clk(clk), .rst_n(rst_n),
    .w0_re(w0_re),.w0_im(w0_im), .w1_re(w1_re),.w1_im(w1_im),
    .w2_re(w2_re),.w2_im(w2_im), .w3_re(w3_re),.w3_im(w3_im),
    .w_bin(w_bin_out), .w_valid(w_valid),
    .x0_re(fft0_re),.x0_im(fft0_im), .x1_re(fft1_re),.x1_im(fft1_im),
    .x2_re(fft2_re),.x2_im(fft2_im), .x3_re(fft3_re),.x3_im(fft3_im),
    .x_bin(bin_cnt), .x_valid(bin_valid),
    .y_re(bf_re), .y_im(bf_im), .y_bin(bf_bin), .y_valid(bf_valid)
);

// ============================================================================
// BEAMFORMED BIN BUFFER
// Problem: bf_valid fires bins 0..128 spread over ~130 cycles.
// IFFT needs all 256 bins in one back-to-back burst.
// Solution: store bins 0..128 as they arrive, then burst all 256 bins
//           (0..128 from buffer, 129..255 as conjugate mirror of 127..1).
//
// Buffer size: 129 entries x 2 x 16-bit = 4128 bits (~0.5 BRAM)
// ============================================================================
reg signed [DW-1:0] bin_buf_re [0:NBINS-1];  // bins 0..128
reg signed [DW-1:0] bin_buf_im [0:NBINS-1];

// Store beamformed bins as they arrive
always @(posedge clk) begin
    if (bf_valid)
        begin
            bin_buf_re[bf_bin] <= bf_re;
            bin_buf_im[bf_bin] <= bf_im;
        end
end

// Detect when all 129 bins collected -> trigger IFFT burst
reg buf_ready;
reg ifft_bursting;
reg [8:0] iburst_cnt;    // 0..255

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        buf_ready <= 0;
        ifft_bursting<= 0;
        iburst_cnt <= 0;
    end else begin
        buf_ready <= 0;
        if (bf_valid && bf_bin == NBINS-1)
            buf_ready <= 1;

        if (buf_ready)
            ifft_bursting <= 1;

        if (ifft_bursting) begin
            if (iburst_cnt == 255) begin
                iburst_cnt <= 0;
                ifft_bursting <= 0;
            end else
                iburst_cnt <= iburst_cnt + 1;
        end
    end
end

// IFFT input mux: bins 0..128 from buffer, bins 129..255 conjugate mirror
// bin k (129..255) mirrors bin (256-k):
//   k=129 -> mirror of bin 127
//   k=255 -> mirror of bin 1
//   k=128 is Nyquist -> real, no mirror needed (already in buf as bin 128)
// Bit-reversal LUT for IFFT DIT input ordering
reg [7:0] bit_rev_lut [0:255];
integer brl;
initial begin
    for (brl = 0; brl < 256; brl = brl + 1) begin : bitrv
        integer rr, bb;
        rr = 0;
        for (bb = 0; bb < 8; bb = bb + 1)
            rr = rr | (((brl >> bb) & 1) << (7 - bb));
        bit_rev_lut[brl] = rr;
    end
end

// Natural bin index for IFFT input position iburst_cnt:
//   iburst_cnt 0..128: forward bins from bin_buf
//   iburst_cnt 129..255: conjugate mirror (bin 256-iburst_cnt)
// Then apply bit_rev so DIT IFFT receives correct order
wire [7:0] mirror_idx = 8'd0 + (9'd256 - iburst_cnt);
wire [7:0] nat_bin = (iburst_cnt <= 128) ? iburst_cnt[7:0] : mirror_idx;
wire [7:0] br_bin = bit_rev_lut[iburst_cnt];  // bit-reversed position to feed

wire signed [DW-1:0] ifft_x_re = (iburst_cnt <= 128) ?
                                bin_buf_re[nat_bin] :
                                bin_buf_re[mirror_idx];
wire signed [DW-1:0] ifft_x_im = (iburst_cnt <= 128) ?
                                bin_buf_im[nat_bin] :
                                -bin_buf_im[mirror_idx];

// ============================================================================
// IFFT
// ============================================================================
wire signed [DW-1:0] ifft_re, ifft_im;
wire ifft_valid, ifft_last;

ifft_r2dit ifft0 (
    .clk(clk), .rst_n(rst_n),
    .x_re(ifft_x_re), .x_im(ifft_x_im),
    .x_valid(ifft_bursting),
    .y_re(ifft_re), .y_im(ifft_im),
    .y_valid(ifft_valid), .y_last(ifft_last)
);

// ============================================================================
// OVERLAP-ADD -> PCM OUTPUT
// ============================================================================
overlap_add ola (
    .clk(clk), .rst_n(rst_n),
    .x_re(ifft_re), .x_valid(ifft_valid), .x_last(ifft_last),
    .pcm_out(pcm_out), .pcm_valid(pcm_valid), .pcm_last(pcm_last)
);

endmodule