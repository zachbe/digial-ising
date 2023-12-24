
// A coupled RO cell, taken from:
// https://www.nature.com/articles/s41928-023-01021-y
//
// Mismatches are measured at different points, and affect the
// propagation delay from that point.
//
// Intended to be instantiated in an NxN array.

`timescale 1ns/1ps

module coupled_cell (
                       //Coupling weight can fall between -2 and +2
		       input  wire [2:0] weight,
	               input  wire sin ,
		       input  wire din ,
		       output wire sout,
		       output wire dout
	               );

    // If coupling is positive, we want to slow down the destination
    // oscillator when it doesn't match the source oscillator.
    //
    // If coupling is negative, we want to slow down the destination
    // oscillator when it does match the source oscillator.
    //
    //  5 levels of coupling strengh
    assign neg2     = (weight == 3'b000);
    assign neg1     = (weight == 3'b001);
    assign zero     = (weight == 3'b010);
    assign pos1     = (weight == 3'b011);
    assign pos2     = (weight == 3'b100);

    assign mismatch_in  = (sin  ^ din );
    assign mismatch_out = (sout ^ dout);
    
    assign slow1d    = (neg1 & ~mismatch_in ) | (pos1 &  mismatch_in ) ;
    assign slow1s    = (neg1 &  mismatch_out) | (pos1 & ~mismatch_out) ;
    assign slow2d    = (neg2 & ~mismatch_in ) | (pos2 &  mismatch_in ) ;
    assign slow2s    = (neg2 &  mismatch_out) | (pos2 & ~mismatch_out) ;
    
    // All delay elements are implemented using muxes for simplicity
    wire mux0_s;
    wire mux1_s;
    wire mux2_s;

    mux mux0s(.a(sin), .b(1'b0  ), .s(1'b0           ), .o(mux0_s));
    mux mux1s(.a(sin), .b(mux0_s), .s(slow1d | slow2d), .o(mux1_s));
    mux mux2s(.a(sin), .b(mux1_s), .s(slow2d         ), .o(mux2_s));

    assign sout = mux0_s & mux1_s & mux2_s;

    // Glitch-free configurable delay cell
    wire mux0_d;
    wire mux1_d;
    wire mux2_d;

    mux mux0d(.a(din), .b(1'b0  ), .s(1'b0           ), .o(mux0_d));
    mux mux1d(.a(din), .b(mux0_d), .s(slow1s | slow2s), .o(mux1_d));
    mux mux2d(.a(din), .b(mux1_d), .s(slow2s         ), .o(mux2_d));
    
    assign dout = mux0_d & mux1_d & mux2_d;

endmodule

// Generic mux for simulation
module mux(input wire a,
	   input wire b,
	   input wire s,
	   output wire o);
    reg o_reg;
    assign o = o_reg;
    always @(a, b, s) begin
        #1 o_reg = s ? b : a;
    end
endmodule
