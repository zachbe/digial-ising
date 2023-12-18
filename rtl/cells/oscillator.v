
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

module oscillator #(parameter PORTS = 16)(
                    //Coupling weights can fall between -2 and +2
		    input wire [(3*PORTS)-1:0] coupling_weights,
	            input wire [PORTS-1    :0] coupling_inputs,
		    input wire rstn, //negedge reset
		    output wire out);

    wire [PORTS  :0] wave;
    wire [PORTS  :0] pad ;

    assign wave[0] = rstn ? ~pad[PORTS] : 0;
    assign out     = wave[0];

    assign pad[0] = wave[PORTS];
    
    // Padding delay ports prevent ringing
    genvar i;
    generate for (i = 1; i <= PORTS; i=i+1) begin
	wire   [4:0] pad_buf_out;
        buffer pad_buffer[4:0] ({pad_buf_out[3:0], pad[i-1]}, pad_buf_out);
	assign pad[i] = rstn ? pad_buf_out[4] : 0;
    end endgenerate

    // check if we're matching the coupled input or not
    wire [PORTS-1:0] match;
    assign match = rstn ? ~(coupling_inputs ^ {PORTS{out}}) : 0 ;

    // Coupled delay ports
    generate for (i = 1; i <= PORTS; i=i+1) begin

	wire [2:0] weight;
	assign weight = coupling_weights[(i-1)*3 + 2 : (i-1)*3];

	// TODO: Coupling is currently directed;
	// if A and B are both coupled, and A and
	// B are mismatched, they both speed up.
	// We need to fix this.
	//
	// -2: slow down if input is mismatch
	//     speed up if input is match
	// -1: slow down if input is mismatch
	//     speed up if input is match
	//  0: no speed change
	// +1: speed up if input is mismatch
	//     slow down if input is match
	// +2: speed up if input is mismatch
	//     slow down if input is match
	assign neg2   = (weight == 3'b000);
	assign neg1   = (weight == 3'b001);
	assign zero   = (weight == 3'b010);
	assign pos1   = (weight == 3'b011);
	assign pos2   = (weight == 3'b100);

        assign buf1   = (neg2 & match)  | (pos2 & !match);
	assign buf2   = (neg1 & match)  | (pos1 & !match);
	assign buf3   = zero;
        assign buf4   = (neg1 & !match) | (pos1 & match) ;
	assign buf5   = (neg2 & !match) | (pos2 & match) ;

	wire   [4:0] buf_out;
        buffer couple_buffer[4:0] ({buf_out[3:0], wave[i-1]}, buf_out);

        // TODO: When we switch from a mismatch to a match,
	// sometimes we swap buffer configurations in a way
	// that causes oscillation.
	assign wave[i] = ~rstn ? 0          :
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
