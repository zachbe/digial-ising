
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
// TODO: In practice, this can be implementd with a series of
// multiplexers and buffers.

`timescale 1ns/1ps

module oscillator #(parameter PORTS = 16)(
                    //Coupling weights can fall between -2 and +2
		    input wire [(3*PORTS)-1:0] coupling_weights,
	            input wire [PORTS-1    :0] coupling_inputs,
		    input wire rstn, //negedge reset
		    output wire out);

    wire [PORTS:0] wave;
    reg  [PORTS:1] wave_reg;

    assign wave[0] = rstn ? ~out : 0;
    assign out = rstn ? wave[PORTS] : 0;

    // check if we're matching the coupled input or not
    wire [PORTS-1:0] match;
    assign match = rstn ? ~(coupling_inputs ^ {PORTS{out}}) : 0 ;

    genvar i;
    generate for (i = 1; i <= PORTS; i=i+1) begin
	assign wave[i] = rstn ? wave_reg[i] : 0;
	wire [2:0] weight;
	assign weight = coupling_weights[(i-1)*3 + 2 : (i-1)*3];
	always @(*) begin
	    case(weight)
	        3'b000: begin
	                // -2: slow down if input is mismatch
	                //     speed up if input is match
			if (match[i]) begin #1 wave_reg[i] = wave[i-1]; end
			else begin #5 wave_reg[i] = wave[i-1]; end
	        	end
	        3'b001: begin
	                // -1: slow down if input is mismatch
	                //     speed up if input is match
			if (match[i]) begin #2 wave_reg[i] = wave[i-1]; end
			else begin #4 wave_reg[i] = wave[i-1]; end
	        	end
	        3'b010: begin
	                // 0:  no speed change
	        	#3 wave_reg[i] = wave[i-1];
	        	end
	        3'b011: begin
	                // +1: speed up if input is mismatch
	                //     slow down if input is match
			if (match[i]) begin #4 wave_reg[i] = wave[i-1]; end
			else begin #2 wave_reg[i] = wave[i-1]; end
	        	end
	        3'b100: begin
	                // +2: speed up if input is mismatch
	                //     slow down if input is match
			if (match[i]) begin #5 wave_reg[i] = wave[i-1]; end
			else begin #1 wave_reg[i] = wave[i-1]; end
	        	end
	    endcase
	end
    end endgenerate

endmodule
