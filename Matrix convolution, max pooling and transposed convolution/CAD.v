module CAD(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    mode,
    matrix_size,
    matrix,
    matrix_idx,
    // output signals
    out_valid,
    out_value
    );

input [1:0] matrix_size;
input clk;
input [7:0] matrix;
input rst_n;
input [3:0] matrix_idx;
input in_valid2;

input mode;
input in_valid;
output reg out_valid;
output reg out_value;


//=======================================================
//                   Reg/Wire
//=======================================================
reg [2:0] count_5;
reg [1:0] count_4;
reg [2:0] count_8;
reg [4:0] count_25;
reg [4:0] count_28;
reg [4:0] count_32;
reg [5:0] block_count;
reg [3:0] shift_window_count;
reg [5:0] shift_window_count2;
reg [5:0] row_count;
reg [8:0] addr_count[4:0];
reg [15:0] state_count,state_count_comb;
reg [3:0] idx_count;
reg [4:0] pattern_count;
reg [9:0] matrix_size_store;
reg [24:0] Kernel_store[24:0];
reg [3:0] id[1:0]; // 0: matrix id, 1: kernel id

reg [2:0] interval, interval2, interval3;

reg Img_write_en[4:0];
wire Img_read_en[4:0];
wire [13:0] Img_SRAM_address;
reg [63:0] Img_SRAM_DATA_out[4:0];
reg [63:0] Img_SRAM_DATA_in;

reg Ker_write_en_1,Ker_write_en_2;
wire Ker_read_en_1, Ker_read_en_2;
reg [95:0] Ker_SRAM_DATA_in1;
reg [103:0] Ker_SRAM_DATA_in2;
reg [95:0] Ker_SRAM_DATA_out1;
reg [103:0] Ker_SRAM_DATA_out2;
reg [3:0] Kernel_addr;

reg [2:0] state, state_comb;

reg [7:0] img_buffer[12:0];
reg [15:0] read_cycles, write_cycles, write_cycles2;

reg [13:0] Img_Sram_Addr_in[4:0];
reg [19:0] output_buffer;
reg signed [19:0] pooling_members[3:0];
reg signed[19:0] pooling_tmp,pooling_tmp2;
reg signed [19:0] pooling_output;

reg [18:0] out_store;

reg signed [7:0] mult_in[24:0][1:0];
reg signed [15:0]mult_out[24:0];
reg signed [15:0]mult_store[24:0];

reg signed [19:0]add_in[23:0][1:0];
reg signed [19:0]add_out[23:0];



reg [7:0] Img_ready[4:0][5:0], Img_ready_comb[4:0][5:0];
reg [7:0] row_6[5:0], row_6_comb[5:0]; 
reg [7:0] Img_SRAM_Data_split[4:0][7:0];
reg [9:0] start_addr_img1, start_addr_img2, start_addr_ker;
reg [8:0] Img_addr_read[4:0], Img_addr_read_comb[4:0];
reg [7:0] Kernel_SRAM_Data_split[24:0];
reg [5:0] deconv_row_end;
reg [7:0] deconv_transfer[4:0][7:0];

reg in_valid_delay;
reg in_valid2_delay;
reg [1:0] row_end;

genvar i;
genvar j;
//=======================================================
//                     FSM
//=======================================================
parameter IDLE = 0;
parameter READ_1 = 1;
parameter READ_2 = 2;
parameter WAIT = 3;
parameter CONV = 4;
parameter DECONV = 5;

