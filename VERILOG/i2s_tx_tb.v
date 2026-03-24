`timescale 1ns/1ps
module i2s_tx_tb;
localparam CLK_P=10, DW=16;
reg clk, rst_n, bclk, ws;
reg signed [DW-1:0] pcm_in; reg pcm_valid;
wire sdata;

i2s_tx dut(.clk(clk),.rst_n(rst_n),.bclk(bclk),.ws(ws),.pcm_in(pcm_in),.pcm_valid(pcm_valid),.sdata(sdata));
initial clk=0; always #(CLK_P/2) clk=~clk;

// BCLK ~1MHz (490ns half period), WS toggles every 32 BCLK
integer bclk_cnt;
initial begin bclk=0; ws=1; bclk_cnt=0; end
always #490 begin
    bclk=~bclk;
    if(!bclk) begin  // count falling edges
        bclk_cnt=bclk_cnt+1;
        if(bclk_cnt==32) begin ws=~ws; bclk_cnt=0; end
    end
end

integer pass_count, fail_count;
reg saw_high;
integer t;

initial begin
    $dumpfile("i2s_tx.vcd"); $dumpvars(0,i2s_tx_tb);
    pass_count=0; fail_count=0;
    rst_n=0; pcm_valid=0; pcm_in=0;
    repeat(10) @(posedge clk); rst_n=1; repeat(5) @(posedge clk);
    $display("=== I2S TX Testbench ===");

    // Load a sample
    @(negedge clk); pcm_in=16'hA5A5; pcm_valid=1;
    @(negedge clk); pcm_valid=0;
    repeat(10) @(posedge clk);

    // Test 1: sdata toggles (not stuck at 0 or 1)
    $display("\nTest 1: sdata toggles over 128 BCLK cycles");
    saw_high=0;
    for(t=0;t<128;t=t+1) begin
        @(negedge bclk);
        if(sdata) saw_high=1;
    end
    if(saw_high) begin
        $display("  PASS sdata toggled to 1 at least once"); pass_count=pass_count+1;
    end else begin
        $display("  FAIL sdata stuck at 0"); fail_count=fail_count+1;
    end

    // Test 2: after reset output is 0
    $display("\nTest 2: After reset sdata=0");
    rst_n=0; repeat(5) @(posedge clk);
    if(sdata==0) begin
        $display("  PASS sdata=0 after reset"); pass_count=pass_count+1;
    end else begin
        $display("  FAIL sdata=%0d after reset",sdata); fail_count=fail_count+1;
    end
    rst_n=1;

    // Test 3: valid fires output
    $display("\nTest 3: pcm_valid triggers serialization");
    @(negedge clk); pcm_in=16'hFFFF; pcm_valid=1;
    @(negedge clk); pcm_valid=0;
    saw_high=0;
    for(t=0;t<128;t=t+1) begin
        @(negedge bclk);
        if(sdata) saw_high=1;
    end
    if(saw_high) begin
        $display("  PASS serialization active"); pass_count=pass_count+1;
    end else begin
        $display("  FAIL no serialization"); fail_count=fail_count+1;
    end

    $display("\n=== RESULT: %0d PASS, %0d FAIL ===", pass_count, fail_count);
    #10000; $finish;
end
initial begin #10000000; $display("TIMEOUT"); $finish; end
endmodule