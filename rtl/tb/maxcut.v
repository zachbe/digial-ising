
`include "../cells/core_matrix.v"

`timescale 1ns/1ps

// Solve the following max-cut problem:
//
//
//         │
//         │
//    A────X──B─────┐
//    │    │  │     │
//    │    │  │     │
// ───X──┐ └──X──┐  C
//    │  │    │  │  │
//    │  │    │  │  │
//    E──X────D──X──┘
//       │       │
//       └───────┘
//
// Expected output:
//     A, D same phase
//     B, C, E same phase
//
// TODO: Add a wrapper module that automatically reads out the solution from
// the output wires of the core matrix.
//
// TODO: We see weird glitching behavior at the edges of the propagating
// signals on this test. Why? How can we fix it?

module maxcut_tb();

    reg        rstn;

    wire [4:0] outputs_hor;
    wire [4:0] outputs_ver;
    
    reg [19:0] weights;

    // Create a 5x5 array of coupled cells
    core_matrix #(.N(5),
	          .NUM_WEIGHTS(3),
		  .WIRE_DELAY(20)) dut(
		  .rstn(rstn),
		  .weights(weights),
		  .outputs_hor(outputs_hor),
	          .outputs_ver(outputs_ver));

    initial begin
	$dumpfile("maxcut.vcd");
        $dumpvars(0, maxcut_tb);

        weights = {10{2'b01}}; // Default to no coupling

	// Couple AB, AE, BC, BD, CD, DE negatively
	weights[ 1: 0] = 2'b00; // AB
	weights[ 7: 6] = 2'b00; // AE
	weights[ 9: 8] = 2'b00; // BC
	weights[11:10] = 2'b00; // BD
	weights[15:14] = 2'b00; // CD
	weights[19:18] = 2'b00; // DE

        rstn = 1'b0;	
	#200;
	rstn = 1'b1;
	#10000;
	$finish();
    end
endmodule
