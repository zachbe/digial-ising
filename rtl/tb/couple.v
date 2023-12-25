
`include "../cells/core_matrix.v"

`timescale 1ns/1ps
module couple_tb();

    reg        rstn;

    reg  [2:0] ab_weight;
    reg  [2:0] bc_weight;
    reg  [2:0] ac_weight;

    wire [2:0] outputs;
    
    wire [8:0] weights;
    assign     weights = {bc_weight, ac_weight, ab_weight};

    // Create a 3x3 array of coupled cells
    core_matrix #(.N(3),
	          .NUM_WEIGHTS(5),
		  .WIRE_DELAY(20)) dut(
		  .rstn(rstn),
		  .weights(weights),
		  .outputs(outputs));

    initial begin
	$dumpfile("couple.vcd");
        $dumpvars(0, couple_tb);

	ab_weight = 3'b100; // couple A and B positively
	bc_weight = 3'b010; // couple C and B negatively
	ac_weight = 3'b010; // Dont couple A and C
	
        rstn = 1'b0;	
	#200;
	rstn = 1'b1;
	#10000;
	$finish();
    end
endmodule
