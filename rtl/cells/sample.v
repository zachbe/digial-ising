

// Sample the relative phases of the local field (outputs_hor) and the spins
// in the ising machine (outputs_ver).
// 
// We do this by simply sampling the XOR of the two signals, and then keeping
// count of the total samples of each direction we've had. As long as our
// sampling clock frequency isn't much faster than the oscillation frequency,
// we'll get a good phase sample.
//
// TODO: Get more complex phase measurements than "in or out of phase with the
// local field".

`timescale 1ns/1ps

`include "defines.vh"

module sample #(parameter N = 3)(
	        input  wire clk,
	        input  wire rstn,
                input  wire [31 :0] counter_max,
		input  wire [31 :0] counter_cutoff,
	        input  wire [N-1:0] outputs_ver,
	        input  wire [N-1:0] outputs_hor,
		output wire [31:0]  phase,
		input  wire [31:0]  rd_addr 
	       );

    wire [N-1:0] phase_mismatch;
    assign phase_mismatch = outputs_ver ^ outputs_hor;

    reg  [31:0] phase_counters     [N-1:0];
    wire [31:0] phase_counters_nxt [N-1:0];

    wire [N-1:0] overflow;
    wire [N-1:0] underflow;

    wire [31:0] phase_index = (rd_addr - `PHASE_ADDR_BASE) >> 2;
    assign phase = phase_counters[phase_index];

    genvar i;
    generate for (i = 0; i < N ; i = i+1) begin
	assign overflow [i] = (phase_counters[i] >= counter_max);
	assign underflow[i] = (phase_counters[i] == 0);

        assign phase_counters_nxt[i] = ~rstn             ? counter_cutoff         :   
		                       phase_mismatch[i] ? (
		                       underflow         ? phase_counters[i]      :
				                           phase_counters[i] - 1 ):(
				       overflow          ? phase_counters[i]      :
		                                           phase_counters[i] + 1 );

        always @(posedge clk) begin
	    phase_counters[i] <= phase_counters_nxt[i];
	end
    end endgenerate
endmodule
