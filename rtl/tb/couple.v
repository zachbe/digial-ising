
`include "../cells/oscillator.v"

`timescale 1ns/1ps
module couple_tb();

    reg rstn;
    wire out_a;
    wire out_b;

    // Start in one phase                          0  0  0
    oscillator #(3,0) osc_a (.coupling_weights(9'b010010010   ),
	                     .coupling_inputs (3'b0           ),
	  		     .rstn            (rstn           ),
			     .out             (out_a          ));

    // Start in the other                          0  0 +2
    oscillator #(3,1) osc_b (.coupling_weights(9'b010010100   ),
	                     .coupling_inputs ({2'b0, out_a}  ),
			     .rstn            (rstn           ),
			     .out             (out_b          ));

    initial begin
	$dumpfile("couple.vcd");
        $dumpvars(0, couple_tb);

        rstn = 1;
	#1;
        rstn = 0;
	#100;
        rstn = 1;
	#1000;
	$finish();
    end
endmodule
