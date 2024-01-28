
`define SIM
`include "../cells/core_matrix.v"

`timescale 1ns/1ps
module couple_tb();

    reg        rstn;

    reg  [4:0] ab_weight;
    reg  [4:0] bc_weight;
    reg  [4:0] ac_weight;

    wire [2:0] outputs_hor;
    wire [2:0] outputs_ver;
    
    wire [14:0] weights;
    assign     weights = {bc_weight, ac_weight, ab_weight};

    // Create a 3x3 array of coupled cells
    core_matrix #(.N(3),
	          .NUM_WEIGHTS(5),
		  .WIRE_DELAY(20)) dut(
		  .rstn(rstn),
		  .weights(weights),
		  .outputs_hor(outputs_hor),
	          .outputs_ver(outputs_ver));

    initial begin
	$dumpfile("couple.vcd");
        $dumpvars(0, couple_tb);

	ab_weight = 5'b00100; // Don't couple A and B
	bc_weight = 5'b00001; // Couple C and B negatively
	ac_weight = 5'b10000; // Couple A and C positively
	
        rstn = 1'b0;	
	#200;
	rstn = 1'b1;
	#10000;
	$finish();
    end
endmodule
