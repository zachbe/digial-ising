
// A coupled RO cell, taken from:
// https://www.nature.com/articles/s41928-023-01021-y
//
// Mismatches are measured at different points, and affect the
// propagation delay from that point.
//
// Intended to be instantiated in an NxN array.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "buffer.v"
`endif

module coupled_cell #(parameter NUM_WEIGHTS = 15,
                      parameter NUM_LUTS    = 2 ) (
		       // Oscillator RST
		       input  wire ising_rstn,

		       // Asynchronous phase IO
	               input  wire sin ,
		       input  wire din ,
		       output wire sout,
		       output wire dout,

		       // Synchronous AXI write interface
		       input  wire        clk,
		       input  wire        axi_rstn,
                       input  wire        wready,
		       input  wire        wr_addr_match,
		       input  wire [31:0] wdata,
		       output wire [31:0] rdata
	               );

    genvar i;
    
    // Local registers for storing weights.
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight;
    wire [$clog2(NUM_WEIGHTS)-1:0] weight_nxt;

    assign rdata = weight;

    assign weight_nxt = (wready & wr_addr_match) ? wdata[$clog2(NUM_WEIGHTS)-1:0] :
	                                           weight                         ;
    always @(posedge clk) begin
	if (!axi_rstn) begin
      	    weight <= (NUM_WEIGHTS/2); //NUM_WEIGHTS must be odd.
        end else begin
            weight <= weight_nxt;
        end
    end

    wire [NUM_WEIGHTS-1:0] weight_oh;
    generate for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
        assign weight_oh[i] = (weight == i);
    end endgenerate

    // If coupling is positive, we want to slow down the destination
    // oscillator when it doesn't match the source oscillator, and speed it up
    // otherwise.
    //
    // If coupling is negative, we want to slow down the destination
    // oscillator when it does match the source oscillator, and speed it up
    // otherwise.

    assign mismatch_s  = (sin ^ dout);
    assign mismatch_d  = (din ^ sout);
    
    wire [NUM_WEIGHTS-1:0] s_buf;
    wire [NUM_WEIGHTS-1:0] d_buf;
 
    // Select our pair of possible delay elements using the weight array
    wire [NUM_WEIGHTS-1:0] s_sel_ma;
    wire [NUM_WEIGHTS-1:0] s_sel_mi;
    wire [NUM_WEIGHTS-1:0] d_sel_ma;
    wire [NUM_WEIGHTS-1:0] d_sel_mi;

    generate for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
        assign s_sel_ma[i] = weight_oh[NUM_WEIGHTS-1-i] & s_buf[i];
        assign s_sel_mi[i] = weight_oh[i              ] & s_buf[i];
        assign d_sel_ma[i] = weight_oh[NUM_WEIGHTS-1-i] & d_buf[i];
        assign d_sel_mi[i] = weight_oh[i              ] & d_buf[i];
    end endgenerate
    
    wire s_ma;
    wire s_mi;
    wire d_ma;
    wire d_mi;

    assign s_ma = |s_sel_ma;
    assign s_mi = |s_sel_mi;
    assign d_ma = |d_sel_ma;
    assign d_mi = |d_sel_mi;
    
    // Select correct option based on mismatch status
    wire sout_pre;
    wire dout_pre;
    assign sout_pre = mismatch_s ? s_mi : s_ma;
    assign dout_pre = mismatch_d ? d_mi : d_ma;

    // Prioritize dout over sout
    // May need more LUTs to make this not glitch
    wire sout_int;
    wire dout_int;
    buffer #(NUM_LUTS) bufNs(.in(sout_pre), .out(sout_int));
    assign dout_int = dout_pre;

    // Array of generic delay buffers
    // TODO: Potentially replace this with an asynchronous counter and
    // comparator to allow for greater weight resolution per LUT used.
    // (Issue #7)
    buffer #(NUM_LUTS) buf0s(.in(sin   ), .out(s_buf[0]));
    buffer #(NUM_LUTS) buf0d(.in(din   ), .out(d_buf[0]));
    generate for (i = 1; i < NUM_WEIGHTS; i = i + 1) begin
        buffer #(NUM_LUTS) bufis(.in(s_buf[i-1]), .out(s_buf[i]));
        buffer #(NUM_LUTS) bufid(.in(d_buf[i-1]), .out(d_buf[i]));
    end endgenerate
    
    // Latches here trick the tool into not thinking there's
    // a combinational loop in the design.
    `ifdef SIM
        assign sout = ising_rstn ? sout_int : 1'b0;
        assign dout = ising_rstn ? dout_int : 1'b0;
    `else
        (* dont_touch = "yes" *) LDCE s_latch (.Q(sout), .D(sout_int), .G(ising_rstn), .GE(1'b1), .CLR(1'b0)); 
        (* dont_touch = "yes" *) LDCE d_latch (.Q(dout), .D(dout_int), .G(ising_rstn), .GE(1'b1), .CLR(1'b0)); 
    `endif

endmodule
