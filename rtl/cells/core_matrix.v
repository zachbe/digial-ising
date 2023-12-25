

// Create an NxN array of coupled cells
//
//       3|    2|    1|    0|
//        |     |     |     |
//    3   |  0  |  1  |  2  |  3
//  ------S-----C-----C-----C------
//        |     |     |     |
//       0|    3|    2|    1|
//        |     |     |     |
//    2   |  3  |  0  |  1  |  2
//  ------C-----S-----C-----C------
//        |     |     |     |
//       1|    0|    3|    2|
//        |     |     |     |
//    1   |  2  |  3  |  0  |  1
//  ------C-----C-----S-----C------
//        |     |     |     |
//       2|    1|    0|    3|
//        |     |     |     |
//    0   |  1  |  2  |  3  |  0
//  ------C-----C-----C-----S------
//        |     |     |     |
//       3|    2|    1|    0|
//  

`timescale 1ns/1ps
`include "../cells/coupled_cell.v"
`include "../cells/shorted_cell.v"

module core_matrix #(parameter N = 3,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20) (
		     input  wire rstn,
		     input  wire [$clog2(NUM_WEIGHTS)-1:0] weights [(N*(N-1)/2)-1:0],
		     output wire [N-1:0] outputs
	            );

    genvar i;
    genvar j;

    wire [N-1:0] osc_hor_in  [N-1:0];
    wire [N-1:0] osc_ver_in  [N-1:0];
    wire [N-1:0] osc_hor_out [N-1:0];
    wire [N-1:0] osc_ver_out [N-1:0];

    // Create the shorted cells
    generate for (i = 0 ; i < N; i = i + 1) begin
        shorted_cell i_short(.sin (rstn ? osc_hor_in[N-1] : 1'b0),
		             .din (rstn ? osc_ver_in[N-1] : 1'b0),
			     .sout(osc_hor_out[0]),
			     .dout(osc_ver_out[0]));
    end endgenerate

    // Create the right half of the coupled cells
    generate for (i = 0 ; i < N; i = i + 1) begin
	generate for (j = i+1 ; j < N; j = j + 1) begin
	    // Weights are in the order:
	    // (0  , 1  ) (0  , 2) ... (0, N-1) (0, N)
	    // (1  , 2  ) (1  , 3) ... (1, N  )
	    // ...        ...
	    // (N-2, N-1) (N-2, N)
	    // (N-1, N  )
	    //
	    // So, weight (i,j) is at index (N*i + (i*(i+1)/2) + j - i - 1)
            wire weight_ij;
	    assign weight_ij = weights[(N*i + (i*(i+1)/2) + j - i - 1)]

	    // See top of file for wire indexing.
	    // Horizontal wire input index is j-i-1.
	    // Horiztonal wire output index is j-i.
	    // Vertical wire input index is ??? 
            coupled_cell ij_right(.weight(weight_ij),
                                  .sin   (osc_ver_in[j-i-1]),
                                  .din   (osc_hor_in[j-i]),
                                  .sout  (osc_ver_out[1]),
                                  .dout  (osc_hor_out[2]));
 
	end endgenerate
    end endgenerate

endmodule
