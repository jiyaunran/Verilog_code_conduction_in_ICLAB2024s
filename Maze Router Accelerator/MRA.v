//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Si2 LAB @NYCU ED430
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2024 Spring
//   Midterm Proejct            : MRA  
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : MRA.v
//   Module Name : MRA
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module MRA #(parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32)(
	// CHIP IO
	clk            	,	
	rst_n          	,	
	in_valid       	,	
	frame_id        ,	
	net_id         	,	  
	loc_x          	,	  
    loc_y         	,
	cost	 		,		
	busy         	,

    // AXI4 IO
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
	   bready_m_inf 
);

// ===============================================================
//  					Input / Output 
// ===============================================================

// << CHIP io port with system >>
input 			  	clk,rst_n;
input 			   	in_valid;
input  [4:0] 		frame_id;
input  [3:0]       	net_id;     
input  [5:0]       	loc_x; 
input  [5:0]       	loc_y; 
output reg [13:0] 	cost;
output reg          busy;       
  
// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
       Your AXI-4 interface could be designed as a bridge in submodule,
	   therefore I declared output of AXI as wire.  
	   Ex: AXI4_interface AXI4_INF(...);
*/

// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)	axi read address channel 
output wire [ID_WIDTH-1:0]      arid_m_inf;
output wire [1:0]            arburst_m_inf;
output wire [2:0]             arsize_m_inf;
output wire [7:0]              arlen_m_inf;
output wire                  arvalid_m_inf;
input  wire                  arready_m_inf;
output wire [ADDR_WIDTH-1:0]  araddr_m_inf;
// ------------------------
// (2)	axi read data channel 
input  wire [ID_WIDTH-1:0]       rid_m_inf;
input  wire                   rvalid_m_inf;
output wire                   rready_m_inf;
input  wire [DATA_WIDTH-1:0]   rdata_m_inf;
input  wire                    rlast_m_inf;
input  wire [1:0]              rresp_m_inf;
// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1) 	axi write address channel 
output wire [ID_WIDTH-1:0]      awid_m_inf;
output wire [1:0]            awburst_m_inf;
output wire [2:0]             awsize_m_inf;
output wire [7:0]              awlen_m_inf;
output wire                  awvalid_m_inf;
input  wire                  awready_m_inf;
output wire [ADDR_WIDTH-1:0]  awaddr_m_inf;
// -------------------------
// (2)	axi write data channel 
output wire                   wvalid_m_inf;
input  wire                   wready_m_inf;
output wire [DATA_WIDTH-1:0]   wdata_m_inf;
output wire                    wlast_m_inf;
// -------------------------
// (3)	axi write response channel 
input  wire  [ID_WIDTH-1:0]      bid_m_inf;
input  wire                   bvalid_m_inf;
output wire                   bready_m_inf;
input  wire  [1:0]             bresp_m_inf;
// -----------------------------
//		regs & wires
// -----------------------------
reg [4:0] frame_id_store;
reg [3:0] net_id_store[14:0];
reg [5:0] loc_x_store[14:0][1:0]; // 0: target
reg [5:0] loc_y_store[14:0][1:0]; // 1: source
reg [4:0] net_number_count;
reg in_valid_delay;

reg [2:0] state, state_comb;

reg [3:0] SRAM_data_in[31:0];
reg [3:0] SRAM_addr[31:0];

reg [5:0] cur_source_x,  cur_source_y;
reg [5:0] cur_target_x,  cur_target_y;
reg [3:0] cur_net;

reg [1:0] DRAM_state, DRAM_state_comb;

// -----------------------------
//			RETRACE
// -----------------------------
reg [5:0] cur_retrace_x, cur_retrace_y, cur_retrace_x_comb, cur_retrace_y_comb;
reg [5:0] cur_retrace_x_left, cur_retrace_x_right, cur_retrace_y_up, cur_retrace_y_down;
reg [1:0] cur_dir;
reg [5:0] retrace_up_xlist[63:0];
reg [2:0] retrace_down_xlist[63:0];
reg [5:0] retrace_left_xlist[63:0];
reg [5:0] retrace_right_xlist[63:0];
reg [5:0] retrace_up;
reg [5:0] retrace_down;
reg [5:0] retrace_left;
reg [5:0] retrace_right;

reg retrace_end;
reg retrace_cnt;

// -----------------------------
//			READ MAP
// -----------------------------
reg READ_REQUEST, WRITE_REQUEST, READ_FIN;
reg [ADDR_WIDTH-1:0] ID_addr, WEIGHT_addr, read_dram_addr;
reg [6:0]	DRAM_data_count, DRAM_weight_count;
reg [3:0]	ID_addr_select;
reg [3:0]	DRAM_data_split[31:0];
reg 	    MAP_state[63:0][63:0],		// 0: IDLE
			MAP_shift[63:0][63:0],		// 1: macro
            MAP_shift_inv[63:0][63:0];	// 2: path
			
reg [1:0]	MAP[63:0][63:0],	  		// 0: source
			MAP_filling[63:0][63:0];	// 1~3: Fill_path_dir
										// 4: Macro occupied
										// 5: IDLE
										// 6: target(sink)
										// 7: Path occupied

// -----------------------------
//		FILLING_PATH
// -----------------------------
reg [3:0] net_count;
reg touch_end_local[63:0][63:0];
reg touch_end_tmp1[31:0][31:0];
reg touch_end_tmp2[15:0][15:0];
reg touch_end_tmp3[7:0][7:0];
reg touch_end_tmp4[3:0][3:0];
reg touch_end_tmp5[1:0][1:0];
reg touch_end;

// -----------------------------
//			WRITE_BACK
// -----------------------------
reg [127:0] write_data;
reg [3:0] write_data_split[31:0];
reg SRAM_reading_data;

// -----------------------------
//		Calculate Cost
// -----------------------------
reg [3:0] add_in[31:0];
reg [4:0] add_layer1[15:0];
reg [5:0] add_layer2[7:0];
reg [6:0] add_layer3[3:0];
reg [7:0] add_layer4[1:0];
reg [3:0] add_tmp;

// -----------------------------
//			SRAM
// -----------------------------
reg [6:0] ID_SRAM_ADDR;
reg [127:0] ID_SRAM_DATA_IN;
reg [127:0] ID_SRAM_DATA_OUT;
reg ID_SRAM_DATA_WR;  // 0:write 1:read
reg [6:0] WEIGHT_SRAM_ADDR;
reg [127:0] WEIGHT_SRAM_DATA_IN;
reg [127:0] WEIGHT_SRAM_DATA_OUT;
reg WEIGHT_SRAM_DATA_WR;

wire [3:0] WEIGHT_SRAM_DATA_OUT_split[31:0];

reg wait_sram_loading;
reg filt_sink;

// -----------------------------
//			parameters
// -----------------------------
parameter IDLE = 0;
parameter READ_ID = 1;
parameter READ_WEIGHT = 2;
parameter RW_FIN = 3;


parameter WAIT_ID = 1;
parameter CLEAN_MAP = 2;
parameter FILLING_PATH = 3;
parameter RETRACE = 4;
parameter WRITE_BACK_N_ADD = 5;
parameter WAIT_WEIGHT = 6;
	
integer z,x,y;

