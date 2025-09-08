module fir_filter_2d(clk, rst_n, input_data, valid_dmac, tc_set, output_data, valid_core); //synthesis ok
parameter IDLE_S = 0;
parameter TC_SET_S = 1;
parameter CALC_S = 2;
parameter WAIT_S = 3;
parameter MAC_W = 21;
parameter RGB_SIZE = 24;  //added for MAC
parameter FILTERING_SIZE = 9; //added for MAC

input clk;
input rst_n;	
input valid_dmac;
input tc_set;
input [RGB_SIZE*FILTERING_SIZE-1:0] input_data;
	
output reg [23:0] output_data;
output reg valid_core;
	
//For FSM
reg [1:0] present_state, next_state;
reg tc_write, tc_en, mac_en, mac_clr, output_en;
	
//For Demux
reg [23:0] demux_img [8:0]; //added for MAC
reg [23:0] demux_tc; //added for MAC


//For TC FIFO
parameter QUEUE_SIZE = 9;
integer i;
reg [7:0] filter_tc_r[QUEUE_SIZE-1:0];
reg [7:0] filter_tc_g[QUEUE_SIZE-1:0];
reg [7:0] filter_tc_b[QUEUE_SIZE-1:0];
reg empty, full;
reg [3:0] front_ptr, rear_ptr;
reg [7:0] filter_tc_out_r, filter_tc_out_g, filter_tc_out_b;
	
//For MAC
reg [MAC_W-1:0] mac_r, mac_g, mac_b;


//---------------------Core_FSM----------------------//
always @(posedge clk, negedge rst_n)
begin
 if(!rst_n) begin
  present_state <= IDLE_S;

 end
 else
  present_state <= next_state;
end

always @(*)
begin
 case(present_state)
  IDLE_S   : if      (tc_set == 1 && valid_dmac == 1) next_state <= TC_SET_S;
  	     else if (tc_set == 0 && valid_dmac == 1) next_state <= CALC_S;
	     else if 		    (valid_dmac == 0) next_state <= IDLE_S;
	     else				      next_state <= IDLE_S;

  TC_SET_S : if	     (tc_set == 1 && valid_dmac == 1) next_state <= TC_SET_S;
	     else if (tc_set == 0 && valid_dmac == 1) next_state <= CALC_S;
	     else if 		    (valid_dmac == 0) next_state <= TC_SET_S;

  CALC_S   : if      (tc_set == 0 && valid_dmac == 1) next_state <= CALC_S;
	     else if (tc_set == 1 && valid_dmac == 1) next_state <= CALC_S;
	     else if 		    (valid_dmac == 0) next_state <= WAIT_S;

  WAIT_S   :   		 			      next_state <= IDLE_S;


 endcase
end

always @(*)
begin
 case(present_state)
  IDLE_S   : if      (tc_set == 1 && valid_dmac == 1) begin mac_en = 0; mac_clr = 0; tc_en = 1; tc_write = 1; output_en = 0; valid_core = 0; end
             else if (tc_set == 0 && valid_dmac == 1) begin mac_en = 1; mac_clr = 0; tc_en = 1; tc_write = 0; output_en = 0; valid_core = 0; end
             else if 	 	    (valid_dmac == 0) begin mac_en = 0; mac_clr = 1; tc_en = 0; tc_write = 0; output_en = 0; valid_core = 0; end

  TC_SET_S : if	     (tc_set == 1 && valid_dmac == 1) begin mac_en = 0; mac_clr = 0; tc_en = 1; tc_write = 1; output_en = 0; valid_core = 0; end
	     else if (tc_set == 0 && valid_dmac == 1) begin mac_en = 1; mac_clr = 0; tc_en = 1; tc_write = 0; output_en = 0; valid_core = 0; end
	     else if 		    (valid_dmac == 0) begin mac_en = 0; mac_clr = 0; tc_en = 0; tc_write = 0; output_en = 0; valid_core = 0; end

  CALC_S   : if      (tc_set == 0 && valid_dmac == 1) begin mac_en = 1; mac_clr = 0; tc_en = 1; tc_write = 0; output_en = 0; valid_core = 0; end
	     else if (tc_set == 1 && valid_dmac == 1) begin mac_en = 0; mac_clr = 0; tc_en = 0; tc_write = 0; output_en = 0; valid_core = 0; end
	     else if 		    (valid_dmac == 0) begin mac_en = 0; mac_clr = 0; tc_en = 0; tc_write = 0; output_en = 1; valid_core = 0; end

  WAIT_S   :   		 			      begin mac_en = 0; mac_clr = 1; tc_en = 0; tc_write = 0; output_en = 0; valid_core = 1; end
 endcase
