//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2024 Spring
//   Lab02 Exercise		: Enigma
//   Author     		: Yi-Xuan, Ran
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : ENIGMA.v
//   Module Name : ENIGMA
//   Release version : V1.0 (Release Date: 2024-02)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
 
module ENIGMA(
	// Input Ports
	clk, 
	rst_n, 
	in_valid, 
	in_valid_2, 
	crypt_mode, 
	code_in, 

	// Output Ports
	out_code, 
	out_valid
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk;              // clock input
input rst_n;            // asynchronous reset (active low)
input in_valid;         // code_in valid signal for rotor (level sensitive). 0/1: inactive/active
input in_valid_2;       // code_in valid signal for code  (level sensitive). 0/1: inactive/active
input crypt_mode;       // 0: encrypt; 1:decrypt; only valid for 1 cycle when in_valid is active

input [6-1:0] code_in;	// When in_valid   is active, then code_in is input of rotors. 
						// When in_valid_2 is active, then code_in is input of code words.
							
output reg out_valid;       	// 0: out_code is not valid; 1: out_code is valid
output reg [6-1:0] out_code;	// encrypted/decrypted code word

reg in_valid_init;
reg [7:0] count;
reg state, state_delay;
reg en_de;
reg out_valid_2, out_valid_3, out_valid_4;
reg [5:0] A[64], A_inv[64];
reg [5:0] B[64], B_inv[64];
wire [1:0] shift_bit_A;
reg [1:0] shift_bit_A_reg;
wire [2:0] mode_1_B;
reg [2:0] mode_1_B_reg;
reg [5:0]  A_table_in;
reg [5:0] A_table_in2;
wire [5:0] B_table_in; 
reg [5:0] B_table_in2;
reg [5:0] A_table_out, A_table_out2;
reg [5:0] B_table_out, B_table_out2;
wire loada, loadb;
wire load;
reg [3:0] B_shift[8];

reg [5:0] out_store;
reg [1:0] out;
// ===============================================================
// Design
// count
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) out <= 'd1;
	else begin
		if(in_valid) out <= 'd0;
		else if(out_valid_2) out <= 'd2;
		else if(out == 'd2)  out <= 'd1;
		else out <= out;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		count <= 0;
	end
	else begin
		if(out == 'd1) count <= 'd0;
		else if(in_valid) count <= count + 'd1;
		else count <= count;
	end
end		

// encrypt_decrypt
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) in_valid_init <= 'd0;
	else begin
		if(in_valid)	in_valid_init <= 'd1;
		else			in_valid_init <= 'd0;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		en_de <= 0;
	end
	else begin
		if(in_valid & !in_valid_init)	en_de <= crypt_mode; //decrypt = 1, encrypt = 0
		else							en_de <= en_de;
	end
end

// state
//assign loadb = (in_valid & (count < 128));
assign load = count < 127;
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state <= 0;
	end
	else begin
		if(in_valid_2 || out_valid_2)		state <= 1;
		else 								state <= 0;
	end
end

// 1. ROTOR A
always @ (posedge clk) begin
	if(load) 						A[0] <= A[1];
	else if(state == 0)A[0] <= A[0];
	else begin
		case(shift_bit_A)
			'd0 : A[0] <= A[0];
			'd1 : A[0] <= A[63];
			'd2 : A[0] <= A[62];
			'd3 : A[0] <= A[61];
		endcase
	end
end
always @ (posedge clk) begin
	if(load) 						A[1] <= A[2];
	else if(state == 0)A[1] <= A[1];
	else begin
		case(shift_bit_A)
			'd0 : A[1] <= A[1];
			'd1 : A[1] <= A[0];
			'd2 : A[1] <= A[63];
			'd3 : A[1] <= A[62];
		endcase
	end
end
always @ (posedge clk) begin
	if(load) 			A[2] <= A[3];
	else if(state == 0)	A[2] <= A[2];
	else begin
		case(shift_bit_A)
			'd0 : A[2] <= A[2];
			'd1 : A[2] <= A[1];
			'd2 : A[2] <= A[0];
			'd3 : A[2] <= A[63];
		endcase
	end
end
always @ (posedge clk) begin
	if(load) 			A[63] <= B[0];
	else if(state == 0)	A[63] <= A[63];
	else begin
		case(shift_bit_A)
			'd0 : A[63] <= A[63];
			'd1 : A[63] <= A[62];
			'd2 : A[63] <= A[61];
			'd3 : A[63] <= A[60];
		endcase
	end
end

genvar i;
generate
for(i=3; i<63; i++) begin: a
	always @ (posedge clk) begin
		if(load) 			A[i] <= A[i+1];
		else if(state == 0) A[i] <= A[i];
		else begin
			case(shift_bit_A)
				'd0 : A[i] <= A[i];
				'd1 : A[i] <= A[i-1];
				'd2 : A[i] <= A[i-2];
				'd3 : A[i] <= A[i-3];
			endcase
		end
	end
end
endgenerate

// 2. ROTOR B
ROTORB_8bit RB1(clk, rst_n,B[8],state,load,mode_1_B,B[0],B[1],B[2],B[3],B[4],B[5],B[6],B[7]);
ROTORB_8bit RB2(clk, rst_n,B[16],state,load,mode_1_B,B[8],B[9],B[10],B[11],B[12],B[13],B[14],B[15]);
ROTORB_8bit RB3(clk, rst_n,B[24],state,load,mode_1_B,B[16],B[17],B[18],B[19],B[20],B[21],B[22],B[23]);
ROTORB_8bit RB4(clk, rst_n,B[32],state,load,mode_1_B,B[24],B[25],B[26],B[27],B[28],B[29],B[30],B[31]);
ROTORB_8bit RB5(clk, rst_n,B[40],state,load,mode_1_B,B[32],B[33],B[34],B[35],B[36],B[37],B[38],B[39]);
ROTORB_8bit RB6(clk, rst_n,B[48],state,load,mode_1_B,B[40],B[41],B[42],B[43],B[44],B[45],B[46],B[47]);
ROTORB_8bit RB7(clk, rst_n,B[56],state,load,mode_1_B,B[48],B[49],B[50],B[51],B[52],B[53],B[54],B[55]);
ROTORB_8bit RB8(clk, rst_n,code_in,state,load,mode_1_B,B[56],B[57],B[58],B[59],B[60],B[61],B[62],B[63]);

// 3. A table
always @ (*) begin
	case(A_table_in) // synopsys parallel_case
		'd0 : A_table_out = A[0];
		'd1 : A_table_out = A[1];
		'd2 : A_table_out = A[2];
		'd3 : A_table_out = A[3];
		'd4 : A_table_out = A[4];
		'd5 : A_table_out = A[5];
		'd6 : A_table_out = A[6];
		'd7 : A_table_out = A[7];
		'd8 : A_table_out = A[8];
		'd9 : A_table_out = A[9];
		'd10 : A_table_out = A[10];
		'd11 : A_table_out = A[11];
		'd12 : A_table_out = A[12];
		'd13 : A_table_out = A[13];
		'd14 : A_table_out = A[14];
		'd15 : A_table_out = A[15];
		'd16 : A_table_out = A[16];
		'd17 : A_table_out = A[17];
		'd18 : A_table_out = A[18];
		'd19 : A_table_out = A[19];
		'd20 : A_table_out = A[20];
		'd21 : A_table_out = A[21];
		'd22 : A_table_out = A[22];
		'd23 : A_table_out = A[23];
		'd24 : A_table_out = A[24];
		'd25 : A_table_out = A[25];
		'd26 : A_table_out = A[26];
		'd27 : A_table_out = A[27];
		'd28 : A_table_out = A[28];
		'd29 : A_table_out = A[29];
		'd30 : A_table_out = A[30];
		'd31 : A_table_out = A[31];
		'd32 : A_table_out = A[32];
		'd33 : A_table_out = A[33];
		'd34 : A_table_out = A[34];
		'd35 : A_table_out = A[35];
		'd36 : A_table_out = A[36];
		'd37 : A_table_out = A[37];
		'd38 : A_table_out = A[38];
		'd39 : A_table_out = A[39];
		'd40 : A_table_out = A[40];
		'd41 : A_table_out = A[41];
		'd42 : A_table_out = A[42];
		'd43 : A_table_out = A[43];
		'd44 : A_table_out = A[44];
		'd45 : A_table_out = A[45];
		'd46 : A_table_out = A[46];
		'd47 : A_table_out = A[47];
		'd48 : A_table_out = A[48];
		'd49 : A_table_out = A[49];
		'd50 : A_table_out = A[50];
		'd51 : A_table_out = A[51];
		'd52 : A_table_out = A[52];
		'd53 : A_table_out = A[53];
		'd54 : A_table_out = A[54];
		'd55 : A_table_out = A[55];
		'd56 : A_table_out = A[56];
		'd57 : A_table_out = A[57];
		'd58 : A_table_out = A[58];
		'd59 : A_table_out = A[59];
		'd60 : A_table_out = A[60];
		'd61 : A_table_out = A[61];
		'd62 : A_table_out = A[62];
		'd63 : A_table_out = A[63];
	endcase
end
always @ (*) begin
	case(A_table_in2) //synopsys full_case
		A[0] : A_table_out2 = 0;
		A[1] : A_table_out2 = 1;
		A[2] : A_table_out2 = 2;
		A[3] : A_table_out2 = 3;
		A[4] : A_table_out2 = 4;
		A[5] : A_table_out2 = 5;
		A[6] : A_table_out2 = 6;
		A[7] : A_table_out2 = 7;
		A[8] : A_table_out2 = 8;
		A[9] : A_table_out2 = 9;
		A[10] : A_table_out2 = 10;
		A[11] : A_table_out2 = 11;
		A[12] : A_table_out2 = 12;
		A[13] : A_table_out2 = 13;
		A[14] : A_table_out2 = 14;
		A[15] : A_table_out2 = 15;
		A[16] : A_table_out2 = 16;
		A[17] : A_table_out2 = 17;
		A[18] : A_table_out2 = 18;
		A[19] : A_table_out2 = 19;
		A[20] : A_table_out2 = 20;
		A[21] : A_table_out2 = 21;
		A[22] : A_table_out2 = 22;
		A[23] : A_table_out2 = 23;
		A[24] : A_table_out2 = 24;
		A[25] : A_table_out2 = 25;
		A[26] : A_table_out2 = 26;
		A[27] : A_table_out2 = 27;
		A[28] : A_table_out2 = 28;
		A[29] : A_table_out2 = 29;
		A[30] : A_table_out2 = 30;
		A[31] : A_table_out2 = 31;
		A[32] : A_table_out2 = 32;
		A[33] : A_table_out2 = 33;
		A[34] : A_table_out2 = 34;
		A[35] : A_table_out2 = 35;
		A[36] : A_table_out2 = 36;
		A[37] : A_table_out2 = 37;
		A[38] : A_table_out2 = 38;
		A[39] : A_table_out2 = 39;
		A[40] : A_table_out2 = 40;
		A[41] : A_table_out2 = 41;
		A[42] : A_table_out2 = 42;
		A[43] : A_table_out2 = 43;
		A[44] : A_table_out2 = 44;
		A[45] : A_table_out2 = 45;
		A[46] : A_table_out2 = 46;
		A[47] : A_table_out2 = 47;
		A[48] : A_table_out2 = 48;
		A[49] : A_table_out2 = 49;
		A[50] : A_table_out2 = 50;
		A[51] : A_table_out2 = 51;
		A[52] : A_table_out2 = 52;
		A[53] : A_table_out2 = 53;
		A[54] : A_table_out2 = 54;
		A[55] : A_table_out2 = 55;
		A[56] : A_table_out2 = 56;
		A[57] : A_table_out2 = 57;
		A[58] : A_table_out2 = 58;
		A[59] : A_table_out2 = 59;
		A[60] : A_table_out2 = 60;
		A[61] : A_table_out2 = 61;
		A[62] : A_table_out2 = 62;
		A[63] : A_table_out2 = 63;
	endcase
end
assign shift_bit_A = (en_de) ? B_table_out2[1:0] :A_table_out[1:0];

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		A_table_in <= 'd0;
	end
	else begin
		if(in_valid_2) 	A_table_in <= code_in;
		else 			A_table_in <= 'd0;
	end
end
//assign A_table_in = code_in;

assign A_table_in2 = B_table_out2;

// 4. B table
always @ (*) begin
	case(B_table_in) // synopsys parallel_case
		'd0 : B_table_out = B[0];
		'd1 : B_table_out = B[1];
		'd2 : B_table_out = B[2];
		'd3 : B_table_out = B[3];
		'd4 : B_table_out = B[4];
		'd5 : B_table_out = B[5];
		'd6 : B_table_out = B[6];
		'd7 : B_table_out = B[7];
		'd8 : B_table_out = B[8];
		'd9 : B_table_out = B[9];
		'd10 : B_table_out = B[10];
		'd11 : B_table_out = B[11];
		'd12 : B_table_out = B[12];
		'd13 : B_table_out = B[13];
		'd14 : B_table_out = B[14];
		'd15 : B_table_out = B[15];
		'd16 : B_table_out = B[16];
		'd17 : B_table_out = B[17];
		'd18 : B_table_out = B[18];
		'd19 : B_table_out = B[19];
		'd20 : B_table_out = B[20];
		'd21 : B_table_out = B[21];
		'd22 : B_table_out = B[22];
		'd23 : B_table_out = B[23];
		'd24 : B_table_out = B[24];
		'd25 : B_table_out = B[25];
		'd26 : B_table_out = B[26];
		'd27 : B_table_out = B[27];
		'd28 : B_table_out = B[28];
		'd29 : B_table_out = B[29];
		'd30 : B_table_out = B[30];
		'd31 : B_table_out = B[31];
		'd32 : B_table_out = B[32];
		'd33 : B_table_out = B[33];
		'd34 : B_table_out = B[34];
		'd35 : B_table_out = B[35];
		'd36 : B_table_out = B[36];
		'd37 : B_table_out = B[37];
		'd38 : B_table_out = B[38];
		'd39 : B_table_out = B[39];
		'd40 : B_table_out = B[40];
		'd41 : B_table_out = B[41];
		'd42 : B_table_out = B[42];
		'd43 : B_table_out = B[43];
		'd44 : B_table_out = B[44];
		'd45 : B_table_out = B[45];
		'd46 : B_table_out = B[46];
		'd47 : B_table_out = B[47];
		'd48 : B_table_out = B[48];
		'd49 : B_table_out = B[49];
		'd50 : B_table_out = B[50];
		'd51 : B_table_out = B[51];
		'd52 : B_table_out = B[52];
		'd53 : B_table_out = B[53];
		'd54 : B_table_out = B[54];
		'd55 : B_table_out = B[55];
		'd56 : B_table_out = B[56];
		'd57 : B_table_out = B[57];
		'd58 : B_table_out = B[58];
		'd59 : B_table_out = B[59];
		'd60 : B_table_out = B[60];
		'd61 : B_table_out = B[61];
		'd62 : B_table_out = B[62];
		'd63 : B_table_out = B[63];
	endcase
end
always @ (*) begin
	case(B_table_in2)	//synopsys full_case	
		B[0] : B_table_out2 = 0;
		B[1] : B_table_out2 = 1;
		B[2] : B_table_out2 = 2;
		B[3] : B_table_out2 = 3;
		B[4] : B_table_out2 = 4;
		B[5] : B_table_out2 = 5;
		B[6] : B_table_out2 = 6;
		B[7] : B_table_out2 = 7;
		B[8] : B_table_out2 = 8;
		B[9] : B_table_out2 = 9;
		B[10] : B_table_out2 = 10;
		B[11] : B_table_out2 = 11;
		B[12] : B_table_out2 = 12;
		B[13] : B_table_out2 = 13;
		B[14] : B_table_out2 = 14;
		B[15] : B_table_out2 = 15;
		B[16] : B_table_out2 = 16;
		B[17] : B_table_out2 = 17;
		B[18] : B_table_out2 = 18;
		B[19] : B_table_out2 = 19;
		B[20] : B_table_out2 = 20;
		B[21] : B_table_out2 = 21;
		B[22] : B_table_out2 = 22;
		B[23] : B_table_out2 = 23;
		B[24] : B_table_out2 = 24;
		B[25] : B_table_out2 = 25;
		B[26] : B_table_out2 = 26;
		B[27] : B_table_out2 = 27;
		B[28] : B_table_out2 = 28;
		B[29] : B_table_out2 = 29;
		B[30] : B_table_out2 = 30;
		B[31] : B_table_out2 = 31;
		B[32] : B_table_out2 = 32;
		B[33] : B_table_out2 = 33;
		B[34] : B_table_out2 = 34;
		B[35] : B_table_out2 = 35;
		B[36] : B_table_out2 = 36;
		B[37] : B_table_out2 = 37;
		B[38] : B_table_out2 = 38;
		B[39] : B_table_out2 = 39;
		B[40] : B_table_out2 = 40;
		B[41] : B_table_out2 = 41;
		B[42] : B_table_out2 = 42;
		B[43] : B_table_out2 = 43;
		B[44] : B_table_out2 = 44;
		B[45] : B_table_out2 = 45;
		B[46] : B_table_out2 = 46;
		B[47] : B_table_out2 = 47;
		B[48] : B_table_out2 = 48;
		B[49] : B_table_out2 = 49;
		B[50] : B_table_out2 = 50;
		B[51] : B_table_out2 = 51;
		B[52] : B_table_out2 = 52;
		B[53] : B_table_out2 = 53;
		B[54] : B_table_out2 = 54;
		B[55] : B_table_out2 = 55;
		B[56] : B_table_out2 = 56;
		B[57] : B_table_out2 = 57;
		B[58] : B_table_out2 = 58;
		B[59] : B_table_out2 = 59;
		B[60] : B_table_out2 = 60;
		B[61] : B_table_out2 = 61;
		B[62] : B_table_out2 = 62;
		B[63] : B_table_out2 = 63;
	endcase
end

assign mode_1_B = (en_de) ? B_table_in2[2:0] : B_table_out[2:0];
assign B_table_in = A_table_out;
assign B_table_in2 = 63 - B_table_out;


// 5. Output
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid_2 <= 'd0;
	else begin
		if(in_valid_2) 	out_valid_2 <= 'd1;
		else			out_valid_2 <= 'd0;
	end
end


always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid <= 'd0;
		out_code  <= 'd0;
	end
	else begin
		if(out_valid_2) begin
			out_valid <= 'd1;
			out_code <= A_table_out2;
		end
		else begin
			out_valid <= 'd0;
			out_code <= 'd0;
		end
	end
end
// ===============================================================


endmodule

module ROTORB_8bit(
	//Input
	clk, rst_n,
	code_in, state, load, mode_1_B,
	//Output
	B0, B1, B2, B3, B4, B5, B6, B7
);
input clk, rst_n;
input [6-1:0] code_in;	// When in_valid   is active, then code_in is input of rotors. 
						// When in_valid_2 is active, then code_in is input of code words.
input [2:0] mode_1_B;
input state;
//input loada, loadb;
input load;

output reg [5:0] B0, B1, B2, B3, B4, B5, B6, B7;


always @ (posedge clk) begin
	if(load) 							B0 <= B1;
	else if ((state == 0)) B0 <= B0;
	else begin
		case(mode_1_B)
			'd0 : B0 <= B0;
			'd1 : B0 <= B1; 
			'd2 : B0 <= B2;
			'd3 : B0 <= B0;
			'd4 : B0 <= B4;
			'd5 : B0 <= B5;
			'd6 : B0 <= B6;
			'd7 : B0 <= B7;
		endcase
	end
end

always @ (posedge clk) begin
	if(load) 							B1 <= B2;
	else if ((state == 0))	B1 <= B1;
	else begin
		case(mode_1_B)
			'd0 : B1 <= B1;
			'd1 : B1 <= B0; 
			'd2 : B1 <= B3;
			'd3 : B1 <= B4;
			'd4 : B1 <= B5;
			'd5 : B1 <= B6;
			'd6 : B1 <= B7;
			'd7 : B1 <= B6;
		endcase
	end
end

always @ (posedge clk) begin
	if(load) 							B2 <= B3;
	else if ((state == 0)) B2 <= B2;
	else begin
		case(mode_1_B)
			'd0 : B2 <= B2;
			'd1 : B2 <= B3; 
			'd2 : B2 <= B0;
			'd3 : B2 <= B5;
			'd4 : B2 <= B6;
			'd5 : B2 <= B7;
			'd6 : B2 <= B3;
			'd7 : B2 <= B5;
		endcase
	end
end

always @ (posedge clk) begin
	if(load)							B3 <= B4;
	else if ((state == 0))	B3 <= B3;
	else begin
		case(mode_1_B)
			'd0 : B3 <= B3;
			'd1 : B3 <= B2; 
			'd2 : B3 <= B1;
			'd3 : B3 <= B6;
			'd4 : B3 <= B7;
			'd5 : B3 <= B3;
			'd6 : B3 <= B2;
			'd7 : B3 <= B4;
		endcase
	end
end

always @ (posedge clk) begin
	if(load)						 	B4 <= B5;
	else if ((state == 0)) B4 <= B4;
	else begin
		case(mode_1_B)
			'd0 : B4 <= B4;
			'd1 : B4 <= B5; 
			'd2 : B4 <= B6;
			'd3 : B4 <= B1;
			'd4 : B4 <= B0;
			'd5 : B4 <= B4;
			'd6 : B4 <= B5;
			'd7 : B4 <= B3;
		endcase
	end
end

always @ (posedge clk) begin
	if(load) 							B5 <= B6;
	else if ((state == 0))	B5 <= B5;
	else begin
		case(mode_1_B)
			'd0 : B5 <= B5;
			'd1 : B5 <= B4; 
			'd2 : B5 <= B7;
			'd3 : B5 <= B2;
			'd4 : B5 <= B1;
			'd5 : B5 <= B0;
			'd6 : B5 <= B4;
			'd7 : B5 <= B2;
		endcase
	end
end

always @ (posedge clk) begin
	if(load) 							B6 <= B7;
	else if ((state == 0))	B6 <= B6;
	else begin
		case(mode_1_B)
			'd0 : B6 <= B6;
			'd1 : B6 <= B7; 
			'd2 : B6 <= B4;
			'd3 : B6 <= B3;
			'd4 : B6 <= B2;
			'd5 : B6 <= B1;
			'd6 : B6 <= B0;
			'd7 : B6 <= B1;
		endcase
	end
end

always @ (posedge clk) begin
	if 	(load)							B7 <= code_in;
	else if ((state == 0))	B7 <= B7;
	else begin
		case(mode_1_B)
			'd0 : B7 <= B7;
			'd1 : B7 <= B6; 
			'd2 : B7 <= B5;
			'd3 : B7 <= B7;
			'd4 : B7 <= B3;
			'd5 : B7 <= B2;
			'd6 : B7 <= B1;
			'd7 : B7 <= B0;
		endcase
	end
end


endmodule

