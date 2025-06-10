module bridge(input clk, INF.bridge_inf inf);

//================================================================
// logic 
//================================================================
logic [7:0] read_addr;

logic [7:0] write_addr;
logic [63:0] write_data;

logic AR_TRIG;
logic R_TRIG;


//================================================================
// state 
//================================================================
typedef enum logic [1:0] {
	RIDLE,
	WAIT_WRITE,
	AREAD,
	READ
} read_state_t;
typedef enum logic [1:0] {
	AWRITE,
	WIDLE,
	WREPONSE,
	WRITE
} write_state_t;

write_state_t write_state, write_state_comb;
read_state_t read_state, read_state_comb;

always_comb begin
	case(read_state)
		RIDLE	:	begin
						if(inf.C_in_valid && inf.C_r_wb) begin
							if(write_state == WIDLE)		read_state_comb = AREAD;
							else							read_state_comb = WAIT_WRITE;
						end
						else 								read_state_comb = RIDLE;
					end
		WAIT_WRITE:	begin
						if(write_state == WIDLE)			read_state_comb = AREAD;
						else								read_state_comb = WAIT_WRITE;
					end
		AREAD	:	begin
						if(inf.AR_READY && inf.AR_VALID)	read_state_comb = READ;
						else								read_state_comb = AREAD;
					end
		READ	:	begin
						if(inf.R_READY && inf.R_VALID)		read_state_comb = RIDLE;
						else								read_state_comb = READ;
					end
	endcase
end

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		read_state <= RIDLE;
	end
	else begin
		read_state <= read_state_comb;
	end
end

