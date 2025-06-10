module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
	in_matrix_A,
    in_matrix_B,
    out_idle,
    handshake_sready,
    handshake_din,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

	fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_matrix,

    flag_clk1_to_fifo,
    flag_fifo_to_clk1
);
input clk;
input rst_n;
input in_valid;
input [3:0] in_matrix_A;
input [3:0] in_matrix_B;
input out_idle;
output reg handshake_sready;
output reg [7:0] handshake_din;
// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;
output flag_clk1_to_handshake; // flag that tell a input signal coming

input fifo_empty;
input [7:0] fifo_rdata;
output fifo_rinc;
output reg out_valid;
output reg [7:0] out_matrix;
// You can use the the custom flag ports for your design
output flag_clk1_to_fifo;
input flag_fifo_to_clk1;

//-------------------------------------
//		Registers and Wires
//-------------------------------------
reg [2:0] state, state_comb;
reg [3:0] Matrix_A[15:0];
reg [3:0] Matrix_B[15:0];

reg [1:0] receive_state, receive_state_comb;

reg [3:0] send_cnt, send_cnt_comb;

reg [7:0] cur_send_data;

reg [7:0] out_cnt;

reg clean;
reg fifo_rinc_reg;

reg receive_fifo_delay;

//-------------------------------------
//		Registers and Wires
//-------------------------------------
parameter IDLE = 0;
parameter RECEIVE_PAT = 1;
parameter SEND_HANDSHAKE = 2;
parameter WAIT_SIDLE = 3;
parameter WAIT_SIDLE2 = 4;
parameter WAIT_SENDING = 5;

parameter SEND_REQUEST = 1;
parameter RECEIVE_FIFO = 2;
parameter EMPTY_WAIT = 3;

