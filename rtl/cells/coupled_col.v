
// The Kth column of the coupling matrix
// used by DIMPLE.

`timescale 1ns/1ps

// Includes are handled in the wrapper for this module.
`include "defines.vh"

module coupled_col      #(parameter N           = 8,
	                  parameter K           = 0,
	                  parameter NUM_WEIGHTS = 5,
	                  parameter WIRE_DELAY  = 20,
	                  parameter NUM_LUTS    = 2  ) (

		          input  wire ising_rstn,

		          input  wire [N-1:0] in_wires,
		          input  wire [N-1:0] out_wires,

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
    
    // Even columns
    generate if (K % 2 = 0) begin : even_col
        for (i = 0; i < (N/2); i+=2) begin : coupled_loop
            // Couple even wires with odd wires
            coupled_cell #(.NUM_WEIGHTS(NUM_WEIGHTS),
                           .NUM_LUTS   (NUM_LUTS   ))
    	                ij(.ising_rstn  (ising_rstn),
                           .sin   (in_wires[i]),
                           .din   (in_wires[(i+K+1)%N]),
                           .sout  (out_wires_pre[i]),
                           .dout  (out_wires_pre[(i+K+1)%N]),

    	    	           .clk            (clk),
                           .axi_rstn       (axi_rstn),
                           .wready         (wready),
                           .wr_addr_match  (wr_match),
                           .wdata          (wdata),
    		           .rdata          (rdata));
	end
    end else begin: odd_col	
        for (i = 0; i < (N/2); i+=4) begin : coupled_loop
            // Couple even wires with even wires
            coupled_cell #(.NUM_WEIGHTS(NUM_WEIGHTS),
                           .NUM_LUTS   (NUM_LUTS   ))
    	           ij_even(.ising_rstn  (ising_rstn),
                           .sin   (in_wires[i]),
                           .din   (in_wires[(i+K+1)%N]),
                           .sout  (out_wires_pre[i]),
                           .dout  (out_wires_pre[(i+K+1)%N]),

    	    	           .clk            (clk),
                           .axi_rstn       (axi_rstn),
                           .wready         (wready),
                           .wr_addr_match  (wr_match),
                           .wdata          (wdata),
    		           .rdata          (rdata));
	    // and odd wires with odd wires
            coupled_cell #(.NUM_WEIGHTS(NUM_WEIGHTS),
                           .NUM_LUTS   (NUM_LUTS   ))
    	            ij_odd(.ising_rstn  (ising_rstn),
                           .sin   (in_wires[i+1]),
                           .din   (in_wires[(i+K+2)%N]),
                           .sout  (out_wires_pre[i+1]),
                           .dout  (out_wires_pre[(i+K+2)%N]),

    	    	           .clk            (clk),
                           .axi_rstn       (axi_rstn),
                           .wready         (wready),
                           .wr_addr_match  (wr_match),
                           .wdata          (wdata),
    		           .rdata          (rdata));
	end
    end endgenerate

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
