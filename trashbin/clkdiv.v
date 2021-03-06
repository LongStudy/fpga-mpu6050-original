module clkdiv(clk50,rst_n,clkout);
input clk50;  //系统时钟
input rst_n;
output clkout;

reg clkout;
reg [15:0] cnt;
/////分频进程, 50Mhz 的时钟 27 分频/////////
/*计算过程
波特率115200bps
每个bit接收的数据有16个时钟采样
则分频数为：50_000_000/115200/16=27.13
约为27分频
*/
always @(posedge clk50 or negedge rst_n)
begin
    if (!rst_n) 
    begin
        clkout <=1'b0;
        cnt<=0;
    end
    else if(cnt == 16'd65) 
    begin
        clkout <= 1'b1;
        cnt <= cnt + 16'd1;
    end
    else if(cnt == 16'd130) 
    begin
        clkout <= 1'b0;
        cnt <= 16'd0;
    end
    else 
    begin
        cnt <= cnt + 16'd1;
    end
end
endmodule
