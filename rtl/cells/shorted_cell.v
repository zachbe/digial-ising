
// A shorted RO cell, similar to
// https://www.nature.com/articles/s41928-023-01021-y
//
// Forces two RO sections to have the same phase.

`timescale 1ns/1ps
`include "buffer.v"

module shorted_cell #(parameter NUM_LUTS = 2) (
	               input  wire sin ,
		       input  wire din ,
		       output wire sout,
		       output wire dout
	               );

    // TODO: Which method for synchronizing should we use?
    assign out = ~(sin & din);

    buffer #(NUM_LUTS) sbuf(.in(out), .out(sout));
    buffer #(NUM_LUTS) dbuf(.in(out), .out(dout));

endmodule
