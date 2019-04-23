module fiter(
	   clk,
		rst,
		cal_done,
		angle,
		AZangle,
		gy_speed,
		dir,
		data
		);
   input clk,rst,cal_done;
	input [31:0]  AZangle,gy_speed,angle;
	output [1:0]  dir;
	output [31:0] data;
	
   reg[4:0]j;	
	reg [7:0]clk_100;
	reg [31:0]az,gy,al;
	reg aldone;
//	得到cal_done 为高才开始计算

	always @ ( posedge clk or negedge rst )
		 if(!rst)
		 begin clk_100<=8'd0;aldone<=1'b0;j<=5'd0;end
		 else
		    case (j)
		       
				 0:
				 if(cal_done)  begin az<=AZangle;gy<=gy_speed;j<=j+1'b1;end
				 else          j<=1'b0;
				 
				 1:
				 if(aldone==1'b1)  j<=j+1'b1; 
				 else begin al<=angle;aldone<=1'b1;j<=2'd2;end
				 
				 2:  // az*0.1+(gy*dt+angle)*0.9
				 if(clk_100==8'd0)  begin dataa<=az;datab<=32'h3DCCC800;clk_100<=1'b1;end //az*0.1
			    else if(clk_100==8'd100)   begin az<=result_MULT;clk_100<=8'd0;j<=j+1'b1;end
			    else 
             clk_100<=clk_100+1'b1;
				 
				 3:
				 if(clk_100==8'd0)  begin dataa<=gy;datab<=32'h3D385000;clk_100<=1'b1;end //gy*dt*0.9 0.045S
			    else if(clk_100==8'd100)   begin gy<=result_MULT;clk_100<=8'd0;j<=j+1'b1;end
			    else 
             clk_100<=clk_100+1'b1;
				 
				 4:
				 if(clk_100==8'd0)  begin dataa<=al;datab<=32'h3F666600;clk_100<=1'b1;end //angle*0.9
			    else if(clk_100==8'd100)   begin al<=result_MULT;clk_100<=8'd0;j<=j+1'b1;end
			    else 
             clk_100<=clk_100+1'b1;
				 
				 5: //三个相加
				 if(clk_100==8'd0)  begin dataa2<=al;datab2<=gy;clk_100<=1'b1;end 
			    else if(clk_100==8'd100)   begin al<=result_ADD;clk_100<=8'd0;j<=j+1'b1;end
			    else 
             clk_100<=clk_100+1'b1;
				 
				 6: //三个相加
				 if(clk_100==8'd0)  begin dataa2<=al;datab2<=az;clk_100<=1'b1;end 
			    else if(clk_100==8'd100)   begin al<=result_ADD;clk_100<=8'd0;j<=j+1'b1;end
			    else 
             clk_100<=clk_100+1'b1;
				 
				 7:
				 j<=1'b0;
				 
		   endcase
		
		reg [1:0] rdir;
	 /*--//--------与预先存的值比较----dir 1 正转 0 反转 2停止--------- //rdir<=2'd1; rdir<=2'd0;   rdir<=2'd2; */   
     	always @ ( posedge clk or negedge rst )
	    if(!rst )
		     begin  rdir<= 2'd2;end
	    else if(al[31])
		     if({1'b1,al[22:0]}>>(8'd23-(al[30:23]-8'd127)-8'd16)>32'd327680) //5
			       rdir<=2'd1;
			  else
			       rdir<=2'd2;
	   else if({1'b1,al[22:0]}>>(8'd23-(al[30:23]-8'd127)-8'd16)>32'd327680) //5
		     rdir<=2'd0; 
		 else
		     rdir<=2'd2; 
	  
	   /*---------------------------------------------------*/
			
	
	 reg[31:0] dataa,datab,dataa2,datab2;
	 wire [31:0] result_MULT,result_ADD;	
			
    MULT U1(
	   .clock(clk),
	   .dataa(dataa),
	   .datab(datab),
	   .result(result_MULT)
	);		 
	 ADD U2(
	   .clock(clk),
	   .dataa(dataa2),
	   .datab(datab2),
	   .result(result_ADD)
		);		      
				 
	assign 	data=al;
   assign   dir=rdir;
	
endmodule 