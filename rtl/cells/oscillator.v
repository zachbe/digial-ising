
// A couple-able ring oscillator.
//
// Consists of an inverter, N coupled delay ports,
// N padded buffers, and an output port.
//
//     N   wave     0
//  |---<---<---<---<--|
//  |                  |-- out
//  |-->o-->->->->-----|
//          padding

`timescale 1ns/1ps

module oscillator #(parameter PORTS = 16, parameter RESET = 0)(
                    //Coupling weights can fall between -2 and +2
		    input wire [(3*PORTS)-1:0] coupling_weights,
	            input wire [PORTS-1    :0] coupling_inputs,
		    input wire rstn, //negedge reset
		    output wire out);

    wire [PORTS  :0] wave;
    wire [PORTS  :0] pad ;

    assign wave[0] = rstn ? ~pad[PORTS] : RESET;
    assign out     = wave[0];

    assign pad[0] = wave[PORTS];
    
    // Padding delay ports prevent ringing
    genvar i;
    generate for (i = 1; i <= PORTS; i=i+1) begin
	wire   [4:0] pad_buf_out;
        buffer pad_buffer[4:0] ({pad_buf_out[3:0], pad[i-1]}, pad_buf_out);
	assign pad[i] = rstn ? pad_buf_out[4] : RESET;
    end endgenerate

    // TODO: Issues with coupling:
    // Currently, once coupling has been re-aligned by a couple cycles,
    // the propagation delay while the cycles are aligned causes the
    // wave-front to already be past the part that triggers off of
    // mismatch.
    //
    // New idea: we use some sort of counter to measure the phase match
    // between ROs and use that phase match to affect the timing.
    //
    // Other idea: try a topology similar to:
    // https://www.nature.com/articles/s41928-023-01021-y
    // Mismatches are measured at different points, and affect the
    // propagation delay from that point.
    //
    // -----------------
    //
    // Check if we want to enable coupling.
    //
    // If our output value and the coupled output value don't match,
    // positive coupling causes us to speed up to try to match.
    //
    // If our output value and the coupled output value don't match,
    // negative coupling causes us to try to slow down and continue
    // being out of sync.
    
    wire [PORTS-1:0] couple;
    assign couple = rstn ? (coupling_inputs ^ {PORTS{out}}) : 0 ;

    // Coupled delay ports
    generate for (i = 1; i <= PORTS; i=i+1) begin

	wire [2:0] weight;
	assign weight = coupling_weights[(i-1)*3 + 2 : (i-1)*3];

	//  5 levels of coupling strengh
	assign neg2   = (weight == 3'b000);
	assign neg1   = (weight == 3'b001);
	assign zero   = (weight == 3'b010);
	assign pos1   = (weight == 3'b011);
	assign pos2   = (weight == 3'b100);

        assign buf1   = (pos2 &  couple);
	assign buf2   = (pos1 &  couple);
	assign buf3   = (zero | ~couple);
        assign buf4   = (neg1 &  couple);
	assign buf5   = (neg2 &  couple);

	wire   [4:0] buf_out;
        buffer couple_buffer[4:0] ({buf_out[3:0], wave[i-1]}, buf_out);

	assign wave[i] = ~rstn ? RESET      :
	                  buf1 ? buf_out[0] :
		          buf2 ? buf_out[1] :
		          buf3 ? buf_out[2] :
		          buf4 ? buf_out[3] :
		          buf5 ? buf_out[4] : 0;

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
