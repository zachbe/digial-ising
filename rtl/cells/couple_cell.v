
// A coupled RO cell, taken from:
// https://www.nature.com/articles/s41928-023-01021-y
//
// Mismatches are measured at different points, and affect the
// propagation delay from that point.
//
// Intended to be instantiated in an NxN array.

`timescale 1ns/1ps

module coupled_cell  #(parameter RESET = 0)(
                       //Coupling weight can fall between -2 and +2
		       input  wire [2:0] weight,
	               input  wire sin ,
		       input  wire din ,
		       output wire sout,
		       output wire dout,
		       input  wire rstn, //negedge reset
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
    assign pos1     = (weight == 3'b011);
    assign pos2     = (weight == 3'b100);

    assign mismatch = (sin ^ din);
    
    assign slow1    = (neg1 & ~mismatch) | (pos1 & mismatch);
    assign slow2    = (neg2 & ~mismatch) | (pos2 & mismatch);
    
    // All delay elements are implemented using muxes for simplicity
    mux s_buffer_mux(.a(sin), .b(1'b0), .s(1'b0), .o(sout));

    // Glitch-free configurable delay cell
    wire mux0_o;
    wire mux1_o;
    wire mux2_o;

    mux mux0(.a(din), .b(1'b0  ), .s(1'b0          ), .o(mux0_o));
    mux mux2(.a(din), .b(mux0_o), .s(slow1 || slow2), .o(mux1_o));
    mux mux2(.a(din), .b(mux1_o), .s(slow2         ), .o(mux2_o));
    
    assign dout = mux0_o & mux1_o & mux2_o;

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
