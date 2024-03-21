

// Recursively split the remaining cells into 2x2
// chunks.

`timescale 1ns/1ps

// Includes are handled in the wrapper for this module.
`include "defines.vh"

module recursive_matrix #(parameter N = 8,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
	             parameter NUM_LUTS   = 2, 
	             parameter DIAGONAL   = 1) (
		     input  wire ising_rstn,

		     // Some of these are inputs and
		     // some are outputs. They need to be one
		     // big wire because eventually, N goes to 1.
		     //
		     // If we had two wires with width [(N/2)-1:0]
		     // we would end up with negative bus width.
		     inout  wire [N-1:0] bottom,
		     inout  wire [N-1:0] left,
		     inout  wire [N-1:0] top,
		     inout  wire [N-1:0] right,

		     output wire [N-1:0] right_col,

		     input  wire        clk,
		     input  wire        axi_rstn,
                     input  wire        wready,
		     input  wire        wr_match,
                     input  wire [15:0] s_addr,
                     input  wire [15:0] d_addr,
                     input  wire [31:0] wdata,
		     output wire [31:0] rdata
	            );

    genvar j,k;

    // If N != 1, recurse.
    // Else, create the cells.
    generate if (N != 1) begin : recurse
        wire [N-1:0] osc_hor_in  ;
        wire [N-1:0] osc_ver_in  ;
        wire [N-1:0] osc_hor_out ;
        wire [N-1:0] osc_ver_out ;

        // Select cell based on address
        wire tl, tr, br;
        assign tl = wr_match & (~s_addr[15]) & (~d_addr[15]);
        assign tr = wr_match & (~s_addr[15]) & ( d_addr[15]);
        assign br = wr_match & ( s_addr[15]) & ( d_addr[15]);

	wire [31:0] tl_r, tr_r, br_r;
	assign rdata = tl   ? tl_r :
		       tr   ? tr_r :
		       br   ? br_r : 32'hAAAAAAAA;

	// Get far right col for phase measurement
	wire [(N/2)-1:0] right_col_top ;
	wire [(N/2)-1:0] right_col_bot;
	assign right_col = {right_col_top, right_col_bot};

	// Top left
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .WIRE_DELAY(WIRE_DELAY),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL))
			top_left(.ising_rstn (ising_rstn),
				 .bottom (osc_ver_in [N-1:(N/2)]),
				 .left   (inputs_hor [N-1:(N/2)]),
				 .top    (outputs_ver[N-1:(N/2)]),
				 .right  (osc_hor_out[N-1:(N/2)]),

				 .right_col(),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tl),
				 .s_addr({s_addr[14:0], 1'b0}),
				 .d_addr({d_addr[14:0], 1'b0}),
				 .wdata(wdata),
			         .rdata(tl_r));
	// Top right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .WIRE_DELAY(WIRE_DELAY),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(0))
		       top_right(.ising_rstn (ising_rstn),
				 .bottom (osc_ver_in [(N/2)-1:0]),
				 .left   (osc_hor_in [N-1:(N/2)]),
				 .top    (outputs_ver[(N/2)-1:0]),
				 .right  (outputs_hor[N-1:(N/2)]),

				 .right_col(right_col_top),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(tr),
				 .s_addr({s_addr[14:0], 1'b0}),
				 .d_addr({d_addr[14:0], 1'b0}),
				 .wdata(wdata),
			         .rdata(tr_r));
	// Bottom right
        recursive_matrix #(.N(N/2),
		           .NUM_WEIGHTS(NUM_WEIGHTS),
			   .WIRE_DELAY(WIRE_DELAY),
			   .NUM_LUTS(NUM_LUTS),
			   .DIAGONAL(DIAGONAL))
		       bot_right(.ising_rstn (ising_rstn),
				 .bottom (inputs_ver [(N/2)-1:0]),
				 .left   (osc_hor_in [(N/2)-1:0]),
				 .top    (osc_ver_out[(N/2)-1:0]),
				 .right  (outputs_hor[(N/2)-1:0]),

				 .right_col(right_col_bot),

				 .clk(clk),
				 .axi_rstn(axi_rstn),
				 .wready(wready),
				 .wr_match(br),
				 .s_addr({s_addr[14:0], 1'b0}),
				 .d_addr({d_addr[14:0], 1'b0}),
				 .wdata(wdata),
			         .rdata(br_r));
        
	// Add delays
	// TODO: Remove and fold into coupled cell.
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
                              .wdata          (wdata),
		              .rdata          (rdata));
    end endgenerate


endmodule
