// ============================================================================
// twiddle_rom.v  —  Twiddle Factor ROM for 256-point FFT
// 
// Stores W_N^k = e^(-j*2*pi*k/N) for k = 0..N/2-1 (128 entries)
//
// FORMAT: Q1.15 fixed point
//   wr[k] = round(cos(2*pi*k/256) * 32767)
//   wi[k] = round(-sin(2*pi*k/256) * 32767)
//
// In synthesis: This becomes a Block RAM or distributed ROM.
// In simulation: Initialized via $cos/$sin in initial block.
//
// USAGE:
//   The FFT stage s uses twiddle W_N^(k * 2^(S-s-1))
//   where S = log2(N) = 8 for N=256
//   Address = (butterfly_index * stride) mod 128
// ============================================================================

module twiddle_rom #(
    parameter N = 256,   // FFT size
    parameter DW = 16     // Data width
)(
    input wire clk,
    input wire [$clog2(N/2)-1:0] addr,   // 0..127
    output reg signed [DW-1:0] wr,     // cos term
    output reg signed [DW-1:0] wi      // -sin term
);

localparam HALF_N = N/2;  // 128 entries

reg signed [DW-1:0] rom_r [0:HALF_N-1];
reg signed [DW-1:0] rom_i [0:HALF_N-1];

