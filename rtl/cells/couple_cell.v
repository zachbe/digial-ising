
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
		       input  wire [2:0] coupling_weight,
	               input  wire nin ,
		       input  wire win ,
		       output wire sout,
		       output wire eout,
		       input  wire rstn, //negedge reset
	               );

    // If coupling is positive, we want whichever input is 1 first
    // to slow down and wait for the other input.
    //
    // If coupling is negative, we want whichever input is 1 first
    // to speed up and outrun the other input.
    //
    // TODO: Implement this

    wire [2:0] weight;
    assign weight = coupling_weights[(i-1)*3 + 2 : (i-1)*3];
    
    //  5 levels of coupling strengh
    assign neg2   = (weight == 3'b000);
    assign neg1   = (weight == 3'b001);
    assign zero   = (weight == 3'b010);
    assign pos1   = (weight == 3'b011);
    assign pos2   = (weight == 3'b100);
    
    assign ns_buf1   = (pos2 &  couple);
    assign ns_buf2   = (pos1 &  couple);
    assign ns_buf3   = (zero | ~couple);
    assign ns_buf4   = (neg1 &  couple);
    assign ns_buf5   = (neg2 &  couple);
    
    wire   [4:0] ns_buf_out;
    buffer ns_buffer[4:0] ({ns_buf_out[3:0], nin}, ns_buf_out);
    
    assign sout    = ~rstn ? RESET      :
                      buf1 ? ns_buf_out[0] :
    	              buf2 ? ns_buf_out[1] :
    	              buf3 ? ns_buf_out[2] :
    	              buf4 ? ns_buf_out[3] :
    	              buf5 ? ns_buf_out[4] : 0;

    end endgenerate

endmodule

// Generic buffer for simulation
module buffer(input wire i, output wire o);
    reg o_reg;
    assign o = o_reg;
    always @(i) begin
        #1 o_reg = i;
    end
endmodule
