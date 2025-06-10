module BEV(input clk, INF.BEV_inf inf);
import usertype::*;
// This file contains the definition of several state machines used in the BEV (Beverage) System RTL design.
// The state machines are defined using SystemVerilog enumerated types.
// The state machines are:
// - state_t: used to represent the overall state of the BEV system
//
// Each enumerated type defines a set of named states that the corresponding process can be in.
typedef enum logic [3:0]{
    IDLE,
    MAKE_DRINK_REQ_DRAM,
	MAKE_DRINK_CALC,
	MAKE_DRINK_WB,
    SUPPLY_REQ_DRAM,
	SUPPLY_ADD,
	SUPPLY_WAIT_LAST_SUP,
	SUPPLY_WAIT_COUT,
	SUPPLY_WB,
    CHECK_DATE_REQ_DRAM,
	CHECK_DATE_CALC
} state_t;

typedef struct{
	logic [4:0] Date_day;
	logic [3:0] Date_mon;
	Bev_Type Type;
	Bev_Size Size;
	logic [7:0] No_BOX;
	logic [12:0] Supply_amount[3:0];
} input_data;

input_data Data;

logic [4:0] Drink_type;
logic [9:0] BT_require, BT_require_comb;
logic [9:0] GT_require, GT_require_comb;
logic [9:0] Milk_require, Milk_require_comb;
logic [9:0] PJ_require, PJ_require_comb;

logic Ing_lack[3:0];
logic [11:0] BT_Ing;
logic [11:0] GT_Ing;
logic [11:0] Milk_Ing;
logic [11:0] PJ_Ing;

logic Expire;
logic [3:0] Exp_mon;
logic [4:0] Exp_day;

logic [11:0] BT_Ing_dram;
logic [11:0] GT_Ing_dram;
logic [11:0] Milk_Ing_dram;
logic [11:0] PJ_Ing_dram;
logic [3:0] Exp_mon_dram;
logic [4:0] Exp_day_dram;

logic [11:0] BT_Ing_write;
logic [11:0] GT_Ing_write;
logic [11:0] Milk_Ing_write;
logic [11:0] PJ_Ing_write;
logic [3:0] Exp_mon_write;
logic [4:0] Exp_day_write;

logic [11:0] BT_Ing_write_comb;
logic [11:0] GT_Ing_write_comb;
logic [11:0] Milk_Ing_write_comb;
logic [11:0] PJ_Ing_write_comb;
logic [3:0] Exp_mon_write_comb;
logic [4:0] Exp_day_write_comb;

logic [63:0] Data_WB;

logic [1:0] Sup_cnt;

logic [12:0] BT_OF_CHECK;
logic [12:0] GT_OF_CHECK;
logic [12:0] Milk_OF_CHECK;
logic [12:0] PJ_OF_CHECK;
logic Overflow;
logic Overflow_store;

logic bridge_require;

logic [2:0] writing_logic;

logic bridge_busy;

genvar i;

// REGISTERS
state_t state, nstate;

//---------------------------------
//				DESIGN
//---------------------------------
// STATE MACHINE
always_ff @( posedge clk or negedge inf.rst_n) begin : TOP_FSM_SEQ
    if (!inf.rst_n) state <= IDLE;
    else state <= nstate;
end

