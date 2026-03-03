`timescale 1ns/1ps
module ifft_r2dit_tb;
localparam N=256, DW=16, CLK_P=10;
reg clk,rst_n;
reg signed [DW-1:0] x_re,x_im; reg x_valid;
wire signed [DW-1:0] y_re,y_im; wire y_valid,y_last;
ifft_r2dit dut(.clk(clk),.rst_n(rst_n),.x_re(x_re),.x_im(x_im),.x_valid(x_valid),.y_re(y_re),.y_im(y_im),.y_valid(y_valid),.y_last(y_last));
initial clk=0; always #(CLK_P/2) clk=~clk;
integer pass_count,fail_count,out_idx,last_fired,n,k,ok;
reg signed [DW-1:0] out_buf[0:N-1],in_re[0:N-1],in_im[0:N-1];
always @(posedge clk) begin
    if(y_valid) begin out_buf[out_idx]<=y_re; out_idx<=out_idx+1; if(y_last) last_fired<=last_fired+1; end
end
task feed_bins; integer s; begin
    out_idx=0; last_fired=0;
    for(s=0;s<N;s=s+1) out_buf[s]=0;
    for(s=0;s<N;s=s+1) begin @(negedge clk); x_re=in_re[s]; x_im=in_im[s]; x_valid=1; end
    @(negedge clk); x_valid=0;
end endtask
initial begin
    $dumpfile("ifft_r2dit.vcd"); $dumpvars(0,ifft_r2dit_tb);
    pass_count=0; fail_count=0; rst_n=0; x_valid=0; x_re=0; x_im=0;
    repeat(5) @(posedge clk); rst_n=1; repeat(3) @(posedge clk);
    $display("=== IFFT 256-point Testbench ===");

    $display("\nTest 1: DC X[0]=32767 -> flat ~127");
    for(k=0;k<N;k=k+1) begin in_re[k]=0; in_im[k]=0; end
    in_re[0]=16'sd32767;
    feed_bins; @(posedge y_last); repeat(5) @(posedge clk);
    ok=1;
    for(n=0;n<N;n=n+1) if($signed(out_buf[n])<110||$signed(out_buf[n])>140) ok=0;
    if(ok) begin $display("  PASS all samples in [110,140]"); pass_count=pass_count+1; end
    else begin $display("  FAIL s[0]=%0d s[128]=%0d",$signed(out_buf[0]),$signed(out_buf[128])); fail_count=fail_count+1; end

    $display("\nTest 2: 256 outputs, y_last once");
    for(k=0;k<N;k=k+1) begin in_re[k]=0; in_im[k]=0; end
    in_re[0]=16'sd32767;
    feed_bins; @(posedge y_last); repeat(5) @(posedge clk);
    if(out_idx==N) begin $display("  PASS out_idx=%0d",out_idx); pass_count=pass_count+1; end
    else begin $display("  FAIL out_idx=%0d",out_idx); fail_count=fail_count+1; end
    if(last_fired==1) begin $display("  PASS y_last once"); pass_count=pass_count+1; end
    else begin $display("  FAIL y_last=%0d",last_fired); fail_count=fail_count+1; end

    $display("\nTest 3: Tone X[4]=32767 -> cosine (natural order input)");
    for(k=0;k<N;k=k+1) begin in_re[k]=0; in_im[k]=0; end
    in_re[4]=16'sd32767;
    feed_bins; @(posedge y_last); repeat(5) @(posedge clk);
    if($signed(out_buf[0])>50&&$signed(out_buf[0])<140&&
       $signed(out_buf[16])>-30&&$signed(out_buf[16])<30&&
       $signed(out_buf[32])<-50) begin
        $display("  PASS y[0]=%0d y[16]=%0d y[32]=%0d",$signed(out_buf[0]),$signed(out_buf[16]),$signed(out_buf[32]));
        pass_count=pass_count+1;
    end else begin
        $display("  FAIL y[0]=%0d y[16]=%0d y[32]=%0d (exp ~127,~0,~-127)",$signed(out_buf[0]),$signed(out_buf[16]),$signed(out_buf[32]));
        fail_count=fail_count+1;
    end

    $display("\n=== RESULT: %0d PASS, %0d FAIL ===",pass_count,fail_count);
    #1000; $finish;
end
initial begin #5000000; $display("TIMEOUT"); $finish; end
endmodule