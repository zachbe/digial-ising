

// Create an NxN array of coupled cells
//
// Example with N = 4:
//
//       0|    1|    2|    3|
//        |     |     |     |
//    3   |  0  |  1  |  2  |  3
//  ------S-----C-----C-----C------
//        |     |     |     |
//       3|    0|    1|    2|
//        |     |     |     |
//    2   |  3  |  0  |  1  |  2
//  ------C-----S-----C-----C------
//        |     |     |     |
//       2|    3|    0|    1|
//        |     |     |     |
//    1   |  2  |  3  |  0  |  1
//  ------C-----C-----S-----C------
//        |     |     |     |
//       1|    1|    3|    0|
//        |     |     |     |
//    0   |  1  |  2  |  3  |  0
//  ------C-----C-----C-----S------
//        |     |     |     |
//       0|    1|    2|    3|
//  

`timescale 1ns/1ps
`include "../cells/coupled_cell.v"
`include "../cells/shorted_cell.v"

module core_matrix #(parameter N = 3,
	             parameter NUM_WEIGHTS = 5,
	             parameter WIRE_DELAY = 20) (
		     input  wire rstn,
		     input  wire [($clog2(NUM_WEIGHTS)*(N*(N-1)/2))-1:0] weights,
		     output wire [N-1:0] outputs_ver,
		     output wire [N-1:0] outputs_hor
	            );

    genvar i;
    genvar j;

    reg  [N-1:0] osc_hor_in  [N-1:0];
    reg  [N-1:0] osc_ver_in  [N-1:0];
    wire [N-1:0] osc_hor_out [N-1:0];
    wire [N-1:0] osc_ver_out [N-1:0];

    // Get outputs at the bottom of the array
    // TODO: Figure out how to actually do stuff with these
    generate for (i = 0 ; i < N; i = i + 1) begin
        assign outputs_ver[i] = osc_ver_out[i][i];
    end endgenerate
    assign outputs_hor = osc_hor_out[N-1];

    // Create the shorted cells
    generate for (i = 0 ; i < N; i = i + 1) begin
        shorted_cell i_short(.sin (rstn ? osc_hor_in[i][N-1] : 1'b0),
		             .din (rstn ? osc_ver_in[i][N-1] : 1'b0),
			     .sout(osc_hor_out[i][0]),
			     .dout(osc_ver_out[i][0]));
    end endgenerate

    // Create the coupled cells
    generate for (i = 0 ; i < N; i = i + 1) begin
	for (j = i+1 ; j < N; j = j + 1) begin
	    // Weights are in the order:
	    // (0  , 1  ) (0  , 2) ... (0, N-1) (0, N)
	    // (1  , 2  ) (1  , 3) ... (1, N  )
	    // ...        ...
	    // (N-2, N-1) (N-2, N)
	    // (N-1, N  )
	    //
	    // So, weight (i,j) is at index (N*i - (i*(i+1)/2) + j - i - 1)
            wire [$clog2(NUM_WEIGHTS)-1:0] weight_ij;
	    assign weight_ij = weights[((N*i - (i*(i+1)/2) + j - i - 1) 
	                                 * $clog2(NUM_WEIGHTS)) 
					 + $clog2(NUM_WEIGHTS) - 1    :
	                                ((N*i - (i*(i+1)/2) + j - i - 1) 
	                                 * $clog2(NUM_WEIGHTS))];

	    // See top of file for wire indexing.
	    //
	    // Right half:
            coupled_cell ij_right(.weight(weight_ij),
                                  .sin   (osc_ver_in [j][j-i-1]),
                                  .din   (osc_hor_in [i][j-i-1]),
                                  .sout  (osc_ver_out[j][j-i]),
                                  .dout  (osc_hor_out[i][j-i]));
	    // Left half:
            coupled_cell ij_left (.weight(weight_ij),
                                  .sin   (osc_ver_in [i][N-(j-i)-1]),
                                  .din   (osc_hor_in [j][N-(j-i)-1]),
                                  .sout  (osc_ver_out[i][N-(j-i)]),
                                  .dout  (osc_hor_out[j][N-(j-i)]));
 
	end 
    end endgenerate

    // Add delays
    generate for (i = 0 ; i < N; i = i + 1) begin
	always @(osc_hor_out[i]) begin
            #WIRE_DELAY osc_hor_in[i] <= osc_hor_out[i];
	end
	always @(osc_ver_out[i]) begin
            #WIRE_DELAY osc_ver_in[i] <= osc_ver_out[i];
	end
    end endgenerate

endmodule
