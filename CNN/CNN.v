//############################################################################
//=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Convolution Neural Network 
//   Author     		: Cheng-Te Chang (chengdez.ee12@nycu.edu.tw)
//
//=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V1.0 (Release Date: 2024-02)
//
//=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1=+1
//############################################################################

module CNN(
    //Input Port
    clk,
    rst_n,
    in_valid,
    Img,
    Kernel,
	Weight,
    Opt,

    //Output Port
    out_valid,
    out
    );


//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

input rst_n, clk, in_valid;
input [inst_sig_width+inst_exp_width:0] Img, Kernel, Weight;
input [1:0] Opt;

output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

reg [31:0] img_store[20:0];
reg [31:0] conv_result[15:0];
reg [1:0] opt_store;
reg in_valid_delay,in_valid_delay2,in_valid_delay3;
reg [1:0] count;
reg [6:0] count2;
reg [31:0] img_buffer[1:0];
reg [31:0] shift_reg[5:0][3:0];
reg in_valid_start;
reg [31:0] kernel_store[26:0];

reg [31:0] mult_in_1_1, mult_in_1_2;
reg [31:0] mult_in_2_1, mult_in_2_2;
reg [31:0] mult_in_3_1, mult_in_3_2;
reg [31:0] mult_in_4_1, mult_in_4_2;
reg [31:0] mult_in_5_1, mult_in_5_2;
reg [31:0] mult_in_6_1, mult_in_6_2;
reg [31:0] mult_in_7_1, mult_in_7_2;
reg [31:0] mult_in_8_1, mult_in_8_2;
reg [31:0] mult_in_9_1, mult_in_9_2;
reg between_inout;

wire [31:0] mult_out_1,mult_out_2,mult_out_3,mult_out_4,mult_out_5,mult_out_6,mult_out_7,mult_out_8,mult_out_9;
reg [31:0] mult_pipe[8:0];
wire [31:0] add_tmp[8:0];

reg [31:0] comp_in_1_1, comp_in_1_2;
reg [31:0] comp_in_2_1, comp_in_2_2;
reg [31:0] comp_in_3_1, comp_in_3_2;
reg [31:0] comp_in_4_1, comp_in_4_2;
reg [31:0] comp_tmp[1:0];
reg [31:0] FC_data[3:0];
reg [31:0] weight_store[3:0];
reg [31:0] normalize_tmp[3:0];
reg [31:0] adder_in[4:0][1:0];
reg [31:0] div_in[3:0][1:0];
wire [31:0] div_out[3:0];
wire op;

wire [31:0] comp_out_1_z0,comp_out_1_z1,comp_out_2_z0,comp_out_2_z1,comp_out_3_z0,comp_out_3_z1,comp_out_4_z0,comp_out_4_z1;
wire [31:0] ln_out, exp_out;
reg [31:0] z2;
reg [31:0] act_in;
reg [31:0] exp_in;

