
// A couple-able ring oscillator.
//
// Consists of an inverter, N coupled delay ports,
// and an output port.
//
//            N   wave     0
//      |---<---<---<---<--|
//  out-|                  |
//      |-->o--------------|
//
//
//

`timescale 1ns/1ps

module oscillator #(parameter PORTS = 16)(
                    //Coupling weights can fall between -2 and +2
		    input wire [PORTS-1:0] coupling_weights [2:0],
	            input wire [PORTS-1:0] coupling_inputs,
		    output wire out);

    wire [PORTS:0] wave;

    // for now, inverter has no delay
    assign wave[0] = ~out;
    
    // for now, output has no delay
    assign out = wave[PORTS];

    // check if we're matching the coupled input or not
    wire [PORTS-1:0] match;
    assign match = coupling_inputs & {PORTS{out}};

    genvar i;
    generate for (i = 1; i <= PORTS; i=i+1) begin
	always (*) begin
	    case(coupling_weights[i])
	        3'b000: begin
	                // -2: slow down if input is mismatch
		        //     speed up if input is match
			if (match[i]) #1 wave[i] = wave[i-1];
			else #5 wave[i] = wave[i-1];
			end
	        3'b001: begin
	                // -1: slow down if input is mismatch
		        //     speed up if input is match
			if (match[i]) #2 wave[i] = wave[i-1];
			else #4 wave[i] = wave[i-1];
			end
	        3'b010: begin
	                // 0:  no speed change
			#3 wave[i] = wave[i-1];
			end
	        3'b011: begin
	                // +1: speed up if input is mismatch
		        //     slow down if input is match
			if (match[i]) #4 wave[i] = wave[i-1];
			else #2 wave[i] = wave[i-1];
			end
	        3'b100: begin
	                // +2: speed up if input is mismatch
		        //     slow down if input is match
			if (match[i]) #5 wave[i] = wave[i-1];
			else #1 wave[i] = wave[i-1];
			end
	end
    end endgenerate

endmodule
