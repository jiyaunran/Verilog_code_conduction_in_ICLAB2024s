module Handshake_syn #(parameter WIDTH=8) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
output reg flag_handshake_to_clk1;
input flag_clk1_to_handshake; // send data signal

output flag_handshake_to_clk2; // data ready signal
input flag_clk2_to_handshake;

// Remember:
//   Don't modify the signal name
reg sreq;
wire dreq;
reg dack;
wire sack;

//-------------------------------------
//		registers and wires
//-------------------------------------
reg sreq_comb;

reg src_ctrl;
reg [WIDTH-1:0] data, data_comb;

reg dest_ctrl;
reg [WIDTH-1:0] dout_comb;
reg [WIDTH-1:0] dout_store, dout_store_comb;
reg dack_comb;
reg sidle_reg;
reg [1:0] receive_state, receive_state_comb;
reg [1:0] send_state, send_state_comb;
reg dack_addition_edge[8:0];
//------------------------------------
//			parameters
//------------------------------------
parameter IDLE = 0;
parameter SEND = 1;
parameter WAIT = 2;

genvar i;
//------------------------------------
//		module1 to source
//------------------------------------
always @ * begin
	case(receive_state) // synopsys full_case
		IDLE	:	begin
						if(sready)		receive_state_comb = SEND;
						else			receive_state_comb = IDLE;
					end
		SEND	:	begin
						if(sack)		receive_state_comb = WAIT;
						else			receive_state_comb = SEND;
					end
		WAIT	:	begin
						if(!sack)		receive_state_comb = IDLE;
						else			receive_state_comb = WAIT;
					end
	endcase
end

always @ (posedge sclk or negedge rst_n) begin
	if(!rst_n) begin
		receive_state <= IDLE;
	end
	else begin
		receive_state <= receive_state_comb;
	end
end


always @ (posedge sclk or negedge rst_n) begin
	if(!rst_n) begin
		sidle_reg <= 'd1;
	end
	else begin
		if(receive_state == IDLE) begin
			sidle_reg <= 'd1;
		end
		else begin
			sidle_reg <= 'd0;
		end
	end
end

assign sidle = sidle_reg;

always @ * begin
	if(sack) begin
		sreq_comb = 'd0;
	end
	else if(sready) begin
		sreq_comb = 'd1;
	end
	else begin
		sreq_comb = sreq;
	end
end

always @ (posedge sclk or negedge rst_n) begin
	if(!rst_n) begin
		sreq <= 'd0;
	end
	else begin
		sreq <= sreq_comb;
	end
end

NDFF_syn req_syncronizer(.D(sreq), .Q(dreq), .clk(dclk), .rst_n(rst_n));

always @ * begin	
	if(sready) begin
		src_ctrl = 'd1;
 	end
	else begin
		src_ctrl = 'd0;
	end
end

//-------------------------------------
//		source to receive
//-------------------------------------
always @ * begin
	if(src_ctrl) begin
		data_comb = din;
	end
	else begin
		data_comb = data;
	end
end

always @ (posedge sclk or negedge rst_n) begin
	if(!rst_n) begin
		data <= 'd0;
	end
	else begin
		data <= data_comb;
	end
end

always @ * begin
	if(dest_ctrl) begin
		dout_store_comb = dout_store;
	end
	else begin
		dout_store_comb = data;
	end
end
/*
always @ (posedge dclk or negedge rst_n) begin
	if(!rst_n) begin
		dout_store <= 'd0;
	end
	else begin
		dout_store <= dout_store_comb;
	end
end
*/
always @ (posedge dclk or negedge rst_n) begin
	if(!rst_n) begin
		dout <= 'd0;
	end
	else begin
		if(send_state == SEND) begin
			dout <= dout_store_comb;
		end
		else begin
			dout <= 'd0;
		end
	end
end

always @ (posedge dclk or negedge rst_n) begin
	if(!rst_n) begin
		dvalid <= 'd0;
	end
	else begin
		if(send_state == SEND) begin
			dvalid <= 'd1;
		end
		else begin
			dvalid <= 'd0;
		end
	end
end

//-------------------------------------
//		receive to module2
//-------------------------------------
always @ * begin
	case(send_state) // synopsys full_case
		IDLE	:	begin
						if(dreq && !dbusy)	send_state_comb = SEND;
						else		send_state_comb = IDLE;
					end
		SEND	:	begin
						send_state_comb = WAIT;
					end
		WAIT	:	begin
						if(!dreq) 	send_state_comb = IDLE;
						else		send_state_comb = WAIT;
					end
	endcase
end

always @ (posedge dclk or negedge rst_n) begin
	if(!rst_n) begin
		send_state <= IDLE;
	end
	else begin
		send_state <= send_state_comb;
	end
end

always @ * begin
	if(dack && !dbusy) begin
		dest_ctrl = 'd1;
	end
	else begin
		dest_ctrl = 'd0;
	end
end

always @ * begin
	if(send_state == SEND || send_state == WAIT) begin
		dack_comb = 'd1;
	end
	else begin
		dack_comb = 'd0;
	end
end

//always @ (posedge dclk or negedge rst_n) begin
//	if(!rst_n) begin
//		dack_addition_edge[8] <= 'd0;
//	end
//	else begin
//		dack_addition_edge[8] <= dack_comb;
//	end
//end

//generate
//for(i=0;i<8;i=i+1) begin : satisfy_3_edge
//	always @ (posedge dclk or negedge rst_n) begin
//		if(!rst_n) begin
//			dack_addition_edge[i] <= 'd0;
//		end
//		else begin
//			if(dack_comb) begin
//				dack_addition_edge[i] <= 'd1;
//			end
//			else begin
//				dack_addition_edge[i] <= dack_addition_edge[i+1];
//			end
//		end
//	end
//end
//endgenerate

always @ (posedge dclk or negedge rst_n) begin
	if(!rst_n) begin
		dack <= 'd0;
	end
	else begin
		dack <= dack_comb;
	end
end

NDFF_syn ack_synchronizer(.D(dack), .Q(sack), .clk(sclk), .rst_n(rst_n));

endmodule