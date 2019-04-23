//模块文件名：IIC.v
//模块功能：实现IIC总线协议控制
//时间：2016.11.2
module IIC(
    clk50M,
    reset,
    iic_en,
    cs_bit,
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
    input [2:0]cs_bit;         //器件选择地址
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
        
    
    reg [7:0]scl_cnt;
    parameter SCL_CNT_M = SYS_CLOCK/SCL_CLOCK;  //计数最大值
    reg scl_cnt_state;
    
    //产生SCL时钟状态标志scl_cnt_state，为1表示IIC总线忙，为0表示总线闲
    always@(posedge clk50M or negedge reset)
    begin
        if(!reset)
            scl_cnt_state <= 1'b0;
        else if(1)
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