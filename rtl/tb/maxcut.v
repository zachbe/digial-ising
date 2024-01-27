
`define SIM
`include "../cells/top_ising.v"

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

module maxcut_tb();

    reg        clk;
    reg        rstn;

    wire [5:0] phase;
    
    reg [29:0] weights;

    // Create a 6x6 array of coupled cells
    // Cell F is the local field, which is positively coupled with all of the
    // other cells.
    top_ising   #(.N(6),
	          .NUM_WEIGHTS(3),
		  .WIRE_DELAY(20),
	          .COUNTER_DEPTH(5),
	          .COUNTER_CUTOFF(16)) dut(
		  .clk(clk),
		  .rstn(rstn),
		  .weights(weights),
		  .phase(phase));

    // Use a clock that's prime to wire delay
    always #51 clk = ~clk;

    integer i;

    initial begin
	$dumpfile("maxcut.vcd");
        $dumpvars(0, maxcut_tb);
	for (i = 0 ; i < 6; i = i+1) begin
            $dumpvars(0, dut.u_sampler.phase_counters[i]);
            $dumpvars(0, dut.u_sampler.phase_counters_nxt[i]);
	end

	clk = 0;

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
       
	//             FEDCBA
	if(phase == 6'b101101) $display("--- TEST PASSED ---");
	else                   $display("!!! TEST FAILED !!!");

	$finish();
    end
endmodule
