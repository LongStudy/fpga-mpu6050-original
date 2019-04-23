module fenpin(clkin,clkout);
input clkin;
output clkout;
reg clkout=0;
reg [24:0]cnt=0;
always@(posedge clkin)
begin 
if (cnt==500000) 
    clkout=~clkout;
if (cnt==1000000)
  begin
    clkout=~clkout;
	 cnt=0;
	 end 
 cnt=cnt+1;
 end 
 endmodule 

