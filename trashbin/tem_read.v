module IIC(
    clk50M,
    reset,
    iic_en,
    address,
    write,
    write_data,
    read,
    read_data,
    scl,
    sda,
    done
);

    input clk50M;              //系统时钟50MHz
    input reset;               //异步复位信号
    input iic_en;              //使能信号
    //input [2:0]cs_bit;         //器件选择地址
    input [7:0]address;       //13位数据读写地址，24LC64有13位数据存储地址
    input write;               //写数据信号
    input [7:0]write_data;     //写数据
    input read;                //读数据信号
    output reg[7:0]read_data;  //读数据
    
    output reg scl;            //IIC时钟信号
    inout sda;                 //IIC数据总线
    
    output reg done;           //一次IIC读写完成
    
    parameter SYS_CLOCK = 20_000_000;  //系统时钟采用50MHz
    parameter SCL_CLOCK = 400_000;     //scl总线时钟采用200kHz
    
    //状态
    parameter 
        Idle      = 16'b0000_0000_0000_0001,
        Wr_start  = 16'b0000_0000_0000_0010,
        Wr_ctrl   = 16'b0000_0000_0000_0100,
        Ack1      = 16'b0000_0000_0000_1000,
        Wr_addr1  = 16'b0000_0000_0001_0000,
        Ack2      = 16'b0000_0000_0010_0000,
        Wr_addr2  = 16'b0000_0000_0100_0000,
        Ack3      = 16'b0000_0000_1000_0000,
        Wr_data   = 16'b0000_0001_0000_0000,
        Ack4      = 16'b0000_0010_0000_0000,
        Rd_start  = 16'b0000_0100_0000_0000,
        Rd_ctrl   = 16'b0000_1000_0000_0000,
        Ack5      = 16'b0001_0000_0000_0000,
        Rd_data   = 16'b0010_0000_0000_0000,
        Nack      = 16'b0100_0000_0000_0000,
        Stop      = 16'b1000_0000_0000_0000;
        
    //sda数据总线控制位
    reg sda_en;
    
    //sda数据输出寄存器
    reg sda_reg;
    
    assign sda = sda_en ? sda_reg : 1'bz;
        
    //状态寄存器
    reg [15:0]state;
    
    //读写数据标志位
    reg W_flag;
    reg R_flag;
    
    //写数据到sda总线缓存器
    reg [7:0]sda_data_out;
    reg [7:0]sda_data_in;
    reg [3:0]bit_cnt;
    
	 reg [2:0]cs_bit=3'b000;
    
    reg [7:0]scl_cnt;
    parameter SCL_CNT_M = SYS_CLOCK/SCL_CLOCK;  //计数最大值
    reg scl_cnt_state;
    
    //产生SCL时钟状态标志scl_cnt_state，为1表示IIC总线忙，为0表示总线闲
    always@(posedge clk50M or negedge reset)
    begin
        if(!reset)
            scl_cnt_state <= 1'b0;
        else if(iic_en)
            scl_cnt_state <= 1'b1;
        else if(done)
            scl_cnt_state <= 1'b0;
        else
            scl_cnt_state <= scl_cnt_state;
    end
    
    //scl时钟总线产生计数器
    always@(posedge clk50M or negedge reset)
    begin
        if(!reset)
            scl_cnt <= 8'b0;
        else if(scl_cnt_state)
        begin
            if(scl_cnt == SCL_CNT_M - 1)
                scl_cnt <= 8'b0;
            else
                scl_cnt <= scl_cnt + 8'b1;
        end
        else
            scl_cnt <= 8'b0;
    end
    
    //scl时钟总线产生
    always@(posedge clk50M or negedge reset)
    begin
        if(!reset)
            scl <= 1'b1;
        else if(scl_cnt == (SCL_CNT_M>>1)-1)
            scl <= 1'b0;
        else if(scl_cnt == SCL_CNT_M - 1)
            scl <= 1'b1;
        else
            scl <= scl;
    end
    
    //scl时钟电平中部标志位
    reg scl_high;
    reg scl_low;
    
    always@(posedge clk50M or negedge reset)
    begin
        if(!reset)
        begin
            scl_high <= 1'b0;
            scl_low  <= 1'b0;
        end         
        else if(scl_cnt == (SCL_CNT_M>>2))
            scl_high <= 1'b1;
        else if(scl_cnt == (SCL_CNT_M>>1)+(SCL_CNT_M>>2))
            scl_low  <= 1'b1;
        else
        begin
            scl_high <= 1'b0;
            scl_low  <= 1'b0;       
        end
    end 
    
    //状态机
    always@(posedge clk50M or negedge reset)
    begin
        if(!reset)
        begin
            state <= Idle;
            sda_en <= 1'b0;
            sda_reg <= 1'b1;
            W_flag <= 1'b0;
            R_flag <= 1'b0;         
            done <= 1'b0;
        end
        else        
        case(state)
            Idle:
            begin   
                done <= 1'b0;
                W_flag <= 1'b0;       
                R_flag <= 1'b0;
                sda_en <= 1'b0;         
                sda_reg <= 1'b1;
                if(iic_en && write)     //使能IIC并且为写操作
                begin
                    W_flag <= 1'b1;     //写标志位置1 
                    sda_en <= 1'b1;     //设置SDA为输出模式
                    sda_reg <= 1'b1;    //SDA输出高电平
                    state <= Wr_start;  //跳转到起始状态                 
                end
                else if(iic_en && read) //使能IIC并且为读操作
                begin
                    R_flag <= 1'b1;     //读标志位置1 
                    sda_en <= 1'b1;     //设置SDA为输出模式
                    sda_reg <= 1'b1;    //SDA输出高电平
                    state <= Wr_start;  //跳转到起始状态
                end
                else
                    state <= Idle;              
            end         
            
            Wr_start:
            begin
                if(scl_high)
                begin
                    sda_reg <= 1'b0;
                    state <= Wr_ctrl;
                    sda_data_out <= {4'b1101, cs_bit,1'b0};  
                    bit_cnt <= 4'd8;
                end
                else
                begin
                    sda_reg <= 1'b1;
                    state <= Wr_start;
                end 
            end
            
            Wr_ctrl:    //写控制字节4'b1010+3位片选地址+1位写控制
            begin
                if(scl_low)
                begin
                    bit_cnt <= bit_cnt -4'b1;
                    sda_reg <= sda_data_out[7];
                    sda_data_out <= {sda_data_out[6:0],1'b0};
                    if(bit_cnt == 0)
                    begin
                        state <= Ack2;
                        sda_en <= 1'b0;
                    end
                    else 
                        state <= Wr_ctrl;                   
                end
                else
                    state <= Wr_ctrl;   
            end
            
            /*Ack1:      //通过判断SDA是否拉低来判断是否有从机响应
            begin               
                if(scl_high)
                    if(sda == 1'b0)
                    begin
                        state <= Wr_addr1;                      
                        sda_data_out <= {3'bxxx,address[12:8]};
                        bit_cnt <= 4'd8;
                    end
                    else
                        state <= Idle;
                else
                    state <= Ack1;                  
            end
            
            Wr_addr1:  //写2字节地址中的高地址字节中的低五位
            begin
                if(scl_low)
                begin
                    sda_en <= 1'b1;
                    bit_cnt <= bit_cnt -4'b1;
                    sda_reg <= sda_data_out[7];
                    sda_data_out <= {sda_data_out[6:0],1'b0};
                    if(bit_cnt == 0)
                    begin
                        state <= Ack2;                      
                        sda_en <= 1'b0;                     
                    end
                    else 
                        state <= Wr_addr1;                  
                end
                else
                    state <= Wr_addr1;
            end*/
            
            Ack2:   //通过判断SDA是否拉低来判断是否有从机响应
            begin               
                if(scl_high)
                    if(sda == 1'b0)
                    begin
                        state <= Wr_addr2;                      
                        sda_data_out <= address[7:0];
                        bit_cnt <= 4'd8;
                    end
                    else
                        state <= Idle;
                else
                    state <= Ack2;                  
            end
            
            Wr_addr2:  //写2字节地址中的低地址字节
            begin
                if(scl_low)
                begin
                    sda_en <= 1'b1;
                    bit_cnt <= bit_cnt -4'b1;
                    sda_reg <= sda_data_out[7];
                    sda_data_out <= {sda_data_out[6:0],1'b0};
                    if(bit_cnt == 0)
                    begin
                        state <= Ack3;                      
                        sda_en <= 1'b0;                     
                    end
                    else 
                        state <= Wr_addr2;                  
                end
                else
                    state <= Wr_addr2;
            end
            
            Ack3:  //通过判断SDA是否拉低来判断是否有从机响应
            begin                   
                if(scl_high)
                    if(sda == 1'b0)  //有响应就判断是读还是写操作
                    begin                           
                        if(W_flag)        //如果是写数据操作，进入写数据状态
                        begin                           
                            sda_data_out <= write_data;
                            bit_cnt <= 4'd8;
                            state <= Wr_data;
                        end
                        else if(R_flag)  //如果是读数据操作，进入读数据开始状态
                        begin
                            state <= Rd_start;
                            sda_reg <= 1'b1;
                        end
                    end
                    else
                        state <= Idle;
                else
                    state <= Ack3;              
            end
            
            Wr_data:         //写数据状态，向EEPROM写入数据
            begin           
                if(scl_low)
                begin
                    sda_en <= 1'b1;
                    bit_cnt <= bit_cnt -4'b1;
                    sda_reg <= sda_data_out[7];
                    sda_data_out <= {sda_data_out[6:0],1'b0};
                    if(bit_cnt == 0)
                    begin
                        state <= Ack4;
                        sda_en <= 1'b0;
                    end
                    else 
                        state <= Wr_data;                   
                end
                else
                    state <= Wr_data;
            end         
            
            Ack4:   //通过判断SDA是否拉低来判断是否有从机响应
            begin
                if(scl_high)
                    if(sda == 1'b0)    //有响应就进入停止状态
                    begin
                        sda_reg <= 1'b0;
                        state <= Stop;                                              
                    end
                    else
                        state <= Idle;
                else
                    state <= Ack4;
            end
            
            Rd_start:    //读数据的开始操作       
            begin
                if(scl_low)
                begin
                    sda_en <= 1'b1;
                end
                else if(scl_high)
                begin
                    sda_reg <= 1'b0;
                    state <= Rd_ctrl;
                    sda_data_out <= {4'b1101, cs_bit,1'b1};
                    bit_cnt <= 4'd8;
                end
                else
                begin
                    sda_reg <= 1'b1;
                    state <= Rd_start;
                end 
            end
            
            
            Rd_ctrl:      //写控制字节4'b1010+3位片选地址+1位读控制       
            begin
                if(scl_low)
                begin
                    bit_cnt <= bit_cnt -4'b1;
                    sda_reg <= sda_data_out[7];
                    sda_data_out <= {sda_data_out[6:0],1'b0};
                    if(bit_cnt == 0)
                    begin
                        state <= Ack5;
                        sda_en <= 1'b0;
                    end
                    else 
                        state <= Rd_ctrl;                   
                end
                else
                    state <= Rd_ctrl;   
            end         
            
            Ack5:     //通过判断SDA是否拉低来判断是否有从机响应       
            begin               
                if(scl_high)
                    if(sda == 1'b0)   //有响应就进入读数据状态
                    begin
                        state <= Rd_data;
                        sda_en <= 1'b0;   //SDA总线设置为3态输入
                        bit_cnt <= 4'd8;
                    end
                    else
                        state <= Idle;
                else
                    state <= Ack5;                  
            end     
            
            Rd_data:          //读数据状态
            begin
                if(scl_high)  //在时钟高电平读取数据
                begin
                    sda_data_in <= {sda_data_in[6:0],sda};
                    bit_cnt <= bit_cnt - 4'd1;
                    state <= Rd_data;
                end
                else if(scl_low && bit_cnt == 0) //数据接收完成进入无应答响应状态
                begin
                    state <= Nack;                  
                end
                else
                    state <= Rd_data;                   
            end
            
            Nack:   //不做应答响应
            begin
                read_data <= sda_data_in;
                if(scl_high)
                begin
                    state <= Stop;  
                    sda_reg <= 1'b0;
                end
                else
                    state <= Nack;          
            end
            
            Stop:   //停止操作，在时钟高电平，SDA上升沿
            begin
                if(scl_low)
                begin
                    sda_en <= 1'b1;                 
                end             
                else if(scl_high)
                begin
                    sda_en <= 1'b1;
                    sda_reg <= 1'b1;                
                    state <= Idle;
                    done <= 1'b1;
                end             
                else
                    state <= Stop;
            end
    
            default:
            begin
                state <= Idle;
                sda_en <= 1'b0;
                sda_reg <= 1'b1;
                W_flag <= 1'b0;
                R_flag <= 1'b0;
                done <= 1'b0;
            end     
        endcase     
    end 

endmodule



////////////////////////////////////////////////////////////iic///////////////////////////////////////////////////////////////



module tem_read(sda,scl,clk50M,reset,
                 tem_data1,tem_data2,
					  accelx_data1,accelx_data2,
					  accely_data1,accely_data2,
					  accelz_data1,accelz_data2,
					  gyrox_data1,gyrox_data2,
					  gyroy_data1,gyroy_data2,
					  gyroz_data1,gyroz_data2,
					  state,done,finish);
IIC icc(
    clk50M,
    reset,
    iic_en,
    address,
    write,
    write_data,
    read,
    read_data,
    scl,
    sda,
    done
);
	 reg [7:0]state;
    reg iic_en;
    reg [7:0]address;
    reg write;
    reg [7:0]write_data;
    reg read;
	 reg [20:0]t;
	 wire [7:0]read_data;
	 output [7:0]state;
	 input clk50M,reset;
	 inout sda;
	 output scl,done;
	 output reg finish;
	 output reg[7:0]tem_data1,tem_data2,
	                accelx_data1,accelx_data2,
					    accely_data1,accely_data2,
					    accelz_data1,accelz_data2,
					    gyrox_data1,gyrox_data2,
					    gyroy_data1,gyroy_data2,
					    gyroz_data1,gyroz_data2;

always@(posedge clk50M or negedge reset)
if(!reset)
	state=0;
else
begin
case(state)
0:begin//初始化mpu
        iic_en=1'b0;
        address=8'h0;
        write=1'b0;
        write_data=8'b0;
        read=1'b0;
		  state=1;
		  t=0;
		  end
1:begin
  //复位mpu6050
  write=1;
  address=8'h6b;
  write_data=8'h80;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  write=0;
  state=2;
  end
  end
2:begin//等待100ms
	  t=t+1;
	  if (t==2000000)
       begin
		 state=3;
		 t=0;
		 end
  end
3:begin
  write=1;//唤醒mpu6050
  address=8'h6b;
  write_data=8'h00;
  iic_en=1;
  if(done)
	  begin
	  iic_en=0;
	  state=4;
	  //write=0;
	  end
  end
4:begin
  //设置陀螺仪分辨率±2000dps
  //write=1;
  address=8'h1b;
  write_data=8'h18;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  //write=0;
  state=5;
  end
  end
5:begin
  //设置加速度分辨率±2g
  //write=1;
  address=8'h1c;
  write_data=8'h00;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  //write=0;
  state=6;
  end
  end
6:begin
  //设置低通滤波器
  //write=1;
  address=8'h1a;
  write_data=4;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  state=7;
  //write=0;
  end
  end
7:begin
  //传感器不进入待机
  //write=1;
  address=8'h6c;
  write_data=8'h0;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  state=9;
  //write=0;
  end
  end
9:begin
  //关闭中断，
  //write=1;
  address=8'h38;
  write_data=0;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  state=10;
  //write=0;
  end
  end
10:begin
  //write=1;
  address=8'h6a;
  write_data=0;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  state=11;
  //write=0;
  end
  end
11:begin
  //write=1;
  address=8'h23;
  write_data=0;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  state=12;
  //write=0;
  end
  end
12:begin
  //int低有效
  //write=1;
  address=8'h37;
  write_data=8'h80;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  write=0;
  state=13;
  end
  end
13:begin
  read=1;
  iic_en=1;
  if(done)
  begin
  state=8;
  iic_en=0;
  end
  end
8:begin
  address=8'h75;
  iic_en=1;
  if(done)
  iic_en=0;
  if (read_data==8'h68)//器件名正确
  state=14;//begin
  else
  begin
  //state=error;
  tem_data2<=read_data;
  end
  end
14:begin
  write=1;
  address=8'h6B;//X轴为参考
  write_data=8'h01;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  state=15;
  //write=0;
  end
  end
15:begin
  address=8'h6C;//加速度和陀螺仪都工作
  write_data=0;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  state=16;
  //write=0;
  end
  end
16:begin
  //设置采样率50Hz
  //write=1;
  address=8'h19;
  write_data=19;
  iic_en=1;
  if(done)
  begin
  iic_en=0;
  state=17;
  write=0;
  end
  end 
//////////////////////////////////////////////////初始化完成/////////////////////////////////////////////////
17:begin//读温度数据1
  read=1;
  address=8'h41;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  tem_data1<=read_data;//读高8位
	  state=18;
	  end 
  end 
18:begin//读温度数据2
  read=1;
  address=8'h42;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  tem_data2<=read_data;//读低8位
	  state=19;
	  end
  end 
//////////////////////////////////////////////////////温度读取完成//////////////////////////////////////
19:begin//读加速度数据x1
  read=1;
  address=8'h3b;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  accelx_data1<=read_data;//读高8位
	  state=20;
	  end 
  end 
20:begin//读加速度数据x2
  read=1;
  address=8'h3c;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  accelx_data2<=read_data;//读低8位
	  state=21;
	  end
  end 
21:begin//读加速度数据y1
  read=1;
  address=8'h3d;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  accely_data1<=read_data;//读高8位
	  state=22;
	  end 
  end 
22:begin//读加速度数据y2
  read=1;
  address=8'h3e;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  accely_data2<=read_data;//读低8位
	  state=23;
	  end
  end 
23:begin//读加速度数据z1
  read=1;
  address=8'h3f;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  accelz_data1<=read_data;//读高8位
	  state=24;
	  end 
  end 
24:begin//读加速度数据z2
  read=1;
  address=8'h40;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  accelz_data2<=read_data;//读低8位
	  state=25;
	  end
  end 
/////////////////////////////////////////////////////加速度读取完成/////////////////////////////////////
25:begin//读陀螺仪数据x1
  read=1;
  address=8'h43;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  gyrox_data1<=read_data;//读高8位
	  state=26;
	  end 
  end 
26:begin//读陀螺仪数据x2
  read=1;
  address=8'h44;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  gyrox_data2<=read_data;//读低8位
	  state=27;
	  end
  end 
27:begin//读陀螺仪数据y1
  read=1;
  address=8'h45;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  gyroy_data1<=read_data;//读高8位
	  state=28;
	  end 
  end 
28:begin//读陀螺仪数据y2
  read=1;
  address=8'h46;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  gyroy_data2<=read_data;//读低8位
	  state=29;
	  end
  end 
29:begin//读陀螺仪数据z1
  read=1;
  address=8'h47;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  gyroz_data1<=read_data;//读高8位
	  state=30;
	  end 
  end 
30:begin//读陀螺仪数据z2
  read=1;
  address=8'h48;
  iic_en=1;
  if(done)
	  begin
	  iic_en<=0;
	  gyroz_data2<=read_data;//读低8位
	  state=17;//刷新数据
	  finish=1;
	  end
 end
/////////////////////////////////////////////////////////陀螺仪数据读取完成////////////////////////////////////
default:state=0;
endcase

end

endmodule
