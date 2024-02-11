
// AXI-compatible wrapper for Ising machine.
//
// All control registers live here.

`timescale 1ns/1ps

`include "defines.vh"
`include "top_ising.v"

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
    assign       phase_bit = (araddr_q - `PHASE_ADDR_BASE) >> 2;

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
    
    wire [31:0] counter_cutoff_nxt = (wready & (wr_addr == `CTR_CUTOFF_ADDR)) ?
	                             wdata : counter_cutoff; 
    wire [31:0] counter_max_nxt    = (wready & (wr_addr == `CTR_MAX_ADDR)) ?
	                             wdata : counter_max; 
    wire        ising_rstn_nxt     = (wready & (wr_addr == `START_ADDR)) ?
	                             wdata[0] : ising_rstn; 
    
    always @(posedge clk) begin
        if (!axi_rstn) begin
            counter_cutoff <= 32'b0;
	    counter_max <= 32'b0;
            ising_rstn <= 1'b0;
        end
        else begin
            counter_cutoff <= counter_cutoff_nxt;
            counter_max <= counter_max_nxt;
            ising_rstn <= ising_rstn_nxt;
        end
    end

    top_ising   #(.N(N),
	          .NUM_LUTS(NUM_LUTS),
                  .NUM_WEIGHTS(NUM_WEIGHTS),
                  .WIRE_DELAY(WIRE_DELAY)) u_top_ising (
                  .clk(clk),
                  .ising_rstn(ising_rstn),
                  .counter_max(counter_max),
                  .counter_cutoff(counter_cutoff),
                  .phase(phase),
	          .axi_rstn(axi_rstn),
	          .wready(wready),
	          .wr_addr(wr_addr),
	          .wdata(wdata)
    );

endmodule