always_comb begin
	case(write_state)
		WIDLE	:	begin
						if(inf.C_in_valid && !inf.C_r_wb) 	write_state_comb = AWRITE;
						else								write_state_comb = WIDLE;
					end
		AWRITE	:	begin
						if(inf.AW_VALID && inf.AW_READY)	write_state_comb = WRITE;
						else								write_state_comb = AWRITE;
					end
		WRITE	:	begin
						if(inf.W_VALID && inf.W_READY)		write_state_comb = WREPONSE;
						else								write_state_comb = WRITE;
					end
		WREPONSE:	begin
						if(inf.B_VALID && inf.B_READY && (inf.B_RESP == 'd0))	write_state_comb = WIDLE;
						else													write_state_comb = WREPONSE;
					end
	endcase
end

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		write_state <= WIDLE;
	end
	else begin
		write_state <= write_state_comb;
	end
end
//================================================================
// aread
//================================================================
//always_ff @ (posedge clk or negedge inf.rst_n) begin
//	if(!inf.rst_n) begin
//		read_addr <= 'd0;
//	end
//	else begin
//		if(inf.C_in_valid && inf.C_r_wb) begin
//			read_addr <= inf.C_addr;
//		end
//		else begin
//			read_addr <= read_addr;
//		end
//	end
//end

//always_ff @ (posedge clk or negedge inf.rst_n) begin
//	if(!inf.rst_n) begin
//		inf.AR_VALID <= 'd0;
//	end
//	else begin
//		if(read_state == AREAD && !inf.AR_READY) 	inf.AR_VALID <= 'd1;
//		else										inf.AR_VALID <= 'd0;
//	end
//end
//
always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		inf.AR_ADDR <= 'd0;
	end
	else begin
		if(read_state_comb == AREAD) 	inf.AR_ADDR <= {5'h10, 1'h0, inf.C_addr, 3'h0};
		else										inf.AR_ADDR <= 'd0;
	end
end

assign inf.AR_VALID = (read_state == AREAD);
//assign inf.AR_ADDR = (read_state == AREAD) ? {5'h10, 1'h0, read_addr, 3'h0} : 'd0;

//================================================================
// read
//================================================================
//always_ff @ (posedge clk or negedge inf.rst_n) begin
//	if(!inf.rst_n) begin
//		inf.R_READY <= 'd0;
//	end
//	else begin
//		if((read_state == READ || inf.AR_READY) && !inf.R_VALID) 	inf.R_READY <= 'd1;
//		else														inf.R_READY <= 'd0;
//	end
//end

assign inf.R_READY = (read_state == READ);

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		inf.C_out_valid <= 'd0;
	end
	else begin
		if((inf.R_READY && inf.R_VALID) || (inf.W_READY && inf.W_VALID)) begin
			inf.C_out_valid <= 'd1;
		end
		else begin
			inf.C_out_valid <= 'd0;
		end
	end
end

always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		inf.C_data_r <= 'd0;
	end
	else begin
		if((inf.R_READY && inf.R_VALID)) begin
			inf.C_data_r <= inf.R_DATA;
		end
		else begin
			inf.C_data_r <= 'd0;
		end
	end
end
//================================================================
// awrite
//================================================================
always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		write_addr <= 'd0;
	end
	else begin
		if(inf.C_in_valid && !inf.C_r_wb) begin
			write_addr <= inf.C_addr;
		end
		else begin
			write_addr <= write_addr;
		end
	end
end 

//always_ff @ (posedge clk or negedge inf.rst_n) begin
//	if(!inf.rst_n) begin
//		inf.AW_VALID <= 'd0;
//	end
//	else begin
//		if(write_state == AWRITE && !inf.AW_READY) 	inf.AW_VALID <= 'd1;
//		else										inf.AW_VALID <= 'd0;
//	end
//end
//
//always_ff @ (posedge clk or negedge inf.rst_n) begin
//	if(!inf.rst_n) begin
//		inf.AW_ADDR <= 'd0;
//	end
//	else begin
//		if(write_state == AWRITE && !inf.AW_READY) 	inf.AW_ADDR <= {5'h10, 1'h0, write_addr, 3'h0};
//		else										inf.AW_ADDR <= 'd0;
//	end
//end

assign inf.AW_VALID = (write_state == AWRITE);
assign inf.AW_ADDR = !(|write_state) ? {5'h10, 1'h0, write_addr, 3'h0} : 'd0;

//================================================================
// write
//================================================================
//always_ff @ (posedge clk or negedge inf.rst_n) begin
//	if(!inf.rst_n) begin
//		inf.W_VALID <= 'd0;
//	end
//	else begin
//		if((write_state == WRITE || inf.AW_READY) && !inf.W_READY) 	inf.W_VALID <= 'd1;
//		else														inf.W_VALID <= 'd0;
//	end
//end
//
//
//always_ff @ (posedge clk or negedge inf.rst_n) begin
//	if(!inf.rst_n) begin
//		inf.W_DATA <= 'd0;
//	end
//	else begin
//		if((write_state == WRITE || inf.AW_READY) && !inf.W_READY) 	inf.W_DATA <= write_data;
//		else														inf.W_DATA <= 'd0;
//	end
//end


assign inf.W_VALID = (write_state == WRITE);
always_ff @ (posedge clk or negedge inf.rst_n) begin
	if(!inf.rst_n) begin
		inf.W_DATA <= 'd0;
	end
	else begin
		if(inf.AW_VALID && inf.AW_READY || write_state == WRITE) begin
			inf.W_DATA <= inf.C_data_w;
		end
		else begin
			inf.W_DATA <= 'd0;
		end
	end
end
//assign inf.W_DATA = (&write_state) ? inf.C_data_w : 'd0;

//================================================================
// bresp
//================================================================
//always_ff @ (posedge clk or negedge inf.rst_n) begin
//	if(!inf.rst_n) begin
//		inf.B_READY <= 'd0;
//	end
//	else begin
//		if((write_state == WREPONSE || write_state == WRITE || inf.AW_READY) && !inf.B_VALID) 	inf.B_READY <= 'd1;
//		else																					inf.B_READY <= 'd0;
//	end
//end
assign inf.B_READY = ((write_state == WRITE) || (write_state == WREPONSE));
endmodule