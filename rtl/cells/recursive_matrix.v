

// Recursively split the remaining cells into 2x2
// chunks.

`timescale 1ns/1ps

// Includes are handled in the wrapper for this module.
`include "defines.vh"

module recursive_matrix #(parameter N = 8,
	             parameter NUM_WEIGHTS = 5,
	             parameter NUM_LUTS   = 2, 
	             parameter DIAGONAL   = 1) (
		     input  wire ising_rstn,

		     input  wire [N-1:0] inputs_ver_a ,
		     input  wire [N-1:0] inputs_hor_a ,
		     output wire [N-1:0] outputs_ver_a,
		     output wire [N-1:0] outputs_hor_a,
		     input  wire [N-1:0] inputs_ver_b,
		     input  wire [N-1:0] inputs_hor_b,
		     output wire [N-1:0] outputs_ver_b,
		     output wire [N-1:0] outputs_hor_b,

		     output wire [N-1:0] bot_row,

		     input  wire        clk,
		     input  wire        axi_rstn,
                     input  wire        wready,
		     input  wire        wr_match,
                     input  wire [$clog2(N)-1:0] s_addr,
                     input  wire [$clog2(N)-1:0] d_addr,
		     input  wire        s_gt_d,
                     input  wire [31:0] wdata,
		     output wire [31:0] rdata
	            );

    genvar j;

    // If N != 1, recurse.
    // Else, create the cells.
    generate if (N != 1) begin : recurse
        wire [N-1:0] osc_hor_in  ;
        wire [N-1:0] osc_ver_in  ;
        wire [N-1:0] osc_hor_out ;
        wire [N-1:0] osc_ver_out ;

        // Select cell based on addr
        wire tl, tr, bl;
        assign tl = wr_match & (~s_addr[0]) & (~d_addr[0]);
        assign br = wr_match & ( s_addr[0]) & ( d_addr[0]);
        assign tr = wr_match & (~tl       ) & (~br       ); 

	wire [31:0] tl_r, tr_r, br_r;
	assign rdata = tl ? tl_r :
		       tr ? tr_r :
		       br ? br_r : 32'hAAAAAAAA;

	// Get right row for phase measurement
	wire [(N/2)-1:0] bot_row_left ;
	wire [(N/2)-1:0] bot_row_right;
	assign bot_row = {bot_row_left, bot_row_right};

	// Top left
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL))
			top_left(.ising_rstn (ising_rstn),
				 .inputs_ver (osc_ver_in [N-1:(N/2)]),
				 .inputs_hor (inputs_hor [N-1:(N/2)]),
				 .outputs_ver(outputs_ver[N-1:(N/2)]),
				 .outputs_hor(osc_hor_out[N-1:(N/2)]),

				 .bot_row(),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tl),
				 .s_addr(s_addr[$clog2(N)-1:1]),
				 .d_addr(d_addr[$clog2(N)-1:1]),
				 .s_gt_d(s_gt_d),
				 .wdata(wdata),
			         .rdata(tl_r));
	// Top right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(0))
		       top_right(.ising_rstn (ising_rstn),
				 .inputs_ver (osc_ver_in [(N/2)-1:0]),
				 .inputs_hor (osc_hor_in [N-1:(N/2)]),
				 .outputs_ver(outputs_ver[(N/2)-1:0]),
				 .outputs_hor(outputs_hor[N-1:(N/2)]),

				 .bot_row(),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tr),
				 .s_addr(s_addr[$clog2(N)-1:1]),
				 .d_addr(d_addr[$clog2(N)-1:1]),
				 .s_gt_d(s_gt_d),
				 .wdata(wdata),
			         .rdata(tr_r));
	// Bottom right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL))
		       bot_right(.ising_rstn (ising_rstn),
				 .inputs_ver (inputs_ver [(N/2)-1:0]),
				 .inputs_hor (osc_hor_in [(N/2)-1:0]),
				 .outputs_ver(osc_ver_out[(N/2)-1:0]),
				 .outputs_hor(outputs_hor[(N/2)-1:0]),

				 .bot_row(bot_row_right),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(br),
				 .s_addr(s_addr[$clog2(N)-1:1]),
				 .d_addr(d_addr[$clog2(N)-1:1]),
				 .s_gt_d(s_gt_d),
				 .wdata(wdata),
			         .rdata(br_r));

	 // Add delays (only in sim)
	 `ifdef SIM
	     for (j = 0; j < N; j = j + 1) begin: delays
                  always @(osc_hor_out[j]) begin #20 osc_hor_in[j] <= osc_hor_out[j]; end
                  always @(osc_ver_out[j]) begin #20 osc_ver_in[j] <= osc_ver_out[j]; end
	     end
         `else
             assign osc_hor_in = osc_hor_out;
	     assign osc_ver_in = osc_ver_out;
         `endif

    // Diagonal base case is a shorted cell.
    end else if (DIAGONAL == 1) begin : shorted_cell
        assign bot_row = inputs_hor;
	shorted_cell #(.NUM_LUTS(NUM_LUTS))
	             i_short(.ising_rstn(ising_rstn),
			     .sin (inputs_ver ),
		             .din (inputs_hor ),
			     .sout(outputs_ver),
			     .dout(outputs_hor));

    // Otherwise, it's a coupled cell.
    end else begin : coupled_cell
        assign bot_row = inputs_hor;
        coupled_cell #(.NUM_WEIGHTS(NUM_WEIGHTS),
                       .NUM_LUTS   (NUM_LUTS   ))
	             ij   (.ising_rstn  (ising_rstn),
                              .sin   (inputs_ver ),
                              .din   (inputs_hor ),
                              .sout  (outputs_ver),
                              .dout  (outputs_hor),

	    	              .clk            (clk),
                              .axi_rstn       (axi_rstn),
                              .wready         (wready),
                              .wr_addr_match  (wr_match),
			      .s_gt_d         (s_gt_d),
                              .wdata          (wdata),
		              .rdata          (rdata));
    end endgenerate


endmodule
