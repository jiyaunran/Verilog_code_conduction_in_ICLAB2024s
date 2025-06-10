//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2024 Spring
//   Lab01 Exercise		: Code Calculator
//   Author     		  : Jhan-Yi LIAO
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CC.v
//   Module Name : CC
//   Release version : V1.0 (Release Date: 2024-02)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################


module CC(
  // Input signals
    opt,
    in_n0, in_n1, in_n2, in_n3, in_n4,  
  // Output signals
    out_n
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [3:0] in_n0, in_n1, in_n2, in_n3, in_n4;
input [2:0] opt;
output reg [9:0] out_n;         					

//================================================================
//    Wire & Registers 
//================================================================
// Declare the wire/reg you would use in your circuit
// remember 
// wire for port connection and cont. assignment
// reg for proc. assignment
wire [3:0] tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7, tmp8, tmp9, tmp10;
wire [3:0] tmp11, tmp12, tmp13, tmp14, tmp15, tmp16, tmp17, tmp18, tmp19, tmp20;

reg [3:0] sorted[5];
reg signed [4:0] sorted_n[5];
reg [9:0] avg_1;
wire signed [9:0] avg_2;
reg signed [9:0] cal_tmp1, cal_tmp2;
wire signed [9:0] mult_out_1, mult_out_2;
reg signed [9:0] mult_1, mult_2, mult_3, mult_4;
wire [6:0] add_tmp;
wire signed [9:0] add_tmp2;
wire tmp21, tmp22, tmp23;
wire [2:0] remain;
wire [3:0] quo;
wire signed [9:0] mul;
//================================================================
//    DESIGN
//================================================================

// 1. compare
comparator comp1(in_n0, in_n1, tmp1, tmp2);
comparator comp2(in_n2, in_n3, tmp3, tmp4);
//comparator comp3(tmp1, in_n4, tmp5, tmp6);
//comparator comp4(tmp2, tmp4, tmp7, tmp8); 
//comparator comp5(tmp5, tmp3, tmp9, tmp10); //tmp9 biggest
//comparator comp6(tmp8, tmp6, tmp11, tmp12); // tmp12 smallest
//tmp13 = tmp7 > tmp10;
//tmp14 = tmp7 > tmp11;
//tmp15 = tmp10 > tmp11;
//comparator comp7(tmp7, tmp10, tmp13, tmp14);
//comparator comp8(tmp14, tmp11, tmp15, tmp16);
//comparator comp9(tmp13, tmp15, tmp17, tmp18);

comparator comp3(tmp2, tmp3, tmp5, tmp6);
comparator comp4(tmp4, in_n4, tmp7, tmp8);
comparator comp5(tmp1, tmp5, tmp9, tmp10);
comparator comp6(tmp6, tmp7, tmp11, tmp12);
comparator comp7(tmp10, tmp11, tmp13, tmp14);
comparator comp8(tmp12, tmp8, tmp15, tmp16);
comparator comp9(tmp9, tmp13, tmp17, tmp18);
comparator comp10(tmp14, tmp15, tmp19, tmp20);

div_table t1(add_tmp, quo, remain);
mult_table t2(sorted_n[3], mul);

//assign sorted[2] = tmp18;
assign sorted[2] = tmp19;
always @ (*) begin
   if(opt[1] == 1) begin
      //sorted[0] = tmp9;
      //sorted[1] = tmp17;
      //sorted[3] = tmp16;
      //sorted[4] = tmp12;
      sorted[0] = tmp17;
      sorted[1] = tmp18;
      sorted[3] = tmp20;
      sorted[4] = tmp16;
   end
   else begin
      sorted[0] = tmp16;
      sorted[1] = tmp20;
      sorted[3] = tmp18;
      sorted[4] = tmp17;
   end
end

// 2. normalize
//assign avg_1 = (sorted[0] + sorted[4]) >> 1;

always @ (*) begin
   if (opt[0] == 0) begin
      avg_1 = 0;
   end
   else begin
      avg_1 = (tmp17 + tmp16) >> 1;
   end
   sorted_n[0] = $signed(sorted[0] - avg_1);
   sorted_n[1] = $signed(sorted[1] - avg_1);
   sorted_n[2] = $signed(sorted[2] - avg_1);
   sorted_n[3] = $signed(sorted[3] - avg_1);
   sorted_n[4] = $signed(sorted[4] - avg_1);
   //if (opt[0] == 1) begin
   //   sorted_n[0] = sorted[0] - avg_1;
   //   sorted_n[1] = sorted[1] - avg_1;
   //   sorted_n[2] = sorted[2] - avg_1;
   //   sorted_n[3] = sorted[3] - avg_1;
   //   sorted_n[4] = sorted[4] - avg_1;
   //end
   //else begin
   //   sorted_n[0] = sorted[0];
   //   sorted_n[1] = sorted[1];
   //   sorted_n[2] = sorted[2];
   //   sorted_n[3] = sorted[3];
   //   sorted_n[4] = sorted[4];
   //end
end
// 3. calculation
//assign avg_2 = (sorted_n[0] + sorted_n[1] + sorted_n[2] + sorted_n[3] + sorted_n[4]) / 5;
assign add_tmp = (in_n0 + in_n1 + in_n2 + in_n3 + in_n4);
assign add_tmp2 = $signed(quo - avg_1);
//assign quo = add_tmp / 5;
//assign remain = add_tmp % 5;
assign tmp21 = remain != 5;
assign tmp22 = remain != 0;
assign tmp23 = add_tmp2 < 0;
assign avg_2 = (tmp21 && tmp22 && tmp23) ? add_tmp2 + 1 : add_tmp2;
//assign mult_out_1 = mult_1 * mult_2;
//assign mult_out_2 = mult_3 * mult_4;

always @ (*) begin
   cal_tmp1 = mul - sorted_n[0] * sorted_n[4];
   cal_tmp2 = sorted_n[0] + sorted_n[1] * sorted_n[2] + avg_2 * sorted_n[3];
   if(opt[2] == 1) begin   
      //mult_1 = sorted_n[3];
	  //mult_2 = 3;
	  //mult_3 = sorted_n[0];
	  //mult_4 = sorted_n[4];
	  //cal_tmp1 = mult_out_1 - mult_out_2;
      //cal_tmp1 = sorted_n[3] * 3 - sorted_n[0] * sorted_n[4];
	  out_n = cal_tmp1[9] ? ~cal_tmp1+1 : cal_tmp1;
   end
   else begin
      //mult_1 = sorted_n[1];
	  //mult_2 = sorted_n[2];
	  //mult_3 = avg_2;
	  //mult_4 = sorted_n[3];
      //cal_tmp1 = sorted_n[0] + mult_out_1 + mult_out_2;
      //cal_tmp1 = sorted_n[0] + sorted_n[1] * sorted_n[2] + avg_2 * sorted_n[3];
	  out_n = cal_tmp2 / 3;      
   end
end


endmodule

module comparator(
 // Input signals
    in_1, in_2,
 // Output Signals
    out_1, out_2
);

input [3:0] in_1, in_2;
output reg [3:0] out_1, out_2;

always @ (*) begin
   if(in_1 >= in_2) begin
      out_1 = in_1;
      out_2 = in_2;
   end
   else begin
      out_1 = in_2;
      out_2 = in_1;
   end
end



endmodule

module div_table(
	//Input
	sum,
	//Output
	quo, rem
);

input [6:0] sum;
output reg [3:0] quo;
output reg [2:0] rem;

always @ * begin
	case(sum)
	'd0  : begin quo = 0; rem = 0; end
	'd1  : begin quo = 0; rem = 1; end
	'd2  : begin quo = 0; rem = 2; end
	'd3  : begin quo = 0; rem = 3; end
	'd4  : begin quo = 0; rem = 4; end
	'd5  : begin quo = 1; rem = 0; end
	'd6  : begin quo = 1; rem = 1; end
	'd7  : begin quo = 1; rem = 2; end
	'd8  : begin quo = 1; rem = 3; end
	'd9  : begin quo = 1; rem = 4; end
	'd10 : begin quo = 2; rem = 0; end
	'd11 : begin quo = 2; rem = 1; end
	'd12 : begin quo = 2; rem = 2; end
	'd13 : begin quo = 2; rem = 3; end
	'd14 : begin quo = 2; rem = 4; end
	'd15 : begin quo = 3; rem = 0; end
	'd16 : begin quo = 3; rem = 1; end
	'd17 : begin quo = 3; rem = 2; end
	'd18 : begin quo = 3; rem = 3; end
	'd19 : begin quo = 3; rem = 4; end
	'd20 : begin quo = 4; rem = 0; end
	'd21 : begin quo = 4; rem = 1; end
	'd22 : begin quo = 4; rem = 2; end
	'd23 : begin quo = 4; rem = 3; end
	'd24 : begin quo = 4; rem = 4; end
	'd25 : begin quo = 5; rem = 0; end
	'd26 : begin quo = 5; rem = 1; end
	'd27 : begin quo = 5; rem = 2; end
	'd28 : begin quo = 5; rem = 3; end
	'd29 : begin quo = 5; rem = 4; end
	'd30 : begin quo = 6; rem = 0; end
	'd31 : begin quo = 6; rem = 1; end
	'd32 : begin quo = 6; rem = 2; end
	'd33 : begin quo = 6; rem = 3; end
	'd34 : begin quo = 6; rem = 4; end
	'd35 : begin quo = 7; rem = 0; end
	'd36 : begin quo = 7; rem = 1; end
	'd37 : begin quo = 7; rem = 2; end
	'd38 : begin quo = 7; rem = 3; end
	'd39 : begin quo = 7; rem = 4; end
	'd40 : begin quo = 8; rem = 0; end
	'd41 : begin quo = 8; rem = 1; end
	'd42 : begin quo = 8; rem = 2; end
	'd43 : begin quo = 8; rem = 3; end
	'd44 : begin quo = 8; rem = 4; end
	'd45 : begin quo = 9; rem = 0; end
	'd46 : begin quo = 9; rem = 1; end
	'd47 : begin quo = 9; rem = 2; end
	'd48 : begin quo = 9; rem = 3; end
	'd49 : begin quo = 9; rem = 4; end
	'd50 : begin quo = 10;rem = 0; end
	'd51 : begin quo = 10;rem = 1; end
	'd52 : begin quo = 10;rem = 2; end
	'd53 : begin quo = 10;rem = 3; end
	'd54 : begin quo = 10;rem = 4; end
	'd55 : begin quo = 11;rem = 0; end
	'd56 : begin quo = 11;rem = 1; end
	'd57 : begin quo = 11;rem = 2; end
	'd58 : begin quo = 11;rem = 3; end
	'd59 : begin quo = 11;rem = 4; end
	'd60 : begin quo = 12;rem = 0; end
	'd61 : begin quo = 12;rem = 1; end
	'd62 : begin quo = 12;rem = 2; end
	'd63 : begin quo = 12;rem = 3; end
	'd64 : begin quo = 12;rem = 4; end
	'd65 : begin quo = 13;rem = 0; end
	'd66 : begin quo = 13;rem = 1; end
	'd67 : begin quo = 13;rem = 2; end
	'd68 : begin quo = 13;rem = 3; end
	'd69 : begin quo = 13;rem = 4; end
	'd70 : begin quo = 14;rem = 0; end
	'd71 : begin quo = 14;rem = 1; end
	'd72 : begin quo = 14;rem = 2; end
	'd73 : begin quo = 14;rem = 3; end
	'd74 : begin quo = 14;rem = 4; end
	'd75 : begin quo = 15;rem = 0; end
	default: begin quo = 'dx; rem = 'dx; end
	endcase

end


endmodule


module mult_table(
    //Input
    sum,
    //Output
    mul
);

input signed [4:0] sum;
output reg signed [9:0] mul;

always @* begin
   case(sum) 
        5'b00000: mul = 10'b0000000000;
        5'b00001: mul = 10'b0000000011;
        5'b00010: mul = 10'b0000000110;
        5'b00011: mul = 10'b0000001001;
        5'b00100: mul = 10'b0000001100;
        5'b00101: mul = 10'b0000001111;
        5'b00110: mul = 10'b0000010010;
        5'b00111: mul = 10'b0000010101;
        5'b01000: mul = 10'b0000011000;
        5'b01001: mul = 10'b0000011011;
        5'b01010: mul = 10'b0000011110;
        5'b01011: mul = 10'b0000100001;
        5'b01100: mul = 10'b0000100100;
        5'b01101: mul = 10'b0000100111;
        5'b01110: mul = 10'b0000101010;
        5'b01111: mul = 10'b0000101101;
        -5'b00001: mul = -10'b0000000011;
        -5'b00010: mul = -10'b0000000110;
        -5'b00011: mul = -10'b0000001001;
        -5'b00100: mul = -10'b0000001100;
        -5'b00101: mul = -10'b0000001111;
        -5'b00110: mul = -10'b0000010010;
        -5'b00111: mul = -10'b0000010101;
        -5'b01000: mul = -10'b0000011000;
        -5'b01001: mul = -10'b0000011011;
        -5'b01010: mul = -10'b0000011110;
        -5'b01011: mul = -10'b0000100001;
        -5'b01100: mul = -10'b0000100100;
        -5'b01101: mul = -10'b0000100111;
        -5'b01110: mul = -10'b0000101010;
        -5'b01111: mul = -10'b0000101101;
        default: mul = 'bx;
    endcase
end

endmodule

