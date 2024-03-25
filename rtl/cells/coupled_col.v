
// The Kth column of the coupling matrix
// used by DIMPLE.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "coupled_cell.v"
`endif

module coupled_col      #(parameter N           = 8,
	                  parameter K           = 0,
	                  parameter NUM_WEIGHTS = 5,
	                  parameter WIRE_DELAY  = 20,
	                  parameter NUM_LUTS    = 2  ) (

		          input  wire ising_rstn,

		          input  wire [N-1:0] in_wires,
		          output wire [N-1:0] out_wires,

		          input  wire        clk,
		          input  wire        axi_rstn,
                          input  wire        wready,
		          input  wire        wr_match,
                          input  wire [15:0] s_addr,
                          input  wire [15:0] d_addr,
                          input  wire [31:0] wdata,
		          output wire [31:0] rdata
	                  );

    genvar i,j,k;
    wire [N-1:0] out_wires_pre;
    
    generate for (i = 0; i < N; i = i + 1) begin : coupled_loop
        // Couple i to (i+K+1)%N
	// This is an asymmetric coupling
	wire [31:0] rdata_loop;
	wire   wr_match_loop;
	assign wr_match_loop = wr_match & ((s_addr == i) | (d_addr == i)); // TODO: make asymmetric
        coupled_cell #(.NUM_WEIGHTS(NUM_WEIGHTS),
                       .NUM_LUTS   (NUM_LUTS   ))
    	            ij(.ising_rstn  (ising_rstn),
                       .sout  (out_wires_pre[(i+K+1)%N]),
                       .din   (in_wires[i]),
                       .dout  (out_wires_pre[i]),

    		       .clk            (clk),
                       .axi_rstn       (axi_rstn),
                       .wready         (wready),
                       .wr_addr_match  (wr_match_loop),
                       .wdata          (wdata),
    	               .rdata          (rdata_loop));
	wire [31:0] rdata_out;
	if (i == 0) begin
            assign rdata_out = wr_match_loop ? rdata_loop   : 
	    	                               32'hAAAAAAAA ;
	end else begin
            assign rdata_out = wr_match_loop ? rdata_loop                  : 
	    	                               coupled_loop[i-1].rdata_out ;
        end
    end endgenerate
    assign rdata = coupled_loop[N-1].rdata_out;

    // Add delays
    for (j = 0; j < N; j = j + 1) begin : rec_delays
        wire [WIRE_DELAY-1:0] out_del;
        // Array of generic delay buffers
        buffer #(NUM_LUTS) buf0(.in(out_wires_pre[j]), .out(out_del[0]));
        for (k = 1; k < WIRE_DELAY; k = k + 1) begin
            buffer #(NUM_LUTS) bufi(.in(out_del[k-1]), .out(out_del[k]));
        end
        assign out_wires[j] = out_del[WIRE_DELAY-1];
    end

endmodule
