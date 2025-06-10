/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2024 Spring IC Design Laboratory 
Lab09: SystemVerilog Coverage & Assertion
File Name   : CHECKER.sv
Module Name : CHECKER
Release version : v1.0 (Release Date: Apr-2024)
Author : Jui-Huang Tsai (erictsai.ee12@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype_BEV.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;

/*
    Coverage Part
*/

int i_pat;
parameter PAT_NUM = 7200;

// Class definition
class BEV;
    Bev_Type bev_type;
    Bev_Size bev_size;
endclass

BEV bev_info = new();

class Err_MSG;
	Error_Msg error_msg;
endclass

Err_MSG Err_info = new();

class Act;
	Action action;
endclass

Act Act_info = new();

class Supply_ING;
	ING supply_ing;
endclass

Supply_ING Supply_info = new();

// FF
always_ff @(posedge clk) begin
    if (inf.type_valid) begin
        bev_info.bev_type = inf.D.d_type[0];
    end
end

always_ff @(posedge clk) begin
    if (inf.size_valid) begin
        bev_info.bev_size = inf.D.d_size[0];
    end
end

always_ff @ (posedge clk) begin
	if(inf.out_valid) begin
		Err_info.error_msg = inf.err_msg;
	end
end

always_ff @ (posedge clk) begin
	if(inf.sel_action_valid) begin
		Act_info.action = inf.D.d_act[0];
	end
end

always_ff @ (posedge clk) begin
	if(inf.box_sup_valid) begin
		Supply_info.supply_ing = inf.D.d_ing[0];
	end
end


/*
1. Each case of Beverage_Type should be select at least 100 times.
*/


covergroup Spec1 @(posedge clk iff(inf.type_valid));
    option.per_instance = 1;
    option.at_least = 100;
    btype:coverpoint bev_info.bev_type{
        bins b_bev_type [] = {[Black_Tea:Super_Pineapple_Milk_Tea]};
    }
endgroup

/*
2.	Each case of Bererage_Size should be select at least 100 times.
*/
covergroup Spec2 @(posedge clk iff(inf.size_valid));
    option.per_instance = 1;
    option.at_least = 100;
    btype:coverpoint bev_info.bev_size{
        bins b_bev_size [] = {[L:S]};
    }
endgroup

/*
3.	Create a cross bin for the SPEC1 and SPEC2. Each combination should be selected at least 100 times. 
(Black Tea, Milk Tea, Extra Milk Tea, Green Tea, Green Milk Tea, Pineapple Juice, Super Pineapple Tea, Super Pineapple Tea) x (L, M, S)
*/
covergroup Spec3 @(posedge clk iff(inf.size_valid));
    option.per_instance = 1;
    option.at_least = 100;
    btype:cross bev_info.bev_type, bev_info.bev_size;
endgroup

/*
4.	Output signal inf.err_msg should be No_Err, No_Exp, No_Ing and Ing_OF, each at least 20 times. (Sample the value when inf.out_valid is high)
*/
covergroup Spec4 @(posedge clk iff(inf.out_valid));
    option.per_instance = 1;
    option.at_least = 20;
    btype:coverpoint Err_info.error_msg{
	bins b_err_msg [] ={[No_Err:Ing_OF]};
	}
endgroup

/*
5.	Create the transitions bin for the inf.D.act[0] signal from [0:2] to [0:2]. Each transition should be hit at least 200 times. (sample the value at posedge clk iff inf.sel_action_valid)
*/
covergroup Spec5 @(posedge clk iff(inf.sel_action_valid));
    option.per_instance = 1;
    option.at_least = 200;
    btype:coverpoint Act_info.action{
		bins b_act_trans [] = ([Make_drink:Check_Valid_Date]=>[Make_drink:Check_Valid_Date]);
	}
endgroup

/*
6.	Create a covergroup for material of supply action with auto_bin_max = 32, and each bin have to hit at least one time.
*/
covergroup Spec6 @(posedge clk iff(inf.box_sup_valid));
    option.per_instance = 1;
    option.at_least = 1;
    btype:coverpoint Supply_info.supply_ing{
		option.auto_bin_max = 32;
	}
endgroup

/*
    Create instances of Spec1, Spec2, Spec3, Spec4, Spec5, and Spec6
*/
Spec1 cg_spec1 = new();
Spec2 cg_spec2 = new();
Spec3 cg_spec3 = new();
Spec4 cg_spec4 = new();
Spec5 cg_spec5 = new();
Spec6 cg_spec6 = new();
always_ff @(negedge clk) begin
    if(inf.type_valid === 1'b1) 	cg_spec1.sample();
end

always_ff @(negedge clk) begin
    if(inf.size_valid === 1'b1) 	cg_spec2.sample();
end

always_ff @(negedge clk) begin
    if(inf.type_valid === 1'b1 || inf.size_valid) cg_spec3.sample();
end

always_ff @(negedge clk) begin
    if(inf.out_valid === 1'b1) 		cg_spec4.sample();
end

always_ff @(negedge clk) begin
    if(inf.sel_action_valid === 1'b1) cg_spec5.sample();
end

always_ff @(negedge clk) begin
    if(inf.box_sup_valid === 1'b1) 	cg_spec6.sample();
end

initial begin
    for(i_pat = 0; i_pat < PAT_NUM; i_pat = i_pat + 1) begin
        while (inf.out_valid !== 1'b1) begin
            @(negedge clk);
        end
        @(negedge clk);
    end
    @(negedge clk);
    $display("COVERAGE TABLE");
    $display("cg_spec1 = %f %", cg_spec1.get_coverage());
    $display("cg_spec2 = %f %", cg_spec2.get_coverage());
    $display("cg_spec3 = %f %", cg_spec3.get_coverage());
    $display("cg_spec4 = %f %", cg_spec4.get_coverage());
    $display("cg_spec5 = %f %", cg_spec5.get_coverage());
    $display("cg_spec6 = %f %", cg_spec6.get_coverage());
    $display("");
end

/*
    Asseration
*/

/*
    If you need, you can declare some FSM, logic, flag, and etc. here.
*/
logic reset_fin;
logic reset_fin_delay;
logic all_in_valid;
logic [1:0] supply_cnt;
logic [2:0] valid_num;
Action cur_act;
/*
    1. All outputs signals (including BEV.sv and bridge.sv) should be zero after reset.
*/
always_comb begin
	reset_fin = (	(inf.C_out_valid == 0) 	&&
					(inf.C_data_r == 0)		&&
					(inf.out_valid == 0)	&&
					(inf.err_msg == 0)		&&
					(inf.complete == 0)		&&
					(inf.C_addr == 0)		&&
					(inf.C_data_w == 0)		&&
					(inf.C_in_valid == 0)	&&
					(inf.C_r_wb == 0)		&&
					
					(inf.AR_VALID == 0)		&&
					(inf.R_READY == 0)		&&
					(inf.AW_VALID == 0)		&&
					(inf.W_VALID == 0)		&&
					(inf.B_READY == 0)		&&
					(inf.AR_ADDR == 0)		&&
					(inf.AW_ADDR == 0)		&&
					(inf.W_DATA == 0));	
	
end

assign #(1step) reset_fin_delay = inf.rst_n;

always @ (negedge reset_fin_delay) begin
	ast_spec_1 : assert (reset_fin == 1)
	else	$fatal(0, "\nAssertion 1 is violated\n");
end

/*
    2.	Latency should be less than 1000 cycles for each operation.
*/
always @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		supply_cnt = 'd0;
	end
	else begin
		if(inf.box_sup_valid)
			supply_cnt = supply_cnt + 'd1;
	end
end

logic check;
logic cnt_delay;
assign #(1step) cnt_delay = check;
assign check = (cur_act != Supply && supply_cnt == 0);

property assertion_2_1;
	@ (posedge clk) disable iff (check)
	(inf.box_sup_valid)	##[1:1000] inf.out_valid;
endproperty

property assertion_2_2;
	@ (posedge clk) disable iff(cur_act == Supply)
	(inf.box_no_valid) ##[1:1000] inf.out_valid;
endproperty

always @ (posedge inf.box_sup_valid) begin
	ast_spec_2_1: 	assert property (assertion_2_1)
	else			$fatal(0, "\nAssertion 2 is violated\n");
end

always @ (posedge inf.box_no_valid) begin
	ast_spec_2_2: 	assert property (assertion_2_2)
	else			$fatal(0, "\nAssertion 2 is violated\n");
end

/*
    3. If out_valid does not pull up, complete should be 0.
*/
always @ (posedge inf.complete) begin
	ast_spec_3:	assert(inf.err_msg == No_Err)
	else		$fatal(0, "\nAssertion 3 is violated\n");
end

/*
    4. Next input valid will be valid 1-4 cycles after previous input valid fall.
*/
assign all_in_valid = (	(inf.type_valid)		||
						(inf.sel_action_valid)	||
						(inf.size_valid)		||
						(inf.date_valid)		||
						(inf.box_no_valid)		||
						(inf.box_sup_valid));

always_ff @ (posedge clk) begin
	if(inf.sel_action_valid) begin
		cur_act = inf.D.d_act[0];
	end
end

property assertion_4_type;
	@(posedge clk) inf.type_valid ##[1:4] all_in_valid;
endproperty

property assertion_4_size;
	@(posedge clk) inf.size_valid ##[1:4] all_in_valid;
endproperty

property assertion_4_date;
	@(posedge clk) inf.date_valid ##[1:4] all_in_valid;
endproperty

property assertion_4_box_no;
	@(posedge clk) disable iff(cur_act != Supply) 
	inf.box_no_valid ##[1:4] all_in_valid;
endproperty

logic check2;
assign check2 = (cur_act != Supply || supply_cnt != 'd0);

property assertion_4_box_sup;
	@(posedge clk) disable iff(!check2) 
	inf.box_sup_valid ##[1:4] all_in_valid;
endproperty

property assertion_4_action;
	@(posedge clk) inf.sel_action_valid ##[1:4] all_in_valid;
endproperty

always @ (posedge inf.sel_action_valid) begin
	ast_spec_4_act: assert  property (assertion_4_action)
	else			$fatal(0,"\nAssertion 4 is violated\n");
end

always @ (posedge inf.box_no_valid) begin
	ast_spec_4_bno: assert  property (assertion_4_box_no)
	else			$fatal(0,"\nAssertion 4 is violated\n");
end

always @ (posedge inf.box_sup_valid) begin
	ast_spec_4_bin: assert  property (assertion_4_box_sup)
	else			$fatal(0,"\nAssertion 4 is violated\n");
end

always @ (posedge inf.date_valid) begin
	ast_spec_4_dat: assert  property (assertion_4_date)
	else			$fatal(0,"\nAssertion 4 is violated\n");
end

always @ (posedge inf.size_valid) begin
	ast_spec_4_siz: assert  property (assertion_4_size)
	else			$fatal(0,"\nAssertion 4 is violated\n");
end

always @ (posedge inf.type_valid) begin
	ast_spec_4_typ: assert  property (assertion_4_type)
	else			$fatal(0,"\nAssertion 4 is violated\n");
end

/*
    5. All input valid signals won't overlap with each other. 
*/
always_comb begin
	valid_num = inf.sel_action_valid + inf.type_valid + inf.size_valid +
				inf.date_valid + inf.box_no_valid + inf.box_sup_valid;
end

always @ (posedge inf.sel_action_valid or inf.type_valid or inf.size_valid or
		  posedge inf.date_valid or inf.box_no_valid or inf.box_sup_valid) begin
	ast_spec_5: assert (valid_num < 'd2)
	else		$fatal(0, "\nAssertion 5 is violated\n");
end

/*
    6. Out_valid can only be high for exactly one cycle.
*/
property assertion_6;
	@(negedge clk) inf.out_valid |=> !inf.out_valid;
endproperty

always @ (posedge inf.out_valid) begin
	ast_spec_6: assert  property (assertion_6)
	else		$fatal(0, "\nAssertion 6 is violated\n");
end
/*
    7. Next operation will be valid 1-4 cycles after out_valid fall.
*/
property assertion_7;
	@(negedge clk) inf.out_valid ##[1:5] inf.sel_action_valid;
endproperty

always @ (posedge inf.out_valid) begin
	ast_spec_7: assert  property (assertion_7)
	else		$fatal(0, "\nAssertion 7 is violated\n");
end

/*
    8. The input date from pattern should adhere to the real calendar. (ex: 2/29, 3/0, 4/31, 13/1 are illegal cases)
*/
always @ (posedge inf.date_valid) begin
	ast_spec_8_1: assert (inf.D.d_date[0].M <= 'd12 && inf.D.d_date[0].M != 'd0 && inf.D.d_date[0].D != 'd0)
	else		$fatal(0, "\nAssertion 8 is violated\n");
end

always @ (posedge inf.date_valid) begin
	ast_spec_8_2: assert (	(inf.D.d_date[0].M == 'd1 && inf.D.d_date[0].D <= 'd31)	||
							(inf.D.d_date[0].M == 'd2 && inf.D.d_date[0].D <= 'd28)	||
							(inf.D.d_date[0].M == 'd3 && inf.D.d_date[0].D <= 'd31)	||
							(inf.D.d_date[0].M == 'd4 && inf.D.d_date[0].D <= 'd30)	||
							(inf.D.d_date[0].M == 'd5 && inf.D.d_date[0].D <= 'd31)	||
							(inf.D.d_date[0].M == 'd6 && inf.D.d_date[0].D <= 'd30)	||
							(inf.D.d_date[0].M == 'd7 && inf.D.d_date[0].D <= 'd31)	||
							(inf.D.d_date[0].M == 'd8 && inf.D.d_date[0].D <= 'd31)	||
							(inf.D.d_date[0].M == 'd9 && inf.D.d_date[0].D <= 'd30)	||
							(inf.D.d_date[0].M == 'd10 && inf.D.d_date[0].D <= 'd31)||
							(inf.D.d_date[0].M == 'd11 && inf.D.d_date[0].D <= 'd30)||
							(inf.D.d_date[0].M == 'd12 && inf.D.d_date[0].D <= 'd31))
	else		$fatal(0, "\nAssertion 8 is violated\n");
end


/*
    9. C_in_valid can only be high for one cycle and can't be pulled high again before C_out_valid
*/
property assertion_9_1;
	@(negedge clk) inf.C_in_valid |=> !inf.C_in_valid;
endproperty

property assertion_9_2;
	@(negedge inf.C_in_valid) inf.C_in_valid |-> !inf.C_out_valid;
endproperty

always @ (posedge inf.C_in_valid) begin
	ast_spec_9_1:	assert property (assertion_9_1)
	else			$fatal(0, "\nAssertion 9 is violated\n");
end

always @ (posedge inf.C_in_valid) begin
	ast_spec_9_2:	assert property (assertion_9_2)
	else			$fatal(0, "\nAssertion 9 is violated\n");
end

endmodule