// Initialize ROM with twiddle factors
initial begin
    rom_r[0] = 16'h7FFF;
    rom_i[0] = 16'h0000;
    rom_r[1] = 16'h7FF5;
    rom_i[1] = 16'hFCDC;
    rom_r[2] = 16'h7FD7;
    rom_i[2] = 16'hF9B9;
    rom_r[3] = 16'h7FA6;
    rom_i[3] = 16'hF696;
    rom_r[4] = 16'h7F61;
    rom_i[4] = 16'hF375;
    rom_r[5] = 16'h7F08;
    rom_i[5] = 16'hF055;
    rom_r[6] = 16'h7E9C;
    rom_i[6] = 16'hED39;
    rom_r[7] = 16'h7E1C;
    rom_i[7] = 16'hEA1F;
    rom_r[8] = 16'h7D89;
    rom_i[8] = 16'hE708;
    rom_r[9] = 16'h7CE2;
    rom_i[9] = 16'hE3F5;
    rom_r[10] = 16'h7C29;
    rom_i[10] = 16'hE0E7;
    rom_r[11] = 16'h7B5C;
    rom_i[11] = 16'hDDDD;
    rom_r[12] = 16'h7A7C;
    rom_i[12] = 16'hDAD9;
    rom_r[13] = 16'h7989;
    rom_i[13] = 16'hD7DA;
    rom_r[14] = 16'h7883;
    rom_i[14] = 16'hD4E2;
    rom_r[15] = 16'h776B;
    rom_i[15] = 16'hD1F0;
    rom_r[16] = 16'h7640;
    rom_i[16] = 16'hCF05;
    rom_r[17] = 16'h7503;
    rom_i[17] = 16'hCC22;
    rom_r[18] = 16'h73B5;
    rom_i[18] = 16'hC947;
    rom_r[19] = 16'h7254;
    rom_i[19] = 16'hC674;
    rom_r[20] = 16'h70E1;
    rom_i[20] = 16'hC3AA;
    rom_r[21] = 16'h6F5E;
    rom_i[21] = 16'hC0EA;
    rom_r[22] = 16'h6DC9;
    rom_i[22] = 16'hBE33;
    rom_r[23] = 16'h6C23;
    rom_i[23] = 16'hBB86;
    rom_r[24] = 16'h6A6C;
    rom_i[24] = 16'hB8E4;
    rom_r[25] = 16'h68A5;
    rom_i[25] = 16'hB64D;
    rom_r[26] = 16'h66CE;
    rom_i[26] = 16'hB3C1;
    rom_r[27] = 16'h64E7;
    rom_i[27] = 16'hB141;
    rom_r[28] = 16'h62F1;
    rom_i[28] = 16'hAECD;
    rom_r[29] = 16'h60EB;
    rom_i[29] = 16'hAC66;
    rom_r[30] = 16'h5ED6;
    rom_i[30] = 16'hAA0C;
    rom_r[31] = 16'h5CB3;
    rom_i[31] = 16'hA7BE;
    rom_r[32] = 16'h5A81;
    rom_i[32] = 16'hA57F;
    rom_r[33] = 16'h5842;
    rom_i[33] = 16'hA34D;
    rom_r[34] = 16'h55F4;
    rom_i[34] = 16'hA12A;
    rom_r[35] = 16'h539A;
    rom_i[35] = 16'h9F15;
    rom_r[36] = 16'h5133;
    rom_i[36] = 16'h9D0F;
    rom_r[37] = 16'h4EBF;
    rom_i[37] = 16'h9B19;
    rom_r[38] = 16'h4C3F;
    rom_i[38] = 16'h9932;
    rom_r[39] = 16'h49B3;
    rom_i[39] = 16'h975B;
    rom_r[40] = 16'h471C;
    rom_i[40] = 16'h9594;
    rom_r[41] = 16'h447A;
    rom_i[41] = 16'h93DD;
    rom_r[42] = 16'h41CD;
    rom_i[42] = 16'h9237;
    rom_r[43] = 16'h3F16;
    rom_i[43] = 16'h90A2;
    rom_r[44] = 16'h3C56;
    rom_i[44] = 16'h8F1F;
    rom_r[45] = 16'h398C;
    rom_i[45] = 16'h8DAC;
    rom_r[46] = 16'h36B9;
    rom_i[46] = 16'h8C4B;
    rom_r[47] = 16'h33DE;
    rom_i[47] = 16'h8AFD;
    rom_r[48] = 16'h30FB;
    rom_i[48] = 16'h89C0;
    rom_r[49] = 16'h2E10;
    rom_i[49] = 16'h8895;
    rom_r[50] = 16'h2B1E;
    rom_i[50] = 16'h877D;
    rom_r[51] = 16'h2826;
    rom_i[51] = 16'h8677;
    rom_r[52] = 16'h2527;
    rom_i[52] = 16'h8584;
    rom_r[53] = 16'h2223;
    rom_i[53] = 16'h84A4;
    rom_r[54] = 16'h1F19;
    rom_i[54] = 16'h83D7;
    rom_r[55] = 16'h1C0B;
    rom_i[55] = 16'h831E;
    rom_r[56] = 16'h18F8;
    rom_i[56] = 16'h8277;
    rom_r[57] = 16'h15E1;
    rom_i[57] = 16'h81E4;
    rom_r[58] = 16'h12C7;
    rom_i[58] = 16'h8164;
    rom_r[59] = 16'h0FAB;
    rom_i[59] = 16'h80F8;
    rom_r[60] = 16'h0C8B;
    rom_i[60] = 16'h809F;
    rom_r[61] = 16'h096A;
    rom_i[61] = 16'h805A;
    rom_r[62] = 16'h0647;
    rom_i[62] = 16'h8029;
    rom_r[63] = 16'h0324;
    rom_i[63] = 16'h800B;
    rom_r[64] = 16'h0000;
    rom_i[64] = 16'h8001;
    rom_r[65] = 16'hFCDC;
    rom_i[65] = 16'h800B;
    rom_r[66] = 16'hF9B9;
    rom_i[66] = 16'h8029;
    rom_r[67] = 16'hF696;
    rom_i[67] = 16'h805A;
    rom_r[68] = 16'hF375;
    rom_i[68] = 16'h809F;
    rom_r[69] = 16'hF055;
    rom_i[69] = 16'h80F8;
    rom_r[70] = 16'hED39;
    rom_i[70] = 16'h8164;
    rom_r[71] = 16'hEA1F;
    rom_i[71] = 16'h81E4;
    rom_r[72] = 16'hE708;
    rom_i[72] = 16'h8277;
    rom_r[73] = 16'hE3F5;
    rom_i[73] = 16'h831E;
    rom_r[74] = 16'hE0E7;
    rom_i[74] = 16'h83D7;
    rom_r[75] = 16'hDDDD;
    rom_i[75] = 16'h84A4;
    rom_r[76] = 16'hDAD9;
    rom_i[76] = 16'h8584;
    rom_r[77] = 16'hD7DA;
    rom_i[77] = 16'h8677;
    rom_r[78] = 16'hD4E2;
    rom_i[78] = 16'h877D;
    rom_r[79] = 16'hD1F0;
    rom_i[79] = 16'h8895;
    rom_r[80] = 16'hCF05;
    rom_i[80] = 16'h89C0;
    rom_r[81] = 16'hCC22;
    rom_i[81] = 16'h8AFD;
    rom_r[82] = 16'hC947;
    rom_i[82] = 16'h8C4B;
    rom_r[83] = 16'hC674;
    rom_i[83] = 16'h8DAC;
    rom_r[84] = 16'hC3AA;
    rom_i[84] = 16'h8F1F;
    rom_r[85] = 16'hC0EA;
    rom_i[85] = 16'h90A2;
    rom_r[86] = 16'hBE33;
    rom_i[86] = 16'h9237;
    rom_r[87] = 16'hBB86;
    rom_i[87] = 16'h93DD;
    rom_r[88] = 16'hB8E4;
    rom_i[88] = 16'h9594;
    rom_r[89] = 16'hB64D;
    rom_i[89] = 16'h975B;
    rom_r[90] = 16'hB3C1;
    rom_i[90] = 16'h9932;
    rom_r[91] = 16'hB141;
    rom_i[91] = 16'h9B19;
    rom_r[92] = 16'hAECD;
    rom_i[92] = 16'h9D0F;
    rom_r[93] = 16'hAC66;
    rom_i[93] = 16'h9F15;
    rom_r[94] = 16'hAA0C;
    rom_i[94] = 16'hA12A;
    rom_r[95] = 16'hA7BE;
    rom_i[95] = 16'hA34D;
    rom_r[96] = 16'hA57F;
    rom_i[96] = 16'hA57F;
    rom_r[97] = 16'hA34D;
    rom_i[97] = 16'hA7BE;
    rom_r[98] = 16'hA12A;
    rom_i[98] = 16'hAA0C;
    rom_r[99] = 16'h9F15;
    rom_i[99] = 16'hAC66;
    rom_r[100] = 16'h9D0F;
    rom_i[100] = 16'hAECD;
    rom_r[101] = 16'h9B19;
    rom_i[101] = 16'hB141;
    rom_r[102] = 16'h9932;
    rom_i[102] = 16'hB3C1;
    rom_r[103] = 16'h975B;
    rom_i[103] = 16'hB64D;
    rom_r[104] = 16'h9594;
    rom_i[104] = 16'hB8E4;
    rom_r[105] = 16'h93DD;
    rom_i[105] = 16'hBB86;
    rom_r[106] = 16'h9237;
    rom_i[106] = 16'hBE33;
    rom_r[107] = 16'h90A2;
    rom_i[107] = 16'hC0EA;
    rom_r[108] = 16'h8F1F;
    rom_i[108] = 16'hC3AA;
    rom_r[109] = 16'h8DAC;
    rom_i[109] = 16'hC674;
    rom_r[110] = 16'h8C4B;
    rom_i[110] = 16'hC947;
    rom_r[111] = 16'h8AFD;
    rom_i[111] = 16'hCC22;
    rom_r[112] = 16'h89C0;
    rom_i[112] = 16'hCF05;
    rom_r[113] = 16'h8895;
    rom_i[113] = 16'hD1F0;
    rom_r[114] = 16'h877D;
    rom_i[114] = 16'hD4E2;
    rom_r[115] = 16'h8677;
    rom_i[115] = 16'hD7DA;
    rom_r[116] = 16'h8584;
    rom_i[116] = 16'hDAD9;
    rom_r[117] = 16'h84A4;
    rom_i[117] = 16'hDDDD;
    rom_r[118] = 16'h83D7;
    rom_i[118] = 16'hE0E7;
    rom_r[119] = 16'h831E;
    rom_i[119] = 16'hE3F5;
    rom_r[120] = 16'h8277;
    rom_i[120] = 16'hE708;
    rom_r[121] = 16'h81E4;
    rom_i[121] = 16'hEA1F;
    rom_r[122] = 16'h8164;
    rom_i[122] = 16'hED39;
    rom_r[123] = 16'h80F8;
    rom_i[123] = 16'hF055;
    rom_r[124] = 16'h809F;
    rom_i[124] = 16'hF375;
    rom_r[125] = 16'h805A;
    rom_i[125] = 16'hF696;
    rom_r[126] = 16'h8029;
    rom_i[126] = 16'hF9B9;
    rom_r[127] = 16'h800B;
    rom_i[127] = 16'hFCDC;
end

// Registered read (1-cycle latency — matches butterfly pipeline)
always @(posedge clk) begin
    wr <= rom_r[addr];
    wi <= rom_i[addr];
end

endmodule