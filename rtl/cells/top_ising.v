

// Our top-level Ising machine block, with both an array of oscillators and
// a sampler.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "core_matrix.v"
    `include "sample.v"
`endif

module top_ising   #(parameter N = 3,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
		     parameter NUM_LUTS = 2) (
		     input  wire clk,
		     input  wire ising_rstn,
		     input  wire [31 :0] counter_max, 
		     input  wire [31 :0] counter_cutoff, 
		     output wire [N-1:0] phase,

		     input  wire        axi_rstn,
                     input  wire        wready,
                     input  wire [31:0] wr_addr,
                     input  wire [31:0] wdata,
		     input  wire [31:0] rd_addr,
		     output wire [31:0] rdata
	            );

    wire [N-1:0] outputs_ver;
    wire [N-1:0] outputs_hor;

    core_matrix #(.N(N),
	          .NUM_WEIGHTS(NUM_WEIGHTS),
	          .WIRE_DELAY(WIRE_DELAY),
	          .NUM_LUTS(NUM_LUTS)) u_core_matrix (
		  .ising_rstn(ising_rstn),
		  .outputs_ver(outputs_ver),
		  .outputs_hor(outputs_hor),
		  .clk(clk),
	          .axi_rstn(axi_rstn),
	          .wready(wready),
	          .wr_addr(wr_addr),
	          .wdata(wdata),
		  .rd_addr(rd_addr),
		  .rdata(rdata)
    );

    sample #(.N(N)) u_sampler (
	     .clk(clk),
	     .rstn(ising_rstn),
	     .counter_max(counter_max),
	     .counter_cutoff(counter_cutoff),
	     .outputs_ver(outputs_ver),
	     .outputs_hor(outputs_hor),
	     .phase(phase)
     );

endmodule
