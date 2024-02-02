
// AXI-compatible wrapper for Ising machine.
//
// All control registers live here.

`timescale 1ns/1ps
`include "top_ising.v"

`define START_ADDR       32'h00000500
`define CTR_CUTOFF_ADDR  32'h00000600
`define CTR_MAX_ADDR     32'h00000700
`define PHASE_ADDR_BASE  32'h00000800
`define WEIGHT_ADDR_BASE 32'h00001000

module ising_axi    #(parameter N = 3,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
		     parameter NUM_LUTS = 2) (
		     input  wire clk,
		     input  wire axi_rstn,

		     // AXI Read port
		     input  wire        arvalid_q,
		     input  wire [31:0] araddr_q,
		     input  wire        rready,
                     output reg         rvalid,
	             output reg         rresp,	     
		     output reg  [31:0] rdata,

		     // AXI Write port
		     input  wire        wready,
	             input  wire [31:0] wr_addr,
		     input  wire [31:0] wdata
	            );

    wire [N-1:0] phase;
    wire [ 31:0] phase_bit;
    assign       phase_bit = (araddr_q - `PHASE_ADDR_BASE) >> 5;

    // AXI Read Interface
    always @(posedge clk) begin
        if (!axi_rstn) begin
            rvalid <= 0;
            rdata  <= 0;
            rresp  <= 0;
        end
        else if (rvalid && rready) begin
            rvalid <= 0;
            rdata  <= 0;
            rresp  <= 0;
        end
	else if (arvalid_q) begin
            rvalid <= 1;
	    rdata  <= {31'b0, phase[phase_bit]};
            rresp  <= 0;
        end
    end

    // AXI Write Interface
    reg [31:0] counter_cutoff;
    reg [31:0] counter_max;
    reg        ising_rstn;
    reg [(NUM_WEIGHTS*(N*(N-1)/2))-1:0] weights;
    
    wire [31:0] counter_cutoff_nxt = (wready & (wr_addr == `CTR_CUTOFF_ADDR)) ?
	                             wdata : counter_cutoff; 
    wire [31:0] counter_max_nxt    = (wready & (wr_addr == `CTR_MAX_ADDR)) ?
	                             wdata : counter_max; 
    wire        ising_rstn_nxt     = (wready & (wr_addr == `START_ADDR)) ?
	                             wdata[0] : ising_rstn; 
    
    wire [(NUM_WEIGHTS*(N*(N-1)/2))-1:0] weights_nxt;
    wire [(NUM_WEIGHTS*(N*(N-1)/2))-1:0] weights_rst;
    genvar i;
    generate for (i = 0 ; i < (N*(N-1)/2) ; i = i+1) begin
        assign weights_nxt[i*NUM_WEIGHTS +: NUM_WEIGHTS] = (wready & (wr_addr == (`WEIGHT_ADDR_BASE + (32*i)))) ?
	             	                                    wdata[NUM_WEIGHTS:0] : weights[i*NUM_WEIGHTS +: NUM_WEIGHTS];
        assign weights_rst[i*NUM_WEIGHTS +: NUM_WEIGHTS] = {{(NUM_WEIGHTS/2){1'b0}},1'b1,{(NUM_WEIGHTS/2){1'b0}}}; //NUM_WEIGHTS must be odd.
    end endgenerate

    always @(posedge clk) begin
        if (!axi_rstn) begin
            counter_cutoff <= 32'b0;
	    counter_max <= 32'b0;
            ising_rstn <= 1'b0;
	    weights <= weights_rst;
        end
        else begin
            counter_cutoff <= counter_cutoff_nxt;
            counter_max <= counter_max_nxt;
            ising_rstn <= ising_rstn_nxt;
	    weights <= weights_nxt;
        end
    end

    top_ising   #(.N(N),
	          .NUM_LUTS(NUM_LUTS),
                  .NUM_WEIGHTS(NUM_WEIGHTS),
                  .WIRE_DELAY(WIRE_DELAY)) u_top_ising (
                  .clk(clk),
                  .rstn(ising_rstn),
                  .weights(weights),
                  .counter_max(counter_max),
                  .counter_cutoff(counter_cutoff),
                  .phase(phase));

endmodule
