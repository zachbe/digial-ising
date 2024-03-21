
`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "buffer.v"
`endif

module shorted_cell #(parameter NUM_LUTS = 2) (
	               input  wire ising_rstn,
	               input  wire sin ,
		       output wire dout
	               );

    wire s_int;
    assign out = ~(s_int);

    buffer #(NUM_LUTS) dbuf(.in(out), .out(dout));

    // Latches here trick the tool into not thinking there's
    // a combinational loop in the design.
    `ifdef SIM
        assign s_int = ising_rstn ? sin : 1'b0;
    `else
        (* dont_touch = "yes" *) LDCE s_latch (.Q(s_int), .D(sin), .G(ising_rstn), .GE(1'b1), .CLR(1'b0)); 
    `endif
endmodule
