
`include "../cells/core_matrix.v"

`timescale 1ns/1ps

// Solve the following max-cut problem:
//
//
//         │
//         │
//    E────X──D─────┐
//    │    │  │     │
//    │    │  │     │
// ───X──┐ └──X──┐  C
//    │  │    │  │  │
//    │  │    │  │  │
//    A──X────B──X──┘
//       │       │
//       └───────┘
//
// Expected output:
//     A, C, D same phase
//     B, E    same phase
//
// TODO: Add a wrapper module that automatically reads out the solution from
// the output wires of the core matrix.

module maxcut_tb();

    reg        rstn;

    wire [5:0] outputs_hor;
    wire [5:0] outputs_ver;
    
    reg [29:0] weights;

    // Create a 6x6 array of coupled cells
    // Cell F is the local field, which is positively coupled with all of the
    // other cells.
    core_matrix #(.N(6),
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
	weights[11:10] = 2'b00; // BC
	weights[13:12] = 2'b00; // BD
	weights[19:18] = 2'b00; // CD
	weights[25:24] = 2'b00; // DE

        // Couple all of them positively to F
	weights[ 9: 8] = 2'b10; // AF
	weights[17:16] = 2'b10; // BF
	weights[23:22] = 2'b10; // CF
	weights[27:26] = 2'b10; // DF
	weights[29:28] = 2'b10; // EF

        rstn = 1'b0;	
	#200;
	rstn = 1'b1;
	#10000;
	$finish();
    end
endmodule