always @ * begin
	case(state) //synopsys full_case
		IDLE : 	begin
					if(in_valid) 	state_comb = READ_1;
					else			state_comb = IDLE;
				end
		READ_1: begin
					if(state_count >= read_cycles) 		state_comb = READ_2;
					else								state_comb = READ_1;
				end
		READ_2: begin
					if(state_count >= 'd399)			state_comb = WAIT;
					else								state_comb = READ_2;
				end
		WAIT  : begin
					if(in_valid2)
						if(mode)						state_comb = DECONV;
						else							state_comb = CONV;
					else								state_comb = WAIT;
				end
		CONV  : begin
					if(state_count >= write_cycles && count_28 == 'd25) begin
						if(pattern_count == 'd16) 	state_comb = IDLE;
						else						state_comb = WAIT;
					end
					else							state_comb = CONV;
				end
		DECONV: begin
					if(state_count >= write_cycles2 && count_28 == 'd21) begin
						if(pattern_count == 'd16)	state_comb = IDLE;
						else						state_comb = WAIT;
					end
					else							state_comb = DECONV;
				end
	endcase
end

	

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	state <= 'd0;
	else		state <= state_comb;
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state_count <= 'd0;
	end
	else begin
		if(in_valid_delay) begin
			if(state_count == read_cycles && state == READ_1)
				state_count <= 'd0;
			else
				state_count <= state_count + 'd1;
		end
		else if(state == CONV) begin
			if(count_28 == 'd16)
				state_count <= state_count + 'd1;
			else	
				state_count <= state_count;
		end
		else if(state == DECONV) begin
			if(count_28 == 'd12)
				state_count <= state_count + 'd1;
			else
				state_count <= state_count;
		end
		else	
			state_count <= 'd0;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) pattern_count <= 'd0;
	else begin
		if(state == WAIT) begin
			if(in_valid2)
				pattern_count <= pattern_count + 'd1;
			else 
				pattern_count <= pattern_count;
		end
		else if(state == CONV || state == DECONV) begin
			pattern_count <= pattern_count;
		end
		else begin
			pattern_count <= 'd0;
		end
	end
end

always @ * begin
	case(matrix_size_store) // synopsys full_case
		'd7 : deconv_row_end = 'd8;
		'd15: deconv_row_end = 'd16;
		'd31: deconv_row_end = 'd32;
	endcase
	case(matrix_size_store) // synopsys full_case
		'd7 : read_cycles = 'd1023;
		'd15: read_cycles = 'd4095;
		'd31: read_cycles = 'd16383;
	endcase
	case(matrix_size_store) // synopsys full_case
		'd7 : write_cycles = 'd4;
		'd15: write_cycles = 'd36;
		'd31: write_cycles = 'd196;
	endcase
	case(matrix_size_store) // synopsys full_case
		'd7 : write_cycles2 = 'd144;
		'd15: write_cycles2 = 'd400;
		'd31: write_cycles2 = 'd1296;
	endcase
	case(matrix_size_store) // synopsys full_case
		'd7 :	begin
					case(matrix_idx)
						'd0 : start_addr_img1 = 'd0;
						'd1 : start_addr_img1 = 'd2;
						'd2 : start_addr_img1 = 'd4;
						'd3 : start_addr_img1 = 'd6;
						'd4 : start_addr_img1 = 'd8;
						'd5 : start_addr_img1 = 'd10;
						'd6 : start_addr_img1 = 'd12;
						'd7 : start_addr_img1 = 'd14;
						'd8 : start_addr_img1 = 'd16;
						'd9 : start_addr_img1 = 'd18;
						'd10 : start_addr_img1 = 'd20;
						'd11 : start_addr_img1 = 'd22;
						'd12 : start_addr_img1 = 'd24;
						'd13 : start_addr_img1 = 'd26;
						'd14 : start_addr_img1 = 'd28;
						'd15 : start_addr_img1 = 'd30;
					endcase
				end
		'd15:	begin
					case(matrix_idx)
						'd0 : start_addr_img1 = 'd0;
						'd1 : start_addr_img1 = 'd8;
						'd2 : start_addr_img1 = 'd16;
						'd3 : start_addr_img1 = 'd24;
						'd4 : start_addr_img1 = 'd32;
						'd5 : start_addr_img1 = 'd40;
						'd6 : start_addr_img1 = 'd48;
						'd7 : start_addr_img1 = 'd56;
						'd8 : start_addr_img1 = 'd64;
						'd9 : start_addr_img1 = 'd72;
						'd10 : start_addr_img1 = 'd80;
						'd11 : start_addr_img1 = 'd88;
						'd12 : start_addr_img1 = 'd96;
						'd13 : start_addr_img1 = 'd104;
						'd14 : start_addr_img1 = 'd112;
						'd15 : start_addr_img1 = 'd120;
					endcase
				end
		'd31:	begin
					case(matrix_idx)
						'd0 : start_addr_img1 = 'd0;
						'd1 : start_addr_img1 = 'd28;
						'd2 : start_addr_img1 = 'd56;
						'd3 : start_addr_img1 = 'd84;
						'd4 : start_addr_img1 = 'd112;
						'd5 : start_addr_img1 = 'd140;
						'd6 : start_addr_img1 = 'd168;
						'd7 : start_addr_img1 = 'd196;
						'd8 : start_addr_img1 = 'd224;
						'd9 : start_addr_img1 = 'd252;
						'd10 : start_addr_img1 = 'd280;
						'd11 : start_addr_img1 = 'd308;
						'd12 : start_addr_img1 = 'd336;
						'd13 : start_addr_img1 = 'd364;
						'd14 : start_addr_img1 = 'd392;
						'd15 : start_addr_img1 = 'd420;
					endcase
				end
	endcase
	case(matrix_size_store) // synopsys full_case
		'd7 :	begin
					case(matrix_idx)
						'd0 : start_addr_img2 = 'd0;
						'd1 : start_addr_img2 = 'd1;
						'd2 : start_addr_img2 = 'd2;
						'd3 : start_addr_img2 = 'd3;
						'd4 : start_addr_img2 = 'd4;
						'd5 : start_addr_img2 = 'd5;
						'd6 : start_addr_img2 = 'd6;
						'd7 : start_addr_img2 = 'd7; 
						'd8 : start_addr_img2 = 'd8; 
						'd9 : start_addr_img2 = 'd9; 
						'd10 : start_addr_img2 = 'd10;
						'd11 : start_addr_img2 = 'd11;
						'd12 : start_addr_img2 = 'd12;
						'd13 : start_addr_img2 = 'd13;
						'd14 : start_addr_img2 = 'd14;
						'd15 : start_addr_img2 = 'd15;
					endcase
				end
		'd15:	begin
					case(matrix_idx)
						'd0 : start_addr_img2 = 'd0;
						'd1 : start_addr_img2 = 'd6;
						'd2 : start_addr_img2 = 'd12;
						'd3 : start_addr_img2 = 'd18;
						'd4 : start_addr_img2 = 'd24;
						'd5 : start_addr_img2 = 'd30;
						'd6 : start_addr_img2 = 'd36;
						'd7 : start_addr_img2 = 'd42;
						'd8 : start_addr_img2 = 'd48;
						'd9 : start_addr_img2 = 'd54;
						'd10 : start_addr_img2 = 'd60;
						'd11 : start_addr_img2 = 'd66;
						'd12 : start_addr_img2 = 'd72;
						'd13 : start_addr_img2 = 'd78;
						'd14 : start_addr_img2 = 'd84;
						'd15 : start_addr_img2 = 'd90;
					endcase
				end
		'd31:	begin
					case(matrix_idx)
						'd0 : start_addr_img2 = 'd0;
						'd1 : start_addr_img2 = 'd24;
						'd2 : start_addr_img2 = 'd48;
						'd3 : start_addr_img2 = 'd72;
						'd4 : start_addr_img2 = 'd96;
						'd5 : start_addr_img2 = 'd120;
						'd6 : start_addr_img2 = 'd144;
						'd7 : start_addr_img2 = 'd168;
						'd8 : start_addr_img2 = 'd192;
						'd9 : start_addr_img2 = 'd216;
						'd10 : start_addr_img2 = 'd240;
						'd11 : start_addr_img2 = 'd264;
						'd12 : start_addr_img2 = 'd288;
						'd13 : start_addr_img2 = 'd312;
						'd14 : start_addr_img2 = 'd336;
						'd15 : start_addr_img2 = 'd360;
					endcase
				end
	endcase
end
//=======================================================
//					Img Buffer
//=======================================================
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	in_valid_delay <= 'd0;
	else begin
		in_valid_delay <= in_valid;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	in_valid2_delay <= 'd0;
	else begin
		in_valid2_delay <= in_valid2;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	img_buffer[0] <= 'd0;
	else begin
		if(in_valid) begin
			img_buffer[0] <= matrix;
		end
		else	img_buffer[0] <= 'd0;
	end
end
generate
for(i=1;i<13;i=i+1) begin: a
	always @ (posedge clk or negedge rst_n) begin
		if(!rst_n)	img_buffer[i] <= 'd0;
		else begin
			if(in_valid) begin
				img_buffer[i] <= img_buffer[i-1];
			end
			else	img_buffer[i] <= 'd0;
		end
	end
end
endgenerate

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		id[0] <= 'd0;
		id[1] <= 'd0;
	end
	else begin
		if(in_valid2 & !in_valid2_delay) begin
			id[0] <= matrix_idx;
			id[1] <= id[1];
		end
		else if(in_valid2_delay & in_valid2) begin
			id[0] <= id[0];
			id[1] <= matrix_idx;
		end
		else begin
			id[0] <= id[0];
			id[1] <= id[1];
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	matrix_size_store <= 'd7;
	else begin
		if(state == IDLE & in_valid) begin
			case(matrix_size) // synopsys full_case
				'd0 : 	matrix_size_store <= 'd7;
				'd1 : 	matrix_size_store <= 'd15;
				'd2 : 	matrix_size_store <= 'd31;
			endcase
		end
		else			matrix_size_store <= matrix_size_store;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		row_count <= 'd0;
	end
	else begin
		if(state == DECONV) begin
			if(matrix_size_store == 'd7) begin
				if(block_count == 'd11 && count_28 == 'd22) begin
					row_count <= row_count + 'd1;
				end
			end
			else if(matrix_size_store == 'd15) begin
				if(block_count == 'd19 && count_28 == 'd22) begin
					row_count <= row_count + 'd1;
				end
			end
			else if(matrix_size_store == 'd31) begin
				if(block_count == 'd35 && count_28 == 'd22) begin
					row_count <= row_count + 'd1;
				end
			end
			else begin
				row_count <= row_count;
			end
		end
		else	row_count <= 'd0;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		block_count <= 'd0;
	end
	else begin
		if(state == DECONV) begin
			if(count_28 == 'd5) begin
				if(block_count == 'd35) begin
					block_count <= 'd0;
				end
				else if(matrix_size_store == 'd15 && block_count == 'd19) begin
					block_count <= 'd0;
				end
				else if(matrix_size_store == 'd7 && block_count == 'd11) begin
					block_count <= 'd0;
				end
				else begin
					block_count <= block_count + 'd1;
				end
			end
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		count_32 <= 'd0;
	end
	else begin
		if(in_valid_delay) begin
			if(count_4 == row_end && count_8 == 'd7) begin
				if(count_32 == matrix_size_store)
					count_32 <= 'd0;
				else
					count_32 <= count_32 + 'd1;
			end
			else
				count_32 <= count_32;
		end
		else	count_32 <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		count_25 <= 'd0;
	end
	else begin
		if(state == READ_2) begin
			if(count_25 == 'd24)
				count_25 <= 'd0;
			else
				count_25 <= count_25 + 'd1;
		end
		else	count_25 <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		count_28 <= 'd0;
	end
	else begin
		if(state == CONV) begin
			if(count_28 == 'd26)
				count_28 <= 'd7;
			else
				count_28 <= count_28 + 'd1;
		end
		else if(state == DECONV) begin
			if(count_28 == 'd22) begin
				count_28 <= 'd3;
			end
			else begin
				count_28 <= count_28 + 'd1;
			end
		end
		else	count_28 <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		idx_count <= 'd0;
	end
	else begin
		if(state == READ_2) begin
			if(count_25 == 'd24)
				idx_count <= idx_count + 'd1;
			else
				idx_count <= idx_count;
		end
		else	idx_count <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		count_8 <= 'd0;
	end
	else begin
		if(in_valid_delay) 
			count_8 <= count_8 + 'd1;
		else	
			count_8 <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		count_4 <= 'd0;
	end
	else begin
		if(in_valid_delay) begin
			if(count_8 == 'd7)
				case(matrix_size_store) // synopsys full_case
					'd7 : 	count_4 <= 'd0; 
					'd15: 	begin
								if(count_4 == 'd1)
									count_4 <= 'd0;
								else
									count_4 <= count_4 + 'd1;
							end
					'd31:	begin
								count_4 <= count_4 + 'd1;
							end
				endcase
			else begin
				count_4 <= count_4;
			end
		end
		else	
			count_4 <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)
		shift_window_count <= 'd0;
	else begin
		if(state == CONV) begin
			if(count_28 == 'd17) begin
				if(matrix_size_store == 'd7 && shift_window_count == 'd1)
					shift_window_count <= 'd0;
				else if((matrix_size_store == 'd15) && (shift_window_count == 'd5))
					shift_window_count <= 'd0;
				else if(matrix_size_store == 'd31 && shift_window_count == 'd5) begin
					if(shift_window_count2 == 'd0)
						shift_window_count <= 'd0;
					else
						shift_window_count <= 'd2;
				end
				else 
					shift_window_count <= shift_window_count + 'd1;
			end
			else
				shift_window_count <= shift_window_count;
		end
		else
			shift_window_count <= 'd0;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		shift_window_count2 <= 'd0;
	end
	else begin
		if(state == CONV) begin
			if(count_28 == 'd10) begin
				if((shift_window_count2 == 'd5 && matrix_size_store == 'd15) || (shift_window_count2 == 'd13 && matrix_size_store == 'd31)) begin
					shift_window_count2 <= 'd0;
				end
				else begin
					shift_window_count2 <= shift_window_count2 + 'd1;
				end
			end
			else begin
				shift_window_count2 <= shift_window_count2;
			end
		end
		else begin
			shift_window_count2 <= 'd0;
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		count_5 <= 'd0;
	end
	else begin
		if(in_valid_delay) begin
			if(count_4 == row_end && count_8 == 'd7)
				if(count_5 == 'd4)
					count_5 <= 'd0;
				else if(count_32 == matrix_size_store)
					count_5 <= 'd0;
				else
					count_5 <= count_5 + 'd1;
			else
				count_5 <= count_5;
		end
		else if(state == CONV) begin
			if((count_28 == 'd15) && ((shift_window_count2 == 'd0 && matrix_size_store == 'd15) || (shift_window_count2 == 'd0 && matrix_size_store == 'd31) || (shift_window_count == 'd1 && matrix_size_store == 'd7))) begin
				if(count_5 == 'd4) begin
					count_5 <= 'd1;
				end
				else if(count_5 == 'd3) begin
					count_5 <= 'd0;
				end
				else begin
					count_5 <= count_5 + 'd2;
				end
			end
			else begin
				count_5 <= count_5;
			end
		end
		else if(state == DECONV) begin
			if(count_28 == 'd11 && ((block_count == 'd11 && matrix_size_store == 'd7) || (block_count == 'd19 && matrix_size_store == 'd15) || (block_count == 'd35 && matrix_size_store == 'd31))) begin
				if(row_count == 'd0 || row_count == 'd1 || row_count == 'd2 || row_count == 'd3 || row_count == (deconv_row_end-'d1) ||  row_count == deconv_row_end || row_count == (deconv_row_end + 'd1) || row_count == (deconv_row_end + 'd2) || row_count == (deconv_row_end + 'd3)) begin
					count_5 <= count_5;
				end
				else if(count_5 == 'd4) begin
					count_5 <= 'd0;
				end
				else begin
					count_5 <= count_5 + 'd1;
				end
			end
			else begin
				count_5 <= count_5;
			end
		end
		else	
			count_5 <= 'd0;
	end
end
always @ * begin
	if(matrix_size_store == 'd31)
		row_end = 'd3;
	else if(matrix_size_store == 'd7)
		row_end = 'd0;
	else
		row_end = 'd1;
end
generate
for(i=0;i<5;i=i+1) begin: b
	always @ (posedge clk or negedge rst_n) begin
		if(!rst_n)	addr_count[i] <= 'd0;
		else begin
			if(state == READ_1) begin
				if(count_5 == i && count_8 == 'd7)
					addr_count[i] <= addr_count[i] + 'd1;
				else
					addr_count[i] <= addr_count[i];
			end
			else
				addr_count[i] <= 'd0;
		end
	end
end
endgenerate

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid <= 'd0;
	else begin
		if(state == CONV && (count_28 >= 'd6))
			out_valid <= 'd1;
		else if(state == DECONV && (count_28 >= 'd2))
			out_valid <= 'd1;
		else
			out_valid <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) out_value <= 'd0;
	else begin
		if((state == CONV && (count_28 == 'd6 || count_28 == 'd26))) begin
			if(state_count < write_cycles) begin
				out_value <= pooling_output[0];
			end
			else begin
				out_value <= 'd0;
			end
		end
		else if(state == CONV && count_28 > 'd6) begin
			out_value <= out_store[0];
		end
		else if((state == DECONV) && (count_28 == 'd2 || count_28 == 'd22)) begin
			if(state_count < write_cycles2) begin
				out_value <= add_out[23][0];
			end
			else begin
				out_value <= 'd0;
			end
		end
		else if(state == DECONV && count_28 > 'd2) begin
			out_value <= out_store[0];
		end
		else begin
			out_value <= 'd0;
		end
	end
end
//=======================================================
//                    SRAM
//=======================================================
always @ * begin
Img_addr_read_comb[0] = Img_addr_read[0];
Img_addr_read_comb[1] = Img_addr_read[1];
Img_addr_read_comb[2] = Img_addr_read[2];
Img_addr_read_comb[3] = Img_addr_read[3];
Img_addr_read_comb[4] = Img_addr_read[4];
Img_Sram_Addr_in[0] = Img_addr_read[0];
Img_Sram_Addr_in[1] = Img_addr_read[1];
Img_Sram_Addr_in[2] = Img_addr_read[2];
Img_Sram_Addr_in[3] = Img_addr_read[3];
Img_Sram_Addr_in[4] = Img_addr_read[4];
	if(state == CONV) begin
		if(count_28 == 'd14 && (shift_window_count == 'd1 || (shift_window_count == 'd5 && !(((matrix_size_store == 'd15 && shift_window_count2 == 'd0) || (matrix_size_store == 'd31 && shift_window_count2 == 'd0))  && count_5 != 'd0 && count_5 != 'd4)))) begin
			Img_addr_read_comb[0] = Img_addr_read[0] + 'd1;
		end
		if(count_28 == 'd14 && (shift_window_count == 'd1 || (shift_window_count == 'd5 && !(((matrix_size_store == 'd15 && shift_window_count2 == 'd0) || (matrix_size_store == 'd31 && shift_window_count2 == 'd0))  && count_5 != 'd1 && count_5 != 'd0)))) begin
			Img_addr_read_comb[1] = Img_addr_read[1] + 'd1;
		end
		if((count_28 == 'd14) && (shift_window_count == 'd1 || (shift_window_count == 'd5 && !(((matrix_size_store == 'd15 && shift_window_count2 == 'd0) || (matrix_size_store == 'd31 && shift_window_count2 == 'd0))&& count_5 != 'd2 && count_5 != 'd1)))) begin
			if(matrix_size_store != 'd7)
				Img_addr_read_comb[2] = Img_addr_read[2] + 'd1;
		end
		if((count_28 == 'd14) && (shift_window_count == 'd1 || (shift_window_count == 'd5 && !(((matrix_size_store == 'd15 && shift_window_count2 == 'd0) || (matrix_size_store == 'd31 && shift_window_count2 == 'd0))&& count_5 != 'd3 && count_5 != 'd2)))) begin
			if(matrix_size_store != 'd7)
				Img_addr_read_comb[3] = Img_addr_read[3] + 'd1;
		end
		if((count_28 == 'd14) && (shift_window_count == 'd1 || (shift_window_count == 'd5 && !(((matrix_size_store == 'd15 && shift_window_count2 == 'd0) || (matrix_size_store == 'd31 && shift_window_count2 == 'd0))&& count_5 != 'd4 && count_5 != 'd3)))) begin
			if(matrix_size_store != 'd7)
				Img_addr_read_comb[4] = Img_addr_read[4] + 'd1;
		end
	end
	else if(state == DECONV) begin
		if(count_28 == 'd10 && (block_count == 'd8 || block_count == 'd16 || block_count == 'd24 || block_count == 'd32)) begin
			if(matrix_size_store == 'd7) begin
				if(!(row_count == 'd0 || row_count == 'd1 || row_count == 'd2 || row_count == 'd3 || row_count == (deconv_row_end-1) || row_count == deconv_row_end || row_count == (deconv_row_end + 'd1) || row_count == (deconv_row_end + 'd2) || row_count == (deconv_row_end + 'd3))) begin	
					Img_addr_read_comb[0] = Img_addr_read[0] + 'd1;
					Img_addr_read_comb[1] = Img_addr_read[1] + 'd1;
					Img_addr_read_comb[2] = Img_addr_read[2] + 'd1;
					Img_addr_read_comb[3] = Img_addr_read[3] + 'd1;
					Img_addr_read_comb[4] = Img_addr_read[4] + 'd1;
				end
			end
			else if(matrix_size_store == 'd15 || matrix_size_store == 'd31) begin
				Img_addr_read_comb[0] = Img_addr_read[0] + 'd1;
				Img_addr_read_comb[1] = Img_addr_read[1] + 'd1;
				Img_addr_read_comb[2] = Img_addr_read[2] + 'd1;
				Img_addr_read_comb[3] = Img_addr_read[3] + 'd1;
				Img_addr_read_comb[4] = Img_addr_read[4] + 'd1;
			end
		end
	end
		
	
	case(matrix_size_store) // synopsys full_case
		'd7 : interval = 'd1;
		'd15: interval = 'd2;
		'd31: interval = 'd4;
	endcase
	case(matrix_size_store) // synopsys full_case
		'd7 : interval2 = 'd0;
		'd15: interval2 = 'd1;
		'd31: interval2 = 'd3;
	endcase
	case(matrix_size_store) // synopsys full_case
		'd7 : interval3 = 'd1;
		'd15: interval3 = 'd2;
		'd31: interval3 = 'd4;
	endcase
	if(state == CONV && (count_28 == 'd14) && ((matrix_size_store == 'd15 && shift_window_count2 == 'd0) || (matrix_size_store == 'd31 && shift_window_count2 == 'd0))) begin
		if(count_5 != 'd0 && count_5 != 'd4)
			Img_addr_read_comb[0] = Img_addr_read_comb[0] - interval2;
		if(count_5 != 'd1 && count_5 != 'd0)
			Img_addr_read_comb[1] = Img_addr_read_comb[1] - interval2;
		if(count_5 != 'd2 && count_5 != 'd1)
			Img_addr_read_comb[2] = Img_addr_read_comb[2] - interval2;
		if(count_5 != 'd3 && count_5 != 'd2)
			Img_addr_read_comb[3] = Img_addr_read_comb[3] - interval2;
		if(count_5 != 'd4 && count_5 != 'd3)
			Img_addr_read_comb[4] = Img_addr_read_comb[4] - interval2;
	end
	else if(count_28 == 'd10 && state == DECONV) begin
		if(block_count == (matrix_size_store + 'd1)) begin
			if(matrix_size_store == 'd7) begin
				if(!(row_count == 'd0 || row_count == 'd1 || row_count == 'd2 || row_count == 'd3 || row_count == (deconv_row_end-1) || row_count == deconv_row_end || row_count == (deconv_row_end + 'd1) || row_count == (deconv_row_end + 'd2) || row_count == (deconv_row_end + 'd3))) begin	
					if(count_5 != 'd0)
						Img_addr_read_comb[0] = Img_addr_read_comb[0] - interval3;
					if(count_5 != 'd1)     
						Img_addr_read_comb[1] = Img_addr_read_comb[1] - interval3;
					if(count_5 != 'd2)     
						Img_addr_read_comb[2] = Img_addr_read_comb[2] - interval3;
					if(count_5 != 'd3)     
						Img_addr_read_comb[3] = Img_addr_read_comb[3] - interval3;
					if(count_5 != 'd4)     
						Img_addr_read_comb[4] = Img_addr_read_comb[4] - interval3;
				end
			end
			else if(matrix_size_store == 'd15 || matrix_size_store == 'd31) begin
				if(count_5 != 'd0 || ((row_count == 'd0 || row_count == 'd1 || row_count == 'd2 || row_count == 'd3 || row_count == (deconv_row_end-1) || row_count == deconv_row_end || row_count == (deconv_row_end + 'd1) || row_count == (deconv_row_end + 'd2) || row_count == (deconv_row_end + 'd3))))
					Img_addr_read_comb[0] = Img_addr_read_comb[0] - interval3;
				if(count_5 != 'd1 || ((row_count == 'd0 || row_count == 'd1 || row_count == 'd2 || row_count == 'd3 || row_count == (deconv_row_end-1) || row_count == deconv_row_end || row_count == (deconv_row_end + 'd1) || row_count == (deconv_row_end + 'd2) || row_count == (deconv_row_end + 'd3))))     
					Img_addr_read_comb[1] = Img_addr_read_comb[1] - interval3;
				if(count_5 != 'd2 || ((row_count == 'd0 || row_count == 'd1 || row_count == 'd2 || row_count == 'd3 || row_count == (deconv_row_end-1) || row_count == deconv_row_end || row_count == (deconv_row_end + 'd1) || row_count == (deconv_row_end + 'd2) || row_count == (deconv_row_end + 'd3))))     
					Img_addr_read_comb[2] = Img_addr_read_comb[2] - interval3;
				if(count_5 != 'd3 || ((row_count == 'd0 || row_count == 'd1 || row_count == 'd2 || row_count == 'd3 || row_count == (deconv_row_end-1) || row_count == deconv_row_end || row_count == (deconv_row_end + 'd1) || row_count == (deconv_row_end + 'd2) || row_count == (deconv_row_end + 'd3))))     
					Img_addr_read_comb[3] = Img_addr_read_comb[3] - interval3;
				if(count_5 != 'd4 || ((row_count == 'd0 || row_count == 'd1 || row_count == 'd2 || row_count == 'd3 || row_count == (deconv_row_end-1) || row_count == deconv_row_end || row_count == (deconv_row_end + 'd1) || row_count == (deconv_row_end + 'd2) || row_count == (deconv_row_end + 'd3))))     
					Img_addr_read_comb[4] = Img_addr_read_comb[4] - interval3;
			end
		end
	end
	
	if(state == READ_1) begin
		Img_Sram_Addr_in[0] = addr_count[0];
		Img_Sram_Addr_in[1] = addr_count[1];
		Img_Sram_Addr_in[2] = addr_count[2];
		Img_Sram_Addr_in[3] = addr_count[3];
		Img_Sram_Addr_in[4] = addr_count[4];
	end
	else if(state == CONV) begin
		if(count_28 == 'd1 || count_28 == 'd20) begin
			if(count_5 == 'd0) begin
				Img_Sram_Addr_in[0] = Img_addr_read[0] + interval;
			end
			if(count_5 == 'd1) begin
				Img_Sram_Addr_in[1] = Img_addr_read[1] + interval;
			end
			if(count_5 == 'd2) begin
				Img_Sram_Addr_in[2] = Img_addr_read[2] + interval;
			end
			if(count_5 == 'd3) begin
				Img_Sram_Addr_in[3] = Img_addr_read[3] + interval;
			end
			if(count_5 == 'd4) begin
				Img_Sram_Addr_in[4] = Img_addr_read[4] + interval;
			end
		end
	end	
	else if(state == WAIT && in_valid2) begin
		Img_Sram_Addr_in[0] = start_addr_img1;
		if(matrix_size_store != 'd15)
			Img_Sram_Addr_in[1] = start_addr_img1;
		else
			Img_Sram_Addr_in[1] = start_addr_img2;
		if(matrix_size_store == 'd7)
			Img_Sram_Addr_in[2] = start_addr_img1;
		else
			Img_Sram_Addr_in[2] = start_addr_img2;
		Img_Sram_Addr_in[3] = start_addr_img2;
		Img_Sram_Addr_in[4] = start_addr_img2;
	end
	
	{Img_SRAM_Data_split[0][0], Img_SRAM_Data_split[0][1], Img_SRAM_Data_split[0][2], Img_SRAM_Data_split[0][3], Img_SRAM_Data_split[0][4], Img_SRAM_Data_split[0][5], Img_SRAM_Data_split[0][6], Img_SRAM_Data_split[0][7]} = Img_SRAM_DATA_out[0];
	{Img_SRAM_Data_split[1][0], Img_SRAM_Data_split[1][1], Img_SRAM_Data_split[1][2], Img_SRAM_Data_split[1][3], Img_SRAM_Data_split[1][4], Img_SRAM_Data_split[1][5], Img_SRAM_Data_split[1][6], Img_SRAM_Data_split[1][7]} = Img_SRAM_DATA_out[1];
	{Img_SRAM_Data_split[2][0], Img_SRAM_Data_split[2][1], Img_SRAM_Data_split[2][2], Img_SRAM_Data_split[2][3], Img_SRAM_Data_split[2][4], Img_SRAM_Data_split[2][5], Img_SRAM_Data_split[2][6], Img_SRAM_Data_split[2][7]} = Img_SRAM_DATA_out[2];
	{Img_SRAM_Data_split[3][0], Img_SRAM_Data_split[3][1], Img_SRAM_Data_split[3][2], Img_SRAM_Data_split[3][3], Img_SRAM_Data_split[3][4], Img_SRAM_Data_split[3][5], Img_SRAM_Data_split[3][6], Img_SRAM_Data_split[3][7]} = Img_SRAM_DATA_out[3];
	{Img_SRAM_Data_split[4][0], Img_SRAM_Data_split[4][1], Img_SRAM_Data_split[4][2], Img_SRAM_Data_split[4][3], Img_SRAM_Data_split[4][4], Img_SRAM_Data_split[4][5], Img_SRAM_Data_split[4][6], Img_SRAM_Data_split[4][7]} = Img_SRAM_DATA_out[4]; 

	{Kernel_SRAM_Data_split[0], Kernel_SRAM_Data_split[1], Kernel_SRAM_Data_split[2], Kernel_SRAM_Data_split[3], Kernel_SRAM_Data_split[4], Kernel_SRAM_Data_split[5], Kernel_SRAM_Data_split[6], Kernel_SRAM_Data_split[7], Kernel_SRAM_Data_split[8], Kernel_SRAM_Data_split[9], Kernel_SRAM_Data_split[10], Kernel_SRAM_Data_split[11]} = Ker_SRAM_DATA_out1;
	 
	{Kernel_SRAM_Data_split[12], Kernel_SRAM_Data_split[13], Kernel_SRAM_Data_split[14], Kernel_SRAM_Data_split[15], Kernel_SRAM_Data_split[16], Kernel_SRAM_Data_split[17], Kernel_SRAM_Data_split[18], Kernel_SRAM_Data_split[19], Kernel_SRAM_Data_split[20], Kernel_SRAM_Data_split[21], Kernel_SRAM_Data_split[22], Kernel_SRAM_Data_split[23], Kernel_SRAM_Data_split[24]} = Ker_SRAM_DATA_out2;
	
	if (Img_Sram_Addr_in[0] > 'd447) begin
		Img_Sram_Addr_in[0] = 'd0;
	end
	if (Img_Sram_Addr_in[1] > 'd447) begin
		Img_Sram_Addr_in[1] = 'd0;
	end
	if (Img_Sram_Addr_in[2] > 'd383) begin
		Img_Sram_Addr_in[2] = 'd0;
	end
	if (Img_Sram_Addr_in[3] > 'd383) begin
		Img_Sram_Addr_in[3] = 'd0;
	end
	if (Img_Sram_Addr_in[4] > 'd383) begin
		Img_Sram_Addr_in[4] = 'd0;
	end
end	
	
	 
	 
assign Img_read_en[0] = !Img_write_en[0] && state == CONV;
assign Img_read_en[1] = !Img_write_en[1] && state == CONV;
assign Img_read_en[2] = !Img_write_en[2] && state == CONV;
assign Img_read_en[3] = !Img_write_en[3] && state == CONV;
assign Img_read_en[4] = !Img_write_en[4] && state == CONV;
always @ * begin
Img_write_en[0] = 0;
Img_write_en[1] = 0;
Img_write_en[2] = 0;
Img_write_en[3] = 0;
Img_write_en[4] = 0;

Ker_write_en_1 = 0;
Ker_write_en_2 = 0;

	if(count_5 == 'd0 && count_8 == 'd7 && state == READ_1)	Img_write_en[0] = 1;
	if(count_5 == 'd1 && count_8 == 'd7 && state == READ_1)	Img_write_en[1] = 1;
	if(count_5 == 'd2 && count_8 == 'd7 && state == READ_1)	Img_write_en[2] = 1;
	if(count_5 == 'd3 && count_8 == 'd7 && state == READ_1)	Img_write_en[3] = 1;
	if(count_5 == 'd4 && count_8 == 'd7 && state == READ_1)	Img_write_en[4] = 1;
	
	if(state == READ_2) begin
		if(count_25 == 'd11)
			Ker_write_en_1 = 'd1;
		else if(count_25 == 'd24)
			Ker_write_en_2 = 'd1;
	end
	
	Img_SRAM_DATA_in  = {img_buffer[7], img_buffer[6], img_buffer[5], img_buffer[4], img_buffer[3], img_buffer[2], img_buffer[1], img_buffer[0]};
	Ker_SRAM_DATA_in1 = {img_buffer[11], img_buffer[10], img_buffer[9], img_buffer[8], img_buffer[7], img_buffer[6], img_buffer[5], img_buffer[4], img_buffer[3], img_buffer[2],img_buffer[1],img_buffer[0]};
	Ker_SRAM_DATA_in2 = {img_buffer[12], img_buffer[11], img_buffer[10], img_buffer[9], img_buffer[8], img_buffer[7], img_buffer[6], img_buffer[5], img_buffer[4], img_buffer[3], img_buffer[2],img_buffer[1],img_buffer[0]};
end

generate
for(i=0;i<5;i=i+1) begin : h
	for(j=0;j<6;j=j+1) begin : k
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n)	
				Img_ready[i][j] <= 'd0;
			else 
				Img_ready[i][j] <= Img_ready_comb[i][j];
		end
	end
end
endgenerate
generate
for(i=0;i<6;i=i+1) begin : l
	always @ (posedge clk or negedge rst_n) begin
		if(!rst_n)	row_6[i] <= 'd0;
		else		row_6[i] <= row_6_comb[i];
	end
end
endgenerate


always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	Img_addr_read[0] <= 'd0;
	else begin
		if(state == WAIT && in_valid2) begin
			Img_addr_read[0] <= start_addr_img1;
		end
		else if(state == CONV || state == DECONV) begin
			Img_addr_read[0] <= Img_addr_read_comb[0];
		end
		else begin
			Img_addr_read[0] <= Img_addr_read[0];
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	Img_addr_read[1] <= 'd0;
	else begin
		if(state == WAIT && in_valid2) begin
			if(matrix_size_store == 'd15) begin
				Img_addr_read[1] <= start_addr_img2;
			end
			else begin
				Img_addr_read[1] <= start_addr_img1;
			end
		end
		else if(state == CONV || state == DECONV) begin
			Img_addr_read[1] <= Img_addr_read_comb[1];
		end
		else begin
			Img_addr_read[1] <= Img_addr_read[1];
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	Img_addr_read[2] <= 'd0;
	else begin
		if(state == WAIT && in_valid2) begin
			if(matrix_size_store == 'd7) begin
				Img_addr_read[2] <= start_addr_img1;
			end
			else begin
				Img_addr_read[2] <= start_addr_img2;
			end
		end
		else if(state == CONV || state == DECONV) begin
			Img_addr_read[2] <= Img_addr_read_comb[2];
		end
		else begin
			Img_addr_read[2] <= Img_addr_read[2];
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	Img_addr_read[3] <= 'd0;
	else begin
		if(state == WAIT && in_valid2) begin
			Img_addr_read[3] <= start_addr_img2;
		end
		else if(state == CONV || state == DECONV) begin
			Img_addr_read[3] <= Img_addr_read_comb[3];
		end
		else begin
			Img_addr_read[3] <= Img_addr_read[3];
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	Img_addr_read[4] <= 'd0;
	else begin
		if(state == WAIT && in_valid2) begin
			Img_addr_read[4] <= start_addr_img2;
		end
		else if(state == CONV || state == DECONV) begin
			Img_addr_read[4] <= Img_addr_read_comb[4];
		end
		else begin
			Img_addr_read[4] <= Img_addr_read[4];
		end
	end
end
// multiplier
generate
for(i=0;i<4;i=i+1) begin: n
	for(j=0;j<5;j=j+1) begin : n2
		always @ * begin
			if(state == DECONV) begin
				mult_in[i*5+j][0] = Img_ready[i][j];
			end
			else begin
				case(count_28)
					'd1 : mult_in[i*5+j][0] = Img_ready[i][j];
					'd2 : mult_in[i*5+j][0] = Img_ready[i][j+1];
					'd3 : mult_in[i*5+j][0] = Img_ready[i+1][j];
					'd4 : mult_in[i*5+j][0] = Img_ready[i+1][j+1];
					'd20: mult_in[i*5+j][0] = Img_ready[i][j];
					'd21: mult_in[i*5+j][0] = Img_ready[i][j+1];
					'd22: mult_in[i*5+j][0] = Img_ready[i+1][j];
					'd23: mult_in[i*5+j][0] = Img_ready[i+1][j+1];
					default : mult_in[i*5+j][0] = 'd0;
				endcase
			end
		end
	end
end
endgenerate
generate
for(i=0;i<5;i=i+1) begin : o
	always @ * begin
		if(state == DECONV) begin
			mult_in[20+i][0] = Img_ready[4][i];
		end
		else begin
			case(count_28)
				'd1 : mult_in[20+i][0] = Img_ready[4][i];
				'd2 : mult_in[20+i][0] = Img_ready[4][i+1];
				'd3 : mult_in[20+i][0] = row_6[i];
				'd4 : mult_in[20+i][0] = row_6[i+1];
				'd20: mult_in[20+i][0] = Img_ready[4][i];
				'd21: mult_in[20+i][0] = Img_ready[4][i+1];
				'd22: mult_in[20+i][0] = row_6[i];
				'd23: mult_in[20+i][0] = row_6[i+1];
				default : mult_in[20+i][0] = 'd0;
			endcase
		end
	end
end
endgenerate
generate
for(i=0;i<25;i=i+1) begin : p
	always @ * begin
		if(state == CONV) begin
			mult_in[i][1] = Kernel_SRAM_Data_split[i];
		end
		else begin
			mult_in[i][1] = Kernel_SRAM_Data_split[24-i];
		end
	end
end
endgenerate
generate
for(i=0;i<25;i=i+1) begin: m
	always @ * begin
		mult_out[i] = mult_in[i][0] * mult_in[i][1]; 
	end
end
endgenerate
generate
for(i=0;i<25;i=i+1) begin : q
	always @ (posedge clk or negedge rst_n) begin
		if(!rst_n) 	mult_store[i] <= 'd0;
		else begin
			mult_store[i] <= mult_out[i];
		end
	end
end
endgenerate

// Adder
always @ * begin
	add_in[0 ][0] = mult_store[0 ];
	add_in[1 ][0] = mult_store[1 ];
	add_in[2 ][0] = mult_store[2 ];
	add_in[3 ][0] = mult_store[3 ];
	add_in[4 ][0] = mult_store[4 ];
	add_in[5 ][0] = mult_store[5 ];
	add_in[6 ][0] = mult_store[6 ];
	add_in[7 ][0] = mult_store[7 ];
	add_in[8 ][0] = mult_store[8 ];
	add_in[9 ][0] = mult_store[9 ];
	add_in[10][0] = mult_store[10];
	add_in[11][0] = mult_store[11];
	add_in[0 ][1] = mult_store[12];
	add_in[1 ][1] = mult_store[13];
	add_in[2 ][1] = mult_store[14];
	add_in[3 ][1] = mult_store[15];
	add_in[4 ][1] = mult_store[16];
	add_in[5 ][1] = mult_store[17];
	add_in[6 ][1] = mult_store[18];
	add_in[7 ][1] = mult_store[19];
	add_in[8 ][1] = mult_store[20];
	add_in[9 ][1] = mult_store[21];
	add_in[10][1] = mult_store[22];
	add_in[11][1] = mult_store[23];
	
	add_in[12][0] = add_out[0];
	add_in[12][1] = add_out[1];
	add_in[13][0] = add_out[2];
	add_in[13][1] = add_out[3];
	add_in[14][0] = add_out[4];
	add_in[14][1] = add_out[5];
	add_in[15][0] = add_out[6];
	add_in[15][1] = add_out[7];
	add_in[16][0] = add_out[8];
	add_in[16][1] = add_out[9];
	add_in[17][0] = add_out[10];
	add_in[17][1] = add_out[11];
	
	add_in[18][0] = add_out[12];
	add_in[18][1] = add_out[13];
	add_in[19][0] = add_out[14];
	add_in[19][1] = add_out[15];
	add_in[20][0] = add_out[16];
	add_in[20][1] = add_out[17];
	
	add_in[21][0] = add_out[18];
	add_in[21][1] = add_out[19];
	add_in[22][0] = add_out[20];
	add_in[22][1] = mult_store[24];
	
	add_in[23][0] = add_out[21];
	add_in[23][1] = add_out[22];

	add_out[0 ] = add_in[0 ][0] + add_in[0 ][1];
	add_out[1 ] = add_in[1 ][0] + add_in[1 ][1];
	add_out[2 ] = add_in[2 ][0] + add_in[2 ][1];
	add_out[3 ] = add_in[3 ][0] + add_in[3 ][1];
	add_out[4 ] = add_in[4 ][0] + add_in[4 ][1];
	add_out[5 ] = add_in[5 ][0] + add_in[5 ][1];
	add_out[6 ] = add_in[6 ][0] + add_in[6 ][1];
	add_out[7 ] = add_in[7 ][0] + add_in[7 ][1];
	add_out[8 ] = add_in[8 ][0] + add_in[8 ][1];
	add_out[9 ] = add_in[9 ][0] + add_in[9 ][1];
	add_out[10] = add_in[10][0] + add_in[10][1];
	add_out[11] = add_in[11][0] + add_in[11][1];
	add_out[12] = add_in[12][0] + add_in[12][1];
	add_out[13] = add_in[13][0] + add_in[13][1];
	add_out[14] = add_in[14][0] + add_in[14][1];
	add_out[15] = add_in[15][0] + add_in[15][1];
	add_out[16] = add_in[16][0] + add_in[16][1];
	add_out[17] = add_in[17][0] + add_in[17][1];
	add_out[18] = add_in[18][0] + add_in[18][1];
	add_out[19] = add_in[19][0] + add_in[19][1];
	add_out[20] = add_in[20][0] + add_in[20][1];
	add_out[21] = add_in[21][0] + add_in[21][1];
	add_out[22] = add_in[22][0] + add_in[22][1];
	add_out[23] = add_in[23][0] + add_in[23][1];
end

// pooling
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) 
		pooling_members[0] <= 'd0;
	else begin
		if(state == CONV) begin
			if(count_28 == 'd2 || count_28 == 'd21)  pooling_members[0] <= add_out[23];
			else				pooling_members[0] <= pooling_members[0];
		end
		else					pooling_members[0] <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) 
		pooling_members[1] <= 'd0;
	else begin
		if(state == CONV) begin
			if(count_28 == 'd3 || count_28 == 'd22)  pooling_members[1] <= add_out[23];
			else				pooling_members[1] <= pooling_members[1];
		end
		else					pooling_members[1] <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) 
		pooling_members[2] <= 'd0;
	else begin
		if(state == CONV) begin
			if(count_28 == 'd4 || count_28 == 'd23)  pooling_members[2] <= add_out[23];
			else				pooling_members[2] <= pooling_members[2];
		end
		else					pooling_members[2] <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) 
		pooling_members[3] <= 'd0;
	else begin
		if(state == CONV) begin
			if(count_28 == 'd5 || count_28 == 'd24)  pooling_members[3] <= add_out[23];
			else				pooling_members[3] <= pooling_members[3];
		end
		else					pooling_members[3] <= 'd0;
	end
end

always @ * begin
	if(pooling_members[0] > pooling_members[1])
		pooling_tmp = pooling_members[0];
	else
		pooling_tmp = pooling_members[1];
	if(pooling_members[2] > pooling_members[3])
		pooling_tmp2 = pooling_members[2];
	else
		pooling_tmp2 = pooling_members[3];
		
	if(pooling_tmp > pooling_tmp2)
		pooling_output = pooling_tmp;
	else
		pooling_output = pooling_tmp2;
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) out_store <= 'd0;
	else begin
		if(state == CONV) begin
			if(count_28 == 'd6 || count_28 == 'd26) begin
				out_store <= pooling_output[19:1];
			end
			else begin
				out_store <= out_store >> 1'b1;
			end
		end
		else if(state == DECONV) begin
			if(count_28 == 'd2 || count_28 == 'd22) begin
				out_store <= add_out[23][19:1];
			end
			else begin
				out_store <= out_store >> 1'b1;
			end
		end
		else begin
			out_store <= out_store >> 1'b1;
		end
	end
end
generate 
for(i=0;i<8;i=i+1) begin: z
	always @ * begin
		case(count_5) // synopsys full_case
			'd0 : deconv_transfer[0][i] = Img_SRAM_Data_split[0][i];
			'd1 : deconv_transfer[0][i] = Img_SRAM_Data_split[1][i];
			'd2 : deconv_transfer[0][i] = Img_SRAM_Data_split[2][i];
			'd3 : deconv_transfer[0][i] = Img_SRAM_Data_split[3][i];
			'd4 : deconv_transfer[0][i] = Img_SRAM_Data_split[4][i];
		endcase
		case(count_5) // synopsys full_case
			'd0 : deconv_transfer[1][i] = Img_SRAM_Data_split[1][i];
			'd1 : deconv_transfer[1][i] = Img_SRAM_Data_split[2][i];
			'd2 : deconv_transfer[1][i] = Img_SRAM_Data_split[3][i];
			'd3 : deconv_transfer[1][i] = Img_SRAM_Data_split[4][i];
			'd4 : deconv_transfer[1][i] = Img_SRAM_Data_split[0][i];
		endcase
		case(count_5) // synopsys full_case
			'd0 : deconv_transfer[2][i] = Img_SRAM_Data_split[2][i];
			'd1 : deconv_transfer[2][i] = Img_SRAM_Data_split[3][i];
			'd2 : deconv_transfer[2][i] = Img_SRAM_Data_split[4][i];
			'd3 : deconv_transfer[2][i] = Img_SRAM_Data_split[0][i];
			'd4 : deconv_transfer[2][i] = Img_SRAM_Data_split[1][i];
		endcase
		case(count_5) // synopsys full_case
			'd0 : deconv_transfer[3][i] = Img_SRAM_Data_split[3][i];
			'd1 : deconv_transfer[3][i] = Img_SRAM_Data_split[4][i];
			'd2 : deconv_transfer[3][i] = Img_SRAM_Data_split[0][i];
			'd3 : deconv_transfer[3][i] = Img_SRAM_Data_split[1][i];
			'd4 : deconv_transfer[3][i] = Img_SRAM_Data_split[2][i];
		endcase
		case(count_5) // synopsys full_case
			'd0 : deconv_transfer[4][i] = Img_SRAM_Data_split[4][i];
			'd1 : deconv_transfer[4][i] = Img_SRAM_Data_split[0][i];
			'd2 : deconv_transfer[4][i] = Img_SRAM_Data_split[1][i];
			'd3 : deconv_transfer[4][i] = Img_SRAM_Data_split[2][i];
			'd4 : deconv_transfer[4][i] = Img_SRAM_Data_split[3][i];
		endcase
	end
end
endgenerate
// Img buffer mux
always @ * begin
Img_ready_comb[0][0] = Img_ready[0][0];
Img_ready_comb[1][0] = Img_ready[1][0];
Img_ready_comb[2][0] = Img_ready[2][0];
Img_ready_comb[3][0] = Img_ready[3][0];
Img_ready_comb[4][0] = Img_ready[4][0];
Img_ready_comb[0][1] = Img_ready[0][1];
Img_ready_comb[1][1] = Img_ready[1][1];
Img_ready_comb[2][1] = Img_ready[2][1];
Img_ready_comb[3][1] = Img_ready[3][1];
Img_ready_comb[4][1] = Img_ready[4][1];
Img_ready_comb[0][2] = Img_ready[0][2];
Img_ready_comb[1][2] = Img_ready[1][2];
Img_ready_comb[2][2] = Img_ready[2][2];
Img_ready_comb[3][2] = Img_ready[3][2];
Img_ready_comb[4][2] = Img_ready[4][2];
Img_ready_comb[0][3] = Img_ready[0][3];
Img_ready_comb[1][3] = Img_ready[1][3];
Img_ready_comb[2][3] = Img_ready[2][3];
Img_ready_comb[3][3] = Img_ready[3][3];
Img_ready_comb[4][3] = Img_ready[4][3];
Img_ready_comb[0][4] = Img_ready[0][4];
Img_ready_comb[1][4] = Img_ready[1][4];
Img_ready_comb[2][4] = Img_ready[2][4];
Img_ready_comb[3][4] = Img_ready[3][4];
Img_ready_comb[4][4] = Img_ready[4][4];
Img_ready_comb[0][5] = Img_ready[0][5];
Img_ready_comb[1][5] = Img_ready[1][5];
Img_ready_comb[2][5] = Img_ready[2][5];
Img_ready_comb[3][5] = Img_ready[3][5];
Img_ready_comb[4][5] = Img_ready[4][5];
row_6_comb[0] = row_6[0];
row_6_comb[1] = row_6[1];
row_6_comb[2] = row_6[2];
row_6_comb[3] = row_6[3];
row_6_comb[4] = row_6[4];
row_6_comb[5] = row_6[5];
	if(state == WAIT) begin
		Img_ready_comb[0][0] = 'd0;
		Img_ready_comb[1][0] = 'd0;
		Img_ready_comb[2][0] = 'd0;
		Img_ready_comb[3][0] = 'd0;
		Img_ready_comb[4][0] = 'd0;
		Img_ready_comb[0][1] = 'd0;
		Img_ready_comb[1][1] = 'd0;
		Img_ready_comb[2][1] = 'd0;
		Img_ready_comb[3][1] = 'd0;
		Img_ready_comb[4][1] = 'd0;
		Img_ready_comb[0][2] = 'd0;
		Img_ready_comb[1][2] = 'd0;
		Img_ready_comb[2][2] = 'd0;
		Img_ready_comb[3][2] = 'd0;
		Img_ready_comb[4][2] = 'd0;
		Img_ready_comb[0][3] = 'd0;
		Img_ready_comb[1][3] = 'd0;
		Img_ready_comb[2][3] = 'd0;
		Img_ready_comb[3][3] = 'd0;
		Img_ready_comb[4][3] = 'd0;
		Img_ready_comb[0][4] = 'd0;
		Img_ready_comb[1][4] = 'd0;
		Img_ready_comb[2][4] = 'd0;
		Img_ready_comb[3][4] = 'd0;
		Img_ready_comb[4][4] = 'd0;
		Img_ready_comb[0][5] = 'd0;
		Img_ready_comb[1][5] = 'd0;
		Img_ready_comb[2][5] = 'd0;
		Img_ready_comb[3][5] = 'd0;
		Img_ready_comb[4][5] = 'd0;
	end
	else if(state == DECONV && (count_28 == 'd0 || count_28 == 'd15)) begin
		if(row_count == 'd0) begin
			Img_ready_comb[0][0] = 'd0;
			Img_ready_comb[1][0] = 'd0;
			Img_ready_comb[2][0] = 'd0;
			Img_ready_comb[3][0] = 'd0;
			Img_ready_comb[4][0] = Img_ready[4][1];
			Img_ready_comb[0][1] = 'd0;
			Img_ready_comb[1][1] = 'd0;
			Img_ready_comb[2][1] = 'd0;
			Img_ready_comb[3][1] = 'd0;
			Img_ready_comb[4][1] = Img_ready[4][2];
			Img_ready_comb[0][2] = 'd0;
			Img_ready_comb[1][2] = 'd0;
			Img_ready_comb[2][2] = 'd0;
			Img_ready_comb[3][2] = 'd0;
			Img_ready_comb[4][2] = Img_ready[4][3];
			Img_ready_comb[0][3] = 'd0;
			Img_ready_comb[1][3] = 'd0;
			Img_ready_comb[2][3] = 'd0;
			Img_ready_comb[3][3] = 'd0;
			Img_ready_comb[4][3] = Img_ready[4][4];
			Img_ready_comb[0][4] = 'd0;
			Img_ready_comb[1][4] = 'd0;
			Img_ready_comb[2][4] = 'd0;
			Img_ready_comb[3][4] = 'd0;
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = deconv_transfer[0][0];
				'd1 :	Img_ready_comb[4][4] = deconv_transfer[0][1];
				'd2 :	Img_ready_comb[4][4] = deconv_transfer[0][2];
				'd3 :	Img_ready_comb[4][4] = deconv_transfer[0][3];
				'd4 :	Img_ready_comb[4][4] = deconv_transfer[0][4];
				'd5 :	Img_ready_comb[4][4] = deconv_transfer[0][5];
				'd6 :	Img_ready_comb[4][4] = deconv_transfer[0][6];
				'd7 :	Img_ready_comb[4][4] = deconv_transfer[0][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[0][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[0][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[0][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[0][3];
						end
				'd12:	Img_ready_comb[4][4] = deconv_transfer[0][4];
				'd13:	Img_ready_comb[4][4] = deconv_transfer[0][5];
				'd14:	Img_ready_comb[4][4] = deconv_transfer[0][6];
				'd15:	Img_ready_comb[4][4] = deconv_transfer[0][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[0][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[0][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[0][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[0][3];
						end
				
				'd20:	Img_ready_comb[4][4] = deconv_transfer[0][4];
				'd21:	Img_ready_comb[4][4] = deconv_transfer[0][5];
				'd22:	Img_ready_comb[4][4] = deconv_transfer[0][6];
				'd23:	Img_ready_comb[4][4] = deconv_transfer[0][7];
				'd24:	Img_ready_comb[4][4] = deconv_transfer[0][0];
				'd25:	Img_ready_comb[4][4] = deconv_transfer[0][1];
				'd26:	Img_ready_comb[4][4] = deconv_transfer[0][2];
				'd27:	Img_ready_comb[4][4] = deconv_transfer[0][3];
				'd28:	Img_ready_comb[4][4] = deconv_transfer[0][4];
				'd29:	Img_ready_comb[4][4] = deconv_transfer[0][5];
				'd30:	Img_ready_comb[4][4] = deconv_transfer[0][6];
				'd31:	Img_ready_comb[4][4] = deconv_transfer[0][7];
				'd32:	Img_ready_comb[4][4] = 'd0;
				'd33:	Img_ready_comb[4][4] = 'd0;
				'd34:	Img_ready_comb[4][4] = 'd0;
				'd35:	Img_ready_comb[4][4] = 'd0;
			endcase
		end
		else if(row_count == 'd1) begin
			Img_ready_comb[0][0] = 'd0;
			Img_ready_comb[1][0] = 'd0;
			Img_ready_comb[2][0] = 'd0;
			Img_ready_comb[3][0] = Img_ready[3][1];
			Img_ready_comb[4][0] = Img_ready[4][1];
			Img_ready_comb[0][1] = 'd0;
			Img_ready_comb[1][1] = 'd0;
			Img_ready_comb[2][1] = 'd0;
			Img_ready_comb[3][1] = Img_ready[3][2];
			Img_ready_comb[4][1] = Img_ready[4][2];
			Img_ready_comb[0][2] = 'd0;
			Img_ready_comb[1][2] = 'd0;
			Img_ready_comb[2][2] = 'd0;
			Img_ready_comb[3][2] = Img_ready[3][3];
			Img_ready_comb[4][2] = Img_ready[4][3];
			Img_ready_comb[0][3] = 'd0;
			Img_ready_comb[1][3] = 'd0;
			Img_ready_comb[2][3] = 'd0;
			Img_ready_comb[3][3] = Img_ready[3][4];
			Img_ready_comb[4][3] = Img_ready[4][4];
			Img_ready_comb[0][4] = 'd0;
			Img_ready_comb[1][4] = 'd0;
			Img_ready_comb[2][4] = 'd0;
			
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = deconv_transfer[0][0];
				'd1 :	Img_ready_comb[3][4] = deconv_transfer[0][1];
				'd2 :	Img_ready_comb[3][4] = deconv_transfer[0][2];
				'd3 :	Img_ready_comb[3][4] = deconv_transfer[0][3];
				'd4 :	Img_ready_comb[3][4] = deconv_transfer[0][4];
				'd5 :	Img_ready_comb[3][4] = deconv_transfer[0][5];
				'd6 :	Img_ready_comb[3][4] = deconv_transfer[0][6];
				'd7 :	Img_ready_comb[3][4] = deconv_transfer[0][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[0][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[0][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[0][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[0][3];
						end
				'd12:	Img_ready_comb[3][4] = deconv_transfer[0][4];
				'd13:	Img_ready_comb[3][4] = deconv_transfer[0][5];
				'd14:	Img_ready_comb[3][4] = deconv_transfer[0][6];
				'd15:	Img_ready_comb[3][4] = deconv_transfer[0][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[0][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[0][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[0][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[0][3];
						end
				
				'd20:	Img_ready_comb[3][4] = deconv_transfer[0][4];
				'd21:	Img_ready_comb[3][4] = deconv_transfer[0][5];
				'd22:	Img_ready_comb[3][4] = deconv_transfer[0][6];
				'd23:	Img_ready_comb[3][4] = deconv_transfer[0][7];
				'd24:	Img_ready_comb[3][4] = deconv_transfer[0][0];
				'd25:	Img_ready_comb[3][4] = deconv_transfer[0][1];
				'd26:	Img_ready_comb[3][4] = deconv_transfer[0][2];
				'd27:	Img_ready_comb[3][4] = deconv_transfer[0][3];
				'd28:	Img_ready_comb[3][4] = deconv_transfer[0][4];
				'd29:	Img_ready_comb[3][4] = deconv_transfer[0][5];
				'd30:	Img_ready_comb[3][4] = deconv_transfer[0][6];
				'd31:	Img_ready_comb[3][4] = deconv_transfer[0][7];
				'd32:	Img_ready_comb[3][4] = 'd0;
				'd33:	Img_ready_comb[3][4] = 'd0;
				'd34:	Img_ready_comb[3][4] = 'd0;
				'd35:	Img_ready_comb[3][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = deconv_transfer[1][0];
				'd1 :	Img_ready_comb[4][4] = deconv_transfer[1][1];
				'd2 :	Img_ready_comb[4][4] = deconv_transfer[1][2];
				'd3 :	Img_ready_comb[4][4] = deconv_transfer[1][3];
				'd4 :	Img_ready_comb[4][4] = deconv_transfer[1][4];
				'd5 :	Img_ready_comb[4][4] = deconv_transfer[1][5];
				'd6 :	Img_ready_comb[4][4] = deconv_transfer[1][6];
				'd7 :	Img_ready_comb[4][4] = deconv_transfer[1][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[1][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[1][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[1][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[1][3];
						end
				'd12:	Img_ready_comb[4][4] = deconv_transfer[1][4];
				'd13:	Img_ready_comb[4][4] = deconv_transfer[1][5];
				'd14:	Img_ready_comb[4][4] = deconv_transfer[1][6];
				'd15:	Img_ready_comb[4][4] = deconv_transfer[1][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[1][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[1][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[1][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[1][3];
						end
				
				'd20:	Img_ready_comb[4][4] = deconv_transfer[1][4];
				'd21:	Img_ready_comb[4][4] = deconv_transfer[1][5];
				'd22:	Img_ready_comb[4][4] = deconv_transfer[1][6];
				'd23:	Img_ready_comb[4][4] = deconv_transfer[1][7];
				'd24:	Img_ready_comb[4][4] = deconv_transfer[1][0];
				'd25:	Img_ready_comb[4][4] = deconv_transfer[1][1];
				'd26:	Img_ready_comb[4][4] = deconv_transfer[1][2];
				'd27:	Img_ready_comb[4][4] = deconv_transfer[1][3];
				'd28:	Img_ready_comb[4][4] = deconv_transfer[1][4];
				'd29:	Img_ready_comb[4][4] = deconv_transfer[1][5];
				'd30:	Img_ready_comb[4][4] = deconv_transfer[1][6];
				'd31:	Img_ready_comb[4][4] = deconv_transfer[1][7];
				'd32:	Img_ready_comb[4][4] = 'd0;
				'd33:	Img_ready_comb[4][4] = 'd0;
				'd34:	Img_ready_comb[4][4] = 'd0;
				'd35:	Img_ready_comb[4][4] = 'd0;
			endcase
		end
		else if(row_count == 'd2) begin
			Img_ready_comb[0][0] = 'd0;
			Img_ready_comb[1][0] = 'd0;
			Img_ready_comb[2][0] = Img_ready[2][1];
			Img_ready_comb[3][0] = Img_ready[3][1];
			Img_ready_comb[4][0] = Img_ready[4][1];
			Img_ready_comb[0][1] = 'd0;
			Img_ready_comb[1][1] = 'd0;
			Img_ready_comb[2][1] = Img_ready[2][2];
			Img_ready_comb[3][1] = Img_ready[3][2];
			Img_ready_comb[4][1] = Img_ready[4][2];
			Img_ready_comb[0][2] = 'd0;
			Img_ready_comb[1][2] = 'd0;
			Img_ready_comb[2][2] = Img_ready[2][3];
			Img_ready_comb[3][2] = Img_ready[3][3];
			Img_ready_comb[4][2] = Img_ready[4][3];
			Img_ready_comb[0][3] = 'd0;
			Img_ready_comb[1][3] = 'd0;
			Img_ready_comb[2][3] = Img_ready[2][4];
			Img_ready_comb[3][3] = Img_ready[3][4];
			Img_ready_comb[4][3] = Img_ready[4][4];
			Img_ready_comb[0][4] = 'd0;
			Img_ready_comb[1][4] = 'd0;
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = deconv_transfer[0][0];
				'd1 :	Img_ready_comb[2][4] = deconv_transfer[0][1];
				'd2 :	Img_ready_comb[2][4] = deconv_transfer[0][2];
				'd3 :	Img_ready_comb[2][4] = deconv_transfer[0][3];
				'd4 :	Img_ready_comb[2][4] = deconv_transfer[0][4];
				'd5 :	Img_ready_comb[2][4] = deconv_transfer[0][5];
				'd6 :	Img_ready_comb[2][4] = deconv_transfer[0][6];
				'd7 :	Img_ready_comb[2][4] = deconv_transfer[0][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[0][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[0][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[0][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[0][3];
						end
				'd12:	Img_ready_comb[2][4] = deconv_transfer[0][4];
				'd13:	Img_ready_comb[2][4] = deconv_transfer[0][5];
				'd14:	Img_ready_comb[2][4] = deconv_transfer[0][6];
				'd15:	Img_ready_comb[2][4] = deconv_transfer[0][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[0][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[0][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[0][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[0][3];
						end
				
				'd20:	Img_ready_comb[2][4] = deconv_transfer[0][4];
				'd21:	Img_ready_comb[2][4] = deconv_transfer[0][5];
				'd22:	Img_ready_comb[2][4] = deconv_transfer[0][6];
				'd23:	Img_ready_comb[2][4] = deconv_transfer[0][7];
				'd24:	Img_ready_comb[2][4] = deconv_transfer[0][0];
				'd25:	Img_ready_comb[2][4] = deconv_transfer[0][1];
				'd26:	Img_ready_comb[2][4] = deconv_transfer[0][2];
				'd27:	Img_ready_comb[2][4] = deconv_transfer[0][3];
				'd28:	Img_ready_comb[2][4] = deconv_transfer[0][4];
				'd29:	Img_ready_comb[2][4] = deconv_transfer[0][5];
				'd30:	Img_ready_comb[2][4] = deconv_transfer[0][6];
				'd31:	Img_ready_comb[2][4] = deconv_transfer[0][7];
				'd32:	Img_ready_comb[2][4] = 'd0;
				'd33:	Img_ready_comb[2][4] = 'd0;
				'd34:	Img_ready_comb[2][4] = 'd0;
				'd35:	Img_ready_comb[2][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = deconv_transfer[1][0];
				'd1 :	Img_ready_comb[3][4] = deconv_transfer[1][1];
				'd2 :	Img_ready_comb[3][4] = deconv_transfer[1][2];
				'd3 :	Img_ready_comb[3][4] = deconv_transfer[1][3];
				'd4 :	Img_ready_comb[3][4] = deconv_transfer[1][4];
				'd5 :	Img_ready_comb[3][4] = deconv_transfer[1][5];
				'd6 :	Img_ready_comb[3][4] = deconv_transfer[1][6];
				'd7 :	Img_ready_comb[3][4] = deconv_transfer[1][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[1][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[1][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[1][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[1][3];
						end
				'd12:	Img_ready_comb[3][4] = deconv_transfer[1][4];
				'd13:	Img_ready_comb[3][4] = deconv_transfer[1][5];
				'd14:	Img_ready_comb[3][4] = deconv_transfer[1][6];
				'd15:	Img_ready_comb[3][4] = deconv_transfer[1][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[1][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[1][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[1][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[1][3];
						end
				
				'd20:	Img_ready_comb[3][4] = deconv_transfer[1][4];
				'd21:	Img_ready_comb[3][4] = deconv_transfer[1][5];
				'd22:	Img_ready_comb[3][4] = deconv_transfer[1][6];
				'd23:	Img_ready_comb[3][4] = deconv_transfer[1][7];
				'd24:	Img_ready_comb[3][4] = deconv_transfer[1][0];
				'd25:	Img_ready_comb[3][4] = deconv_transfer[1][1];
				'd26:	Img_ready_comb[3][4] = deconv_transfer[1][2];
				'd27:	Img_ready_comb[3][4] = deconv_transfer[1][3];
				'd28:	Img_ready_comb[3][4] = deconv_transfer[1][4];
				'd29:	Img_ready_comb[3][4] = deconv_transfer[1][5];
				'd30:	Img_ready_comb[3][4] = deconv_transfer[1][6];
				'd31:	Img_ready_comb[3][4] = deconv_transfer[1][7];
				'd32:	Img_ready_comb[3][4] = 'd0;
				'd33:	Img_ready_comb[3][4] = 'd0;
				'd34:	Img_ready_comb[3][4] = 'd0;
				'd35:	Img_ready_comb[3][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = deconv_transfer[2][0];
				'd1 :	Img_ready_comb[4][4] = deconv_transfer[2][1];
				'd2 :	Img_ready_comb[4][4] = deconv_transfer[2][2];
				'd3 :	Img_ready_comb[4][4] = deconv_transfer[2][3];
				'd4 :	Img_ready_comb[4][4] = deconv_transfer[2][4];
				'd5 :	Img_ready_comb[4][4] = deconv_transfer[2][5];
				'd6 :	Img_ready_comb[4][4] = deconv_transfer[2][6];
				'd7 :	Img_ready_comb[4][4] = deconv_transfer[2][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[2][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[2][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[2][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[2][3];
						end
				'd12:	Img_ready_comb[4][4] = deconv_transfer[2][4];
				'd13:	Img_ready_comb[4][4] = deconv_transfer[2][5];
				'd14:	Img_ready_comb[4][4] = deconv_transfer[2][6];
				'd15:	Img_ready_comb[4][4] = deconv_transfer[2][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[2][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[2][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[2][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[2][3];
						end
				
				'd20:	Img_ready_comb[4][4] = deconv_transfer[2][4];
				'd21:	Img_ready_comb[4][4] = deconv_transfer[2][5];
				'd22:	Img_ready_comb[4][4] = deconv_transfer[2][6];
				'd23:	Img_ready_comb[4][4] = deconv_transfer[2][7];
				'd24:	Img_ready_comb[4][4] = deconv_transfer[2][0];
				'd25:	Img_ready_comb[4][4] = deconv_transfer[2][1];
				'd26:	Img_ready_comb[4][4] = deconv_transfer[2][2];
				'd27:	Img_ready_comb[4][4] = deconv_transfer[2][3];
				'd28:	Img_ready_comb[4][4] = deconv_transfer[2][4];
				'd29:	Img_ready_comb[4][4] = deconv_transfer[2][5];
				'd30:	Img_ready_comb[4][4] = deconv_transfer[2][6];
				'd31:	Img_ready_comb[4][4] = deconv_transfer[2][7];
				'd32:	Img_ready_comb[4][4] = 'd0;
				'd33:	Img_ready_comb[4][4] = 'd0;
				'd34:	Img_ready_comb[4][4] = 'd0;
				'd35:	Img_ready_comb[4][4] = 'd0;
			endcase
		end
		else if(row_count == 'd3) begin
			Img_ready_comb[0][0] = 'd0;
			Img_ready_comb[1][0] = Img_ready[1][1];
			Img_ready_comb[2][0] = Img_ready[2][1];
			Img_ready_comb[3][0] = Img_ready[3][1];
			Img_ready_comb[4][0] = Img_ready[4][1];
			Img_ready_comb[0][1] = 'd0;
			Img_ready_comb[1][1] = Img_ready[1][2];
			Img_ready_comb[2][1] = Img_ready[2][2];
			Img_ready_comb[3][1] = Img_ready[3][2];
			Img_ready_comb[4][1] = Img_ready[4][2];
			Img_ready_comb[0][2] = 'd0;
			Img_ready_comb[1][2] = Img_ready[1][3];
			Img_ready_comb[2][2] = Img_ready[2][3];
			Img_ready_comb[3][2] = Img_ready[3][3];
			Img_ready_comb[4][2] = Img_ready[4][3];
			Img_ready_comb[0][3] = 'd0;
			Img_ready_comb[1][3] = Img_ready[1][4];
			Img_ready_comb[2][3] = Img_ready[2][4];
			Img_ready_comb[3][3] = Img_ready[3][4];
			Img_ready_comb[4][3] = Img_ready[4][4];
			Img_ready_comb[0][4] = 'd0;
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = deconv_transfer[0][0];
				'd1 :	Img_ready_comb[1][4] = deconv_transfer[0][1];
				'd2 :	Img_ready_comb[1][4] = deconv_transfer[0][2];
				'd3 :	Img_ready_comb[1][4] = deconv_transfer[0][3];
				'd4 :	Img_ready_comb[1][4] = deconv_transfer[0][4];
				'd5 :	Img_ready_comb[1][4] = deconv_transfer[0][5];
				'd6 :	Img_ready_comb[1][4] = deconv_transfer[0][6];
				'd7 :	Img_ready_comb[1][4] = deconv_transfer[0][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[0][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[0][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[0][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[0][3];
						end
				'd12:	Img_ready_comb[1][4] = deconv_transfer[0][4];
				'd13:	Img_ready_comb[1][4] = deconv_transfer[0][5];
				'd14:	Img_ready_comb[1][4] = deconv_transfer[0][6];
				'd15:	Img_ready_comb[1][4] = deconv_transfer[0][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[0][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[0][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[0][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[0][3];
						end
				
				'd20:	Img_ready_comb[1][4] = deconv_transfer[0][4];
				'd21:	Img_ready_comb[1][4] = deconv_transfer[0][5];
				'd22:	Img_ready_comb[1][4] = deconv_transfer[0][6];
				'd23:	Img_ready_comb[1][4] = deconv_transfer[0][7];
				'd24:	Img_ready_comb[1][4] = deconv_transfer[0][0];
				'd25:	Img_ready_comb[1][4] = deconv_transfer[0][1];
				'd26:	Img_ready_comb[1][4] = deconv_transfer[0][2];
				'd27:	Img_ready_comb[1][4] = deconv_transfer[0][3];
				'd28:	Img_ready_comb[1][4] = deconv_transfer[0][4];
				'd29:	Img_ready_comb[1][4] = deconv_transfer[0][5];
				'd30:	Img_ready_comb[1][4] = deconv_transfer[0][6];
				'd31:	Img_ready_comb[1][4] = deconv_transfer[0][7];
				'd32:	Img_ready_comb[1][4] = 'd0;
				'd33:	Img_ready_comb[1][4] = 'd0;
				'd34:	Img_ready_comb[1][4] = 'd0;
				'd35:	Img_ready_comb[1][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = deconv_transfer[1][0];
				'd1 :	Img_ready_comb[2][4] = deconv_transfer[1][1];
				'd2 :	Img_ready_comb[2][4] = deconv_transfer[1][2];
				'd3 :	Img_ready_comb[2][4] = deconv_transfer[1][3];
				'd4 :	Img_ready_comb[2][4] = deconv_transfer[1][4];
				'd5 :	Img_ready_comb[2][4] = deconv_transfer[1][5];
				'd6 :	Img_ready_comb[2][4] = deconv_transfer[1][6];
				'd7 :	Img_ready_comb[2][4] = deconv_transfer[1][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[1][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[1][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[1][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[1][3];
						end
				'd12:	Img_ready_comb[2][4] = deconv_transfer[1][4];
				'd13:	Img_ready_comb[2][4] = deconv_transfer[1][5];
				'd14:	Img_ready_comb[2][4] = deconv_transfer[1][6];
				'd15:	Img_ready_comb[2][4] = deconv_transfer[1][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[1][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[1][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[1][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[1][3];
						end
				
				'd20:	Img_ready_comb[2][4] = deconv_transfer[1][4];
				'd21:	Img_ready_comb[2][4] = deconv_transfer[1][5];
				'd22:	Img_ready_comb[2][4] = deconv_transfer[1][6];
				'd23:	Img_ready_comb[2][4] = deconv_transfer[1][7];
				'd24:	Img_ready_comb[2][4] = deconv_transfer[1][0];
				'd25:	Img_ready_comb[2][4] = deconv_transfer[1][1];
				'd26:	Img_ready_comb[2][4] = deconv_transfer[1][2];
				'd27:	Img_ready_comb[2][4] = deconv_transfer[1][3];
				'd28:	Img_ready_comb[2][4] = deconv_transfer[1][4];
				'd29:	Img_ready_comb[2][4] = deconv_transfer[1][5];
				'd30:	Img_ready_comb[2][4] = deconv_transfer[1][6];
				'd31:	Img_ready_comb[2][4] = deconv_transfer[1][7];
				'd32:	Img_ready_comb[2][4] = 'd0;
				'd33:	Img_ready_comb[2][4] = 'd0;
				'd34:	Img_ready_comb[2][4] = 'd0;
				'd35:	Img_ready_comb[2][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = deconv_transfer[2][0];
				'd1 :	Img_ready_comb[3][4] = deconv_transfer[2][1];
				'd2 :	Img_ready_comb[3][4] = deconv_transfer[2][2];
				'd3 :	Img_ready_comb[3][4] = deconv_transfer[2][3];
				'd4 :	Img_ready_comb[3][4] = deconv_transfer[2][4];
				'd5 :	Img_ready_comb[3][4] = deconv_transfer[2][5];
				'd6 :	Img_ready_comb[3][4] = deconv_transfer[2][6];
				'd7 :	Img_ready_comb[3][4] = deconv_transfer[2][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[2][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[2][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[2][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[2][3];
						end
				'd12:	Img_ready_comb[3][4] = deconv_transfer[2][4];
				'd13:	Img_ready_comb[3][4] = deconv_transfer[2][5];
				'd14:	Img_ready_comb[3][4] = deconv_transfer[2][6];
				'd15:	Img_ready_comb[3][4] = deconv_transfer[2][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[2][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[2][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[2][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[2][3];
						end
				
				'd20:	Img_ready_comb[3][4] = deconv_transfer[2][4];
				'd21:	Img_ready_comb[3][4] = deconv_transfer[2][5];
				'd22:	Img_ready_comb[3][4] = deconv_transfer[2][6];
				'd23:	Img_ready_comb[3][4] = deconv_transfer[2][7];
				'd24:	Img_ready_comb[3][4] = deconv_transfer[2][0];
				'd25:	Img_ready_comb[3][4] = deconv_transfer[2][1];
				'd26:	Img_ready_comb[3][4] = deconv_transfer[2][2];
				'd27:	Img_ready_comb[3][4] = deconv_transfer[2][3];
				'd28:	Img_ready_comb[3][4] = deconv_transfer[2][4];
				'd29:	Img_ready_comb[3][4] = deconv_transfer[2][5];
				'd30:	Img_ready_comb[3][4] = deconv_transfer[2][6];
				'd31:	Img_ready_comb[3][4] = deconv_transfer[2][7];
				'd32:	Img_ready_comb[3][4] = 'd0;
				'd33:	Img_ready_comb[3][4] = 'd0;
				'd34:	Img_ready_comb[3][4] = 'd0;
				'd35:	Img_ready_comb[3][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = deconv_transfer[3][0];
				'd1 :	Img_ready_comb[4][4] = deconv_transfer[3][1];
				'd2 :	Img_ready_comb[4][4] = deconv_transfer[3][2];
				'd3 :	Img_ready_comb[4][4] = deconv_transfer[3][3];
				'd4 :	Img_ready_comb[4][4] = deconv_transfer[3][4];
				'd5 :	Img_ready_comb[4][4] = deconv_transfer[3][5];
				'd6 :	Img_ready_comb[4][4] = deconv_transfer[3][6];
				'd7 :	Img_ready_comb[4][4] = deconv_transfer[3][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[3][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[3][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[3][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[3][3];
						end
				'd12:	Img_ready_comb[4][4] = deconv_transfer[3][4];
				'd13:	Img_ready_comb[4][4] = deconv_transfer[3][5];
				'd14:	Img_ready_comb[4][4] = deconv_transfer[3][6];
				'd15:	Img_ready_comb[4][4] = deconv_transfer[3][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[3][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[3][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[3][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[3][3];
						end
				
				'd20:	Img_ready_comb[4][4] = deconv_transfer[3][4];
				'd21:	Img_ready_comb[4][4] = deconv_transfer[3][5];
				'd22:	Img_ready_comb[4][4] = deconv_transfer[3][6];
				'd23:	Img_ready_comb[4][4] = deconv_transfer[3][7];
				'd24:	Img_ready_comb[4][4] = deconv_transfer[3][0];
				'd25:	Img_ready_comb[4][4] = deconv_transfer[3][1];
				'd26:	Img_ready_comb[4][4] = deconv_transfer[3][2];
				'd27:	Img_ready_comb[4][4] = deconv_transfer[3][3];
				'd28:	Img_ready_comb[4][4] = deconv_transfer[3][4];
				'd29:	Img_ready_comb[4][4] = deconv_transfer[3][5];
				'd30:	Img_ready_comb[4][4] = deconv_transfer[3][6];
				'd31:	Img_ready_comb[4][4] = deconv_transfer[3][7];
				'd32:	Img_ready_comb[4][4] = 'd0;
				'd33:	Img_ready_comb[4][4] = 'd0;
				'd34:	Img_ready_comb[4][4] = 'd0;
				'd35:	Img_ready_comb[4][4] = 'd0;
			endcase
		end
		else if(row_count == deconv_row_end) begin
			Img_ready_comb[0][0] = Img_ready[0][1];
			Img_ready_comb[1][0] = Img_ready[1][1];
			Img_ready_comb[2][0] = Img_ready[2][1];
			Img_ready_comb[3][0] = Img_ready[3][1];
			Img_ready_comb[4][0] = 'd0;
			Img_ready_comb[0][1] = Img_ready[0][2];
			Img_ready_comb[1][1] = Img_ready[1][2];
			Img_ready_comb[2][1] = Img_ready[2][2];
			Img_ready_comb[3][1] = Img_ready[3][2];
			Img_ready_comb[4][1] = 'd0;
			Img_ready_comb[0][2] = Img_ready[0][3];
			Img_ready_comb[1][2] = Img_ready[1][3];
			Img_ready_comb[2][2] = Img_ready[2][3];
			Img_ready_comb[3][2] = Img_ready[3][3];
			Img_ready_comb[4][2] = 'd0;
			Img_ready_comb[0][3] = Img_ready[0][4];
			Img_ready_comb[1][3] = Img_ready[1][4];
			Img_ready_comb[2][3] = Img_ready[2][4];
			Img_ready_comb[3][3] = Img_ready[3][4];
			Img_ready_comb[4][3] = 'd0;
			Img_ready_comb[4][4] = 'd0;
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = deconv_transfer[1][0];
				'd1 :	Img_ready_comb[0][4] = deconv_transfer[1][1];
				'd2 :	Img_ready_comb[0][4] = deconv_transfer[1][2];
				'd3 :	Img_ready_comb[0][4] = deconv_transfer[1][3];
				'd4 :	Img_ready_comb[0][4] = deconv_transfer[1][4];
				'd5 :	Img_ready_comb[0][4] = deconv_transfer[1][5];
				'd6 :	Img_ready_comb[0][4] = deconv_transfer[1][6];
				'd7 :	Img_ready_comb[0][4] = deconv_transfer[1][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[1][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[1][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[1][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[1][3];
						end
				'd12:	Img_ready_comb[0][4] = deconv_transfer[1][4];
				'd13:	Img_ready_comb[0][4] = deconv_transfer[1][5];
				'd14:	Img_ready_comb[0][4] = deconv_transfer[1][6];
				'd15:	Img_ready_comb[0][4] = deconv_transfer[1][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[1][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[1][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[1][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[1][3];
						end
				
				'd20:	Img_ready_comb[0][4] = deconv_transfer[1][4];
				'd21:	Img_ready_comb[0][4] = deconv_transfer[1][5];
				'd22:	Img_ready_comb[0][4] = deconv_transfer[1][6];
				'd23:	Img_ready_comb[0][4] = deconv_transfer[1][7];
				'd24:	Img_ready_comb[0][4] = deconv_transfer[1][0];
				'd25:	Img_ready_comb[0][4] = deconv_transfer[1][1];
				'd26:	Img_ready_comb[0][4] = deconv_transfer[1][2];
				'd27:	Img_ready_comb[0][4] = deconv_transfer[1][3];
				'd28:	Img_ready_comb[0][4] = deconv_transfer[1][4];
				'd29:	Img_ready_comb[0][4] = deconv_transfer[1][5];
				'd30:	Img_ready_comb[0][4] = deconv_transfer[1][6];
				'd31:	Img_ready_comb[0][4] = deconv_transfer[1][7];
				'd32:	Img_ready_comb[0][4] = 'd0;
				'd33:	Img_ready_comb[0][4] = 'd0;
				'd34:	Img_ready_comb[0][4] = 'd0;
				'd35:	Img_ready_comb[0][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = deconv_transfer[2][0];
				'd1 :	Img_ready_comb[1][4] = deconv_transfer[2][1];
				'd2 :	Img_ready_comb[1][4] = deconv_transfer[2][2];
				'd3 :	Img_ready_comb[1][4] = deconv_transfer[2][3];
				'd4 :	Img_ready_comb[1][4] = deconv_transfer[2][4];
				'd5 :	Img_ready_comb[1][4] = deconv_transfer[2][5];
				'd6 :	Img_ready_comb[1][4] = deconv_transfer[2][6];
				'd7 :	Img_ready_comb[1][4] = deconv_transfer[2][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[2][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[2][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[2][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[2][3];
						end
				'd12:	Img_ready_comb[1][4] = deconv_transfer[2][4];
				'd13:	Img_ready_comb[1][4] = deconv_transfer[2][5];
				'd14:	Img_ready_comb[1][4] = deconv_transfer[2][6];
				'd15:	Img_ready_comb[1][4] = deconv_transfer[2][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[2][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[2][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[2][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[2][3];
						end
				
				'd20:	Img_ready_comb[1][4] = deconv_transfer[2][4];
				'd21:	Img_ready_comb[1][4] = deconv_transfer[2][5];
				'd22:	Img_ready_comb[1][4] = deconv_transfer[2][6];
				'd23:	Img_ready_comb[1][4] = deconv_transfer[2][7];
				'd24:	Img_ready_comb[1][4] = deconv_transfer[2][0];
				'd25:	Img_ready_comb[1][4] = deconv_transfer[2][1];
				'd26:	Img_ready_comb[1][4] = deconv_transfer[2][2];
				'd27:	Img_ready_comb[1][4] = deconv_transfer[2][3];
				'd28:	Img_ready_comb[1][4] = deconv_transfer[2][4];
				'd29:	Img_ready_comb[1][4] = deconv_transfer[2][5];
				'd30:	Img_ready_comb[1][4] = deconv_transfer[2][6];
				'd31:	Img_ready_comb[1][4] = deconv_transfer[2][7];
				'd32:	Img_ready_comb[1][4] = 'd0;
				'd33:	Img_ready_comb[1][4] = 'd0;
				'd34:	Img_ready_comb[1][4] = 'd0;
				'd35:	Img_ready_comb[1][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = deconv_transfer[3][0];
				'd1 :	Img_ready_comb[2][4] = deconv_transfer[3][1];
				'd2 :	Img_ready_comb[2][4] = deconv_transfer[3][2];
				'd3 :	Img_ready_comb[2][4] = deconv_transfer[3][3];
				'd4 :	Img_ready_comb[2][4] = deconv_transfer[3][4];
				'd5 :	Img_ready_comb[2][4] = deconv_transfer[3][5];
				'd6 :	Img_ready_comb[2][4] = deconv_transfer[3][6];
				'd7 :	Img_ready_comb[2][4] = deconv_transfer[3][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[3][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[3][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[3][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[3][3];
						end
				'd12:	Img_ready_comb[2][4] = deconv_transfer[3][4];
				'd13:	Img_ready_comb[2][4] = deconv_transfer[3][5];
				'd14:	Img_ready_comb[2][4] = deconv_transfer[3][6];
				'd15:	Img_ready_comb[2][4] = deconv_transfer[3][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[3][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[3][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[3][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[3][3];
						end
				
				'd20:	Img_ready_comb[2][4] = deconv_transfer[3][4];
				'd21:	Img_ready_comb[2][4] = deconv_transfer[3][5];
				'd22:	Img_ready_comb[2][4] = deconv_transfer[3][6];
				'd23:	Img_ready_comb[2][4] = deconv_transfer[3][7];
				'd24:	Img_ready_comb[2][4] = deconv_transfer[3][0];
				'd25:	Img_ready_comb[2][4] = deconv_transfer[3][1];
				'd26:	Img_ready_comb[2][4] = deconv_transfer[3][2];
				'd27:	Img_ready_comb[2][4] = deconv_transfer[3][3];
				'd28:	Img_ready_comb[2][4] = deconv_transfer[3][4];
				'd29:	Img_ready_comb[2][4] = deconv_transfer[3][5];
				'd30:	Img_ready_comb[2][4] = deconv_transfer[3][6];
				'd31:	Img_ready_comb[2][4] = deconv_transfer[3][7];
				'd32:	Img_ready_comb[2][4] = 'd0;
				'd33:	Img_ready_comb[2][4] = 'd0;
				'd34:	Img_ready_comb[2][4] = 'd0;
				'd35:	Img_ready_comb[2][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = deconv_transfer[4][0];
				'd1 :	Img_ready_comb[3][4] = deconv_transfer[4][1];
				'd2 :	Img_ready_comb[3][4] = deconv_transfer[4][2];
				'd3 :	Img_ready_comb[3][4] = deconv_transfer[4][3];
				'd4 :	Img_ready_comb[3][4] = deconv_transfer[4][4];
				'd5 :	Img_ready_comb[3][4] = deconv_transfer[4][5];
				'd6 :	Img_ready_comb[3][4] = deconv_transfer[4][6];
				'd7 :	Img_ready_comb[3][4] = deconv_transfer[4][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[4][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[4][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[4][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[4][3];
						end
				'd12:	Img_ready_comb[3][4] = deconv_transfer[4][4];
				'd13:	Img_ready_comb[3][4] = deconv_transfer[4][5];
				'd14:	Img_ready_comb[3][4] = deconv_transfer[4][6];
				'd15:	Img_ready_comb[3][4] = deconv_transfer[4][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[4][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[4][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[4][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[4][3];
						end
				
				'd20:	Img_ready_comb[3][4] = deconv_transfer[4][4];
				'd21:	Img_ready_comb[3][4] = deconv_transfer[4][5];
				'd22:	Img_ready_comb[3][4] = deconv_transfer[4][6];
				'd23:	Img_ready_comb[3][4] = deconv_transfer[4][7];
				'd24:	Img_ready_comb[3][4] = deconv_transfer[4][0];
				'd25:	Img_ready_comb[3][4] = deconv_transfer[4][1];
				'd26:	Img_ready_comb[3][4] = deconv_transfer[4][2];
				'd27:	Img_ready_comb[3][4] = deconv_transfer[4][3];
				'd28:	Img_ready_comb[3][4] = deconv_transfer[4][4];
				'd29:	Img_ready_comb[3][4] = deconv_transfer[4][5];
				'd30:	Img_ready_comb[3][4] = deconv_transfer[4][6];
				'd31:	Img_ready_comb[3][4] = deconv_transfer[4][7];
				'd32:	Img_ready_comb[3][4] = 'd0;
				'd33:	Img_ready_comb[3][4] = 'd0;
				'd34:	Img_ready_comb[3][4] = 'd0;
				'd35:	Img_ready_comb[3][4] = 'd0;
			endcase
		end
		else if(row_count == deconv_row_end + 'd1) begin
			Img_ready_comb[0][0] = Img_ready[0][1];
			Img_ready_comb[1][0] = Img_ready[1][1];
			Img_ready_comb[2][0] = Img_ready[2][1];
			Img_ready_comb[3][0] = 'd0;
			Img_ready_comb[4][0] = 'd0;
			Img_ready_comb[0][1] = Img_ready[0][2];
			Img_ready_comb[1][1] = Img_ready[1][2];
			Img_ready_comb[2][1] = Img_ready[2][2];
			Img_ready_comb[3][1] = 'd0;
			Img_ready_comb[4][1] = 'd0;
			Img_ready_comb[0][2] = Img_ready[0][3];
			Img_ready_comb[1][2] = Img_ready[1][3];
			Img_ready_comb[2][2] = Img_ready[2][3];
			Img_ready_comb[3][2] = 'd0;
			Img_ready_comb[4][2] = 'd0;
			Img_ready_comb[0][3] = Img_ready[0][4];
			Img_ready_comb[1][3] = Img_ready[1][4];
			Img_ready_comb[2][3] = Img_ready[2][4];
			Img_ready_comb[3][3] = 'd0;
			Img_ready_comb[4][3] = 'd0;
			Img_ready_comb[3][4] = 'd0;
			Img_ready_comb[4][4] = 'd0;
			
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = deconv_transfer[2][0];
				'd1 :	Img_ready_comb[0][4] = deconv_transfer[2][1];
				'd2 :	Img_ready_comb[0][4] = deconv_transfer[2][2];
				'd3 :	Img_ready_comb[0][4] = deconv_transfer[2][3];
				'd4 :	Img_ready_comb[0][4] = deconv_transfer[2][4];
				'd5 :	Img_ready_comb[0][4] = deconv_transfer[2][5];
				'd6 :	Img_ready_comb[0][4] = deconv_transfer[2][6];
				'd7 :	Img_ready_comb[0][4] = deconv_transfer[2][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[2][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[2][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[2][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[2][3];
						end
				'd12:	Img_ready_comb[0][4] = deconv_transfer[2][4];
				'd13:	Img_ready_comb[0][4] = deconv_transfer[2][5];
				'd14:	Img_ready_comb[0][4] = deconv_transfer[2][6];
				'd15:	Img_ready_comb[0][4] = deconv_transfer[2][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[2][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[2][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[2][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[2][3];
						end
				
				'd20:	Img_ready_comb[0][4] = deconv_transfer[2][4];
				'd21:	Img_ready_comb[0][4] = deconv_transfer[2][5];
				'd22:	Img_ready_comb[0][4] = deconv_transfer[2][6];
				'd23:	Img_ready_comb[0][4] = deconv_transfer[2][7];
				'd24:	Img_ready_comb[0][4] = deconv_transfer[2][0];
				'd25:	Img_ready_comb[0][4] = deconv_transfer[2][1];
				'd26:	Img_ready_comb[0][4] = deconv_transfer[2][2];
				'd27:	Img_ready_comb[0][4] = deconv_transfer[2][3];
				'd28:	Img_ready_comb[0][4] = deconv_transfer[2][4];
				'd29:	Img_ready_comb[0][4] = deconv_transfer[2][5];
				'd30:	Img_ready_comb[0][4] = deconv_transfer[2][6];
				'd31:	Img_ready_comb[0][4] = deconv_transfer[2][7];
				'd32:	Img_ready_comb[0][4] = 'd0;
				'd33:	Img_ready_comb[0][4] = 'd0;
				'd34:	Img_ready_comb[0][4] = 'd0;
				'd35:	Img_ready_comb[0][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = deconv_transfer[3][0];
				'd1 :	Img_ready_comb[1][4] = deconv_transfer[3][1];
				'd2 :	Img_ready_comb[1][4] = deconv_transfer[3][2];
				'd3 :	Img_ready_comb[1][4] = deconv_transfer[3][3];
				'd4 :	Img_ready_comb[1][4] = deconv_transfer[3][4];
				'd5 :	Img_ready_comb[1][4] = deconv_transfer[3][5];
				'd6 :	Img_ready_comb[1][4] = deconv_transfer[3][6];
				'd7 :	Img_ready_comb[1][4] = deconv_transfer[3][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[3][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[3][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[3][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[3][3];
						end
				'd12:	Img_ready_comb[1][4] = deconv_transfer[3][4];
				'd13:	Img_ready_comb[1][4] = deconv_transfer[3][5];
				'd14:	Img_ready_comb[1][4] = deconv_transfer[3][6];
				'd15:	Img_ready_comb[1][4] = deconv_transfer[3][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[3][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[3][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[3][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[3][3];
						end
				
				'd20:	Img_ready_comb[1][4] = deconv_transfer[3][4];
				'd21:	Img_ready_comb[1][4] = deconv_transfer[3][5];
				'd22:	Img_ready_comb[1][4] = deconv_transfer[3][6];
				'd23:	Img_ready_comb[1][4] = deconv_transfer[3][7];
				'd24:	Img_ready_comb[1][4] = deconv_transfer[3][0];
				'd25:	Img_ready_comb[1][4] = deconv_transfer[3][1];
				'd26:	Img_ready_comb[1][4] = deconv_transfer[3][2];
				'd27:	Img_ready_comb[1][4] = deconv_transfer[3][3];
				'd28:	Img_ready_comb[1][4] = deconv_transfer[3][4];
				'd29:	Img_ready_comb[1][4] = deconv_transfer[3][5];
				'd30:	Img_ready_comb[1][4] = deconv_transfer[3][6];
				'd31:	Img_ready_comb[1][4] = deconv_transfer[3][7];
				'd32:	Img_ready_comb[1][4] = 'd0;
				'd33:	Img_ready_comb[1][4] = 'd0;
				'd34:	Img_ready_comb[1][4] = 'd0;
				'd35:	Img_ready_comb[1][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = deconv_transfer[4][0];
				'd1 :	Img_ready_comb[2][4] = deconv_transfer[4][1];
				'd2 :	Img_ready_comb[2][4] = deconv_transfer[4][2];
				'd3 :	Img_ready_comb[2][4] = deconv_transfer[4][3];
				'd4 :	Img_ready_comb[2][4] = deconv_transfer[4][4];
				'd5 :	Img_ready_comb[2][4] = deconv_transfer[4][5];
				'd6 :	Img_ready_comb[2][4] = deconv_transfer[4][6];
				'd7 :	Img_ready_comb[2][4] = deconv_transfer[4][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[4][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[4][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[4][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[4][3];
						end
				'd12:	Img_ready_comb[2][4] = deconv_transfer[4][4];
				'd13:	Img_ready_comb[2][4] = deconv_transfer[4][5];
				'd14:	Img_ready_comb[2][4] = deconv_transfer[4][6];
				'd15:	Img_ready_comb[2][4] = deconv_transfer[4][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[4][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[4][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[4][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[4][3];
						end
				
				'd20:	Img_ready_comb[2][4] = deconv_transfer[4][4];
				'd21:	Img_ready_comb[2][4] = deconv_transfer[4][5];
				'd22:	Img_ready_comb[2][4] = deconv_transfer[4][6];
				'd23:	Img_ready_comb[2][4] = deconv_transfer[4][7];
				'd24:	Img_ready_comb[2][4] = deconv_transfer[4][0];
				'd25:	Img_ready_comb[2][4] = deconv_transfer[4][1];
				'd26:	Img_ready_comb[2][4] = deconv_transfer[4][2];
				'd27:	Img_ready_comb[2][4] = deconv_transfer[4][3];
				'd28:	Img_ready_comb[2][4] = deconv_transfer[4][4];
				'd29:	Img_ready_comb[2][4] = deconv_transfer[4][5];
				'd30:	Img_ready_comb[2][4] = deconv_transfer[4][6];
				'd31:	Img_ready_comb[2][4] = deconv_transfer[4][7];
				'd32:	Img_ready_comb[2][4] = 'd0;
				'd33:	Img_ready_comb[2][4] = 'd0;
				'd34:	Img_ready_comb[2][4] = 'd0;
				'd35:	Img_ready_comb[2][4] = 'd0;
			endcase
		end
		else if(row_count == deconv_row_end + 'd2) begin
			Img_ready_comb[0][0] = Img_ready[0][1];
			Img_ready_comb[1][0] = Img_ready[1][1];
			Img_ready_comb[2][0] = 'd0;
			Img_ready_comb[3][0] = 'd0;
			Img_ready_comb[4][0] = 'd0;
			Img_ready_comb[0][1] = Img_ready[0][2];
			Img_ready_comb[1][1] = Img_ready[1][2];
			Img_ready_comb[2][1] = 'd0;
			Img_ready_comb[3][1] = 'd0;
			Img_ready_comb[4][1] = 'd0;
			Img_ready_comb[0][2] = Img_ready[0][3];
			Img_ready_comb[1][2] = Img_ready[1][3];
			Img_ready_comb[2][2] = 'd0;
			Img_ready_comb[3][2] = 'd0;
			Img_ready_comb[4][2] = 'd0;
			Img_ready_comb[0][3] = Img_ready[0][4];
			Img_ready_comb[1][3] = Img_ready[1][4];
			Img_ready_comb[2][3] = 'd0;
			Img_ready_comb[3][3] = 'd0;
			Img_ready_comb[4][3] = 'd0;
			Img_ready_comb[2][4] = 'd0;
			Img_ready_comb[3][4] = 'd0;
			Img_ready_comb[4][4] = 'd0;
			
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = deconv_transfer[3][0];
				'd1 :	Img_ready_comb[0][4] = deconv_transfer[3][1];
				'd2 :	Img_ready_comb[0][4] = deconv_transfer[3][2];
				'd3 :	Img_ready_comb[0][4] = deconv_transfer[3][3];
				'd4 :	Img_ready_comb[0][4] = deconv_transfer[3][4];
				'd5 :	Img_ready_comb[0][4] = deconv_transfer[3][5];
				'd6 :	Img_ready_comb[0][4] = deconv_transfer[3][6];
				'd7 :	Img_ready_comb[0][4] = deconv_transfer[3][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[3][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[3][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[3][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[3][3];
						end
				'd12:	Img_ready_comb[0][4] = deconv_transfer[3][4];
				'd13:	Img_ready_comb[0][4] = deconv_transfer[3][5];
				'd14:	Img_ready_comb[0][4] = deconv_transfer[3][6];
				'd15:	Img_ready_comb[0][4] = deconv_transfer[3][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[3][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[3][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[3][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[3][3];
						end
				
				'd20:	Img_ready_comb[0][4] = deconv_transfer[3][4];
				'd21:	Img_ready_comb[0][4] = deconv_transfer[3][5];
				'd22:	Img_ready_comb[0][4] = deconv_transfer[3][6];
				'd23:	Img_ready_comb[0][4] = deconv_transfer[3][7];
				'd24:	Img_ready_comb[0][4] = deconv_transfer[3][0];
				'd25:	Img_ready_comb[0][4] = deconv_transfer[3][1];
				'd26:	Img_ready_comb[0][4] = deconv_transfer[3][2];
				'd27:	Img_ready_comb[0][4] = deconv_transfer[3][3];
				'd28:	Img_ready_comb[0][4] = deconv_transfer[3][4];
				'd29:	Img_ready_comb[0][4] = deconv_transfer[3][5];
				'd30:	Img_ready_comb[0][4] = deconv_transfer[3][6];
				'd31:	Img_ready_comb[0][4] = deconv_transfer[3][7];
				'd32:	Img_ready_comb[0][4] = 'd0;
				'd33:	Img_ready_comb[0][4] = 'd0;
				'd34:	Img_ready_comb[0][4] = 'd0;
				'd35:	Img_ready_comb[0][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = deconv_transfer[4][0];
				'd1 :	Img_ready_comb[1][4] = deconv_transfer[4][1];
				'd2 :	Img_ready_comb[1][4] = deconv_transfer[4][2];
				'd3 :	Img_ready_comb[1][4] = deconv_transfer[4][3];
				'd4 :	Img_ready_comb[1][4] = deconv_transfer[4][4];
				'd5 :	Img_ready_comb[1][4] = deconv_transfer[4][5];
				'd6 :	Img_ready_comb[1][4] = deconv_transfer[4][6];
				'd7 :	Img_ready_comb[1][4] = deconv_transfer[4][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[4][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[4][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[4][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[4][3];
						end
				'd12:	Img_ready_comb[1][4] = deconv_transfer[4][4];
				'd13:	Img_ready_comb[1][4] = deconv_transfer[4][5];
				'd14:	Img_ready_comb[1][4] = deconv_transfer[4][6];
				'd15:	Img_ready_comb[1][4] = deconv_transfer[4][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[4][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[4][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[4][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[4][3];
						end
				
				'd20:	Img_ready_comb[1][4] = deconv_transfer[4][4];
				'd21:	Img_ready_comb[1][4] = deconv_transfer[4][5];
				'd22:	Img_ready_comb[1][4] = deconv_transfer[4][6];
				'd23:	Img_ready_comb[1][4] = deconv_transfer[4][7];
				'd24:	Img_ready_comb[1][4] = deconv_transfer[4][0];
				'd25:	Img_ready_comb[1][4] = deconv_transfer[4][1];
				'd26:	Img_ready_comb[1][4] = deconv_transfer[4][2];
				'd27:	Img_ready_comb[1][4] = deconv_transfer[4][3];
				'd28:	Img_ready_comb[1][4] = deconv_transfer[4][4];
				'd29:	Img_ready_comb[1][4] = deconv_transfer[4][5];
				'd30:	Img_ready_comb[1][4] = deconv_transfer[4][6];
				'd31:	Img_ready_comb[1][4] = deconv_transfer[4][7];
				'd32:	Img_ready_comb[1][4] = 'd0;
				'd33:	Img_ready_comb[1][4] = 'd0;
				'd34:	Img_ready_comb[1][4] = 'd0;
				'd35:	Img_ready_comb[1][4] = 'd0;
			endcase
		end
		else if(row_count == deconv_row_end + 'd3) begin
			Img_ready_comb[0][0] = Img_ready[0][1];
			Img_ready_comb[1][0] = 'd0;
			Img_ready_comb[2][0] = 'd0;
			Img_ready_comb[3][0] = 'd0;
			Img_ready_comb[4][0] = 'd0;
			Img_ready_comb[0][1] = Img_ready[0][2];
			Img_ready_comb[1][1] = 'd0;
			Img_ready_comb[2][1] = 'd0;
			Img_ready_comb[3][1] = 'd0;
			Img_ready_comb[4][1] = 'd0;
			Img_ready_comb[0][2] = Img_ready[0][3];
			Img_ready_comb[1][2] = 'd0;
			Img_ready_comb[2][2] = 'd0;
			Img_ready_comb[3][2] = 'd0;
			Img_ready_comb[4][2] = 'd0;
			Img_ready_comb[0][3] = Img_ready[0][4];
			Img_ready_comb[1][3] = 'd0;
			Img_ready_comb[2][3] = 'd0;
			Img_ready_comb[3][3] = 'd0;
			Img_ready_comb[4][3] = 'd0;
			Img_ready_comb[1][4] = 'd0;
			Img_ready_comb[2][4] = 'd0;
			Img_ready_comb[3][4] = 'd0;
			Img_ready_comb[4][4] = 'd0;
			
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = deconv_transfer[4][0];
				'd1 :	Img_ready_comb[0][4] = deconv_transfer[4][1];
				'd2 :	Img_ready_comb[0][4] = deconv_transfer[4][2];
				'd3 :	Img_ready_comb[0][4] = deconv_transfer[4][3];
				'd4 :	Img_ready_comb[0][4] = deconv_transfer[4][4];
				'd5 :	Img_ready_comb[0][4] = deconv_transfer[4][5];
				'd6 :	Img_ready_comb[0][4] = deconv_transfer[4][6];
				'd7 :	Img_ready_comb[0][4] = deconv_transfer[4][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[4][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[4][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[4][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[4][3];
						end
				'd12:	Img_ready_comb[0][4] = deconv_transfer[4][4];
				'd13:	Img_ready_comb[0][4] = deconv_transfer[4][5];
				'd14:	Img_ready_comb[0][4] = deconv_transfer[4][6];
				'd15:	Img_ready_comb[0][4] = deconv_transfer[4][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[4][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[4][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[4][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[4][3];
						end
				
				'd20:	Img_ready_comb[0][4] = deconv_transfer[4][4];
				'd21:	Img_ready_comb[0][4] = deconv_transfer[4][5];
				'd22:	Img_ready_comb[0][4] = deconv_transfer[4][6];
				'd23:	Img_ready_comb[0][4] = deconv_transfer[4][7];
				'd24:	Img_ready_comb[0][4] = deconv_transfer[4][0];
				'd25:	Img_ready_comb[0][4] = deconv_transfer[4][1];
				'd26:	Img_ready_comb[0][4] = deconv_transfer[4][2];
				'd27:	Img_ready_comb[0][4] = deconv_transfer[4][3];
				'd28:	Img_ready_comb[0][4] = deconv_transfer[4][4];
				'd29:	Img_ready_comb[0][4] = deconv_transfer[4][5];
				'd30:	Img_ready_comb[0][4] = deconv_transfer[4][6];
				'd31:	Img_ready_comb[0][4] = deconv_transfer[4][7];
				'd32:	Img_ready_comb[0][4] = 'd0;
				'd33:	Img_ready_comb[0][4] = 'd0;
				'd34:	Img_ready_comb[0][4] = 'd0;
				'd35:	Img_ready_comb[0][4] = 'd0;
			endcase
		end
		else begin
			Img_ready_comb[0][0] = Img_ready[0][1];
			Img_ready_comb[1][0] = Img_ready[1][1];
			Img_ready_comb[2][0] = Img_ready[2][1];
			Img_ready_comb[3][0] = Img_ready[3][1];
			Img_ready_comb[4][0] = Img_ready[4][1];
			Img_ready_comb[0][1] = Img_ready[0][2];
			Img_ready_comb[1][1] = Img_ready[1][2];
			Img_ready_comb[2][1] = Img_ready[2][2];
			Img_ready_comb[3][1] = Img_ready[3][2];
			Img_ready_comb[4][1] = Img_ready[4][2];
			Img_ready_comb[0][2] = Img_ready[0][3];
			Img_ready_comb[1][2] = Img_ready[1][3];
			Img_ready_comb[2][2] = Img_ready[2][3];
			Img_ready_comb[3][2] = Img_ready[3][3];
			Img_ready_comb[4][2] = Img_ready[4][3];
			Img_ready_comb[0][3] = Img_ready[0][4];
			Img_ready_comb[1][3] = Img_ready[1][4];
			Img_ready_comb[2][3] = Img_ready[2][4];
			Img_ready_comb[3][3] = Img_ready[3][4];
			Img_ready_comb[4][3] = Img_ready[4][4];
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = deconv_transfer[0][0];
				'd1 :	Img_ready_comb[0][4] = deconv_transfer[0][1];
				'd2 :	Img_ready_comb[0][4] = deconv_transfer[0][2];
				'd3 :	Img_ready_comb[0][4] = deconv_transfer[0][3];
				'd4 :	Img_ready_comb[0][4] = deconv_transfer[0][4];
				'd5 :	Img_ready_comb[0][4] = deconv_transfer[0][5];
				'd6 :	Img_ready_comb[0][4] = deconv_transfer[0][6];
				'd7 :	Img_ready_comb[0][4] = deconv_transfer[0][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[0][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[0][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[0][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[0][3];
						end
				'd12:	Img_ready_comb[0][4] = deconv_transfer[0][4];
				'd13:	Img_ready_comb[0][4] = deconv_transfer[0][5];
				'd14:	Img_ready_comb[0][4] = deconv_transfer[0][6];
				'd15:	Img_ready_comb[0][4] = deconv_transfer[0][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[0][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[0][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[0][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[0][4] = 'd0;
							else 							Img_ready_comb[0][4] = deconv_transfer[0][3];
						end
				
				'd20:	Img_ready_comb[0][4] = deconv_transfer[0][4];
				'd21:	Img_ready_comb[0][4] = deconv_transfer[0][5];
				'd22:	Img_ready_comb[0][4] = deconv_transfer[0][6];
				'd23:	Img_ready_comb[0][4] = deconv_transfer[0][7];
				'd24:	Img_ready_comb[0][4] = deconv_transfer[0][0];
				'd25:	Img_ready_comb[0][4] = deconv_transfer[0][1];
				'd26:	Img_ready_comb[0][4] = deconv_transfer[0][2];
				'd27:	Img_ready_comb[0][4] = deconv_transfer[0][3];
				'd28:	Img_ready_comb[0][4] = deconv_transfer[0][4];
				'd29:	Img_ready_comb[0][4] = deconv_transfer[0][5];
				'd30:	Img_ready_comb[0][4] = deconv_transfer[0][6];
				'd31:	Img_ready_comb[0][4] = deconv_transfer[0][7];
				'd32:	Img_ready_comb[0][4] = 'd0;
				'd33:	Img_ready_comb[0][4] = 'd0;
				'd34:	Img_ready_comb[0][4] = 'd0;
				'd35:	Img_ready_comb[0][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = deconv_transfer[1][0];
				'd1 :	Img_ready_comb[1][4] = deconv_transfer[1][1];
				'd2 :	Img_ready_comb[1][4] = deconv_transfer[1][2];
				'd3 :	Img_ready_comb[1][4] = deconv_transfer[1][3];
				'd4 :	Img_ready_comb[1][4] = deconv_transfer[1][4];
				'd5 :	Img_ready_comb[1][4] = deconv_transfer[1][5];
				'd6 :	Img_ready_comb[1][4] = deconv_transfer[1][6];
				'd7 :	Img_ready_comb[1][4] = deconv_transfer[1][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[1][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[1][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[1][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[1][3];
						end
				'd12:	Img_ready_comb[1][4] = deconv_transfer[1][4];
				'd13:	Img_ready_comb[1][4] = deconv_transfer[1][5];
				'd14:	Img_ready_comb[1][4] = deconv_transfer[1][6];
				'd15:	Img_ready_comb[1][4] = deconv_transfer[1][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[1][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[1][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[1][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[1][4] = 'd0;
							else 							Img_ready_comb[1][4] = deconv_transfer[1][3];
						end
				
				'd20:	Img_ready_comb[1][4] = deconv_transfer[1][4];
				'd21:	Img_ready_comb[1][4] = deconv_transfer[1][5];
				'd22:	Img_ready_comb[1][4] = deconv_transfer[1][6];
				'd23:	Img_ready_comb[1][4] = deconv_transfer[1][7];
				'd24:	Img_ready_comb[1][4] = deconv_transfer[1][0];
				'd25:	Img_ready_comb[1][4] = deconv_transfer[1][1];
				'd26:	Img_ready_comb[1][4] = deconv_transfer[1][2];
				'd27:	Img_ready_comb[1][4] = deconv_transfer[1][3];
				'd28:	Img_ready_comb[1][4] = deconv_transfer[1][4];
				'd29:	Img_ready_comb[1][4] = deconv_transfer[1][5];
				'd30:	Img_ready_comb[1][4] = deconv_transfer[1][6];
				'd31:	Img_ready_comb[1][4] = deconv_transfer[1][7];
				'd32:	Img_ready_comb[1][4] = 'd0;
				'd33:	Img_ready_comb[1][4] = 'd0;
				'd34:	Img_ready_comb[1][4] = 'd0;
				'd35:	Img_ready_comb[1][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = deconv_transfer[2][0];
				'd1 :	Img_ready_comb[2][4] = deconv_transfer[2][1];
				'd2 :	Img_ready_comb[2][4] = deconv_transfer[2][2];
				'd3 :	Img_ready_comb[2][4] = deconv_transfer[2][3];
				'd4 :	Img_ready_comb[2][4] = deconv_transfer[2][4];
				'd5 :	Img_ready_comb[2][4] = deconv_transfer[2][5];
				'd6 :	Img_ready_comb[2][4] = deconv_transfer[2][6];
				'd7 :	Img_ready_comb[2][4] = deconv_transfer[2][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[2][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[2][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[2][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[2][3];
						end
				'd12:	Img_ready_comb[2][4] = deconv_transfer[2][4];
				'd13:	Img_ready_comb[2][4] = deconv_transfer[2][5];
				'd14:	Img_ready_comb[2][4] = deconv_transfer[2][6];
				'd15:	Img_ready_comb[2][4] = deconv_transfer[2][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[2][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[2][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[2][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[2][4] = 'd0;
							else 							Img_ready_comb[2][4] = deconv_transfer[2][3];
						end
				
				'd20:	Img_ready_comb[2][4] = deconv_transfer[2][4];
				'd21:	Img_ready_comb[2][4] = deconv_transfer[2][5];
				'd22:	Img_ready_comb[2][4] = deconv_transfer[2][6];
				'd23:	Img_ready_comb[2][4] = deconv_transfer[2][7];
				'd24:	Img_ready_comb[2][4] = deconv_transfer[2][0];
				'd25:	Img_ready_comb[2][4] = deconv_transfer[2][1];
				'd26:	Img_ready_comb[2][4] = deconv_transfer[2][2];
				'd27:	Img_ready_comb[2][4] = deconv_transfer[2][3];
				'd28:	Img_ready_comb[2][4] = deconv_transfer[2][4];
				'd29:	Img_ready_comb[2][4] = deconv_transfer[2][5];
				'd30:	Img_ready_comb[2][4] = deconv_transfer[2][6];
				'd31:	Img_ready_comb[2][4] = deconv_transfer[2][7];
				'd32:	Img_ready_comb[2][4] = 'd0;
				'd33:	Img_ready_comb[2][4] = 'd0;
				'd34:	Img_ready_comb[2][4] = 'd0;
				'd35:	Img_ready_comb[2][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = deconv_transfer[3][0];
				'd1 :	Img_ready_comb[3][4] = deconv_transfer[3][1];
				'd2 :	Img_ready_comb[3][4] = deconv_transfer[3][2];
				'd3 :	Img_ready_comb[3][4] = deconv_transfer[3][3];
				'd4 :	Img_ready_comb[3][4] = deconv_transfer[3][4];
				'd5 :	Img_ready_comb[3][4] = deconv_transfer[3][5];
				'd6 :	Img_ready_comb[3][4] = deconv_transfer[3][6];
				'd7 :	Img_ready_comb[3][4] = deconv_transfer[3][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[3][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[3][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[3][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[3][3];
						end
				'd12:	Img_ready_comb[3][4] = deconv_transfer[3][4];
				'd13:	Img_ready_comb[3][4] = deconv_transfer[3][5];
				'd14:	Img_ready_comb[3][4] = deconv_transfer[3][6];
				'd15:	Img_ready_comb[3][4] = deconv_transfer[3][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[3][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[3][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[3][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[3][4] = 'd0;
							else 							Img_ready_comb[3][4] = deconv_transfer[3][3];
						end
				
				'd20:	Img_ready_comb[3][4] = deconv_transfer[3][4];
				'd21:	Img_ready_comb[3][4] = deconv_transfer[3][5];
				'd22:	Img_ready_comb[3][4] = deconv_transfer[3][6];
				'd23:	Img_ready_comb[3][4] = deconv_transfer[3][7];
				'd24:	Img_ready_comb[3][4] = deconv_transfer[3][0];
				'd25:	Img_ready_comb[3][4] = deconv_transfer[3][1];
				'd26:	Img_ready_comb[3][4] = deconv_transfer[3][2];
				'd27:	Img_ready_comb[3][4] = deconv_transfer[3][3];
				'd28:	Img_ready_comb[3][4] = deconv_transfer[3][4];
				'd29:	Img_ready_comb[3][4] = deconv_transfer[3][5];
				'd30:	Img_ready_comb[3][4] = deconv_transfer[3][6];
				'd31:	Img_ready_comb[3][4] = deconv_transfer[3][7];
				'd32:	Img_ready_comb[3][4] = 'd0;
				'd33:	Img_ready_comb[3][4] = 'd0;
				'd34:	Img_ready_comb[3][4] = 'd0;
				'd35:	Img_ready_comb[3][4] = 'd0;
			endcase
			case(block_count) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = deconv_transfer[4][0];
				'd1 :	Img_ready_comb[4][4] = deconv_transfer[4][1];
				'd2 :	Img_ready_comb[4][4] = deconv_transfer[4][2];
				'd3 :	Img_ready_comb[4][4] = deconv_transfer[4][3];
				'd4 :	Img_ready_comb[4][4] = deconv_transfer[4][4];
				'd5 :	Img_ready_comb[4][4] = deconv_transfer[4][5];
				'd6 :	Img_ready_comb[4][4] = deconv_transfer[4][6];
				'd7 :	Img_ready_comb[4][4] = deconv_transfer[4][7];
				'd8 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[4][0];
						end
				'd9 :	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[4][1];
						end
				'd10:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[4][2];
						end
				'd11:	begin
							if(matrix_size_store == 'd7)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[4][3];
						end
				'd12:	Img_ready_comb[4][4] = deconv_transfer[4][4];
				'd13:	Img_ready_comb[4][4] = deconv_transfer[4][5];
				'd14:	Img_ready_comb[4][4] = deconv_transfer[4][6];
				'd15:	Img_ready_comb[4][4] = deconv_transfer[4][7];
				'd16:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[4][0];
						end
				'd17:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[4][1];
						end
				'd18:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[4][2];
						end
				'd19:	begin
							if(matrix_size_store == 'd15)	Img_ready_comb[4][4] = 'd0;
							else 							Img_ready_comb[4][4] = deconv_transfer[4][3];
						end
				
				'd20:	Img_ready_comb[4][4] = deconv_transfer[4][4];
				'd21:	Img_ready_comb[4][4] = deconv_transfer[4][5];
				'd22:	Img_ready_comb[4][4] = deconv_transfer[4][6];
				'd23:	Img_ready_comb[4][4] = deconv_transfer[4][7];
				'd24:	Img_ready_comb[4][4] = deconv_transfer[4][0];
				'd25:	Img_ready_comb[4][4] = deconv_transfer[4][1];
				'd26:	Img_ready_comb[4][4] = deconv_transfer[4][2];
				'd27:	Img_ready_comb[4][4] = deconv_transfer[4][3];
				'd28:	Img_ready_comb[4][4] = deconv_transfer[4][4];
				'd29:	Img_ready_comb[4][4] = deconv_transfer[4][5];
				'd30:	Img_ready_comb[4][4] = deconv_transfer[4][6];
				'd31:	Img_ready_comb[4][4] = deconv_transfer[4][7];
				'd32:	Img_ready_comb[4][4] = 'd0;
				'd33:	Img_ready_comb[4][4] = 'd0;
				'd34:	Img_ready_comb[4][4] = 'd0;
				'd35:	Img_ready_comb[4][4] = 'd0;
			endcase
		end
	end	
	else if(state == CONV && (count_28 == 'd0 || count_28 == 'd19)) begin
		if(shift_window_count == 'd0) begin
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][0] = Img_SRAM_Data_split[0][0];
				'd1 :	Img_ready_comb[0][0] = Img_SRAM_Data_split[1][0];
				'd2 :	Img_ready_comb[0][0] = Img_SRAM_Data_split[2][0];
				'd3 :	Img_ready_comb[0][0] = Img_SRAM_Data_split[3][0];
				'd4 :	Img_ready_comb[0][0] = Img_SRAM_Data_split[4][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][0] = Img_SRAM_Data_split[1][0];
				'd1 :	Img_ready_comb[1][0] = Img_SRAM_Data_split[2][0];
				'd2 :	Img_ready_comb[1][0] = Img_SRAM_Data_split[3][0];
				'd3 :	Img_ready_comb[1][0] = Img_SRAM_Data_split[4][0];
				'd4 :	Img_ready_comb[1][0] = Img_SRAM_Data_split[0][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][0] = Img_SRAM_Data_split[2][0];
				'd1 :	Img_ready_comb[2][0] = Img_SRAM_Data_split[3][0];
				'd2 :	Img_ready_comb[2][0] = Img_SRAM_Data_split[4][0];
				'd3 :	Img_ready_comb[2][0] = Img_SRAM_Data_split[0][0];
				'd4 :	Img_ready_comb[2][0] = Img_SRAM_Data_split[1][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][0] = Img_SRAM_Data_split[3][0];
				'd1 :	Img_ready_comb[3][0] = Img_SRAM_Data_split[4][0];
				'd2 :	Img_ready_comb[3][0] = Img_SRAM_Data_split[0][0];
				'd3 :	Img_ready_comb[3][0] = Img_SRAM_Data_split[1][0];
				'd4 :	Img_ready_comb[3][0] = Img_SRAM_Data_split[2][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][0] = Img_SRAM_Data_split[4][0];
				'd1 :	Img_ready_comb[4][0] = Img_SRAM_Data_split[0][0];
				'd2 :	Img_ready_comb[4][0] = Img_SRAM_Data_split[1][0];
				'd3 :	Img_ready_comb[4][0] = Img_SRAM_Data_split[2][0];
				'd4 :	Img_ready_comb[4][0] = Img_SRAM_Data_split[3][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][1] = Img_SRAM_Data_split[0][1];
				'd1 :	Img_ready_comb[0][1] = Img_SRAM_Data_split[1][1];
				'd2 :	Img_ready_comb[0][1] = Img_SRAM_Data_split[2][1];
				'd3 :	Img_ready_comb[0][1] = Img_SRAM_Data_split[3][1];
				'd4 :	Img_ready_comb[0][1] = Img_SRAM_Data_split[4][1];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][1] = Img_SRAM_Data_split[1][1];
				'd1 :	Img_ready_comb[1][1] = Img_SRAM_Data_split[2][1];
				'd2 :	Img_ready_comb[1][1] = Img_SRAM_Data_split[3][1];
				'd3 :	Img_ready_comb[1][1] = Img_SRAM_Data_split[4][1];
				'd4 :	Img_ready_comb[1][1] = Img_SRAM_Data_split[0][1];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][1] = Img_SRAM_Data_split[2][1];
				'd1 :	Img_ready_comb[2][1] = Img_SRAM_Data_split[3][1];
				'd2 :	Img_ready_comb[2][1] = Img_SRAM_Data_split[4][1];
				'd3 :	Img_ready_comb[2][1] = Img_SRAM_Data_split[0][1];
				'd4 :	Img_ready_comb[2][1] = Img_SRAM_Data_split[1][1];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][1] = Img_SRAM_Data_split[3][1];
				'd1 :	Img_ready_comb[3][1] = Img_SRAM_Data_split[4][1];
				'd2 :	Img_ready_comb[3][1] = Img_SRAM_Data_split[0][1];
				'd3 :	Img_ready_comb[3][1] = Img_SRAM_Data_split[1][1];
				'd4 :	Img_ready_comb[3][1] = Img_SRAM_Data_split[2][1];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][1] = Img_SRAM_Data_split[4][1];
				'd1 :	Img_ready_comb[4][1] = Img_SRAM_Data_split[0][1];
				'd2 :	Img_ready_comb[4][1] = Img_SRAM_Data_split[1][1];
				'd3 :	Img_ready_comb[4][1] = Img_SRAM_Data_split[2][1];
				'd4 :	Img_ready_comb[4][1] = Img_SRAM_Data_split[3][1];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][2] = Img_SRAM_Data_split[0][2];
				'd1 :	Img_ready_comb[0][2] = Img_SRAM_Data_split[1][2];
				'd2 :	Img_ready_comb[0][2] = Img_SRAM_Data_split[2][2];
				'd3 :	Img_ready_comb[0][2] = Img_SRAM_Data_split[3][2];
				'd4 :	Img_ready_comb[0][2] = Img_SRAM_Data_split[4][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][2] = Img_SRAM_Data_split[1][2];
				'd1 :	Img_ready_comb[1][2] = Img_SRAM_Data_split[2][2];
				'd2 :	Img_ready_comb[1][2] = Img_SRAM_Data_split[3][2];
				'd3 :	Img_ready_comb[1][2] = Img_SRAM_Data_split[4][2];
				'd4 :	Img_ready_comb[1][2] = Img_SRAM_Data_split[0][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][2] = Img_SRAM_Data_split[2][2];
				'd1 :	Img_ready_comb[2][2] = Img_SRAM_Data_split[3][2];
				'd2 :	Img_ready_comb[2][2] = Img_SRAM_Data_split[4][2];
				'd3 :	Img_ready_comb[2][2] = Img_SRAM_Data_split[0][2];
				'd4 :	Img_ready_comb[2][2] = Img_SRAM_Data_split[1][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][2] = Img_SRAM_Data_split[3][2];
				'd1 :	Img_ready_comb[3][2] = Img_SRAM_Data_split[4][2];
				'd2 :	Img_ready_comb[3][2] = Img_SRAM_Data_split[0][2];
				'd3 :	Img_ready_comb[3][2] = Img_SRAM_Data_split[1][2];
				'd4 :	Img_ready_comb[3][2] = Img_SRAM_Data_split[2][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][2] = Img_SRAM_Data_split[4][2];
				'd1 :	Img_ready_comb[4][2] = Img_SRAM_Data_split[0][2];
				'd2 :	Img_ready_comb[4][2] = Img_SRAM_Data_split[1][2];
				'd3 :	Img_ready_comb[4][2] = Img_SRAM_Data_split[2][2];
				'd4 :	Img_ready_comb[4][2] = Img_SRAM_Data_split[3][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][3] = Img_SRAM_Data_split[0][3];
				'd1 :	Img_ready_comb[0][3] = Img_SRAM_Data_split[1][3];
				'd2 :	Img_ready_comb[0][3] = Img_SRAM_Data_split[2][3];
				'd3 :	Img_ready_comb[0][3] = Img_SRAM_Data_split[3][3];
				'd4 :	Img_ready_comb[0][3] = Img_SRAM_Data_split[4][3];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][3] = Img_SRAM_Data_split[1][3];
				'd1 :	Img_ready_comb[1][3] = Img_SRAM_Data_split[2][3];
				'd2 :	Img_ready_comb[1][3] = Img_SRAM_Data_split[3][3];
				'd3 :	Img_ready_comb[1][3] = Img_SRAM_Data_split[4][3];
				'd4 :	Img_ready_comb[1][3] = Img_SRAM_Data_split[0][3];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][3] = Img_SRAM_Data_split[2][3];
				'd1 :	Img_ready_comb[2][3] = Img_SRAM_Data_split[3][3];
				'd2 :	Img_ready_comb[2][3] = Img_SRAM_Data_split[4][3];
				'd3 :	Img_ready_comb[2][3] = Img_SRAM_Data_split[0][3];
				'd4 :	Img_ready_comb[2][3] = Img_SRAM_Data_split[1][3];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][3] = Img_SRAM_Data_split[3][3];
				'd1 :	Img_ready_comb[3][3] = Img_SRAM_Data_split[4][3];
				'd2 :	Img_ready_comb[3][3] = Img_SRAM_Data_split[0][3];
				'd3 :	Img_ready_comb[3][3] = Img_SRAM_Data_split[1][3];
				'd4 :	Img_ready_comb[3][3] = Img_SRAM_Data_split[2][3];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][3] = Img_SRAM_Data_split[4][3];
				'd1 :	Img_ready_comb[4][3] = Img_SRAM_Data_split[0][3];
				'd2 :	Img_ready_comb[4][3] = Img_SRAM_Data_split[1][3];
				'd3 :	Img_ready_comb[4][3] = Img_SRAM_Data_split[2][3];
				'd4 :	Img_ready_comb[4][3] = Img_SRAM_Data_split[3][3];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[0][4];
				'd1 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[1][4];
				'd2 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[2][4];
				'd3 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[3][4];
				'd4 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[4][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[1][4];
				'd1 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[2][4];
				'd2 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[3][4];
				'd3 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[4][4];
				'd4 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[0][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[2][4];
				'd1 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[3][4];
				'd2 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[4][4];
				'd3 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[0][4];
				'd4 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[1][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[3][4];
				'd1 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[4][4];
				'd2 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[0][4];
				'd3 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[1][4];
				'd4 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[2][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[4][4];
				'd1 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[0][4];
				'd2 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[1][4];
				'd3 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[2][4];
				'd4 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[3][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[0][5];
				'd1 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[1][5];
				'd2 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[2][5];
				'd3 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[3][5];
				'd4 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[4][5];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[1][5];
				'd1 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[2][5];
				'd2 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[3][5];
				'd3 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[4][5];
				'd4 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[0][5];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[2][5];
				'd1 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[3][5];
				'd2 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[4][5];
				'd3 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[0][5];
				'd4 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[1][5];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[3][5];
				'd1 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[4][5];
				'd2 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[0][5];
				'd3 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[1][5];
				'd4 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[2][5];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[4][5];
				'd1 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[0][5];
				'd2 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[1][5];
				'd3 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[2][5];
				'd4 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[3][5];
			endcase
		end
		else if(shift_window_count == 'd1 || shift_window_count == 'd5) begin
			Img_ready_comb[0][0] = Img_ready[0][2];
			Img_ready_comb[0][1] = Img_ready[0][3];
			Img_ready_comb[0][2] = Img_ready[0][4];
			Img_ready_comb[0][3] = Img_ready[0][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[0][6];
				'd1 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[1][6];
				'd2 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[2][6];
				'd3 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[3][6];
				'd4 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[4][6];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[0][7];
				'd1 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[1][7];
				'd2 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[2][7];
				'd3 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[3][7];
				'd4 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[4][7];
			endcase
			Img_ready_comb[1][0] = Img_ready[1][2];
			Img_ready_comb[1][1] = Img_ready[1][3];
			Img_ready_comb[1][2] = Img_ready[1][4];
			Img_ready_comb[1][3] = Img_ready[1][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[1][6];
				'd1 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[2][6];
				'd2 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[3][6];
				'd3 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[4][6];
				'd4 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[0][6];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[1][7];
				'd1 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[2][7];
				'd2 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[3][7];
				'd3 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[4][7];
				'd4 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[0][7];
			endcase
			Img_ready_comb[2][0] = Img_ready[2][2];
			Img_ready_comb[2][1] = Img_ready[2][3];
			Img_ready_comb[2][2] = Img_ready[2][4];
			Img_ready_comb[2][3] = Img_ready[2][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[2][6];
				'd1 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[3][6];
				'd2 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[4][6];
				'd3 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[0][6];
				'd4 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[1][6];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[2][7];
				'd1 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[3][7];
				'd2 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[4][7];
				'd3 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[0][7];
				'd4 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[1][7];
			endcase
			Img_ready_comb[3][0] = Img_ready[3][2];
			Img_ready_comb[3][1] = Img_ready[3][3];
			Img_ready_comb[3][2] = Img_ready[3][4];
			Img_ready_comb[3][3] = Img_ready[3][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[3][6];
				'd1 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[4][6];
				'd2 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[0][6];
				'd3 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[1][6];
				'd4 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[2][6];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[3][7];
				'd1 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[4][7];
				'd2 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[0][7];
				'd3 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[1][7];
				'd4 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[2][7];
			endcase
			Img_ready_comb[4][0] = Img_ready[4][2];
			Img_ready_comb[4][1] = Img_ready[4][3];
			Img_ready_comb[4][2] = Img_ready[4][4];
			Img_ready_comb[4][3] = Img_ready[4][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[4][6];
				'd1 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[0][6];
				'd2 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[1][6];
				'd3 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[2][6];
				'd4 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[3][6];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[4][7];
				'd1 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[0][7];
				'd2 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[1][7];
				'd3 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[2][7];
				'd4 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[3][7];
			endcase
		end
		else if(shift_window_count == 'd2) begin
			Img_ready_comb[0][0] = Img_ready[0][2];
			Img_ready_comb[0][1] = Img_ready[0][3];
			Img_ready_comb[0][2] = Img_ready[0][4];
			Img_ready_comb[0][3] = Img_ready[0][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[0][0];
				'd1 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[1][0];
				'd2 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[2][0];
				'd3 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[3][0];
				'd4 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[4][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[0][1];
				'd1 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[1][1];
				'd2 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[2][1];
				'd3 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[3][1];
				'd4 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[4][1];
			endcase
			Img_ready_comb[1][0] = Img_ready[1][2];
			Img_ready_comb[1][1] = Img_ready[1][3];
			Img_ready_comb[1][2] = Img_ready[1][4];
			Img_ready_comb[1][3] = Img_ready[1][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[1][0];
				'd1 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[2][0];
				'd2 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[3][0];
				'd3 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[4][0];
				'd4 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[0][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[1][1];
				'd1 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[2][1];
				'd2 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[3][1];
				'd3 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[4][1];
				'd4 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[0][1];
			endcase
			Img_ready_comb[2][0] = Img_ready[2][2];
			Img_ready_comb[2][1] = Img_ready[2][3];
			Img_ready_comb[2][2] = Img_ready[2][4];
			Img_ready_comb[2][3] = Img_ready[2][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[2][0];
				'd1 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[3][0];
				'd2 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[4][0];
				'd3 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[0][0];
				'd4 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[1][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[2][1];
				'd1 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[3][1];
				'd2 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[4][1];
				'd3 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[0][1];
				'd4 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[1][1];
			endcase
			Img_ready_comb[3][0] = Img_ready[3][2];
			Img_ready_comb[3][1] = Img_ready[3][3];
			Img_ready_comb[3][2] = Img_ready[3][4];
			Img_ready_comb[3][3] = Img_ready[3][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[3][0];
				'd1 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[4][0];
				'd2 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[0][0];
				'd3 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[1][0];
				'd4 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[2][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[3][1];
				'd1 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[4][1];
				'd2 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[0][1];
				'd3 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[1][1];
				'd4 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[2][1];
			endcase
			Img_ready_comb[4][0] = Img_ready[4][2];
			Img_ready_comb[4][1] = Img_ready[4][3];
			Img_ready_comb[4][2] = Img_ready[4][4];
			Img_ready_comb[4][3] = Img_ready[4][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[4][0];
				'd1 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[0][0];
				'd2 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[1][0];
				'd3 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[2][0];
				'd4 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[3][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[4][1];
				'd1 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[0][1];
				'd2 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[1][1];
				'd3 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[2][1];
				'd4 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[3][1];
			endcase
		end
		else if(shift_window_count == 'd3) begin
			Img_ready_comb[0][0] = Img_ready[0][2];
			Img_ready_comb[0][1] = Img_ready[0][3];
			Img_ready_comb[0][2] = Img_ready[0][4];
			Img_ready_comb[0][3] = Img_ready[0][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[0][2];
				'd1 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[1][2];
				'd2 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[2][2];
				'd3 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[3][2];
				'd4 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[4][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[0][3];
				'd1 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[1][3];
				'd2 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[2][3];
				'd3 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[3][3];
				'd4 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[4][3];
			endcase
			Img_ready_comb[1][0] = Img_ready[1][2];
			Img_ready_comb[1][1] = Img_ready[1][3];
			Img_ready_comb[1][2] = Img_ready[1][4];
			Img_ready_comb[1][3] = Img_ready[1][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[1][2];
				'd1 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[2][2];
				'd2 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[3][2];
				'd3 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[4][2];
				'd4 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[0][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[1][3];
				'd1 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[2][3];
				'd2 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[3][3];
				'd3 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[4][3];
				'd4 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[0][3];
			endcase
			Img_ready_comb[2][0] = Img_ready[2][2];
			Img_ready_comb[2][1] = Img_ready[2][3];
			Img_ready_comb[2][2] = Img_ready[2][4];
			Img_ready_comb[2][3] = Img_ready[2][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[2][2];
				'd1 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[3][2];
				'd2 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[4][2];
				'd3 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[0][2];
				'd4 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[1][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[2][3];
				'd1 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[3][3];
				'd2 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[4][3];
				'd3 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[0][3];
				'd4 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[1][3];
			endcase
			Img_ready_comb[3][0] = Img_ready[3][2];
			Img_ready_comb[3][1] = Img_ready[3][3];
			Img_ready_comb[3][2] = Img_ready[3][4];
			Img_ready_comb[3][3] = Img_ready[3][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[3][2];
				'd1 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[4][2];
				'd2 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[0][2];
				'd3 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[1][2];
				'd4 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[2][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[3][3];
				'd1 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[4][3];
				'd2 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[0][3];
				'd3 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[1][3];
				'd4 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[2][3];
			endcase
			Img_ready_comb[4][0] = Img_ready[4][2];
			Img_ready_comb[4][1] = Img_ready[4][3];
			Img_ready_comb[4][2] = Img_ready[4][4];
			Img_ready_comb[4][3] = Img_ready[4][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[4][2];
				'd1 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[0][2];
				'd2 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[1][2];
				'd3 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[2][2];
				'd4 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[3][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[4][3];
				'd1 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[0][3];
				'd2 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[1][3];
				'd3 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[2][3];
				'd4 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[3][3];
			endcase
		end
		else if(shift_window_count == 'd4) begin
			Img_ready_comb[0][0] = Img_ready[0][2];
			Img_ready_comb[0][1] = Img_ready[0][3];
			Img_ready_comb[0][2] = Img_ready[0][4];
			Img_ready_comb[0][3] = Img_ready[0][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[0][4];
				'd1 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[1][4];
				'd2 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[2][4];
				'd3 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[3][4];
				'd4 :	Img_ready_comb[0][4] = Img_SRAM_Data_split[4][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[0][5];
				'd1 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[1][5];
				'd2 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[2][5];
				'd3 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[3][5];
				'd4 :	Img_ready_comb[0][5] = Img_SRAM_Data_split[4][5];
			endcase
			Img_ready_comb[1][0] = Img_ready[1][2];
			Img_ready_comb[1][1] = Img_ready[1][3];
			Img_ready_comb[1][2] = Img_ready[1][4];
			Img_ready_comb[1][3] = Img_ready[1][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[1][4];
				'd1 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[2][4];
				'd2 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[3][4];
				'd3 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[4][4];
				'd4 :	Img_ready_comb[1][4] = Img_SRAM_Data_split[0][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[1][5];
				'd1 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[2][5];
				'd2 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[3][5];
				'd3 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[4][5];
				'd4 :	Img_ready_comb[1][5] = Img_SRAM_Data_split[0][5];
			endcase
			Img_ready_comb[2][0] = Img_ready[2][2];
			Img_ready_comb[2][1] = Img_ready[2][3];
			Img_ready_comb[2][2] = Img_ready[2][4];
			Img_ready_comb[2][3] = Img_ready[2][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[2][4];
				'd1 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[3][4];
				'd2 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[4][4];
				'd3 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[0][4];
				'd4 :	Img_ready_comb[2][4] = Img_SRAM_Data_split[1][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[2][5];
				'd1 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[3][5];
				'd2 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[4][5];
				'd3 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[0][5];
				'd4 :	Img_ready_comb[2][5] = Img_SRAM_Data_split[1][5];
			endcase
			Img_ready_comb[3][0] = Img_ready[3][2];
			Img_ready_comb[3][1] = Img_ready[3][3];
			Img_ready_comb[3][2] = Img_ready[3][4];
			Img_ready_comb[3][3] = Img_ready[3][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[3][4];
				'd1 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[4][4];
				'd2 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[0][4];
				'd3 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[1][4];
				'd4 :	Img_ready_comb[3][4] = Img_SRAM_Data_split[2][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[3][5];
				'd1 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[4][5];
				'd2 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[0][5];
				'd3 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[1][5];
				'd4 :	Img_ready_comb[3][5] = Img_SRAM_Data_split[2][5];
			endcase
			Img_ready_comb[4][0] = Img_ready[4][2];
			Img_ready_comb[4][1] = Img_ready[4][3];
			Img_ready_comb[4][2] = Img_ready[4][4];
			Img_ready_comb[4][3] = Img_ready[4][5];
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[4][4];
				'd1 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[0][4];
				'd2 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[1][4];
				'd3 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[2][4];
				'd4 :	Img_ready_comb[4][4] = Img_SRAM_Data_split[3][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[4][5];
				'd1 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[0][5];
				'd2 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[1][5];
				'd3 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[2][5];
				'd4 :	Img_ready_comb[4][5] = Img_SRAM_Data_split[3][5];
			endcase
		end
	end
	if(state == CONV && count_28 == 'd2 || count_28 == 'd21) begin
		if(shift_window_count == 'd0) begin
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[0] = Img_SRAM_Data_split[0][0];
				'd1 : row_6_comb[0] = Img_SRAM_Data_split[1][0];
				'd2 : row_6_comb[0] = Img_SRAM_Data_split[2][0];
				'd3 : row_6_comb[0] = Img_SRAM_Data_split[3][0];
				'd4 : row_6_comb[0] = Img_SRAM_Data_split[4][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[1] = Img_SRAM_Data_split[0][1];
				'd1 : row_6_comb[1] = Img_SRAM_Data_split[1][1];
				'd2 : row_6_comb[1] = Img_SRAM_Data_split[2][1];
				'd3 : row_6_comb[1] = Img_SRAM_Data_split[3][1];
				'd4 : row_6_comb[1] = Img_SRAM_Data_split[4][1];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[2] = Img_SRAM_Data_split[0][2];
				'd1 : row_6_comb[2] = Img_SRAM_Data_split[1][2];
				'd2 : row_6_comb[2] = Img_SRAM_Data_split[2][2];
				'd3 : row_6_comb[2] = Img_SRAM_Data_split[3][2];
				'd4 : row_6_comb[2] = Img_SRAM_Data_split[4][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[3] = Img_SRAM_Data_split[0][3];
				'd1 : row_6_comb[3] = Img_SRAM_Data_split[1][3];
				'd2 : row_6_comb[3] = Img_SRAM_Data_split[2][3];
				'd3 : row_6_comb[3] = Img_SRAM_Data_split[3][3];
				'd4 : row_6_comb[3] = Img_SRAM_Data_split[4][3];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[4] = Img_SRAM_Data_split[0][4];
				'd1 : row_6_comb[4] = Img_SRAM_Data_split[1][4];
				'd2 : row_6_comb[4] = Img_SRAM_Data_split[2][4];
				'd3 : row_6_comb[4] = Img_SRAM_Data_split[3][4];
				'd4 : row_6_comb[4] = Img_SRAM_Data_split[4][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[5] = Img_SRAM_Data_split[0][5];
				'd1 : row_6_comb[5] = Img_SRAM_Data_split[1][5];
				'd2 : row_6_comb[5] = Img_SRAM_Data_split[2][5];
				'd3 : row_6_comb[5] = Img_SRAM_Data_split[3][5];
				'd4 : row_6_comb[5] = Img_SRAM_Data_split[4][5];
			endcase
		end
		else if(shift_window_count == 'd1) begin
			row_6_comb[0] = row_6[2];
			row_6_comb[1] = row_6[3];
			row_6_comb[2] = row_6[4];
			row_6_comb[3] = row_6[5];
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[4] = Img_SRAM_Data_split[0][6];
				'd1 : row_6_comb[4] = Img_SRAM_Data_split[1][6];
				'd2 : row_6_comb[4] = Img_SRAM_Data_split[2][6];
				'd3 : row_6_comb[4] = Img_SRAM_Data_split[3][6];
				'd4 : row_6_comb[4] = Img_SRAM_Data_split[4][6];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[5] = Img_SRAM_Data_split[0][7];
				'd1 : row_6_comb[5] = Img_SRAM_Data_split[1][7];
				'd2 : row_6_comb[5] = Img_SRAM_Data_split[2][7];
				'd3 : row_6_comb[5] = Img_SRAM_Data_split[3][7];
				'd4 : row_6_comb[5] = Img_SRAM_Data_split[4][7];
			endcase
		end
		else if(shift_window_count == 'd2) begin
			row_6_comb[0] = row_6[2];
			row_6_comb[1] = row_6[3];
			row_6_comb[2] = row_6[4];
			row_6_comb[3] = row_6[5];
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[4] = Img_SRAM_Data_split[0][0];
				'd1 : row_6_comb[4] = Img_SRAM_Data_split[1][0];
				'd2 : row_6_comb[4] = Img_SRAM_Data_split[2][0];
				'd3 : row_6_comb[4] = Img_SRAM_Data_split[3][0];
				'd4 : row_6_comb[4] = Img_SRAM_Data_split[4][0];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[5] = Img_SRAM_Data_split[0][1];
				'd1 : row_6_comb[5] = Img_SRAM_Data_split[1][1];
				'd2 : row_6_comb[5] = Img_SRAM_Data_split[2][1];
				'd3 : row_6_comb[5] = Img_SRAM_Data_split[3][1];
				'd4 : row_6_comb[5] = Img_SRAM_Data_split[4][1];
			endcase
		end
		else if(shift_window_count == 'd3) begin
			row_6_comb[0] = row_6[2];
			row_6_comb[1] = row_6[3];
			row_6_comb[2] = row_6[4];
			row_6_comb[3] = row_6[5];
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[4] = Img_SRAM_Data_split[0][2];
				'd1 : row_6_comb[4] = Img_SRAM_Data_split[1][2];
				'd2 : row_6_comb[4] = Img_SRAM_Data_split[2][2];
				'd3 : row_6_comb[4] = Img_SRAM_Data_split[3][2];
				'd4 : row_6_comb[4] = Img_SRAM_Data_split[4][2];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[5] = Img_SRAM_Data_split[0][3];
				'd1 : row_6_comb[5] = Img_SRAM_Data_split[1][3];
				'd2 : row_6_comb[5] = Img_SRAM_Data_split[2][3];
				'd3 : row_6_comb[5] = Img_SRAM_Data_split[3][3];
				'd4 : row_6_comb[5] = Img_SRAM_Data_split[4][3];
			endcase
		end
		else if(shift_window_count == 'd4) begin
			row_6_comb[0] = row_6[2];
			row_6_comb[1] = row_6[3];
			row_6_comb[2] = row_6[4];
			row_6_comb[3] = row_6[5];
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[4] = Img_SRAM_Data_split[0][4];
				'd1 : row_6_comb[4] = Img_SRAM_Data_split[1][4];
				'd2 : row_6_comb[4] = Img_SRAM_Data_split[2][4];
				'd3 : row_6_comb[4] = Img_SRAM_Data_split[3][4];
				'd4 : row_6_comb[4] = Img_SRAM_Data_split[4][4];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[5] = Img_SRAM_Data_split[0][5];
				'd1 : row_6_comb[5] = Img_SRAM_Data_split[1][5];
				'd2 : row_6_comb[5] = Img_SRAM_Data_split[2][5];
				'd3 : row_6_comb[5] = Img_SRAM_Data_split[3][5];
				'd4 : row_6_comb[5] = Img_SRAM_Data_split[4][5];
			endcase
		end
		else if(shift_window_count == 'd5) begin
			row_6_comb[0] = row_6[2];
			row_6_comb[1] = row_6[3];
			row_6_comb[2] = row_6[4];
			row_6_comb[3] = row_6[5];
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[4] = Img_SRAM_Data_split[0][6];
				'd1 : row_6_comb[4] = Img_SRAM_Data_split[1][6];
				'd2 : row_6_comb[4] = Img_SRAM_Data_split[2][6];
				'd3 : row_6_comb[4] = Img_SRAM_Data_split[3][6];
				'd4 : row_6_comb[4] = Img_SRAM_Data_split[4][6];
			endcase
			case(count_5) // synopsys full_case
				'd0 : row_6_comb[5] = Img_SRAM_Data_split[0][7];
				'd1 : row_6_comb[5] = Img_SRAM_Data_split[1][7];
				'd2 : row_6_comb[5] = Img_SRAM_Data_split[2][7];
				'd3 : row_6_comb[5] = Img_SRAM_Data_split[3][7];
				'd4 : row_6_comb[5] = Img_SRAM_Data_split[4][7];
			endcase
		end
	end
end

always @ * begin
Kernel_addr = idx_count;
	if(state == CONV || state == DECONV) begin
		if(in_valid2)
			Kernel_addr = matrix_idx;
		else
			Kernel_addr = id[1];
	end
	
end

assign Ker_read_en_1 = !Ker_write_en_1;
assign Ker_read_en_2 = !Ker_write_en_2;

Img_SRAM_448w_64b IMGSRAM1(.A0(Img_Sram_Addr_in[0][0]),.A1(Img_Sram_Addr_in[0][1]),.A2(Img_Sram_Addr_in[0][2]),.A3(Img_Sram_Addr_in[0][3]),
						   .A4(Img_Sram_Addr_in[0][4]),.A5(Img_Sram_Addr_in[0][5]),.A6(Img_Sram_Addr_in[0][6]),.A7(Img_Sram_Addr_in[0][7]),
						   .A8(Img_Sram_Addr_in[0][8]),
						   .DO0(Img_SRAM_DATA_out[0][0]),.DO1(Img_SRAM_DATA_out[0][1]),.DO2(Img_SRAM_DATA_out[0][2]),
						   .DO3(Img_SRAM_DATA_out[0][3]),.DO4(Img_SRAM_DATA_out[0][4]),.DO5(Img_SRAM_DATA_out[0][5]),
						   .DO6(Img_SRAM_DATA_out[0][6]),.DO7(Img_SRAM_DATA_out[0][7]),.DO8(Img_SRAM_DATA_out[0][8]),
						   .DO9(Img_SRAM_DATA_out[0][9]),.DO10(Img_SRAM_DATA_out[0][10]),.DO11(Img_SRAM_DATA_out[0][11]),
						   .DO12(Img_SRAM_DATA_out[0][12]),.DO13(Img_SRAM_DATA_out[0][13]),.DO14(Img_SRAM_DATA_out[0][14]),
						   .DO15(Img_SRAM_DATA_out[0][15]),.DO16(Img_SRAM_DATA_out[0][16]),.DO17(Img_SRAM_DATA_out[0][17]),
						   .DO18(Img_SRAM_DATA_out[0][18]),.DO19(Img_SRAM_DATA_out[0][19]),.DO20(Img_SRAM_DATA_out[0][20]),
						   .DO21(Img_SRAM_DATA_out[0][21]),.DO22(Img_SRAM_DATA_out[0][22]),.DO23(Img_SRAM_DATA_out[0][23]),
						   .DO24(Img_SRAM_DATA_out[0][24]),.DO25(Img_SRAM_DATA_out[0][25]),.DO26(Img_SRAM_DATA_out[0][26]),
						   .DO27(Img_SRAM_DATA_out[0][27]),.DO28(Img_SRAM_DATA_out[0][28]),.DO29(Img_SRAM_DATA_out[0][29]),
						   .DO30(Img_SRAM_DATA_out[0][30]),.DO31(Img_SRAM_DATA_out[0][31]),.DO32(Img_SRAM_DATA_out[0][32]),
						   .DO33(Img_SRAM_DATA_out[0][33]),.DO34(Img_SRAM_DATA_out[0][34]),.DO35(Img_SRAM_DATA_out[0][35]),
						   .DO36(Img_SRAM_DATA_out[0][36]),.DO37(Img_SRAM_DATA_out[0][37]),.DO38(Img_SRAM_DATA_out[0][38]),
						   .DO39(Img_SRAM_DATA_out[0][39]),.DO40(Img_SRAM_DATA_out[0][40]),.DO41(Img_SRAM_DATA_out[0][41]),
						   .DO42(Img_SRAM_DATA_out[0][42]),.DO43(Img_SRAM_DATA_out[0][43]),.DO44(Img_SRAM_DATA_out[0][44]),
						   .DO45(Img_SRAM_DATA_out[0][45]),.DO46(Img_SRAM_DATA_out[0][46]),.DO47(Img_SRAM_DATA_out[0][47]),
						   .DO48(Img_SRAM_DATA_out[0][48]),.DO49(Img_SRAM_DATA_out[0][49]),.DO50(Img_SRAM_DATA_out[0][50]),
						   .DO51(Img_SRAM_DATA_out[0][51]),.DO52(Img_SRAM_DATA_out[0][52]),.DO53(Img_SRAM_DATA_out[0][53]),
						   .DO54(Img_SRAM_DATA_out[0][54]),.DO55(Img_SRAM_DATA_out[0][55]),.DO56(Img_SRAM_DATA_out[0][56]),
						   .DO57(Img_SRAM_DATA_out[0][57]),.DO58(Img_SRAM_DATA_out[0][58]),.DO59(Img_SRAM_DATA_out[0][59]),
						   .DO60(Img_SRAM_DATA_out[0][60]),.DO61(Img_SRAM_DATA_out[0][61]),.DO62(Img_SRAM_DATA_out[0][62]),
                           .DO63(Img_SRAM_DATA_out[0][63]),
						   .DI0 (Img_SRAM_DATA_in[0]), .DI1 (Img_SRAM_DATA_in[1]), .DI2 (Img_SRAM_DATA_in[2]),
						   .DI3 (Img_SRAM_DATA_in[3]), .DI4 (Img_SRAM_DATA_in[4]), .DI5 (Img_SRAM_DATA_in[5]),
						   .DI6 (Img_SRAM_DATA_in[6]), .DI7 (Img_SRAM_DATA_in[7]), .DI8 (Img_SRAM_DATA_in[8]),
						   .DI9 (Img_SRAM_DATA_in[9]), .DI10(Img_SRAM_DATA_in[10]),.DI11(Img_SRAM_DATA_in[11]),
						   .DI12(Img_SRAM_DATA_in[12]),.DI13(Img_SRAM_DATA_in[13]),.DI14(Img_SRAM_DATA_in[14]),
						   .DI15(Img_SRAM_DATA_in[15]),.DI16(Img_SRAM_DATA_in[16]),.DI17(Img_SRAM_DATA_in[17]),
						   .DI18(Img_SRAM_DATA_in[18]),.DI19(Img_SRAM_DATA_in[19]),.DI20(Img_SRAM_DATA_in[20]),
						   .DI21(Img_SRAM_DATA_in[21]),.DI22(Img_SRAM_DATA_in[22]),.DI23(Img_SRAM_DATA_in[23]),
						   .DI24(Img_SRAM_DATA_in[24]),.DI25(Img_SRAM_DATA_in[25]),.DI26(Img_SRAM_DATA_in[26]),
						   .DI27(Img_SRAM_DATA_in[27]),.DI28(Img_SRAM_DATA_in[28]),.DI29(Img_SRAM_DATA_in[29]),
						   .DI30(Img_SRAM_DATA_in[30]),.DI31(Img_SRAM_DATA_in[31]),.DI32(Img_SRAM_DATA_in[32]),
						   .DI33(Img_SRAM_DATA_in[33]),.DI34(Img_SRAM_DATA_in[34]),.DI35(Img_SRAM_DATA_in[35]),
						   .DI36(Img_SRAM_DATA_in[36]),.DI37(Img_SRAM_DATA_in[37]),.DI38(Img_SRAM_DATA_in[38]),
						   .DI39(Img_SRAM_DATA_in[39]),.DI40(Img_SRAM_DATA_in[40]),.DI41(Img_SRAM_DATA_in[41]),
						   .DI42(Img_SRAM_DATA_in[42]),.DI43(Img_SRAM_DATA_in[43]),.DI44(Img_SRAM_DATA_in[44]),
						   .DI45(Img_SRAM_DATA_in[45]),.DI46(Img_SRAM_DATA_in[46]),.DI47(Img_SRAM_DATA_in[47]),
						   .DI48(Img_SRAM_DATA_in[48]),.DI49(Img_SRAM_DATA_in[49]),.DI50(Img_SRAM_DATA_in[50]),
						   .DI51(Img_SRAM_DATA_in[51]),.DI52(Img_SRAM_DATA_in[52]),.DI53(Img_SRAM_DATA_in[53]),
						   .DI54(Img_SRAM_DATA_in[54]),.DI55(Img_SRAM_DATA_in[55]),.DI56(Img_SRAM_DATA_in[56]),
						   .DI57(Img_SRAM_DATA_in[57]),.DI58(Img_SRAM_DATA_in[58]),.DI59(Img_SRAM_DATA_in[59]),
						   .DI60(Img_SRAM_DATA_in[60]),.DI61(Img_SRAM_DATA_in[61]),.DI62(Img_SRAM_DATA_in[62]),
                           .DI63(Img_SRAM_DATA_in[63]),
						   .CK(clk),.WEB(!Img_write_en[0]),.OE(1'b1), .CS(1'b1));
Img_SRAM_448w_64b IMGSRAM2(.A0(Img_Sram_Addr_in[1][0]),.A1(Img_Sram_Addr_in[1][1]),.A2(Img_Sram_Addr_in[1][2]),.A3(Img_Sram_Addr_in[1][3]),
						   .A4(Img_Sram_Addr_in[1][4]),.A5(Img_Sram_Addr_in[1][5]),.A6(Img_Sram_Addr_in[1][6]),.A7(Img_Sram_Addr_in[1][7]),
						   .A8(Img_Sram_Addr_in[1][8]),
						   .DO0(Img_SRAM_DATA_out[1][0]),.DO1(Img_SRAM_DATA_out[1][1]),.DO2(Img_SRAM_DATA_out[1][2]),
						   .DO3(Img_SRAM_DATA_out[1][3]),.DO4(Img_SRAM_DATA_out[1][4]),.DO5(Img_SRAM_DATA_out[1][5]),
						   .DO6(Img_SRAM_DATA_out[1][6]),.DO7(Img_SRAM_DATA_out[1][7]),.DO8(Img_SRAM_DATA_out[1][8]),
						   .DO9(Img_SRAM_DATA_out[1][9]),.DO10(Img_SRAM_DATA_out[1][10]),.DO11(Img_SRAM_DATA_out[1][11]),
						   .DO12(Img_SRAM_DATA_out[1][12]),.DO13(Img_SRAM_DATA_out[1][13]),.DO14(Img_SRAM_DATA_out[1][14]),
						   .DO15(Img_SRAM_DATA_out[1][15]),.DO16(Img_SRAM_DATA_out[1][16]),.DO17(Img_SRAM_DATA_out[1][17]),
						   .DO18(Img_SRAM_DATA_out[1][18]),.DO19(Img_SRAM_DATA_out[1][19]),.DO20(Img_SRAM_DATA_out[1][20]),
						   .DO21(Img_SRAM_DATA_out[1][21]),.DO22(Img_SRAM_DATA_out[1][22]),.DO23(Img_SRAM_DATA_out[1][23]),
						   .DO24(Img_SRAM_DATA_out[1][24]),.DO25(Img_SRAM_DATA_out[1][25]),.DO26(Img_SRAM_DATA_out[1][26]),
						   .DO27(Img_SRAM_DATA_out[1][27]),.DO28(Img_SRAM_DATA_out[1][28]),.DO29(Img_SRAM_DATA_out[1][29]),
						   .DO30(Img_SRAM_DATA_out[1][30]),.DO31(Img_SRAM_DATA_out[1][31]),.DO32(Img_SRAM_DATA_out[1][32]),
						   .DO33(Img_SRAM_DATA_out[1][33]),.DO34(Img_SRAM_DATA_out[1][34]),.DO35(Img_SRAM_DATA_out[1][35]),
						   .DO36(Img_SRAM_DATA_out[1][36]),.DO37(Img_SRAM_DATA_out[1][37]),.DO38(Img_SRAM_DATA_out[1][38]),
						   .DO39(Img_SRAM_DATA_out[1][39]),.DO40(Img_SRAM_DATA_out[1][40]),.DO41(Img_SRAM_DATA_out[1][41]),
						   .DO42(Img_SRAM_DATA_out[1][42]),.DO43(Img_SRAM_DATA_out[1][43]),.DO44(Img_SRAM_DATA_out[1][44]),
						   .DO45(Img_SRAM_DATA_out[1][45]),.DO46(Img_SRAM_DATA_out[1][46]),.DO47(Img_SRAM_DATA_out[1][47]),
						   .DO48(Img_SRAM_DATA_out[1][48]),.DO49(Img_SRAM_DATA_out[1][49]),.DO50(Img_SRAM_DATA_out[1][50]),
						   .DO51(Img_SRAM_DATA_out[1][51]),.DO52(Img_SRAM_DATA_out[1][52]),.DO53(Img_SRAM_DATA_out[1][53]),
						   .DO54(Img_SRAM_DATA_out[1][54]),.DO55(Img_SRAM_DATA_out[1][55]),.DO56(Img_SRAM_DATA_out[1][56]),
						   .DO57(Img_SRAM_DATA_out[1][57]),.DO58(Img_SRAM_DATA_out[1][58]),.DO59(Img_SRAM_DATA_out[1][59]),
						   .DO60(Img_SRAM_DATA_out[1][60]),.DO61(Img_SRAM_DATA_out[1][61]),.DO62(Img_SRAM_DATA_out[1][62]),
                           .DO63(Img_SRAM_DATA_out[1][63]),
						   .DI0 (Img_SRAM_DATA_in[0]), .DI1 (Img_SRAM_DATA_in[1]), .DI2 (Img_SRAM_DATA_in[2]),
						   .DI3 (Img_SRAM_DATA_in[3]), .DI4 (Img_SRAM_DATA_in[4]), .DI5 (Img_SRAM_DATA_in[5]),
						   .DI6 (Img_SRAM_DATA_in[6]), .DI7 (Img_SRAM_DATA_in[7]), .DI8 (Img_SRAM_DATA_in[8]),
						   .DI9 (Img_SRAM_DATA_in[9]), .DI10(Img_SRAM_DATA_in[10]),.DI11(Img_SRAM_DATA_in[11]),
						   .DI12(Img_SRAM_DATA_in[12]),.DI13(Img_SRAM_DATA_in[13]),.DI14(Img_SRAM_DATA_in[14]),
						   .DI15(Img_SRAM_DATA_in[15]),.DI16(Img_SRAM_DATA_in[16]),.DI17(Img_SRAM_DATA_in[17]),
						   .DI18(Img_SRAM_DATA_in[18]),.DI19(Img_SRAM_DATA_in[19]),.DI20(Img_SRAM_DATA_in[20]),
						   .DI21(Img_SRAM_DATA_in[21]),.DI22(Img_SRAM_DATA_in[22]),.DI23(Img_SRAM_DATA_in[23]),
						   .DI24(Img_SRAM_DATA_in[24]),.DI25(Img_SRAM_DATA_in[25]),.DI26(Img_SRAM_DATA_in[26]),
						   .DI27(Img_SRAM_DATA_in[27]),.DI28(Img_SRAM_DATA_in[28]),.DI29(Img_SRAM_DATA_in[29]),
						   .DI30(Img_SRAM_DATA_in[30]),.DI31(Img_SRAM_DATA_in[31]),.DI32(Img_SRAM_DATA_in[32]),
						   .DI33(Img_SRAM_DATA_in[33]),.DI34(Img_SRAM_DATA_in[34]),.DI35(Img_SRAM_DATA_in[35]),
						   .DI36(Img_SRAM_DATA_in[36]),.DI37(Img_SRAM_DATA_in[37]),.DI38(Img_SRAM_DATA_in[38]),
						   .DI39(Img_SRAM_DATA_in[39]),.DI40(Img_SRAM_DATA_in[40]),.DI41(Img_SRAM_DATA_in[41]),
						   .DI42(Img_SRAM_DATA_in[42]),.DI43(Img_SRAM_DATA_in[43]),.DI44(Img_SRAM_DATA_in[44]),
						   .DI45(Img_SRAM_DATA_in[45]),.DI46(Img_SRAM_DATA_in[46]),.DI47(Img_SRAM_DATA_in[47]),
						   .DI48(Img_SRAM_DATA_in[48]),.DI49(Img_SRAM_DATA_in[49]),.DI50(Img_SRAM_DATA_in[50]),
						   .DI51(Img_SRAM_DATA_in[51]),.DI52(Img_SRAM_DATA_in[52]),.DI53(Img_SRAM_DATA_in[53]),
						   .DI54(Img_SRAM_DATA_in[54]),.DI55(Img_SRAM_DATA_in[55]),.DI56(Img_SRAM_DATA_in[56]),
						   .DI57(Img_SRAM_DATA_in[57]),.DI58(Img_SRAM_DATA_in[58]),.DI59(Img_SRAM_DATA_in[59]),
						   .DI60(Img_SRAM_DATA_in[60]),.DI61(Img_SRAM_DATA_in[61]),.DI62(Img_SRAM_DATA_in[62]),
                           .DI63(Img_SRAM_DATA_in[63]),
						   .CK(clk),.WEB(!Img_write_en[1]),.OE(1'b1), .CS(1'b1));
Img_SRAM_384w_64b IMGSRAM3(.A0(Img_Sram_Addr_in[2][0]),.A1(Img_Sram_Addr_in[2][1]),.A2(Img_Sram_Addr_in[2][2]),.A3(Img_Sram_Addr_in[2][3]),
						   .A4(Img_Sram_Addr_in[2][4]),.A5(Img_Sram_Addr_in[2][5]),.A6(Img_Sram_Addr_in[2][6]),.A7(Img_Sram_Addr_in[2][7]),
						   .A8(Img_Sram_Addr_in[2][8]),
						   .DO0(Img_SRAM_DATA_out[2][0]),.DO1(Img_SRAM_DATA_out[2][1]),.DO2(Img_SRAM_DATA_out[2][2]),
						   .DO3(Img_SRAM_DATA_out[2][3]),.DO4(Img_SRAM_DATA_out[2][4]),.DO5(Img_SRAM_DATA_out[2][5]),
						   .DO6(Img_SRAM_DATA_out[2][6]),.DO7(Img_SRAM_DATA_out[2][7]),.DO8(Img_SRAM_DATA_out[2][8]),
						   .DO9(Img_SRAM_DATA_out[2][9]),.DO10(Img_SRAM_DATA_out[2][10]),.DO11(Img_SRAM_DATA_out[2][11]),
						   .DO12(Img_SRAM_DATA_out[2][12]),.DO13(Img_SRAM_DATA_out[2][13]),.DO14(Img_SRAM_DATA_out[2][14]),
						   .DO15(Img_SRAM_DATA_out[2][15]),.DO16(Img_SRAM_DATA_out[2][16]),.DO17(Img_SRAM_DATA_out[2][17]),
						   .DO18(Img_SRAM_DATA_out[2][18]),.DO19(Img_SRAM_DATA_out[2][19]),.DO20(Img_SRAM_DATA_out[2][20]),
						   .DO21(Img_SRAM_DATA_out[2][21]),.DO22(Img_SRAM_DATA_out[2][22]),.DO23(Img_SRAM_DATA_out[2][23]),
						   .DO24(Img_SRAM_DATA_out[2][24]),.DO25(Img_SRAM_DATA_out[2][25]),.DO26(Img_SRAM_DATA_out[2][26]),
						   .DO27(Img_SRAM_DATA_out[2][27]),.DO28(Img_SRAM_DATA_out[2][28]),.DO29(Img_SRAM_DATA_out[2][29]),
						   .DO30(Img_SRAM_DATA_out[2][30]),.DO31(Img_SRAM_DATA_out[2][31]),.DO32(Img_SRAM_DATA_out[2][32]),
						   .DO33(Img_SRAM_DATA_out[2][33]),.DO34(Img_SRAM_DATA_out[2][34]),.DO35(Img_SRAM_DATA_out[2][35]),
						   .DO36(Img_SRAM_DATA_out[2][36]),.DO37(Img_SRAM_DATA_out[2][37]),.DO38(Img_SRAM_DATA_out[2][38]),
						   .DO39(Img_SRAM_DATA_out[2][39]),.DO40(Img_SRAM_DATA_out[2][40]),.DO41(Img_SRAM_DATA_out[2][41]),
						   .DO42(Img_SRAM_DATA_out[2][42]),.DO43(Img_SRAM_DATA_out[2][43]),.DO44(Img_SRAM_DATA_out[2][44]),
						   .DO45(Img_SRAM_DATA_out[2][45]),.DO46(Img_SRAM_DATA_out[2][46]),.DO47(Img_SRAM_DATA_out[2][47]),
						   .DO48(Img_SRAM_DATA_out[2][48]),.DO49(Img_SRAM_DATA_out[2][49]),.DO50(Img_SRAM_DATA_out[2][50]),
						   .DO51(Img_SRAM_DATA_out[2][51]),.DO52(Img_SRAM_DATA_out[2][52]),.DO53(Img_SRAM_DATA_out[2][53]),
						   .DO54(Img_SRAM_DATA_out[2][54]),.DO55(Img_SRAM_DATA_out[2][55]),.DO56(Img_SRAM_DATA_out[2][56]),
						   .DO57(Img_SRAM_DATA_out[2][57]),.DO58(Img_SRAM_DATA_out[2][58]),.DO59(Img_SRAM_DATA_out[2][59]),
						   .DO60(Img_SRAM_DATA_out[2][60]),.DO61(Img_SRAM_DATA_out[2][61]),.DO62(Img_SRAM_DATA_out[2][62]),
                           .DO63(Img_SRAM_DATA_out[2][63]),
						   .DI0 (Img_SRAM_DATA_in[0]), .DI1 (Img_SRAM_DATA_in[1]), .DI2 (Img_SRAM_DATA_in[2]),
						   .DI3 (Img_SRAM_DATA_in[3]), .DI4 (Img_SRAM_DATA_in[4]), .DI5 (Img_SRAM_DATA_in[5]),
						   .DI6 (Img_SRAM_DATA_in[6]), .DI7 (Img_SRAM_DATA_in[7]), .DI8 (Img_SRAM_DATA_in[8]),
						   .DI9 (Img_SRAM_DATA_in[9]), .DI10(Img_SRAM_DATA_in[10]),.DI11(Img_SRAM_DATA_in[11]),
						   .DI12(Img_SRAM_DATA_in[12]),.DI13(Img_SRAM_DATA_in[13]),.DI14(Img_SRAM_DATA_in[14]),
						   .DI15(Img_SRAM_DATA_in[15]),.DI16(Img_SRAM_DATA_in[16]),.DI17(Img_SRAM_DATA_in[17]),
						   .DI18(Img_SRAM_DATA_in[18]),.DI19(Img_SRAM_DATA_in[19]),.DI20(Img_SRAM_DATA_in[20]),
						   .DI21(Img_SRAM_DATA_in[21]),.DI22(Img_SRAM_DATA_in[22]),.DI23(Img_SRAM_DATA_in[23]),
						   .DI24(Img_SRAM_DATA_in[24]),.DI25(Img_SRAM_DATA_in[25]),.DI26(Img_SRAM_DATA_in[26]),
						   .DI27(Img_SRAM_DATA_in[27]),.DI28(Img_SRAM_DATA_in[28]),.DI29(Img_SRAM_DATA_in[29]),
						   .DI30(Img_SRAM_DATA_in[30]),.DI31(Img_SRAM_DATA_in[31]),.DI32(Img_SRAM_DATA_in[32]),
						   .DI33(Img_SRAM_DATA_in[33]),.DI34(Img_SRAM_DATA_in[34]),.DI35(Img_SRAM_DATA_in[35]),
						   .DI36(Img_SRAM_DATA_in[36]),.DI37(Img_SRAM_DATA_in[37]),.DI38(Img_SRAM_DATA_in[38]),
						   .DI39(Img_SRAM_DATA_in[39]),.DI40(Img_SRAM_DATA_in[40]),.DI41(Img_SRAM_DATA_in[41]),
						   .DI42(Img_SRAM_DATA_in[42]),.DI43(Img_SRAM_DATA_in[43]),.DI44(Img_SRAM_DATA_in[44]),
						   .DI45(Img_SRAM_DATA_in[45]),.DI46(Img_SRAM_DATA_in[46]),.DI47(Img_SRAM_DATA_in[47]),
						   .DI48(Img_SRAM_DATA_in[48]),.DI49(Img_SRAM_DATA_in[49]),.DI50(Img_SRAM_DATA_in[50]),
						   .DI51(Img_SRAM_DATA_in[51]),.DI52(Img_SRAM_DATA_in[52]),.DI53(Img_SRAM_DATA_in[53]),
						   .DI54(Img_SRAM_DATA_in[54]),.DI55(Img_SRAM_DATA_in[55]),.DI56(Img_SRAM_DATA_in[56]),
						   .DI57(Img_SRAM_DATA_in[57]),.DI58(Img_SRAM_DATA_in[58]),.DI59(Img_SRAM_DATA_in[59]),
						   .DI60(Img_SRAM_DATA_in[60]),.DI61(Img_SRAM_DATA_in[61]),.DI62(Img_SRAM_DATA_in[62]),
                           .DI63(Img_SRAM_DATA_in[63]),
						   .CK(clk),.WEB(!Img_write_en[2]),.OE(1'b1), .CS(1'b1));
Img_SRAM_384w_64b IMGSRAM4(.A0(Img_Sram_Addr_in[3][0]),.A1(Img_Sram_Addr_in[3][1]),.A2(Img_Sram_Addr_in[3][2]),.A3(Img_Sram_Addr_in[3][3]),
						   .A4(Img_Sram_Addr_in[3][4]),.A5(Img_Sram_Addr_in[3][5]),.A6(Img_Sram_Addr_in[3][6]),.A7(Img_Sram_Addr_in[3][7]),
						   .A8(Img_Sram_Addr_in[3][8]),
						   .DO0 (Img_SRAM_DATA_out[3][0]), .DO1 (Img_SRAM_DATA_out[3][1]), .DO2 (Img_SRAM_DATA_out[3][2]),
						   .DO3 (Img_SRAM_DATA_out[3][3]), .DO4 (Img_SRAM_DATA_out[3][4]), .DO5 (Img_SRAM_DATA_out[3][5]),
						   .DO6 (Img_SRAM_DATA_out[3][6]), .DO7 (Img_SRAM_DATA_out[3][7]), .DO8 (Img_SRAM_DATA_out[3][8]),
						   .DO9 (Img_SRAM_DATA_out[3][9]), .DO10(Img_SRAM_DATA_out[3][10]),.DO11(Img_SRAM_DATA_out[3][11]),
						   .DO12(Img_SRAM_DATA_out[3][12]),.DO13(Img_SRAM_DATA_out[3][13]),.DO14(Img_SRAM_DATA_out[3][14]),
						   .DO15(Img_SRAM_DATA_out[3][15]),.DO16(Img_SRAM_DATA_out[3][16]),.DO17(Img_SRAM_DATA_out[3][17]),
						   .DO18(Img_SRAM_DATA_out[3][18]),.DO19(Img_SRAM_DATA_out[3][19]),.DO20(Img_SRAM_DATA_out[3][20]),
						   .DO21(Img_SRAM_DATA_out[3][21]),.DO22(Img_SRAM_DATA_out[3][22]),.DO23(Img_SRAM_DATA_out[3][23]),
						   .DO24(Img_SRAM_DATA_out[3][24]),.DO25(Img_SRAM_DATA_out[3][25]),.DO26(Img_SRAM_DATA_out[3][26]),
						   .DO27(Img_SRAM_DATA_out[3][27]),.DO28(Img_SRAM_DATA_out[3][28]),.DO29(Img_SRAM_DATA_out[3][29]),
						   .DO30(Img_SRAM_DATA_out[3][30]),.DO31(Img_SRAM_DATA_out[3][31]),.DO32(Img_SRAM_DATA_out[3][32]),
						   .DO33(Img_SRAM_DATA_out[3][33]),.DO34(Img_SRAM_DATA_out[3][34]),.DO35(Img_SRAM_DATA_out[3][35]),
						   .DO36(Img_SRAM_DATA_out[3][36]),.DO37(Img_SRAM_DATA_out[3][37]),.DO38(Img_SRAM_DATA_out[3][38]),
						   .DO39(Img_SRAM_DATA_out[3][39]),.DO40(Img_SRAM_DATA_out[3][40]),.DO41(Img_SRAM_DATA_out[3][41]),
						   .DO42(Img_SRAM_DATA_out[3][42]),.DO43(Img_SRAM_DATA_out[3][43]),.DO44(Img_SRAM_DATA_out[3][44]),
						   .DO45(Img_SRAM_DATA_out[3][45]),.DO46(Img_SRAM_DATA_out[3][46]),.DO47(Img_SRAM_DATA_out[3][47]),
						   .DO48(Img_SRAM_DATA_out[3][48]),.DO49(Img_SRAM_DATA_out[3][49]),.DO50(Img_SRAM_DATA_out[3][50]),
						   .DO51(Img_SRAM_DATA_out[3][51]),.DO52(Img_SRAM_DATA_out[3][52]),.DO53(Img_SRAM_DATA_out[3][53]),
						   .DO54(Img_SRAM_DATA_out[3][54]),.DO55(Img_SRAM_DATA_out[3][55]),.DO56(Img_SRAM_DATA_out[3][56]),
						   .DO57(Img_SRAM_DATA_out[3][57]),.DO58(Img_SRAM_DATA_out[3][58]),.DO59(Img_SRAM_DATA_out[3][59]),
						   .DO60(Img_SRAM_DATA_out[3][60]),.DO61(Img_SRAM_DATA_out[3][61]),.DO62(Img_SRAM_DATA_out[3][62]),
                           .DO63(Img_SRAM_DATA_out[3][63]),
						   .DI0 (Img_SRAM_DATA_in[0]), .DI1 (Img_SRAM_DATA_in[1]), .DI2 (Img_SRAM_DATA_in[2]),
						   .DI3 (Img_SRAM_DATA_in[3]), .DI4 (Img_SRAM_DATA_in[4]), .DI5 (Img_SRAM_DATA_in[5]),
						   .DI6 (Img_SRAM_DATA_in[6]), .DI7 (Img_SRAM_DATA_in[7]), .DI8 (Img_SRAM_DATA_in[8]),
						   .DI9 (Img_SRAM_DATA_in[9]), .DI10(Img_SRAM_DATA_in[10]),.DI11(Img_SRAM_DATA_in[11]),
						   .DI12(Img_SRAM_DATA_in[12]),.DI13(Img_SRAM_DATA_in[13]),.DI14(Img_SRAM_DATA_in[14]),
						   .DI15(Img_SRAM_DATA_in[15]),.DI16(Img_SRAM_DATA_in[16]),.DI17(Img_SRAM_DATA_in[17]),
						   .DI18(Img_SRAM_DATA_in[18]),.DI19(Img_SRAM_DATA_in[19]),.DI20(Img_SRAM_DATA_in[20]),
						   .DI21(Img_SRAM_DATA_in[21]),.DI22(Img_SRAM_DATA_in[22]),.DI23(Img_SRAM_DATA_in[23]),
						   .DI24(Img_SRAM_DATA_in[24]),.DI25(Img_SRAM_DATA_in[25]),.DI26(Img_SRAM_DATA_in[26]),
						   .DI27(Img_SRAM_DATA_in[27]),.DI28(Img_SRAM_DATA_in[28]),.DI29(Img_SRAM_DATA_in[29]),
						   .DI30(Img_SRAM_DATA_in[30]),.DI31(Img_SRAM_DATA_in[31]),.DI32(Img_SRAM_DATA_in[32]),
						   .DI33(Img_SRAM_DATA_in[33]),.DI34(Img_SRAM_DATA_in[34]),.DI35(Img_SRAM_DATA_in[35]),
						   .DI36(Img_SRAM_DATA_in[36]),.DI37(Img_SRAM_DATA_in[37]),.DI38(Img_SRAM_DATA_in[38]),
						   .DI39(Img_SRAM_DATA_in[39]),.DI40(Img_SRAM_DATA_in[40]),.DI41(Img_SRAM_DATA_in[41]),
						   .DI42(Img_SRAM_DATA_in[42]),.DI43(Img_SRAM_DATA_in[43]),.DI44(Img_SRAM_DATA_in[44]),
						   .DI45(Img_SRAM_DATA_in[45]),.DI46(Img_SRAM_DATA_in[46]),.DI47(Img_SRAM_DATA_in[47]),
						   .DI48(Img_SRAM_DATA_in[48]),.DI49(Img_SRAM_DATA_in[49]),.DI50(Img_SRAM_DATA_in[50]),
						   .DI51(Img_SRAM_DATA_in[51]),.DI52(Img_SRAM_DATA_in[52]),.DI53(Img_SRAM_DATA_in[53]),
						   .DI54(Img_SRAM_DATA_in[54]),.DI55(Img_SRAM_DATA_in[55]),.DI56(Img_SRAM_DATA_in[56]),
						   .DI57(Img_SRAM_DATA_in[57]),.DI58(Img_SRAM_DATA_in[58]),.DI59(Img_SRAM_DATA_in[59]),
						   .DI60(Img_SRAM_DATA_in[60]),.DI61(Img_SRAM_DATA_in[61]),.DI62(Img_SRAM_DATA_in[62]),
                           .DI63(Img_SRAM_DATA_in[63]),
						   .CK(clk),.WEB(!Img_write_en[3]),.OE(1'b1), .CS(1'b1));
Img_SRAM_384w_64b IMGSRAM5(.A0(Img_Sram_Addr_in[4][0]),.A1(Img_Sram_Addr_in[4][1]),.A2(Img_Sram_Addr_in[4][2]),.A3(Img_Sram_Addr_in[4][3]),
						   .A4(Img_Sram_Addr_in[4][4]),.A5(Img_Sram_Addr_in[4][5]),.A6(Img_Sram_Addr_in[4][6]),.A7(Img_Sram_Addr_in[4][7]),
						   .A8(Img_Sram_Addr_in[4][8]),
						   .DO0 (Img_SRAM_DATA_out[4][0]), .DO1 (Img_SRAM_DATA_out[4][1]), .DO2 (Img_SRAM_DATA_out[4][2]),
						   .DO3 (Img_SRAM_DATA_out[4][3]), .DO4 (Img_SRAM_DATA_out[4][4]), .DO5 (Img_SRAM_DATA_out[4][5]),
						   .DO6 (Img_SRAM_DATA_out[4][6]), .DO7 (Img_SRAM_DATA_out[4][7]), .DO8 (Img_SRAM_DATA_out[4][8]),
						   .DO9 (Img_SRAM_DATA_out[4][9]), .DO10(Img_SRAM_DATA_out[4][10]),.DO11(Img_SRAM_DATA_out[4][11]),
						   .DO12(Img_SRAM_DATA_out[4][12]),.DO13(Img_SRAM_DATA_out[4][13]),.DO14(Img_SRAM_DATA_out[4][14]),
						   .DO15(Img_SRAM_DATA_out[4][15]),.DO16(Img_SRAM_DATA_out[4][16]),.DO17(Img_SRAM_DATA_out[4][17]),
						   .DO18(Img_SRAM_DATA_out[4][18]),.DO19(Img_SRAM_DATA_out[4][19]),.DO20(Img_SRAM_DATA_out[4][20]),
						   .DO21(Img_SRAM_DATA_out[4][21]),.DO22(Img_SRAM_DATA_out[4][22]),.DO23(Img_SRAM_DATA_out[4][23]),
						   .DO24(Img_SRAM_DATA_out[4][24]),.DO25(Img_SRAM_DATA_out[4][25]),.DO26(Img_SRAM_DATA_out[4][26]),
						   .DO27(Img_SRAM_DATA_out[4][27]),.DO28(Img_SRAM_DATA_out[4][28]),.DO29(Img_SRAM_DATA_out[4][29]),
						   .DO30(Img_SRAM_DATA_out[4][30]),.DO31(Img_SRAM_DATA_out[4][31]),.DO32(Img_SRAM_DATA_out[4][32]),
						   .DO33(Img_SRAM_DATA_out[4][33]),.DO34(Img_SRAM_DATA_out[4][34]),.DO35(Img_SRAM_DATA_out[4][35]),
						   .DO36(Img_SRAM_DATA_out[4][36]),.DO37(Img_SRAM_DATA_out[4][37]),.DO38(Img_SRAM_DATA_out[4][38]),
						   .DO39(Img_SRAM_DATA_out[4][39]),.DO40(Img_SRAM_DATA_out[4][40]),.DO41(Img_SRAM_DATA_out[4][41]),
						   .DO42(Img_SRAM_DATA_out[4][42]),.DO43(Img_SRAM_DATA_out[4][43]),.DO44(Img_SRAM_DATA_out[4][44]),
						   .DO45(Img_SRAM_DATA_out[4][45]),.DO46(Img_SRAM_DATA_out[4][46]),.DO47(Img_SRAM_DATA_out[4][47]),
						   .DO48(Img_SRAM_DATA_out[4][48]),.DO49(Img_SRAM_DATA_out[4][49]),.DO50(Img_SRAM_DATA_out[4][50]),
						   .DO51(Img_SRAM_DATA_out[4][51]),.DO52(Img_SRAM_DATA_out[4][52]),.DO53(Img_SRAM_DATA_out[4][53]),
						   .DO54(Img_SRAM_DATA_out[4][54]),.DO55(Img_SRAM_DATA_out[4][55]),.DO56(Img_SRAM_DATA_out[4][56]),
						   .DO57(Img_SRAM_DATA_out[4][57]),.DO58(Img_SRAM_DATA_out[4][58]),.DO59(Img_SRAM_DATA_out[4][59]),
						   .DO60(Img_SRAM_DATA_out[4][60]),.DO61(Img_SRAM_DATA_out[4][61]),.DO62(Img_SRAM_DATA_out[4][62]),
                           .DO63(Img_SRAM_DATA_out[4][63]),
						   .DI0 (Img_SRAM_DATA_in[0]), .DI1 (Img_SRAM_DATA_in[1]), .DI2 (Img_SRAM_DATA_in[2]),
						   .DI3 (Img_SRAM_DATA_in[3]), .DI4 (Img_SRAM_DATA_in[4]), .DI5 (Img_SRAM_DATA_in[5]),
						   .DI6 (Img_SRAM_DATA_in[6]), .DI7 (Img_SRAM_DATA_in[7]), .DI8 (Img_SRAM_DATA_in[8]),
						   .DI9 (Img_SRAM_DATA_in[9]), .DI10(Img_SRAM_DATA_in[10]),.DI11(Img_SRAM_DATA_in[11]),
						   .DI12(Img_SRAM_DATA_in[12]),.DI13(Img_SRAM_DATA_in[13]),.DI14(Img_SRAM_DATA_in[14]),
						   .DI15(Img_SRAM_DATA_in[15]),.DI16(Img_SRAM_DATA_in[16]),.DI17(Img_SRAM_DATA_in[17]),
						   .DI18(Img_SRAM_DATA_in[18]),.DI19(Img_SRAM_DATA_in[19]),.DI20(Img_SRAM_DATA_in[20]),
						   .DI21(Img_SRAM_DATA_in[21]),.DI22(Img_SRAM_DATA_in[22]),.DI23(Img_SRAM_DATA_in[23]),
						   .DI24(Img_SRAM_DATA_in[24]),.DI25(Img_SRAM_DATA_in[25]),.DI26(Img_SRAM_DATA_in[26]),
						   .DI27(Img_SRAM_DATA_in[27]),.DI28(Img_SRAM_DATA_in[28]),.DI29(Img_SRAM_DATA_in[29]),
						   .DI30(Img_SRAM_DATA_in[30]),.DI31(Img_SRAM_DATA_in[31]),.DI32(Img_SRAM_DATA_in[32]),
						   .DI33(Img_SRAM_DATA_in[33]),.DI34(Img_SRAM_DATA_in[34]),.DI35(Img_SRAM_DATA_in[35]),
						   .DI36(Img_SRAM_DATA_in[36]),.DI37(Img_SRAM_DATA_in[37]),.DI38(Img_SRAM_DATA_in[38]),
						   .DI39(Img_SRAM_DATA_in[39]),.DI40(Img_SRAM_DATA_in[40]),.DI41(Img_SRAM_DATA_in[41]),
						   .DI42(Img_SRAM_DATA_in[42]),.DI43(Img_SRAM_DATA_in[43]),.DI44(Img_SRAM_DATA_in[44]),
						   .DI45(Img_SRAM_DATA_in[45]),.DI46(Img_SRAM_DATA_in[46]),.DI47(Img_SRAM_DATA_in[47]),
						   .DI48(Img_SRAM_DATA_in[48]),.DI49(Img_SRAM_DATA_in[49]),.DI50(Img_SRAM_DATA_in[50]),
						   .DI51(Img_SRAM_DATA_in[51]),.DI52(Img_SRAM_DATA_in[52]),.DI53(Img_SRAM_DATA_in[53]),
						   .DI54(Img_SRAM_DATA_in[54]),.DI55(Img_SRAM_DATA_in[55]),.DI56(Img_SRAM_DATA_in[56]),
						   .DI57(Img_SRAM_DATA_in[57]),.DI58(Img_SRAM_DATA_in[58]),.DI59(Img_SRAM_DATA_in[59]),
						   .DI60(Img_SRAM_DATA_in[60]),.DI61(Img_SRAM_DATA_in[61]),.DI62(Img_SRAM_DATA_in[62]),
                           .DI63(Img_SRAM_DATA_in[63]),
						   .CK(clk),.WEB(!Img_write_en[4]),.OE(1'b1), .CS(1'b1));
						
Kernel_SRAM_96b KernSRAM1 (.A0(Kernel_addr[0]),.A1(Kernel_addr[1]),.A2(Kernel_addr[2]),.A3(Kernel_addr[3]),
						   .A4(1'b0),.A5(1'b0),
						   .DO0 (Ker_SRAM_DATA_out1[0]), .DO1 (Ker_SRAM_DATA_out1[1]), .DO2 (Ker_SRAM_DATA_out1[2]),
						   .DO3 (Ker_SRAM_DATA_out1[3]), .DO4 (Ker_SRAM_DATA_out1[4]), .DO5 (Ker_SRAM_DATA_out1[5]),
						   .DO6 (Ker_SRAM_DATA_out1[6]), .DO7 (Ker_SRAM_DATA_out1[7]), .DO8 (Ker_SRAM_DATA_out1[8]),
						   .DO9 (Ker_SRAM_DATA_out1[9]), .DO10(Ker_SRAM_DATA_out1[10]),.DO11(Ker_SRAM_DATA_out1[11]),
						   .DO12(Ker_SRAM_DATA_out1[12]),.DO13(Ker_SRAM_DATA_out1[13]),.DO14(Ker_SRAM_DATA_out1[14]),
						   .DO15(Ker_SRAM_DATA_out1[15]),.DO16(Ker_SRAM_DATA_out1[16]),.DO17(Ker_SRAM_DATA_out1[17]),
						   .DO18(Ker_SRAM_DATA_out1[18]),.DO19(Ker_SRAM_DATA_out1[19]),.DO20(Ker_SRAM_DATA_out1[20]),
						   .DO21(Ker_SRAM_DATA_out1[21]),.DO22(Ker_SRAM_DATA_out1[22]),.DO23(Ker_SRAM_DATA_out1[23]),
						   .DO24(Ker_SRAM_DATA_out1[24]),.DO25(Ker_SRAM_DATA_out1[25]),.DO26(Ker_SRAM_DATA_out1[26]),
						   .DO27(Ker_SRAM_DATA_out1[27]),.DO28(Ker_SRAM_DATA_out1[28]),.DO29(Ker_SRAM_DATA_out1[29]),
						   .DO30(Ker_SRAM_DATA_out1[30]),.DO31(Ker_SRAM_DATA_out1[31]),.DO32(Ker_SRAM_DATA_out1[32]),
						   .DO33(Ker_SRAM_DATA_out1[33]),.DO34(Ker_SRAM_DATA_out1[34]),.DO35(Ker_SRAM_DATA_out1[35]),
						   .DO36(Ker_SRAM_DATA_out1[36]),.DO37(Ker_SRAM_DATA_out1[37]),.DO38(Ker_SRAM_DATA_out1[38]),
						   .DO39(Ker_SRAM_DATA_out1[39]),.DO40(Ker_SRAM_DATA_out1[40]),.DO41(Ker_SRAM_DATA_out1[41]),
						   .DO42(Ker_SRAM_DATA_out1[42]),.DO43(Ker_SRAM_DATA_out1[43]),.DO44(Ker_SRAM_DATA_out1[44]),
						   .DO45(Ker_SRAM_DATA_out1[45]),.DO46(Ker_SRAM_DATA_out1[46]),.DO47(Ker_SRAM_DATA_out1[47]),
						   .DO48(Ker_SRAM_DATA_out1[48]),.DO49(Ker_SRAM_DATA_out1[49]),.DO50(Ker_SRAM_DATA_out1[50]),
						   .DO51(Ker_SRAM_DATA_out1[51]),.DO52(Ker_SRAM_DATA_out1[52]),.DO53(Ker_SRAM_DATA_out1[53]),
						   .DO54(Ker_SRAM_DATA_out1[54]),.DO55(Ker_SRAM_DATA_out1[55]),.DO56(Ker_SRAM_DATA_out1[56]),
						   .DO57(Ker_SRAM_DATA_out1[57]),.DO58(Ker_SRAM_DATA_out1[58]),.DO59(Ker_SRAM_DATA_out1[59]),
						   .DO60(Ker_SRAM_DATA_out1[60]),.DO61(Ker_SRAM_DATA_out1[61]),.DO62(Ker_SRAM_DATA_out1[62]),
                           .DO63(Ker_SRAM_DATA_out1[63]),.DO64(Ker_SRAM_DATA_out1[64]),.DO65(Ker_SRAM_DATA_out1[65]),
						   .DO66(Ker_SRAM_DATA_out1[66]),.DO67(Ker_SRAM_DATA_out1[67]),.DO68(Ker_SRAM_DATA_out1[68]),
						   .DO69(Ker_SRAM_DATA_out1[69]),.DO70(Ker_SRAM_DATA_out1[70]),.DO71(Ker_SRAM_DATA_out1[71]),
						   .DO72(Ker_SRAM_DATA_out1[72]),.DO73(Ker_SRAM_DATA_out1[73]),.DO74(Ker_SRAM_DATA_out1[74]),
						   .DO75(Ker_SRAM_DATA_out1[75]),.DO76(Ker_SRAM_DATA_out1[76]),.DO77(Ker_SRAM_DATA_out1[77]),
						   .DO78(Ker_SRAM_DATA_out1[78]),.DO79(Ker_SRAM_DATA_out1[79]),.DO80(Ker_SRAM_DATA_out1[80]),
						   .DO81(Ker_SRAM_DATA_out1[81]),.DO82(Ker_SRAM_DATA_out1[82]),.DO83(Ker_SRAM_DATA_out1[83]),
						   .DO84(Ker_SRAM_DATA_out1[84]),.DO85(Ker_SRAM_DATA_out1[85]),.DO86(Ker_SRAM_DATA_out1[86]),
						   .DO87(Ker_SRAM_DATA_out1[87]),.DO88(Ker_SRAM_DATA_out1[88]),.DO89(Ker_SRAM_DATA_out1[89]),
						   .DO90(Ker_SRAM_DATA_out1[90]),.DO91(Ker_SRAM_DATA_out1[91]),.DO92(Ker_SRAM_DATA_out1[92]),
						   .DO93(Ker_SRAM_DATA_out1[93]),.DO94(Ker_SRAM_DATA_out1[94]),.DO95(Ker_SRAM_DATA_out1[95]),
						   .DI0 (Ker_SRAM_DATA_in1[0]), .DI1 (Ker_SRAM_DATA_in1[1]), .DI2 (Ker_SRAM_DATA_in1[2]),
						   .DI3 (Ker_SRAM_DATA_in1[3]), .DI4 (Ker_SRAM_DATA_in1[4]), .DI5 (Ker_SRAM_DATA_in1[5]),
						   .DI6 (Ker_SRAM_DATA_in1[6]), .DI7 (Ker_SRAM_DATA_in1[7]), .DI8 (Ker_SRAM_DATA_in1[8]),
						   .DI9 (Ker_SRAM_DATA_in1[9]), .DI10(Ker_SRAM_DATA_in1[10]),.DI11(Ker_SRAM_DATA_in1[11]),
						   .DI12(Ker_SRAM_DATA_in1[12]),.DI13(Ker_SRAM_DATA_in1[13]),.DI14(Ker_SRAM_DATA_in1[14]),
						   .DI15(Ker_SRAM_DATA_in1[15]),.DI16(Ker_SRAM_DATA_in1[16]),.DI17(Ker_SRAM_DATA_in1[17]),
						   .DI18(Ker_SRAM_DATA_in1[18]),.DI19(Ker_SRAM_DATA_in1[19]),.DI20(Ker_SRAM_DATA_in1[20]),
						   .DI21(Ker_SRAM_DATA_in1[21]),.DI22(Ker_SRAM_DATA_in1[22]),.DI23(Ker_SRAM_DATA_in1[23]),
						   .DI24(Ker_SRAM_DATA_in1[24]),.DI25(Ker_SRAM_DATA_in1[25]),.DI26(Ker_SRAM_DATA_in1[26]),
						   .DI27(Ker_SRAM_DATA_in1[27]),.DI28(Ker_SRAM_DATA_in1[28]),.DI29(Ker_SRAM_DATA_in1[29]),
						   .DI30(Ker_SRAM_DATA_in1[30]),.DI31(Ker_SRAM_DATA_in1[31]),.DI32(Ker_SRAM_DATA_in1[32]),
						   .DI33(Ker_SRAM_DATA_in1[33]),.DI34(Ker_SRAM_DATA_in1[34]),.DI35(Ker_SRAM_DATA_in1[35]),
						   .DI36(Ker_SRAM_DATA_in1[36]),.DI37(Ker_SRAM_DATA_in1[37]),.DI38(Ker_SRAM_DATA_in1[38]),
						   .DI39(Ker_SRAM_DATA_in1[39]),.DI40(Ker_SRAM_DATA_in1[40]),.DI41(Ker_SRAM_DATA_in1[41]),
						   .DI42(Ker_SRAM_DATA_in1[42]),.DI43(Ker_SRAM_DATA_in1[43]),.DI44(Ker_SRAM_DATA_in1[44]),
						   .DI45(Ker_SRAM_DATA_in1[45]),.DI46(Ker_SRAM_DATA_in1[46]),.DI47(Ker_SRAM_DATA_in1[47]),
						   .DI48(Ker_SRAM_DATA_in1[48]),.DI49(Ker_SRAM_DATA_in1[49]),.DI50(Ker_SRAM_DATA_in1[50]),
						   .DI51(Ker_SRAM_DATA_in1[51]),.DI52(Ker_SRAM_DATA_in1[52]),.DI53(Ker_SRAM_DATA_in1[53]),
						   .DI54(Ker_SRAM_DATA_in1[54]),.DI55(Ker_SRAM_DATA_in1[55]),.DI56(Ker_SRAM_DATA_in1[56]),
						   .DI57(Ker_SRAM_DATA_in1[57]),.DI58(Ker_SRAM_DATA_in1[58]),.DI59(Ker_SRAM_DATA_in1[59]),
						   .DI60(Ker_SRAM_DATA_in1[60]),.DI61(Ker_SRAM_DATA_in1[61]),.DI62(Ker_SRAM_DATA_in1[62]),
                           .DI63(Ker_SRAM_DATA_in1[63]),.DI64(Ker_SRAM_DATA_in1[64]),.DI65(Ker_SRAM_DATA_in1[65]),
						   .DI66(Ker_SRAM_DATA_in1[66]),.DI67(Ker_SRAM_DATA_in1[67]),.DI68(Ker_SRAM_DATA_in1[68]),
						   .DI69(Ker_SRAM_DATA_in1[69]),.DI70(Ker_SRAM_DATA_in1[70]),.DI71(Ker_SRAM_DATA_in1[71]),
						   .DI72(Ker_SRAM_DATA_in1[72]),.DI73(Ker_SRAM_DATA_in1[73]),.DI74(Ker_SRAM_DATA_in1[74]),
						   .DI75(Ker_SRAM_DATA_in1[75]),.DI76(Ker_SRAM_DATA_in1[76]),.DI77(Ker_SRAM_DATA_in1[77]),
						   .DI78(Ker_SRAM_DATA_in1[78]),.DI79(Ker_SRAM_DATA_in1[79]),.DI80(Ker_SRAM_DATA_in1[80]),
						   .DI81(Ker_SRAM_DATA_in1[81]),.DI82(Ker_SRAM_DATA_in1[82]),.DI83(Ker_SRAM_DATA_in1[83]),
						   .DI84(Ker_SRAM_DATA_in1[84]),.DI85(Ker_SRAM_DATA_in1[85]),.DI86(Ker_SRAM_DATA_in1[86]),
						   .DI87(Ker_SRAM_DATA_in1[87]),.DI88(Ker_SRAM_DATA_in1[88]),.DI89(Ker_SRAM_DATA_in1[89]),
						   .DI90(Ker_SRAM_DATA_in1[90]),.DI91(Ker_SRAM_DATA_in1[91]),.DI92(Ker_SRAM_DATA_in1[92]),
						   .DI93(Ker_SRAM_DATA_in1[93]),.DI94(Ker_SRAM_DATA_in1[94]),.DI95(Ker_SRAM_DATA_in1[95]),
						   .CK(clk),.WEB(!Ker_write_en_1), .OE(1'b1), .CS(1'b1));		
Kernel_SRAM_104b KernSRAM2(.A0(Kernel_addr[0]),.A1(Kernel_addr[1]),.A2(Kernel_addr[2]),.A3(Kernel_addr[3]),
						   .A4(1'b0),.A5(1'b0),
						   .DO0 (Ker_SRAM_DATA_out2[0]), .DO1 (Ker_SRAM_DATA_out2[1]), .DO2 (Ker_SRAM_DATA_out2[2]),
						   .DO3 (Ker_SRAM_DATA_out2[3]), .DO4 (Ker_SRAM_DATA_out2[4]), .DO5 (Ker_SRAM_DATA_out2[5]),
						   .DO6 (Ker_SRAM_DATA_out2[6]), .DO7 (Ker_SRAM_DATA_out2[7]), .DO8 (Ker_SRAM_DATA_out2[8]),
						   .DO9 (Ker_SRAM_DATA_out2[9]), .DO10(Ker_SRAM_DATA_out2[10]),.DO11(Ker_SRAM_DATA_out2[11]),
						   .DO12(Ker_SRAM_DATA_out2[12]),.DO13(Ker_SRAM_DATA_out2[13]),.DO14(Ker_SRAM_DATA_out2[14]),
						   .DO15(Ker_SRAM_DATA_out2[15]),.DO16(Ker_SRAM_DATA_out2[16]),.DO17(Ker_SRAM_DATA_out2[17]),
						   .DO18(Ker_SRAM_DATA_out2[18]),.DO19(Ker_SRAM_DATA_out2[19]),.DO20(Ker_SRAM_DATA_out2[20]),
						   .DO21(Ker_SRAM_DATA_out2[21]),.DO22(Ker_SRAM_DATA_out2[22]),.DO23(Ker_SRAM_DATA_out2[23]),
						   .DO24(Ker_SRAM_DATA_out2[24]),.DO25(Ker_SRAM_DATA_out2[25]),.DO26(Ker_SRAM_DATA_out2[26]),
						   .DO27(Ker_SRAM_DATA_out2[27]),.DO28(Ker_SRAM_DATA_out2[28]),.DO29(Ker_SRAM_DATA_out2[29]),
						   .DO30(Ker_SRAM_DATA_out2[30]),.DO31(Ker_SRAM_DATA_out2[31]),.DO32(Ker_SRAM_DATA_out2[32]),
						   .DO33(Ker_SRAM_DATA_out2[33]),.DO34(Ker_SRAM_DATA_out2[34]),.DO35(Ker_SRAM_DATA_out2[35]),
						   .DO36(Ker_SRAM_DATA_out2[36]),.DO37(Ker_SRAM_DATA_out2[37]),.DO38(Ker_SRAM_DATA_out2[38]),
						   .DO39(Ker_SRAM_DATA_out2[39]),.DO40(Ker_SRAM_DATA_out2[40]),.DO41(Ker_SRAM_DATA_out2[41]),
						   .DO42(Ker_SRAM_DATA_out2[42]),.DO43(Ker_SRAM_DATA_out2[43]),.DO44(Ker_SRAM_DATA_out2[44]),
						   .DO45(Ker_SRAM_DATA_out2[45]),.DO46(Ker_SRAM_DATA_out2[46]),.DO47(Ker_SRAM_DATA_out2[47]),
						   .DO48(Ker_SRAM_DATA_out2[48]),.DO49(Ker_SRAM_DATA_out2[49]),.DO50(Ker_SRAM_DATA_out2[50]),
						   .DO51(Ker_SRAM_DATA_out2[51]),.DO52(Ker_SRAM_DATA_out2[52]),.DO53(Ker_SRAM_DATA_out2[53]),
						   .DO54(Ker_SRAM_DATA_out2[54]),.DO55(Ker_SRAM_DATA_out2[55]),.DO56(Ker_SRAM_DATA_out2[56]),
						   .DO57(Ker_SRAM_DATA_out2[57]),.DO58(Ker_SRAM_DATA_out2[58]),.DO59(Ker_SRAM_DATA_out2[59]),
						   .DO60(Ker_SRAM_DATA_out2[60]),.DO61(Ker_SRAM_DATA_out2[61]),.DO62(Ker_SRAM_DATA_out2[62]),
                           .DO63(Ker_SRAM_DATA_out2[63]),.DO64(Ker_SRAM_DATA_out2[64]),.DO65(Ker_SRAM_DATA_out2[65]),
						   .DO66(Ker_SRAM_DATA_out2[66]),.DO67(Ker_SRAM_DATA_out2[67]),.DO68(Ker_SRAM_DATA_out2[68]),
						   .DO69(Ker_SRAM_DATA_out2[69]),.DO70(Ker_SRAM_DATA_out2[70]),.DO71(Ker_SRAM_DATA_out2[71]),
						   .DO72(Ker_SRAM_DATA_out2[72]),.DO73(Ker_SRAM_DATA_out2[73]),.DO74(Ker_SRAM_DATA_out2[74]),
						   .DO75(Ker_SRAM_DATA_out2[75]),.DO76(Ker_SRAM_DATA_out2[76]),.DO77(Ker_SRAM_DATA_out2[77]),
						   .DO78(Ker_SRAM_DATA_out2[78]),.DO79(Ker_SRAM_DATA_out2[79]),.DO80(Ker_SRAM_DATA_out2[80]),
						   .DO81(Ker_SRAM_DATA_out2[81]),.DO82(Ker_SRAM_DATA_out2[82]),.DO83(Ker_SRAM_DATA_out2[83]),
						   .DO84(Ker_SRAM_DATA_out2[84]),.DO85(Ker_SRAM_DATA_out2[85]),.DO86(Ker_SRAM_DATA_out2[86]),
						   .DO87(Ker_SRAM_DATA_out2[87]),.DO88(Ker_SRAM_DATA_out2[88]),.DO89(Ker_SRAM_DATA_out2[89]),
						   .DO90(Ker_SRAM_DATA_out2[90]),.DO91(Ker_SRAM_DATA_out2[91]),.DO92(Ker_SRAM_DATA_out2[92]),
						   .DO93(Ker_SRAM_DATA_out2[93]),.DO94(Ker_SRAM_DATA_out2[94]),.DO95(Ker_SRAM_DATA_out2[95]),
						   .DO96(Ker_SRAM_DATA_out2[96]),.DO97(Ker_SRAM_DATA_out2[97]),.DO98(Ker_SRAM_DATA_out2[98]),
						   .DO99(Ker_SRAM_DATA_out2[99]),.DO100(Ker_SRAM_DATA_out2[100]),.DO101(Ker_SRAM_DATA_out2[101]),
						   .DO102(Ker_SRAM_DATA_out2[102]),.DO103(Ker_SRAM_DATA_out2[103]),
						   .DI0 (Ker_SRAM_DATA_in2[0]), .DI1 (Ker_SRAM_DATA_in2[1]), .DI2 (Ker_SRAM_DATA_in2[2]),
						   .DI3 (Ker_SRAM_DATA_in2[3]), .DI4 (Ker_SRAM_DATA_in2[4]), .DI5 (Ker_SRAM_DATA_in2[5]),
						   .DI6 (Ker_SRAM_DATA_in2[6]), .DI7 (Ker_SRAM_DATA_in2[7]), .DI8 (Ker_SRAM_DATA_in2[8]),
						   .DI9 (Ker_SRAM_DATA_in2[9]), .DI10(Ker_SRAM_DATA_in2[10]),.DI11(Ker_SRAM_DATA_in2[11]),
						   .DI12(Ker_SRAM_DATA_in2[12]),.DI13(Ker_SRAM_DATA_in2[13]),.DI14(Ker_SRAM_DATA_in2[14]),
						   .DI15(Ker_SRAM_DATA_in2[15]),.DI16(Ker_SRAM_DATA_in2[16]),.DI17(Ker_SRAM_DATA_in2[17]),
						   .DI18(Ker_SRAM_DATA_in2[18]),.DI19(Ker_SRAM_DATA_in2[19]),.DI20(Ker_SRAM_DATA_in2[20]),
						   .DI21(Ker_SRAM_DATA_in2[21]),.DI22(Ker_SRAM_DATA_in2[22]),.DI23(Ker_SRAM_DATA_in2[23]),
						   .DI24(Ker_SRAM_DATA_in2[24]),.DI25(Ker_SRAM_DATA_in2[25]),.DI26(Ker_SRAM_DATA_in2[26]),
						   .DI27(Ker_SRAM_DATA_in2[27]),.DI28(Ker_SRAM_DATA_in2[28]),.DI29(Ker_SRAM_DATA_in2[29]),
						   .DI30(Ker_SRAM_DATA_in2[30]),.DI31(Ker_SRAM_DATA_in2[31]),.DI32(Ker_SRAM_DATA_in2[32]),
						   .DI33(Ker_SRAM_DATA_in2[33]),.DI34(Ker_SRAM_DATA_in2[34]),.DI35(Ker_SRAM_DATA_in2[35]),
						   .DI36(Ker_SRAM_DATA_in2[36]),.DI37(Ker_SRAM_DATA_in2[37]),.DI38(Ker_SRAM_DATA_in2[38]),
						   .DI39(Ker_SRAM_DATA_in2[39]),.DI40(Ker_SRAM_DATA_in2[40]),.DI41(Ker_SRAM_DATA_in2[41]),
						   .DI42(Ker_SRAM_DATA_in2[42]),.DI43(Ker_SRAM_DATA_in2[43]),.DI44(Ker_SRAM_DATA_in2[44]),
						   .DI45(Ker_SRAM_DATA_in2[45]),.DI46(Ker_SRAM_DATA_in2[46]),.DI47(Ker_SRAM_DATA_in2[47]),
						   .DI48(Ker_SRAM_DATA_in2[48]),.DI49(Ker_SRAM_DATA_in2[49]),.DI50(Ker_SRAM_DATA_in2[50]),
						   .DI51(Ker_SRAM_DATA_in2[51]),.DI52(Ker_SRAM_DATA_in2[52]),.DI53(Ker_SRAM_DATA_in2[53]),
						   .DI54(Ker_SRAM_DATA_in2[54]),.DI55(Ker_SRAM_DATA_in2[55]),.DI56(Ker_SRAM_DATA_in2[56]),
						   .DI57(Ker_SRAM_DATA_in2[57]),.DI58(Ker_SRAM_DATA_in2[58]),.DI59(Ker_SRAM_DATA_in2[59]),
						   .DI60(Ker_SRAM_DATA_in2[60]),.DI61(Ker_SRAM_DATA_in2[61]),.DI62(Ker_SRAM_DATA_in2[62]),
                           .DI63(Ker_SRAM_DATA_in2[63]),.DI64(Ker_SRAM_DATA_in2[64]),.DI65(Ker_SRAM_DATA_in2[65]),
						   .DI66(Ker_SRAM_DATA_in2[66]),.DI67(Ker_SRAM_DATA_in2[67]),.DI68(Ker_SRAM_DATA_in2[68]),
						   .DI69(Ker_SRAM_DATA_in2[69]),.DI70(Ker_SRAM_DATA_in2[70]),.DI71(Ker_SRAM_DATA_in2[71]),
						   .DI72(Ker_SRAM_DATA_in2[72]),.DI73(Ker_SRAM_DATA_in2[73]),.DI74(Ker_SRAM_DATA_in2[74]),
						   .DI75(Ker_SRAM_DATA_in2[75]),.DI76(Ker_SRAM_DATA_in2[76]),.DI77(Ker_SRAM_DATA_in2[77]),
						   .DI78(Ker_SRAM_DATA_in2[78]),.DI79(Ker_SRAM_DATA_in2[79]),.DI80(Ker_SRAM_DATA_in2[80]),
						   .DI81(Ker_SRAM_DATA_in2[81]),.DI82(Ker_SRAM_DATA_in2[82]),.DI83(Ker_SRAM_DATA_in2[83]),
						   .DI84(Ker_SRAM_DATA_in2[84]),.DI85(Ker_SRAM_DATA_in2[85]),.DI86(Ker_SRAM_DATA_in2[86]),
						   .DI87(Ker_SRAM_DATA_in2[87]),.DI88(Ker_SRAM_DATA_in2[88]),.DI89(Ker_SRAM_DATA_in2[89]),
						   .DI90(Ker_SRAM_DATA_in2[90]),.DI91(Ker_SRAM_DATA_in2[91]),.DI92(Ker_SRAM_DATA_in2[92]),
						   .DI93(Ker_SRAM_DATA_in2[93]),.DI94(Ker_SRAM_DATA_in2[94]),.DI95(Ker_SRAM_DATA_in2[95]),
						   .DI96(Ker_SRAM_DATA_in2[96]),.DI97(Ker_SRAM_DATA_in2[97]),.DI98(Ker_SRAM_DATA_in2[98]),
						   .DI99(Ker_SRAM_DATA_in2[99]),.DI100(Ker_SRAM_DATA_in2[100]),.DI101(Ker_SRAM_DATA_in2[101]),
						   .DI102(Ker_SRAM_DATA_in2[102]),.DI103(Ker_SRAM_DATA_in2[103]),
						   .CK(clk),.WEB(!Ker_write_en_2),.OE(1'b1), .CS(1'b1));						


endmodule