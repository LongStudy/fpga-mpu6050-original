module UART(
   rst,
	clk,
	data,
	tx,
   is_send,
	is_done
	);
	
	input rst,clk,is_send;
	input[7:0] data;
	output tx;
	output is_done;
	
	wire BPS_CLK;
	reg [7:0]rdata;
	
	always@(posedge clk or negedge rst)
	if(!rst)
	   rdata<=8'd0;
	else if(is_send)
	   rdata<=data;
	
	  tx_bps_module U1
	  (
	      .CLK( clk),
			.RSTn( rst ),
			.Count_Sig( is_send),    // input - from U2
			.BPS_CLK( BPS_CLK )         // output - to U2
	  );
	  
	  /*********************************/
	  
	  tx_control_module U2
	  (
	      .CLK( clk ),
			.RSTn( rst ),
			.TX_En_Sig( is_send ),    // input - from top
			.TX_Data( rdata ),        // input - from top
			.BPS_CLK( BPS_CLK ),        // input - from U2
			.TX_Done_Sig( is_done ),  // output - to top
			.TX_Pin_Out( tx )     // output - to top
	  );
	  
	  /***********************************/

	
	
endmodule 