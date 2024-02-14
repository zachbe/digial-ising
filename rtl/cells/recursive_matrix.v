

// Recursively split the remaining cells into 2x2
// chunks.

`timescale 1ns/1ps

// Includes are handled in the wrapper for this module.
`include "defines.vh"

module recursive_matrix #(parameter N = 8,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
	             parameter NUM_LUTS   = 2, 
	             parameter DIAGONAL   = 1,
	             parameter TRANSPOSE  = 0) (
		     input  wire ising_rstn,

		     input  wire [N-1:0] inputs_ver,
		     input  wire [N-1:0] inputs_hor,
		     output wire [N-1:0] outputs_ver,
		     output wire [N-1:0] outputs_hor,

		     output wire [N-1:0] bot_row,

		     input  wire        clk,
		     input  wire        axi_rstn,
                     input  wire        wready,
		     input  wire        wr_match,
                     input  wire [15:0] s_addr,
                     input  wire [15:0] d_addr,
                     input  wire [31:0] wdata
	            );

    genvar j,k;

    // If N != 1, recurse.
    // Else, create the cells.
    generate if (N != 1) begin : recurse
        wire [N-1:0] osc_hor_in  ;
        wire [N-1:0] osc_ver_in  ;
        wire [N-1:0] osc_hor_out ;
        wire [N-1:0] osc_ver_out ;

        // Select cell based on addr
        wire tl, tr, bl, br, tr_m, bl_m;
        assign tl = wr_match & (~s_addr[15]) & (~d_addr[15]);
        assign tr = wr_match & (~s_addr[15]) & ( d_addr[15]);
        assign br = wr_match & ( s_addr[15]) & ( d_addr[15]);
        assign bl = wr_match & ( s_addr[15]) & (~d_addr[15]);

	assign tr_m = TRANSPOSE ? bl : tr;
	assign bl_m = DIAGONAL  ? tr :
		      TRANSPOSE ? tr : bl;

	// Get bottom row for phase measurement
	wire [(N/2)-1:0] bot_row_left ;
	wire [(N/2)-1:0] bot_row_right;
	assign bot_row = {bot_row_left, bot_row_right};

	// Top left
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .WIRE_DELAY(WIRE_DELAY),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL),
		           .TRANSPOSE(TRANSPOSE))
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
				 .s_addr({s_addr[14:0], 1'b0}),
				 .d_addr({d_addr[14:0], 1'b0}),
				 .wdata(wdata));
	// Top right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .WIRE_DELAY(WIRE_DELAY),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(0),
		           .TRANSPOSE(TRANSPOSE))
		       top_right(.ising_rstn (ising_rstn),
				 .inputs_ver (osc_ver_in [(N/2)-1:0]),
				 .inputs_hor (osc_hor_in [N-1:(N/2)]),
				 .outputs_ver(outputs_ver[(N/2)-1:0]),
				 .outputs_hor(outputs_hor[N-1:(N/2)]),

				 .bot_row(),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tr_m),
				 .s_addr({s_addr[14:0], 1'b0}),
				 .d_addr({d_addr[14:0], 1'b0}),
				 .wdata(wdata));
	// Bottom right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .WIRE_DELAY(WIRE_DELAY),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL),
		           .TRANSPOSE(TRANSPOSE))
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
				 .s_addr({s_addr[14:0], 1'b0}),
				 .d_addr({d_addr[14:0], 1'b0}),
				 .wdata(wdata));
	// Bottom left
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .WIRE_DELAY(WIRE_DELAY),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(0),
		           .TRANSPOSE(DIAGONAL | TRANSPOSE))
		        bot_left(.ising_rstn (ising_rstn),
				 .inputs_ver (inputs_ver [N-1:(N/2)]),
				 .inputs_hor (inputs_hor [(N/2)-1:0]),
				 .outputs_ver(osc_ver_out[N-1:(N/2)]),
				 .outputs_hor(osc_hor_out[(N/2)-1:0]),

				 .bot_row(bot_row_left),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(bl_m),
				 .s_addr({s_addr[14:0], 1'b0}),
				 .d_addr({d_addr[14:0], 1'b0}),
				 .wdata(wdata));
        // Add delays
        for (j = 0; j < N; j = j + 1) begin : rec_delays
            wire [WIRE_DELAY-1:0] hor_del;
            wire [WIRE_DELAY-1:0] ver_del;
            // Array of generic delay buffers
            buffer #(NUM_LUTS) buf0h(.in(osc_hor_out[j]), .out(hor_del[0]));
            buffer #(NUM_LUTS) buf0v(.in(osc_ver_out[j]), .out(ver_del[0]));
            for (k = 1; k < WIRE_DELAY; k = k + 1) begin
                buffer #(NUM_LUTS) bufih(.in(hor_del[k-1]), .out(hor_del[k]));
                buffer #(NUM_LUTS) bufiv(.in(ver_del[k-1]), .out(ver_del[k]));
            end
            
            assign osc_hor_in[j] = hor_del[WIRE_DELAY-1];
            assign osc_ver_in[j] = ver_del[WIRE_DELAY-1];
        end

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
                              .wdata          (wdata));
    end endgenerate


endmodule
