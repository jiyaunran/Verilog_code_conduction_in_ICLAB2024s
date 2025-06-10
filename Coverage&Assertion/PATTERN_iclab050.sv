/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2024 Spring IC Design Laboratory 
Lab08: SystemVerilog Design and Verification 
File Name   : PATTERN.sv
Module Name : PATTERN
Release version : v1.0 (Release Date: Apr-2024)
Author : Jui-Huang Tsai (erictsai.ee12@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype_BEV.sv"
`define PATTERN_NUM 	7200
`define CYCLE_TIME      15.0

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter DRAM_p_w = "../00_TESTBED/DRAM/output.dat";
real CYCLE = `CYCLE_TIME;
//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM [((65536+8*256)-1):(65536+0)];  

//================================================================
// class random
//================================================================

/**
 * Class representing a random action.
 */


class random_act;
    randc Action act_id;
    constraint range{
        act_id inside{Make_drink, Supply, Check_Valid_Date};
    }
endclass


/**
 * Class representing a random box from 0 to 31.
 */

class random_box;
    randc logic [7:0] box_id;
    constraint range{
        box_id inside{[0:255]};
    }
endclass

/**
 * Class representing a random type of beverage.
 */
class random_type;
	randc logic [2:0] type_id;
	constraint range{
		type_id inside{
			Black_Tea      ,
			Milk_Tea	   ,
			Extra_Milk_Tea ,
			Green_Tea 	       ,
            Green_Milk_Tea     ,
            Pineapple_Juice    ,
            Super_Pineapple_Tea,
            Super_Pineapple_Milk_Tea                
		};
	}
endclass

/**
 * Class representing a random size of beverage.
 */
class random_size;
	randc logic [1:0] size_id;
	constraint range{
		size_id inside{L,M,S};
	}
endclass


random_act act_rand;
random_box box_rand;
random_type type_rand;
random_size size_rand;


Date cur_date;
ING cur_supply[3:0];

integer total_latency;
integer n_PAT;
integer t;
integer latency;

logic [11:0] BT_cost;
logic [11:0] GT_cost;
logic [11:0] MK_cost;
logic [11:0] PJ_cost;

logic [11:0] BT_value;
logic [11:0] GT_value;
logic [11:0] MK_value;
logic [11:0] PJ_value;
logic [3:0]  Mon_value;
logic [4:0]  Day_value;
		
logic [12:0] BT_total;
logic [12:0] GT_total;
logic [12:0] MK_total;
logic [12:0] PJ_total;

logic [1:0]  golden_err;
logic golden_complete;

parameter N_PATTERN = `PATTERN_NUM;

//================================================================
// initial
//================================================================

initial begin
	$readmemh(DRAM_p_r, golden_DRAM);
	act_rand = new();
	box_rand = new();
	type_rand = new();
	size_rand = new();
	total_latency = 0;
	reset_task;
	
	t = $urandom_range(1, 3);
	repeat (t) @(negedge clk);
	
	for(n_PAT = 0; n_PAT < N_PATTERN; n_PAT=n_PAT+1) begin
		latency = 0;
		input_task;
		wait_out_valid_task;
		check_ans;
		//$display("pass pattern no. %d, task: %d, no_box: %d", n_PAT, act_rand.act_id, box_rand.box_id);
		repeat($urandom_range(1,3)) @(negedge clk);
	end
	$writememh(DRAM_p_w, golden_DRAM);
	YOU_PASS_TASK;

end

//================================================================
// tasks
//================================================================
task reset_task; begin
	inf.rst_n = 1'b1;
    inf.sel_action_valid = 1'b0;
    inf.type_valid = 1'b0;
    inf.size_valid = 1'b0;
    inf.date_valid = 1'b0;
    inf.box_no_valid = 1'b0;
    inf.box_sup_valid = 1'b0;
    inf.D = 'dx;
	
	force clk = 0;
	
	#(10); inf.rst_n = 0;
    #(50); inf.rst_n = 1;
	
	release clk;
	
	if(inf.out_valid !== 1'b0 || inf.complete !== 1'b0 || inf.err_msg !== 2'b00) begin
        YOU_FAIL_TASK;
        $display("************************************************************");
        $display("*  Output signal should be 0 after initial RESET           *");
        $display("************************************************************");
        repeat(2) @(negedge clk);
        $finish;
    end
end endtask

task input_task; begin
	inf.sel_action_valid = 1'b1;
	act_rand.randomize();
	inf.D = act_rand.act_id;
	@ (negedge clk);
	inf.sel_action_valid = 1'b0;
	inf.D = 'dx;
	repeat (t) @(negedge clk);
	t = $urandom_range(0, 3);
	
	if(act_rand.act_id == Make_drink) begin
		///////////////////////////////
        ////////input 4 bev type///////
        ///////////////////////////////
		inf.type_valid = 1'b1;
		type_rand.randomize();
		inf.D = type_rand.type_id;
		@ (negedge clk);
		
		inf.type_valid = 1'b0;
		inf.D = 'dx;
		
		///////////////////////////////
        ////////input 4 box size///////
        ///////////////////////////////
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.size_valid = 1'b1;
		size_rand.randomize();
		inf.D = size_rand.size_id;
		@ (negedge clk);
		
		inf.size_valid = 1'b0;
		inf.D = 'dx;
		
		///////////////////////////////
        ////////input 4 date///////////
        ///////////////////////////////
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.date_valid = 1'b1;
		cur_date.M = $urandom_range(1,12);
		if(cur_date.M == 'd2) begin
			cur_date.D = $urandom_range(1,28);
		end
		else if(cur_date.M == 1 || cur_date.M == 3 || cur_date.M == 5 || cur_date.M == 7 || cur_date.M == 8 ||
           cur_date.M == 10|| cur_date.M == 12) begin
			cur_date.D = $urandom_range(1,31);
		end
		else begin
			cur_date.D = $urandom_range(1,30);
		end
		inf.D = cur_date;
		
		@(negedge clk);
		inf.date_valid = 1'b0;
		inf.D = 'dx;
		
		///////////////////////////////
        ////////input 4 box num////////
        ///////////////////////////////
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.box_no_valid = 1'b1;
		box_rand.randomize();
		inf.D = box_rand.box_id;
		
		@(negedge clk);
		inf.box_no_valid = 1'b0;
		inf.D = 'dx;
	end
	else if(act_rand.act_id == Supply) begin
		///////////////////////////////
        ////////input 4 date///////////
        ///////////////////////////////
		inf.date_valid = 1'b1;
		cur_date.M = $urandom_range(1,12);
		if(cur_date.M == 'd2) begin
			cur_date.D = $urandom_range(1,28);
		end
		else if(cur_date.M == 1 || cur_date.M == 3 || cur_date.M == 5 || cur_date.M == 7 || cur_date.M == 8 ||
           cur_date.M == 10|| cur_date.M == 12) begin
			cur_date.D = $urandom_range(1,31);
		end
		else begin
			cur_date.D = $urandom_range(1,30);
		end
		inf.D = cur_date;
		
		@(negedge clk);
		inf.date_valid = 1'b0;
		inf.D = 'dx;
		
		///////////////////////////////
        ////////input 4 box num////////
        ///////////////////////////////
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.box_no_valid = 1'b1;
		box_rand.randomize();
		inf.D = box_rand.box_id;
		
		@(negedge clk);
		inf.box_no_valid = 1'b0;
		inf.D = 'dx;
		
		///////////////////////////////
        ////////input 4 supply/////////
        ///////////////////////////////
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.box_sup_valid = 1'b1;
		cur_supply[0] = $urandom_range(0, 4095);
		inf.D = cur_supply[0];
		
		@(negedge clk);
		inf.box_sup_valid = 1'b0;
		inf.D = 'dx;
		
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.box_sup_valid = 1'b1;
		cur_supply[1] = $urandom_range(0, 4095);
		inf.D = cur_supply[1];
		
		@(negedge clk);
		inf.box_sup_valid = 1'b0;
		inf.D = 'dx;
		
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.box_sup_valid = 1'b1;
		cur_supply[2] = $urandom_range(0, 4095);
		inf.D = cur_supply[2];
		
		@(negedge clk);
		inf.box_sup_valid = 1'b0;
		inf.D = 'dx;
		
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.box_sup_valid = 1'b1;
		cur_supply[3] = $urandom_range(0, 4095);
		inf.D = cur_supply[3];
		
		@(negedge clk);
		inf.box_sup_valid = 1'b0;
		inf.D = 'dx;
	end
	else begin
		///////////////////////////////
        ////////input 4 date///////////
        ///////////////////////////////
		inf.date_valid = 1'b1;
		cur_date.M = $urandom_range(1,12);
		if(cur_date.M == 'd2) begin
			cur_date.D = $urandom_range(1,28);
		end
		else if(cur_date.M == 1 || cur_date.M == 3 || cur_date.M == 5 || cur_date.M == 7 || cur_date.M == 8 ||
           cur_date.M == 10|| cur_date.M == 12) begin
			cur_date.D = $urandom_range(1,31);
		end
		else begin
			cur_date.D = $urandom_range(1,30);
		end
		inf.D = cur_date;
		
		@(negedge clk);
		inf.date_valid = 1'b0;
		inf.D = 'dx;
		
		///////////////////////////////
        ////////input 4 box num////////
        ///////////////////////////////
		repeat (t) @(negedge clk);
		t = $urandom_range(0, 3);
		inf.box_no_valid = 1'b1;
		box_rand.randomize();
		inf.D = box_rand.box_id;
		
		@(negedge clk);
		inf.box_no_valid = 1'b0;
		inf.D = 'dx;	
	end	
end endtask

task wait_out_valid_task; begin
	while(inf.out_valid !== 1'b1) begin
		latency = latency + 1;
		if(latency == 1000) begin
			YOU_FAIL_TASK;
            $display("*************************************************************************");
            $display("                           fail pattern: %d                           ", n_PAT);
            $display("             The execution latency is limited in 1000 cycle              ");
            $display("*************************************************************************");
			$writememh(DRAM_p_w, golden_DRAM);
			repeat (2) @ (negedge clk);
			$finish;
		end
		
		if(inf.err_msg !== 'd0 || inf.complete !== 1'b0) begin
			YOU_FAIL_TASK;
            $display("*************************************************************************");
            $display("                           fail pattern: %d                           ", n_PAT);
            $display("            The output should remain 0 until out_valid was high			");
            $display("*************************************************************************");
			$writememh(DRAM_p_w, golden_DRAM);
            repeat (2) @ (negedge clk);
			$finish;
		end
		@(negedge clk);
	end
	total_latency = total_latency + latency;
end endtask

task check_ans; begin
	BT_value = {golden_DRAM[65536+ 7 +8*box_rand.box_id],      golden_DRAM[65536+ 6 +8*box_rand.box_id][7:4]};
	GT_value = {golden_DRAM[65536+ 6 +8*box_rand.box_id][3:0], golden_DRAM[65536+ 5 +8*box_rand.box_id]};
    MK_value = {golden_DRAM[65536+ 3 +8*box_rand.box_id],      golden_DRAM[65536+ 2 +8*box_rand.box_id][7:4]};
    PJ_value = {golden_DRAM[65536+ 2 +8*box_rand.box_id][3:0], golden_DRAM[65536+ 1 +8*box_rand.box_id]};
    Mon_value= {golden_DRAM[65536+ 4 +8*box_rand.box_id]};
    Day_value= {golden_DRAM[65536+ 0 +8*box_rand.box_id]};
	
	golden_err = 2'b00;
	golden_complete = 1'b1;
	if(act_rand.act_id == Make_drink) begin	
		///////////////////////////////
        ////////check ingredient///////
        ///////////////////////////////
		case(size_rand.size_id)
			L	:	BT_cost = 960;
			M	:	BT_cost = 720;
			S	:	BT_cost = 480;
		endcase
		
		case(size_rand.size_id)
			L	:	GT_cost = 960;
			M	:	GT_cost = 720;
			S	:	GT_cost = 480;
		endcase
		
		case(size_rand.size_id)
			L	:	MK_cost = 960;
			M	:	MK_cost = 720;
			S	:	MK_cost = 480;
		endcase
		
		case(size_rand.size_id)
			L	:	PJ_cost = 960;
			M	:	PJ_cost = 720;
			S	:	PJ_cost = 480;
		endcase
		
		
		case(type_rand.type_id)
			Black_Tea					:	BT_cost = BT_cost;
			Milk_Tea					:	BT_cost = BT_cost / 4 * 3;
			Extra_Milk_Tea,
			Super_Pineapple_Tea,
			Super_Pineapple_Milk_Tea	:	BT_cost = BT_cost / 2;
			default						:	BT_cost = 'd0;
		endcase
		
		case(type_rand.type_id)
			Green_Tea					:	GT_cost = GT_cost;
			Green_Milk_Tea				:	GT_cost = GT_cost / 2;
			default						:	GT_cost = 'd0;
		endcase
		
		case(type_rand.type_id)
			Milk_Tea,
			Super_Pineapple_Milk_Tea	:	MK_cost = MK_cost / 4;
			Extra_Milk_Tea,
			Green_Milk_Tea				:	MK_cost = MK_cost / 2;
			default						:	MK_cost = 'd0;
		endcase
		
		case(type_rand.type_id)
			Pineapple_Juice				:	PJ_cost = PJ_cost;
			Super_Pineapple_Tea			:	PJ_cost = PJ_cost / 2;                 
			Super_Pineapple_Milk_Tea	:	PJ_cost = PJ_cost / 4;
			default						:	PJ_cost = 'd0;
		endcase
		
		if(BT_cost > BT_value) begin
			golden_err = 2'b10;
			golden_complete = 1'b0;
		end
		if(GT_cost > GT_value) begin
			golden_err = 2'b10;
			golden_complete = 1'b0;
		end
		if(MK_cost > MK_value) begin
			golden_err = 2'b10;
			golden_complete = 1'b0;
		end
		if(PJ_cost > PJ_value) begin
			golden_err = 2'b10;
			golden_complete = 1'b0;
		end
		
		///////////////////////////////
        ////////check Exp Day//////////
        ///////////////////////////////
		if(Mon_value < cur_date.M) begin
			golden_err = 2'b01;
			golden_complete = 1'b0;
		end
		
		if(Mon_value == cur_date.M) begin
			if(Day_value < cur_date.D) begin
				golden_err = 2'b01;
				golden_complete = 1'b0;
			end
		end
		
	end
	else if(act_rand.act_id == Supply) begin
		///////////////////////////////
        ////////check overflow/////////
        ///////////////////////////////
		BT_total = BT_value + cur_supply[0];
		GT_total = GT_value + cur_supply[1];
		MK_total = MK_value + cur_supply[2];
		PJ_total = PJ_value + cur_supply[3];
		
		if(BT_total > 'd4095) begin
			golden_err = 2'b11;
			golden_complete = 1'b0;
		end
		if(GT_total > 'd4095) begin
			golden_err = 2'b11;
			golden_complete = 1'b0;
		end
		if(MK_total > 'd4095) begin
			golden_err = 2'b11;
			golden_complete = 1'b0;
		end
		if(PJ_total > 'd4095) begin
			golden_err = 2'b11;
			golden_complete = 1'b0;
		end		
	end
	else begin
		///////////////////////////////
        ////////check Exp Day//////////
        ///////////////////////////////
		if(Mon_value < cur_date.M) begin
			golden_err = 2'b01;
			golden_complete = 1'b0;
		end
		
		if(Mon_value == cur_date.M) begin
			if(Day_value < cur_date.D) begin
				golden_err = 2'b01;
				golden_complete = 1'b0;
			end
		end
	end
	
	if(inf.err_msg !== golden_err) begin
		$display("Wrong Answer");
		$finish;
	end
	else if(inf.complete === 1 && golden_err != 2'b00) begin
		$display("Wrong Answer");
		$finish;
    end
	else if(inf.complete !== golden_complete) begin
		$display("Wrong Answer");
		$finish;
	end
	///////////////////////////////
	////////update DRAM////////////
	///////////////////////////////
	if(act_rand.act_id == Make_drink) begin
		{golden_DRAM[65536+ 7 +8*box_rand.box_id], golden_DRAM[65536+ 6 +8*box_rand.box_id][7:4]} = (golden_err == 2'b00) ? BT_value - BT_cost : BT_value;
		{golden_DRAM[65536+ 6 +8*box_rand.box_id][3:0], golden_DRAM[65536+ 5 +8*box_rand.box_id]} = (golden_err == 2'b00) ? GT_value - GT_cost : GT_value;
		{golden_DRAM[65536+ 3 +8*box_rand.box_id], golden_DRAM[65536+ 2 +8*box_rand.box_id][7:4]} = (golden_err == 2'b00) ? MK_value - MK_cost : MK_value;
		{golden_DRAM[65536+ 2 +8*box_rand.box_id][3:0], golden_DRAM[65536+ 1 +8*box_rand.box_id]} = (golden_err == 2'b00) ? PJ_value - PJ_cost : PJ_value;
	end
	else if(act_rand.act_id == Supply) begin
		{golden_DRAM[65536+ 7 +8*box_rand.box_id], golden_DRAM[65536+ 6 +8*box_rand.box_id][7:4]} = (BT_total > 4095) ? 4095 : BT_total;
        {golden_DRAM[65536+ 6 +8*box_rand.box_id][3:0], golden_DRAM[65536+ 5 +8*box_rand.box_id]} = (GT_total > 4095) ? 4095 : GT_total;
        {golden_DRAM[65536+ 3 +8*box_rand.box_id], golden_DRAM[65536+ 2 +8*box_rand.box_id][7:4]} = (MK_total > 4095) ? 4095 : MK_total;
        {golden_DRAM[65536+ 2 +8*box_rand.box_id][3:0], golden_DRAM[65536+ 1 +8*box_rand.box_id]} = (PJ_total > 4095) ? 4095 : PJ_total;
        {golden_DRAM[65536+ 4 +8*box_rand.box_id]} = cur_date.M;
        {golden_DRAM[65536+ 0 +8*box_rand.box_id]} = cur_date.D;
	end
end endtask

task YOU_FAIL_TASK; begin
    $display("\n");
    $display("\n");
    $display("        ----------------------------               ");
    $display("        --                        --       |\__||  ");
    $display("        --  OOPS!!                --      / X,X  | ");
    $display("        --                        --    /_____   | ");
    $display("        --  \033[0;31mSimulation FAIL!!\033[m   --   /^ ^ ^ \\  |");
    $display("        --                        --  |^ ^ ^ ^ |w| ");
    $display("        ----------------------------   \\m___m__|_|");
    $display("\n");
end endtask

task YOU_PASS_TASK; begin
    $display("Congratulations");
	$finish;	
end endtask

endprogram
