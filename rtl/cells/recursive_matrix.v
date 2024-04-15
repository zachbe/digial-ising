

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

                     input  wire [N-1:0] lin,
                     input  wire [N-1:0] rin,
                     input  wire [N-1:0] tin,
                     input  wire [N-1:0] bin,
                     output wire [N-1:0] lout,
                     output wire [N-1:0] rout,
                     output wire [N-1:0] tout,
                     output wire [N-1:0] bout,

		     output wire [N-1:0] right_col,

		     input  wire        clk,
		     input  wire        axi_rstn,
                     input  wire        wready,
		     input  wire        wr_match,
                     input  wire [$clog2(N)-1:0] s_addr,
                     input  wire [$clog2(N)-1:0] d_addr,
		     input  wire        vh,
                     input  wire [31:0] wdata,
		     output wire [31:0] rdata
	            );

    genvar j;

    // If N != 1, recurse.
    // Else, create the cells.
    generate if (N != 1) begin : recurse
        wire [(N/2)-1:0] int_r_i;
        wire [(N/2)-1:0] int_t_i;
        wire [(N/2)-1:0] int_b_i;
        wire [(N/2)-1:0] int_l_i;
        wire [(N/2)-1:0] int_r_o;
        wire [(N/2)-1:0] int_t_o;
        wire [(N/2)-1:0] int_b_o;
        wire [(N/2)-1:0] int_l_o;
	
	// When we step off the diagonal, set vh value.
	// If we're already off the diagonal, keep vh value.
	wire vh_new;
	assign vh_new = DIAGONAL ? s_addr[0] :
		                   vh        ;

        // Select cell based on addr and vh
        wire tl, tr, bl;
        assign tl = wr_match & (~s_addr[0]) & (~d_addr[0]);
        assign br = wr_match & ( s_addr[0]) & ( d_addr[0]);
        assign tr = wr_match & ( s_addr[0]) & (~d_addr[0]);	

	wire [31:0] tl_r, tr_r, br_r;
	assign rdata = tl ? tl_r :
		       tr ? tr_r :
		       br ? br_r : 32'hAAAAAAAA;

	// Get right col for phase measurement
	wire [(N/2)-1:0] right_col_top;
	wire [(N/2)-1:0] right_col_bot;
	assign right_col = {right_col_left, right_col_right};

	// Top left
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL))
			top_left(.ising_rstn (ising_rstn),
                                 .lin  (    /* None */     ),
                                 .rin  (int_r_i            ),
                                 .tin  (tin     [N-1:(N/2)]),
                                 .bin  (    /* None */     ),
			         .lout (    /* None */     ),
			         .rout (int_r_o            ),
			         .tout (tout    [N-1:(N/2)]),
			         .bout (    /* None */     ),

				 .right_col(),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tl),
				 .s_addr(s_addr[$clog2(N)-1:1]),
				 .d_addr(d_addr[$clog2(N)-1:1]),
				 .vh(vh_new),
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
                                 .lin  (int_l_i            ),
                                 .rin  (rin     [N-1:(N/2)]),
                                 .tin  (tin     [(N/2)-1:0]),
                                 .bin  (int_b_i            ),
			         .lout (int_l_o            ),
			         .rout (rout    [N-1:(N/2)]),
			         .tout (tout    [(N/2)-1:0]),
			         .bout (int_b_o            ),

				 .right_col(right_col_top),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tr),
				 .s_addr(s_addr[$clog2(N)-1:1]),
				 .d_addr(d_addr[$clog2(N)-1:1]),
				 .vh(vh_new),
				 .wdata(wdata),
			         .rdata(tr_r));
	// Bottom right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL))
		       bot_right(.ising_rstn (ising_rstn),
                                 .lin  (    /* None */     ),
                                 .rin  (rin     [(N/2)-1:0]),
                                 .tin  (int_t_i            ),
                                 .bin  (    /* None */     ),
			         .lout (    /* None */     ),
			         .rout (rout    [(N/2)-1:0]),
			         .tout (int_t_o            ),
			         .bout (    /* None */     ),

				 .right_col(right_col_bot),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(br),
				 .s_addr(s_addr[$clog2(N)-1:1]),
				 .d_addr(d_addr[$clog2(N)-1:1]),
				 .vh(vh_new),
				 .wdata(wdata),
			         .rdata(br_r));

	 // Add delays (only in sim)
	 `ifdef SIM
	     for (j = 0; j < N; j = j + 1) begin: delays
                  always @(int_b_o[j]) begin #20 int_t_i[j] <= int_b_o[j]; end
                  always @(int_l_o[j]) begin #20 int_r_i[j] <= int_l_o[j]; end
                  always @(int_t_o[j]) begin #20 int_b_i[j] <= int_t_o[j]; end
                  always @(int_r_o[j]) begin #20 int_l_i[j] <= int_r_o[j]; end
	     end
         `else
             assign int_t_i = int_b_o;
             assign int_r_i = int_l_o;
             assign int_b_i = int_t_o;
             assign int_l_i = int_r_o;
         `endif

    // Diagonal base case is a shorted cell.
    end else if (DIAGONAL == 1) begin : shorted_cell
        assign right_col = tout;
	shorted_cell #(.NUM_LUTS(NUM_LUTS))
	             i_short(.ising_rstn(ising_rstn),
			     .tin  (tin),
		             .rin  (rin),
			     .tout (tout),
			     .rout (rout),
	    	              
		             .clk            (clk),
                             .axi_rstn       (axi_rstn),
                             .wready         (wready),
                             .wr_addr_match  (wr_match),
                             .wdata          (wdata),
		             .rdata          (rdata));

    // Otherwise, it's a coupled cell.
    end else begin : coupled_cell
        assign right_col = tout;
        coupled_cell #(.NUM_WEIGHTS(NUM_WEIGHTS),
                       .NUM_LUTS   (NUM_LUTS   ))
	             ij   (.ising_rstn  (ising_rstn),
                              .lin  (lin ),
                              .rin  (rin ),
                              .tin  (tin ),
                              .bin  (bin ),
			      .lout (lout),
			      .rout (rout),
			      .tout (tout),
			      .bout (bout),

	    	              .clk            (clk),
                              .axi_rstn       (axi_rstn),
                              .wready         (wready),
                              .wr_addr_match  (wr_match),
			      .vh             (vh),
                              .wdata          (wdata),
		              .rdata          (rdata));
    end endgenerate


endmodule
