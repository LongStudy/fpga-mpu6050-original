module choose(ch,a,b,out);
input ch;
input [7:0]a,b;
output reg [7:0]out;
always@(a,b)
if(ch)
out<=a;
else
out<=b;
endmodule
