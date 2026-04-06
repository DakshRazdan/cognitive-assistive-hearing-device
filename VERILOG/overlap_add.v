// overlap_add.v -- 50% Overlap-Add Reconstruction
`timescale 1ns/1ps

module overlap_add #(
    parameter N = 256,
    parameter HOP = 128,
    parameter DW = 16
)(
    input wire clk,
    input wire rst_n,
    input wire signed [DW-1:0] x_re,
    input wire x_valid,
    input wire x_last,
    output reg signed [DW-1:0] pcm_out,
    output reg pcm_valid,
    output reg pcm_last
);

// Hann window ROM Q1.15
(* ramstyle = "M9K" *) reg signed [DW-1:0] hann [0:N-1];
initial begin
    hann[0] = 16'h0000;
    hann[1] = 16'h0004;
    hann[2] = 16'h0013;
    hann[3] = 16'h002C;
    hann[4] = 16'h004E;
    hann[5] = 16'h007B;
    hann[6] = 16'h00B1;
    hann[7] = 16'h00F1;
    hann[8] = 16'h013A;
    hann[9] = 16'h018E;
    hann[10] = 16'h01EA;
    hann[11] = 16'h0251;
    hann[12] = 16'h02C1;
    hann[13] = 16'h033A;
    hann[14] = 16'h03BD;
    hann[15] = 16'h0449;
    hann[16] = 16'h04DF;
    hann[17] = 16'h057D;
    hann[18] = 16'h0624;
    hann[19] = 16'h06D5;
    hann[20] = 16'h078E;
    hann[21] = 16'h0850;
    hann[22] = 16'h091A;
    hann[23] = 16'h09ED;
    hann[24] = 16'h0AC9;
    hann[25] = 16'h0BAC;
    hann[26] = 16'h0C98;
    hann[27] = 16'h0D8B;
    hann[28] = 16'h0E86;
    hann[29] = 16'h0F89;
    hann[30] = 16'h1094;
    hann[31] = 16'h11A5;
    hann[32] = 16'h12BE;
    hann[33] = 16'h13DE;
    hann[34] = 16'h1505;
    hann[35] = 16'h1632;
    hann[36] = 16'h1765;
    hann[37] = 16'h189F;
    hann[38] = 16'h19DF;
    hann[39] = 16'h1B25;
    hann[40] = 16'h1C71;
    hann[41] = 16'h1DC2;
    hann[42] = 16'h1F18;
    hann[43] = 16'h2074;
    hann[44] = 16'h21D4;
    hann[45] = 16'h2339;
    hann[46] = 16'h24A2;
    hann[47] = 16'h2610;
    hann[48] = 16'h2781;
    hann[49] = 16'h28F7;
    hann[50] = 16'h2A70;
    hann[51] = 16'h2BEC;
    hann[52] = 16'h2D6B;
    hann[53] = 16'h2EED;
    hann[54] = 16'h3072;
    hann[55] = 16'h31F9;
    hann[56] = 16'h3383;
    hann[57] = 16'h350E;
    hann[58] = 16'h369B;
    hann[59] = 16'h3829;
    hann[60] = 16'h39B9;
    hann[61] = 16'h3B4A;
    hann[62] = 16'h3CDB;
    hann[63] = 16'h3E6D;
    hann[64] = 16'h3FFF;
    hann[65] = 16'h4191;
    hann[66] = 16'h4323;
    hann[67] = 16'h44B4;
    hann[68] = 16'h4645;
    hann[69] = 16'h47D5;
    hann[70] = 16'h4963;
    hann[71] = 16'h4AF0;
    hann[72] = 16'h4C7B;
    hann[73] = 16'h4E05;
    hann[74] = 16'h4F8C;
    hann[75] = 16'h5111;
    hann[76] = 16'h5293;
    hann[77] = 16'h5412;
    hann[78] = 16'h558E;
    hann[79] = 16'h5707;
    hann[80] = 16'h587D;
    hann[81] = 16'h59EE;
    hann[82] = 16'h5B5C;
    hann[83] = 16'h5CC5;
    hann[84] = 16'h5E2A;
    hann[85] = 16'h5F8A;
    hann[86] = 16'h60E6;
    hann[87] = 16'h623C;
    hann[88] = 16'h638D;
    hann[89] = 16'h64D9;
    hann[90] = 16'h661F;
    hann[91] = 16'h675F;
    hann[92] = 16'h6899;
    hann[93] = 16'h69CC;
    hann[94] = 16'h6AF9;
    hann[95] = 16'h6C20;
    hann[96] = 16'h6D40;
    hann[97] = 16'h6E59;
    hann[98] = 16'h6F6A;
    hann[99] = 16'h7075;
    hann[100] = 16'h7178;
    hann[101] = 16'h7273;
    hann[102] = 16'h7366;
    hann[103] = 16'h7452;
    hann[104] = 16'h7535;
    hann[105] = 16'h7611;
    hann[106] = 16'h76E4;
    hann[107] = 16'h77AE;
    hann[108] = 16'h7870;
    hann[109] = 16'h7929;
    hann[110] = 16'h79DA;
    hann[111] = 16'h7A81;
    hann[112] = 16'h7B1F;
    hann[113] = 16'h7BB5;
    hann[114] = 16'h7C41;
    hann[115] = 16'h7CC4;
    hann[116] = 16'h7D3D;
    hann[117] = 16'h7DAD;
    hann[118] = 16'h7E14;
    hann[119] = 16'h7E70;
    hann[120] = 16'h7EC4;
    hann[121] = 16'h7F0D;
    hann[122] = 16'h7F4D;
    hann[123] = 16'h7F83;
    hann[124] = 16'h7FB0;
    hann[125] = 16'h7FD2;
    hann[126] = 16'h7FEB;
    hann[127] = 16'h7FFA;
    hann[128] = 16'h7FFF;
    hann[129] = 16'h7FFA;
    hann[130] = 16'h7FEB;
    hann[131] = 16'h7FD2;
    hann[132] = 16'h7FB0;
    hann[133] = 16'h7F83;
    hann[134] = 16'h7F4D;
    hann[135] = 16'h7F0D;
    hann[136] = 16'h7EC4;
    hann[137] = 16'h7E70;
    hann[138] = 16'h7E14;
    hann[139] = 16'h7DAD;
    hann[140] = 16'h7D3D;
    hann[141] = 16'h7CC4;
    hann[142] = 16'h7C41;
    hann[143] = 16'h7BB5;
    hann[144] = 16'h7B1F;
    hann[145] = 16'h7A81;
    hann[146] = 16'h79DA;
    hann[147] = 16'h7929;
    hann[148] = 16'h7870;
    hann[149] = 16'h77AE;
    hann[150] = 16'h76E4;
    hann[151] = 16'h7611;
    hann[152] = 16'h7535;
    hann[153] = 16'h7452;
    hann[154] = 16'h7366;
    hann[155] = 16'h7273;
    hann[156] = 16'h7178;
    hann[157] = 16'h7075;
    hann[158] = 16'h6F6A;
    hann[159] = 16'h6E59;
    hann[160] = 16'h6D40;
    hann[161] = 16'h6C20;
    hann[162] = 16'h6AF9;
    hann[163] = 16'h69CC;
    hann[164] = 16'h6899;
    hann[165] = 16'h675F;
    hann[166] = 16'h661F;
    hann[167] = 16'h64D9;
    hann[168] = 16'h638D;
    hann[169] = 16'h623C;
    hann[170] = 16'h60E6;
    hann[171] = 16'h5F8A;
    hann[172] = 16'h5E2A;
    hann[173] = 16'h5CC5;
    hann[174] = 16'h5B5C;
    hann[175] = 16'h59EE;
    hann[176] = 16'h587D;
    hann[177] = 16'h5707;
    hann[178] = 16'h558E;
    hann[179] = 16'h5412;
    hann[180] = 16'h5293;
    hann[181] = 16'h5111;
    hann[182] = 16'h4F8C;
    hann[183] = 16'h4E05;
    hann[184] = 16'h4C7B;
    hann[185] = 16'h4AF0;
    hann[186] = 16'h4963;
    hann[187] = 16'h47D5;
    hann[188] = 16'h4645;
    hann[189] = 16'h44B4;
    hann[190] = 16'h4323;
    hann[191] = 16'h4191;
    hann[192] = 16'h3FFF;
    hann[193] = 16'h3E6D;
    hann[194] = 16'h3CDB;
    hann[195] = 16'h3B4A;
    hann[196] = 16'h39B9;
    hann[197] = 16'h3829;
    hann[198] = 16'h369B;
    hann[199] = 16'h350E;
    hann[200] = 16'h3383;
    hann[201] = 16'h31F9;
    hann[202] = 16'h3072;
    hann[203] = 16'h2EED;
    hann[204] = 16'h2D6B;
    hann[205] = 16'h2BEC;
    hann[206] = 16'h2A70;
    hann[207] = 16'h28F7;
    hann[208] = 16'h2781;
    hann[209] = 16'h2610;
    hann[210] = 16'h24A2;
    hann[211] = 16'h2339;
    hann[212] = 16'h21D4;
    hann[213] = 16'h2074;
    hann[214] = 16'h1F18;
    hann[215] = 16'h1DC2;
    hann[216] = 16'h1C71;
    hann[217] = 16'h1B25;
    hann[218] = 16'h19DF;
    hann[219] = 16'h189F;
    hann[220] = 16'h1765;
    hann[221] = 16'h1632;
    hann[222] = 16'h1505;
    hann[223] = 16'h13DE;
    hann[224] = 16'h12BE;
    hann[225] = 16'h11A5;
    hann[226] = 16'h1094;
    hann[227] = 16'h0F89;
    hann[228] = 16'h0E86;
    hann[229] = 16'h0D8B;
    hann[230] = 16'h0C98;
    hann[231] = 16'h0BAC;
    hann[232] = 16'h0AC9;
    hann[233] = 16'h09ED;
    hann[234] = 16'h091A;
    hann[235] = 16'h0850;
    hann[236] = 16'h078E;
    hann[237] = 16'h06D5;
    hann[238] = 16'h0624;
    hann[239] = 16'h057D;
    hann[240] = 16'h04DF;
    hann[241] = 16'h0449;
    hann[242] = 16'h03BD;
    hann[243] = 16'h033A;
    hann[244] = 16'h02C1;
    hann[245] = 16'h0251;
    hann[246] = 16'h01EA;
    hann[247] = 16'h018E;
    hann[248] = 16'h013A;
    hann[249] = 16'h00F1;
    hann[250] = 16'h00B1;
    hann[251] = 16'h007B;
    hann[252] = 16'h004E;
    hann[253] = 16'h002C;
    hann[254] = 16'h0013;
    hann[255] = 16'h0004;
end

// Overlap buffer: windowed tail of previous frame
(* ramstyle = "M9K" *) reg signed [DW-1:0] overlap_buf [0:HOP-1];
integer oi;
initial begin
    for (oi = 0; oi < HOP; oi = oi + 1) overlap_buf[oi] = 0;
end

// Frame buffer: windowed current frame
(* ramstyle = "M9K" *) reg signed [DW-1:0] frame_buf [0:N-1];
integer fi;
initial begin
    for (fi = 0; fi < N; fi = fi + 1) frame_buf[fi] = 0;
end

localparam ST_IDLE = 2'd0;
localparam ST_WINDOW = 2'd1;
localparam ST_OUTPUT = 2'd2;

reg [1:0] state;
reg [7:0] cnt;     // 0..255 window, 0..127 output

// ============================================================================
// COMBINATIONAL WIRES for array reads — avoids iverilog blocking-assign issue
// 1D arrays with variable index in wire assign are safe in iverilog
// ============================================================================
wire signed [DW-1:0] fb_val = frame_buf[cnt];          // frame_buf[cnt]
wire signed [DW-1:0] ob_val = overlap_buf[cnt];         // overlap_buf[cnt]
wire signed [DW-1:0] fb_tail = frame_buf[cnt + HOP];     // frame_buf[cnt+128]
wire signed [DW-1:0] hw_val = hann[cnt];                // hann[cnt]

// Overlap-add sum — 17-bit to catch overflow before saturation
wire signed [16:0] oa_sum = $signed(fb_val) + $signed(ob_val);

// Saturated output
wire signed [DW-1:0] oa_sat =
    (oa_sum > 17'sd32767)  ? 16'sd32767  :
    (oa_sum < -17'sd32768) ? -16'sd32768 :
    oa_sum[DW-1:0];

// Windowed input: x_re * hann[cnt] >> 15
wire signed [2*DW-1:0] win_full = $signed(x_re) * $signed(hw_val);
wire signed [DW-1:0] win_val = win_full >>> 15;

// ============================================================================
// FSM
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= ST_IDLE;
        cnt <= 0;
        pcm_valid <= 0;
        pcm_last <= 0;
        pcm_out <= 0;
    end else begin
        pcm_valid <= 0;
        pcm_last <= 0;

        case (state)

        ST_IDLE: begin
            if (x_valid) begin
                frame_buf[cnt] <= win_val;
                if (cnt == N-1) begin
                    cnt <= 0;
                    state <= ST_OUTPUT;
                end else
                    cnt <= cnt + 1;
            end
        end

        ST_WINDOW: begin  // alias — ST_IDLE handles both via cnt
            state <= ST_IDLE;
        end

        ST_OUTPUT: begin
            pcm_out <= oa_sat;
            pcm_valid <= 1;
            pcm_last <= (cnt == HOP-1);
            overlap_buf[cnt] <= fb_tail;  // save second half as new overlap
            if (cnt == HOP-1) begin
                cnt <= 0;
                state <= ST_IDLE;
            end else
                cnt <= cnt + 1;
        end

        default: state <= ST_IDLE;
        endcase
    end
end

endmodule