
`include "../cells/oscillator.v"

`timescale 1ns/1ps
module osc_tb();

    reg rstn;
    reg [2:0] coupling_input;
    reg [8:0] coupling_weight;
    wire out;

    oscillator #(3) dut (.coupling_weights(coupling_weight),
	                 .coupling_inputs (coupling_input ),
			 .rstn            (rstn           ),
			 .out             (out            ));

    initial begin
	$dumpfile("osc.vcd");
        $dumpvars(0, osc_tb);

        rstn = 1;
	#1;
        rstn = 0;
	coupling_input = 3'b0;
	coupling_weight = 9'b010010010;
	#20;
        rstn = 1;
	#50
        rstn = 0;
        coupling_input = 3'b0;
	coupling_weight = 9'b100010010;
	#20;
        rstn = 1;
	#50
	$finish();
    end
endmodule
