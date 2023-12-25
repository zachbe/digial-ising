
// A coupled RO cell, taken from:
// https://www.nature.com/articles/s41928-023-01021-y
//
// Mismatches are measured at different points, and affect the
// propagation delay from that point.
//
// Intended to be instantiated in an NxN array.

`timescale 1ns/1ps
`include "../cells/buffer.v"

module coupled_cell #(parameter NUM_WEIGHTS = 5) (
                       //Parameterize coupling weight
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
   
    // TODO: There is a bug where sin and din both change at the same time,
    // which causes a combinational loop.
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
    
    // Figure out which buffer we should use
    wire [NUM_WEIGHTS-1:0] sel_buf_s;
    wire [NUM_WEIGHTS-1:0] sel_buf_d;

    generate for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
	assign sel_buf_s[i] = mismatch_s ? sel_weights[i] : sel_weights[NUM_WEIGHTS-1-i];	
	assign sel_buf_d[i] = mismatch_d ? sel_weights[i] : sel_weights[NUM_WEIGHTS-1-i];	
    end endgenerate

    // Use that buffer
    wire [NUM_WEIGHTS-1:0] s_mux;
    wire [NUM_WEIGHTS-1:0] d_mux;

    assign s_mux[0] = s_buf[0];
    assign d_mux[0] = d_buf[0];
    generate for (i = 1; i < NUM_WEIGHTS; i = i + 1) begin
        assign s_mux[i] = sel_buf_s[i] ? s_buf[i] : s_mux[i-1];
        assign d_mux[i] = sel_buf_d[i] ? d_buf[i] : d_mux[i-1];
    end endgenerate

    assign sout = s_mux[NUM_WEIGHTS-1];
    assign dout = d_mux[NUM_WEIGHTS-1];

    // Array of generic delay buffers
    buffer buf0s(.in(sin   ), .out(s_buf[0]));
    buffer buf0d(.in(din   ), .out(d_buf[0]));
    generate for (i = 1; i < NUM_WEIGHTS; i = i + 1) begin
        buffer bufis(.in(s_buf[i-1]), .out(s_buf[i]));
        buffer bufid(.in(d_buf[i-1]), .out(d_buf[i]));
    end endgenerate

endmodule