// -----------------------------
//				FSM
// -----------------------------
always @ * begin
	case(state) // synopsys full_case
		IDLE				:	begin
									if(in_valid)												state_comb = WAIT_ID;
									else														state_comb = IDLE;
								end
		WAIT_ID				:	begin
									if(rvalid_m_inf && rready_m_inf && rlast_m_inf)				state_comb = CLEAN_MAP;
									else														state_comb = WAIT_ID;
								end
		CLEAN_MAP			:	begin
									if(net_count == 'd0)										state_comb = WRITE_BACK_N_ADD;
									else														state_comb = FILLING_PATH;
								end
		FILLING_PATH		:	begin
									if(touch_end) begin
										if(DRAM_state == RW_FIN)								state_comb = RETRACE;
										else													state_comb = WAIT_WEIGHT;
									end
									else														state_comb = FILLING_PATH;
								end
		RETRACE				:	begin
									if(retrace_end)												state_comb = CLEAN_MAP;
									else														state_comb = RETRACE;
								end
		WRITE_BACK_N_ADD	:	begin
									if(wlast_m_inf)												state_comb = IDLE;
									else														state_comb = WRITE_BACK_N_ADD;
								end
		WAIT_WEIGHT			:	begin
									if(DRAM_state == RW_FIN)									state_comb = RETRACE;
									else														state_comb = WAIT_WEIGHT;
								end
	endcase								
end

always @ * begin
	case(DRAM_state) // synopsys full_case
		IDLE	:	begin
						if(in_valid)															DRAM_state_comb = READ_ID;
						else																	DRAM_state_comb = IDLE;
					end						
		READ_ID :  	begin						
						if(rvalid_m_inf && rready_m_inf && rlast_m_inf)							DRAM_state_comb = READ_WEIGHT;
						else																	DRAM_state_comb = READ_ID;
					end						
		READ_WEIGHT:begin						
						if(rvalid_m_inf && rready_m_inf && rlast_m_inf)							DRAM_state_comb = RW_FIN;
						else																	DRAM_state_comb = READ_WEIGHT;
					end						
		RW_FIN :	begin						
						if(state == IDLE)														DRAM_state_comb = IDLE;
						else																	DRAM_state_comb = RW_FIN;
					end
		
	endcase
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
		DRAM_state <= 'd0;
	end
	else begin
		DRAM_state <= DRAM_state_comb;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		busy <= 'd0;
	end
	else begin
		if(state == IDLE) begin
			busy <= 'd0;
		end
		else if(!in_valid) begin
			busy <= 'd1;
		end
		else begin
			busy <= 'd0;
		end
	end
end

// -----------------------------
//		Information store
// -----------------------------
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		net_number_count <= 'd0;
	end
	else begin
		if(in_valid) begin
			net_number_count <= net_number_count + 'd1;
		end
		else if(state == IDLE) begin
			net_number_count <= 'd0;
		end
		else begin
			net_number_count <= net_number_count;
		end
	end
end


always @ (posedge clk) begin
	if(in_valid) 	frame_id_store <= frame_id;
	else			frame_id_store <= frame_id_store;
end

always @ (posedge clk) begin
	if(in_valid && net_number_count[0] == 1'b0)	net_id_store[0] <= net_id;
	else										net_id_store[0] <= net_id_store[0];
end

always @ (posedge clk) begin
	if(in_valid) begin
		loc_x_store[0][0] <= loc_x;
	end
	else begin
		loc_x_store[0][0] <= loc_x_store[0][0];
	end
end

always @ (posedge clk) begin
	if(in_valid) begin
		loc_y_store[0][0] <= loc_y;
	end
	else begin
		loc_y_store[0][0] <= loc_y_store[0][0];
	end
end

genvar i;
generate	
for(i=1;i<15;i=i+1) begin : a
	always @ (posedge clk) begin
		if(in_valid &&  net_number_count[0] == 1'b0)	net_id_store[i] <= net_id_store[i-1];
		else											net_id_store[i] <= net_id_store[i];
	end
end

for(i=0;i<15;i=i+1) begin
	always @ (posedge clk) begin
		if(in_valid) begin
			loc_y_store[i][1] <= loc_y_store[i][0];
		end
		else begin
			loc_y_store[i][1] <= loc_y_store[i][1];
		end
	end
end
for(i=1;i<15;i=i+1) begin
	always @ (posedge clk) begin
		if(in_valid) begin
			loc_y_store[i][0] <= loc_y_store[i-1][1];
		end
		else begin
			loc_y_store[i][0] <= loc_y_store[i][0];
		end
	end
end

for(i=0;i<15;i=i+1) begin
	always @ (posedge clk) begin
		if(in_valid) begin
			loc_x_store[i][1] <= loc_x_store[i][0];
		end
		else begin
			loc_x_store[i][1] <= loc_x_store[i][1];
		end
	end
end
for(i=1;i<15;i=i+1) begin
	always @ (posedge clk) begin
		if(in_valid) begin
			loc_x_store[i][0] <= loc_x_store[i-1][1];
		end
		else begin
			loc_x_store[i][0] <= loc_x_store[i][0];
		end
	end
end
endgenerate

// -----------------------------
//			READ MAP
// -----------------------------
always @ (posedge clk) begin
	if(DRAM_state == READ_ID) begin
		if((rvalid_m_inf && rready_m_inf)) begin
			DRAM_data_count <= DRAM_data_count + 'd1;
		end
		else if(arvalid_m_inf) begin
			DRAM_data_count <= 'd0;
		end
		else begin
			DRAM_data_count <= DRAM_data_count;
		end
	end
	else if(DRAM_state == READ_WEIGHT) begin
		if((rvalid_m_inf && rready_m_inf)) begin
			DRAM_data_count <= DRAM_data_count + 'd1;
		end
		else if(arvalid_m_inf) begin
			DRAM_data_count <= 'd0;
		end
		else begin
			DRAM_data_count <= DRAM_data_count;
		end
	end
	else if(state == WRITE_BACK_N_ADD) begin
		if((awready_m_inf && awaddr_m_inf) || (DRAM_data_count == 'd1)) begin
			DRAM_data_count <= DRAM_data_count + 'd1;
		end
		else if(wvalid_m_inf && wready_m_inf) begin
			DRAM_data_count <= DRAM_data_count + 'd1;
		end
		else begin
			DRAM_data_count <= DRAM_data_count;
		end
	end
	else if(state == IDLE) begin
		DRAM_data_count <= 'd0;
	end
	else begin
		DRAM_data_count <= DRAM_data_count;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		READ_FIN <= 'd0;
	end
	else begin
		if(DRAM_state == READ_WEIGHT && READ_REQUEST == 'd1) begin
			READ_FIN <= 'd1;
		end
		else if(state == IDLE) begin
			READ_FIN <= 'd0;
		end
		else begin
			READ_FIN <= READ_FIN;
		end
	end
end

always @ * begin
ID_addr = 'd0;
WEIGHT_addr = 'd0;
READ_REQUEST   = 'd0;
ID_addr_select = frame_id_store[4:1];
ID_addr[11] = frame_id_store[0];
	
	if(in_valid && !(state == WAIT_ID)) begin
		READ_REQUEST = 'd1;
	end
	else if(DRAM_state == READ_WEIGHT && !READ_FIN) begin
		READ_REQUEST = 'd1;
	end
	
	if(in_valid && !(state == WAIT_ID)) begin // early case
		ID_addr[11] = frame_id[0];
		ID_addr_select = frame_id[4:1];
	end
	

WEIGHT_addr[11] = frame_id_store[0];
case(frame_id_store[4:1])
	'd0 :	WEIGHT_addr[23:12] = 'h20;
	'd1 :	WEIGHT_addr[23:12] = 'h21;
	'd2 :	WEIGHT_addr[23:12] = 'h22;
	'd3 :	WEIGHT_addr[23:12] = 'h23;
	'd4 :	WEIGHT_addr[23:12] = 'h24;
	'd5 :	WEIGHT_addr[23:12] = 'h25;
	'd6 :	WEIGHT_addr[23:12] = 'h26;
	'd7 :	WEIGHT_addr[23:12] = 'h27;
	'd8 :	WEIGHT_addr[23:12] = 'h28;
	'd9 :	WEIGHT_addr[23:12] = 'h29;
	'd10:	WEIGHT_addr[23:12] = 'h2a;
	'd11:	WEIGHT_addr[23:12] = 'h2b;
	'd12:	WEIGHT_addr[23:12] = 'h2c;
	'd13:	WEIGHT_addr[23:12] = 'h2d;
	'd14:	WEIGHT_addr[23:12] = 'h2e;
	'd15:	WEIGHT_addr[23:12] = 'h2f;
endcase

case(ID_addr_select)
	'd0 :	ID_addr[23:12] = 'h10;
	'd1 :	ID_addr[23:12] = 'h11;
	'd2 :	ID_addr[23:12] = 'h12;
	'd3 :	ID_addr[23:12] = 'h13;
	'd4 :	ID_addr[23:12] = 'h14;
	'd5 :	ID_addr[23:12] = 'h15;
	'd6 :	ID_addr[23:12] = 'h16;
	'd7 :	ID_addr[23:12] = 'h17;
	'd8 :	ID_addr[23:12] = 'h18;
	'd9 :	ID_addr[23:12] = 'h19;
	'd10:	ID_addr[23:12] = 'h1a;
	'd11:	ID_addr[23:12] = 'h1b;
	'd12:	ID_addr[23:12] = 'h1c;
	'd13:	ID_addr[23:12] = 'h1d;
	'd14:	ID_addr[23:12] = 'h1e;
	'd15:	ID_addr[23:12] = 'h1f;
endcase
read_dram_addr = ID_addr;

	if(DRAM_state == READ_WEIGHT) begin
		read_dram_addr = WEIGHT_addr;
	end
end

always @ * begin
	{DRAM_data_split[31],DRAM_data_split[30],DRAM_data_split[29],DRAM_data_split[28],DRAM_data_split[27],DRAM_data_split[26],DRAM_data_split[25],DRAM_data_split[24],DRAM_data_split[23],DRAM_data_split[22],DRAM_data_split[21],DRAM_data_split[20],DRAM_data_split[19],DRAM_data_split[18],DRAM_data_split[17],DRAM_data_split[16],DRAM_data_split[15],DRAM_data_split[14],DRAM_data_split[13],DRAM_data_split[12],DRAM_data_split[11],DRAM_data_split[10],DRAM_data_split[9],DRAM_data_split[8],DRAM_data_split[7],DRAM_data_split[6],DRAM_data_split[5],DRAM_data_split[4],DRAM_data_split[3],DRAM_data_split[2],DRAM_data_split[1],DRAM_data_split[0]} = rdata_m_inf;
end

wire [127:0] write_data_wire;

assign write_data_wire = write_data;

AXI4_interface IF(
	.clk(clk), .rst_n(rst_n),
	.read_addr(read_dram_addr), .write_addr(ID_addr),
	.write_data(write_data_wire),
	.READ_REQUEST(READ_REQUEST), .WRITE_REQUEST(WRITE_REQUEST),
	.write_last_count(DRAM_data_count),
	// AXI4 IO
   .   awid_m_inf(   awid_m_inf),
   . awaddr_m_inf( awaddr_m_inf),
   . awsize_m_inf( awsize_m_inf),
   .awburst_m_inf(awburst_m_inf),
   .  awlen_m_inf(  awlen_m_inf),
   .awvalid_m_inf(awvalid_m_inf),
   .awready_m_inf(awready_m_inf),

   .  wdata_m_inf(  wdata_m_inf),
   .  wlast_m_inf(  wlast_m_inf),
   . wvalid_m_inf( wvalid_m_inf),
   . wready_m_inf( wready_m_inf),

   .    bid_m_inf(    bid_m_inf),
   .  bresp_m_inf(  bresp_m_inf),
   . bvalid_m_inf( bvalid_m_inf),
   . bready_m_inf( bready_m_inf),

   .   arid_m_inf(   arid_m_inf),
   . araddr_m_inf( araddr_m_inf),
   .  arlen_m_inf(  arlen_m_inf),
   . arsize_m_inf( arsize_m_inf),
   .arburst_m_inf(arburst_m_inf),
   .arvalid_m_inf(arvalid_m_inf),
   .arready_m_inf(arready_m_inf), 

   .    rid_m_inf(    rid_m_inf),
   .  rdata_m_inf(  rdata_m_inf),
   .  rresp_m_inf(  rresp_m_inf),
   .  rlast_m_inf(  rlast_m_inf),
   . rvalid_m_inf( rvalid_m_inf),
   . rready_m_inf( rready_m_inf) 
);

// -----------------------------
//		FILLING_PATH
// -----------------------------
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		net_count <= 'd0;
	end
	else begin
		if(state == WAIT_ID) begin
			net_count <= net_number_count[4:1];
		end
		else if(state == CLEAN_MAP) begin
			net_count <= net_count;
		end
		else if(retrace_end && state == RETRACE) begin
			net_count <= net_count - 'd1;
		end
		else begin
			net_count <= net_count;
		end
	end
end
reg [3:0] target_source_select;
always @ * begin
	target_source_select = net_count - 'd1;
	case(target_source_select)
		'd0  : cur_source_x = loc_x_store[0 ][1];
		'd1  : cur_source_x = loc_x_store[1 ][1];
		'd2  : cur_source_x = loc_x_store[2 ][1];
		'd3  : cur_source_x = loc_x_store[3 ][1];
		'd4  : cur_source_x = loc_x_store[4 ][1];
		'd5  : cur_source_x = loc_x_store[5 ][1];
		'd6  : cur_source_x = loc_x_store[6 ][1];
		'd7  : cur_source_x = loc_x_store[7 ][1];
		'd8  : cur_source_x = loc_x_store[8 ][1];
		'd9  : cur_source_x = loc_x_store[9 ][1];
		'd10 : cur_source_x = loc_x_store[10][1];
		'd11 : cur_source_x = loc_x_store[11][1];
		'd12 : cur_source_x = loc_x_store[12][1];
		'd13 : cur_source_x = loc_x_store[13][1];
		'd14 : cur_source_x = loc_x_store[14][1];
		'd15 : cur_source_x = 'd0;
	endcase
	case(target_source_select)
		'd0  : cur_source_y = loc_y_store[0 ][1];
		'd1  : cur_source_y = loc_y_store[1 ][1];
		'd2  : cur_source_y = loc_y_store[2 ][1];
		'd3  : cur_source_y = loc_y_store[3 ][1];
		'd4  : cur_source_y = loc_y_store[4 ][1];
		'd5  : cur_source_y = loc_y_store[5 ][1];
		'd6  : cur_source_y = loc_y_store[6 ][1];
		'd7  : cur_source_y = loc_y_store[7 ][1];
		'd8  : cur_source_y = loc_y_store[8 ][1];
		'd9  : cur_source_y = loc_y_store[9 ][1];
		'd10 : cur_source_y = loc_y_store[10][1];
		'd11 : cur_source_y = loc_y_store[11][1];
		'd12 : cur_source_y = loc_y_store[12][1];
		'd13 : cur_source_y = loc_y_store[13][1];
		'd14 : cur_source_y = loc_y_store[14][1];
		'd15 : cur_source_y = 'd0;
	endcase
	case(target_source_select)
		'd0  : cur_target_x = loc_x_store[0 ][0];
		'd1  : cur_target_x = loc_x_store[1 ][0];
		'd2  : cur_target_x = loc_x_store[2 ][0];
		'd3  : cur_target_x = loc_x_store[3 ][0];
		'd4  : cur_target_x = loc_x_store[4 ][0];
		'd5  : cur_target_x = loc_x_store[5 ][0];
		'd6  : cur_target_x = loc_x_store[6 ][0];
		'd7  : cur_target_x = loc_x_store[7 ][0];
		'd8  : cur_target_x = loc_x_store[8 ][0];
		'd9  : cur_target_x = loc_x_store[9 ][0];
		'd10 : cur_target_x = loc_x_store[10][0];
		'd11 : cur_target_x = loc_x_store[11][0];
		'd12 : cur_target_x = loc_x_store[12][0];
		'd13 : cur_target_x = loc_x_store[13][0];
		'd14 : cur_target_x = loc_x_store[14][0];
		'd15 : cur_target_x = 'd0;
	endcase
	case(target_source_select)
		'd0  : cur_target_y = loc_y_store[0 ][0];
		'd1  : cur_target_y = loc_y_store[1 ][0];
		'd2  : cur_target_y = loc_y_store[2 ][0];
		'd3  : cur_target_y = loc_y_store[3 ][0];
		'd4  : cur_target_y = loc_y_store[4 ][0];
		'd5  : cur_target_y = loc_y_store[5 ][0];
		'd6  : cur_target_y = loc_y_store[6 ][0];
		'd7  : cur_target_y = loc_y_store[7 ][0];
		'd8  : cur_target_y = loc_y_store[8 ][0];
		'd9  : cur_target_y = loc_y_store[9 ][0];
		'd10 : cur_target_y = loc_y_store[10][0];
		'd11 : cur_target_y = loc_y_store[11][0];
		'd12 : cur_target_y = loc_y_store[12][0];
		'd13 : cur_target_y = loc_y_store[13][0];
		'd14 : cur_target_y = loc_y_store[14][0];
		'd15 : cur_target_y = 'd0;
	endcase
	case(target_source_select)
		'd0  : cur_net = net_id_store[0 ];
		'd1  : cur_net = net_id_store[1 ];
		'd2  : cur_net = net_id_store[2 ];
		'd3  : cur_net = net_id_store[3 ];
		'd4  : cur_net = net_id_store[4 ];
		'd5  : cur_net = net_id_store[5 ];
		'd6  : cur_net = net_id_store[6 ];
		'd7  : cur_net = net_id_store[7 ];
		'd8  : cur_net = net_id_store[8 ];
		'd9  : cur_net = net_id_store[9 ];
		'd10 : cur_net = net_id_store[10];
		'd11 : cur_net = net_id_store[11];
		'd12 : cur_net = net_id_store[12];
		'd13 : cur_net = net_id_store[13];
		'd14 : cur_net = net_id_store[14];
		'd15 : cur_net = 'd0;
	endcase
end


genvar j,k;
generate
for(i=0;i<64;i=i+1) begin : d
	for(j=0;j<64;j=j+1) begin : c
		always @ (posedge clk) begin
			case(state)
				CLEAN_MAP : begin
								if(j == cur_source_y && i == cur_source_x) begin
									MAP[i][j] <= 'd1;
								end
								else begin
									MAP[i][j] <= 'd0;
								end
							end
				FILLING_PATH : MAP[i][j] <= MAP_filling[i][j];
				default : MAP[i][j] <= MAP[i][j];
			endcase
		end
	end
end
reg avoid_target;
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		avoid_target <= 'd0;
	end
	else begin
		if(state == RETRACE) begin
			avoid_target <= 'd1;
		end
		else begin
			avoid_target <= 'd0;
		end
	end
end

for(i=0;i<64;i=i+1) begin : MAP_state_in_i
	for(j=0;j<64;j=j+1) begin : MAP_state_in_j
		always @ (posedge clk) begin
			if((DRAM_state == READ_ID && rvalid_m_inf)) begin
				MAP_state[i][j] <= MAP_shift[i][j];
			end
			else begin
				MAP_state[i][j] <= MAP_state[i][j] || (avoid_target && cur_retrace_x == i && cur_retrace_y == j);
			end
		end
	end
end

for(i=0;i<63;i=i+1) begin : MAP_shift_in_i
	for(k=0;k<32;k=k+1) begin : MAP_shift_in_k
		always @ * begin
			MAP_shift[k][i] = MAP_state[k+32][i];
			MAP_shift[k+32][i] = MAP_state[k][i+1];
		end
	end
end
for(j=0;j<32;j=j+1) begin : MAP_shift_in_j
	always @ * begin
		MAP_shift[j][63] = MAP_state[j+32][63];
		MAP_shift[j+32][63] = |DRAM_data_split[j];
	end
end


for(i=1;i<63;i=i+1) begin : assign_MAP_filling_sidex
	always @ * begin
		MAP_filling[i][0] = MAP[i][0];
		MAP_filling[i][63] = MAP[i][63];
		if(MAP[i][0] == 'd0 && MAP_state[i][0] == 'd0) begin
			if(MAP[i+1][0] | MAP[i-1][0] | MAP[i][1]) begin
				MAP_filling[i][0] = cur_dir;
			end
		end
		if(MAP[i][63] == 'd0 && MAP_state[i][63] == 'd0) begin
			if(MAP[i+1][63] | MAP[i-1][63] | MAP[i][62]) begin
				MAP_filling[i][63] = cur_dir;
			end
		end
	end
end

for(i=1;i<63;i=i+1) begin : assign_MAP_filling_sidey
	always @ * begin
		MAP_filling[0][i] = MAP[0][i];
		MAP_filling[63][i] = MAP[63][i];
		if(MAP[0][i] == 'd0 && MAP_state[0][i] == 'd0) begin
			if(MAP[0][i+1] | MAP[0][i-1] | MAP[1][i]) begin
				MAP_filling[0][i] = cur_dir;
			end
		end
		if(MAP[63][i] == 'd0 && MAP_state[63][i] == 'd0) begin
			if(MAP[63][i+1] | MAP[63][i-1] | MAP[62][i]) begin
				MAP_filling[63][i] = cur_dir;
			end
		end
	end
end

always @ * begin
	MAP_filling[0][0] = MAP[0][0];
	MAP_filling[63][0] = MAP[63][0];
	MAP_filling[0][63] = MAP[0][63];
	MAP_filling[63][63] = MAP[63][63];
	if(MAP[0][0] == 'd0 && MAP_state[0][0] == 'd0) begin
		if(|(MAP[0][1] | MAP[1][0])) begin
			MAP_filling[0][0] = cur_dir;
		end
	end
	if(MAP[63][0] == 'd0 && MAP_state[63][0] == 'd0) begin
		if(|(MAP[63][1] | MAP[62][0])) begin
			MAP_filling[63][0] = cur_dir;
		end
	end
	if(MAP[0][63] == 'd0 && MAP_state[0][63] == 'd0) begin
		if(|(MAP[0][62] | MAP[1][63])) begin
			MAP_filling[0][63] = cur_dir;
		end
	end
	if(MAP[63][63] == 'd0 && MAP_state[63][63] == 'd0) begin
		if(|(MAP[62][63] | MAP[63][62])) begin
			MAP_filling[63][63] = cur_dir;
		end
	end
end

for(i=1;i<63;i=i+1) begin : assign_MAP_filling_i
	for(j=1;j<63;j=j+1) begin : assign_MAP_filling_j
		always @ * begin
			MAP_filling[i][j] = MAP[i][j];
			if(MAP[i][j] == 'd0 && MAP_state[i][j] == 'd0) begin
				if(|(MAP[i+1][j] | MAP[i-1][j] | MAP[i][j+1] | MAP[i][j-1])) begin
					MAP_filling[i][j] = cur_dir;
				end
			end
		end
	end
end

endgenerate

always @ * begin
	touch_end = 'd0;
	if(retrace_down | retrace_up | retrace_left | retrace_right) begin
		touch_end = 'd1;
	end
end

// -----------------------------
//			RETRACE
// -----------------------------
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) cur_dir <= 'd2;
	else begin
		if(state_comb == RETRACE || state == RETRACE) begin
			if(!retrace_cnt) begin
				case(cur_dir) // synopsys full_case
					'd1 : cur_dir <= 'd3;
					'd2 : cur_dir <= 'd1;
					'd3 : cur_dir <= 'd2;
				endcase
			end
			else begin
				cur_dir <= cur_dir;
			end
		end
		else if(state_comb == WAIT_WEIGHT || state == WAIT_WEIGHT) begin
			cur_dir <= cur_dir;
		end
		else if(state == FILLING_PATH) begin
			case(cur_dir) // synopsys full_case
				'd1 : cur_dir <= 'd2;
				'd2 : cur_dir <= 'd3;
				'd3 : cur_dir <= 'd1;
			endcase
		end
		else begin
			cur_dir <= 'd2;
		end
	end
end


always @ (posedge clk) begin
	if(state == RETRACE || avoid_target) begin
		retrace_cnt <= !retrace_cnt;
	end
	else begin
		retrace_cnt <= 'd0;
	end
end 

always @ (posedge clk) begin
	if(!retrace_cnt) begin
		cur_retrace_x <= cur_retrace_x_comb;
	end
	else begin
		cur_retrace_x <= cur_retrace_x;
	end
end
always @ (posedge clk) begin
	if(!retrace_cnt) begin
		cur_retrace_y <= cur_retrace_y_comb;
	end
	else begin
		cur_retrace_y <= cur_retrace_y;
	end
end


always @ * begin
	cur_retrace_x_comb = cur_target_x;
	cur_retrace_y_comb = cur_target_y;
	
	cur_retrace_x_left = (cur_retrace_x == 'd0) ? 'd0 : cur_retrace_x - 'd1;
	cur_retrace_x_right = (cur_retrace_x == 'd63) ? 'd63 : cur_retrace_x + 'd1;
	
	cur_retrace_y_up = (cur_retrace_y == 'd0) ? 'd0 : cur_retrace_y - 'd1;
	cur_retrace_y_down = (cur_retrace_y == 'd63) ? 'd63 : cur_retrace_y + 'd1;
	
	retrace_up = MAP[cur_retrace_x][cur_retrace_y_up];
	retrace_down = MAP[cur_retrace_x][cur_retrace_y_down];
	
	retrace_left = MAP[cur_retrace_x_left][cur_retrace_y];
	retrace_right = MAP[cur_retrace_x_right][cur_retrace_y];
	
	if(state == RETRACE) begin
		if(retrace_down == cur_dir) begin
			cur_retrace_y_comb = cur_retrace_y_down;
			cur_retrace_x_comb = cur_retrace_x;
		end
		else if(retrace_up == cur_dir) begin
			cur_retrace_y_comb = cur_retrace_y_up;
			cur_retrace_x_comb = cur_retrace_x;
		end
		else if(retrace_right == cur_dir) begin
			cur_retrace_x_comb = cur_retrace_x_right;
			cur_retrace_y_comb = cur_retrace_y;
		end
		else if(retrace_left == cur_dir) begin
			cur_retrace_x_comb = cur_retrace_x_left;
			cur_retrace_y_comb = cur_retrace_y;
		end
	end
end

wire up_case, down_case, left_case, right_case;
assign up_case = (cur_retrace_x == cur_source_x && cur_retrace_y_up == cur_source_y);
assign down_case = (cur_retrace_x == cur_source_x && cur_retrace_y_down == cur_source_y);
assign left_case = (cur_retrace_x_left == cur_source_x && cur_retrace_y == cur_source_y);
assign right_case = (cur_retrace_x_right == cur_source_x && cur_retrace_y == cur_source_y);

always @ * begin
	if(up_case || down_case || left_case || right_case) begin
		retrace_end = 'd1;
	end
	else begin
		retrace_end = 'd0;
	end
end

// -----------------------------
//			WRITE_BACK
// -----------------------------
reg [127:0] write_data_store, write_data_store2;
always @ * begin
WRITE_REQUEST = 'd0;
	if(state == CLEAN_MAP && state_comb == WRITE_BACK_N_ADD) begin
		WRITE_REQUEST = 'd1;
	end
end

reg tmp;
always @ (posedge clk) begin
	tmp <= (DRAM_data_count == 'd1);
end
always @ (posedge clk) begin
	if(awready_m_inf && awvalid_m_inf)		write_data_store <= ID_SRAM_DATA_OUT;
	else									write_data_store <= write_data_store;
end
always @ (posedge clk) begin
	if(tmp)									write_data_store2 <= ID_SRAM_DATA_OUT;
	else									write_data_store2 <= write_data_store2;
end
always @ * begin
	if(ID_SRAM_ADDR == 'd2) begin
		if(wready_m_inf) begin
			write_data = write_data_store2;
		end
		else begin
			write_data = write_data_store;
		end
	end
	else begin
		write_data = ID_SRAM_DATA_OUT;
	end
end


// -----------------------------
//		Calculate Cost
// -----------------------------
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cost <= 'd0;
	end
	else begin
		if(state == WAIT_ID) begin
			cost <= 'd0;
		end
		else begin
			cost <= cost + add_tmp;
		end
	end
end

always @ * begin
	add_tmp = 'd0;
	if(avoid_target && !retrace_cnt) begin
		add_tmp = WEIGHT_SRAM_DATA_OUT_split[cur_retrace_x[4:0]];
	end
end

generate
for(i=0;i<32;i=i+1) begin: SRAM_WEIGHT_split
	assign WEIGHT_SRAM_DATA_OUT_split[i] = WEIGHT_SRAM_DATA_OUT[4*i+3:4*i];
end
endgenerate
// -----------------------------
//			SRAM
// -----------------------------	
reg [3:0] cur_net_delay;

always @ (posedge clk) begin
	cur_net_delay <= cur_net;
end

always @ * begin
ID_SRAM_ADDR = 0;
	if(DRAM_state == READ_ID) begin
		ID_SRAM_ADDR = DRAM_data_count;
	end
	else if(state == RETRACE || avoid_target) begin
		ID_SRAM_ADDR = cur_retrace_y << 1;
		if(cur_retrace_x >= 32) begin
			ID_SRAM_ADDR = ID_SRAM_ADDR + 1;
		end
	end
	else if(state == WRITE_BACK_N_ADD) begin
		ID_SRAM_ADDR = DRAM_data_count;
	end

WEIGHT_SRAM_DATA_WR = 'd1;	
WEIGHT_SRAM_ADDR    = 'd0;
WEIGHT_SRAM_DATA_IN = 'd0;
	if(DRAM_state == READ_WEIGHT) begin
		WEIGHT_SRAM_ADDR = DRAM_data_count;
		WEIGHT_SRAM_DATA_WR = 0;
		WEIGHT_SRAM_DATA_IN = rdata_m_inf;
	end
	else if(state == RETRACE || avoid_target) begin
		WEIGHT_SRAM_ADDR = cur_retrace_y << 1;
		if(cur_retrace_x >= 32) begin
			WEIGHT_SRAM_ADDR = WEIGHT_SRAM_ADDR + 1;
		end
	end
	
	
end

generate
for(i=0;i<32;i=i+1) begin
	always @ * begin
		ID_SRAM_DATA_IN[4*i+3:4*i] = 'd0;
		if(DRAM_state == READ_ID) begin
			ID_SRAM_DATA_IN[4*i+3:4*i] = rdata_m_inf[4*i+3:4*i];
		end
		else if(avoid_target) begin
			if(cur_retrace_x[4:0] == i)
				ID_SRAM_DATA_IN[4*i+3:4*i] = cur_net_delay;
			else
				ID_SRAM_DATA_IN[4*i+3:4*i] = ID_SRAM_DATA_OUT[4*i+3:4*i];
		end
	end
end
endgenerate

always @ * begin	
	ID_SRAM_DATA_WR = 1;
	if(DRAM_state == READ_ID) begin
		ID_SRAM_DATA_WR = 'd0;
	end
	else if(avoid_target) begin
		if(!retrace_cnt)
			ID_SRAM_DATA_WR = 'd0;
		else 
			ID_SRAM_DATA_WR = 'd1;
	end
end


MAP_WEIGHT_SRAM_128w_128b ID_SRAM(		.A0(ID_SRAM_ADDR[0]), .A1(ID_SRAM_ADDR[1]), .A2(ID_SRAM_ADDR[2]), .A3(ID_SRAM_ADDR[3]),
										.A4(ID_SRAM_ADDR[4]), .A5(ID_SRAM_ADDR[5]), .A6(ID_SRAM_ADDR[6]),
										.DO0(ID_SRAM_DATA_OUT[0]), .DO1(ID_SRAM_DATA_OUT[1]), .DO2(ID_SRAM_DATA_OUT[2]), .DO3(ID_SRAM_DATA_OUT[3]),
										.DO4(ID_SRAM_DATA_OUT[4]), .DO5(ID_SRAM_DATA_OUT[5]), .DO6(ID_SRAM_DATA_OUT[6]), .DO7(ID_SRAM_DATA_OUT[7]),
										.DO8(ID_SRAM_DATA_OUT[8]), .DO9(ID_SRAM_DATA_OUT[9]), .DO10(ID_SRAM_DATA_OUT[10]), .DO11(ID_SRAM_DATA_OUT[11]),
										.DO12(ID_SRAM_DATA_OUT[12]), .DO13(ID_SRAM_DATA_OUT[13]), .DO14(ID_SRAM_DATA_OUT[14]), .DO15(ID_SRAM_DATA_OUT[15]),
										.DO16(ID_SRAM_DATA_OUT[16]), .DO17(ID_SRAM_DATA_OUT[17]), .DO18(ID_SRAM_DATA_OUT[18]), .DO19(ID_SRAM_DATA_OUT[19]),
										.DO20(ID_SRAM_DATA_OUT[20]), .DO21(ID_SRAM_DATA_OUT[21]), .DO22(ID_SRAM_DATA_OUT[22]), .DO23(ID_SRAM_DATA_OUT[23]),
										.DO24(ID_SRAM_DATA_OUT[24]), .DO25(ID_SRAM_DATA_OUT[25]), .DO26(ID_SRAM_DATA_OUT[26]), .DO27(ID_SRAM_DATA_OUT[27]),
										.DO28(ID_SRAM_DATA_OUT[28]), .DO29(ID_SRAM_DATA_OUT[29]), .DO30(ID_SRAM_DATA_OUT[30]), .DO31(ID_SRAM_DATA_OUT[31]),
										.DO32(ID_SRAM_DATA_OUT[32]), .DO33(ID_SRAM_DATA_OUT[33]), .DO34(ID_SRAM_DATA_OUT[34]), .DO35(ID_SRAM_DATA_OUT[35]),
										.DO36(ID_SRAM_DATA_OUT[36]), .DO37(ID_SRAM_DATA_OUT[37]), .DO38(ID_SRAM_DATA_OUT[38]), .DO39(ID_SRAM_DATA_OUT[39]),
										.DO40(ID_SRAM_DATA_OUT[40]), .DO41(ID_SRAM_DATA_OUT[41]), .DO42(ID_SRAM_DATA_OUT[42]), .DO43(ID_SRAM_DATA_OUT[43]),
										.DO44(ID_SRAM_DATA_OUT[44]), .DO45(ID_SRAM_DATA_OUT[45]), .DO46(ID_SRAM_DATA_OUT[46]), .DO47(ID_SRAM_DATA_OUT[47]),
										.DO48(ID_SRAM_DATA_OUT[48]), .DO49(ID_SRAM_DATA_OUT[49]), .DO50(ID_SRAM_DATA_OUT[50]), .DO51(ID_SRAM_DATA_OUT[51]),
										.DO52(ID_SRAM_DATA_OUT[52]), .DO53(ID_SRAM_DATA_OUT[53]), .DO54(ID_SRAM_DATA_OUT[54]), .DO55(ID_SRAM_DATA_OUT[55]),
										.DO56(ID_SRAM_DATA_OUT[56]), .DO57(ID_SRAM_DATA_OUT[57]), .DO58(ID_SRAM_DATA_OUT[58]), .DO59(ID_SRAM_DATA_OUT[59]),
										.DO60(ID_SRAM_DATA_OUT[60]), .DO61(ID_SRAM_DATA_OUT[61]), .DO62(ID_SRAM_DATA_OUT[62]), .DO63(ID_SRAM_DATA_OUT[63]),
										.DO64(ID_SRAM_DATA_OUT[64]), .DO65(ID_SRAM_DATA_OUT[65]), .DO66(ID_SRAM_DATA_OUT[66]), .DO67(ID_SRAM_DATA_OUT[67]),
										.DO68(ID_SRAM_DATA_OUT[68]), .DO69(ID_SRAM_DATA_OUT[69]), .DO70(ID_SRAM_DATA_OUT[70]), .DO71(ID_SRAM_DATA_OUT[71]),
										.DO72(ID_SRAM_DATA_OUT[72]), .DO73(ID_SRAM_DATA_OUT[73]), .DO74(ID_SRAM_DATA_OUT[74]), .DO75(ID_SRAM_DATA_OUT[75]),
										.DO76(ID_SRAM_DATA_OUT[76]), .DO77(ID_SRAM_DATA_OUT[77]), .DO78(ID_SRAM_DATA_OUT[78]), .DO79(ID_SRAM_DATA_OUT[79]),
										.DO80(ID_SRAM_DATA_OUT[80]), .DO81(ID_SRAM_DATA_OUT[81]), .DO82(ID_SRAM_DATA_OUT[82]), .DO83(ID_SRAM_DATA_OUT[83]),
										.DO84(ID_SRAM_DATA_OUT[84]), .DO85(ID_SRAM_DATA_OUT[85]), .DO86(ID_SRAM_DATA_OUT[86]), .DO87(ID_SRAM_DATA_OUT[87]),
										.DO88(ID_SRAM_DATA_OUT[88]), .DO89(ID_SRAM_DATA_OUT[89]), .DO90(ID_SRAM_DATA_OUT[90]), .DO91(ID_SRAM_DATA_OUT[91]),
										.DO92(ID_SRAM_DATA_OUT[92]), .DO93(ID_SRAM_DATA_OUT[93]), .DO94(ID_SRAM_DATA_OUT[94]), .DO95(ID_SRAM_DATA_OUT[95]),
										.DO96(ID_SRAM_DATA_OUT[96]), .DO97(ID_SRAM_DATA_OUT[97]), .DO98(ID_SRAM_DATA_OUT[98]), .DO99(ID_SRAM_DATA_OUT[99]),
										.DO100(ID_SRAM_DATA_OUT[100]), .DO101(ID_SRAM_DATA_OUT[101]), .DO102(ID_SRAM_DATA_OUT[102]), .DO103(ID_SRAM_DATA_OUT[103]),
										.DO104(ID_SRAM_DATA_OUT[104]), .DO105(ID_SRAM_DATA_OUT[105]), .DO106(ID_SRAM_DATA_OUT[106]), .DO107(ID_SRAM_DATA_OUT[107]),
										.DO108(ID_SRAM_DATA_OUT[108]), .DO109(ID_SRAM_DATA_OUT[109]), .DO110(ID_SRAM_DATA_OUT[110]), .DO111(ID_SRAM_DATA_OUT[111]),
										.DO112(ID_SRAM_DATA_OUT[112]), .DO113(ID_SRAM_DATA_OUT[113]), .DO114(ID_SRAM_DATA_OUT[114]), .DO115(ID_SRAM_DATA_OUT[115]),
										.DO116(ID_SRAM_DATA_OUT[116]), .DO117(ID_SRAM_DATA_OUT[117]), .DO118(ID_SRAM_DATA_OUT[118]), .DO119(ID_SRAM_DATA_OUT[119]),
										.DO120(ID_SRAM_DATA_OUT[120]), .DO121(ID_SRAM_DATA_OUT[121]), .DO122(ID_SRAM_DATA_OUT[122]), .DO123(ID_SRAM_DATA_OUT[123]),
										.DO124(ID_SRAM_DATA_OUT[124]), .DO125(ID_SRAM_DATA_OUT[125]), .DO126(ID_SRAM_DATA_OUT[126]), .DO127(ID_SRAM_DATA_OUT[127]),
										.DI0(ID_SRAM_DATA_IN[0]), .DI1(ID_SRAM_DATA_IN[1]), .DI2(ID_SRAM_DATA_IN[2]), .DI3(ID_SRAM_DATA_IN[3]),
										.DI4(ID_SRAM_DATA_IN[4]), .DI5(ID_SRAM_DATA_IN[5]), .DI6(ID_SRAM_DATA_IN[6]), .DI7(ID_SRAM_DATA_IN[7]),
										.DI8(ID_SRAM_DATA_IN[8]), .DI9(ID_SRAM_DATA_IN[9]), .DI10(ID_SRAM_DATA_IN[10]), .DI11(ID_SRAM_DATA_IN[11]),
										.DI12(ID_SRAM_DATA_IN[12]), .DI13(ID_SRAM_DATA_IN[13]), .DI14(ID_SRAM_DATA_IN[14]), .DI15(ID_SRAM_DATA_IN[15]),
										.DI16(ID_SRAM_DATA_IN[16]), .DI17(ID_SRAM_DATA_IN[17]), .DI18(ID_SRAM_DATA_IN[18]), .DI19(ID_SRAM_DATA_IN[19]),
										.DI20(ID_SRAM_DATA_IN[20]), .DI21(ID_SRAM_DATA_IN[21]), .DI22(ID_SRAM_DATA_IN[22]), .DI23(ID_SRAM_DATA_IN[23]),
										.DI24(ID_SRAM_DATA_IN[24]), .DI25(ID_SRAM_DATA_IN[25]), .DI26(ID_SRAM_DATA_IN[26]), .DI27(ID_SRAM_DATA_IN[27]),
										.DI28(ID_SRAM_DATA_IN[28]), .DI29(ID_SRAM_DATA_IN[29]), .DI30(ID_SRAM_DATA_IN[30]), .DI31(ID_SRAM_DATA_IN[31]),
										.DI32(ID_SRAM_DATA_IN[32]), .DI33(ID_SRAM_DATA_IN[33]), .DI34(ID_SRAM_DATA_IN[34]), .DI35(ID_SRAM_DATA_IN[35]),
										.DI36(ID_SRAM_DATA_IN[36]), .DI37(ID_SRAM_DATA_IN[37]), .DI38(ID_SRAM_DATA_IN[38]), .DI39(ID_SRAM_DATA_IN[39]),
										.DI40(ID_SRAM_DATA_IN[40]), .DI41(ID_SRAM_DATA_IN[41]), .DI42(ID_SRAM_DATA_IN[42]), .DI43(ID_SRAM_DATA_IN[43]),
										.DI44(ID_SRAM_DATA_IN[44]), .DI45(ID_SRAM_DATA_IN[45]), .DI46(ID_SRAM_DATA_IN[46]), .DI47(ID_SRAM_DATA_IN[47]),
										.DI48(ID_SRAM_DATA_IN[48]), .DI49(ID_SRAM_DATA_IN[49]), .DI50(ID_SRAM_DATA_IN[50]), .DI51(ID_SRAM_DATA_IN[51]),
										.DI52(ID_SRAM_DATA_IN[52]), .DI53(ID_SRAM_DATA_IN[53]), .DI54(ID_SRAM_DATA_IN[54]), .DI55(ID_SRAM_DATA_IN[55]),
										.DI56(ID_SRAM_DATA_IN[56]), .DI57(ID_SRAM_DATA_IN[57]), .DI58(ID_SRAM_DATA_IN[58]), .DI59(ID_SRAM_DATA_IN[59]),
										.DI60(ID_SRAM_DATA_IN[60]), .DI61(ID_SRAM_DATA_IN[61]), .DI62(ID_SRAM_DATA_IN[62]), .DI63(ID_SRAM_DATA_IN[63]),
										.DI64(ID_SRAM_DATA_IN[64]), .DI65(ID_SRAM_DATA_IN[65]), .DI66(ID_SRAM_DATA_IN[66]), .DI67(ID_SRAM_DATA_IN[67]),
										.DI68(ID_SRAM_DATA_IN[68]), .DI69(ID_SRAM_DATA_IN[69]), .DI70(ID_SRAM_DATA_IN[70]), .DI71(ID_SRAM_DATA_IN[71]),
										.DI72(ID_SRAM_DATA_IN[72]), .DI73(ID_SRAM_DATA_IN[73]), .DI74(ID_SRAM_DATA_IN[74]), .DI75(ID_SRAM_DATA_IN[75]),
										.DI76(ID_SRAM_DATA_IN[76]), .DI77(ID_SRAM_DATA_IN[77]), .DI78(ID_SRAM_DATA_IN[78]), .DI79(ID_SRAM_DATA_IN[79]),
										.DI80(ID_SRAM_DATA_IN[80]), .DI81(ID_SRAM_DATA_IN[81]), .DI82(ID_SRAM_DATA_IN[82]), .DI83(ID_SRAM_DATA_IN[83]),
										.DI84(ID_SRAM_DATA_IN[84]), .DI85(ID_SRAM_DATA_IN[85]), .DI86(ID_SRAM_DATA_IN[86]), .DI87(ID_SRAM_DATA_IN[87]),
										.DI88(ID_SRAM_DATA_IN[88]), .DI89(ID_SRAM_DATA_IN[89]), .DI90(ID_SRAM_DATA_IN[90]), .DI91(ID_SRAM_DATA_IN[91]),
										.DI92(ID_SRAM_DATA_IN[92]), .DI93(ID_SRAM_DATA_IN[93]), .DI94(ID_SRAM_DATA_IN[94]), .DI95(ID_SRAM_DATA_IN[95]),
										.DI96(ID_SRAM_DATA_IN[96]), .DI97(ID_SRAM_DATA_IN[97]), .DI98(ID_SRAM_DATA_IN[98]), .DI99(ID_SRAM_DATA_IN[99]),
										.DI100(ID_SRAM_DATA_IN[100]), .DI101(ID_SRAM_DATA_IN[101]), .DI102(ID_SRAM_DATA_IN[102]), .DI103(ID_SRAM_DATA_IN[103]),
										.DI104(ID_SRAM_DATA_IN[104]), .DI105(ID_SRAM_DATA_IN[105]), .DI106(ID_SRAM_DATA_IN[106]), .DI107(ID_SRAM_DATA_IN[107]),
										.DI108(ID_SRAM_DATA_IN[108]), .DI109(ID_SRAM_DATA_IN[109]), .DI110(ID_SRAM_DATA_IN[110]), .DI111(ID_SRAM_DATA_IN[111]),
										.DI112(ID_SRAM_DATA_IN[112]), .DI113(ID_SRAM_DATA_IN[113]), .DI114(ID_SRAM_DATA_IN[114]), .DI115(ID_SRAM_DATA_IN[115]),
										.DI116(ID_SRAM_DATA_IN[116]), .DI117(ID_SRAM_DATA_IN[117]), .DI118(ID_SRAM_DATA_IN[118]), .DI119(ID_SRAM_DATA_IN[119]),
										.DI120(ID_SRAM_DATA_IN[120]), .DI121(ID_SRAM_DATA_IN[121]), .DI122(ID_SRAM_DATA_IN[122]), .DI123(ID_SRAM_DATA_IN[123]),
										.DI124(ID_SRAM_DATA_IN[124]), .DI125(ID_SRAM_DATA_IN[125]), .DI126(ID_SRAM_DATA_IN[126]), .DI127(ID_SRAM_DATA_IN[127]),
										.CK(clk), .WEB(ID_SRAM_DATA_WR), .OE(1'b1), .CS(1'b1));


MAP_WEIGHT_SRAM_128w_128b WEIGHT_SRAM(	.A0(WEIGHT_SRAM_ADDR[0]), .A1(WEIGHT_SRAM_ADDR[1]), .A2(WEIGHT_SRAM_ADDR[2]),
										.A3(WEIGHT_SRAM_ADDR[3]), .A4(WEIGHT_SRAM_ADDR[4]), .A5(WEIGHT_SRAM_ADDR[5]),
										.A6(WEIGHT_SRAM_ADDR[6]),
										.DO0(WEIGHT_SRAM_DATA_OUT[0]), .DO1(WEIGHT_SRAM_DATA_OUT[1]), .DO2(WEIGHT_SRAM_DATA_OUT[2]),
										.DO3(WEIGHT_SRAM_DATA_OUT[3]), .DO4(WEIGHT_SRAM_DATA_OUT[4]), .DO5(WEIGHT_SRAM_DATA_OUT[5]),
										.DO6(WEIGHT_SRAM_DATA_OUT[6]), .DO7(WEIGHT_SRAM_DATA_OUT[7]), .DO8(WEIGHT_SRAM_DATA_OUT[8]),
										.DO9(WEIGHT_SRAM_DATA_OUT[9]), .DO10(WEIGHT_SRAM_DATA_OUT[10]), .DO11(WEIGHT_SRAM_DATA_OUT[11]),
										.DO12(WEIGHT_SRAM_DATA_OUT[12]), .DO13(WEIGHT_SRAM_DATA_OUT[13]), .DO14(WEIGHT_SRAM_DATA_OUT[14]),
										.DO15(WEIGHT_SRAM_DATA_OUT[15]), .DO16(WEIGHT_SRAM_DATA_OUT[16]), .DO17(WEIGHT_SRAM_DATA_OUT[17]),
										.DO18(WEIGHT_SRAM_DATA_OUT[18]), .DO19(WEIGHT_SRAM_DATA_OUT[19]), .DO20(WEIGHT_SRAM_DATA_OUT[20]),
										.DO21(WEIGHT_SRAM_DATA_OUT[21]), .DO22(WEIGHT_SRAM_DATA_OUT[22]), .DO23(WEIGHT_SRAM_DATA_OUT[23]),
										.DO24(WEIGHT_SRAM_DATA_OUT[24]), .DO25(WEIGHT_SRAM_DATA_OUT[25]), .DO26(WEIGHT_SRAM_DATA_OUT[26]),
										.DO27(WEIGHT_SRAM_DATA_OUT[27]), .DO28(WEIGHT_SRAM_DATA_OUT[28]), .DO29(WEIGHT_SRAM_DATA_OUT[29]),
										.DO30(WEIGHT_SRAM_DATA_OUT[30]), .DO31(WEIGHT_SRAM_DATA_OUT[31]), .DO32(WEIGHT_SRAM_DATA_OUT[32]),
										.DO33(WEIGHT_SRAM_DATA_OUT[33]), .DO34(WEIGHT_SRAM_DATA_OUT[34]), .DO35(WEIGHT_SRAM_DATA_OUT[35]),
										.DO36(WEIGHT_SRAM_DATA_OUT[36]), .DO37(WEIGHT_SRAM_DATA_OUT[37]), .DO38(WEIGHT_SRAM_DATA_OUT[38]),
										.DO39(WEIGHT_SRAM_DATA_OUT[39]), .DO40(WEIGHT_SRAM_DATA_OUT[40]), .DO41(WEIGHT_SRAM_DATA_OUT[41]),
										.DO42(WEIGHT_SRAM_DATA_OUT[42]), .DO43(WEIGHT_SRAM_DATA_OUT[43]), .DO44(WEIGHT_SRAM_DATA_OUT[44]),
										.DO45(WEIGHT_SRAM_DATA_OUT[45]), .DO46(WEIGHT_SRAM_DATA_OUT[46]), .DO47(WEIGHT_SRAM_DATA_OUT[47]),
										.DO48(WEIGHT_SRAM_DATA_OUT[48]), .DO49(WEIGHT_SRAM_DATA_OUT[49]), .DO50(WEIGHT_SRAM_DATA_OUT[50]),
										.DO51(WEIGHT_SRAM_DATA_OUT[51]), .DO52(WEIGHT_SRAM_DATA_OUT[52]), .DO53(WEIGHT_SRAM_DATA_OUT[53]),
										.DO54(WEIGHT_SRAM_DATA_OUT[54]), .DO55(WEIGHT_SRAM_DATA_OUT[55]), .DO56(WEIGHT_SRAM_DATA_OUT[56]),
										.DO57(WEIGHT_SRAM_DATA_OUT[57]), .DO58(WEIGHT_SRAM_DATA_OUT[58]), .DO59(WEIGHT_SRAM_DATA_OUT[59]),
										.DO60(WEIGHT_SRAM_DATA_OUT[60]), .DO61(WEIGHT_SRAM_DATA_OUT[61]), .DO62(WEIGHT_SRAM_DATA_OUT[62]),
										.DO63(WEIGHT_SRAM_DATA_OUT[63]), .DO64(WEIGHT_SRAM_DATA_OUT[64]), .DO65(WEIGHT_SRAM_DATA_OUT[65]),
										.DO66(WEIGHT_SRAM_DATA_OUT[66]), .DO67(WEIGHT_SRAM_DATA_OUT[67]), .DO68(WEIGHT_SRAM_DATA_OUT[68]),
										.DO69(WEIGHT_SRAM_DATA_OUT[69]), .DO70(WEIGHT_SRAM_DATA_OUT[70]), .DO71(WEIGHT_SRAM_DATA_OUT[71]),
										.DO72(WEIGHT_SRAM_DATA_OUT[72]), .DO73(WEIGHT_SRAM_DATA_OUT[73]), .DO74(WEIGHT_SRAM_DATA_OUT[74]),
										.DO75(WEIGHT_SRAM_DATA_OUT[75]), .DO76(WEIGHT_SRAM_DATA_OUT[76]), .DO77(WEIGHT_SRAM_DATA_OUT[77]),
										.DO78(WEIGHT_SRAM_DATA_OUT[78]), .DO79(WEIGHT_SRAM_DATA_OUT[79]), .DO80(WEIGHT_SRAM_DATA_OUT[80]),
										.DO81(WEIGHT_SRAM_DATA_OUT[81]), .DO82(WEIGHT_SRAM_DATA_OUT[82]), .DO83(WEIGHT_SRAM_DATA_OUT[83]),
										.DO84(WEIGHT_SRAM_DATA_OUT[84]), .DO85(WEIGHT_SRAM_DATA_OUT[85]), .DO86(WEIGHT_SRAM_DATA_OUT[86]),
										.DO87(WEIGHT_SRAM_DATA_OUT[87]), .DO88(WEIGHT_SRAM_DATA_OUT[88]), .DO89(WEIGHT_SRAM_DATA_OUT[89]),
										.DO90(WEIGHT_SRAM_DATA_OUT[90]), .DO91(WEIGHT_SRAM_DATA_OUT[91]), .DO92(WEIGHT_SRAM_DATA_OUT[92]),
										.DO93(WEIGHT_SRAM_DATA_OUT[93]), .DO94(WEIGHT_SRAM_DATA_OUT[94]), .DO95(WEIGHT_SRAM_DATA_OUT[95]),
										.DO96(WEIGHT_SRAM_DATA_OUT[96]), .DO97(WEIGHT_SRAM_DATA_OUT[97]), .DO98(WEIGHT_SRAM_DATA_OUT[98]),
										.DO99(WEIGHT_SRAM_DATA_OUT[99]), .DO100(WEIGHT_SRAM_DATA_OUT[100]), .DO101(WEIGHT_SRAM_DATA_OUT[101]),
										.DO102(WEIGHT_SRAM_DATA_OUT[102]), .DO103(WEIGHT_SRAM_DATA_OUT[103]), .DO104(WEIGHT_SRAM_DATA_OUT[104]),
										.DO105(WEIGHT_SRAM_DATA_OUT[105]), .DO106(WEIGHT_SRAM_DATA_OUT[106]), .DO107(WEIGHT_SRAM_DATA_OUT[107]),
										.DO108(WEIGHT_SRAM_DATA_OUT[108]), .DO109(WEIGHT_SRAM_DATA_OUT[109]), .DO110(WEIGHT_SRAM_DATA_OUT[110]),
										.DO111(WEIGHT_SRAM_DATA_OUT[111]), .DO112(WEIGHT_SRAM_DATA_OUT[112]), .DO113(WEIGHT_SRAM_DATA_OUT[113]),
										.DO114(WEIGHT_SRAM_DATA_OUT[114]), .DO115(WEIGHT_SRAM_DATA_OUT[115]), .DO116(WEIGHT_SRAM_DATA_OUT[116]),
										.DO117(WEIGHT_SRAM_DATA_OUT[117]), .DO118(WEIGHT_SRAM_DATA_OUT[118]), .DO119(WEIGHT_SRAM_DATA_OUT[119]),
										.DO120(WEIGHT_SRAM_DATA_OUT[120]), .DO121(WEIGHT_SRAM_DATA_OUT[121]), .DO122(WEIGHT_SRAM_DATA_OUT[122]),
										.DO123(WEIGHT_SRAM_DATA_OUT[123]), .DO124(WEIGHT_SRAM_DATA_OUT[124]), .DO125(WEIGHT_SRAM_DATA_OUT[125]),
										.DO126(WEIGHT_SRAM_DATA_OUT[126]), .DO127(WEIGHT_SRAM_DATA_OUT[127]),
										.DI0(WEIGHT_SRAM_DATA_IN[0]), .DI1(WEIGHT_SRAM_DATA_IN[1]), .DI2(WEIGHT_SRAM_DATA_IN[2]),
										.DI3(WEIGHT_SRAM_DATA_IN[3]), .DI4(WEIGHT_SRAM_DATA_IN[4]), .DI5(WEIGHT_SRAM_DATA_IN[5]),
										.DI6(WEIGHT_SRAM_DATA_IN[6]), .DI7(WEIGHT_SRAM_DATA_IN[7]), .DI8(WEIGHT_SRAM_DATA_IN[8]),
										.DI9(WEIGHT_SRAM_DATA_IN[9]), .DI10(WEIGHT_SRAM_DATA_IN[10]), .DI11(WEIGHT_SRAM_DATA_IN[11]),
										.DI12(WEIGHT_SRAM_DATA_IN[12]), .DI13(WEIGHT_SRAM_DATA_IN[13]), .DI14(WEIGHT_SRAM_DATA_IN[14]),
										.DI15(WEIGHT_SRAM_DATA_IN[15]), .DI16(WEIGHT_SRAM_DATA_IN[16]), .DI17(WEIGHT_SRAM_DATA_IN[17]),
										.DI18(WEIGHT_SRAM_DATA_IN[18]), .DI19(WEIGHT_SRAM_DATA_IN[19]), .DI20(WEIGHT_SRAM_DATA_IN[20]),
										.DI21(WEIGHT_SRAM_DATA_IN[21]), .DI22(WEIGHT_SRAM_DATA_IN[22]), .DI23(WEIGHT_SRAM_DATA_IN[23]),
										.DI24(WEIGHT_SRAM_DATA_IN[24]), .DI25(WEIGHT_SRAM_DATA_IN[25]), .DI26(WEIGHT_SRAM_DATA_IN[26]),
										.DI27(WEIGHT_SRAM_DATA_IN[27]), .DI28(WEIGHT_SRAM_DATA_IN[28]), .DI29(WEIGHT_SRAM_DATA_IN[29]),
										.DI30(WEIGHT_SRAM_DATA_IN[30]), .DI31(WEIGHT_SRAM_DATA_IN[31]), .DI32(WEIGHT_SRAM_DATA_IN[32]),
										.DI33(WEIGHT_SRAM_DATA_IN[33]), .DI34(WEIGHT_SRAM_DATA_IN[34]), .DI35(WEIGHT_SRAM_DATA_IN[35]),
										.DI36(WEIGHT_SRAM_DATA_IN[36]), .DI37(WEIGHT_SRAM_DATA_IN[37]), .DI38(WEIGHT_SRAM_DATA_IN[38]),
										.DI39(WEIGHT_SRAM_DATA_IN[39]), .DI40(WEIGHT_SRAM_DATA_IN[40]), .DI41(WEIGHT_SRAM_DATA_IN[41]),
										.DI42(WEIGHT_SRAM_DATA_IN[42]), .DI43(WEIGHT_SRAM_DATA_IN[43]), .DI44(WEIGHT_SRAM_DATA_IN[44]),
										.DI45(WEIGHT_SRAM_DATA_IN[45]), .DI46(WEIGHT_SRAM_DATA_IN[46]), .DI47(WEIGHT_SRAM_DATA_IN[47]),
										.DI48(WEIGHT_SRAM_DATA_IN[48]), .DI49(WEIGHT_SRAM_DATA_IN[49]), .DI50(WEIGHT_SRAM_DATA_IN[50]),
										.DI51(WEIGHT_SRAM_DATA_IN[51]), .DI52(WEIGHT_SRAM_DATA_IN[52]), .DI53(WEIGHT_SRAM_DATA_IN[53]),
										.DI54(WEIGHT_SRAM_DATA_IN[54]), .DI55(WEIGHT_SRAM_DATA_IN[55]), .DI56(WEIGHT_SRAM_DATA_IN[56]),
										.DI57(WEIGHT_SRAM_DATA_IN[57]), .DI58(WEIGHT_SRAM_DATA_IN[58]), .DI59(WEIGHT_SRAM_DATA_IN[59]),
										.DI60(WEIGHT_SRAM_DATA_IN[60]), .DI61(WEIGHT_SRAM_DATA_IN[61]), .DI62(WEIGHT_SRAM_DATA_IN[62]),
										.DI63(WEIGHT_SRAM_DATA_IN[63]), .DI64(WEIGHT_SRAM_DATA_IN[64]), .DI65(WEIGHT_SRAM_DATA_IN[65]),
										.DI66(WEIGHT_SRAM_DATA_IN[66]), .DI67(WEIGHT_SRAM_DATA_IN[67]), .DI68(WEIGHT_SRAM_DATA_IN[68]),
										.DI69(WEIGHT_SRAM_DATA_IN[69]), .DI70(WEIGHT_SRAM_DATA_IN[70]), .DI71(WEIGHT_SRAM_DATA_IN[71]),
										.DI72(WEIGHT_SRAM_DATA_IN[72]), .DI73(WEIGHT_SRAM_DATA_IN[73]), .DI74(WEIGHT_SRAM_DATA_IN[74]),
										.DI75(WEIGHT_SRAM_DATA_IN[75]), .DI76(WEIGHT_SRAM_DATA_IN[76]), .DI77(WEIGHT_SRAM_DATA_IN[77]),
										.DI78(WEIGHT_SRAM_DATA_IN[78]), .DI79(WEIGHT_SRAM_DATA_IN[79]), .DI80(WEIGHT_SRAM_DATA_IN[80]),
										.DI81(WEIGHT_SRAM_DATA_IN[81]), .DI82(WEIGHT_SRAM_DATA_IN[82]), .DI83(WEIGHT_SRAM_DATA_IN[83]),
										.DI84(WEIGHT_SRAM_DATA_IN[84]), .DI85(WEIGHT_SRAM_DATA_IN[85]), .DI86(WEIGHT_SRAM_DATA_IN[86]),
										.DI87(WEIGHT_SRAM_DATA_IN[87]), .DI88(WEIGHT_SRAM_DATA_IN[88]), .DI89(WEIGHT_SRAM_DATA_IN[89]),
										.DI90(WEIGHT_SRAM_DATA_IN[90]), .DI91(WEIGHT_SRAM_DATA_IN[91]), .DI92(WEIGHT_SRAM_DATA_IN[92]),
										.DI93(WEIGHT_SRAM_DATA_IN[93]), .DI94(WEIGHT_SRAM_DATA_IN[94]), .DI95(WEIGHT_SRAM_DATA_IN[95]),
										.DI96(WEIGHT_SRAM_DATA_IN[96]), .DI97(WEIGHT_SRAM_DATA_IN[97]), .DI98(WEIGHT_SRAM_DATA_IN[98]),
										.DI99(WEIGHT_SRAM_DATA_IN[99]), .DI100(WEIGHT_SRAM_DATA_IN[100]), .DI101(WEIGHT_SRAM_DATA_IN[101]),
										.DI102(WEIGHT_SRAM_DATA_IN[102]), .DI103(WEIGHT_SRAM_DATA_IN[103]), .DI104(WEIGHT_SRAM_DATA_IN[104]),
										.DI105(WEIGHT_SRAM_DATA_IN[105]), .DI106(WEIGHT_SRAM_DATA_IN[106]), .DI107(WEIGHT_SRAM_DATA_IN[107]),
										.DI108(WEIGHT_SRAM_DATA_IN[108]), .DI109(WEIGHT_SRAM_DATA_IN[109]), .DI110(WEIGHT_SRAM_DATA_IN[110]),
										.DI111(WEIGHT_SRAM_DATA_IN[111]), .DI112(WEIGHT_SRAM_DATA_IN[112]), .DI113(WEIGHT_SRAM_DATA_IN[113]),
										.DI114(WEIGHT_SRAM_DATA_IN[114]), .DI115(WEIGHT_SRAM_DATA_IN[115]), .DI116(WEIGHT_SRAM_DATA_IN[116]),
										.DI117(WEIGHT_SRAM_DATA_IN[117]), .DI118(WEIGHT_SRAM_DATA_IN[118]), .DI119(WEIGHT_SRAM_DATA_IN[119]),
										.DI120(WEIGHT_SRAM_DATA_IN[120]), .DI121(WEIGHT_SRAM_DATA_IN[121]), .DI122(WEIGHT_SRAM_DATA_IN[122]),
										.DI123(WEIGHT_SRAM_DATA_IN[123]), .DI124(WEIGHT_SRAM_DATA_IN[124]), .DI125(WEIGHT_SRAM_DATA_IN[125]),
										.DI126(WEIGHT_SRAM_DATA_IN[126]), .DI127(WEIGHT_SRAM_DATA_IN[127]),
										.CK(clk), .WEB(WEIGHT_SRAM_DATA_WR), .OE(1'b1), .CS(1'b1));

endmodule





module AXI4_interface #(parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32)(
	// Input
	clk, rst_n,
	read_addr, write_addr,
	write_data,
	READ_REQUEST, WRITE_REQUEST,
	write_last_count,
	// AXI4 IO
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
	   bready_m_inf 
);

input clk;
input rst_n;
input [ADDR_WIDTH-1 : 0] read_addr;
input [ADDR_WIDTH-1 : 0] write_addr;
input READ_REQUEST, WRITE_REQUEST;
input [DATA_WIDTH-1:0] write_data;
input [6:0] write_last_count;
// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)	axi read address channel 
output wire [ID_WIDTH-1:0]      arid_m_inf;
output wire [1:0]            arburst_m_inf;
output wire [2:0]             arsize_m_inf;
output wire [7:0]              arlen_m_inf;
output reg                  arvalid_m_inf;
input  wire                  arready_m_inf;
output reg [ADDR_WIDTH-1:0]  araddr_m_inf;
// ------------------------
// (2)	axi read data channel 
input  wire [ID_WIDTH-1:0]       rid_m_inf;
input  wire                   rvalid_m_inf;
output reg                   rready_m_inf;
input  wire [DATA_WIDTH-1:0]   rdata_m_inf;
input  wire                    rlast_m_inf;
input  wire [1:0]              rresp_m_inf;
// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1) 	axi write address channel 
output wire [ID_WIDTH-1:0]      awid_m_inf;
output wire [1:0]            awburst_m_inf;
output wire [2:0]             awsize_m_inf;
output wire [7:0]              awlen_m_inf;
output reg                  awvalid_m_inf;
input  wire                  awready_m_inf;
output reg [ADDR_WIDTH-1:0]  awaddr_m_inf;
// -------------------------
// (2)	axi write data channel 
output reg                   wvalid_m_inf;
input  wire                   wready_m_inf;
output reg [DATA_WIDTH-1:0]   wdata_m_inf;
output reg                    wlast_m_inf;
// -------------------------
// (3)	axi write response channel 
input  wire  [ID_WIDTH-1:0]      bid_m_inf;
input  wire                   bvalid_m_inf;
output reg                   bready_m_inf;
input  wire  [1:0]             bresp_m_inf;


// -------------------------
//		parameters
// -------------------------
reg [2:0] read_state, read_state_comb;
reg [2:0] write_state, write_state_comb;

wire AR_TRIG;
wire R_END_TRIG;
wire R_TRIG;

wire AW_TRIG;
wire W_TRIG;
wire RESP_TRIG;

reg [6:0] write_count;

parameter IDLE = 0;
parameter AR = 1;
parameter READ = 2;
parameter AW = 1;
parameter WRITE = 2;
// -------------------------
//			FSM
// -------------------------
always @ * begin
	case(read_state) // synopsys full_case
		IDLE	:	begin
						if(AR_TRIG)	read_state_comb = AR;
						else		read_state_comb = IDLE;
					end
		AR		: 	begin
						if(R_TRIG)	read_state_comb = READ;
						else		read_state_comb = AR;
					end
		READ	:	begin
						if(R_END_TRIG)	read_state_comb = IDLE;
						else			read_state_comb = READ;
					end
	endcase
end
always @ * begin
	case(write_state) // synopsys full_case
		IDLE	:	begin
						if(AW_TRIG)	write_state_comb = AW;
						else				write_state_comb = IDLE;
					end
		AW		: 	begin
						if(W_TRIG)	write_state_comb = READ;
						else								write_state_comb = AR;
					end
		WRITE	:	begin
						if(RESP_TRIG)	write_state_comb = IDLE;
						else			write_state_comb = READ;
					end
	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		read_state <= 'd0;
	end
	else begin
		read_state <= read_state_comb;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		write_state <= 'd0;
	end
	else begin
		write_state <= write_state_comb;
	end
end
//---------------------------
//			AR
//---------------------------
assign awid_m_inf    = 4'd0;
assign awburst_m_inf = 2'b01;
assign awsize_m_inf  = 3'b100;
assign awlen_m_inf   = 8'd127;
assign arid_m_inf    = 4'd0;
assign arburst_m_inf = 2'b01;
assign arsize_m_inf  = 3'b100;
assign arlen_m_inf   = 8'd127;

assign AR_TRIG = READ_REQUEST;
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		arvalid_m_inf <= 'd0;
	end
	else begin
		if((AR_TRIG || read_state == AR) && !R_TRIG) begin
			arvalid_m_inf <= 'd1;
		end
		else begin
			arvalid_m_inf <= 'd0;
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		araddr_m_inf <= 'd0;
	end
	else begin
		if((AR_TRIG || read_state == AR) && !R_TRIG) begin
			araddr_m_inf <= read_addr;
		end
		else begin
			araddr_m_inf <= 'd0;
		end
	end
end
//---------------------------
//			READ
//---------------------------
assign R_TRIG = (arready_m_inf && arvalid_m_inf);
assign R_END_TRIG = (rlast_m_inf && rvalid_m_inf && rready_m_inf);
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	rready_m_inf <= 'd0;
	else begin
		if((R_TRIG || read_state == READ) && !R_END_TRIG) begin
			rready_m_inf <= 'd1;
		end
		else begin
			rready_m_inf <= 'd0;
		end
	end
end

//---------------------------
//			AW
//---------------------------
assign AW_TRIG = WRITE_REQUEST;
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		awvalid_m_inf <= 'd0;
	end
	else begin
		if((AW_TRIG || write_state == AW) && !W_TRIG) begin
			awvalid_m_inf <= 'd1;
		end
		else begin
			awvalid_m_inf <= 'd0;
		end
	end
end


always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		awaddr_m_inf <= 'd0;
	end
	else begin
		if((AW_TRIG || write_state == AW) && !W_TRIG) begin
			awaddr_m_inf <= write_addr;
		end
		else begin
			awaddr_m_inf <= 'd0;
		end
	end
end
//---------------------------
//			WRITE
//---------------------------
assign W_TRIG = (awready_m_inf && awvalid_m_inf);
assign RESP_TRIG = (wlast_m_inf && wvalid_m_inf && wready_m_inf);
assign RESP_END_TRIG = (bvalid_m_inf && bready_m_inf && (bresp_m_inf==2'b00));
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n)	wvalid_m_inf <= 'd0;
	else begin
		if((W_TRIG || write_state == WRITE) && !RESP_TRIG) begin
			wvalid_m_inf <= 'd1;
		end
		else begin
			wvalid_m_inf <= 'd0;
		end
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) wdata_m_inf <= 'd0;
	else begin
		if((W_TRIG || write_state == WRITE) && !RESP_TRIG) begin
			wdata_m_inf <= write_data;
		end
		else begin
			wdata_m_inf <= 'd0;
		end
	end
end
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) bready_m_inf <= 'd0;
	else begin
		if(W_TRIG) begin
			bready_m_inf <= 'd1;
		end
		else if(RESP_END_TRIG) begin
			bready_m_inf <= 'd0;
		end
		else begin
			bready_m_inf <= bready_m_inf;
		end
	end
end

reg wlast_delay;

always @ (posedge clk) begin
	wlast_delay <= (write_last_count == 'd127);
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) wlast_m_inf <= 'd0;
	else begin
		if(wlast_delay && write_state == WRITE) begin
			wlast_m_inf <= 'd1;
		end
		else begin
			wlast_m_inf <= 'd0;
		end
	end
end
endmodule