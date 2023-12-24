
// A shorted RO cell, similar to
// https://www.nature.com/articles/s41928-023-01021-y
//
// Forces two RO sections to have the same phase.

`timescale 1ns/1ps

module shorted_cell (
	               input  wire sin ,
		       input  wire din ,
		       output wire sout,
		       output wire dout
	               );

    // TODO: Which method for synchronizing should we use?
    assign out = ~(sin & din);

    buffer sbuf(.i(out), .o(sout));
    buffer dbuf(.i(out), .o(dout));

endmodule

// Generic buffer for simulation
module buffer(input  wire i,
	      output wire o);
    reg o_reg;
    assign o = o_reg;
    always @(i) begin
        #1 o_reg = i;
    end
endmodule