end


//---------------------Calc_block----------------------//

//---------1.Demux---------//

always @(*) begin
	if(tc_write) begin
		demux_tc <= input_data[RGB_SIZE-1:0]; //added for MAC
		demux_img[0] <= 24'b0;
		demux_img[1] <= 24'b0;
		demux_img[2] <= 24'b0;
		demux_img[3] <= 24'b0;
		demux_img[4] <= 24'b0;
		demux_img[5] <= 24'b0;
		demux_img[6] <= 24'b0;
		demux_img[7] <= 24'b0;
		demux_img[8] <= 24'b0; //added for MAC	
	end
	else begin
		demux_img[0] <= input_data[0*RGB_SIZE+:RGB_SIZE];
		demux_img[1] <= input_data[1*RGB_SIZE+:RGB_SIZE];
		demux_img[2] <= input_data[2*RGB_SIZE+:RGB_SIZE];
		demux_img[3] <= input_data[3*RGB_SIZE+:RGB_SIZE];
		demux_img[4] <= input_data[4*RGB_SIZE+:RGB_SIZE];
		demux_img[5] <= input_data[5*RGB_SIZE+:RGB_SIZE];
		demux_img[6] <= input_data[6*RGB_SIZE+:RGB_SIZE];
		demux_img[7] <= input_data[7*RGB_SIZE+:RGB_SIZE];
		demux_img[8] <= input_data[8*RGB_SIZE+:RGB_SIZE]; //added for MAC	
		demux_tc <= 24'b0;	
	end
end


//---------2.TC FIFO---------//
initial
begin
 rear_ptr  <= 0;
 front_ptr <= 0;
end

always @(posedge clk)
begin
 if(tc_en == 1'b1 && tc_write == 1'b1) begin
  front_ptr <= front_ptr;
  filter_tc_r[rear_ptr] <= demux_tc[0+:8];
  filter_tc_g[rear_ptr] <= demux_tc[8+:8];
  filter_tc_b[rear_ptr] <= demux_tc[16+:8];
  if(rear_ptr == QUEUE_SIZE-1)
   rear_ptr <= 1'b0;
  else
   rear_ptr <= rear_ptr + 1'b1;
  end
  else if(tc_en == 1'b1 && tc_write == 1'b0) begin
   rear_ptr <= rear_ptr;
   if(front_ptr == QUEUE_SIZE-1)
    front_ptr <= 1'b0;
   else
    front_ptr <= front_ptr + 1'b1;
  end

  else begin
   front_ptr <= front_ptr;
   rear_ptr <= rear_ptr;				
  end
end

always @(*)
begin
 filter_tc_out_r <= filter_tc_r[front_ptr];
 filter_tc_out_g <= filter_tc_g[front_ptr];
 filter_tc_out_b <= filter_tc_b[front_ptr];
end


