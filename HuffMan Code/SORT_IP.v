//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2023/10
//		Version		: v1.0
//   	File Name   : SORT_IP.v
//   	Module Name : SORT_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module SORT_IP #(parameter IP_WIDTH = 8) (
    // Input signals
    IN_character, IN_weight,
    // Output signals
    OUT_character
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_WIDTH*4-1:0]  IN_character;
input [IP_WIDTH*5-1:0]  IN_weight;

output reg [IP_WIDTH*4-1:0] OUT_character;

// ===============================================================
// Parameter
// ===============================================================
parameter COMP_LAYER = IP_WIDTH;
parameter COMP_log2 = (IP_WIDTH == 1) ? 1 : $clog2(IP_WIDTH);
parameter COMP_NUMBER = (1 << COMP_log2);

wire [3:0] Characters[IP_WIDTH-1:0];
wire [4:0] Weights[IP_WIDTH-1:0];
reg comp_result[IP_WIDTH-1:0][IP_WIDTH-1:0];
reg [COMP_log2-1:0] wins[IP_WIDTH-1:0];
integer z;
integer y;
// ===============================================================
// Design
// ===============================================================

genvar i, j;
generate
for(i=0;i<IP_WIDTH;i=i+1) begin : a
	assign Characters[i] 	= IN_character[4*i+3:4*i];
	assign Weights[i]		= IN_weight[5*i+4:5*i];
end

for(i=0;i<IP_WIDTH;i=i+1) begin : comp_i
	for(j=i+1;j<IP_WIDTH;j=j+1) begin : comp_j
		always @ * begin
			if(Weights[i] > Weights[j]) begin
				comp_result[i][j] = 1;
			end
			else if(Characters[i] > Characters[j] && Weights[i] == Weights[j]) begin
				comp_result[i][j] = 1;
			end
			else begin
				comp_result[i][j] = 0;
			end
		end
	end
end

for(i=IP_WIDTH-1; i>=0; i=i-1) begin : comp_i2
	for(j=i-1;j>=0;j=j-1) begin  : comp_j2
		always @ * begin
			comp_result[i][j] = !comp_result[j][i];
		end
	end
end

for(i=0;i<IP_WIDTH; i=i+1) begin : accumulate_result_i 
	always @ * begin
		if(i==0) begin
			wins[i] = comp_result[i][IP_WIDTH-1];
			for(z=0;z<IP_WIDTH-1; z=z+1) begin
				if(i!=z) begin
					wins[i] = wins[i] + comp_result[i][z];
				end
			end
		end
		else begin
			wins[i] = comp_result[i][0];
			
			for(z=1;z<IP_WIDTH; z=z+1) begin
				if(i!=z) begin
					wins[i] = wins[i] + comp_result[i][z];
				end
			end
		end
	end
end
if(IP_WIDTH != 1) begin
	always @ * begin
		OUT_character = 'z;
		for(z=0;z<IP_WIDTH;z=z+1) begin
			for(y=0;y<IP_WIDTH;y=y+1) begin
				if(wins[z] == y) begin
					OUT_character[(4*y)+:4] = Characters[z];
				end
			end
		end
	end
end
else begin
	always @ * begin
		OUT_character = IN_character;
	end
end

endgenerate

endmodule