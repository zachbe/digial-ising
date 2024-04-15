

// Create an NxN array of coupled cells.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "shorted_cell.v"
    `include "coupled_cell.v"
    `include "recursive_matrix.v"
`endif

module core_matrix #(parameter N = 8,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
	             parameter NUM_LUTS   = 2) (
		     input  wire ising_rstn,

		     output wire [N-1:0] external_spin,
		     output wire [N-1:0] outputs,

		     input  wire        clk,
		     input  wire        axi_rstn,
                     input  wire        wready,
                     input  wire [31:0] wr_addr,
                     input  wire [31:0] wdata,
		     input  wire [31:0] rd_addr,
		     output wire [31:0] rdata
	            );

    `ifdef SIM
    reg  [N-1:0] rin;
    reg  [N-1:0] tin;
    `else
    wire [N-1:0] rin;
    wire [N-1:0] tin;
    `endif
    wire [N-1:0] rout;
    wire [N-1:0] tout;
    wire [N-1:0] right_col;

    assign external_spin = right_col;
    assign outputs       = rout     ;

    wire wr_match;
    assign wr_match = (wr_addr[31:24] == `WEIGHT_ADDR_MASK);

    // Split the address into S and D
    wire [15:0] s_addr;
    wire [15:0] d_addr;
    wire [15:0] sd_dist;
    wire [31:0] addr;
    wire        vh;

    assign addr = wready ? wr_addr : rd_addr;
    assign s_addr = {5'b0, addr[12: 2]} ;
    assign d_addr = {5'b0, addr[23:13]} ;
    assign vh     = (s_addr > d_addr  ) ;

    // Create recursive matrix
    recursive_matrix #(.N(N),
                  .NUM_WEIGHTS(NUM_WEIGHTS),
                  .NUM_LUTS(NUM_LUTS),
	          .DIAGONAL(1))
		  u_rec_matrix (
                  .ising_rstn(ising_rstn),
                  .lin  (    /* None */     ),
                  .rin  (rin                ),
                  .tin  (tin                ),
                  .bin  (    /* None */     ),
                  .lout (    /* None */     ),
                  .rout (rout               ),
                  .tout (tout               ),
                  .bout (    /* None */     ),

                  .right_col(right_col),

                  .clk(clk),
                  .axi_rstn(axi_rstn),
                  .wready(wready),
                  .wr_match(wr_match),
                  .s_addr(s_addr[$clog2(N):0]),
                  .d_addr(d_addr[$clog2(N):0]),
                  .vh(vh),
                  .wdata(wdata),
                  .rdata(rdata) 
    );

    // Add delays (only in sim)
    genvar j;
    `ifdef SIM
        generate for (j = 0; j < N; j = j + 1) begin: delays
             always @(rout[j]) begin #20 tin[j] <= rout[j]; end
             always @(tout[j]) begin #20 rin[j] <= tout[j]; end
        end endgenerate
    `else
        assign rin = tout;
        assign tin = rout;
    `endif

endmodule
