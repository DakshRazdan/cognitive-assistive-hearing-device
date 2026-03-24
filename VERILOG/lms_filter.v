// lms_filter.v — 32-tap LMS Adaptive Post-Filter
`timescale 1ns/1ps

module lms_filter #(
    parameter DW = 16,
    parameter M  = 32,
    parameter MU = 16'd32    // 0.001 in Q1.15
)(
    input wire clk,
    input wire rst_n,
    input wire signed [DW-1:0] pcm_in,
    input wire pcm_valid,
    input wire speech,
    output reg signed [DW-1:0] pcm_out,
    output reg pcm_out_valid
);

// Tap delay line
reg signed [DW-1:0] delay_line [0:M-1];
// Filter weights Q1.15
reg signed [DW-1:0] weights [0:M-1];

integer i;
initial begin
    for (i = 0; i < M; i = i + 1) begin
        delay_line[i] = 0;
        weights[i] = 0;
    end
end

// Pipeline registers
reg signed [DW-1:0] s1_in;
reg s1_valid, s1_speech;

// Stage 1: shift delay line, register input
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s1_valid <= 0; s1_speech <= 0; s1_in <= 0;
    end else begin
        s1_valid <= pcm_valid;
        s1_speech <= speech;
        s1_in <= pcm_in;
        if (pcm_valid) begin : shift_delay
            integer j;
            for (j = M-1; j > 0; j = j - 1)
                delay_line[j] <= delay_line[j-1];
            delay_line[0] <= pcm_in;
        end
    end
end

// Stage 2: compute filter output y = w^T * x
reg signed [31:0] y_acc;
reg signed [DW-1:0] s2_in;
reg s2_valid, s2_speech;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_acc <= 0; s2_valid <= 0; s2_speech <= 0; s2_in <= 0;
    end else begin
        s2_valid <= s1_valid;
        s2_speech <= s1_speech;
        s2_in <= s1_in;
        if (s1_valid) begin : dot_product
            integer k;
            reg signed [31:0] acc;
            acc = 0;
            for (k = 0; k < M; k = k + 1)
                acc = acc + (($signed(weights[k]) * $signed(delay_line[k])) >>> 15);
            y_acc <= acc;
        end
    end
end

// Stage 3: error = input - y, update weights if speech=0
wire signed [DW-1:0] y_out = (y_acc > 32767) ? 16'sd32767 :
                                (y_acc < -32768) ? -16'sd32768 : y_acc[15:0];
wire signed [DW-1:0] err_out = s2_in - y_out;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pcm_out <= 0; pcm_out_valid <= 0;
        for (i = 0; i < M; i = i + 1) weights[i] <= 0;
    end else begin
        pcm_out_valid <= s2_valid;
        if (s2_valid) begin
            pcm_out <= err_out;
            // Update weights only during noise frames (speech=0)
            if (!s2_speech) begin : weight_update
                integer m;
                for (m = 0; m < M; m = m + 1)
                    weights[m] <= weights[m] +
                        (($signed(MU) * $signed(delay_line[m]) * $signed(err_out)) >>> 30);
            end
        end
    end
end
endmodule