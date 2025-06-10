	//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2023/10
//		Version		: v1.0
//   	File Name   : HT_TOP.v
//   	Module Name : HT_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "SORT_IP.v"
//synopsys translate_on

module HT_TOP(
    // Input signals
    clk,
	rst_n,
	in_valid,
    in_weight, 
	out_mode,
    // Output signals
    out_valid, 
	out_code
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid, out_mode;
input [2:0] in_weight;

output reg out_valid, out_code;

// ===============================================================
// Reg & Wire Declaration
// ===============================================================
parameter cA=0;
parameter cB=1;
parameter cC=2;
parameter cE=3;
parameter cI=4;
parameter cL=5;
parameter cO=6;
parameter cV=7;

parameter IDLE = 0;
parameter READ = 1;
parameter COMP = 2;
parameter COMB = 3;
parameter OUTPUT = 4;

reg [4:0] Weights[7:0];
reg [3:0] Characters[7:0];
reg [1:0] Code[7:0][7:0], Code_comb[7:0][7:0];
reg [3:0] link[7:0], link_comb[7:0];
wire [4:0] sorting_weights_unit[7:0];
wire [3:0] sorting_characters_unit[7:0];
wire [31:0] sorting_characters_in;
wire [39:0] sorting_weights_in;
wire [31:0] sorting_characters_out;

wire [3:0] comp_result[7:0];

reg in_valid_delay;
reg mode_store;
reg [3:0] comb_count;
reg [2:0] out_count;
reg [1:0] out_select;

reg [31:0] in_characters_sorting, out_sorting;
reg [2:0] state, state_comb;

reg [3:0] big_character, small_character;

reg [3:0] comp_store[7:0];
reg [4:0] tmp[7:0];
reg state_in_control

genvar i,j;
integer z;
// ===============================================================
// Design
// ===============================================================
// FSM


always @ * begin
	case(state) // synopsys full_case
		IDLE	:	begin
						if(in_valid)
							state_comb = READ;
						else
							state_comb = IDLE;
					end
		READ	:	begin
						if(!in_valid)
							state_comb = COMP;
						else
							state_comb = READ;
					end
		COMP	:	state_comb = COMB;
		COMB	:	begin
						if(comb_count == 6)
							state_comb = OUTPUT;
						else
							state_comb = COMP;
					end
		OUTPUT	:	begin
						if(out_count == 'd4 && ((mode_store == 0 && Code[4][6] == 'd2) || (mode_store==1 && Code[6][6] == 'd2)))
							state_comb = IDLE;
						else
							state_comb = OUTPUT;
					end
	endcase		
end

always @ * begin
	if(mode_store) begin
		case(out_count) // synopsys full_case
			'd0 : out_select = Code[3][6];
			'd1 : out_select = Code[5][6];
			'd2 : out_select = Code[2][6];
			'd3 : out_select = Code[7][6];
			'd4 : out_select = Code[6][6];
			'd5 : out_select = 'd0;
		endcase
	end
	else begin
		case(out_count) // synopsys full_case
			'd0 : out_select = Code[3][6];
			'd1 : out_select = Code[2][6];
			'd2 : out_select = Code[1][6];
			'd3 : out_select = Code[0][6];
			'd4 : out_select = Code[4][6];
			'd5 : out_select = 'd0;
		endcase
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_count <= 'd0;
	end
	else begin
		if(state == OUTPUT) begin
			if(out_select == 'd2) begin
				out_count <= out_count + 'd1;
			end
			else begin
				out_count <= out_count;
			end
		end
		else begin
			out_count <= 'd0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state <= 'd0;
	end
	else begin
		state <= state_comb;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		comb_count <= 'd0;
	end
	else begin
		if(state == COMB) begin
			comb_count <= comb_count + 1;
		end
		else if(state == OUTPUT) begin
			comb_count <= 'd0;
		end
		else begin
			comb_count <= comb_count;
		end
	end
end
// MODE STORE
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		mode_store <= 'd0;
	end
	else begin
		if(in_valid & state == IDLE) begin
			mode_store <= out_mode;
		end
		else begin
			mode_store <= mode_store;
		end
	end
end

// OUTPUT
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_code <= 'd0;
	end
	else begin
		if(state == OUTPUT) begin
			if(mode_store) begin
				case(out_count) // synopsys full_case
					'd0: out_code <= Code[3][7];
					'd1: out_code <= Code[5][7];
					'd2: out_code <= Code[2][7];
					'd3: out_code <= Code[7][7];
					'd4: out_code <= Code[6][7];
				endcase	
			end
			else begin
				case(out_count) // synopsys full_case
					'd0: out_code <= Code[3][7];
					'd1: out_code <= Code[2][7];
					'd2: out_code <= Code[1][7];
					'd3: out_code <= Code[0][7];
					'd4: out_code <= Code[4][7];
				endcase
			end
		end
		else begin
			out_code <= 'd0;
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid <= 'd0;
	end
	else begin
		if(state == OUTPUT) begin
			if(out_count == 'd7 && ((mode_store == 0 && Code[1][6] == 'd2) || (mode_store==1 && Code[3][6] == 'd2))) begin
				out_valid <= 'd0;
			end
			else begin
				out_valid <= 'd1;
			end
		end
		else begin
			out_valid <= 'd0;
		end
	end
end

// Sorting signal alignment
generate
for(i=0;i<8;i=i+1) begin : sorting_align
	assign sorting_characters_unit[i] = {Characters[i]};
	assign sorting_weights_unit[i]    = {Weights[i]};
	assign comp_result[i] = sorting_characters_out[4*i+3:4*i];
end
endgenerate

assign sorting_characters_in = {sorting_characters_unit[0], sorting_characters_unit[1], sorting_characters_unit[2],  sorting_characters_unit[3],  sorting_characters_unit[4],  sorting_characters_unit[5],  sorting_characters_unit[6],  sorting_characters_unit[7]};
assign sorting_weights_in    = {sorting_weights_unit[0],    sorting_weights_unit[1],    sorting_weights_unit[2],    sorting_weights_unit[3],    sorting_weights_unit[4],    sorting_weights_unit[5],    sorting_weights_unit[6],    sorting_weights_unit[7]};

for(i=0;i<8;i=i+1) begin
	always @ (posedge clk) begin
		comp_store[i] <= Characters[i];
	end

	always @ * begin
		case(Characters[i])
			comp_store[0]	:	tmp[i] = Weights[0];
			comp_store[1]	:	tmp[i] = Weights[1];
			comp_store[2]	:	tmp[i] = Weights[2];
			comp_store[3]	:	tmp[i] = Weights[3];
			comp_store[4]	:	tmp[i] = Weights[4];
			comp_store[5]	:	tmp[i] = Weights[5];
			comp_store[6]	:	tmp[i] = Weights[6];
			comp_store[7]	:	tmp[i] = Weights[7];
			default         :   tmp[i] = Weights[0];
		endcase
	end
end

always @ (posedge clk) begin
	if(in_valid) begin
		Weights[0] <= in_weight;
	end
	else if(state == COMB) begin
		if(comb_count == 0) begin
			Weights[0] <= 'd0;
		end
		else begin
			Weights[0] <= tmp[0];
		end
	end
	else begin
		Weights[0] <= Weights[0];
	end
end

generate 
for(i=1;i<8;i=i+1) begin : assign_w
	always @ (posedge clk) begin
		if(in_valid) begin
			Weights[i] <= Weights[i-1];
		end
		else if(state == COMB) begin
			if(comb_count==i-1) begin
				Weights[i] <= tmp[i] + tmp[i-1];
			end
			else if(comb_count == i) begin
				Weights[i] <= 'd0;
			end
			else begin
				Weights[i] <= tmp[i];
			end
		end
		else begin
			Weights[i] <= Weights[i];
		end
	end
end
always @ (posedge clk) begin
	if(state == COMP) begin
		Characters[0] <= comp_result[0];
	end
	else if(state == COMB) begin				
		if(comb_count == 0) begin
			Characters[0] <= 'd0;
		end
		else if(Characters[0] == 'd1 || Characters[0] == 'd2 || Characters[0] == 'd3 || Characters[0] == 'd4 || Characters[0] == 'd5 || Characters[0] == 'd6 || Characters[0] == 'd7) begin
			Characters[0] <= Characters[0] + 'd1;
		end
		else begin
			Characters[0] <= Characters[0];
		end
	end
	else begin
		Characters[0] <= 'd8;
	end
end
for(i=1;i<8;i=i+1) begin : assign_c
	always @ (posedge clk) begin
		if(state == COMP) begin
			Characters[i] <= comp_result[i];
		end
		else if(state == COMB) begin			
			if(comb_count == i-1) begin
				Characters[i] <= 'd1;
			end
			else if(comb_count == i) begin
				Characters[i] <= 'd0;
			end
			else begin
				if(Characters[i] == 'd1 || Characters[i] == 'd2 || Characters[i] == 'd3 || Characters[i] == 'd4 || Characters[i] == 'd5 || Characters[i] == 'd6 || Characters[i] == 'd7) begin
					Characters[i] <= Characters[i] + 'd1;
				end
				else begin
					Characters[i] <= Characters[i];
				end
			end
		end
		else begin
			Characters[i] <= i+8;
		end
	end
end

for(i=0;i<8;i=i+1) begin : assign_link
	always @ (posedge clk) begin
		if(state == IDLE) begin
			link[i] <= 'd0;
		end
		else begin
			link[i] <= link_comb[i];
		end
	end
end
always @ * begin
	link_comb[0] = link[0];
	link_comb[1] = link[1];
	link_comb[2] = link[2];
	link_comb[3] = link[3];
	link_comb[4] = link[4];
	link_comb[5] = link[5];
	link_comb[6] = link[6];
	link_comb[7] = link[7];
	
	if(state == COMB) begin	
		for(z=0;z<8;z=z+1) begin		
			case(link_comb[z]) // synopsys full_case
				'd1 : link_comb[z] = 'd2;
				'd2 : link_comb[z] = 'd3;
				'd3 : link_comb[z] = 'd4;
				'd4 : link_comb[z] = 'd5;
				'd5 : link_comb[z] = 'd6;
				'd6 : link_comb[z] = 'd7;
			endcase
			
		end
		// when a Characters has already link to a Characters who got 
		// assign the Characters to the Characters with larger value.
		if(big_character == 'd8 || small_character == 'd8 || link[0] == small_character || link[0] == big_character) begin
			link_comb[0] = 'd1;
		end
		if(big_character == 'd9 || small_character == 'd9 || link[1] == small_character || link[1] == big_character) begin
			link_comb[1] = 'd1;
		end
		if(big_character == 'd10 || small_character == 'd10 || link[2] == small_character || link[2] == big_character) begin
			link_comb[2] = 'd1;
		end
		if(big_character == 'd11 || small_character == 'd11 || link[3] == small_character || link[3] == big_character) begin
			link_comb[3] = 'd1;
		end
		if(big_character == 'd12 || small_character == 'd12 || link[4] == small_character || link[4] == big_character) begin
			link_comb[4] = 'd1;
		end
		if(big_character == 'd13 || small_character == 'd13 || link[5] == small_character || link[5] == big_character) begin
			link_comb[5] = 'd1;
		end
		if(big_character == 'd14 || small_character == 'd14 || link[6] == small_character || link[6] == big_character) begin
			link_comb[6] = 'd1;
		end
		if(big_character == 'd15 || small_character == 'd15 || link[7] == small_character || link[7] == big_character) begin
			link_comb[7] = 'd1;
		end
	end
end


for(i=1;i<8;i=i+1) begin : assign_code_comb_i
	for(j=0;j<7;j=j+1) begin : assign_code_comb_j
		always @ * begin
			Code_comb[i][j] = Code[i][j];			
			  
			if(state == COMB) begin
				if(link[i] == small_character || link[i] == big_character || big_character == (i+8) || small_character == (i+8)) begin
					Code_comb[i][j] = Code[i][j+1];
				end
			end
		end	
	end	
	always @ * begin
		Code_comb[i][7] = Code[i][7];
		if(state == COMB) begin
			if(small_character == (i+8) || link[i] == small_character) begin
				Code_comb[i][7] = 'd1;
			end
			else if(big_character == (i+8) || link[i] == big_character) begin
				Code_comb[i][7] = 'd0;
			end
		end
	end
end
for(j=0;j<7;j=j+1) begin : assign_code_comb_j2
	always @ * begin
		Code_comb[0][j] = Code[0][j];		
		if(state == COMB) begin
			if(link[0] == small_character || link[0] == big_character || big_character == 'd8 || small_character == 'd8) begin
				Code_comb[0][j] = Code[0][j+1];
			end
		end
	end	
end
always @ * begin
	Code_comb[0][7] = Code[0][7];
	if(state == COMB) begin
		if(small_character == 'd8 || link[0] == small_character) begin
			Code_comb[0][7] = 'd1;
		end
		else if(big_character == 'd8 || link[0] == big_character) begin
			Code_comb[0][7] = 'd0;
		end
	end
end
	
for(j=1;j<8;j=j+1) begin : assign_code_j
	always @ (posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			Code[0][j] <= 'd2;
			Code[1][j] <= 'd2;
			Code[2][j] <= 'd2;
			Code[3][j] <= 'd2;
			Code[4][j] <= 'd2;
			Code[5][j] <= 'd2;
			Code[6][j] <= 'd2;
			Code[7][j] <= 'd2;
		end
		else begin
			if(state == OUTPUT) begin
				if(out_count == 0) begin
					Code[3][j] <= Code[3][j-1];
					
					Code[0][j] <= Code[0][j];
					Code[1][j] <= Code[1][j];
					Code[2][j] <= Code[2][j];
					Code[4][j] <= Code[4][j];
					Code[5][j] <= Code[5][j];
					Code[6][j] <= Code[6][j];
					Code[7][j] <= Code[7][j];							
				end
				else if(mode_store) begin
					Code[0][j] <= Code[0][j-1];
					Code[1][j] <= Code[1][j-1];
					Code[4][j] <= Code[4][j-1];
					
					if(out_count == 1) begin
						Code[5][j] <= Code[5][j-1];
					end
					else begin
						Code[5][j] <= Code[5][j];
					end
					if(out_count == 2) begin
						Code[2][j] <= Code[2][j-1];
					end
					else begin
						Code[2][j] <= Code[2][j];
					end
					if(out_count == 3) begin
						Code[7][j] <= Code[7][j-1];
					end
					else begin
						Code[7][j] <= Code[7][j];
					end
					if(out_count == 4) begin
						Code[6][j] <= Code[6][j-1];
					end
					else begin
						Code[6][j] <= Code[6][j];
					end
				end
				else begin
					Code[5][j] <= Code[5][j-1];
					Code[6][j] <= Code[6][j-1];
					Code[7][j] <= Code[7][j-1];
					
					if(out_count == 1) begin
						Code[2][j] <= Code[2][j-1];
					end
					else begin
						Code[2][j] <= Code[2][j];
					end
					if(out_count == 2) begin
						Code[1][j] <= Code[1][j-1];
					end
					else begin
						Code[1][j] <= Code[1][j];
					end
					if(out_count == 3) begin
						Code[0][j] <= Code[0][j-1];
					end
					else begin
						Code[0][j] <= Code[0][j];
					end
					if(out_count == 4) begin
						Code[4][j] <= Code[4][j-1];
					end
					else begin
						Code[4][j] <= Code[4][j];
					end
				end
			end
			else begin
				Code[0][j] <= Code_comb[0][j];
				Code[1][j] <= Code_comb[1][j];
				Code[2][j] <= Code_comb[2][j];
				Code[3][j] <= Code_comb[3][j];
				Code[4][j] <= Code_comb[4][j];
				Code[5][j] <= Code_comb[5][j];
				Code[6][j] <= Code_comb[6][j];
				Code[7][j] <= Code_comb[7][j];
			end
		end
	end
end
	
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Code[0][0] <= 'd2;
		Code[1][0] <= 'd2;
		Code[2][0] <= 'd2;
		Code[3][0] <= 'd2;
		Code[4][0] <= 'd2;
		Code[5][0] <= 'd2;
		Code[6][0] <= 'd2;
		Code[7][0] <= 'd2;
	end
	else begin
		if(state == OUTPUT) begin
			if(out_count == 0) begin
				Code[3][0] <= 'd2;
				
				Code[0][0] <= Code[0][0];
				Code[1][0] <= Code[1][0];
				Code[2][0] <= Code[2][0];
				Code[4][0] <= Code[4][0];
				Code[5][0] <= Code[5][0];
				Code[6][0] <= Code[6][0];
				Code[7][0] <= Code[7][0];							
			end
			else if(mode_store) begin
				Code[0][0] <= 'd2;
				Code[1][0] <= 'd2;
				Code[4][0] <= 'd2;
				
				if(out_count == 1) begin
					Code[5][0] <= 'd2;
				end
				else begin
					Code[5][0] <= Code[5][0];
				end
				if(out_count == 2) begin
					Code[2][0] <= 'd2;
				end
				else begin
					Code[2][0] <= Code[2][0];
				end
				if(out_count == 3) begin
					Code[7][0] <= 'd2;
				end
				else begin
					Code[7][0] <= Code[7][0];
				end
				if(out_count == 4) begin
					Code[6][0] <= 'd2;
				end
				else begin
					Code[6][0] <= Code[6][0];
				end
			end
			else begin
				Code[5][0] <= 'd2;
				Code[6][0] <= 'd2;
				Code[7][0] <= 'd2;
				
				if(out_count == 1) begin
					Code[2][0] <= 'd2;
				end
				else begin
					Code[2][0] <= Code[2][0];
				end
				if(out_count == 2) begin
					Code[1][0] <= 'd2;
				end
				else begin
					Code[1][0] <= Code[1][0];
				end
				if(out_count == 3) begin
					Code[0][0] <= 'd2;
				end
				else begin
					Code[0][0] <= Code[0][0];
				end
				if(out_count == 4) begin
					Code[4][0] <= 'd2;
				end
				else begin
					Code[4][0] <= Code[4][0];
				end
			end
		end
		else begin
			Code[0][0] <= Code_comb[0][0];
			Code[1][0] <= Code_comb[1][0];
			Code[2][0] <= Code_comb[2][0];
			Code[3][0] <= Code_comb[3][0];
			Code[4][0] <= Code_comb[4][0];
			Code[5][0] <= Code_comb[5][0];
			Code[6][0] <= Code_comb[6][0];
			Code[7][0] <= Code_comb[7][0];
		end
	end
end
endgenerate


always @ * begin
	case(comb_count) // synopsys full_case
		'd0 : big_character = Characters[1];
		'd1 : big_character = Characters[2];
		'd2 : big_character = Characters[3];
		'd3 : big_character = Characters[4];
		'd4 : big_character = Characters[5];
		'd5 : big_character = Characters[6];
		'd6 : big_character = Characters[7];
		'd7 : big_character = 0;
	endcase
	case(comb_count) // synopsys full_case
		'd0 : small_character = Characters[0];
		'd1 : small_character = Characters[1];
		'd2 : small_character = Characters[2];
		'd3 : small_character = Characters[3];
		'd4 : small_character = Characters[4];
		'd5 : small_character = Characters[5];
		'd6 : small_character = Characters[6];
		'd7 : small_character = Characters[7];
	endcase 
end

SORT_IP #(.IP_WIDTH(8)) Sorting(.IN_character(sorting_characters_in), .IN_weight(sorting_weights_in), .OUT_character(sorting_characters_out));

endmodule