always_comb begin : TOP_FSM_COMB
    case(state) // synopsys full_case
        IDLE: 					begin
									if (inf.sel_action_valid) begin
										case(inf.D.d_act[0])
											Make_drink: nstate = MAKE_DRINK_REQ_DRAM;
											Supply: nstate = SUPPLY_REQ_DRAM;
											Check_Valid_Date: nstate = CHECK_DATE_REQ_DRAM;
											default: nstate = IDLE;
										endcase
									end
									else begin
										nstate = IDLE; 
									end
								end
		MAKE_DRINK_REQ_DRAM :	begin
									if(inf.C_out_valid && !bridge_busy) begin
										nstate = MAKE_DRINK_CALC;
									end
									else begin
										nstate = MAKE_DRINK_REQ_DRAM;
									end
								end
		MAKE_DRINK_CALC		:	begin
									if(Ing_lack[0] || Ing_lack[1] || Ing_lack[2] || Ing_lack[3] || Expire) begin
										nstate = IDLE;
									end
									else begin
										nstate = MAKE_DRINK_WB;
									end
								end
		MAKE_DRINK_WB		:	nstate = IDLE;
		SUPPLY_REQ_DRAM		:	begin
									if(inf.box_sup_valid && Sup_cnt == 'd3) begin
										if(inf.C_out_valid && !bridge_busy)	begin
											nstate = SUPPLY_ADD;
										end
										else begin
											nstate = SUPPLY_WAIT_COUT;
										end
									end
									else if(inf.C_out_valid && !bridge_busy) begin
										nstate = SUPPLY_WAIT_LAST_SUP;
									end
									else begin
										nstate = SUPPLY_REQ_DRAM;
									end
								end
		SUPPLY_WAIT_LAST_SUP:	begin
									if(inf.box_sup_valid && Sup_cnt == 'd3 && !bridge_busy) begin
										nstate = SUPPLY_ADD;
									end
									else begin
										nstate = SUPPLY_WAIT_LAST_SUP;
									end
								end
		SUPPLY_WAIT_COUT	:	begin
									if(inf.C_out_valid && !bridge_busy) begin
										nstate = SUPPLY_ADD;
									end
									else begin
										nstate = SUPPLY_WAIT_COUT;
									end
								end
		SUPPLY_ADD			:	nstate = SUPPLY_WB;
		SUPPLY_WB			:	nstate = IDLE;
		CHECK_DATE_REQ_DRAM	:	begin
									if(inf.C_out_valid && !bridge_busy) begin
										nstate = CHECK_DATE_CALC;
									end
									else begin
										nstate = CHECK_DATE_REQ_DRAM;
									end
								end
		CHECK_DATE_CALC		:	nstate = IDLE;
    endcase
end

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		bridge_busy <= 'd0;
	end
	else begin
		if(inf.C_in_valid && !inf.C_r_wb) begin
			bridge_busy <= 'd1;
		end
		else if(inf.C_out_valid) begin
			bridge_busy <= 'd0;
		end
		else begin
			bridge_busy <= bridge_busy;
		end
	end
end

always_ff @ (posedge clk) begin
		if(inf.date_valid) begin
			Data.Date_day <= inf.D.d_date[0].D;
			Data.Date_mon <= inf.D.d_date[0].M;
		end
		else begin
			Data.Date_day <= Data.Date_day;
			Data.Date_mon <= Data.Date_mon;
		end
end

always_ff @ (posedge clk) begin
	if(inf.type_valid) begin
		Data.Type <= inf.D.d_type[0];
	end
	else begin
		Data.Type <= Data.Type;
	end
end

always_ff @ (posedge clk) begin
	if(inf.size_valid) begin
		Data.Size <= inf.D.d_size[0];
	end
	else begin
		Data.Size <= Data.Size;
	end
end

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		Data.No_BOX <= 'd0;
	end
	else begin
		if(inf.box_no_valid) begin
			Data.No_BOX <= inf.D.d_box_no[0];
		end
		else begin
			Data.No_BOX <= Data.No_BOX;
		end
	end
end

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) 	bridge_require <= 0;
	else begin
		if(inf.box_no_valid || state == SUPPLY_ADD) begin
			bridge_require <= 'd1;
		end
		else if(!bridge_busy) begin
			bridge_require <= 'd0;
		end
		else begin
			bridge_require <= bridge_require;
		end
	end	
end

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		inf.C_r_wb <= 'd0;
	end
	else begin
		inf.C_r_wb <= !(state == MAKE_DRINK_CALC || state == SUPPLY_ADD);
	end
end

//--------------------------------------
//				Make Drink
//--------------------------------------
//1. SEND REQUEST TO DRAM
always_comb begin
inf.C_in_valid = (bridge_require || state == MAKE_DRINK_WB) && (!bridge_busy);
//inf.C_r_wb = !(state == MAKE_DRINK_WB || state == SUPPLY_WB || !inf.rst_n);
inf.C_data_w = Data_WB;
inf.C_addr = Data.No_BOX;
end

//2. Calculate the require amount
always_comb begin
Drink_type = {Data.Size, Data.Type};
	case({Data.Size, Data.Type}) 
		{S, Black_Tea}					:	BT_require_comb = 'd480;
		{M, Black_Tea}					:	BT_require_comb = 'd720;
		{L,  Black_Tea}					:	BT_require_comb = 'd960;
		{S, Milk_Tea}					:	BT_require_comb = 'd360;
		{M, Milk_Tea}					:	BT_require_comb = 'd540;
		{L,  Milk_Tea}					:	BT_require_comb = 'd720;
		{S, Extra_Milk_Tea}				:	BT_require_comb = 'd240;
		{M, Extra_Milk_Tea}				:	BT_require_comb = 'd360;
		{L,  Extra_Milk_Tea}			:	BT_require_comb = 'd480;
		{S, Super_Pineapple_Tea}		:	BT_require_comb = 'd240;
		{M, Super_Pineapple_Tea}		:	BT_require_comb = 'd360;
		{L,  Super_Pineapple_Tea}		:	BT_require_comb = 'd480;
		{S, Super_Pineapple_Milk_Tea}	:	BT_require_comb = 'd240;
		{M, Super_Pineapple_Milk_Tea}	:	BT_require_comb = 'd360;
		{L,  Super_Pineapple_Milk_Tea}	:	BT_require_comb = 'd480;
		default 						:	BT_require_comb = 'd0;
	endcase
	
	case({Data.Size, Data.Type})
		{S, Green_Tea}			:	GT_require_comb = 'd480;
		{M, Green_Tea}			:	GT_require_comb = 'd720;
		{L,  Green_Tea}			:	GT_require_comb = 'd960;
		{S, Green_Milk_Tea}		:	GT_require_comb = 'd240;
		{M, Green_Milk_Tea}		:	GT_require_comb = 'd360;
		{L,  Green_Milk_Tea}	:	GT_require_comb = 'd480;
		default 				:	GT_require_comb = 'd0;
	endcase
	
	case({Data.Size, Data.Type})
		{S, Milk_Tea}					:	Milk_require_comb = 'd120;
		{M, Milk_Tea}					:	Milk_require_comb = 'd180;
		{L,  Milk_Tea}					:	Milk_require_comb = 'd240;
		{S, Extra_Milk_Tea} 			:	Milk_require_comb = 'd240;
		{M, Extra_Milk_Tea} 			:	Milk_require_comb = 'd360;
		{L,  Extra_Milk_Tea}			:	Milk_require_comb = 'd480;
		{S, Green_Milk_Tea} 			:	Milk_require_comb = 'd240;
		{M, Green_Milk_Tea} 			:	Milk_require_comb = 'd360;
		{L,  Green_Milk_Tea} 			:	Milk_require_comb = 'd480;
		{S, Super_Pineapple_Milk_Tea} 	:	Milk_require_comb = 'd120;
		{M, Super_Pineapple_Milk_Tea} 	:	Milk_require_comb = 'd180;
		{L,  Super_Pineapple_Milk_Tea} 	:	Milk_require_comb = 'd240;
		default 						:	Milk_require_comb = 'd0;
	endcase
	
	case({Data.Size, Data.Type})
		{S, Pineapple_Juice}			:	PJ_require_comb = 'd480;
		{M, Pineapple_Juice}			:	PJ_require_comb = 'd720;
		{L,  Pineapple_Juice}			:	PJ_require_comb = 'd960;
		{S, Super_Pineapple_Tea} 		:	PJ_require_comb = 'd240;
		{M, Super_Pineapple_Tea} 		:	PJ_require_comb = 'd360;
		{L,  Super_Pineapple_Tea}		:	PJ_require_comb = 'd480;
		{S, Super_Pineapple_Milk_Tea} 	:	PJ_require_comb = 'd120;
		{M, Super_Pineapple_Milk_Tea} 	:	PJ_require_comb = 'd180;
		{L, Super_Pineapple_Milk_Tea}	:	PJ_require_comb = 'd240;
		default 						:	PJ_require_comb = 'd0;
	endcase
end

always_ff @ (posedge clk) begin
	BT_require <= BT_require_comb;
	GT_require <= GT_require_comb;
	Milk_require <= Milk_require_comb;
	PJ_require <= PJ_require_comb;
end

//3. Compare Expire Date
always_comb begin
	Exp_day_dram = inf.C_data_r[4:0];
	PJ_Ing_dram = inf.C_data_r[19:8];
	Milk_Ing_dram = inf.C_data_r[31:20];
	Exp_mon_dram = inf.C_data_r[35:32];
	GT_Ing_dram = inf.C_data_r[51:40];
	BT_Ing_dram = inf.C_data_r[63:52];
end

always_comb begin
Ing_lack[0] = (state == MAKE_DRINK_CALC) && (BT_Ing_write < BT_require);	
Ing_lack[1] = (state == MAKE_DRINK_CALC) && (GT_Ing_write < GT_require);	
Ing_lack[2] = (state == MAKE_DRINK_CALC) && (Milk_Ing_write < Milk_require);	
Ing_lack[3] = (state == MAKE_DRINK_CALC) && (PJ_Ing_write < PJ_require);	
Expire = 'd0;

	//if(state == MAKE_DRINK_CALC) begin
	//	if(BT_Ing_write < BT_require) begin
	//		Ing_lack[0] = 'd1;
	//	end
	//	if(GT_Ing_write < GT_require) begin
	//		Ing_lack[1] = 'd1;
	//	end
	//	if(Milk_Ing_write < Milk_require) begin
	//		Ing_lack[2] = 'd1;
	//	end
	//	if(PJ_Ing_write < PJ_require) begin
	//		Ing_lack[3] = 'd1;
	//	end
	//end
	if(state == MAKE_DRINK_CALC || state == CHECK_DATE_CALC) begin
		if(Data.Date_mon > Exp_mon_write) begin
			Expire = 'd1;
		end
		else if(Data.Date_mon == Exp_mon_write && (Data.Date_day > Exp_day_write)) begin
			Expire = 'd1;
		end
	end
end

always_comb begin
Exp_day_write_comb = Exp_day_write;
Exp_mon_write_comb = Exp_mon_write;


	if(inf.C_out_valid) begin
		Exp_day_write_comb = Exp_day_dram;
		Exp_mon_write_comb = Exp_mon_dram;
	end
	else if(state == SUPPLY_ADD) begin
		Exp_day_write_comb = Data.Date_day;
		Exp_mon_write_comb = Data.Date_mon;
	end
	
	// Supply Add
	BT_OF_CHECK = BT_Ing_write + Data.Supply_amount[0];
	GT_OF_CHECK = GT_Ing_write + Data.Supply_amount[1];
	Milk_OF_CHECK = Milk_Ing_write + Data.Supply_amount[2];
	PJ_OF_CHECK = PJ_Ing_write + Data.Supply_amount[3];

	

	writing_logic[0] = inf.C_out_valid;
	writing_logic[1] = (state == MAKE_DRINK_CALC);
	writing_logic[2] = (state == SUPPLY_ADD);
	
	case(writing_logic) // synopsys full_case parallel_case	
		3'b100	:	begin
						if(BT_OF_CHECK[12]) begin
							BT_Ing_write_comb = 'd4095;
						end
						else begin
							BT_Ing_write_comb = BT_OF_CHECK;
						end
						if(GT_OF_CHECK[12]) begin
							GT_Ing_write_comb = 'd4095;
						end
						else begin
							GT_Ing_write_comb = GT_OF_CHECK;
						end
						if(Milk_OF_CHECK[12]) begin
							Milk_Ing_write_comb = 'd4095;
						end
						else begin
							Milk_Ing_write_comb = Milk_OF_CHECK;
						end
						if(PJ_OF_CHECK[12]) begin
							PJ_Ing_write_comb = 'd4095;
						end
						else begin
							PJ_Ing_write_comb = PJ_OF_CHECK;
						end
					end
		3'b000	:	begin
						BT_Ing_write_comb = BT_Ing_write;	
						GT_Ing_write_comb = GT_Ing_write;	
						Milk_Ing_write_comb = Milk_Ing_write;	
						PJ_Ing_write_comb = PJ_Ing_write;	
					end
		3'b001	:	begin
						BT_Ing_write_comb = BT_Ing_dram;
					    GT_Ing_write_comb = GT_Ing_dram;
					    Milk_Ing_write_comb = Milk_Ing_dram;
					    PJ_Ing_write_comb = PJ_Ing_dram;
					end
		3'b010	:	begin
						BT_Ing_write_comb = {BT_Ing_write[11:2] - BT_require[9:2], BT_Ing_write[1:0]};
						GT_Ing_write_comb = {GT_Ing_write[11:2] - GT_require[9:2], GT_Ing_write[1:0]};
						Milk_Ing_write_comb = {Milk_Ing_write[11:2] - Milk_require[9:2], Milk_Ing_write[1:0]};
						PJ_Ing_write_comb = {PJ_Ing_write[11:2] - PJ_require[9:2], PJ_Ing_write[1:0]};
					end
	endcase
	
	Overflow = (BT_OF_CHECK[12] || GT_OF_CHECK[12] || Milk_OF_CHECK[12] || PJ_OF_CHECK[12]) && (state == SUPPLY_ADD);
end

always_ff @ (posedge clk) begin
		BT_Ing_write <= BT_Ing_write_comb;
		GT_Ing_write <= GT_Ing_write_comb;
		Milk_Ing_write <= Milk_Ing_write_comb;
		PJ_Ing_write <= PJ_Ing_write_comb;
		Exp_day_write <= Exp_day_write_comb;
		Exp_mon_write <= Exp_mon_write_comb;
end

//4. Write Back
assign Data_WB[63:52] = BT_Ing_write;      
assign Data_WB[51:40] = GT_Ing_write;       
assign Data_WB[31:20] = Milk_Ing_write;
assign Data_WB[19:8]  = PJ_Ing_write; 
assign Data_WB[39:32] = Exp_mon_write;              
assign Data_WB[7:0]   = Exp_day_write;  
/*
assign Data_WB = {	BT_Ing_write, GT_Ing_write, 4'b0, Exp_mon_write, Milk_Ing_write,
					PJ_Ing_write, 3'b0, Exp_day_write};
*/				
//--------------------------------------
//				Supply
//--------------------------------------
always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		Sup_cnt <= 'd0;
	end
	else begin
		if(inf.box_sup_valid) begin
			Sup_cnt <= Sup_cnt + 'd1;
		end
		else begin
			Sup_cnt <= Sup_cnt;
		end
	end
end

generate
	for(i=0;i<4;i=i+1) begin : supply_amount_assignment
		always_ff @ (posedge clk) begin
			if(inf.box_sup_valid) begin
				if(Sup_cnt == i) begin
					Data.Supply_amount[i] <= inf.D.d_ing[0];
				end
				else begin
					Data.Supply_amount[i] <= Data.Supply_amount[i];
				end
			end
			else begin
				Data.Supply_amount[i] <= Data.Supply_amount[i];
			end
		end
	end
endgenerate

//--------------------------------------
//				Output
//--------------------------------------
always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		inf.out_valid <= 'd0;
	end
	else begin
		inf.out_valid <= (state == MAKE_DRINK_CALC || (state == SUPPLY_ADD) || (state == CHECK_DATE_CALC));
		//if(state == MAKE_DRINK_CALC || (state == SUPPLY_ADD) || (state == CHECK_DATE_CALC)) begin
		//	inf.out_valid <= 'd1;
		//end
		//else begin
		//	inf.out_valid <= 'd0;
		//end
	end
end

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		inf.err_msg <= No_Err;
	end
	else begin
		if(Expire) begin
			inf.err_msg <= No_Exp;
		end
		else if(Ing_lack[0] || Ing_lack[1] || Ing_lack[2] || Ing_lack[3]) begin
			inf.err_msg <= No_Ing;
		end
		else if(Overflow) begin
			inf.err_msg <= Ing_OF;
		end
		else begin
			inf.err_msg <= No_Err;
		end
	end
end

assign inf.complete = (inf.out_valid && inf.err_msg == No_Err);

endmodule
