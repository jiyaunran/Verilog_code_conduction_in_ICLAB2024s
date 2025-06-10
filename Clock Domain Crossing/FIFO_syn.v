module FIFO_syn #(parameter WIDTH=8, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk1,
	flag_clk1_to_fifo
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

// You can change the input / output of the custom flag ports
output  flag_fifo_to_clk2;
input flag_clk2_to_fifo; // clean signal

output flag_fifo_to_clk1;
input flag_clk1_to_fifo; // clean signal

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
reg [$clog2(WORDS):0] wptr;
reg [$clog2(WORDS):0] rptr;

// rdata
//  Add one more register stage to rdata
always @(posedge rclk, negedge rst_n) begin
    if (!rst_n) begin
        rdata <= 0;
    end
    else begin
		if (rinc & !rempty) begin
			rdata <= rdata_q;
		end
    end
end

//---------------------------------
//			Regs and wires
//---------------------------------
reg [$clog2(WORDS):0] write_address;
reg [$clog2(WORDS):0] read_address;
reg [$clog2(WORDS):0] write_address_sync;
reg [$clog2(WORDS):0] read_address_sync;
reg [$clog2(WORDS):0] wptr_comb;
reg [$clog2(WORDS):0] rptr_comb;
reg [$clog2(WORDS):0] wptr_sync;
reg [$clog2(WORDS):0] rptr_sync;

reg SRAM_write_en;

//---------------------------------
//			reading
//---------------------------------
always @ (posedge rclk or negedge rst_n)begin
	if(!rst_n) begin
		rempty <= 'd1;
	end
	else begin
		if(rptr == wptr_sync) begin
			rempty <= 'd1;
		end
		else begin
			rempty <= 'd0;
		end
	end
end

always @ (posedge rclk or negedge rst_n) begin
	if(!rst_n) begin
		read_address <= 'd0;
	end
	else begin
		if(rinc && !rempty) begin
			read_address <= read_address + 'd1;
		end
		else begin
			read_address <= read_address;
		end
	end
end

//---------------------------------
//			writing
//---------------------------------
always @ * begin
	wfull = ({~wptr[6:5],wptr[4:0]} == rptr_sync);
	SRAM_write_en = ~winc;
end

always @ (posedge wclk or negedge rst_n) begin
	if(!rst_n) begin
		write_address <= 'd0;
	end
	else begin
		if(winc && !wfull) begin
			write_address <= write_address + 'd1;
		end
		else begin
			write_address <= write_address;
		end
	end
end

//---------------------------------
//				SRAM
//---------------------------------
always @ * begin
	rptr = binary_to_gray(read_address);
	wptr = binary_to_gray(write_address);
end

DUAL_64X8X1BM1 u_dual_sram (
    .CKA(wclk),
    .CKB(rclk),
    .WEAN(SRAM_write_en),
    .WEBN(1'b1),
    .CSA(1'b1),
    .CSB(1'b1),
    .OEA(1'b1),
    .OEB(1'b1),
    .A0(write_address[0]),
    .A1(write_address[1]),
    .A2(write_address[2]),
    .A3(write_address[3]),
    .A4(write_address[4]),
    .A5(write_address[5]),
    .B0(read_address[0]),
    .B1(read_address[1]),
    .B2(read_address[2]),
    .B3(read_address[3]),
    .B4(read_address[4]),
    .B5(read_address[5]),
    .DIA0(wdata[0]),
    .DIA1(wdata[1]),
    .DIA2(wdata[2]),
    .DIA3(wdata[3]),
    .DIA4(wdata[4]),
    .DIA5(wdata[5]),
    .DIA6(wdata[6]),
    .DIA7(wdata[7]),
    .DIB0(1'b0),
    .DIB1(1'b0),
    .DIB2(1'b0),
    .DIB3(1'b0),
    .DIB4(1'b0),
    .DIB5(1'b0),
    .DIB6(1'b0),
    .DIB7(1'b0),
    .DOB0(rdata_q[0]),
    .DOB1(rdata_q[1]),
    .DOB2(rdata_q[2]),
    .DOB3(rdata_q[3]),
    .DOB4(rdata_q[4]),
    .DOB5(rdata_q[5]),
    .DOB6(rdata_q[6]),
    .DOB7(rdata_q[7])
);

function [6:0] binary_to_gray;
    input [6:0] binary;
    integer i;

    binary_to_gray[6] = binary[6];
    for(i = 0; i < 6; i = i + 1)
        binary_to_gray[i] = binary[i] ^ binary[i + 1];
endfunction

NDFF_BUS_syn #($clog2(WORDS)+1) wptr_synchronizer(.D(wptr), .Q(wptr_sync), .clk(rclk), .rst_n(rst_n));
NDFF_BUS_syn #($clog2(WORDS)+1) rptr_synchronizer(.D(rptr), .Q(rptr_sync), .clk(wclk), .rst_n(rst_n));

NDFF_BUS_syn #($clog2(WORDS)+1) wptr_synchronizer2(.D(write_address), .Q(write_address_sync), .clk(rclk), .rst_n(rst_n));
NDFF_BUS_syn #($clog2(WORDS)+1) rptr_synchronizer2(.D(read_address), .Q(read_address_sync), .clk(wclk), .rst_n(rst_n));

endmodule
