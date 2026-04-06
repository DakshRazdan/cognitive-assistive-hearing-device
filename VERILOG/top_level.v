// ============================================================================
// top_level.v -- Cognitive-Assistive Hearing Device (Resource-Optimized)
// 
// KEY CHANGE: Single shared FFT processes all 4 channels sequentially
// instead of 4 parallel FFTs. Saves ~75% of FFT logic elements.
// One FFT at 100MHz processes 256 samples in ~20us per channel,
// 4 channels = 80us total — well within 8ms frame budget.
//
// Target: EP4CE115F29C7 (DE2-115), Cyclone IV E
// ============================================================================

`timescale 1ns/1ps

module top_level (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sdata_01,
    input  wire        sdata_23,
    output wire        bclk,
    output wire        ws,
    output wire        sdata_out,
    output wire        pcm_valid_out
);

localparam N     = 256;
localparam NBINS = 129;
localparam DW    = 16;

// ============================================================================
// I2S CLOCK + RX
// ============================================================================
wire mclk_unused;
i2s_master_clk clk_gen (.clk(clk),.rst_n(rst_n),.bclk(bclk),.ws(ws),.mclk(mclk_unused));

wire [23:0] mic0_raw, mic1_raw, mic2_raw, mic3_raw;
wire i2s_valid_01, i2s_valid_23;

i2s_rx rx_01 (.clk(clk),.rst_n(rst_n),.bclk(bclk),.ws(ws),.sdata(sdata_01),
              .left_out(mic0_raw),.right_out(mic1_raw),.valid(i2s_valid_01));
i2s_rx rx_23 (.clk(clk),.rst_n(rst_n),.bclk(bclk),.ws(ws),.sdata(sdata_23),
              .left_out(mic2_raw),.right_out(mic3_raw),.valid(i2s_valid_23));

// ============================================================================
// CIC DECIMATORS x4
// ============================================================================
wire [15:0] cic0_out, cic1_out, cic2_out, cic3_out;
wire cic0_valid, cic1_valid, cic2_valid, cic3_valid;

cic_decimator cic0(.clk(clk),.rst_n(rst_n),.x_in(mic0_raw),.x_valid(i2s_valid_01),.y_out(cic0_out),.y_valid(cic0_valid));
cic_decimator cic1(.clk(clk),.rst_n(rst_n),.x_in(mic1_raw),.x_valid(i2s_valid_01),.y_out(cic1_out),.y_valid(cic1_valid));
cic_decimator cic2(.clk(clk),.rst_n(rst_n),.x_in(mic2_raw),.x_valid(i2s_valid_23),.y_out(cic2_out),.y_valid(cic2_valid));
cic_decimator cic3(.clk(clk),.rst_n(rst_n),.x_in(mic3_raw),.x_valid(i2s_valid_23),.y_out(cic3_out),.y_valid(cic3_valid));

// ============================================================================
// SAMPLE BUFFERS — store 256 samples per channel for FFT
// ============================================================================
(* ramstyle = "M9K" *) reg signed [DW-1:0] sbuf0 [0:N-1];
(* ramstyle = "M9K" *) reg signed [DW-1:0] sbuf1 [0:N-1];
(* ramstyle = "M9K" *) reg signed [DW-1:0] sbuf2 [0:N-1];
(* ramstyle = "M9K" *) reg signed [DW-1:0] sbuf3 [0:N-1];

reg [7:0] samp_cnt;
reg       frame_ready;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        samp_cnt <= 0; frame_ready <= 0;
    end else begin
        frame_ready <= 0;
        if (cic0_valid) begin
            sbuf0[samp_cnt] <= cic0_out[15:0];
            sbuf1[samp_cnt] <= cic1_out[15:0];
            sbuf2[samp_cnt] <= cic2_out[15:0];
            sbuf3[samp_cnt] <= cic3_out[15:0];
            if (samp_cnt == N-1) begin
                samp_cnt    <= 0;
                frame_ready <= 1;
            end else
                samp_cnt <= samp_cnt + 1;
        end
    end
end

// ============================================================================
// SHARED FFT SEQUENCER
// Feeds 4 channels one after another into single FFT instance
// ch=0: mic0, ch=1: mic1, ch=2: mic2, ch=3: mic3
// ============================================================================
reg [1:0]  fft_ch;        // current channel 0..3
reg [7:0]  fft_feed_cnt;  // sample index 0..255
reg        fft_feeding;
reg        fft_x_valid;
reg signed [DW-1:0] fft_x_re;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fft_ch <= 0; fft_feed_cnt <= 0;
        fft_feeding <= 0; fft_x_valid <= 0; fft_x_re <= 0;
    end else begin
        fft_x_valid <= 0;
        if (frame_ready && !fft_feeding) begin
            fft_ch      <= 0;
            fft_feed_cnt<= 0;
            fft_feeding <= 1;
        end else if (fft_feeding) begin
            // Select sample from appropriate buffer
            case (fft_ch)
                2'd0: fft_x_re <= sbuf0[fft_feed_cnt];
                2'd1: fft_x_re <= sbuf1[fft_feed_cnt];
                2'd2: fft_x_re <= sbuf2[fft_feed_cnt];
                2'd3: fft_x_re <= sbuf3[fft_feed_cnt];
            endcase
            fft_x_valid <= 1;
            if (fft_feed_cnt == N-1) begin
                fft_feed_cnt <= 0;
                if (fft_ch == 3)
                    fft_feeding <= 0;
                else
                    fft_ch <= fft_ch + 1;
            end else
                fft_feed_cnt <= fft_feed_cnt + 1;
        end
    end
end

// ============================================================================
// SINGLE SHARED FFT
// ============================================================================
wire signed [DW-1:0] fft_y_re, fft_y_im;
wire fft_y_valid, fft_y_last;

fft_r2dit fft_shared (
    .clk(clk), .rst_n(rst_n),
    .x_re(fft_x_re), .x_valid(fft_x_valid),
    .y_re(fft_y_re), .y_im(fft_y_im),
    .y_valid(fft_y_valid), .y_last(fft_y_last)
);

// ============================================================================
// FFT OUTPUT CAPTURE — store bins per channel
// ============================================================================
(* ramstyle = "M9K" *) reg signed [DW-1:0] fft_re [0:3][0:NBINS-1];
(* ramstyle = "M9K" *) reg signed [DW-1:0] fft_im [0:3][0:NBINS-1];

reg [1:0]  cap_ch;
reg [7:0]  cap_bin;
reg        cap_active;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cap_ch <= 0; cap_bin <= 0; cap_active <= 0;
    end else begin
        if (fft_y_valid) begin
            cap_active <= 1;
            if (cap_bin < NBINS) begin
                fft_re[cap_ch][cap_bin] <= fft_y_re;
                fft_im[cap_ch][cap_bin] <= fft_y_im;
            end
            if (fft_y_last) begin
                cap_bin <= 0;
                if (cap_ch == 3) begin cap_ch <= 0; cap_active <= 0; end
                else cap_ch <= cap_ch + 1;
            end else
                cap_bin <= cap_bin + 1;
        end
    end
end

// All 4 channels ready when cap_ch wraps back to 0
wire all_ch_ready = (cap_ch == 0) && cap_active && fft_y_last;

// ============================================================================
// BIN SEQUENCER — feed bins to covariance + beamformer
// ============================================================================
reg [7:0] bin_seq;
reg       bin_valid;
reg       bin_running;

wire signed [DW-1:0] x0_re = fft_re[0][bin_seq];
wire signed [DW-1:0] x0_im = fft_im[0][bin_seq];
wire signed [DW-1:0] x1_re = fft_re[1][bin_seq];
wire signed [DW-1:0] x1_im = fft_im[1][bin_seq];
wire signed [DW-1:0] x2_re = fft_re[2][bin_seq];
wire signed [DW-1:0] x2_im = fft_im[2][bin_seq];
wire signed [DW-1:0] x3_re = fft_re[3][bin_seq];
wire signed [DW-1:0] x3_im = fft_im[3][bin_seq];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bin_seq <= 0; bin_valid <= 0; bin_running <= 0;
    end else begin
        bin_valid <= 0;
        if (all_ch_ready && !bin_running) begin
            bin_seq     <= 0;
            bin_running <= 1;
        end else if (bin_running) begin
            bin_valid <= 1;
            if (bin_seq == NBINS-1) begin
                bin_seq     <= 0;
                bin_running <= 0;
            end else
                bin_seq <= bin_seq + 1;
        end
    end
end

// ============================================================================
// COVARIANCE ESTIMATOR
// ============================================================================
wire [7:0]           cov_rd_bin;
wire [3:0]           cov_rd_elem;
wire                 cov_rd_en;
wire signed [DW-1:0] cov_rd_re, cov_rd_im;
wire                 cov_rd_valid;

covariance_est cov (
    .clk(clk), .rst_n(rst_n),
    .x0_re(x0_re), .x0_im(x0_im),
    .x1_re(x1_re), .x1_im(x1_im),
    .x2_re(x2_re), .x2_im(x2_im),
    .x3_re(x3_re), .x3_im(x3_im),
    .x_bin(bin_seq), .x_valid(bin_valid),
    .rd_bin(cov_rd_bin), .rd_elem(cov_rd_elem), .rd_en(cov_rd_en),
    .rd_re(cov_rd_re), .rd_im(cov_rd_im), .rd_valid(cov_rd_valid)
);

// ============================================================================
// MVDR WEIGHT SEQUENCER
// ============================================================================
reg [7:0] wgt_bin;
reg       wgt_compute, wgt_busy;

wire signed [DW-1:0] w0_re,w0_im,w1_re,w1_im,w2_re,w2_im,w3_re,w3_im;
wire [7:0] w_bin_out;
wire       w_valid;

mvdr_weights wgt (
    .clk(clk), .rst_n(rst_n),
    .compute(wgt_compute), .bin_in(wgt_bin),
    .rd_bin(cov_rd_bin), .rd_elem(cov_rd_elem), .rd_en(cov_rd_en),
    .rd_re(cov_rd_re), .rd_im(cov_rd_im), .rd_valid(cov_rd_valid),
    .w0_re(w0_re),.w0_im(w0_im),.w1_re(w1_re),.w1_im(w1_im),
    .w2_re(w2_re),.w2_im(w2_im),.w3_re(w3_re),.w3_im(w3_im),
    .w_bin(w_bin_out),.w_valid(w_valid)
);

reg bin_last_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin wgt_bin<=0; wgt_compute<=0; wgt_busy<=0; bin_last_d<=0; end
    else begin
        wgt_compute <= 0;
        bin_last_d  <= (bin_seq == NBINS-1) && bin_valid;
        if (bin_last_d && !wgt_busy) begin
            wgt_bin<=0; wgt_compute<=1; wgt_busy<=1;
        end else if (w_valid && wgt_busy) begin
            if (wgt_bin==NBINS-1) wgt_busy<=0;
            else begin wgt_bin<=wgt_bin+1; wgt_compute<=1; end
        end
    end
end

// ============================================================================
// BEAMFORMER APPLY
// ============================================================================
wire signed [DW-1:0] bf_re, bf_im;
wire [7:0]            bf_bin;
wire                  bf_valid;

beamformer_apply bf (
    .clk(clk), .rst_n(rst_n),
    .w0_re(w0_re),.w0_im(w0_im),.w1_re(w1_re),.w1_im(w1_im),
    .w2_re(w2_re),.w2_im(w2_im),.w3_re(w3_re),.w3_im(w3_im),
    .w_bin(w_bin_out),.w_valid(w_valid),
    .x0_re(x0_re),.x0_im(x0_im),.x1_re(x1_re),.x1_im(x1_im),
    .x2_re(x2_re),.x2_im(x2_im),.x3_re(x3_re),.x3_im(x3_im),
    .x_bin(bin_seq),.x_valid(bin_valid),
    .y_re(bf_re),.y_im(bf_im),.y_bin(bf_bin),.y_valid(bf_valid)
);

// ============================================================================
// BEAMFORMED BIN BUFFER + IFFT BURST
// ============================================================================
(* ramstyle = "M9K" *) reg signed [DW-1:0] bin_buf_re [0:NBINS-1];
(* ramstyle = "M9K" *) reg signed [DW-1:0] bin_buf_im [0:NBINS-1];

always @(posedge clk) begin
    if (bf_valid) begin
        bin_buf_re[bf_bin] <= bf_re;
        bin_buf_im[bf_bin] <= bf_im;
    end
end

reg        ifft_bursting;
reg [8:0]  iburst_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin ifft_bursting<=0; iburst_cnt<=0; end
    else begin
        if (bf_valid && bf_bin==NBINS-1) ifft_bursting<=1;
        if (ifft_bursting) begin
            if (iburst_cnt==255) begin iburst_cnt<=0; ifft_bursting<=0; end
            else iburst_cnt<=iburst_cnt+1;
        end
    end
end

wire [7:0]           mirror_idx = 8'd0 + (9'd256 - iburst_cnt);
wire signed [DW-1:0] ifft_x_re  = (iburst_cnt<=128) ? bin_buf_re[iburst_cnt[7:0]] : bin_buf_re[mirror_idx];
wire signed [DW-1:0] ifft_x_im  = (iburst_cnt<=128) ? bin_buf_im[iburst_cnt[7:0]] : -bin_buf_im[mirror_idx];

// ============================================================================
// IFFT
// ============================================================================
wire signed [DW-1:0] ifft_re, ifft_im;
wire                  ifft_valid, ifft_last;

ifft_r2dit ifft0 (
    .clk(clk),.rst_n(rst_n),
    .x_re(ifft_x_re),.x_im(ifft_x_im),.x_valid(ifft_bursting),
    .y_re(ifft_re),.y_im(ifft_im),.y_valid(ifft_valid),.y_last(ifft_last)
);

// ============================================================================
// OVERLAP-ADD
// ============================================================================
wire signed [DW-1:0] ola_out;
wire                  ola_valid, ola_last;

overlap_add ola (
    .clk(clk),.rst_n(rst_n),
    .x_re(ifft_re),.x_valid(ifft_valid),.x_last(ifft_last),
    .pcm_out(ola_out),.pcm_valid(ola_valid),.pcm_last(ola_last)
);

// ============================================================================
// VAD
// ============================================================================
wire speech_flag;
vad vad_inst (.clk(clk),.rst_n(rst_n),.pcm_in(ola_out),.pcm_valid(ola_valid),.speech(speech_flag));

// ============================================================================
// LMS FILTER
// ============================================================================
wire signed [DW-1:0] lms_out;
wire                  lms_valid;
lms_filter lms_inst (
    .clk(clk),.rst_n(rst_n),
    .pcm_in(ola_out),.pcm_valid(ola_valid),.speech(speech_flag),
    .pcm_out(lms_out),.pcm_out_valid(lms_valid)
);

// ============================================================================
// SPECTRAL SUBTRACTION
// ============================================================================
wire signed [DW-1:0] ss_re, ss_im;
wire [7:0]            ss_bin;
wire                  ss_valid;
spectral_sub ss_inst (
    .clk(clk),.rst_n(rst_n),
    .x_re(bf_re),.x_im(bf_im),.x_bin(bf_bin),.x_valid(bf_valid),
    .speech(speech_flag),
    .y_re(ss_re),.y_im(ss_im),.y_bin(ss_bin),.y_valid(ss_valid)
);

// ============================================================================
// COMPRESSOR
// ============================================================================
wire signed [DW-1:0] comp_out;
wire                  comp_valid;
compressor comp_inst (
    .clk(clk),.rst_n(rst_n),
    .pcm_in(lms_out),.pcm_valid(lms_valid),
    .pcm_out(comp_out),.pcm_out_valid(comp_valid)
);

// ============================================================================
// FREQUENCY SHAPER
// ============================================================================
wire signed [DW-1:0] shaped_out;
wire                  shaped_valid;
freq_shaper shape_inst (
    .clk(clk),.rst_n(rst_n),
    .pcm_in(comp_out),.pcm_valid(comp_valid),
    .pcm_out(shaped_out),.pcm_out_valid(shaped_valid)
);

// ============================================================================
// I2S TX
// ============================================================================
i2s_tx tx_inst (
    .clk(clk),.rst_n(rst_n),
    .bclk(bclk),.ws(ws),
    .pcm_in(shaped_out),.pcm_valid(shaped_valid),
    .sdata(sdata_out)
);

assign pcm_valid_out = shaped_valid;

endmodule