//---------3.MAC---------//
always @(posedge clk, negedge rst_n) begin
 if(!rst_n) begin
  mac_r <= 21'b0;
  mac_g <= 21'b0;
  mac_b <= 21'b0;
 end
 else if(mac_clr) begin
  mac_r <= 21'b0;
  mac_g <= 21'b0;
  mac_b <= 21'b0;
 end
 else if(mac_clr == 1'b0 && mac_en == 1'b1) begin
  mac_r <= $signed(filter_tc_r[0]) * $signed({1'b0, demux_img[0][0+:8]})+
					$signed(filter_tc_r[1]) * $signed({1'b0, demux_img[1][0+:8]})+
					$signed(filter_tc_r[2]) * $signed({1'b0, demux_img[2][0+:8]})+
					$signed(filter_tc_r[3]) * $signed({1'b0, demux_img[3][0+:8]})+
					$signed(filter_tc_r[4]) * $signed({1'b0, demux_img[4][0+:8]})+
					$signed(filter_tc_r[5]) * $signed({1'b0, demux_img[5][0+:8]})+
					$signed(filter_tc_r[6]) * $signed({1'b0, demux_img[6][0+:8]})+
					$signed(filter_tc_r[7]) * $signed({1'b0, demux_img[7][0+:8]})+
					$signed(filter_tc_r[8]) * $signed({1'b0, demux_img[8][0+:8]});

  mac_g <= $signed(filter_tc_g[0]) * $signed({1'b0, demux_img[0][8+:8]})+
					$signed(filter_tc_g[1]) * $signed({1'b0, demux_img[1][8+:8]})+
					$signed(filter_tc_g[2]) * $signed({1'b0, demux_img[2][8+:8]})+
					$signed(filter_tc_g[3]) * $signed({1'b0, demux_img[3][8+:8]})+
					$signed(filter_tc_g[4]) * $signed({1'b0, demux_img[4][8+:8]})+
					$signed(filter_tc_g[5]) * $signed({1'b0, demux_img[5][8+:8]})+
					$signed(filter_tc_g[6]) * $signed({1'b0, demux_img[6][8+:8]})+
					$signed(filter_tc_g[7]) * $signed({1'b0, demux_img[7][8+:8]})+
					$signed(filter_tc_g[8]) * $signed({1'b0, demux_img[8][8+:8]});

  mac_b <= $signed(filter_tc_b[0]) * $signed({1'b0, demux_img[0][16+:8]})+
					$signed(filter_tc_b[1]) * $signed({1'b0, demux_img[1][16+:8]})+
					$signed(filter_tc_b[2]) * $signed({1'b0, demux_img[2][16+:8]})+
					$signed(filter_tc_b[3]) * $signed({1'b0, demux_img[3][16+:8]})+
					$signed(filter_tc_b[4]) * $signed({1'b0, demux_img[4][16+:8]})+
					$signed(filter_tc_b[5]) * $signed({1'b0, demux_img[5][16+:8]})+
					$signed(filter_tc_b[6]) * $signed({1'b0, demux_img[6][16+:8]})+
					$signed(filter_tc_b[7]) * $signed({1'b0, demux_img[7][16+:8]})+
					$signed(filter_tc_b[8]) * $signed({1'b0, demux_img[8][16+:8]});
	end
	else begin
		mac_r <= mac_r;
		mac_g <= mac_g;
		mac_b <= mac_b;
	end
end

//---------4.Saturatin and Output reg---------//
always @(posedge clk, negedge rst_n) begin
 if(!rst_n) begin
  output_data <= 24'b0;
 end
 else if(output_en) begin
   if(mac_r[MAC_W-1] == 1)
   output_data[0+:8] <= 0;
  else if(mac_r[MAC_W-2:0]>255)
   output_data[0+:8] <= 8'b11111111;
  else
   output_data[0+:8] <= mac_r[0+:8];

  if(mac_g[MAC_W-1] == 1)
   output_data[8+:8] <= 0;
  else if(mac_g[MAC_W-2:0]>255)
   output_data[8+:8] <= 8'b11111111;
  else
   output_data[8+:8] <= mac_g[0+:8];

  if(mac_b[MAC_W-1] == 1)
   output_data[16+:8] <= 0;
  else if(mac_b[MAC_W-2:0]>255)
   output_data[16+:8] <= 8'b11111111;
  else
   output_data[16+:8] <= mac_b[0+:8];
 end
 else
  output_data <= output_data;
end

endmodule
