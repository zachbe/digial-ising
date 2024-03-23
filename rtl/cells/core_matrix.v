

// Create an NxN array of coupled cells.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "shorted_cell.v"
    `include "coupled_col.v"
`endif

module core_matrix #(parameter N = 8,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
	             parameter NUM_LUTS   = 2) (
		     input  wire ising_rstn,

		     output wire [N-1:0] outputs,

		     input  wire        clk,
		     input  wire        axi_rstn,
                     input  wire        wready,
                     input  wire [31:0] wr_addr,
                     input  wire [31:0] wdata,
		     input  wire [31:0] rd_addr,
		     output wire [31:0] rdata
	            );

    wire [N-1:0] osc_in  ;
    wire [N-1:0] osc_out ;

    wire wr_match;
    assign wr_match = (wr_addr[31:24] == `WEIGHT_ADDR_MASK);

    // Split the address into S and D
    wire [15:0] s_addr;
    wire [15:0] d_addr;
    wire [15:0] sd_dist;
    wire [31:0] addr;

    assign addr = wready ? wr_addr : rd_addr;
    assign s_addr = {5'b0, addr[12: 2]} << (16 - $clog2(N));
    assign d_addr = {5'b0, addr[23:13]} << (16 - $clog2(N));
    assign sd_dist = (s_addr > d_addr) ? (s_addr - d_addr) :
                                         (d_addr - s_addr) ;

    // Create columns
    genvar i,j,k;
    generate for (i = 0; i < N; i = i + 1) begin : column_loop
        wire [N-1:0] column_out;
	wire [31 :0] rdata_out ;
	if (i == 0) begin: start_column_loop
            assign column_out = osc_in;
	    assign rdata_out  = 32'hAAAAAAAA;
	end else begin: main_column_loop
	    // The Nth column has a coupling distance of N.
	    wire wr_match;
	    assign wr_match = (sd_dist == i);
	    wire [31:0] rdata_col;
            coupled_col #(.N(N),
		          .K(i-1),
			  .NUM_WEIGHTS(NUM_WEIGHTS),
			  .WIRE_DELAY(WIRE_DELAY),
			  .NUM_LUTS(NUM_LUTS))
		     col_k(.ising_rstn  (ising_rstn),
			   .in_wires    (column_loop[i-1].column_out),
			   .out_wires   (column_out),

			   .clk         (clk),
			   .axi_rstn    (axi_rstn),
			   .wready      (wready),
			   .wr_match    (wr_match),
			   .s_addr      (s_addr),
			   .d_addr      (d_addr),
			   .wdata       (wdata),
			   .rdata       (rdata_col));
	    assign rdata_out = wr_match ? rdata_col                 :
		                          column_loop[i-1].rdata_out;
	end
    end endgenerate

    // Get read data
    assign rdata = column_loop[N-1].rdata_out;

    // Create shorted cells
    generate for (i = 0; i < N; i = i + 1) begin: shorted_cell_loop
        shorted_cell #(.NUM_LUTS(NUM_LUTS))
	       short_i(.ising_rstn(ising_rstn),
		       .sin       (column_loop[N-1].column_out[i]),
		       .dout      (osc_out[i]));
    end endgenerate

    // Add delays that loop around
    generate for (j = 0; j < N; j = j + 1) begin
        wire [WIRE_DELAY-1:0] osc_del;
        // Array of generic delay buffers
        buffer #(NUM_LUTS) buf0(.in(osc_out[j]), .out(osc_del[0]));
        for (k = 1; k < WIRE_DELAY; k = k + 1) begin
            buffer #(NUM_LUTS) bufi(.in(osc_del[k-1]), .out(osc_del[k]));
        end
        assign osc_in[j] = osc_del[WIRE_DELAY-1];
    end endgenerate

endmodule
