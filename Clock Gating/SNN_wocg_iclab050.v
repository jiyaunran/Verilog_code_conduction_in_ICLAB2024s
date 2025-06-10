module SNN(
	// Input signals
	clk,
	rst_n,
	in_valid,
	img,
	ker,
	weight,
	// Output signals
	out_valid,
	out_data
);

input clk;
input rst_n;
input in_valid;
input [7:0] img;
input [7:0] ker;
input [7:0] weight;

output reg out_valid;
output reg [9:0] out_data;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
genvar i,j;
//==============================================//
//           reg & wire declaration             //
//==============================================//
reg [7:0] img1_store [14:0];
reg [7:0] img2_store [5:0][5:0];
reg [7:0] kernel_store[8:0];
reg [7:0] weight_store[3:0];

reg [6:0] cnt;

reg [7:0] mult_in[8:0][1:0];
reg [15:0] mult_out_comb[8:0], mult_out[8:0];

reg [19:0] add_result, add_result_comb;

reg [7:0] FM[3:0][1:0];

reg [19:0] dividend;
reg [11:0] divisor;
reg [7:0] div_out;

reg [7:0] comp_in[3:0];
reg [7:0] comp_out;

reg [7:0] FM_small[1:0];

reg [7:0] encode1[3:0];
reg [7:0] encode2;

reg [9:0] similarity_store, similarity_store_comb;

reg [7:0] abs_minus_in[1:0];
reg [7:0] minus_in[1:0];
reg [7:0] abs_minus_out;

//==============================================//
//                  design                      //
//==============================================//

// cnt assignment
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cnt <= 'd0;
	end
	else begin
		if(in_valid) begin
			cnt <= cnt + 'd1;
		end
		else begin
			if(cnt == 'd0 || cnt == 'd80) begin
				cnt <= 'd0;
			end
			else begin
				cnt <= cnt + 'd1;
			end
		end
	end
end

