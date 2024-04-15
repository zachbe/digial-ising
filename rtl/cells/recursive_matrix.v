

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
		     // Keeping an addr extra bit around so that
		     // we don't end up with [-1:0]
                     input  wire [$clog2(N):0] s_addr,
                     input  wire [$clog2(N):0] d_addr,
		     input  wire        vh,
                     input  wire [31:0] wdata,
		     output wire [31:0] rdata
	            );

    genvar j;

    // If N != 1, recurse.
    // Else, create the cells.
    generate if (N != 1) begin : recurse
	`ifdef SIM
        reg  [N-1:0] int_r_i;
        reg  [N-1:0] int_t_i;
        reg  [N-1:0] int_b_i;
        reg  [N-1:0] int_l_i;
	`else
        wire [N-1:0] int_r_i;
        wire [N-1:0] int_t_i;
        wire [N-1:0] int_b_i;
        wire [N-1:0] int_l_i;
        `endif
        wire [N-1:0] int_r_o;
        wire [N-1:0] int_t_o;
        wire [N-1:0] int_b_o;
        wire [N-1:0] int_l_o;
	
        // Select cell based on addr and vh
        wire tl, tr, bl, br;
        assign tl = wr_match & (~s_addr[$clog2(N)-1]) & (~d_addr[$clog2(N)-1]);
        assign br = wr_match & ( s_addr[$clog2(N)-1]) & ( d_addr[$clog2(N)-1]);
        assign tr = wr_match & ( s_addr[$clog2(N)-1]) & (~d_addr[$clog2(N)-1]);	
        assign bl = wr_match & (~s_addr[$clog2(N)-1]) & ( d_addr[$clog2(N)-1]);	
	
	// "Fold" the matrix in half on the diagonal
	wire tr_m = DIAGONAL ? (tr | bl) : ( vh ? tr : bl);
	wire bl_m = DIAGONAL ? (  1'b0 ) : (~vh ? tr : bl);

	// Read value based on selection
	wire [31:0] tl_r, tr_r, br_r, bl_r;
	assign rdata = tl   ? tl_r :
		       tr_m ? tr_r :
		       br   ? br_r :
		       bl   ? bl_r : 32'hAAAAAAAA;

	// Get right col for phase measurement
	wire [(N/2)-1:0] right_col_top;
	wire [(N/2)-1:0] right_col_bot;
	assign right_col = {right_col_top, right_col_bot};

	// Top left
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL))
			top_left(.ising_rstn (ising_rstn),
                                 .lin  (lin     [N-1:(N/2)]),
                                 .rin  (int_r_i [N-1:(N/2)]),
                                 .tin  (tin     [N-1:(N/2)]),
                                 .bin  (int_b_i [N-1:(N/2)]),
			         .lout (lout    [N-1:(N/2)]),
			         .rout (int_r_o [N-1:(N/2)]),
			         .tout (tout    [N-1:(N/2)]),
			         .bout (int_b_o [N-1:(N/2)]),

				 .right_col(),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tl),
				 .s_addr(s_addr[$clog2(N)-1:0]),
				 .d_addr(d_addr[$clog2(N)-1:0]),
				 .vh(vh),
				 .wdata(wdata),
			         .rdata(tl_r));
	// Top right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(0))
		       top_right(.ising_rstn (ising_rstn),
                                 .lin  (int_l_i [N-1:(N/2)]),
                                 .rin  (rin     [N-1:(N/2)]),
                                 .tin  (tin     [(N/2)-1:0]),
                                 .bin  (int_b_i [(N/2)-1:0]),
			         .lout (int_l_o [N-1:(N/2)]),
			         .rout (rout    [N-1:(N/2)]),
			         .tout (tout    [(N/2)-1:0]),
			         .bout (int_b_o [(N/2)-1:0]),

				 .right_col(right_col_top),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tr_m),
				 .s_addr(s_addr[$clog2(N)-1:0]),
				 .d_addr(d_addr[$clog2(N)-1:0]),
				 .vh(vh),
				 .wdata(wdata),
			         .rdata(tr_r));
	// Bottom right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL))
		       bot_right(.ising_rstn (ising_rstn),
                                 .lin  (int_l_i [(N/2)-1:0]),
                                 .rin  (rin     [(N/2)-1:0]),
                                 .tin  (int_t_i [(N/2)-1:0]),
                                 .bin  (bin     [(N/2)-1:0]),
			         .lout (int_l_o [(N/2)-1:0]),
			         .rout (rout    [(N/2)-1:0]),
			         .tout (int_t_o [(N/2)-1:0]),
			         .bout (bout    [(N/2)-1:0]),

				 .right_col(right_col_bot),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(br),
				 .s_addr(s_addr[$clog2(N)-1:0]),
				 .d_addr(d_addr[$clog2(N)-1:0]),
				 .vh(vh),
				 .wdata(wdata),
			         .rdata(br_r));

	// Bottom left
	if (DIAGONAL == 0) begin
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(0))
		     bottom_left(.ising_rstn (ising_rstn),
                                 .lin  (lin     [(N/2)-1:0]),
                                 .rin  (int_r_i [(N/2)-1:0]),
                                 .tin  (int_t_i [N-1:(N/2)]),
                                 .bin  (bin     [N-1:(N/2)]),
			         .lout (lout    [(N/2)-1:0]),
			         .rout (int_r_o [(N/2)-1:0]),
			         .tout (int_t_o [N-1:(N/2)]),
			         .bout (bout    [N-1:(N/2)]),

				 .right_col(),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(bl_m),
				 .s_addr(s_addr[$clog2(N)-1:0]),
				 .d_addr(d_addr[$clog2(N)-1:0]),
				 .vh(vh),
				 .wdata(wdata),
			         .rdata(bl_r));
        end else begin
	    assign bl_r = 32'hAAAAAAAA;
        end

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
