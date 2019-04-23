module mpu_6050init(read,iic_en,done,address,read_data,clk20m,sda,scl,t);

IIC ICC(
	.clk50M(clk50M),
	.reset(reset),
	.iic_en(iic_en),
	.cs_bit(3'b000),
	.address(address),
	.write(write),
	.write_data(write_data),
	.read(read),
	.read_data(read_data),
	.scl(scl),
	.sda(sda),
	.done(done)
);

    //reg cs_bit[2:0];
    reg reset,t=0;
    reg iic_en;
    reg [7:0]address;
    reg write;
    reg [7:0]write_data;
    reg read;
	 input clk20m,read,iic_en;
	 inout sda;
	 output scl,t,done;
	 output reg [7:0]read_data;
    assign clk50M=clk20m;
	 initial
    begin
		  reset=1'b0;
        iic_en=1'b0;
        address=8'h0;
        write=1'b0;
        write_data=8'b0;
        read=1'b0;
  
  reset=1;
  //cs_bit=3'b000;//A0悬空，地址后三位000
  
  //复位mpu6050
  write=1;
  address=2'h6b;
  write_data=2'h80;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  write=0;
  end
  /*//检查
  always@(!i)
  read=1;
  iic_en=1;
  @(posedge done)
  iic_en=0;
  address=2'h6b;
  if (read_data[7]==0)//复位完成
  begin
  read=0;
  i=1;
  end
  else 
  i=0;*/
  //唤醒mpu6050
  
  write=1;
  address=2'h6b;
  write_data=2'h00;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  
  //设置陀螺仪分辨率±2000dps
  //write=1;
  address=2'h1b;
  write_data=2'h18;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  
  //设置加速度分辨率±2g
  //write=1;
  address=2'h1c;
  write_data=2'h00;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  
  //设置低通滤波器
  //write=1;
  address=2'h1a;
  write_data=4;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  
  //传感器不进入待机
  //write=1;
  address=2'h6c;
  write_data=0;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  
  //关闭中断，
  //write=1;
  address=2'h38;
  write_data=0;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  //write=1;
  address=2'h6a;
  write_data=0;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  //write=1;
  address=2'h23;
  write_data=0;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  
  //int低有效
  //write=1;
  address=2'h37;
  write_data=2'h80;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  write=0;
  end
  
  read=1;
  iic_en=1;
  @(posedge done)
  iic_en=0;
  
  address=2'h75;
  if (read_data==2'h68)//器件名正确
  begin
  address=2'h6B;//X轴为参考
  write_data=2'h01;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  address=2'h6C;//加速度和陀螺仪都工作
  write_data=0;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  //write=0;
  end
  
  //设置采样率50Hz
  //write=1;
  address=2'h19;
  write_data=19;
  iic_en=1;
  @(posedge done)
  begin
  iic_en=0;
  write=0;
  end
  t=1;
  end 
  else t=0;
  end
  
 endmodule