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
initial begin
    hann_rom[0] = 16'sd0;
    hann_rom[1] = 16'sd4;
    hann_rom[2] = 16'sd19;
    hann_rom[3] = 16'sd44;
    hann_rom[4] = 16'sd78;
    hann_rom[5] = 16'sd123;
    hann_rom[6] = 16'sd177;
    hann_rom[7] = 16'sd241;
    hann_rom[8] = 16'sd314;
    hann_rom[9] = 16'sd398;
    hann_rom[10] = 16'sd490;
    hann_rom[11] = 16'sd593;
    hann_rom[12] = 16'sd705;
    hann_rom[13] = 16'sd826;
    hann_rom[14] = 16'sd957;
    hann_rom[15] = 16'sd1097;
    hann_rom[16] = 16'sd1247;
    hann_rom[17] = 16'sd1405;
    hann_rom[18] = 16'sd1572;
    hann_rom[19] = 16'sd1749;
    hann_rom[20] = 16'sd1934;
    hann_rom[21] = 16'sd2128;
    hann_rom[22] = 16'sd2330;
    hann_rom[23] = 16'sd2541;
    hann_rom[24] = 16'sd2761;
    hann_rom[25] = 16'sd2988;
    hann_rom[26] = 16'sd3224;
    hann_rom[27] = 16'sd3467;
    hann_rom[28] = 16'sd3718;
    hann_rom[29] = 16'sd3977;
    hann_rom[30] = 16'sd4244;
    hann_rom[31] = 16'sd4517;
    hann_rom[32] = 16'sd4798;
    hann_rom[33] = 16'sd5086;
    hann_rom[34] = 16'sd5381;
    hann_rom[35] = 16'sd5682;
    hann_rom[36] = 16'sd5989;
    hann_rom[37] = 16'sd6303;
    hann_rom[38] = 16'sd6623;
    hann_rom[39] = 16'sd6949;
    hann_rom[40] = 16'sd7281;
    hann_rom[41] = 16'sd7618;
    hann_rom[42] = 16'sd7960;
    hann_rom[43] = 16'sd8308;
    hann_rom[44] = 16'sd8660;
    hann_rom[45] = 16'sd9017;
    hann_rom[46] = 16'sd9378;
    hann_rom[47] = 16'sd9744;
    hann_rom[48] = 16'sd10113;
    hann_rom[49] = 16'sd10487;
    hann_rom[50] = 16'sd10864;
    hann_rom[51] = 16'sd11244;
    hann_rom[52] = 16'sd11627;
    hann_rom[53] = 16'sd12013;
    hann_rom[54] = 16'sd12402;
    hann_rom[55] = 16'sd12793;
    hann_rom[56] = 16'sd13187;
    hann_rom[57] = 16'sd13582;
    hann_rom[58] = 16'sd13979;
    hann_rom[59] = 16'sd14377;
    hann_rom[60] = 16'sd14777;
    hann_rom[61] = 16'sd15178;
    hann_rom[62] = 16'sd15579;
    hann_rom[63] = 16'sd15981;
    hann_rom[64] = 16'sd16383;
    hann_rom[65] = 16'sd16785;
    hann_rom[66] = 16'sd17187;
    hann_rom[67] = 16'sd17588;
    hann_rom[68] = 16'sd17989;
    hann_rom[69] = 16'sd18389;
    hann_rom[70] = 16'sd18787;
    hann_rom[71] = 16'sd19184;
    hann_rom[72] = 16'sd19579;
    hann_rom[73] = 16'sd19973;
    hann_rom[74] = 16'sd20364;
    hann_rom[75] = 16'sd20753;
    hann_rom[76] = 16'sd21139;
    hann_rom[77] = 16'sd21522;
    hann_rom[78] = 16'sd21902;
    hann_rom[79] = 16'sd22279;
    hann_rom[80] = 16'sd22653;
    hann_rom[81] = 16'sd23022;
    hann_rom[82] = 16'sd23388;
    hann_rom[83] = 16'sd23749;
    hann_rom[84] = 16'sd24106;
    hann_rom[85] = 16'sd24458;
    hann_rom[86] = 16'sd24806;
    hann_rom[87] = 16'sd25148;
    hann_rom[88] = 16'sd25485;
    hann_rom[89] = 16'sd25817;
    hann_rom[90] = 16'sd26143;
    hann_rom[91] = 16'sd26463;
    hann_rom[92] = 16'sd26777;
    hann_rom[93] = 16'sd27084;
    hann_rom[94] = 16'sd27385;
    hann_rom[95] = 16'sd27680;
    hann_rom[96] = 16'sd27968;
    hann_rom[97] = 16'sd28249;
    hann_rom[98] = 16'sd28522;
    hann_rom[99] = 16'sd28789;
    hann_rom[100] = 16'sd29048;
    hann_rom[101] = 16'sd29299;
    hann_rom[102] = 16'sd29542;
    hann_rom[103] = 16'sd29778;
    hann_rom[104] = 16'sd30005;
    hann_rom[105] = 16'sd30225;
    hann_rom[106] = 16'sd30436;
    hann_rom[107] = 16'sd30638;
    hann_rom[108] = 16'sd30832;
    hann_rom[109] = 16'sd31017;
    hann_rom[110] = 16'sd31194;
    hann_rom[111] = 16'sd31361;
    hann_rom[112] = 16'sd31519;
    hann_rom[113] = 16'sd31669;
    hann_rom[114] = 16'sd31809;
    hann_rom[115] = 16'sd31940;
    hann_rom[116] = 16'sd32061;
    hann_rom[117] = 16'sd32173;
    hann_rom[118] = 16'sd32276;
    hann_rom[119] = 16'sd32368;
    hann_rom[120] = 16'sd32452;
    hann_rom[121] = 16'sd32525;
    hann_rom[122] = 16'sd32589;
    hann_rom[123] = 16'sd32643;
    hann_rom[124] = 16'sd32688;
    hann_rom[125] = 16'sd32722;
    hann_rom[126] = 16'sd32747;
    hann_rom[127] = 16'sd32762;
    hann_rom[128] = 16'sd32767;
    hann_rom[129] = 16'sd32762;
    hann_rom[130] = 16'sd32747;
    hann_rom[131] = 16'sd32722;
    hann_rom[132] = 16'sd32688;
    hann_rom[133] = 16'sd32643;
    hann_rom[134] = 16'sd32589;
    hann_rom[135] = 16'sd32525;
    hann_rom[136] = 16'sd32452;
    hann_rom[137] = 16'sd32368;
    hann_rom[138] = 16'sd32276;
    hann_rom[139] = 16'sd32173;
    hann_rom[140] = 16'sd32061;
    hann_rom[141] = 16'sd31940;
    hann_rom[142] = 16'sd31809;
    hann_rom[143] = 16'sd31669;
    hann_rom[144] = 16'sd31519;
    hann_rom[145] = 16'sd31361;
    hann_rom[146] = 16'sd31194;
    hann_rom[147] = 16'sd31017;
    hann_rom[148] = 16'sd30832;
    hann_rom[149] = 16'sd30638;
    hann_rom[150] = 16'sd30436;
    hann_rom[151] = 16'sd30225;
    hann_rom[152] = 16'sd30005;
    hann_rom[153] = 16'sd29778;
    hann_rom[154] = 16'sd29542;
    hann_rom[155] = 16'sd29299;
    hann_rom[156] = 16'sd29048;
    hann_rom[157] = 16'sd28789;
    hann_rom[158] = 16'sd28522;
    hann_rom[159] = 16'sd28249;
    hann_rom[160] = 16'sd27968;
    hann_rom[161] = 16'sd27680;
    hann_rom[162] = 16'sd27385;
    hann_rom[163] = 16'sd27084;
    hann_rom[164] = 16'sd26777;
    hann_rom[165] = 16'sd26463;
    hann_rom[166] = 16'sd26143;
    hann_rom[167] = 16'sd25817;
    hann_rom[168] = 16'sd25485;
    hann_rom[169] = 16'sd25148;
    hann_rom[170] = 16'sd24806;
    hann_rom[171] = 16'sd24458;
    hann_rom[172] = 16'sd24106;
    hann_rom[173] = 16'sd23749;
    hann_rom[174] = 16'sd23388;
    hann_rom[175] = 16'sd23022;
    hann_rom[176] = 16'sd22653;
    hann_rom[177] = 16'sd22279;
    hann_rom[178] = 16'sd21902;
    hann_rom[179] = 16'sd21522;
    hann_rom[180] = 16'sd21139;
    hann_rom[181] = 16'sd20753;
    hann_rom[182] = 16'sd20364;
    hann_rom[183] = 16'sd19973;
    hann_rom[184] = 16'sd19579;
    hann_rom[185] = 16'sd19184;
    hann_rom[186] = 16'sd18787;
    hann_rom[187] = 16'sd18389;
    hann_rom[188] = 16'sd17989;
    hann_rom[189] = 16'sd17588;
    hann_rom[190] = 16'sd17187;
    hann_rom[191] = 16'sd16785;
    hann_rom[192] = 16'sd16383;
    hann_rom[193] = 16'sd15981;
    hann_rom[194] = 16'sd15579;
    hann_rom[195] = 16'sd15178;
    hann_rom[196] = 16'sd14777;
    hann_rom[197] = 16'sd14377;
    hann_rom[198] = 16'sd13979;
    hann_rom[199] = 16'sd13582;
    hann_rom[200] = 16'sd13187;
    hann_rom[201] = 16'sd12793;
    hann_rom[202] = 16'sd12402;
    hann_rom[203] = 16'sd12013;
    hann_rom[204] = 16'sd11627;
    hann_rom[205] = 16'sd11244;
    hann_rom[206] = 16'sd10864;
    hann_rom[207] = 16'sd10487;
    hann_rom[208] = 16'sd10113;
    hann_rom[209] = 16'sd9744;
    hann_rom[210] = 16'sd9378;
    hann_rom[211] = 16'sd9017;
    hann_rom[212] = 16'sd8660;
    hann_rom[213] = 16'sd8308;
    hann_rom[214] = 16'sd7960;
    hann_rom[215] = 16'sd7618;
    hann_rom[216] = 16'sd7281;
    hann_rom[217] = 16'sd6949;
    hann_rom[218] = 16'sd6623;
    hann_rom[219] = 16'sd6303;
    hann_rom[220] = 16'sd5989;
    hann_rom[221] = 16'sd5682;
    hann_rom[222] = 16'sd5381;
    hann_rom[223] = 16'sd5086;
    hann_rom[224] = 16'sd4798;
    hann_rom[225] = 16'sd4517;
    hann_rom[226] = 16'sd4244;
    hann_rom[227] = 16'sd3977;
    hann_rom[228] = 16'sd3718;
    hann_rom[229] = 16'sd3467;
    hann_rom[230] = 16'sd3224;
    hann_rom[231] = 16'sd2988;
    hann_rom[232] = 16'sd2761;
    hann_rom[233] = 16'sd2541;
    hann_rom[234] = 16'sd2330;
    hann_rom[235] = 16'sd2128;
    hann_rom[236] = 16'sd1934;
    hann_rom[237] = 16'sd1749;
    hann_rom[238] = 16'sd1572;
    hann_rom[239] = 16'sd1405;
    hann_rom[240] = 16'sd1247;
    hann_rom[241] = 16'sd1097;
    hann_rom[242] = 16'sd957;
    hann_rom[243] = 16'sd826;
    hann_rom[244] = 16'sd705;
    hann_rom[245] = 16'sd593;
    hann_rom[246] = 16'sd490;
    hann_rom[247] = 16'sd398;
    hann_rom[248] = 16'sd314;
    hann_rom[249] = 16'sd241;
    hann_rom[250] = 16'sd177;
    hann_rom[251] = 16'sd123;
    hann_rom[252] = 16'sd78;
    hann_rom[253] = 16'sd44;
    hann_rom[254] = 16'sd19;
    hann_rom[255] = 16'sd4;
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