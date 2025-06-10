//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2021 Final Project: Customized ISA Processor 
//   Author              : Hsi-Hao Huang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CPU.v
//   Module Name : CPU.v
//   Release version : V1.0 (Release Date: 2021-May)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CPU(

				clk,
			  rst_n,
  
		   IO_stall,

         awid_m_inf,
       awaddr_m_inf,
       awsize_m_inf,
      awburst_m_inf,
        awlen_m_inf,
      awvalid_m_inf,
      awready_m_inf,
                    
        wdata_m_inf,
        wlast_m_inf,
       wvalid_m_inf,
       wready_m_inf,
                    
          bid_m_inf,
        bresp_m_inf,
       bvalid_m_inf,
       bready_m_inf,
                    
         arid_m_inf,
       araddr_m_inf,
        arlen_m_inf,
       arsize_m_inf,
      arburst_m_inf,
      arvalid_m_inf,
                    
      arready_m_inf, 
          rid_m_inf,
        rdata_m_inf,
        rresp_m_inf,
        rlast_m_inf,
       rvalid_m_inf,
       rready_m_inf 

);
// Input port
input  wire clk, rst_n;
// Output port
output reg  IO_stall;

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
  your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
  therefore I declared output of AXI as wire in CPU
*/



// axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf;
output  wire [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf;
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf;
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf;
output  wire [WRIT_NUMBER * 7 -1:0]             awlen_m_inf;
output  wire [WRIT_NUMBER-1:0]                awvalid_m_inf;
input   wire [WRIT_NUMBER-1:0]                awready_m_inf;
// axi write data channel 
output  wire [WRIT_NUMBER * DATA_WIDTH-1:0]     wdata_m_inf;
output  wire [WRIT_NUMBER-1:0]                  wlast_m_inf;
output  wire [WRIT_NUMBER-1:0]                 wvalid_m_inf;
input   wire [WRIT_NUMBER-1:0]                 wready_m_inf;
// axi write response channel
input   wire [WRIT_NUMBER * ID_WIDTH-1:0]         bid_m_inf;
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf;
input   wire [WRIT_NUMBER-1:0]             	   bvalid_m_inf;
output  wire [WRIT_NUMBER-1:0]                 bready_m_inf;
// -----------------------------
// axi read address channel 
output  wire [DRAM_NUMBER * ID_WIDTH-1:0]       arid_m_inf;
output  wire [DRAM_NUMBER * ADDR_WIDTH-1:0]   araddr_m_inf;
output  wire [DRAM_NUMBER * 7 -1:0]            arlen_m_inf;
output  wire [DRAM_NUMBER * 3 -1:0]           arsize_m_inf;
output  wire [DRAM_NUMBER * 2 -1:0]          arburst_m_inf;
output  wire [DRAM_NUMBER-1:0]               arvalid_m_inf;
input   wire [DRAM_NUMBER-1:0]               arready_m_inf;
// -----------------------------
// axi read data channel 
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf;
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf;
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;
output  wire [DRAM_NUMBER-1:0]                 rready_m_inf;
// -----------------------------

//
//
// 
/* Register in each core:
  There are sixteen registers in your CPU. You should not change the name of those registers.
  TA will check the value in each register when your core is not busy.
  If you change the name of registers below, you must get the fail in this lab.
*/

reg signed [15:0] core_r0 , core_r1 , core_r2 , core_r3 ;
reg signed [15:0] core_r4 , core_r5 , core_r6 , core_r7 ;
reg signed [15:0] core_r8 , core_r9 , core_r10, core_r11;
reg signed [15:0] core_r12, core_r13, core_r14, core_r15;


//###########################################
//
// Wrtie down your design below
//
//###########################################

//####################################################
//               reg & wire
//####################################################
wire [ID_WIDTH-1:0]        awid_m_inf_data;
wire [ADDR_WIDTH-1:0]    awaddr_m_inf_data;
wire [3 -1:0]            awsize_m_inf_data;
wire [2 -1:0]           awburst_m_inf_data;
wire [7 -1:0]             awlen_m_inf_data;
wire 	               awvalid_m_inf_data;
wire 	               awready_m_inf_data;
// axi write data channel 
wire [DATA_WIDTH-1:0]     wdata_m_inf_data;
wire 	                  wlast_m_inf_data;
wire 	                 wvalid_m_inf_data;
wire 	                 wready_m_inf_data;
// axi write response channel
wire [ID_WIDTH-1:0]         bid_m_inf_data;
wire [2 -1:0]             bresp_m_inf_data;
wire 	             	   bvalid_m_inf_data;
wire 	                 bready_m_inf_data;
// -----------------------------
// axi read address channel 
wire [ID_WIDTH-1:0]       arid_m_inf_data;
wire [ADDR_WIDTH-1:0]   araddr_m_inf_data;
wire [7 -1:0]            arlen_m_inf_data;
wire [3 -1:0]           arsize_m_inf_data;
wire [2 -1:0]          arburst_m_inf_data;
wire              	  arvalid_m_inf_data;
wire              	  arready_m_inf_data;
// -----------------------------
// axi read data channel 
wire [ID_WIDTH-1:0]         rid_m_inf_data;
wire [DATA_WIDTH-1:0]     rdata_m_inf_data;
wire [2 -1:0]             rresp_m_inf_data;
wire 	                  rlast_m_inf_data;
wire 	                 rvalid_m_inf_data;
wire 	                 rready_m_inf_data;
// -----------------------------
// axi read address channel 
wire [ID_WIDTH-1:0]       arid_m_inf_inst;
wire [ADDR_WIDTH-1:0]   araddr_m_inf_inst;
wire [7 -1:0]            arlen_m_inf_inst;
wire [3 -1:0]           arsize_m_inf_inst;
wire [2 -1:0]          arburst_m_inf_inst;
wire              	  arvalid_m_inf_inst;
wire              	  arready_m_inf_inst;
// -----------------------------
// axi read data channel 
wire [ID_WIDTH-1:0]         rid_m_inf_inst;
wire [DATA_WIDTH-1:0]     rdata_m_inf_inst;
wire [2 -1:0]             rresp_m_inf_inst;
wire 	                  rlast_m_inf_inst;
wire 	                 rvalid_m_inf_inst;
wire 	                 rready_m_inf_inst;

// axi read address channel 
assign      arid_m_inf[7:4] = arid_m_inf_inst;
assign    araddr_m_inf[63:32] =  araddr_m_inf_inst;
assign     arlen_m_inf[13:7] = arlen_m_inf_inst;
assign    arsize_m_inf[5:3] = arsize_m_inf_inst;
assign   arburst_m_inf[3:2] = arburst_m_inf_inst;
assign   arvalid_m_inf[1] = arvalid_m_inf_inst;
assign   arready_m_inf_inst = arready_m_inf[1];
// -----------------------------
// axi read data channel 
assign 	   rid_m_inf_inst =    rid_m_inf[7:4];
assign 	 rdata_m_inf_inst =  rdata_m_inf[31:16];
assign 	 rresp_m_inf_inst =  rresp_m_inf[3:2];
assign 	 rlast_m_inf_inst =  rlast_m_inf[1];
assign 	rvalid_m_inf_inst = rvalid_m_inf[1];
assign 	rready_m_inf[1] = rready_m_inf_inst;

// axi read address channel 
assign      arid_m_inf[3:0] = arid_m_inf_data;
assign    araddr_m_inf[31:0] = araddr_m_inf_data;
assign     arlen_m_inf[6:0] = arlen_m_inf_data;
assign    arsize_m_inf[2:0] = arsize_m_inf_data;
assign   arburst_m_inf[1:0] = arburst_m_inf_data;
assign   arvalid_m_inf[0] = arvalid_m_inf_data;
assign   arready_m_inf_data = arready_m_inf[0];
// -----------------------------
// axi read data channel 
assign 	   rid_m_inf_data =    rid_m_inf[3:0];
assign 	 rdata_m_inf_data =  rdata_m_inf[15:0];
assign 	 rresp_m_inf_data =  rresp_m_inf[1:0];
assign 	 rlast_m_inf_data =  rlast_m_inf[0];
assign 	rvalid_m_inf_data = rvalid_m_inf[0];
assign 	rready_m_inf[0] = rready_m_inf_data;

// axi write address channel 
assign     awid_m_inf = awid_m_inf_data;
assign   awaddr_m_inf = awaddr_m_inf_data;
assign   awsize_m_inf = awsize_m_inf_data;
assign  awburst_m_inf = awburst_m_inf_data;
assign    awlen_m_inf = awlen_m_inf_data;
assign awvalid_m_inf = awvalid_m_inf_data;
assign awready_m_inf_data = awready_m_inf;
// axi write data channel 
assign  wdata_m_inf = wdata_m_inf_data;
assign  wlast_m_inf = wlast_m_inf_data;
assign wvalid_m_inf = wvalid_m_inf_data;
assign wready_m_inf_data = wready_m_inf;
// axi write response channel
assign    bid_m_inf_data =    bid_m_inf;
assign  bresp_m_inf_data =  bresp_m_inf;
assign bvalid_m_inf_data = bvalid_m_inf;
assign bready_m_inf = bready_m_inf_data;


reg [10:0] inst_sram_addr;
reg [15:0] inst_sram_in;
reg [15:0] inst_sram_out;
reg inst_sram_wr;

reg [1:0] init_sram_mem_id_stable;

reg [1:0] sram_state[2:0], sram_state_next[2:0];
reg sram_state_toLOAD[2:0];
reg [3:0] cur_mem_id[2:0];
reg [1:0] mid_sram_id;
reg [1:0] post_sram_id;
reg [1:0] pre_sram_id;


reg inst_dram_req;
reg turn_next_sram;
reg [3:0] cycle_reading_numb;
reg [3:0] inst_dram_req_id;

reg inst_dram_busy;

reg signed [10:0] cur_inst_addr, cur_inst_addr_next; // 0~2048
wire [3:0] cur_inst_id;
wire [6:0] cur_inst_sram_addr;
reg cur_mem_addsub;
reg [1:0] id_match_instNsram;
wire init_inst_sram;

reg [10:0] inst_reading_addr, inst_reading_addr_delay;

reg [1:0] SRAM_select_IF;

reg [15:0] instruction;
reg [2:0] inst_type;
reg [3:0] rt_addr;
reg [3:0] rd_addr;
reg [3:0] rs_addr;
reg [4:0] immediate;
reg [8:0] coef_b;
reg [3:0] coef_a;
reg func;
reg [4:0] reg_under_calc;

reg [15:0] rs_data, rs_data_next;
reg [15:0] rt_data, rt_data_next;
reg signed [15:0] rs_data_final;
reg signed [15:0] rt_data_final;
reg [3:0] rd_addr_forward_EXE;
reg [3:0] rs_addr_forward_EXE;
reg [3:0] rt_addr_forward_EXE;
reg [3:0] rd_addr_forward_MA;
reg [3:0] rs_addr_forward_MA;
reg [3:0] rt_addr_forward_MA;
reg [3:0] rd_addr_forward_WB;
reg [3:0] rs_addr_forward_WB;
reg [3:0] rt_addr_forward_WB;
reg [15:0] immediate_forward;
reg [2:0] inst_type_forward_EXE;
reg [2:0] inst_type_forward_MA;
reg [2:0] inst_type_forward_WB;
reg [3:0] save_reg_addr_MA;
reg [3:0] save_reg_addr_WB;
reg [15:0] ALU_out_forward_MA;
reg [15:0] ALU_out_forward_WB;
reg [10:0] inst_addr_forward_EXE;
reg [10:0] inst_addr_forward_ID;
reg [15:0] rt_data_forward_MA;

reg signed [15:0] ALU_in1, ALU_in2;
wire signed [15:0] Add_in[1:0];
wire signed [15:0] Sub_in[1:0];
reg signed [31:0] Mult_in[29:0][1:0];

wire signed [15:0] Add_out;
wire signed [15:0] Sub_out;
reg signed [63:0] Mult_out[29:0];

reg signed [15:0] ALU_out;

reg [3:0] Determiant_cycle;

reg signed [15:0] core_r0_final , core_r1_final , core_r2_final , core_r3_final ;
reg signed [15:0] core_r4_final , core_r5_final , core_r6_final , core_r7_final ;
reg signed [15:0] core_r8_final , core_r9_final , core_r10_final, core_r11_final;
reg signed [15:0] core_r12_final, core_r13_final, core_r14_final, core_r15_final;

reg signed [31:0] Determinant_tmp_16b[17:0]; 
reg signed [63:0] Determinant_tmp_32b[5:0]; 
reg signed [69:0] Determinant_tmp_add, Determinant_tmp_add_next;
reg signed [68:0] Determinant_tmp_sub;
reg signed [69:0] Determinant_final;
reg signed [15:0] Determinant_final_clip;

reg [10:0] Inst_addr_before_add;

reg [15:0] Memory_block_read, Memory_block_read_next;
reg [3:0] cur_inst_dram_req_id, cur_inst_dram_req_id_next, cur_inst_dram_req_id_delay;


reg data_dram_req;
reg data_dram_read_req;
reg data_dram_write_req;
reg data_dram_reading;
reg data_dram_finish_read;
reg data_dram_wr;

reg [3:0] data_dram_id;
reg [6:0] data_dram_addr;
reg [15:0] data_dram_data_in;

reg data_dram_busy;

reg [10:0] data_reading_addr, data_reading_addr_delay;
reg [10:0] data_writing_addr;
reg [10:0] data_sram_addr;

reg [15:0] data_sram_in;
reg [15:0] data_sram_out;
reg data_sram_wr;

reg [10:0] data_dram_write_idaddr;


reg [15:0] data_WB;
reg WB;

reg wash;
reg wash_delay;

reg [17:0] DATA_HAZARD_CHECK;
reg DATA_HAZARD_hold;
reg INST_DRAM_hold;
reg Calc_Determinant_hold;
wire DATA_DRAM_hold;
reg MEMORY_ACCESS_hold;
wire System_hold;

wire show_function_bit;

reg null_inst;

reg [15:0] instruction_store_for_hold;
reg hold_delay;

reg inst_dram_finish_read, inst_dram_finish_read_delay;
reg [3:0] cur_data_dram_req_id;

reg pull_for_maxL;
reg run_first_inst;
reg run_first_inst_forward_ID;
reg run_first_inst_forward_EXE;
reg run_first_inst_forward_MA;
reg run_first_inst_forward_WB;
reg fin_first_inst;

wire signed [16:0] Upper_bound;
wire signed [16:0] Lower_bound;

reg signed [16:0] Mult_in_16b[5:0][1:0];
reg signed [31:0] Mult_in_32b[5:0][1:0];

reg signed [31:0] Mult_out_16b[5:0];
reg signed [63:0] Mult_out_32b[5:0];

reg data_from_dram_in;
reg [31:0] dram_data_buf;

parameter IDLE = 0;
parameter LOAD = 1;
parameter READY = 2;
parameter NULL_INST_TYPE = 6;

genvar i;
//####################################################
//               		SRAM
//####################################################
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		fin_first_inst <= 'd0;
	end
	else begin
		if(cur_data_dram_req_id == 'd9 && cur_inst_dram_req_id == 'd9) begin
			fin_first_inst <= 'd1;
		end
		else begin
			fin_first_inst <= fin_first_inst;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		run_first_inst <= 'd0;
	end
	else begin
		if(fin_first_inst) begin
			run_first_inst <= 'd0;
		end
		else if(cur_data_dram_req_id == 'd9 && cur_inst_dram_req_id == 'd9) begin
			run_first_inst <= 'd1;
		end
		else begin
			run_first_inst <= 'd0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		run_first_inst_forward_ID <= 'd0;
	end
	else begin
		run_first_inst_forward_ID <= run_first_inst;
	end
end

assign System_hold = (DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || DATA_HAZARD_hold || MEMORY_ACCESS_hold);

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		hold_delay <= 'd0;
	end
	else begin
		hold_delay <= System_hold;
	end
end
// sram address
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_reading_addr <= 'd0;
	end
	else begin
		if(rready_m_inf[1] && rvalid_m_inf[1]) begin
			inst_reading_addr <= inst_reading_addr + 'd1;
		end
		else begin
			inst_reading_addr <= inst_reading_addr;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_reading_addr_delay <= 'd0;
	end
	else begin
		inst_reading_addr_delay <= inst_reading_addr;
	end
end

// next instruction
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cur_inst_addr <= 'd0;
	end
	else begin
		if(run_first_inst_forward_EXE) begin
			cur_inst_addr <= cur_inst_addr_next;
		end
		else if(DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || DATA_HAZARD_hold || MEMORY_ACCESS_hold) begin
			cur_inst_addr <= cur_inst_addr;
		end
		else begin
			cur_inst_addr <= cur_inst_addr_next;
		end
	end
end

assign cur_inst_sram_addr 	= cur_inst_addr[6:0];
assign cur_inst_id 			= cur_inst_addr[10:7];

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_dram_busy <= 'd0;
	end
	else begin
		if(inst_dram_req) begin
			inst_dram_busy <= 'd1;
		end
		else if(rvalid_m_inf_inst && rready_m_inf_inst && rlast_m_inf_inst) begin
			inst_dram_busy <= 'd0;
		end
		else begin
			inst_dram_busy <= inst_dram_busy;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cur_inst_dram_req_id <= 'd0;
	end
	else begin
		if(rlast_m_inf_inst && rready_m_inf_inst && rvalid_m_inf_inst) begin
			cur_inst_dram_req_id <= cur_inst_dram_req_id + 'd1;
		end
		else begin
			cur_inst_dram_req_id <= cur_inst_dram_req_id;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cur_inst_dram_req_id_delay <= 'd0;
	end
	else begin
		cur_inst_dram_req_id_delay <= cur_inst_dram_req_id;
	end
end

assign INST_DRAM_hold = (!inst_dram_finish_read_delay);

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_dram_finish_read <= 'd0;
	end
	else begin
		if(cur_inst_dram_req_id == 'd15 && rlast_m_inf_inst && rready_m_inf_inst && rvalid_m_inf_inst) begin
			inst_dram_finish_read <= 'd1;
		end
		else begin
			inst_dram_finish_read <= inst_dram_finish_read;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_dram_finish_read_delay <= 'd0;
	end
	else begin
		inst_dram_finish_read_delay <= inst_dram_finish_read;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_sram_wr <= 'd0;
	end
	else begin
		if(rvalid_m_inf_inst && rready_m_inf_inst) begin
			inst_sram_wr <= 'd0;
		end
		else begin
			inst_sram_wr <= 'd1;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_sram_in <= 'd0;
	end
	else begin
		if(rvalid_m_inf_inst && rready_m_inf_inst) begin
			inst_sram_in <= rdata_m_inf_inst;
		end
		else begin
			inst_sram_in <= 'd0;
		end
	end
end

always @ * begin
	if(run_first_inst)
		inst_sram_addr = 'd0;
	else if(!inst_dram_finish_read_delay)	
		inst_sram_addr = inst_reading_addr_delay;
	else 
		inst_sram_addr = cur_inst_addr;
		
	
	inst_dram_req = (!inst_dram_finish_read) && !inst_dram_busy && !pull_for_maxL;
end

SRAM_2048w_16b inst_sram(
.A0(inst_sram_addr[0]),
.A1(inst_sram_addr[1]),
.A2(inst_sram_addr[2]),
.A3(inst_sram_addr[3]),
.A4(inst_sram_addr[4]),
.A5(inst_sram_addr[5]),
.A6(inst_sram_addr[6]),
.A7(inst_sram_addr[7]),
.A8(inst_sram_addr[8]),
.A9(inst_sram_addr[9]),
.A10(inst_sram_addr[10]),
.DO0(inst_sram_out[0]),
.DO1(inst_sram_out[1]),
.DO2(inst_sram_out[2]),
.DO3(inst_sram_out[3]),
.DO4(inst_sram_out[4]),
.DO5(inst_sram_out[5]),
.DO6(inst_sram_out[6]),
.DO7(inst_sram_out[7]),
.DO8(inst_sram_out[8]),
.DO9(inst_sram_out[9]),
.DO10(inst_sram_out[10]),
.DO11(inst_sram_out[11]),
.DO12(inst_sram_out[12]),
.DO13(inst_sram_out[13]),
.DO14(inst_sram_out[14]),
.DO15(inst_sram_out[15]),
.DI0(inst_sram_in[0]),
.DI1(inst_sram_in[1]),
.DI2(inst_sram_in[2]),
.DI3(inst_sram_in[3]),
.DI4(inst_sram_in[4]),
.DI5(inst_sram_in[5]),
.DI6(inst_sram_in[6]),
.DI7(inst_sram_in[7]),
.DI8(inst_sram_in[8]),
.DI9(inst_sram_in[9]),
.DI10(inst_sram_in[10]),
.DI11(inst_sram_in[11]),
.DI12(inst_sram_in[12]),
.DI13(inst_sram_in[13]),
.DI14(inst_sram_in[14]),
.DI15(inst_sram_in[15]),
.CK(clk), .WEB(inst_sram_wr), .OE(1'b1), .CS(1'b1));



AXI4_inf_inst instruction_interface(
.clk(clk), .rst_n(rst_n),
.start(inst_dram_req),
.in_mem_id(cur_inst_dram_req_id),
.   arid_m_inf   (   arid_m_inf_inst   ),
. araddr_m_inf   ( araddr_m_inf_inst   ),
.  arlen_m_inf   (  arlen_m_inf_inst   ),
. arsize_m_inf   ( arsize_m_inf_inst   ),
.arburst_m_inf   (arburst_m_inf_inst   ),
.arvalid_m_inf   (arvalid_m_inf_inst   ),
.arready_m_inf   (arready_m_inf_inst   ),
.   rid_m_inf    (    rid_m_inf_inst    ),
. rdata_m_inf    (  rdata_m_inf_inst    ),
. rresp_m_inf    (  rresp_m_inf_inst    ),
. rlast_m_inf    (  rlast_m_inf_inst    ),
.rvalid_m_inf    ( rvalid_m_inf_inst    ),
.rready_m_inf    ( rready_m_inf_inst    ));

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_addr_forward_ID <= 'd0;
	end
	else begin
		if(DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || DATA_HAZARD_hold || MEMORY_ACCESS_hold) begin
			inst_addr_forward_ID <= inst_addr_forward_ID;
		end
		else begin
			inst_addr_forward_ID <= cur_inst_addr;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		null_inst <= 'd0;
	end
	else begin
		if(INST_DRAM_hold || DATA_DRAM_hold) begin
			null_inst <= 'd1;
		end
		else begin
			null_inst <= 'd0;
		end
	end
end

//####################################################
//               	Inst Fetch
//####################################################
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		instruction_store_for_hold[15:13] <= NULL_INST_TYPE;
		instruction_store_for_hold[12:0]  <= 'd0;
	end
	else begin
		if(INST_DRAM_hold) begin
			instruction_store_for_hold[15:13] <= NULL_INST_TYPE;
			instruction_store_for_hold[12:0]  <= 'd0;
		end
		else if(System_hold && !hold_delay) begin
			instruction_store_for_hold <= instruction;
		end
		else begin
			instruction_store_for_hold <= instruction_store_for_hold;
		end
	end
end

always @ * begin
	if(run_first_inst_forward_ID) begin
		instruction = inst_sram_out;
	end
	else if(hold_delay && !System_hold) begin
		instruction = instruction_store_for_hold;
	end
	else if(null_inst || wash || wash_delay) begin
		instruction[15:13] = NULL_INST_TYPE;
		instruction[12:0] = 'd0;		
	end
	else begin
		instruction = inst_sram_out;
	end
	
	inst_type = instruction[15:13];
	rt_addr   = instruction[8:5];
	rd_addr   = instruction[4:1];
	rs_addr   = instruction[12:9];
	immediate = instruction[4:0];
	coef_b    = instruction[8:0];
	coef_a    = instruction[12:9];
	func      = instruction[0];
end

always @ * begin
	case(rs_addr)
		'd0	:	rs_data_next = core_r0 ;
		'd1	:	rs_data_next = core_r1 ;
		'd2	:	rs_data_next = core_r2 ;
		'd3	:	rs_data_next = core_r3 ;
		'd4	:	rs_data_next = core_r4 ;
		'd5	:	rs_data_next = core_r5 ;
		'd6	:	rs_data_next = core_r6 ;
		'd7	:	rs_data_next = core_r7 ;
		'd8	:	rs_data_next = core_r8 ;
		'd9	:	rs_data_next = core_r9 ;
		'd10:	rs_data_next = core_r10;
		'd11:	rs_data_next = core_r11;
		'd12:	rs_data_next = core_r12;
		'd13:	rs_data_next = core_r13;
		'd14:	rs_data_next = core_r14;
		'd15:	rs_data_next = core_r15;
	endcase
	
	case(rt_addr)
		'd0	:	rt_data_next = core_r0 ;
		'd1	:	rt_data_next = core_r1 ;
		'd2	:	rt_data_next = core_r2 ;
		'd3	:	rt_data_next = core_r3 ;
		'd4	:	rt_data_next = core_r4 ;
		'd5	:	rt_data_next = core_r5 ;
		'd6	:	rt_data_next = core_r6 ;
		'd7	:	rt_data_next = core_r7 ;
		'd8	:	rt_data_next = core_r8 ;
		'd9	:	rt_data_next = core_r9 ;
		'd10:	rt_data_next = core_r10;
		'd11:	rt_data_next = core_r11;
		'd12:	rt_data_next = core_r12;
		'd13:	rt_data_next = core_r13;
		'd14:	rt_data_next = core_r14;
		'd15:	rt_data_next = core_r15;
	endcase
	
	if(rs_addr == save_reg_addr_WB && (inst_type_forward_WB != NULL_INST_TYPE && inst_type_forward_WB != 3'b011 && inst_type_forward_WB != 3'b100)) begin
		rs_data_next = data_WB;
	end
	
	if(rt_addr == save_reg_addr_WB && (inst_type_forward_WB != NULL_INST_TYPE && inst_type_forward_WB != 3'b011 && inst_type_forward_WB != 3'b100)) begin
		rt_data_next = data_WB;
	end
	
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rt_data <= 'd0;
	end
	else begin
		if(run_first_inst_forward_ID) begin
			rt_data <= rt_data_next;
		end
		else if(DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || MEMORY_ACCESS_hold || DATA_HAZARD_CHECK) begin
			rt_data <= rt_data_final;
		end
		else begin
			rt_data <= rt_data_next;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rs_data <= 'd0;
	end
	else begin
		if(run_first_inst_forward_ID) begin
			rs_data <= rs_data_next;
		end
		else if(DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || MEMORY_ACCESS_hold || DATA_HAZARD_CHECK) begin
			rs_data <= rs_data_final;
		end
		else begin
			rs_data <= rs_data_next;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rs_addr_forward_EXE <= 'd0;
	end
	else begin
		if(run_first_inst_forward_ID) begin
			rs_addr_forward_EXE <= rs_addr;
		end
		else if(DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || DATA_HAZARD_hold || MEMORY_ACCESS_hold) begin
			rs_addr_forward_EXE <= rs_addr_forward_EXE;
		end
		else begin
			rs_addr_forward_EXE <= rs_addr;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rt_addr_forward_EXE <= 'd0;
	end
	else begin
		if(run_first_inst_forward_ID) begin
			rt_addr_forward_EXE <= rt_addr;
		end
		else if(DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || DATA_HAZARD_hold || MEMORY_ACCESS_hold) begin
			rt_addr_forward_EXE <= rt_addr_forward_EXE;
		end
		else begin
			rt_addr_forward_EXE <= rt_addr;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rd_addr_forward_EXE <= 'd0;
	end
	else begin
		if(run_first_inst_forward_ID) begin
			rd_addr_forward_EXE <= rd_addr;
		end
		else if(DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || DATA_HAZARD_hold || MEMORY_ACCESS_hold) begin
			rd_addr_forward_EXE <= rd_addr_forward_EXE;
		end
		else begin
			rd_addr_forward_EXE <= rd_addr;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		immediate_forward <= 'd0;
	end
	else begin
		// sign extend
		if(run_first_inst_forward_ID) begin
			if(immediate[4]) begin
				immediate_forward <= {11'b11111111111, immediate};
			end
			else begin
				immediate_forward <= {11'b00000000000, immediate};
			end
		end
		else if(DATA_DRAM_hold || INST_DRAM_hold || Calc_Determinant_hold || DATA_HAZARD_hold || MEMORY_ACCESS_hold) begin
			immediate_forward <= immediate_forward;
		end
		else begin
			if(immediate[4]) begin
				immediate_forward <= {11'b11111111111, immediate};
			end
			else begin
				immediate_forward <= {11'b00000000000, immediate};
			end
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_type_forward_EXE <= NULL_INST_TYPE;
	end
	else begin
		if(run_first_inst_forward_ID) begin
			inst_type_forward_EXE <= inst_type;
		end
		else if(System_hold && !run_first_inst_forward_EXE) begin
			inst_type_forward_EXE <= inst_type_forward_EXE;
		end
		else if(wash) begin
			inst_type_forward_EXE <= NULL_INST_TYPE;
		end
		else begin
			inst_type_forward_EXE <= inst_type;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_addr_forward_EXE <= 'd0;
	end
	else begin
		if(System_hold) begin
			inst_addr_forward_EXE <= inst_addr_forward_EXE;
		end
		else begin
			inst_addr_forward_EXE <= inst_addr_forward_ID;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		run_first_inst_forward_EXE <= 'd0;
	end
	else begin
		run_first_inst_forward_EXE <= run_first_inst_forward_ID;
	end
end

//####################################################
//               		EXE
//####################################################
assign show_function_bit = immediate[0];
// forwarding unit
always @ * begin
	if(|DATA_HAZARD_CHECK) begin
		DATA_HAZARD_hold = 'd1;
	end
	else begin
		DATA_HAZARD_hold = 'd0;
	end
end

always @ * begin
rs_data_final = rs_data;
rt_data_final = rt_data;
core_r0_final = core_r0;
core_r1_final = core_r1;
core_r2_final = core_r2;
core_r3_final = core_r3;
core_r4_final = core_r4;
core_r5_final = core_r5;
core_r6_final = core_r6;
core_r7_final = core_r7;
core_r8_final = core_r8;
core_r9_final = core_r9;
core_r10_final = core_r10;
core_r11_final = core_r11;
core_r12_final = core_r12;
core_r13_final = core_r13;
core_r14_final = core_r14;
core_r15_final = core_r15;
	case(inst_type_forward_WB)
		3'b000,
		3'b001	:	begin
						if(rs_addr_forward_EXE == save_reg_addr_WB)	begin
							rs_data_final = ALU_out_forward_WB;
						end
						if(rt_addr_forward_EXE == save_reg_addr_WB)	begin
							rt_data_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd0)	begin
							core_r0_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd1)	begin
							core_r1_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd2)	begin
							core_r2_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd3)	begin
							core_r3_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd4)	begin
							core_r4_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd5)	begin
							core_r5_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd6)	begin
							core_r6_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd7)	begin
							core_r7_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd8)	begin
							core_r8_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd9)	begin
							core_r9_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd10)	begin
							core_r10_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd11)	begin
							core_r11_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd12)	begin
							core_r12_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd13)	begin
							core_r13_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd14)	begin
							core_r14_final = ALU_out_forward_WB;
						end
						if(save_reg_addr_WB == 'd15)	begin
							core_r15_final = ALU_out_forward_WB;
						end
					end
		3'b111	:	begin
						if(rt_addr_forward_EXE == 'd0) begin
							rt_data_final = ALU_out_forward_WB;
						end
						if(rs_addr_forward_EXE == 'd0) begin
							rs_data_final = ALU_out_forward_WB;
						end
						core_r0_final = ALU_out_forward_WB;
					end
		3'b010	:	begin
						if(rs_addr_forward_EXE == save_reg_addr_WB)	begin
							rs_data_final = data_sram_out;
						end
						if(rt_addr_forward_EXE == save_reg_addr_WB)	begin
							rt_data_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd0)	begin
							core_r0_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd1)	begin
							core_r1_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd2)	begin
							core_r2_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd3)	begin
							core_r3_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd4)	begin
							core_r4_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd5)	begin
							core_r5_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd6)	begin
							core_r6_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd7)	begin
							core_r7_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd8)	begin
							core_r8_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd9)	begin
							core_r9_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd10)	begin
							core_r10_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd11)	begin
							core_r11_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd12)	begin
							core_r12_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd13)	begin
							core_r13_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd14)	begin
							core_r14_final = data_sram_out;
						end
						if(save_reg_addr_WB == 'd15)	begin
							core_r15_final = data_sram_out;
						end
					end
	endcase
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && rs_addr_forward_EXE == save_reg_addr_MA) begin
		rs_data_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b111 && rs_addr_forward_EXE == 'd0)) begin
		rs_data_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && rs_addr_forward_EXE == save_reg_addr_MA)) begin
		rs_data_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && rt_addr_forward_EXE == save_reg_addr_MA) begin
		rt_data_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b111 && rt_addr_forward_EXE == 'd0)) begin
		rt_data_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && rt_addr_forward_EXE == save_reg_addr_MA)) begin
		rt_data_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd0) begin
		core_r0_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b111)) begin
		core_r0_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r0_final == 'd0)) begin
		core_r0_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd1) begin
		core_r1_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd1)) begin
		core_r1_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd2) begin
		core_r2_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r2_final == 'd2)) begin
		core_r2_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd3) begin
		core_r3_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd3)) begin
		core_r3_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd4) begin
		core_r4_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd4)) begin
		core_r4_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd5) begin
		core_r5_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd5)) begin
		core_r5_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd6) begin
		core_r6_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd6)) begin
		core_r6_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd7) begin
		core_r7_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd7)) begin
		core_r7_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd8) begin
		core_r8_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd8)) begin
		core_r8_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd9) begin
		core_r9_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd9)) begin
		core_r9_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd10) begin
		core_r10_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd10)) begin
		core_r10_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd11) begin
		core_r11_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd11)) begin
		core_r11_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd12) begin
		core_r12_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd12)) begin
		core_r12_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd13) begin
		core_r13_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd13)) begin
		core_r13_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd14) begin
		core_r14_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd14)) begin
		core_r14_final = data_sram_out;
	end
	
	if((inst_type_forward_MA == 3'b000 || inst_type_forward_MA == 3'b001) && save_reg_addr_MA == 'd15) begin
		core_r15_final = ALU_out_forward_MA;
	end
	if((inst_type_forward_MA == 3'b010 && DATA_HAZARD_hold && core_r1_final == 'd15)) begin
		core_r15_final = data_sram_out;
	end
DATA_HAZARD_CHECK = 'd0;
	if(inst_type_forward_MA == 3'b010) begin
		if(rs_addr_forward_EXE == save_reg_addr_MA) begin
			if(inst_type_forward_EXE == 3'b000 || inst_type_forward_EXE == 3'b001 || inst_type_forward_EXE == 3'b010 || inst_type_forward_EXE == 3'b011 || inst_type_forward_EXE == 3'b100) begin
				DATA_HAZARD_CHECK[0] = 'b1;
			end
		end
		if(rt_addr_forward_EXE == save_reg_addr_MA) begin
			if(inst_type_forward_EXE == 3'b000 || inst_type_forward_EXE == 3'b001 || inst_type_forward_EXE == 3'b011 || inst_type_forward_EXE == 3'b100) begin
				DATA_HAZARD_CHECK[1] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd0) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[2] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd1) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[3] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd2) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[4] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd3) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[5] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd4) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[6] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd5) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[7] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd6) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[8] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd7) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[9] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd8) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[10] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd9) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[11] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd10) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[12] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd11) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[13] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd12) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[14] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd13) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[15] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd14) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[16] = 'b1;
			end
		end
		if(save_reg_addr_MA == 'd15) begin
			if(inst_type_forward_EXE == 3'b111) begin
				DATA_HAZARD_CHECK[17] = 'b1;
			end
		end
	end
end

assign Sub_out = rs_data_final - rt_data_final;

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Determiant_cycle <= 'd0;
	end
	else begin
		if(MEMORY_ACCESS_hold || DATA_HAZARD_hold) begin
			Determiant_cycle <= Determiant_cycle;
		end
		else if(inst_type_forward_EXE == 3'b111) begin
			if(Determiant_cycle == 'd6) begin
				Determiant_cycle <= 'd0;
			end
			else begin
				Determiant_cycle <= Determiant_cycle + 'd1;
			end
		end
		else begin
			Determiant_cycle <= 'd0;
		end
	end
end

always @ * begin
Mult_in_16b[0][0] = 'd0;
Mult_in_16b[0][1] = 'd0;
Mult_in_16b[1][0] = 'd0;
Mult_in_16b[1][1] = 'd0;
Mult_in_16b[2][0] = 'd0;
Mult_in_16b[2][1] = 'd0;
Mult_in_16b[3][0] = 'd0;
Mult_in_16b[3][1] = 'd0;
Mult_in_16b[4][0] = 'd0;
Mult_in_16b[4][1] = 'd0;
Mult_in_16b[5][0] = 'd0;
Mult_in_16b[5][1] = 'd0;
Mult_in_32b[0][0] = 'd0;
Mult_in_32b[0][1] = 'd0;
Mult_in_32b[1][0] = 'd0;
Mult_in_32b[1][1] = 'd0;
Mult_in_32b[2][0] = 'd0;
Mult_in_32b[2][1] = 'd0;
Mult_in_32b[3][0] = 'd0;
Mult_in_32b[3][1] = 'd0;
Mult_in_32b[4][0] = 'd0;
Mult_in_32b[4][1] = 'd0;
Mult_in_32b[5][0] = 'd0;
Mult_in_32b[5][1] = 'd0;
	if(inst_type_forward_EXE != 3'b111) begin
		Mult_in_16b[0][0] = rs_data_final;
		Mult_in_16b[0][1] = rt_data_final;
	end
	else begin
		// Determinant
		case(Determiant_cycle)
			'd0	:	begin
						Mult_in_16b[0][0] = core_r0_final;
						Mult_in_16b[0][1] = core_r5_final;
						Mult_in_16b[1][0] = core_r0_final;
						Mult_in_16b[1][1] = core_r6_final;
						Mult_in_16b[2][0] = core_r0_final;
						Mult_in_16b[2][1] = core_r7_final;
						
						Mult_in_16b[3][0] = core_r4_final;
						Mult_in_16b[3][1] = core_r1_final;
						Mult_in_16b[4][0] = core_r4_final;
						Mult_in_16b[4][1] = core_r2_final;
						Mult_in_16b[5][0] = core_r4_final;
						Mult_in_16b[5][1] = core_r3_final;
					end
			'd1	:	begin
						Mult_in_16b[0][0] = core_r10_final; // a33
						Mult_in_16b[0][1] = core_r15_final; // a44
						Mult_in_16b[1][0] = core_r11_final; // a34
						Mult_in_16b[1][1] = core_r14_final; // a43
						Mult_in_16b[2][0] = core_r11_final; // a34
						Mult_in_16b[2][1] = core_r13_final; // a42
						                
						Mult_in_16b[3][0] = core_r9_final ; // a32
						Mult_in_16b[3][1] = core_r15_final; // a44
						Mult_in_16b[4][0] = core_r9_final ; // a32
						Mult_in_16b[4][1] = core_r14_final; // a43
						Mult_in_16b[5][0] = core_r10_final; // a33
						Mult_in_16b[5][1] = core_r13_final; // a42
					end
			'd2	:	begin
						Mult_in_16b[0][0] = core_r8_final;
						Mult_in_16b[0][1] = core_r13_final;
						Mult_in_16b[1][0] = core_r8_final;
						Mult_in_16b[1][1] = core_r14_final;
						Mult_in_16b[2][0] = core_r8_final;
						Mult_in_16b[2][1] = core_r15_final;
						                
						Mult_in_16b[3][0] = core_r12_final;
						Mult_in_16b[3][1] = core_r9_final;
						Mult_in_16b[4][0] = core_r12_final;
						Mult_in_16b[4][1] = core_r10_final;
						Mult_in_16b[5][0] = core_r12_final;
						Mult_in_16b[5][1] = core_r11_final;
					end
			'd3	:	begin
						Mult_in_16b[0][0] = core_r2_final; // a13
						Mult_in_16b[0][1] = core_r7_final; // a24	
						Mult_in_16b[1][0] = core_r3_final; // a14
						Mult_in_16b[1][1] = core_r6_final; // a23	
						Mult_in_16b[2][0] = core_r3_final; // a14
						Mult_in_16b[2][1] = core_r5_final; // a22
						                                
						Mult_in_16b[3][0] = core_r1_final; // a12
						Mult_in_16b[3][1] = core_r7_final; // a24	
						Mult_in_16b[4][0] = core_r1_final; // a12
						Mult_in_16b[4][1] = core_r6_final; // a23	
						Mult_in_16b[5][0] = core_r2_final; // a13
						Mult_in_16b[5][1] = core_r5_final; // a22
					end
		endcase
		case(Determiant_cycle)
			'd2	:	begin
						Mult_in_32b[0][0] = Determinant_tmp_16b[0];
						Mult_in_32b[0][1] = Determinant_tmp_16b[6];
						Mult_in_32b[1][0] = Determinant_tmp_16b[0]; 
						Mult_in_32b[1][1] = Determinant_tmp_16b[7];
						Mult_in_32b[2][0] = Determinant_tmp_16b[1];
						Mult_in_32b[2][1] = Determinant_tmp_16b[8];					
						Mult_in_32b[3][0] = Determinant_tmp_16b[1];
						Mult_in_32b[3][1] = Determinant_tmp_16b[9];
						Mult_in_32b[4][0] = Determinant_tmp_16b[2];
						Mult_in_32b[4][1] = Determinant_tmp_16b[10];
						Mult_in_32b[5][0] = Determinant_tmp_16b[2];
						Mult_in_32b[5][1] = Determinant_tmp_16b[11];
					end
			'd3	:	begin
						Mult_in_32b[0][0] = Determinant_tmp_16b[3];
						Mult_in_32b[0][1] = Determinant_tmp_16b[7];
						Mult_in_32b[1][0] = Determinant_tmp_16b[3];
						Mult_in_32b[1][1] = Determinant_tmp_16b[6];
						Mult_in_32b[2][0] = Determinant_tmp_16b[4];
						Mult_in_32b[2][1] = Determinant_tmp_16b[9];					                
						Mult_in_32b[3][0] = Determinant_tmp_16b[4];
						Mult_in_32b[3][1] = Determinant_tmp_16b[8];
						Mult_in_32b[4][0] = Determinant_tmp_16b[5];
						Mult_in_32b[4][1] = Determinant_tmp_16b[11];
						Mult_in_32b[5][0] = Determinant_tmp_16b[5];
						Mult_in_32b[5][1] = Determinant_tmp_16b[10];
					end
			'd4	:	begin
						Mult_in_32b[0][0] = Determinant_tmp_16b[12];
						Mult_in_32b[0][1] = Determinant_tmp_16b[0];
						Mult_in_32b[1][0] = Determinant_tmp_16b[12];
						Mult_in_32b[1][1] = Determinant_tmp_16b[1];
						Mult_in_32b[2][0] = Determinant_tmp_16b[13];
						Mult_in_32b[2][1] = Determinant_tmp_16b[2];					                
						Mult_in_32b[3][0] = Determinant_tmp_16b[13];
						Mult_in_32b[3][1] = Determinant_tmp_16b[3];
						Mult_in_32b[4][0] = Determinant_tmp_16b[14];
						Mult_in_32b[4][1] = Determinant_tmp_16b[4];
						Mult_in_32b[5][0] = Determinant_tmp_16b[14];
						Mult_in_32b[5][1] = Determinant_tmp_16b[5];
					end
			'd5	:	begin
						Mult_in_32b[0][0] = Determinant_tmp_16b[15];
						Mult_in_32b[0][1] = Determinant_tmp_16b[1];	
						Mult_in_32b[1][0] = Determinant_tmp_16b[15];
						Mult_in_32b[1][1] = Determinant_tmp_16b[0];	
						Mult_in_32b[2][0] = Determinant_tmp_16b[16];
						Mult_in_32b[2][1] = Determinant_tmp_16b[3];						                                
						Mult_in_32b[3][0] = Determinant_tmp_16b[16];
						Mult_in_32b[3][1] = Determinant_tmp_16b[2];	
						Mult_in_32b[4][0] = Determinant_tmp_16b[17];
						Mult_in_32b[4][1] = Determinant_tmp_16b[5];	
						Mult_in_32b[5][0] = Determinant_tmp_16b[17];
						Mult_in_32b[5][1] = Determinant_tmp_16b[4];
					end
		endcase
		/*
		if(Determiant_cycle == 'd0) begin
			Mult_in[0][0] = core_r0_final;
			Mult_in[0][1] = core_r5_final;
			Mult_in[1][0] = core_r0_final;
			Mult_in[1][1] = core_r6_final;
			Mult_in[2][0] = core_r0_final;
			Mult_in[2][1] = core_r7_final;
			
			Mult_in[3][0] = core_r4_final;
			Mult_in[3][1] = core_r1_final;
			Mult_in[4][0] = core_r4_final;
			Mult_in[4][1] = core_r2_final;
			Mult_in[5][0] = core_r4_final;
			Mult_in[5][1] = core_r3_final;
			
			Mult_in[6][0] = core_r8_final;
			Mult_in[6][1] = core_r13_final;
			Mult_in[7][0] = core_r8_final;
			Mult_in[7][1] = core_r14_final;
			Mult_in[8][0] = core_r8_final;
			Mult_in[8][1] = core_r15_final;
			
			Mult_in[9][0]  = core_r12_final;
			Mult_in[9][1]  = core_r9_final;
			Mult_in[10][0] = core_r12_final;
			Mult_in[10][1] = core_r10_final;
			Mult_in[11][0] = core_r12_final;
			Mult_in[11][1] = core_r11_final;
			
			Mult_in[12][0] = core_r10_final; // a33 
			Mult_in[12][1] = core_r15_final; // a44 			                                        
			Mult_in[13][0] = core_r11_final; // a34 
			Mult_in[13][1] = core_r14_final; // a43 			                                        
			Mult_in[14][0] = core_r11_final; // a34 
			Mult_in[14][1] = core_r13_final; // a42 
			
			Mult_in[15][0] = core_r9_final ; // a32 
			Mult_in[15][1] = core_r15_final; // a44 											
			Mult_in[16][0] = core_r9_final ; // a32 
			Mult_in[16][1] = core_r14_final; // a43 			                                        
			Mult_in[17][0] = core_r10_final; // a33 
			Mult_in[17][1] = core_r13_final; // a42 
			
			Mult_in[18][0] = core_r2_final; // a13
			Mult_in[18][1] = core_r7_final; // a24			                                 
			Mult_in[19][0] = core_r3_final; // a14
			Mult_in[19][1] = core_r6_final; // a23			                                 
			Mult_in[20][0] = core_r3_final; // a14
			Mult_in[20][1] = core_r5_final; // a22
			                                 
			Mult_in[21][0] = core_r1_final; // a12
			Mult_in[21][1] = core_r7_final; // a24			                                 
			Mult_in[22][0] = core_r1_final; // a12
			Mult_in[22][1] = core_r6_final; // a23			                                 
			Mult_in[23][0] = core_r2_final; // a13
			Mult_in[23][1] = core_r5_final; // a22
		end
		else if(Determiant_cycle == 'd1) begin
			Mult_in[0][0] = Determinant_tmp[0];
			Mult_in[0][1] = Determinant_tmp[12];
			Mult_in[1][0] = Determinant_tmp[0]; 
			Mult_in[1][1] = Determinant_tmp[13]; 
			Mult_in[2][0] = Determinant_tmp[1];
			Mult_in[2][1] = Determinant_tmp[14];
			Mult_in[3][0] = Determinant_tmp[1];
			Mult_in[3][1] = Determinant_tmp[15];
			Mult_in[4][0] = Determinant_tmp[2];
			Mult_in[4][1] = Determinant_tmp[16];
			Mult_in[5][0] = Determinant_tmp[2];
			Mult_in[5][1] = Determinant_tmp[17];
			
			Mult_in[6][0]  = Determinant_tmp[3];
			Mult_in[6][1]  = Determinant_tmp[13];
			Mult_in[7][0]  = Determinant_tmp[3];
			Mult_in[7][1]  = Determinant_tmp[12];
			Mult_in[8][0]  = Determinant_tmp[4];
			Mult_in[8][1]  = Determinant_tmp[15];
			Mult_in[9][0]  = Determinant_tmp[4];
			Mult_in[9][1]  = Determinant_tmp[14];
			Mult_in[10][0] = Determinant_tmp[5];
			Mult_in[10][1] = Determinant_tmp[17];
			Mult_in[11][0] = Determinant_tmp[5];
			Mult_in[11][1] = Determinant_tmp[16];
			
			Mult_in[12][0] = Determinant_tmp[6];
			Mult_in[12][1] = Determinant_tmp[18];
			Mult_in[13][0] = Determinant_tmp[6];
			Mult_in[13][1] = Determinant_tmp[19];
			Mult_in[14][0] = Determinant_tmp[7];
			Mult_in[14][1] = Determinant_tmp[20];
			Mult_in[15][0] = Determinant_tmp[7];
			Mult_in[15][1] = Determinant_tmp[21];
			Mult_in[16][0] = Determinant_tmp[8];
			Mult_in[16][1] = Determinant_tmp[22];
			Mult_in[17][0] = Determinant_tmp[8];
			Mult_in[17][1] = Determinant_tmp[23];
			
			Mult_in[18][0] = Determinant_tmp[9];
			Mult_in[18][1] = Determinant_tmp[19];
			Mult_in[19][0] = Determinant_tmp[9];
			Mult_in[19][1] = Determinant_tmp[18];
			Mult_in[20][0] = Determinant_tmp[10];
			Mult_in[20][1] = Determinant_tmp[21];
			Mult_in[21][0] = Determinant_tmp[10];
			Mult_in[21][1] = Determinant_tmp[20];
			Mult_in[22][0] = Determinant_tmp[11];
			Mult_in[22][1] = Determinant_tmp[23];
			Mult_in[23][0] = Determinant_tmp[11];
			Mult_in[23][1] = Determinant_tmp[22];
		end
		*/
	end
	Mult_out_16b[0 ] = Mult_in_16b[0 ][0] * Mult_in_16b[0 ][1];
	Mult_out_16b[1 ] = Mult_in_16b[1 ][0] * Mult_in_16b[1 ][1];
	Mult_out_16b[2 ] = Mult_in_16b[2 ][0] * Mult_in_16b[2 ][1];
	Mult_out_16b[3 ] = Mult_in_16b[3 ][0] * Mult_in_16b[3 ][1];
	Mult_out_16b[4 ] = Mult_in_16b[4 ][0] * Mult_in_16b[4 ][1];
	Mult_out_16b[5 ] = Mult_in_16b[5 ][0] * Mult_in_16b[5 ][1];
	
	Mult_out_32b[0 ] = Mult_in_32b[0 ][0] * Mult_in_32b[0 ][1];
	Mult_out_32b[1 ] = Mult_in_32b[1 ][0] * Mult_in_32b[1 ][1];
	Mult_out_32b[2 ] = Mult_in_32b[2 ][0] * Mult_in_32b[2 ][1];
	Mult_out_32b[3 ] = Mult_in_32b[3 ][0] * Mult_in_32b[3 ][1];
	Mult_out_32b[4 ] = Mult_in_32b[4 ][0] * Mult_in_32b[4 ][1];
	Mult_out_32b[5 ] = Mult_in_32b[5 ][0] * Mult_in_32b[5 ][1];
end


reg [68:0] tmp1;
reg signed [68:0] tmp3;
reg [8:0] tmp2;
assign Upper_bound = 'd32767;
assign Lower_bound = -'d32768;
always @ * begin
	Determinant_tmp_add_next = 	Determinant_tmp_32b[0] - Determinant_tmp_32b[1] + Determinant_tmp_32b[2] - Determinant_tmp_32b[3] + 
								Determinant_tmp_32b[4] - Determinant_tmp_32b[5] + Determinant_tmp_add;
	/*
	Determinant_tmp_add[0] = Determinant_tmp[0] - Determinant_tmp[1] + Determinant_tmp[2] - Determinant_tmp[3] + 
						     Determinant_tmp[4] - Determinant_tmp[5] + Determinant_tmp[6] - Determinant_tmp[7] + 
						     Determinant_tmp[8] - Determinant_tmp[9] + Determinant_tmp[10] - Determinant_tmp[11]; 
	Determinant_tmp_add[1] = Determinant_tmp[12] - Determinant_tmp[13] + Determinant_tmp[14] - Determinant_tmp[15] + 
						     Determinant_tmp[16] - Determinant_tmp[17] + Determinant_tmp[18] - Determinant_tmp[19] + 
						     Determinant_tmp[20] - Determinant_tmp[21] + Determinant_tmp[22] - Determinant_tmp[23]; 
	*/
	
	/*Determinant_tmp_sub = Determinant_tmp[8] + Determinant_tmp[9] + Determinant_tmp[10] + Determinant_tmp[11] + 
						  Determinant_tmp[12] + Determinant_tmp[13] + Determinant_tmp[14] + Determinant_tmp[15]; 
	*/
	//tmp3 = $signed(Determinant_tmp_add[0] + Determinant_tmp_add[1]);
	tmp1 = (Determinant_tmp_add_next >>> {rs_addr_forward_EXE, 1'b0});
	tmp2 = {rt_addr_forward_EXE, immediate_forward[4:0]};
	Determinant_final = $signed(tmp1 + tmp2);
	if(Determinant_final > Upper_bound)
		Determinant_final_clip = Upper_bound;
	else if(Determinant_final < Lower_bound)
		Determinant_final_clip = Lower_bound;
	else
		Determinant_final_clip = Determinant_final[15:0];
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		Determinant_tmp_add <= 'd0;
	end
	else begin
		if(Calc_Determinant_hold) begin
			Determinant_tmp_add <= Determinant_tmp_add_next;
		end
		else begin
			Determinant_tmp_add <= 'd0;
		end
	end
end

generate
	for(i=0;i<6;i=i+1) begin: Determinant_16b_first_temp_result
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				Determinant_tmp_16b[i] <= 'd0;
			end
			else begin
				if(Calc_Determinant_hold) begin
					if(Determiant_cycle == 'd0 || Determiant_cycle == 'd3) begin
						Determinant_tmp_16b[i] <= Mult_out_16b[i];
					end
					else begin
						Determinant_tmp_16b[i] <= Determinant_tmp_16b[i];
					end
				end
				else begin
					Determinant_tmp_16b[i] <= 'd0;
				end
			end
		end
	end
	for(i=0;i<6;i=i+1) begin: Determinant_16b_second_temp_result
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				Determinant_tmp_16b[i+6] <= 'd0;
			end
			else begin
				if(Calc_Determinant_hold) begin
					if(Determiant_cycle == 'd1) begin
						Determinant_tmp_16b[i+6] <= Mult_out_16b[i];
					end
					else begin
						Determinant_tmp_16b[i+6] <= Determinant_tmp_16b[i+6];
					end
				end
				else begin
					Determinant_tmp_16b[i+6] <= 'd0;				
				end
			end
		end
	end
	for(i=0;i<6;i=i+1) begin: Determinant_16b_third_temp_result
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				Determinant_tmp_16b[i+12] <= 'd0;
			end
			else begin
				if(Calc_Determinant_hold) begin
					if(Determiant_cycle == 'd2) begin
						Determinant_tmp_16b[i+12] <= Mult_out_16b[i];
					end
					else begin
						Determinant_tmp_16b[i+12] <= Determinant_tmp_16b[i+12];
					end
				end
				else begin
					Determinant_tmp_16b[i+12] <= 'd0;	
				end
			end
		end
	end
	for(i=0;i<6;i=i+1) begin: Determinant_32b_first_temp_result
		always @ (posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				Determinant_tmp_32b[i] <= 'd0;
			end
			else begin
				if(Calc_Determinant_hold) begin
					Determinant_tmp_32b[i] <= Mult_out_32b[i];
				end
				else begin
					Determinant_tmp_32b[i] <= 'd0;
				end
			end
		end
	end
endgenerate

always @ * begin
	Calc_Determinant_hold = (inst_type_forward_EXE == 3'b111 && Determiant_cycle != 'd6); 
end

always @ * begin
	case({inst_type_forward_EXE, immediate_forward[0]})
		4'b0000	:	ALU_out = rs_data_final + rt_data_final;
		4'b0100,
		4'b0101,
		4'b0110,
		4'b0111	:	ALU_out = rs_data_final + immediate_forward;
		4'b0001	:	ALU_out = Sub_out;
		4'b0010	:	begin
						if(rs_data_final < rt_data_final) begin
							ALU_out = 'd1;
						end
						else begin
							ALU_out = 'd0;
						end
					end
		4'b0011	:	begin
						/*
						if(Mult_out_16b[0] < Lower_bound) begin
							ALU_out = Lower_bound;
						end
						else if(Mult_out_16b[0] > Upper_bound) begin
							ALU_out = Upper_bound;
						end
						else begin
							ALU_out = Mult_out_16b[0];
						end
						*/
						ALU_out = Mult_out_16b[0];
					end
		4'b1000,
		4'b1001	:	ALU_out = $signed(inst_addr_forward_EXE + immediate_forward);
		4'b1110,
		4'b1111	:	begin
						if(Determiant_cycle == 'd6) begin
							ALU_out = Determinant_final_clip;
						end
						else begin
							ALU_out = 'd0;
						end
					end
		default	:	ALU_out = 'd0;
	endcase
end

// BRANCH
always @ * begin
wash = 1'b0;
	if(inst_type_forward_EXE == 3'b100 && !(DATA_HAZARD_hold) && (rt_data_final == rs_data_final)) begin
		wash = 1'b1;
	end

	if(inst_type_forward_EXE == 3'b100) begin
		if(rt_data_final == rs_data_final) begin
			Inst_addr_before_add = ALU_out;
		end
		else begin
			Inst_addr_before_add = cur_inst_addr;
		end
	end
	else begin
		Inst_addr_before_add = cur_inst_addr;
	end
	
	cur_inst_addr_next = Inst_addr_before_add + 'd1;
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		wash_delay <= 'd0;
	end
	else begin
		wash_delay <= wash;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_type_forward_MA <= NULL_INST_TYPE;
	end
	else begin
		if(run_first_inst_forward_EXE) begin
			inst_type_forward_MA <= inst_type_forward_EXE;
		end
		else if((DATA_DRAM_hold || INST_DRAM_hold || MEMORY_ACCESS_hold) && !run_first_inst_forward_MA) begin
			inst_type_forward_MA <= inst_type_forward_MA;
		end
		else if(Calc_Determinant_hold || DATA_HAZARD_hold) begin
			inst_type_forward_MA <= NULL_INST_TYPE;
		end
		else begin
			inst_type_forward_MA <= inst_type_forward_EXE;
		end
	end
end


always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		save_reg_addr_MA <= 'd0;
	end
	else begin
		if(run_first_inst_forward_EXE) begin
			case(inst_type_forward_EXE)
				3'b000,
				3'b001	:	save_reg_addr_MA <= rd_addr_forward_EXE;
				3'b010,
				3'b011	:	save_reg_addr_MA <= rt_addr_forward_EXE;
				3'b111	:	save_reg_addr_MA <= 'd0;
				default :	save_reg_addr_MA <= 'd0;
			endcase
		end
		else if(MEMORY_ACCESS_hold || DATA_DRAM_hold || INST_DRAM_hold) begin
			save_reg_addr_MA <= save_reg_addr_MA;
		end
		else begin
			case(inst_type_forward_EXE)
				3'b000,
				3'b001	:	save_reg_addr_MA <= rd_addr_forward_EXE;
				3'b010,
				3'b011	:	save_reg_addr_MA <= rt_addr_forward_EXE;
				3'b111	:	save_reg_addr_MA <= 'd0;
				default :	save_reg_addr_MA <= 'd0;
			endcase
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rt_data_forward_MA <= 'd0;
	end
	else begin
		if(run_first_inst_forward_EXE) begin
			rt_data_forward_MA <= rt_data_final;
		end
		else if(MEMORY_ACCESS_hold || DATA_DRAM_hold || INST_DRAM_hold) begin
			rt_data_forward_MA <= rt_data_forward_MA;
		end
		else begin
			rt_data_forward_MA <= rt_data_final;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		ALU_out_forward_MA <= 'd0;
	end
	else begin
		if(run_first_inst_forward_EXE) begin
			ALU_out_forward_MA <= ALU_out;
		end
		else if(MEMORY_ACCESS_hold || DATA_DRAM_hold || INST_DRAM_hold) begin
			ALU_out_forward_MA <= ALU_out_forward_MA;
		end
		else begin
			ALU_out_forward_MA <= ALU_out;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		run_first_inst_forward_MA <= 'd0;
	end
	else begin
		run_first_inst_forward_MA <= run_first_inst_forward_EXE;
	end
end

//####################################################
//               Memory Access
//####################################################
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cur_data_dram_req_id <= 'd0;
	end
	else begin
		if(rlast_m_inf_data && rready_m_inf_data && rvalid_m_inf_data) begin
			cur_data_dram_req_id <= cur_data_dram_req_id + 'd1;
		end
		else begin
			cur_data_dram_req_id <= cur_data_dram_req_id;
		end
	end
end

assign DATA_DRAM_hold = (!data_dram_finish_read);

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		data_dram_finish_read <= 'd0;
	end
	else begin
		if(cur_data_dram_req_id == 'd15 && rlast_m_inf_data && rready_m_inf_data && rvalid_m_inf_data) begin
			data_dram_finish_read <= 'd1;
		end
		else begin
			data_dram_finish_read <= data_dram_finish_read;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		data_reading_addr <= 'd0;
	end
	else begin
		if(rvalid_m_inf_data && rready_m_inf_data) begin
			data_reading_addr <= data_reading_addr + 'd1;
		end
		else begin
			data_reading_addr <= data_reading_addr;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		data_reading_addr_delay <= 'd0;
	end
	else begin
		data_reading_addr_delay <= data_reading_addr;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		data_dram_busy <= 'd0;
	end
	else begin
		if(data_dram_req) begin
			data_dram_busy <= 'd1;
		end
		else if((rlast_m_inf_data && rready_m_inf_data && rvalid_m_inf_data) || (bresp_m_inf == 2'b00 && bvalid_m_inf && bready_m_inf)) begin
			data_dram_busy <= 'd0;
		end
		else begin
			data_dram_busy <= data_dram_busy;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		data_from_dram_in <= 'd0;
	end
	else begin
		if(rvalid_m_inf_data && rready_m_inf_data) begin
			data_from_dram_in <= 'd1;
		end
		else begin
			data_from_dram_in <= 'd0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		dram_data_buf <= 'd0;
	end
	else begin
		if(rvalid_m_inf_data && rready_m_inf_data) begin
			dram_data_buf <= rdata_m_inf_data;
		end
		else begin
			dram_data_buf <= 'd0;
		end
	end
end

always @ * begin
	if(data_from_dram_in) begin
		data_sram_in = dram_data_buf;
	end
	else if(inst_type_forward_MA == 3'b011) begin
		data_sram_in = rt_data_forward_MA;
	end
	else begin
		data_sram_in = 'd0;
	end
	
	if(data_from_dram_in || (inst_type_forward_MA == 3'b011)) begin
		data_sram_wr = 'd0;
	end
	else begin
		data_sram_wr = 'd1;
	end
	
	if((inst_type_forward_MA == 3'b011) || (inst_type_forward_MA == 3'b010)) begin
		data_sram_addr = data_writing_addr;
	end
	else begin
		data_sram_addr = data_reading_addr_delay;
	end
end

always @ * begin
	data_dram_read_req = (!data_dram_finish_read);
	data_dram_write_req = (inst_type_forward_MA == 3'b011);
	
	data_writing_addr = ALU_out_forward_MA[10:0];
	
	if(data_dram_read_req)
		data_dram_wr = 'd1;
	else
		data_dram_wr = 'd0;
		
	if(data_dram_read_req)
		data_dram_id = cur_data_dram_req_id;
	else if(data_dram_write_req)
		data_dram_id = data_writing_addr[10:7];
	else
		data_dram_id = 'd0;
		
	if(data_dram_write_req)
		data_dram_addr = data_writing_addr[6:0];
	else
		data_dram_addr = 'd0;
		
	if(data_dram_write_req)
		data_dram_data_in = rt_data_forward_MA;
	else
		data_dram_data_in = 'd0;
	
	data_dram_req = (data_dram_read_req || data_dram_write_req) && !data_dram_busy && !pull_for_maxL;
end

AXI4_inf_data data_interface(
.clk(clk), .rst_n(rst_n),
.start(data_dram_req),
.in_mem_id(data_dram_id),
.wr(data_dram_wr),
.in_mem_addr(data_dram_addr),
.write_data(data_dram_data_in),
.   arid_m_inf   (   arid_m_inf_data   ),
. araddr_m_inf   ( araddr_m_inf_data   ),
.  arlen_m_inf   (  arlen_m_inf_data   ),
. arsize_m_inf   ( arsize_m_inf_data   ),
.arburst_m_inf   (arburst_m_inf_data   ),
.arvalid_m_inf   (arvalid_m_inf_data   ),
.arready_m_inf   (arready_m_inf_data   ),
.   rid_m_inf    (    rid_m_inf_data    ),
. rdata_m_inf    (  rdata_m_inf_data    ),
. rresp_m_inf    (  rresp_m_inf_data    ),
. rlast_m_inf    (  rlast_m_inf_data    ),
.rvalid_m_inf    ( rvalid_m_inf_data    ),
.rready_m_inf    ( rready_m_inf_data    ),
.   awid_m_inf   (   awid_m_inf_data   ),
. awaddr_m_inf   ( awaddr_m_inf_data   ),
. awsize_m_inf   ( awsize_m_inf_data   ),
.awburst_m_inf   (awburst_m_inf_data   ),
.  awlen_m_inf   (  awlen_m_inf_data   ),
.awvalid_m_inf   (awvalid_m_inf_data   ),
.awready_m_inf   (awready_m_inf_data   ),

.  wdata_m_inf   (  wdata_m_inf_data   ),
.  wlast_m_inf   (  wlast_m_inf_data   ),
. wvalid_m_inf   ( wvalid_m_inf_data   ),
. wready_m_inf   ( wready_m_inf_data   ),

.    bid_m_inf   (    bid_m_inf_data   ),
.  bresp_m_inf   (  bresp_m_inf_data   ),
. bvalid_m_inf   ( bvalid_m_inf_data   ),
. bready_m_inf   ( bready_m_inf_data   )
);

SRAM_2048w_16b data_sram(
.A0(data_sram_addr[0]),
.A1(data_sram_addr[1]),
.A2(data_sram_addr[2]),
.A3(data_sram_addr[3]),
.A4(data_sram_addr[4]),
.A5(data_sram_addr[5]),
.A6(data_sram_addr[6]),
.A7(data_sram_addr[7]),
.A8(data_sram_addr[8]),
.A9(data_sram_addr[9]),
.A10(data_sram_addr[10]),
.DO0(data_sram_out[0]),
.DO1(data_sram_out[1]),
.DO2(data_sram_out[2]),
.DO3(data_sram_out[3]),
.DO4(data_sram_out[4]),
.DO5(data_sram_out[5]),
.DO6(data_sram_out[6]),
.DO7(data_sram_out[7]),
.DO8(data_sram_out[8]),
.DO9(data_sram_out[9]),
.DO10(data_sram_out[10]),
.DO11(data_sram_out[11]),
.DO12(data_sram_out[12]),
.DO13(data_sram_out[13]),
.DO14(data_sram_out[14]),
.DO15(data_sram_out[15]),
.DI0(data_sram_in[0]),
.DI1(data_sram_in[1]),
.DI2(data_sram_in[2]),
.DI3(data_sram_in[3]),
.DI4(data_sram_in[4]),
.DI5(data_sram_in[5]),
.DI6(data_sram_in[6]),
.DI7(data_sram_in[7]),
.DI8(data_sram_in[8]),
.DI9(data_sram_in[9]),
.DI10(data_sram_in[10]),
.DI11(data_sram_in[11]),
.DI12(data_sram_in[12]),
.DI13(data_sram_in[13]),
.DI14(data_sram_in[14]),
.DI15(data_sram_in[15]),
.CK(clk), .WEB(data_sram_wr), .OE(1'b1), .CS(1'b1));

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		MEMORY_ACCESS_hold <= 'd0;
	end
	else begin
		if(wvalid_m_inf && wready_m_inf && wlast_m_inf) begin
			MEMORY_ACCESS_hold <= 'd0;
		end
		else if(inst_type_forward_EXE == 3'b011 && !DATA_HAZARD_hold) begin
			MEMORY_ACCESS_hold <= 'd1;
		end
		else begin
			MEMORY_ACCESS_hold <= MEMORY_ACCESS_hold;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_type_forward_WB <= NULL_INST_TYPE;
	end
	else begin
		if(run_first_inst_forward_MA) begin
			inst_type_forward_WB <= inst_type_forward_MA;
		end
		else if(MEMORY_ACCESS_hold) begin
			inst_type_forward_WB <= NULL_INST_TYPE;
		end
		else if((DATA_DRAM_hold || INST_DRAM_hold) && !run_first_inst_forward_WB)begin
			inst_type_forward_WB <= inst_type_forward_WB;
		end
		else begin
			inst_type_forward_WB <= inst_type_forward_MA;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		save_reg_addr_WB <= 'd0;
	end
	else begin
		save_reg_addr_WB <= save_reg_addr_MA; 
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		ALU_out_forward_WB <= 'd0;
	end
	else begin
		ALU_out_forward_WB <= ALU_out_forward_MA;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		run_first_inst_forward_WB <= 'd0;
	end
	else begin
		if(run_first_inst_forward_MA) begin
			run_first_inst_forward_WB <= 'd1;
		end
		else begin
			run_first_inst_forward_WB <= run_first_inst_forward_WB;
		end
	end
end

//####################################################
//               	Write Back
//####################################################
always @ * begin
	case(inst_type_forward_WB)
		3'b000,
		3'b001,
		3'b111	:	data_WB = ALU_out_forward_WB;
		3'b010	:	data_WB = data_sram_out;
		default	:	data_WB = 'd0;
	endcase
	
	if(inst_type_forward_WB == 3'b000 || inst_type_forward_WB == 3'b001 || inst_type_forward_WB == 3'b111 || inst_type_forward_WB == 3'b010) begin
		WB = 'd1;
	end
	else begin
		WB = 'd0;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r0 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd0) begin
			core_r0 <= data_WB;
		end
		else begin
			core_r0 <= core_r0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r1 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd1) begin
			core_r1 <= data_WB;
		end
		else begin
			core_r1 <= core_r1;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r2 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd2) begin
			core_r2 <= data_WB;
		end
		else begin
			core_r2 <= core_r2;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r3 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd3) begin
			core_r3 <= data_WB;
		end
		else begin
			core_r3 <= core_r3;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r4 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd4) begin
			core_r4 <= data_WB;
		end
		else begin
			core_r4 <= core_r4;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r5 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd5) begin
			core_r5 <= data_WB;
		end
		else begin
			core_r5 <= core_r5;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r6 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd6) begin
			core_r6 <= data_WB;
		end
		else begin
			core_r6 <= core_r6;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r7 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd7) begin
			core_r7 <= data_WB;
		end
		else begin
			core_r7 <= core_r7;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r8 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd8) begin
			core_r8 <= data_WB;
		end
		else begin
			core_r8 <= core_r8;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r9 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd9) begin
			core_r9 <= data_WB;
		end
		else begin
			core_r9 <= core_r9;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r10 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd10) begin
			core_r10 <= data_WB;
		end
		else begin
			core_r10 <= core_r10;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r11 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd11) begin
			core_r11 <= data_WB;
		end
		else begin
			core_r11 <= core_r11;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r12 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd12) begin
			core_r12 <= data_WB;
		end
		else begin
			core_r12 <= core_r12;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r13 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd13) begin
			core_r13 <= data_WB;
		end
		else begin
			core_r13 <= core_r13;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r14 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd14) begin
			core_r14 <= data_WB;
		end
		else begin
			core_r14 <= core_r14;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		core_r15 <= 'd0;
	end
	else begin
		if(WB && save_reg_addr_WB == 'd15) begin
			core_r15 <= data_WB;
		end
		else begin
			core_r15 <= core_r15;
		end
	end
end


// Output
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		pull_for_maxL <= 'd0;
	end
	else begin
		if(run_first_inst_forward_WB) begin
			pull_for_maxL <= 'd0;
		end
		else if(cur_data_dram_req_id == 'd9 || cur_inst_dram_req_id == 'd9) begin
			pull_for_maxL <= 'd1;
		end
		else if(inst_type_forward_WB != NULL_INST_TYPE) begin
			pull_for_maxL <= 'd0;
		end
		else begin
			pull_for_maxL <= pull_for_maxL;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		IO_stall <= 'd1;
	end
	else begin
		if(inst_type_forward_WB != NULL_INST_TYPE) begin
			IO_stall <= 'd0;
		end
		else begin
			IO_stall <= 'd1;
		end
	end
end

endmodule


module AXI4_inf_inst(
	// input
	clk, rst_n,
	start, in_mem_id,
	// output
	arid_m_inf,
   araddr_m_inf,
	arlen_m_inf,
   arsize_m_inf,
  arburst_m_inf,
  arvalid_m_inf,
				
  arready_m_inf, 
	  rid_m_inf,
	rdata_m_inf,
	rresp_m_inf,
	rlast_m_inf,
   rvalid_m_inf,
   rready_m_inf 
);

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

input clk, rst_n;
input start;
input [3:0] in_mem_id;
// -----------------------------
// axi read address channel 
output  wire [ID_WIDTH-1:0]       arid_m_inf;
output  wire [ADDR_WIDTH-1:0]   araddr_m_inf;
output  wire [6:0]            arlen_m_inf;
output  wire [2:0]           arsize_m_inf;
output  wire [1:0]          arburst_m_inf;
output  wire arvalid_m_inf;
input   wire arready_m_inf;
// -----------------------------
// axi read data channel 
input   wire [ID_WIDTH-1:0]         rid_m_inf;
input   wire [DATA_WIDTH-1:0]     rdata_m_inf;
input   wire [1:0]             rresp_m_inf;
input   wire rlast_m_inf;
input   wire rvalid_m_inf;
output  wire rready_m_inf;
// -----------------------------
//####################################################
//               reg & wire
//####################################################
reg [1:0] state, state_next;
reg [3:0] mem_id;

parameter IDLE = 0;
parameter AREAD = 1;
parameter READ = 2;

always @ * begin
	case(state) // synopsys full_case
		IDLE	:	begin
						if(start)
							state_next = AREAD;
						else
							state_next = IDLE;
					end
		AREAD	:	begin
						if(arvalid_m_inf && arready_m_inf)
							state_next = READ;
						else
							state_next = AREAD;
					end
		READ	:	begin
						if(rvalid_m_inf && rready_m_inf && rlast_m_inf)
							state_next = IDLE;
						else
							state_next = READ;
					end
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state <= IDLE;
	end
	else begin
		state <= state_next;
	end
end

//=====================================
//				AREAD
//=====================================
always @ (posedge clk) begin
	if(start)
		mem_id <= in_mem_id;
	else 
		mem_id <= mem_id;
end

assign araddr_m_inf = (state == AREAD) ? {19'b0, 1'b1, mem_id, 8'b0} : 'd0;
assign arvalid_m_inf = (state == AREAD);
assign arburst_m_inf = 2'b01;
assign arlen_m_inf = 7'b1111111;
assign arid_m_inf = 'd0;
assign arsize_m_inf = 3'b001;
//=====================================
//				READ
//=====================================
assign rready_m_inf = (state == READ);


endmodule


module AXI4_inf_data(
	// input
	clk, rst_n,
	start, in_mem_id, wr, in_mem_addr, write_data,
	// output
	arid_m_inf,
   araddr_m_inf,
	arlen_m_inf,
   arsize_m_inf,
  arburst_m_inf,
  arvalid_m_inf,
				
  arready_m_inf, 
	  rid_m_inf,
	rdata_m_inf,
	rresp_m_inf,
	rlast_m_inf,
   rvalid_m_inf,
   rready_m_inf,

	awid_m_inf,
   awaddr_m_inf,
   awsize_m_inf,
  awburst_m_inf,
	awlen_m_inf,
  awvalid_m_inf,
  awready_m_inf,
				
	wdata_m_inf,
	wlast_m_inf,
   wvalid_m_inf,
   wready_m_inf,
				
	  bid_m_inf,
	bresp_m_inf,
   bvalid_m_inf,
   bready_m_inf,
);

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

input clk, rst_n;
input start;
input wr;
input [3:0] in_mem_id;
input [6:0] in_mem_addr;
input [15:0] write_data;

// axi write address channel 
output  wire [ID_WIDTH-1:0]        awid_m_inf;
output  wire [ADDR_WIDTH-1:0]    awaddr_m_inf;
output  wire [3 -1:0]            awsize_m_inf;
output  wire [2 -1:0]           awburst_m_inf;
output  wire [7 -1:0]             awlen_m_inf;
output  wire               		awvalid_m_inf;
input   wire               		awready_m_inf;
// axi write data channel 
output  wire [DATA_WIDTH-1:0]     wdata_m_inf;
output  wire                   wlast_m_inf;
output  wire                  wvalid_m_inf;
input   wire                  wready_m_inf;
// axi write response channel
input   wire [ID_WIDTH-1:0]         bid_m_inf;
input   wire [2 -1:0]             bresp_m_inf;
input   wire               	   bvalid_m_inf;
output  wire                   bready_m_inf;
// -----------------------------
// -----------------------------
// axi read address channel 
output  wire [ID_WIDTH-1:0]       arid_m_inf;
output  wire [ADDR_WIDTH-1:0]   araddr_m_inf;
output  wire [6:0]            arlen_m_inf;
output  wire [2:0]           arsize_m_inf;
output  wire [1:0]          arburst_m_inf;
output  wire arvalid_m_inf;
input   wire arready_m_inf;
// -----------------------------
// axi read data channel 
input   wire [ID_WIDTH-1:0]         rid_m_inf;
input   wire [DATA_WIDTH-1:0]     rdata_m_inf;
input   wire [1:0]             rresp_m_inf;
input   wire rlast_m_inf;
input   wire rvalid_m_inf;
output  wire rready_m_inf;
// -----------------------------
//####################################################
//               reg & wire
//####################################################
reg [2:0] state, state_next;
reg [3:0] mem_id;
reg [6:0] mem_addr;
reg [15:0] write_data_store;

parameter IDLE = 0;
parameter AREAD = 1;
parameter READ = 2;
parameter AWRITE = 3;
parameter WRITE = 4;
parameter BRESP = 5;

always @ * begin
	case(state) // synopsys full_case
		IDLE	:	begin
						if(start) begin
							if(wr) begin
								state_next = AREAD;
							end
							else begin
								state_next = AWRITE;
							end
						end
						else begin
							state_next = IDLE;
						end
					end
		AREAD	:	begin
						if(arvalid_m_inf && arready_m_inf)
							state_next = READ;
						else
							state_next = AREAD;
					end
		READ	:	begin
						if(rvalid_m_inf && rready_m_inf && rlast_m_inf)
							state_next = IDLE;
						else
							state_next = READ;
					end
		AWRITE	:	begin
						if(awvalid_m_inf && awready_m_inf)
							state_next = WRITE;
						else
							state_next = AWRITE;
					end
		WRITE	:	begin
						if(wvalid_m_inf && wready_m_inf)
							state_next = BRESP;
						else
							state_next = WRITE;
					end
		BRESP	:	begin
						if(bresp_m_inf == 2'b00 && bvalid_m_inf && bready_m_inf) 
							state_next = IDLE;
						else
							state_next = BRESP;
					end
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state <= IDLE;
	end
	else begin
		state <= state_next;
	end
end

//=====================================
//				AREAD
//=====================================
always @ (posedge clk) begin
	if(start)
		mem_id <= in_mem_id;
	else 
		mem_id <= mem_id;
end

assign araddr_m_inf = (state == AREAD) ? {19'b0, 1'b1, mem_id, 8'b0} : 'd0;
assign arvalid_m_inf = (state == AREAD);
assign arburst_m_inf = 2'b01;
assign arlen_m_inf = 7'b1111111;
assign arid_m_inf = 'd0;
assign arsize_m_inf = 3'b001;
//=====================================
//				READ
//=====================================
assign rready_m_inf = (state == READ);

//=====================================
//				AWRITE
//=====================================
always @ (posedge clk) begin
	if(start && !wr)
		mem_addr <= in_mem_addr;
	else
		mem_addr <= mem_addr;
end

assign awaddr_m_inf = (state == AWRITE) ? {19'b0, 1'b1, mem_id, mem_addr, 1'b0} : 'd0;
assign awvalid_m_inf = (state == AWRITE);
assign awid_m_inf = 'd0;
assign awlen_m_inf = 'd0;
assign awsize_m_inf = 3'b001;
assign awburst_m_inf = 2'b01;

//=====================================
//				WRITE
//=====================================
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		write_data_store <= 'd0;
	end
	else begin
		if(start && !wr) begin
			write_data_store <= write_data;
		end
		else begin
			write_data_store <= write_data_store;
		end
	end
end

assign wvalid_m_inf = (state == WRITE);
assign wdata_m_inf = (state == WRITE) ? write_data_store : 0;
assign wlast_m_inf = (state == WRITE);

//=====================================
//				BRESP
//=====================================
assign bready_m_inf = (state == WRITE || state == BRESP);

endmodule