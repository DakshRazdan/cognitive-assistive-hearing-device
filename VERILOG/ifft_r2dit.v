// ============================================================================
// ifft_r2dit.v -- 256-point Radix-2 DIT Inverse FFT
// 
// IFFT implemented as: IFFT{X} = conj(FFT(conj(X))) / N
//
// This is mathematically exact and reuses the verified FFT butterfly.
// Steps:
//   1. Load conj(X): store x_re as-is, store -x_im (negate imaginary)
//   2. Run identical FFT butterfly (same twiddles, same bit-reversal)
//   3. Output conj(result): output y_re as-is, output -y_im
//   4. 1/N scaling: free from 8 stages x >>1 = >>8 = /256
//
// PORTS: identical to fft_r2dit but with added x_im input
// ============================================================================

`timescale 1ns/1ps

module ifft_r2dit #(
    parameter N = 256,
    parameter DW = 16,
    parameter LOGN = 8
)(
    input wire clk,
    input wire rst_n,
    input wire signed [DW-1:0] x_re,
    input wire signed [DW-1:0] x_im,   // complex input
    input wire x_valid,
    output reg signed [DW-1:0] y_re,
    output reg signed [DW-1:0] y_im,
    output reg y_valid,
    output reg y_last
);

// Bit-reversal LUT
reg [LOGN-1:0] bit_rev [0:N-1];
integer r, b;
initial begin
    for (r = 0; r < N; r = r+1) begin
        bit_rev[r] = 0;
        for (b = 0; b < LOGN; b = b+1)
            bit_rev[r][b] = (r >> (LOGN-1-b)) & 1;
    end
end

// Sample RAM
(* ramstyle = "M9K" *) reg signed [DW-1:0] ram_re [0:N-1];
(* ramstyle = "M9K" *) reg signed [DW-1:0] ram_im [0:N-1];

// Twiddle ROM -- same as FFT (-sin), no change needed
(* ramstyle = "M9K" *) reg signed [DW-1:0] tw_re_rom [0:N/2-1];
(* ramstyle = "M9K" *) reg signed [DW-1:0] tw_im_rom [0:N/2-1];
initial begin
    tw_re_rom[0] = 16'h7FFF;
    tw_im_rom[0] = 16'h0000;
    tw_re_rom[1] = 16'h7FF5;
    tw_im_rom[1] = 16'hFCDC;
    tw_re_rom[2] = 16'h7FD7;
    tw_im_rom[2] = 16'hF9B9;
    tw_re_rom[3] = 16'h7FA6;
    tw_im_rom[3] = 16'hF696;
    tw_re_rom[4] = 16'h7F61;
    tw_im_rom[4] = 16'hF375;
    tw_re_rom[5] = 16'h7F08;
    tw_im_rom[5] = 16'hF055;
    tw_re_rom[6] = 16'h7E9C;
    tw_im_rom[6] = 16'hED39;
    tw_re_rom[7] = 16'h7E1C;
    tw_im_rom[7] = 16'hEA1F;
    tw_re_rom[8] = 16'h7D89;
    tw_im_rom[8] = 16'hE708;
    tw_re_rom[9] = 16'h7CE2;
    tw_im_rom[9] = 16'hE3F5;
    tw_re_rom[10] = 16'h7C29;
    tw_im_rom[10] = 16'hE0E7;
    tw_re_rom[11] = 16'h7B5C;
    tw_im_rom[11] = 16'hDDDD;
    tw_re_rom[12] = 16'h7A7C;
    tw_im_rom[12] = 16'hDAD9;
    tw_re_rom[13] = 16'h7989;
    tw_im_rom[13] = 16'hD7DA;
    tw_re_rom[14] = 16'h7883;
    tw_im_rom[14] = 16'hD4E2;
    tw_re_rom[15] = 16'h776B;
    tw_im_rom[15] = 16'hD1F0;
    tw_re_rom[16] = 16'h7640;
    tw_im_rom[16] = 16'hCF05;
    tw_re_rom[17] = 16'h7503;
    tw_im_rom[17] = 16'hCC22;
    tw_re_rom[18] = 16'h73B5;
    tw_im_rom[18] = 16'hC947;
    tw_re_rom[19] = 16'h7254;
    tw_im_rom[19] = 16'hC674;
    tw_re_rom[20] = 16'h70E1;
    tw_im_rom[20] = 16'hC3AA;
    tw_re_rom[21] = 16'h6F5E;
    tw_im_rom[21] = 16'hC0EA;
    tw_re_rom[22] = 16'h6DC9;
    tw_im_rom[22] = 16'hBE33;
    tw_re_rom[23] = 16'h6C23;
    tw_im_rom[23] = 16'hBB86;
    tw_re_rom[24] = 16'h6A6C;
    tw_im_rom[24] = 16'hB8E4;
    tw_re_rom[25] = 16'h68A5;
    tw_im_rom[25] = 16'hB64D;
    tw_re_rom[26] = 16'h66CE;
    tw_im_rom[26] = 16'hB3C1;
    tw_re_rom[27] = 16'h64E7;
    tw_im_rom[27] = 16'hB141;
    tw_re_rom[28] = 16'h62F1;
    tw_im_rom[28] = 16'hAECD;
    tw_re_rom[29] = 16'h60EB;
    tw_im_rom[29] = 16'hAC66;
    tw_re_rom[30] = 16'h5ED6;
    tw_im_rom[30] = 16'hAA0C;
    tw_re_rom[31] = 16'h5CB3;
    tw_im_rom[31] = 16'hA7BE;
    tw_re_rom[32] = 16'h5A81;
    tw_im_rom[32] = 16'hA57F;
    tw_re_rom[33] = 16'h5842;
    tw_im_rom[33] = 16'hA34D;
    tw_re_rom[34] = 16'h55F4;
    tw_im_rom[34] = 16'hA12A;
    tw_re_rom[35] = 16'h539A;
    tw_im_rom[35] = 16'h9F15;
    tw_re_rom[36] = 16'h5133;
    tw_im_rom[36] = 16'h9D0F;
    tw_re_rom[37] = 16'h4EBF;
    tw_im_rom[37] = 16'h9B19;
    tw_re_rom[38] = 16'h4C3F;
    tw_im_rom[38] = 16'h9932;
    tw_re_rom[39] = 16'h49B3;
    tw_im_rom[39] = 16'h975B;
    tw_re_rom[40] = 16'h471C;
    tw_im_rom[40] = 16'h9594;
    tw_re_rom[41] = 16'h447A;
    tw_im_rom[41] = 16'h93DD;
    tw_re_rom[42] = 16'h41CD;
    tw_im_rom[42] = 16'h9237;
    tw_re_rom[43] = 16'h3F16;
    tw_im_rom[43] = 16'h90A2;
    tw_re_rom[44] = 16'h3C56;
    tw_im_rom[44] = 16'h8F1F;
    tw_re_rom[45] = 16'h398C;
    tw_im_rom[45] = 16'h8DAC;
    tw_re_rom[46] = 16'h36B9;
    tw_im_rom[46] = 16'h8C4B;
    tw_re_rom[47] = 16'h33DE;
    tw_im_rom[47] = 16'h8AFD;
    tw_re_rom[48] = 16'h30FB;
    tw_im_rom[48] = 16'h89C0;
    tw_re_rom[49] = 16'h2E10;
    tw_im_rom[49] = 16'h8895;
    tw_re_rom[50] = 16'h2B1E;
    tw_im_rom[50] = 16'h877D;
    tw_re_rom[51] = 16'h2826;
    tw_im_rom[51] = 16'h8677;
    tw_re_rom[52] = 16'h2527;
    tw_im_rom[52] = 16'h8584;
    tw_re_rom[53] = 16'h2223;
    tw_im_rom[53] = 16'h84A4;
    tw_re_rom[54] = 16'h1F19;
    tw_im_rom[54] = 16'h83D7;
    tw_re_rom[55] = 16'h1C0B;
    tw_im_rom[55] = 16'h831E;
    tw_re_rom[56] = 16'h18F8;
    tw_im_rom[56] = 16'h8277;
    tw_re_rom[57] = 16'h15E1;
    tw_im_rom[57] = 16'h81E4;
    tw_re_rom[58] = 16'h12C7;
    tw_im_rom[58] = 16'h8164;
    tw_re_rom[59] = 16'h0FAB;
    tw_im_rom[59] = 16'h80F8;
    tw_re_rom[60] = 16'h0C8B;
    tw_im_rom[60] = 16'h809F;
    tw_re_rom[61] = 16'h096A;
    tw_im_rom[61] = 16'h805A;
    tw_re_rom[62] = 16'h0647;
    tw_im_rom[62] = 16'h8029;
    tw_re_rom[63] = 16'h0324;
    tw_im_rom[63] = 16'h800B;
    tw_re_rom[64] = 16'h0000;
    tw_im_rom[64] = 16'h8001;
    tw_re_rom[65] = 16'hFCDC;
    tw_im_rom[65] = 16'h800B;
    tw_re_rom[66] = 16'hF9B9;
    tw_im_rom[66] = 16'h8029;
    tw_re_rom[67] = 16'hF696;
    tw_im_rom[67] = 16'h805A;
    tw_re_rom[68] = 16'hF375;
    tw_im_rom[68] = 16'h809F;
    tw_re_rom[69] = 16'hF055;
    tw_im_rom[69] = 16'h80F8;
    tw_re_rom[70] = 16'hED39;
    tw_im_rom[70] = 16'h8164;
    tw_re_rom[71] = 16'hEA1F;
    tw_im_rom[71] = 16'h81E4;
    tw_re_rom[72] = 16'hE708;
    tw_im_rom[72] = 16'h8277;
    tw_re_rom[73] = 16'hE3F5;
    tw_im_rom[73] = 16'h831E;
    tw_re_rom[74] = 16'hE0E7;
    tw_im_rom[74] = 16'h83D7;
    tw_re_rom[75] = 16'hDDDD;
    tw_im_rom[75] = 16'h84A4;
    tw_re_rom[76] = 16'hDAD9;
    tw_im_rom[76] = 16'h8584;
    tw_re_rom[77] = 16'hD7DA;
    tw_im_rom[77] = 16'h8677;
    tw_re_rom[78] = 16'hD4E2;
    tw_im_rom[78] = 16'h877D;
    tw_re_rom[79] = 16'hD1F0;
    tw_im_rom[79] = 16'h8895;
    tw_re_rom[80] = 16'hCF05;
    tw_im_rom[80] = 16'h89C0;
    tw_re_rom[81] = 16'hCC22;
    tw_im_rom[81] = 16'h8AFD;
    tw_re_rom[82] = 16'hC947;
    tw_im_rom[82] = 16'h8C4B;
    tw_re_rom[83] = 16'hC674;
    tw_im_rom[83] = 16'h8DAC;
    tw_re_rom[84] = 16'hC3AA;
    tw_im_rom[84] = 16'h8F1F;
    tw_re_rom[85] = 16'hC0EA;
    tw_im_rom[85] = 16'h90A2;
    tw_re_rom[86] = 16'hBE33;
    tw_im_rom[86] = 16'h9237;
    tw_re_rom[87] = 16'hBB86;
    tw_im_rom[87] = 16'h93DD;
    tw_re_rom[88] = 16'hB8E4;
    tw_im_rom[88] = 16'h9594;
    tw_re_rom[89] = 16'hB64D;
    tw_im_rom[89] = 16'h975B;
    tw_re_rom[90] = 16'hB3C1;
    tw_im_rom[90] = 16'h9932;
    tw_re_rom[91] = 16'hB141;
    tw_im_rom[91] = 16'h9B19;
    tw_re_rom[92] = 16'hAECD;
    tw_im_rom[92] = 16'h9D0F;
    tw_re_rom[93] = 16'hAC66;
    tw_im_rom[93] = 16'h9F15;
    tw_re_rom[94] = 16'hAA0C;
    tw_im_rom[94] = 16'hA12A;
    tw_re_rom[95] = 16'hA7BE;
    tw_im_rom[95] = 16'hA34D;
    tw_re_rom[96] = 16'hA57F;
    tw_im_rom[96] = 16'hA57F;
    tw_re_rom[97] = 16'hA34D;
    tw_im_rom[97] = 16'hA7BE;
    tw_re_rom[98] = 16'hA12A;
    tw_im_rom[98] = 16'hAA0C;
    tw_re_rom[99] = 16'h9F15;
    tw_im_rom[99] = 16'hAC66;
    tw_re_rom[100] = 16'h9D0F;
    tw_im_rom[100] = 16'hAECD;
    tw_re_rom[101] = 16'h9B19;
    tw_im_rom[101] = 16'hB141;
    tw_re_rom[102] = 16'h9932;
    tw_im_rom[102] = 16'hB3C1;
    tw_re_rom[103] = 16'h975B;
    tw_im_rom[103] = 16'hB64D;
    tw_re_rom[104] = 16'h9594;
    tw_im_rom[104] = 16'hB8E4;
    tw_re_rom[105] = 16'h93DD;
    tw_im_rom[105] = 16'hBB86;
    tw_re_rom[106] = 16'h9237;
    tw_im_rom[106] = 16'hBE33;
    tw_re_rom[107] = 16'h90A2;
    tw_im_rom[107] = 16'hC0EA;
    tw_re_rom[108] = 16'h8F1F;
    tw_im_rom[108] = 16'hC3AA;
    tw_re_rom[109] = 16'h8DAC;
    tw_im_rom[109] = 16'hC674;
    tw_re_rom[110] = 16'h8C4B;
    tw_im_rom[110] = 16'hC947;
    tw_re_rom[111] = 16'h8AFD;
    tw_im_rom[111] = 16'hCC22;
    tw_re_rom[112] = 16'h89C0;
    tw_im_rom[112] = 16'hCF05;
    tw_re_rom[113] = 16'h8895;
    tw_im_rom[113] = 16'hD1F0;
    tw_re_rom[114] = 16'h877D;
    tw_im_rom[114] = 16'hD4E2;
    tw_re_rom[115] = 16'h8677;
    tw_im_rom[115] = 16'hD7DA;
    tw_re_rom[116] = 16'h8584;
    tw_im_rom[116] = 16'hDAD9;
    tw_re_rom[117] = 16'h84A4;
    tw_im_rom[117] = 16'hDDDD;
    tw_re_rom[118] = 16'h83D7;
    tw_im_rom[118] = 16'hE0E7;
    tw_re_rom[119] = 16'h831E;
    tw_im_rom[119] = 16'hE3F5;
    tw_re_rom[120] = 16'h8277;
    tw_im_rom[120] = 16'hE708;
    tw_re_rom[121] = 16'h81E4;
    tw_im_rom[121] = 16'hEA1F;
    tw_re_rom[122] = 16'h8164;
    tw_im_rom[122] = 16'hED39;
    tw_re_rom[123] = 16'h80F8;
    tw_im_rom[123] = 16'hF055;
    tw_re_rom[124] = 16'h809F;
    tw_im_rom[124] = 16'hF375;
    tw_re_rom[125] = 16'h805A;
    tw_im_rom[125] = 16'hF696;
    tw_re_rom[126] = 16'h8029;
    tw_im_rom[126] = 16'hF9B9;
    tw_re_rom[127] = 16'h800B;
    tw_im_rom[127] = 16'hFCDC;
end

localparam ST_IDLE = 2'd0;
localparam ST_LOAD = 2'd1;
localparam ST_COMPUTE = 2'd2;
localparam ST_OUTPUT = 2'd3;

reg [1:0] state;
reg [LOGN-1:0] load_cnt;
reg [LOGN-1:0] stage;
reg [LOGN-1:0] bfly_cnt;
reg [LOGN-1:0] out_cnt;

// Butterfly index decode (identical to fft_r2dit)
reg [LOGN-1:0] idx_a, idx_b, tw_idx;
reg [LOGN-1:0] half_size, group, offset;
always @(*) begin
    half_size = 1 << stage;
    group = bfly_cnt >> stage;
    offset = bfly_cnt & (half_size - 1);
    idx_a = (group << (stage+1)) + offset;
    idx_b = idx_a + half_size;
    tw_idx = offset * ((N/2) >> stage);
end

wire signed [DW-1:0] a_re_w = ram_re[idx_a];
wire signed [DW-1:0] a_im_w = ram_im[idx_a];
wire signed [DW-1:0] b_re_w = ram_re[idx_b];
wire signed [DW-1:0] b_im_w = ram_im[idx_b];
wire signed [DW-1:0] w_re_w = tw_re_rom[tw_idx];
wire signed [DW-1:0] w_im_w = tw_im_rom[tw_idx];

wire signed [2*DW-1:0] wb_re_full = (w_re_w * b_re_w) - (w_im_w * b_im_w);
wire signed [2*DW-1:0] wb_im_full = (w_re_w * b_im_w) + (w_im_w * b_re_w);
wire signed [DW-1:0] wb_re = $signed(wb_re_full) >>> 15;
wire signed [DW-1:0] wb_im = $signed(wb_im_full) >>> 15;

wire signed [DW-1:0] p_re = (a_re_w + wb_re) >>> 1;
wire signed [DW-1:0] p_im = (a_im_w + wb_im) >>> 1;
wire signed [DW-1:0] q_re = (a_re_w - wb_re) >>> 1;
wire signed [DW-1:0] q_im = (a_im_w - wb_im) >>> 1;

integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= ST_IDLE;
        load_cnt <= 0; stage <= 0; bfly_cnt <= 0; out_cnt <= 0;
        y_valid <= 0; y_last <= 0; y_re <= 0; y_im <= 0;
        for (i = 0; i < N; i = i+1) begin
            ram_re[i] <= 0; ram_im[i] <= 0;
        end
    end else begin
        y_valid <= 0;
        y_last <= 0;

        case (state)

        ST_IDLE: begin
            if (x_valid) begin
                // Step 1: load conj(X) in bit-reversed order
                // conj means: keep real, negate imaginary
                ram_re[bit_rev[0]] <= x_re;
                ram_im[bit_rev[0]] <= -x_im;   // conjugate
                load_cnt <= 1;
                state <= ST_LOAD;
            end
        end

        ST_LOAD: begin
            if (x_valid) begin
                ram_re[bit_rev[load_cnt]] <= x_re;
                ram_im[bit_rev[load_cnt]] <= -x_im;  // conjugate
                if (load_cnt == N-1) begin
                    stage <= 0; bfly_cnt <= 0;
                    state <= ST_COMPUTE;
                end else
                    load_cnt <= load_cnt + 1;
            end
        end

        // Step 2: run identical FFT butterfly
        ST_COMPUTE: begin
            ram_re[idx_a] <= p_re; ram_im[idx_a] <= p_im;
            ram_re[idx_b] <= q_re; ram_im[idx_b] <= q_im;
            if (bfly_cnt == N/2-1) begin
                bfly_cnt <= 0;
                if (stage == LOGN-1) begin
                    out_cnt <= 0; state <= ST_OUTPUT;
                end else
                    stage <= stage + 1;
            end else
                bfly_cnt <= bfly_cnt + 1;
        end

        // Step 3: output conj(result) -- negate imaginary part
        ST_OUTPUT: begin
            y_re <= ram_re[out_cnt];
            y_im <= -ram_im[out_cnt];   // conjugate output
            y_valid <= 1;
            y_last <= (out_cnt == N-1);
            if (out_cnt == N-1) begin
                load_cnt <= 0; state <= ST_IDLE;
            end else
                out_cnt <= out_cnt + 1;
        end

        endcase
    end
end

endmodule