genvar i,j;
//-------------------------------------
//				FSM
//-------------------------------------
always @ * begin
	case(state) // synopsys full_case
		IDLE				:	begin
									if(in_valid)			state_comb = RECEIVE_PAT;
									else					state_comb = IDLE;
								end		
		RECEIVE_PAT			:	begin		
									if(!in_valid)			state_comb = SEND_HANDSHAKE;
									else					state_comb = RECEIVE_PAT;
								end
		SEND_HANDSHAKE		:								state_comb = WAIT_SIDLE;
		WAIT_SIDLE			:								state_comb = WAIT_SIDLE2;
		WAIT_SIDLE2			:								state_comb = WAIT_SENDING;
		WAIT_SENDING		:	begin
									if(out_idle) begin
										if(send_cnt == 'd15)	state_comb = IDLE;
										else				state_comb = SEND_HANDSHAKE;
									end
									else					state_comb = WAIT_SENDING;
								end
	endcase
end

always @ * begin
	case(receive_state) // synopsys full_case
		IDLE			:	begin
								if(!fifo_empty) 		receive_state_comb = SEND_REQUEST;
								else					receive_state_comb = IDLE;
							end
		SEND_REQUEST	:	begin
								if(fifo_empty)			receive_state_comb = SEND_REQUEST;
								else					receive_state_comb = RECEIVE_FIFO;
							end
		RECEIVE_FIFO	:	begin
								if(fifo_empty)			receive_state_comb = EMPTY_WAIT;
								else					receive_state_comb = SEND_REQUEST;
							end
		EMPTY_WAIT		:	begin
								if(!fifo_empty) 		receive_state_comb = SEND_REQUEST;
								else					receive_state_comb = IDLE;
							end
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state <= IDLE;
	end
	else begin
		state <= state_comb;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		receive_state <= IDLE;
	end
	else begin
		receive_state <= receive_state_comb;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_cnt <= 'd0;
	end
	else begin
		if(receive_fifo_delay) begin
			out_cnt <= out_cnt + 'd1;
		end
		else begin
			out_cnt <= out_cnt;
		end
	end
end
//-------------------------------------
//			RECEIVE from PAT
//-------------------------------------
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Matrix_A[15] <= 'd0;
	end
	else begin
		if(in_valid && (state == RECEIVE_PAT || state == IDLE)) begin
			Matrix_A[15] <= in_matrix_A;
		end
		else begin
			Matrix_A[15] <= Matrix_A[15];
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Matrix_B[15] <= 'd0;
	end
	else begin
		if(in_valid && (state == RECEIVE_PAT || state == IDLE)) begin
			Matrix_B[15] <= in_matrix_B;
		end
		else begin
			Matrix_B[15] <= Matrix_B[15];
		end
	end
end

generate
	for(i=0;i<15;i=i+1) begin : Matrix_A_assignment
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				Matrix_A[i] <= 'd0;
			end
			else begin
				if(in_valid && (state == RECEIVE_PAT || state == IDLE)) begin
					Matrix_A[i] <= Matrix_A[i+1];
				end
				else begin
					Matrix_A[i] <= Matrix_A[i];
				end
			end
		end
	end
	
	for(i=0;i<15;i=i+1) begin : Matrix_B_assignment
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				Matrix_B[i] <= 'd0;
			end
			else begin
				if(in_valid && (state == RECEIVE_PAT || state == IDLE)) begin
					Matrix_B[i] <= Matrix_B[i+1];
				end
				else begin
					Matrix_B[i] <= Matrix_B[i];
				end
			end
		end
	end
endgenerate

//-------------------------------------
//			SEND to HANDSHAKE
//-------------------------------------
always @ * begin
	send_cnt_comb = send_cnt;
	if(state == WAIT_SENDING) begin
		if(out_idle) begin
			send_cnt_comb = send_cnt + 'd1;
		end
	end
	else if(state == IDLE) begin
		send_cnt_comb = 'd0;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		send_cnt <= 'd0;
	end
	else begin
		send_cnt <= send_cnt_comb;
	end
end

always @ * begin
	case(send_cnt)
		'd0 : cur_send_data = {Matrix_B[1],  Matrix_B[0]};
		'd1 : cur_send_data = {Matrix_B[3],  Matrix_B[2]};
		'd2 : cur_send_data = {Matrix_B[5],  Matrix_B[4]};
		'd3 : cur_send_data = {Matrix_B[7],  Matrix_B[6]};
		'd4 : cur_send_data = {Matrix_B[9],  Matrix_B[8]};
		'd5 : cur_send_data = {Matrix_B[11], Matrix_B[10]};
		'd6 : cur_send_data = {Matrix_B[13], Matrix_B[12]};
		'd7 : cur_send_data = {Matrix_B[15], Matrix_B[14]};
		'd8 : cur_send_data =  {Matrix_A[1],  Matrix_A[0]};
		'd9 : cur_send_data =  {Matrix_A[3],  Matrix_A[2]};
		'd10 : cur_send_data = {Matrix_A[5],  Matrix_A[4]};
		'd11 : cur_send_data = {Matrix_A[7],  Matrix_A[6]};
		'd12 : cur_send_data = {Matrix_A[9],  Matrix_A[8]};
		'd13 : cur_send_data = {Matrix_A[11], Matrix_A[10]};
		'd14 : cur_send_data = {Matrix_A[13], Matrix_A[12]};
		'd15 : cur_send_data = {Matrix_A[15], Matrix_A[14]};
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		handshake_din <= 'd0;
	end
	else begin
		if((state == SEND_HANDSHAKE) && out_idle) begin
			handshake_din <= cur_send_data;
		end
		else begin
			handshake_din <= handshake_din	;
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		handshake_sready <= 'd0;
	end
	else begin
		if(state == SEND_HANDSHAKE && out_idle) begin
			handshake_sready <= 'd1;
		end
		else begin
			handshake_sready <= 'd0;
		end
	end
end

//-------------------------------------
//			RECEIVE from FIFO
//-------------------------------------
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		fifo_rinc_reg <= 'd0;
	end
	else begin
		if(receive_state == SEND_REQUEST) begin
			fifo_rinc_reg <= 'd1;
		end
		else begin
			fifo_rinc_reg <= 'd0;
		end
	end
end

assign fifo_rinc = (fifo_rinc_reg && !fifo_empty);

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		receive_fifo_delay <= 'd0;
	end
	else begin
		receive_fifo_delay <= (receive_state == RECEIVE_FIFO && !fifo_empty);
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid <= 'd0;
	end
	else begin
		if(receive_fifo_delay) begin
			out_valid <= 'd1;
		end
		else begin
			out_valid <= 'd0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_matrix <= 'd0;
	end
	else begin
		if(receive_fifo_delay) begin
			out_matrix <= fifo_rdata;
		end
		else begin
			out_matrix <= 'd0;
		end
	end
end
endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    fifo_full,
    in_matrix,
    out_valid,
    out_matrix,
    busy,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

input clk;
input rst_n;
input in_valid;
input fifo_full;
input [7:0] in_matrix;
output reg out_valid;
output reg [7:0] out_matrix;
output reg busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;

//-------------------------------------
//		Registers and Wires
//-------------------------------------
reg [2:0] state, state_comb;
reg [3:0] B[15:0];
reg [3:0] A[1:0];
reg [3:0] receive_cnt;

reg [4:0] calc_cnt;
reg [2:0] A_row_cnt;
reg [3:0] mult_in[1:0];
reg [7:0] mult_out;
reg clean;
reg full_delay, full_delay2;
reg [7:0] full_store;
//-------------------------------------
//			PARAMETERS
//-------------------------------------
parameter IDLE = 0;
parameter STORE_B = 1;
parameter RECEIVE_A = 2;
parameter CALC = 3;
parameter WAIT_FULL = 4;
parameter FIFO_PROC = 5;
parameter FOR_TEST = 6;
genvar i,j;
integer z;
//-------------------------------------
//				FSM
//-------------------------------------
always @ * begin
	case(state) // synopsys full_case
		IDLE	:	begin
						if(in_valid) 						state_comb = STORE_B;
						else								state_comb = IDLE;
					end	
		STORE_B	:	begin	
						if(receive_cnt == 'd8)				state_comb = RECEIVE_A;
						else								state_comb = STORE_B;
					end			
		RECEIVE_A:	begin			
						if(in_valid && !fifo_full)			state_comb = CALC;
						else								state_comb = RECEIVE_A;
					end
		CALC	:	state_comb = FIFO_PROC;
		FIFO_PROC:	state_comb = WAIT_FULL;
		WAIT_FULL:	begin	
						if(!fifo_full) begin
							if(calc_cnt == 'd0) begin
								if(A_row_cnt == 'd0)		state_comb = IDLE;
								else						state_comb = RECEIVE_A;
							end
							else							state_comb = CALC;
						end
						else								state_comb = WAIT_FULL;
					end
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state <= IDLE;
	end
	else begin
		state <= state_comb;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		busy <= 'd0;
	end
	else begin
		if(state == CALC || state == WAIT_FULL || state == FIFO_PROC) begin
			busy <= 'd1;
		end
		else begin
			busy <= 'd0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		full_delay <= 'd0;
	end
	else begin
		full_delay <= fifo_full;
	end
end
//-------------------------------------
//				Store B
//-------------------------------------
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		receive_cnt <= 'd0;
	end
	else begin
		if(in_valid) begin
			receive_cnt <= receive_cnt + 'd1;
		end
		else if(state == IDLE) begin
			receive_cnt <= 'd0;
		end
		else begin
			receive_cnt <= receive_cnt;
		end
	end
end

generate
	for(i=0;i<8;i=i+1) begin : B_assignment_even
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				B[2*i] <= 'd0;
			end
			else begin
				if(state == STORE_B || state == IDLE) begin
					if(receive_cnt == i) begin
						B[2*i] <= in_matrix[3:0];
					end
					else begin
						B[2*i] <= B[2*i];
					end
				end
				else begin
					B[2*i] <= B[2*i];
				end
			end
		end
	end
	for(i=0;i<8;i=i+1) begin : B_assignment_odd
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				B[2*i+1] <= 'd0;
			end
			else begin
				if(state == STORE_B || state == IDLE) begin
					if(receive_cnt == i) begin
						B[2*i+1] <= in_matrix[7:4];
					end
					else begin
						B[2*i+1] <= B[2*i+1];
					end
				end
				else begin
					B[2*i+1] <= B[2*i+1];
				end
			end
		end
	end
endgenerate

//-------------------------------------
//			Calculation
//-------------------------------------
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		A[0] <= 'd0;
		A[1] <= 'd0;
	end
	else begin
		if(state == RECEIVE_A) begin
			if(in_valid) begin
				A[0] <= in_matrix[3:0];
				A[1] <= in_matrix[7:4];
			end
			else begin
				A[0] <= A[0];
				A[1] <= A[1];
			end
		end
		else begin
			A[0] <= A[0];
			A[1] <= A[1];
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		calc_cnt <= 'd0;
	end
	else begin
		if(state == CALC) begin
			calc_cnt <= calc_cnt + 'd1;
		end
		else if(state == WAIT_FULL || state == FIFO_PROC) begin
			calc_cnt <= calc_cnt;
		end
		else begin
			calc_cnt <= 'd0;
		end
	end
end

always @ * begin
	case(calc_cnt[3:0])
		'd0 :  mult_in[1] = B[0 ];
		'd1 :  mult_in[1] = B[1 ];
		'd2 :  mult_in[1] = B[2 ];
		'd3 :  mult_in[1] = B[3 ];
		'd4 :  mult_in[1] = B[4 ];
		'd5 :  mult_in[1] = B[5 ];
		'd6 :  mult_in[1] = B[6 ];
		'd7 :  mult_in[1] = B[7 ];
		'd8 :  mult_in[1] = B[8 ];
		'd9 :  mult_in[1] = B[9 ];
		'd10 : mult_in[1] = B[10];
		'd11 : mult_in[1] = B[11];
		'd12 : mult_in[1] = B[12];
		'd13 : mult_in[1] = B[13];
		'd14 : mult_in[1] = B[14];
		'd15 : mult_in[1] = B[15];
	endcase
	if(calc_cnt[4]) begin
		mult_in[0] = A[1];
	end
	else begin
		mult_in[0] = A[0];
	end
end

always @ * begin
	mult_out = mult_in[0] * mult_in[1];
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_matrix <= 'd0;
	end
	else begin
		if(state == CALC && !fifo_full) begin
			out_matrix <= mult_out;
		end
		else begin
			out_matrix <= 'd0;
		end
	end
end

reg out_valid_reg;

assign out_valid = (out_valid_reg && !fifo_full);

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid_reg <= 'd0;
	end
	else begin
		if(state == CALC && !fifo_full) begin
			out_valid_reg <= 'd1;
		end
		else begin
			out_valid_reg <= 'd0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		A_row_cnt <= 'd0;
	end
	else begin
		if(state == RECEIVE_A) begin
			if(in_valid) begin
				A_row_cnt <= A_row_cnt + 'd1;
			end
			else begin
				A_row_cnt <= A_row_cnt;
			end
		end
		else begin
			A_row_cnt <= A_row_cnt;
		end
	end
end

endmodule