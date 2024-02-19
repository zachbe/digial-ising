

// Create an NxN array of coupled cells.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "coupled_cell.v"
    `include "shorted_cell.v"
    `include "recursive_matrix.v"
`endif

module core_matrix #(parameter N = 8,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20,
	             parameter NUM_LUTS   = 2) (
		     input  wire ising_rstn,
		     output wire [N-1:0] outputs_ver,
		     output wire [N-1:0] outputs_hor,

		     input  wire        clk,
		     input  wire        axi_rstn,
                     input  wire        wready,
                     input  wire [31:0] wr_addr,
                     input  wire [31:0] wdata
	            );

    wire [N-1:0] osc_hor_in ;
    wire [N-1:0] osc_ver_in ;
    wire [N-1:0] osc_hor_out;
    wire [N-1:0] osc_ver_out;
    wire [N-1:0] bot_row;

    wire wr_match;
    assign wr_match = (wr_addr & `WEIGHT_ADDR_MASK) == `WEIGHT_ADDR_BASE;

    // Get outputs at the bottom of the array
    assign outputs_hor = bot_row;
    assign outputs_ver = osc_ver_out;

    // Split the address into S and D
    wire [15:0] s_addr;
    wire [15:0] d_addr;

    assign s_addr = wr_addr[15:0]          << (16 - $clog2(N));
    assign d_addr = {1'b0, wr_addr[30:16]} << (16 - $clog2(N));

    recursive_matrix #(.N(N),
                  .NUM_WEIGHTS(NUM_WEIGHTS),
                  .WIRE_DELAY(WIRE_DELAY),
                  .NUM_LUTS(NUM_LUTS),
	          .DIAGONAL(1),
	          .TRANSPOSE(0)) 
		  u_rec_matrix (
                  .ising_rstn(ising_rstn),
                  .inputs_ver(osc_ver_in),
                  .inputs_hor(osc_hor_in),
                  .outputs_ver(osc_ver_out),
                  .outputs_hor(osc_hor_out),
		  .bot_row(bot_row),
                  .clk(clk),
                  .axi_rstn(axi_rstn),
                  .wready(wready),
		  .wr_match(wr_match),
                  .s_addr(s_addr),
		  .d_addr(d_addr),
                  .wdata(wdata)
    );

    // Add delays that loop around
    genvar j,k;
    generate for (j = 0; j < N; j = j + 1) begin
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
    end endgenerate

endmodule
