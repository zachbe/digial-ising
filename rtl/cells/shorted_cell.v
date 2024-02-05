
// A shorted RO cell, similar to
// https://www.nature.com/articles/s41928-023-01021-y
//
// Forces two RO sections to have the same phase.

`timescale 1ns/1ps

`include "defines.vh"
`include "buffer.v"

module shorted_cell #(parameter NUM_LUTS = 2) (
	               input  wire rstn,
	               input  wire sin ,
		       input  wire din ,
		       output wire sout,
		       output wire dout
	               );

    wire s_int;
    wire d_int;
    assign out = ~(s_int & d_int);

    buffer #(NUM_LUTS) sbuf(.in(out), .out(sout));
    buffer #(NUM_LUTS) dbuf(.in(out), .out(dout));

    // Latches here trick the tool into not thinking there's
    // a combinational loop in the design.
    `ifdef SIM
        assign s_int = rstn ? sin : 1'b0;
        assign d_int = rstn ? din : 1'b0;
    `else
        (* dont_touch = "yes" *) LDCE s_latch (.Q(s_int), .D(sin), .G(rstn), .GE(1'b1), .CLR(1'b0)); 
        (* dont_touch = "yes" *) LDCE d_latch (.Q(d_int), .D(din), .G(rstn), .GE(1'b1), .CLR(1'b0)); 
    `endif
endmodule
