
// A coupled RO cell, taken from:
// https://www.nature.com/articles/s41928-023-01021-y
//
// Mismatches are measured at different points, and affect the
// propagation delay from that point.
//
// Intended to be instantiated in an NxN array.

`timescale 1ns/1ps
`include "../cells/buffer.v"

module coupled_cell (
                       //Coupling weight can fall between -2 and +2
		       input  wire [2:0] weight,
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
    //
    //  5 levels of coupling strengh
    assign neg2     = (weight == 3'b000);
    assign neg1     = (weight == 3'b001);
    assign zero     = (weight == 3'b010);
    assign pos1     = (weight == 3'b011);
    assign pos2     = (weight == 3'b100);

    //TODO: There is a bug where sin and din both change at the same time,
    //which causes a combinational loop.
    assign mismatch_s  = (sin  ^ dout);
    assign mismatch_d  = (din  ^ sout);
    
    assign slow1d    = (neg1 & ~mismatch_d) | (pos1 &  mismatch_d) ;
    assign slow1s    = (neg1 & ~mismatch_s) | (pos1 &  mismatch_s) ;
    assign slow2d    = (neg2 & ~mismatch_d) | (pos2 &  mismatch_d) ;
    assign slow2s    = (neg2 & ~mismatch_s) | (pos2 &  mismatch_s) ;
    
    assign fast1d    = (neg1 &  mismatch_d) | (pos1 & ~mismatch_d) ;
    assign fast1s    = (neg1 &  mismatch_s) | (pos1 & ~mismatch_s) ;
    assign fast2d    = (neg2 &  mismatch_d) | (pos2 & ~mismatch_d) ;
    assign fast2s    = (neg2 &  mismatch_s) | (pos2 & ~mismatch_s) ;
    
    // All delay elements are implemented using buffers for simplicity
    wire buf0_s;
    wire buf1_s;
    wire buf2_s;
    wire buf3_s;
    wire buf4_s;

    buffer buf0s(.i(sin   ), .o(buf0_s));
    buffer buf1s(.i(buf0_s), .o(buf1_s));
    buffer buf2s(.i(buf1_s), .o(buf2_s));
    buffer buf3s(.i(buf2_s), .o(buf3_s));
    buffer buf4s(.i(buf3_s), .o(buf4_s));

    assign sout = slow2s ? buf4_s :
	          slow1s ? buf3_s :
		  fast1s ? buf1_s :
		  fast2s ? buf0_s :
		           buf2_s ;

    wire buf0_d;
    wire buf1_d;
    wire buf2_d;
    wire buf3_d;
    wire buf4_d;

    buffer buf0d(.i(din   ), .o(buf0_d));
    buffer buf1d(.i(buf0_d), .o(buf1_d));
    buffer buf2d(.i(buf1_d), .o(buf2_d));
    buffer buf3d(.i(buf2_d), .o(buf3_d));
    buffer buf4d(.i(buf3_d), .o(buf4_d));
    
    assign dout = slow2d ? buf4_d :
	          slow1d ? buf3_d :
		  fast1d ? buf1_d :
		  fast2d ? buf0_d :
		           buf2_d ;

endmodule
