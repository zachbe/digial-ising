

// Our top-level Ising machine block, with both an array of oscillators and
// a sampler.
//
// This block doesn't include any smart interfacing yet.

`timescale 1ns/1ps
`include "../cells/core_matrix.v"
`include "../cells/sample.v"


module top_ising   #(parameter N = 3,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
	             parameter COUNTER_DEPTH = 5,
	             parameter COUNTER_CUTOFF = 16) (
		     input  wire clk,
		     input  wire rstn,
		     input  wire [($clog2(NUM_WEIGHTS)*(N*(N-1)/2))-1:0] weights,
		     output wire [N-1:0] phase
	            );

    wire [N-1:0] outputs_ver;
    wire [N-1:0] outputs_hor;

    core_matrix #(.N(N),
	          .NUM_WEIGHTS(NUM_WEIGHTS),
	          .WIRE_DELAY(WIRE_DELAY)) u_core_matrix (
		  .rstn(rstn),
		  .weights(weights),
		  .outputs_ver(outputs_ver),
		  .outputs_hor(outputs_hor)
    );

    sample #(.N(N)
             .COUNTER_DEPTH(COUNTER_DEPTH),
	     .COUNTER_CUTOFF(COUNTER_CUTOFF)) u_sampler (
	     .clk(clk),
	     .rstn(rstn),
	     .outputs_ver(outputs_ver),
	     .outputs_hor(outputs_hor),
	     .phase(phase)
     );

endmodule