//---------------------------------------------------------------------
//   Implement
//---------------------------------------------------------------------

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) 	begin
		between_inout <= 'd0;
	end
	else begin
		if(in_valid)
			between_inout <= 'd1;
		else if(out_valid)
			between_inout <= 'd0;
		else
			between_inout <= between_inout;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) 	begin
		in_valid_delay <= 'd0;
		in_valid_delay2 <= 'd0;
	end
	else begin
		in_valid_delay <= in_valid;
		in_valid_delay2 <= in_valid_delay;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) 	opt_store <= 'd0;
	else begin
		if(in_valid & !in_valid_delay) 	opt_store <= Opt;
		else							opt_store <= opt_store;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) in_valid_start <= 'd0;
	else begin
		if(in_valid) in_valid_start <= 'd1;
		else if(out_valid) in_valid_start <= 'd0;
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) 	count2 <= 'd0;
	else begin
		if(in_valid) begin
			if(!in_valid_delay)	count2 <= 'd0;
			else				count2 <= count2 + 'd1;
		end
		else begin
			if(between_inout || count2 == 'd62 || count2 == 'd63 || count2 == 'd64 || count2 == 'd65 || count2 == 'd66) 	count2 <= count2 + 'd1;
			else			count2 <= 'd0;
		end
	end
end

always @ (posedge clk) begin
	if(in_valid) begin
		img_buffer[0] <= Img;
	end
	else begin
		img_buffer[0] <= 0;
	end
end
always @ (posedge clk) begin
	if(in_valid_delay) begin
		img_buffer[1] <= img_buffer[0];
	end
	else begin
		img_buffer[1] <= 0;
	end
end
//shift reg
//kernel_store
always @ (posedge clk) begin
	if(in_valid) begin
		if(count2 < 'd8) begin
			kernel_store[8] <= Kernel;
		end
		else kernel_store[8] <= kernel_store[8];
	end
end
always @ (posedge clk) begin
	if(in_valid) begin
		if(count2 < 'd17) begin
			kernel_store[17] <= Kernel;
		end
		else kernel_store[17] <= kernel_store[17];
	end
end
always @ (posedge clk) begin
	if(in_valid) begin
		if(count2 < 'd26) begin
			kernel_store[26] <= Kernel;
		end
		else kernel_store[26] <= kernel_store[26];
	end
end

//weight
always @ (posedge clk) begin
	if(in_valid) begin
		if(count2 < 'd3) begin
			weight_store[3] <= Weight;
		end
		else weight_store[3] <= weight_store[3];
	end
end
always @ (posedge clk) begin
	if(in_valid) begin
		if(count2 < 'd3) begin
			weight_store[2] <= weight_store[3];
		end
		else weight_store[2] <= weight_store[2];
	end
end
always @ (posedge clk) begin
	if(!rst_n) 	begin
		weight_store[1] <= 'd0;
	end
	else begin
		if(in_valid) begin
			if(count2 < 'd3) begin
				weight_store[1] <= weight_store[2];
			end
			else weight_store[1] <= weight_store[1];
		end
	end
end
always @ (posedge clk) begin
	if(in_valid) begin
		if(count2 < 'd3) begin
			weight_store[0] <= weight_store[1];
		end
		else weight_store[0] <= weight_store[0];
	end
end
genvar j;
generate
for(j=0;j<8;j=j+1) begin : b
	always @ (posedge clk) begin
		if(in_valid) begin
			if(count2 < 'd8) begin
				kernel_store[j] <= kernel_store[j+1];
			end
			else begin
				kernel_store[j] <= kernel_store[j];
			end
		end
	end
end
endgenerate
generate
for(j=9;j<17;j=j+1) begin : c
	always @ (posedge clk) begin
		if(in_valid) begin
			if(count2 < 'd17) begin
				kernel_store[j] <= kernel_store[j+1];
			end
			else begin
				kernel_store[j] <= kernel_store[j];
			end
		end
	end
end
endgenerate
generate
for(j=18;j<26;j=j+1) begin : e
	always @ (posedge clk) begin
		if(in_valid) begin
			if(count2 < 'd26) begin
				kernel_store[j] <= kernel_store[j+1];
			end
			else begin
				kernel_store[j] <= kernel_store[j];
			end
		end
	end
end
endgenerate
//image
always @ (posedge clk) begin
	if(count2 > 'd0 && count2 < 'd56) begin
		if(count2[1:0] == 1) begin
			if(opt_store[1]) begin
				if(count2 == 1) begin
					shift_reg[0][3] <= 'd0;
					shift_reg[0][2] <= img_buffer[1]; 
					shift_reg[0][1] <= img_buffer[1];
					shift_reg[0][0] <= 'd0;
				end
				else if((count2 == 'd17) || (count2 == 'd33) || (count2 == 'd49)) begin
					shift_reg[0][3] <= img_buffer[1]; 
					shift_reg[0][2] <= shift_reg[0][3]; 
					shift_reg[0][1] <= shift_reg[0][2];
					shift_reg[0][0] <= shift_reg[0][1];
				end
				else if(((count2 == 'd21)) || (count2 == 'd37)) begin
					shift_reg[0][3] <= 'd0; 
					shift_reg[0][2] <= img_buffer[1]; 
					shift_reg[0][1] <= shift_reg[0][3];
					shift_reg[0][0] <= shift_reg[0][3];
				end
				else if((count2 == 'd13) || (count2 == 'd29) || (count2 == 'd45)) begin
					shift_reg[0][3] <= img_buffer[1]; 
					shift_reg[0][2] <= img_buffer[1]; 
					shift_reg[0][1] <= shift_reg[0][2];
					shift_reg[0][0] <= shift_reg[0][1];
				end
				else begin
					shift_reg[0][3] <= 'd0; 
					shift_reg[0][2] <= img_buffer[1]; 
					shift_reg[0][1] <= shift_reg[0][2];
					shift_reg[0][0] <= shift_reg[0][1];
				end
			end
			else begin
				shift_reg[0][3] <= 'd0; 
				shift_reg[0][2] <= 'd0; 
				shift_reg[0][1] <= 'd0;
				shift_reg[0][0] <= 'd0;
			end
		end
		else begin
			shift_reg[0][3] <= shift_reg[0][3];
			shift_reg[0][2] <= shift_reg[0][2];
			shift_reg[0][1] <= shift_reg[0][1];
			shift_reg[0][0] <= shift_reg[0][0];
		end
	end
	else begin
		shift_reg[0][3] <= shift_reg[0][3];
		shift_reg[0][2] <= shift_reg[0][2];
		shift_reg[0][1] <= shift_reg[0][1];
		shift_reg[0][0] <= shift_reg[0][0];
	end
end
genvar i;
generate
for(i=1;i<4;i=i+1) begin: a
	always @ (posedge clk) begin
		if(count2 > 'd0 && count2 < 'd56) begin
			if(count2[1:0] == i) begin
				if(opt_store[1]) begin
					if(count2 == i) begin
						shift_reg[i][3] <= 'd0;
						shift_reg[i][2] <= img_buffer[1]; 
						shift_reg[i][1] <= img_buffer[1];
						shift_reg[i][0] <= 'd0;
					end
					else if(((count2 == (i+'d16)) || (count2 == (i+'d32)) || (count2 == (i+'d48)))) begin
						shift_reg[i][3] <= img_buffer[1]; 
						shift_reg[i][2] <= shift_reg[i][3]; 
						shift_reg[i][1] <= shift_reg[i][2];
						shift_reg[i][0] <= shift_reg[i][1];
					end
					else if(((count2 == (i+'d20)) || (count2 == (i+'d36)))) begin
						shift_reg[i][3] <= 'd0; 
						shift_reg[i][2] <= img_buffer[1]; 
						shift_reg[i][1] <= shift_reg[i][3];
						shift_reg[i][0] <= shift_reg[i][3];
					end
					else if((count2 == i+'d12) || (count2 == i+'d28) || (count2 == i+'d44)) begin
						shift_reg[i][3] <= img_buffer[1]; 
						shift_reg[i][2] <= img_buffer[1]; 
						shift_reg[i][1] <= shift_reg[i][2];
						shift_reg[i][0] <= shift_reg[i][1];
					end
					else begin
						shift_reg[i][3] <= 'd0; 
						shift_reg[i][2] <= img_buffer[1]; 
						shift_reg[i][1] <= shift_reg[i][2];
						shift_reg[i][0] <= shift_reg[i][1];
					end
				end
				else begin
					if(count2 == i) begin
						shift_reg[i][3] <= 'd0;
						shift_reg[i][2] <= img_buffer[1]; 
						shift_reg[i][1] <= 'd0;
						shift_reg[i][0] <= 'd0;
					end
					else if(((count2 == (i+'d16)) || (count2 == (i+'d32)))) begin
						shift_reg[i][3] <= img_buffer[1]; 
						shift_reg[i][2] <= shift_reg[i][3]; 
						shift_reg[i][1] <= shift_reg[i][2];
						shift_reg[i][0] <= shift_reg[i][1];
					end
					else if(((count2 == (i+'d20)) || (count2 == (i+'d36)))) begin
						shift_reg[i][3] <= 'd0; 
						shift_reg[i][2] <= img_buffer[1]; 
						shift_reg[i][1] <= shift_reg[i][3];
						shift_reg[i][0] <= 'd0;
					end
					else if((count2 == i+'d12) || (count2 == i+'d28) || (count2 == i+'d44)) begin
						shift_reg[i][3] <= 'd0; 
						shift_reg[i][2] <= img_buffer[1]; 
						shift_reg[i][1] <= shift_reg[i][2];
						shift_reg[i][0] <= shift_reg[i][1];
					end
					else begin
						shift_reg[i][3] <= 'd0; 
						shift_reg[i][2] <= img_buffer[1]; 
						shift_reg[i][1] <= shift_reg[i][2];
						shift_reg[i][0] <= shift_reg[i][1];
					end
				end
			end
			else begin
				shift_reg[i][3] <= shift_reg[i][3];
				shift_reg[i][2] <= shift_reg[i][2];
				shift_reg[i][1] <= shift_reg[i][1];
				shift_reg[i][0] <= shift_reg[i][0];
			end
		end
		else begin
			shift_reg[i][3] <= shift_reg[i][3];
			shift_reg[i][2] <= shift_reg[i][2];
			shift_reg[i][1] <= shift_reg[i][1];
			shift_reg[i][0] <= shift_reg[i][0];
		end
	end
end
endgenerate
always @ (posedge clk) begin
	if(count2 > 'd0 && count2 < 'd56) begin
		if(count2[1:0] == 0) begin
			if(opt_store[1]) begin
				if(count2 == 4) begin
					shift_reg[4][3] <= 'd0;
					shift_reg[4][2] <= img_buffer[1]; 
					shift_reg[4][1] <= img_buffer[1];
					shift_reg[4][0] <= 'd0;
				end
				else if((count2 == 'd20) || (count2 == 'd36) || (count2 == 'd52)) begin
					shift_reg[4][3] <= img_buffer[1]; 
					shift_reg[4][2] <= shift_reg[4][3]; 
					shift_reg[4][1] <= shift_reg[4][2];
					shift_reg[4][0] <= shift_reg[4][1];
				end
				else if((count2 == 'd24) || (count2 == 'd40)) begin
					shift_reg[4][3] <= 'd0; 
					shift_reg[4][2] <= img_buffer[1]; 
					shift_reg[4][1] <= shift_reg[4][3];
					shift_reg[4][0] <= shift_reg[4][3];
				end
				else if((count2 == 'd16) || (count2 == 'd32) || (count2 == 'd48)) begin
					shift_reg[4][3] <= img_buffer[1]; 
					shift_reg[4][2] <= img_buffer[1]; 
					shift_reg[4][1] <= shift_reg[4][2];
					shift_reg[4][0] <= shift_reg[4][1];
				end
				else begin
					shift_reg[4][3] <= 'd0; 
					shift_reg[4][2] <= img_buffer[1]; 
					shift_reg[4][1] <= shift_reg[4][2];
					shift_reg[4][0] <= shift_reg[4][1];
				end
			end
			else begin
				if(count2 == 'd4) begin
					shift_reg[4][3] <= 'd0;
					shift_reg[4][2] <= img_buffer[1]; 
					shift_reg[4][1] <= 'd0;
					shift_reg[4][0] <= 'd0;
				end
				else if((count2 == 'd20) || (count2 == 'd36)) begin
					shift_reg[4][3] <= img_buffer[1]; 
					shift_reg[4][2] <= shift_reg[4][3]; 
					shift_reg[4][1] <= shift_reg[4][2];
					shift_reg[4][0] <= shift_reg[4][1];
				end
				else if((count2 == 'd24) || (count2 == 'd40)) begin
					shift_reg[4][3] <= 'd0; 
					shift_reg[4][2] <= img_buffer[1]; 
					shift_reg[4][1] <= shift_reg[4][3];
					shift_reg[4][0] <= 'd0;
				end
				else if((count2 == 'd16) || (count2 == 'd32) || (count2 == 'd48)) begin
					shift_reg[4][3] <= 'd0; 
					shift_reg[4][2] <= img_buffer[1]; 
					shift_reg[4][1] <= shift_reg[4][2];
					shift_reg[4][0] <= shift_reg[4][1];
				end
				else begin
					shift_reg[4][3] <= 'd0; 
					shift_reg[4][2] <= img_buffer[1]; 
					shift_reg[4][1] <= shift_reg[4][2];
					shift_reg[4][0] <= shift_reg[4][1];
				end
			end
		end
		else begin
			shift_reg[4][3] <= shift_reg[4][3];
			shift_reg[4][2] <= shift_reg[4][2];
			shift_reg[4][1] <= shift_reg[4][1];
			shift_reg[4][0] <= shift_reg[4][0];
		end
	end
	else begin
		shift_reg[4][3] <= shift_reg[4][3];
		shift_reg[4][2] <= shift_reg[4][2];
		shift_reg[4][1] <= shift_reg[4][1];
		shift_reg[4][0] <= shift_reg[4][0];
	end
end
always @ (posedge clk) begin
	if(count2 > 'd0 && count2 < 'd56) begin
		if(count2[1:0] == 0) begin
			if(opt_store[1]) begin
				if(count2 == 4) begin
					shift_reg[5][3] <= 'd0;
					shift_reg[5][2] <= img_buffer[1]; 
					shift_reg[5][1] <= img_buffer[1];
					shift_reg[5][0] <= 'd0;
				end
				else if((count2 == 'd20) || (count2 == 'd36) || (count2 == 'd52)) begin
					shift_reg[5][3] <= img_buffer[1]; 
					shift_reg[5][2] <= shift_reg[5][3]; 
					shift_reg[5][1] <= shift_reg[5][2];
					shift_reg[5][0] <= shift_reg[5][1];
				end
				else if(((count2 == 'd24)) || (count2 == 'd40)) begin
					shift_reg[5][3] <= 'd0; 
					shift_reg[5][2] <= img_buffer[1]; 
					shift_reg[5][1] <= shift_reg[5][3];
					shift_reg[5][0] <= shift_reg[5][3];
				end
				else if((count2 == 'd16) || (count2 == 'd32) || (count2 == 'd48)) begin
					shift_reg[5][3] <= img_buffer[1]; 
					shift_reg[5][2] <= img_buffer[1]; 
					shift_reg[5][1] <= shift_reg[5][2];
					shift_reg[5][0] <= shift_reg[5][1];
				end
				else begin
					shift_reg[5][3] <= 'd0; 
					shift_reg[5][2] <= img_buffer[1]; 
					shift_reg[5][1] <= shift_reg[5][2];
					shift_reg[5][0] <= shift_reg[5][1];
				end
			end
			else begin
				shift_reg[5][3] <= 'd0; 
				shift_reg[5][2] <= 'd0; 
				shift_reg[5][1] <= 'd0;
				shift_reg[5][0] <= 'd0;
			end
		end
		else begin
			shift_reg[5][3] <= shift_reg[5][3];
			shift_reg[5][2] <= shift_reg[5][2];
			shift_reg[5][1] <= shift_reg[5][1];
			shift_reg[5][0] <= shift_reg[5][0];
		end
	end
	else begin
		shift_reg[5][3] <= shift_reg[5][3];
		shift_reg[5][2] <= shift_reg[5][2];
		shift_reg[5][1] <= shift_reg[5][1];
		shift_reg[5][0] <= shift_reg[5][0];
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid <= 'd0;
	else begin
		if(opt_store == 'd0) begin
			if(count2 == 'd61 || count2 == 'd63 || count2 == 'd64 || count2 == 'd62)	out_valid <= 'd1;
			else																		out_valid <= 'd0;
		end
		else begin
			if(count2 == 'd66 || count2 == 'd63 || count2 == 'd64 || count2 == 'd65)	out_valid <= 'd1;
			else																		out_valid <= 'd0;
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) out <= 'd0;
	else begin
		if(opt_store == 'd0) begin
			if(count2 == 'd61 || count2 == 'd62 || count2 == 'd63 || count2 == 'd64) out <= div_out[0];
			else out <= 'd0;
		end                 
		else if(count2 == 'd66 || count2 == 'd63 || count2 == 'd64 || count2 == 'd65) begin
			if(opt_store == 'd3)	out <= ln_out;
			else					out <= div_out[1];
		end
		else begin
			out <= 'd0;
		end
	end
end

// Convolution
always @ * begin
	if(count2 < 'd57) begin
		case(count2[1:0])
		'd0 :	begin
					mult_in_1_2 = shift_reg[0][0];
					mult_in_2_2 = shift_reg[1][0];
					mult_in_3_2 = shift_reg[2][0];
					mult_in_4_2 = shift_reg[0][1];
					mult_in_5_2 = shift_reg[1][1];
					mult_in_6_2 = shift_reg[2][1];
					mult_in_7_2 = shift_reg[0][2];
					mult_in_8_2 = shift_reg[1][2];
					mult_in_9_2 = shift_reg[2][2];
				end
		'd1 :	begin
					mult_in_1_2 = shift_reg[1][0];
					mult_in_2_2 = shift_reg[2][0];
					mult_in_3_2 = shift_reg[3][0];
					mult_in_4_2 = shift_reg[1][1];
					mult_in_5_2 = shift_reg[2][1];
					mult_in_6_2 = shift_reg[3][1];
					mult_in_7_2 = shift_reg[1][2];
					mult_in_8_2 = shift_reg[2][2];
					mult_in_9_2 = shift_reg[3][2];
				end
		'd2 :	begin
					mult_in_1_2 = shift_reg[2][0];
					mult_in_2_2 = shift_reg[3][0];
					mult_in_3_2 = shift_reg[4][0];
					mult_in_4_2 = shift_reg[2][1];
					mult_in_5_2 = shift_reg[3][1];
					mult_in_6_2 = shift_reg[4][1];
					mult_in_7_2 = shift_reg[2][2];
					mult_in_8_2 = shift_reg[3][2];
					mult_in_9_2 = shift_reg[4][2];
				end
		'd3 :	begin
					mult_in_1_2 = shift_reg[3][0];
					mult_in_2_2 = shift_reg[4][0];
					mult_in_3_2 = shift_reg[5][0];
					mult_in_4_2 = shift_reg[3][1];
					mult_in_5_2 = shift_reg[4][1];
					mult_in_6_2 = shift_reg[5][1];
					mult_in_7_2 = shift_reg[3][2];
					mult_in_8_2 = shift_reg[4][2];
					mult_in_9_2 = shift_reg[5][2];
				end
		endcase
	end
	else begin
		mult_in_1_2 = FC_data[0];
		mult_in_2_2 = FC_data[1];
		mult_in_3_2 = FC_data[0];
		mult_in_4_2 = FC_data[1];
		mult_in_5_2 = FC_data[2];
		mult_in_6_2 = FC_data[3];
		mult_in_7_2 = FC_data[2];
		mult_in_8_2 = FC_data[3];
		mult_in_9_2 = 'd0;
	end
	if((count2 < 'd24)) begin
		mult_in_1_1 = kernel_store[0];
		mult_in_2_1 = kernel_store[1];
		mult_in_3_1 = kernel_store[2];
		mult_in_4_1 = kernel_store[3];
		mult_in_5_1 = kernel_store[4];
		mult_in_6_1 = kernel_store[5];
		mult_in_7_1 = kernel_store[6];
		mult_in_8_1 = kernel_store[7];
		mult_in_9_1 = kernel_store[8];
	end
	else if(count2 < 'd40) begin
		mult_in_1_1 = kernel_store[9];
		mult_in_2_1 = kernel_store[10];
		mult_in_3_1 = kernel_store[11];
		mult_in_4_1 = kernel_store[12];
		mult_in_5_1 = kernel_store[13];
		mult_in_6_1 = kernel_store[14];
		mult_in_7_1 = kernel_store[15];
		mult_in_8_1 = kernel_store[16];
		mult_in_9_1 = kernel_store[17];
	end
	else if(count2 == 'd59)begin
		mult_in_1_1 = weight_store[0];
		mult_in_2_1 = weight_store[2];
		mult_in_3_1 = weight_store[1];
		mult_in_4_1 = weight_store[3];
		mult_in_5_1 = weight_store[0];
		mult_in_6_1 = weight_store[2];
		mult_in_7_1 = weight_store[1];
		mult_in_8_1 = weight_store[3];
		mult_in_9_1 = 'd0;
	end
	else begin
		mult_in_1_1 = kernel_store[18];
		mult_in_2_1 = kernel_store[19];
		mult_in_3_1 = kernel_store[20];
		mult_in_4_1 = kernel_store[21];
		mult_in_5_1 = kernel_store[22];
		mult_in_6_1 = kernel_store[23];
		mult_in_7_1 = kernel_store[24];
		mult_in_8_1 = kernel_store[25];
		mult_in_9_1 = kernel_store[26];
	end
end

always @ * begin
adder_in[0][0] = mult_out_1;
adder_in[1][0] = mult_out_3;
adder_in[2][0] = mult_out_5;
adder_in[3][0] = mult_out_7;
adder_in[4][0] = conv_result[1];

adder_in[0][1] = mult_out_2;
adder_in[1][1] = mult_out_4;
adder_in[2][1] = mult_out_6;
adder_in[3][1] = mult_out_8;
adder_in[4][1] = mult_out_9;

	if(count2 == 'd60) begin
		adder_in[0][0] = FC_data[0];
		adder_in[1][0] = FC_data[1];
		adder_in[2][0] = FC_data[2];
		adder_in[3][0] = FC_data[3];
		adder_in[4][0] = comp_out_3_z0;
		
		adder_in[0][1] = comp_out_4_z1;
		adder_in[1][1] = comp_out_4_z1;
		adder_in[2][1] = comp_out_4_z1;
		adder_in[3][1] = comp_out_4_z1;
		adder_in[4][1] = comp_out_4_z1;
	end
	else if(count2 == 'd62 || count2 == 'd63 || count2 == 'd64 || count2 == 'd65) begin
		adder_in[0][0] = exp_out;
		adder_in[0][1] = 'h3F800000;
		
		adder_in[1][0] = exp_out;
		adder_in[1][1] = 'hBF800000;
	end
end
assign op = (count2 == 'd60) ? 1 : 0;

DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler1(.a(mult_in_1_1), .b(mult_in_1_2), .rnd(3'b0), .z(mult_out_1));
DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler2(.a(mult_in_2_1), .b(mult_in_2_2), .rnd(3'b0), .z(mult_out_2));
DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler3(.a(mult_in_3_1), .b(mult_in_3_2), .rnd(3'b0), .z(mult_out_3));
DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler4(.a(mult_in_4_1), .b(mult_in_4_2), .rnd(3'b0), .z(mult_out_4));
DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler5(.a(mult_in_5_1), .b(mult_in_5_2), .rnd(3'b0), .z(mult_out_5));
DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler6(.a(mult_in_6_1), .b(mult_in_6_2), .rnd(3'b0), .z(mult_out_6));
DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler7(.a(mult_in_7_1), .b(mult_in_7_2), .rnd(3'b0), .z(mult_out_7));
DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler8(.a(mult_in_8_1), .b(mult_in_8_2), .rnd(3'b0), .z(mult_out_8));
DW_fp_mult #(inst_sig_width, inst_exp_width, 0) multipler9(.a(mult_in_9_1), .b(mult_in_9_2), .rnd(3'b0), .z(mult_out_9));

always @ (posedge clk) begin
	mult_pipe[0] <= add_tmp[0];
end
always @ (posedge clk) begin
	mult_pipe[1] <= add_tmp[1];
end
always @ (posedge clk) begin
	mult_pipe[2] <= add_tmp[2];
end
always @ (posedge clk) begin
	mult_pipe[3] <= add_tmp[3];
end
always @ (posedge clk) begin
	mult_pipe[4] <= add_tmp[4];
end

DW_fp_addsub #(inst_sig_width, inst_exp_width, 0) adder1(.a(adder_in[0][0]), .b(adder_in[0][1]), .rnd(3'b0), .z(add_tmp[0]), .op(op));
DW_fp_addsub #(inst_sig_width, inst_exp_width, 0) adder2(.a(adder_in[1][0]), .b(adder_in[1][1]), .rnd(3'b0), .z(add_tmp[1]), .op(op));
DW_fp_addsub #(inst_sig_width, inst_exp_width, 0) adder3(.a(adder_in[2][0]), .b(adder_in[2][1]), .rnd(3'b0), .z(add_tmp[2]), .op(op));
DW_fp_addsub #(inst_sig_width, inst_exp_width, 0) adder4(.a(adder_in[3][0]), .b(adder_in[3][1]), .rnd(3'b0), .z(add_tmp[3]), .op(op));
DW_fp_addsub #(inst_sig_width, inst_exp_width, 0) adder5(.a(adder_in[4][0]), .b(adder_in[4][1]), .rnd(3'b0), .z(add_tmp[4]), .op(op));
DW_fp_sum4   #(inst_sig_width, inst_exp_width, 0, 0) adder6(.a(mult_pipe[0]) , .b(mult_pipe[1]), .c(mult_pipe[2]), .d(mult_pipe[3]), .rnd(3'b0), .z(add_tmp[5]));
DW_fp_add #(inst_sig_width, inst_exp_width, 0) adder7(.a(mult_pipe[4]), .b(add_tmp[5]), .rnd(3'b0), .z(add_tmp[6]));

always @ (posedge clk) begin
	if(count2 == 'd7 || count2 == 'd8)		conv_result[15] <= 'd0;
	else					conv_result[15] <= add_tmp[6];
end
generate
for(i=0;i<15;i=i+1) begin : d
	always @ (posedge clk) begin
		if(count2 == 'd7 || count2 == 'd8)		conv_result[i] <= 'd0;
		else					conv_result[i] <= conv_result[i+1];
	end
end
endgenerate

always @ * begin
	if(count2 == 'd61) begin
		div_in[0][0] = FC_data[0];
		div_in[0][1] = normalize_tmp[0];
	end
	else if(count2 == 'd62) begin
		div_in[0][0] = FC_data[1];
		div_in[0][1] = normalize_tmp[0];
	end
	else if(count2 == 'd63) begin
		div_in[0][0] = FC_data[2];
		div_in[0][1] = normalize_tmp[0];
	end
	else if(count2 == 'd64) begin
		div_in[0][0] = FC_data[3];
		div_in[0][1] = normalize_tmp[0];
	end
	else begin
		div_in[0][0] = FC_data[0];
		
		div_in[0][1] = normalize_tmp[0];
	end
	

	div_in[1][1] = normalize_tmp[1];
	if(opt_store == 'd2)
		div_in[1][0] = 'h3F800000;
	else
		div_in[1][0] = normalize_tmp[2];


	if(opt_store == 'd2)
		exp_in = {~act_in[31], act_in[30:0]};
	else if(opt_store == 'd1)
		exp_in = z2;
	else
		exp_in = act_in;

end

DW_fp_cmp #(inst_sig_width, inst_exp_width, 0) comp1(.a(comp_in_1_1), .b(comp_in_1_2), .z0(comp_out_1_z0), .z1(comp_out_1_z1), .zctr(1'd1));
DW_fp_cmp #(inst_sig_width, inst_exp_width, 0) comp2(.a(comp_in_2_1), .b(comp_in_2_2), .z0(comp_out_2_z0), .z1(comp_out_2_z1), .zctr(1'd1));
DW_fp_cmp #(inst_sig_width, inst_exp_width, 0) comp3(.a(comp_out_1_z0), .b(comp_out_2_z0), .z0(comp_out_3_z0), .z1(comp_out_3_z1), .zctr(1'd1));
DW_fp_cmp #(inst_sig_width, inst_exp_width, 0) comp4(.a(comp_out_1_z1), .b(comp_out_2_z1), .z0(comp_out_4_z0), .z1(comp_out_4_z1), .zctr(1'd1));

DW_fp_div #(inst_sig_width, inst_exp_width, 0, 0) div1(.a(div_in[0][0]), .b(div_in[0][1]), .rnd(3'b0), .z(div_out[0]));
DW_fp_div #(inst_sig_width, inst_exp_width, 0, 0) div2(.a(div_in[1][0]), .b(div_in[1][1]), .rnd(3'b0), .z(div_out[1]));

DW_fp_exp #(inst_sig_width, inst_exp_width, 0, 0) exp1(.a(exp_in), .z(exp_out));
DW_fp_ln  #(inst_sig_width, inst_exp_width, 0, 0, 0) ln1(.a(normalize_tmp[1]), .z(ln_out));
// POOLING
always @ * begin
	if(count2 == 'd48 || count2 == 'd50 || count2 == 'd56 || count2 == 'd58) begin
		comp_in_1_1 = comp_tmp[0];
		comp_in_1_2 = comp_tmp[1];
		comp_in_2_1 = conv_result[14];
		comp_in_2_2 = conv_result[15];
	end
	else if(count2 == 'd60) begin
		comp_in_1_1 = FC_data[0];
		comp_in_1_2 = FC_data[1];
		comp_in_2_1 = FC_data[2];
		comp_in_2_2 = FC_data[3];
	end
	else begin
		comp_in_1_1 = conv_result[10];
		comp_in_1_2 = conv_result[11];
		comp_in_2_1 = conv_result[14];
		comp_in_2_2 = conv_result[15];
	end
end
always @ (posedge clk) begin
	if(count2 == 'd47 || count2 == 'd49 || count2 == 'd55 || count2 == 'd57)  comp_tmp[0] <= comp_out_1_z0;
	else				comp_tmp[0] <= 'd0;
end
always @ (posedge clk) begin
	if(count2 == 'd47 || count2 == 'd49 || count2 == 'd55 || count2 == 'd57)  comp_tmp[1] <= comp_out_2_z0;
	else				comp_tmp[1] <= 'd0;
end
always @ (posedge clk) begin
	if(count2 == 'd48)  FC_data[0] <= comp_out_1_z0;
	else if(count2 == 'd59 || count2 == 'd60) FC_data[0] <= add_tmp[0]; 
	else if(count2 == 'd61) FC_data[0] <= div_out[0];
	else				FC_data[0] <= FC_data[0];
end
always @ (posedge clk) begin
	if(count2 == 'd50)  FC_data[1] <= comp_out_1_z0;
	else if(count2 == 'd59 || count2 == 'd60) FC_data[1] <= add_tmp[2]; 
	else if(count2 == 'd62) FC_data[1] <= div_out[0];
	else				FC_data[1] <= FC_data[1];
end
always @ (posedge clk) begin
	if(count2 == 'd56)  FC_data[2] <= comp_out_1_z0;
	else if(count2 == 'd59 || count2 == 'd60) FC_data[2] <= add_tmp[1]; 
	else if(count2 == 'd63) FC_data[2] <= div_out[0];
	else				FC_data[2] <= FC_data[2];
end
always @ (posedge clk) begin
	if(count2 == 'd58)  FC_data[3] <= comp_out_1_z0;
	else if(count2 == 'd59 || count2 == 'd60) FC_data[3] <= add_tmp[3]; 
	else if(count2 == 'd64) FC_data[3] <= div_out[0];
	else				FC_data[3] <= FC_data[3];
end
always @ (posedge clk) begin
	if(count2 == 'd60) normalize_tmp[0] <= add_tmp[4];
	else				normalize_tmp[0] <= normalize_tmp[0];
end
always @ (posedge clk) begin
	if(count2 == 'd62 || count2 == 'd63 || count2 == 'd64 || count2 == 'd65) normalize_tmp[1] <= add_tmp[0];
	else				normalize_tmp[1] <= normalize_tmp[1];
end
always @ (posedge clk) begin
	if(count2 == 'd59) 	normalize_tmp[2] <= comp_out_2_z0;
	else if(count2 == 'd62 || count2 == 'd63 || count2 == 'd64 || count2 == 'd65) normalize_tmp[2] <= add_tmp[1];
	else				normalize_tmp[2] <= normalize_tmp[2];
end
always @ (posedge clk) begin
	if(count2 == 'd59) 	normalize_tmp[3] <= comp_out_2_z1;
	else				normalize_tmp[3] <= normalize_tmp[3];
end

// Activation
always @ * begin
	if(count2 == 'd62) 		act_in = FC_data[0];
	else if(count2 == 'd63) act_in = FC_data[1];
	else if(count2 == 'd64) act_in = FC_data[2];
	else					act_in = FC_data[3];
end
always @ * begin
	z2[31] = act_in[31];
	z2[30:23] = act_in[30:23] + 1;
	z2[22:0] = act_in[22:0];
end

// sigmoid


endmodule
