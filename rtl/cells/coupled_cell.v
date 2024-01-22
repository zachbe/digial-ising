
// A coupled RO cell, taken from:
// https://www.nature.com/articles/s41928-023-01021-y
//
// Mismatches are measured at different points, and affect the
// propagation delay from that point.
//
// Intended to be instantiated in an NxN array.

`timescale 1ns/1ps
`include "../cells/buffer.v"

module coupled_cell #(parameter NUM_WEIGHTS = 5,
                      parameter NUM_LUTS    = 2) (
		       //TODO: Weight should be programmed via regs
		       //rather than just wires going everywhere.
		       input  wire [$clog2(NUM_WEIGHTS)-1:0] weight,
	               input  wire sin ,
		       input  wire din ,
		       output wire sout,
		       output wire dout
	               );

    // If coupling is positive, we want to slow down the destination
    // oscillator when it doesn't match the source oscillator, and speed it up
    // otherwise.
    //
    // If coupling is negative, we want to slow down the destination
    // oscillator when it does match the source oscillator, and speed it up
    // otherwise.
   
    assign mismatch_s  = (sin  ^ dout);
    assign mismatch_d  = (din  ^ sout);
    
    wire [NUM_WEIGHTS-1:0] s_buf;
    wire [NUM_WEIGHTS-1:0] d_buf;
 
    genvar i;

    // TODO: All of this logic also includes delays when synthesized!
    // How can we design the RTL such that these delays are utilized instead
    // of generic buffers?

    // Create a 1-hot array of weights
    wire [NUM_WEIGHTS-1:0] sel_weights;
    generate for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
	assign sel_weights[i] = (weight == i);
    end endgenerate
    
    // Select our pair of possible delay elements using the weight array
    wire [NUM_WEIGHTS-1:0] s_sel_ma;
    wire [NUM_WEIGHTS-1:0] s_sel_mi;
    wire [NUM_WEIGHTS-1:0] d_sel_ma;
    wire [NUM_WEIGHTS-1:0] d_sel_mi;

    generate for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
        assign s_sel_ma[i] = sel_weights[NUM_WEIGHTS-1-i] & s_buf[i];
        assign s_sel_mi[i] = sel_weights[i              ] & s_buf[i];
        assign d_sel_ma[i] = sel_weights[NUM_WEIGHTS-1-i] & d_buf[i];
        assign d_sel_mi[i] = sel_weights[i              ] & d_buf[i];
    end endgenerate
    
    wire s_ma;
    wire s_mi;
    wire d_ma;
    wire d_mi;

    assign s_ma = |s_sel_ma;
    assign s_mi = |s_sel_mi;
    assign d_ma = |d_sel_ma;
    assign d_mi = |d_sel_mi;
    
    // Select correct option based on mismatch statis
    wire sout_pre;
    wire dout_pre;
    assign sout_pre = mismatch_s ? s_mi : s_ma;
    assign dout_pre = mismatch_d ? d_mi : d_ma;

    // Prioritize dout over sout
    // TODO: may need more LUTs to make this not glitch
    buffer #(NUM_LUTS) bufNs(.in(sout_pre), .out(sout));
    assign dout = dout_pre;

    // Array of generic delay buffers
    buffer #(NUM_LUTS) buf0s(.in(sin   ), .out(s_buf[0]));
    buffer #(NUM_LUTS) buf0d(.in(din   ), .out(d_buf[0]));
    generate for (i = 1; i < NUM_WEIGHTS; i = i + 1) begin
        buffer #(NUM_LUTS) bufis(.in(s_buf[i-1]), .out(s_buf[i]));
        buffer #(NUM_LUTS) bufid(.in(d_buf[i-1]), .out(d_buf[i]));
    end endgenerate

endmodule