// 1. store Input
always @ (posedge clk) begin
	if(cnt <= 'd8) begin
		kernel_store[0] <= ker;
	end
	else if(cnt >= 'd72) begin
		kernel_store[0] <= ~kernel_store[0];
	end
	else begin
		kernel_store[0] <= kernel_store[0];
	end
end
generate
	for(i=1; i<9; i=i+1) begin
		always @ (posedge clk) begin
			if(cnt <= 'd8) begin
				kernel_store[i] <= kernel_store[i-1];
			end
			else if(cnt >= 'd72) begin
				kernel_store[i] <= ~kernel_store[i];
			end
			else begin
				kernel_store[i] <= kernel_store[i];
			end
		end
	end
endgenerate

always @ (posedge clk) begin
	if(cnt == 'd0) begin
		weight_store[0] <= weight;
	end
	else begin
		weight_store[0] <= weight_store[0];
	end
end

always @ (posedge clk) begin
	if(cnt <= 'd1) begin
		weight_store[1] <= weight;
	end
	else begin
		weight_store[1] <= weight_store[1];
	end
end

always @ (posedge clk) begin
	if(cnt <= 'd2) begin
		weight_store[2] <= weight;
	end
	else begin
		weight_store[2] <= weight_store[2];
	end
end

always @ (posedge clk) begin
	if(cnt <= 'd3) begin
		weight_store[3] <= weight;
	end
	else begin
		weight_store[3] <= weight_store[3];
	end
end


always @ (posedge clk) begin
	if(cnt >= 'd72) begin
		img1_store[0] <= ~img1_store[0];
	end
	else begin
		img1_store[0] <= img;
	end
end

generate
	for(i=1; i<15; i=i+1) begin : assign_img_store2
		always @ (posedge clk) begin
			if(cnt >= 'd72) begin
				img1_store[i] <= ~img1_store[i];
			end
			else begin
				img1_store[i] <= img1_store[i-1];
			end
		end
	end
endgenerate

// 2. convolution
always @ * begin
// mult for convolution
mult_in[0][0] = img1_store[0];
mult_in[1][0] = img1_store[1];
mult_in[2][0] = img1_store[2];
mult_in[3][0] = img1_store[6];
mult_in[4][0] = img1_store[7];
mult_in[5][0] = img1_store[8];
mult_in[6][0] = img1_store[12];
mult_in[7][0] = img1_store[13];
mult_in[8][0] = img1_store[14];

mult_in[0][1] = kernel_store[0];
mult_in[1][1] = kernel_store[1];
mult_in[2][1] = kernel_store[2];
mult_in[3][1] = kernel_store[3];
mult_in[4][1] = kernel_store[4];
mult_in[5][1] = kernel_store[5];
mult_in[6][1] = kernel_store[6];
mult_in[7][1] = kernel_store[7];
mult_in[8][1] = kernel_store[8];

	// mult for FC
	if(cnt == 'd31 || cnt == 'd32 || cnt == 'd40 || cnt == 'd41 || cnt == 'd67 || cnt == 'd68 || cnt == 'd76 || cnt == 'd77) begin
		mult_in[0][0] = FM_small[0];
		mult_in[0][1] = weight_store[0];
		mult_in[1][0] = FM_small[1];
		mult_in[1][1] = weight_store[2];
		mult_in[2][0] = FM_small[0];
		mult_in[2][1] = weight_store[1];
		mult_in[3][0] = FM_small[1];
		mult_in[3][1] = weight_store[3];
	end
end

always @ * begin
	mult_out_comb[0] = mult_in[0][0] * mult_in[0][1];
	mult_out_comb[1] = mult_in[1][0] * mult_in[1][1];
	mult_out_comb[2] = mult_in[2][0] * mult_in[2][1];
	mult_out_comb[3] = mult_in[3][0] * mult_in[3][1];
	mult_out_comb[4] = mult_in[4][0] * mult_in[4][1];
	mult_out_comb[5] = mult_in[5][0] * mult_in[5][1];
	mult_out_comb[6] = mult_in[6][0] * mult_in[6][1];
	mult_out_comb[7] = mult_in[7][0] * mult_in[7][1];
	mult_out_comb[8] = mult_in[8][0] * mult_in[8][1];
end

generate
	for(i=0;i<9;i=i+1) begin
		always @ (posedge clk) begin
			mult_out[i] <= mult_out_comb[i];
		end
	end
endgenerate

always @ * begin
add_result_comb = mult_out[0] + mult_out[1] + mult_out[2] + mult_out[3] + mult_out[4] + mult_out[5] + mult_out[6] + mult_out[7] + mult_out[8]; 
	// add for FC
	if(cnt == 'd32 || cnt == 'd41 || cnt == 'd68 || cnt == 'd77)
		add_result_comb = mult_out[0] + mult_out[1];
	else if(cnt == 'd33 || cnt == 'd42 || cnt == 'd69 || cnt == 'd78)
		add_result_comb = mult_out[2] + mult_out[3];
end

always @ (posedge clk) begin
	if(cnt <= 'd15) begin
		add_result <= ~add_result;
	end
	else begin
		add_result <= add_result_comb;
	end
end

/*
generate
	for(j=0;j<4;j=j+1) begin : Feature_map_j
		for(i=0;i<4;i=i+1) begin : Feature_map_i
			always @ (posedge clk or negedge rst_n) begin
				if(!rst_n) begin
					FM[i][j] <= 'd0;
				end
				else begin
					if(cnt == 'd16+i+6*j) begin
						FM[i][j] <= add_result;
					end
					else begin
						FM[i][j] <= FM[i][j];
					end
				end
			end
		end
	end
endgenerate
*/
// 3. Quantization
always @ * begin

	// Q1
	dividend = add_result;
	divisor = 'd2295;
	
	// Q2
	if(cnt == 'd33 || cnt == 'd34 || cnt == 'd42 || cnt == 'd43 || cnt == 'd69 || cnt == 'd70 || cnt == 'd78 || cnt == 'd79) begin
		dividend = add_result >> 1'b1;
		divisor = 'd255;
	end
	div_out = dividend / divisor;
end

generate
	for(j=0;j<2;j=j+1) begin : Feature_map_j
		for(i=0;i<4;i=i+1) begin : Feature_map_i
			always @ (posedge clk) begin
				if(cnt == ('d17+i+6*j) || cnt == ('d29+i+6*j) || cnt==('d53+i+6*j) || cnt==('d65+i+6*j)) begin
					FM[i][j] <= div_out;
				end
				else begin
					FM[i][j] <= FM[i][j];
				end
			end
		end
	end
endgenerate

// 4. Max pooling
always @ * begin
	if(cnt == 'd25 || cnt == 'd37 || cnt == 'd61 || cnt == 'd73) begin
		comp_in[0] = FM[0][0];
		comp_in[1] = FM[0][1];
		comp_in[2] = FM[1][0];
		comp_in[3] = FM[1][1];
	end
	else begin
		comp_in[0] = FM[2][0];
		comp_in[1] = FM[2][1];
		comp_in[2] = FM[3][0];
		comp_in[3] = FM[3][1];
	end
end

comparator comp(.in1(comp_in[0]), .in2(comp_in[1]), .in3(comp_in[2]), .in4(comp_in[3]), .out(comp_out));

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		FM_small[0] <= 'd0;
	end
	else begin
		if(cnt == 'd25 || cnt == 'd37 || cnt == 'd61 || cnt == 'd73) begin
			FM_small[0] <= comp_out;
		end
		else if(cnt < 'd25) begin
			FM_small[0] <= ~FM_small[0];
		end
		else begin
			FM_small[0] <= FM_small[0];
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		FM_small[1] <= 'd0;
	end
	else begin
		if(cnt == 'd27 || cnt == 'd39 || cnt == 'd63 || cnt == 'd75) begin
			FM_small[1] <= comp_out;
		end
		else if(cnt < 'd27) begin
			FM_small[1] <= ~FM_small[1];
		end
		else begin
			FM_small[1] <= FM_small[1];
		end
	end
end

// 7. Encode 1
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		encode1[0] <= 'd0;
	end
	else begin
		if(cnt == 'd33) begin
			encode1[0] <= div_out;
		end
		else begin
			encode1[0] <= encode1[0];
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		encode1[1] <= 'd0;
	end
	else begin
		if(cnt == 'd34) begin
			encode1[1] <= div_out;
		end
		else begin
			encode1[1] <= encode1[1];
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		encode1[2] <= 'd0;
	end
	else begin
		if(cnt == 'd42) begin
			encode1[2] <= div_out;
		end
		else begin
			encode1[2] <= encode1[2];
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		encode1[3] <= 'd0;
	end
	else begin
		if(cnt == 'd43) begin
			encode1[3] <= div_out;
		end
		else begin
			encode1[3] <= encode1[3];
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		encode2 <= 'd0;
	end
	else begin
		if(cnt == 'd69 || cnt == 'd70 || cnt == 'd78 || cnt == 'd79) begin
			encode2 <= div_out;
		end
		else begin
			encode2 <= encode2;
		end
	end
end

// 8. similarity
always @ * begin
	if(cnt == 'd70) begin
		minus_in[0] = encode1[0];
	end
	else if(cnt == 'd71) begin
		minus_in[0] = encode1[1];
	end
	else if(cnt == 'd79) begin
		minus_in[0] = encode1[2];
	end
	else if(cnt == 'd80) begin
		minus_in[0] = encode1[3];
	end
	else begin
		minus_in[0] = 'd0;
	end
	
	if(cnt == 'd70 || cnt == 'd71 || cnt == 'd79 || cnt == 'd80) begin
		minus_in[1] = encode2;
	end
	else begin
		minus_in[1] = 'd0;
	end
	
	if(minus_in[0] > minus_in[1]) begin
		abs_minus_in[0] = minus_in[0];
		abs_minus_in[1] = minus_in[1];
	end
	else begin
		abs_minus_in[0] = minus_in[1];
		abs_minus_in[1] = minus_in[0];
	end
	
	abs_minus_out = abs_minus_in[0] - abs_minus_in[1];
	
	similarity_store_comb = similarity_store + abs_minus_out;
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		similarity_store <= 'd0;
	end
	else begin
		if(out_valid) begin
			similarity_store <= 'd0;
		end
		else begin
			similarity_store <= similarity_store_comb;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid <= 'd0;
	end
	else begin
		if(cnt == 'd80) begin
			out_valid <= 'd1;
		end
		else begin
			out_valid <= 'd0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_data <= 'd0;
	end
	else begin
		if(cnt == 'd80 && similarity_store_comb >= 'd16) begin
			out_data <= similarity_store_comb;
		end
		else begin
			out_data <= 'd0;
		end
	end
end

endmodule

module comparator(
	// Input
	in1, in2, in3, in4,
	// Output
	out
);

input [7:0] in1, in2, in3, in4;
output reg [7:0] out;

reg [7:0] tmp1, tmp2;

always @ * begin
	if(in1 >= in2) 
		tmp1 = in1;
	else
		tmp1 = in2;
		
	if(in3 >= in4) 
		tmp2 = in3;
	else
		tmp2 = in4;
		
	if (tmp1 >= tmp2)
		out = tmp1;
	else
		out = tmp2;
end

endmodule