module cal_gy(
	   clk,
		rst,
		GY,
		is_read,
		gy_speed,
		data
		);
    input clk,rst,is_read;
	 input [15:0]GY;
	 output [31:0] gy_speed;
	 output [31:0] data;
		
    reg [31:0] gy_speed1;
	 reg [15:0] gy;
	 		
	  always @ ( posedge clk or negedge rst )
		 if(!rst)
	       gy<=16'd0;
		 else if(is_read)
	       gy<=GY;	 
	
 /* --------开始计算 陀螺仪得到的角度----------*/
    reg [3:0]i; 
	 reg [7:0]clk_100;
	 always @ ( posedge clk or negedge rst )
		 if(!rst)
		       begin 
				 i<=4'd0;
				 dataU1<=16'h0;
				 dataa<=32'h0;
				 datab<=32'h0;
				 gy_speed1<=32'h0;
				 clk_100<=1'b0;
				 end
		 else
		    case (i)	 
			 0:                  // 等待一次is_read,读GY到gy
			 if(is_read) begin i<=i+1'b1;end    
			 else  i<=1'b0;
		    
			 1:                  //gy-漂移量 gy_offset 10  换成浮点数
			 if(clk_100==8'd0)     begin dataU1<=gy;clk_100<=1'b1;end
			 else if(clk_100==8'd100)   begin gy_speed1<=gyf;clk_100<=8'd0;i<=i+1'b1;end
			 else 
          clk_100<=clk_100+1'b1;
		    
			 2:                  // 除以16.384 得到角速度 w°/s  32'h41831268
			 if(clk_100==8'd0)     begin dataa<=gy_speed1;datab<=32'h41831268;clk_100<=1'b1;end
			 else if(clk_100==8'd100)   begin gy_speed1<=gy_speedf;clk_100<=8'd0;i<=i+1'b1;end
			 else 
          clk_100<=clk_100+1'b1;
			 
			 3:
			 i<=1'b0;
			 
			 endcase 
	 
	 reg[15:0] dataU1;
	 reg[31:0] dataa,datab;
	 wire [31:0]gyf,gy_speedf;
	 

	i16to32f U1(
	   .clock(clk),
	   .dataa(dataU1),
	   .result(gyf)
		);
	/*
	  DIV U2(
	    .clock(clk),
	    .dataa(dataa),//        
	    .datab(datab),
	    .result(gy_speedf)
		 );
		*/
		
	 DIV1 U3(
	   .clock(clk),
	   .dataa(dataa),
	   .datab(datab),
    	.division_by_zero(),
	   .nan(),
	   .overflow(),
	   .result(gy_speedf),
	   .underflow(),
	   .zero()
	   );

	 
	 
	 assign gy_speed=gy_speed1;
	 assign data=gy_speed1;
	 
endmodule 