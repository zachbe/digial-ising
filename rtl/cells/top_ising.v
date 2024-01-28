

// Our top-level Ising machine block, with both an array of oscillators and
// a sampler.

`timescale 1ns/1ps
`include "core_matrix.v"
`include "sample.v"


module top_ising   #(parameter N = 3,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
		     parameter NUM_LUTS = 2) (
		     input  wire clk,
		     input  wire rstn,
		     input  wire [(NUM_WEIGHTS*(N*(N-1)/2))-1:0] weights,
		     input  wire [31 :0] counter_max, 
		     input  wire [31 :0] counter_cutoff, 
		     output wire [N-1:0] phase
	            );

    wire [N-1:0] outputs_ver;
    wire [N-1:0] outputs_hor;

    core_matrix #(.N(N),
	          .NUM_WEIGHTS(NUM_WEIGHTS),
	          .WIRE_DELAY(WIRE_DELAY),
	          .NUM_LUTS(NUM_LUTS)) u_core_matrix (
		  .rstn(rstn),
		  .weights(weights),
		  .outputs_ver(outputs_ver),
		  .outputs_hor(outputs_hor)
    );

    sample #(.N(N)) u_sampler (
	     .clk(clk),
	     .rstn(rstn),
	     .counter_max(counter_max),
	     .counter_cutoff(counter_cutoff),
	     .outputs_ver(outputs_ver),
	     .outputs_hor(outputs_hor),
	     .phase(phase)
     );

endmodule
