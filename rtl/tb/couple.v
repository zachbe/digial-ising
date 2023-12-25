
`include "../cells/coupled_cell.v"
`include "../cells/shorted_cell.v"

`timescale 1ns/1ps
module couple_tb();

    reg rstn;

    // Create a 3x3 array of coupled cells
    //
    //  0 | 1 | 2 | 0
    //  --S---C---C--M
    //  1 |   |   |
    //  --C---S---C--M
    //  2 |   |   |
    //  --C---C---S--M
    //  0 |   |   |
    //    M   M   M
    //
    reg  [2:0] osc_a_hor_in;
    reg  [2:0] osc_a_ver_in;
    reg  [2:0] osc_b_hor_in;
    reg  [2:0] osc_b_ver_in;
    reg  [2:0] osc_c_hor_in;
    reg  [2:0] osc_c_ver_in;
    wire [2:0] osc_a_hor_out;
    wire [2:0] osc_a_ver_out;
    wire [2:0] osc_b_hor_out;
    wire [2:0] osc_b_ver_out;
    wire [2:0] osc_c_hor_out;
    wire [2:0] osc_c_ver_out;

    reg [2:0] ab_weight;
    reg [2:0] bc_weight;
    reg [2:0] ac_weight;

    reg rst_a, rst_b, rst_c;

    // 3 shorted cells
    shorted_cell a_short(.sin (rstn ? osc_a_hor_in[0] : rst_a),
	                 .din (rstn ? osc_a_ver_in[0] : rst_a),
                         .sout(osc_a_hor_out[1]),
			 .dout(osc_a_ver_out[1]));
    shorted_cell b_short(.sin (rstn ? osc_b_hor_in[1] : rst_b),
	                 .din (rstn ? osc_b_ver_in[1] : rst_b),
                         .sout(osc_b_hor_out[2]),
			 .dout(osc_b_ver_out[2]));
    shorted_cell c_short(.sin (rstn ? osc_c_hor_in[2] : rst_c),
	                 .din (rstn ? osc_c_ver_in[2] : rst_c),
                         .sout(osc_c_hor_out[0]),
			 .dout(osc_c_ver_out[0]));

    // A x B coupling
    coupled_cell ab_right(.weight(ab_weight),
	                  .sin   (osc_b_ver_in[0]),
			  .din   (osc_a_hor_in[1]),
			  .sout  (osc_b_ver_out[1]),
			  .dout  (osc_a_hor_out[2]));
    coupled_cell ab_left (.weight(ab_weight),
	                  .sin   (osc_b_hor_in[0]),
			  .din   (osc_a_ver_in[1]),
			  .sout  (osc_b_hor_out[1]),
			  .dout  (osc_a_ver_out[2]));

    // A x C coupling
    coupled_cell ac_right(.weight(ac_weight),
	                  .sin   (osc_a_hor_in[2]),
			  .din   (osc_c_ver_in[0]),
			  .sout  (osc_a_hor_out[0]),
			  .dout  (osc_c_ver_out[1]));
    coupled_cell ac_left (.weight(ac_weight),
	                  .sin   (osc_a_ver_in[2]),
			  .din   (osc_c_hor_in[0]),
			  .sout  (osc_a_ver_out[0]),
			  .dout  (osc_c_hor_out[1]));

    // B x C coupling
    coupled_cell bc_right(.weight(bc_weight),
	                  .sin   (osc_c_ver_in[1]),
			  .din   (osc_b_hor_in[2]),
			  .sout  (osc_c_ver_out[2]),
			  .dout  (osc_b_hor_out[0]));
    coupled_cell bc_left (.weight(bc_weight),
	                  .sin   (osc_c_hor_in[1]),
			  .din   (osc_b_ver_in[2]),
			  .sout  (osc_c_hor_out[2]),
			  .dout  (osc_b_ver_out[0]));

    always @(osc_a_hor_out) begin
        #20 osc_a_hor_in <= osc_a_hor_out;  
    end
    always @(osc_b_hor_out) begin
        #20 osc_b_hor_in <= osc_b_hor_out;  
    end
    always @(osc_c_hor_out) begin
        #20 osc_c_hor_in <= osc_c_hor_out;  
    end
    always @(osc_a_ver_out) begin
        #20 osc_a_ver_in <= osc_a_ver_out;  
    end
    always @(osc_b_ver_out) begin
        #20 osc_b_ver_in <= osc_b_ver_out;  
    end
    always @(osc_c_ver_out) begin
        #20 osc_c_ver_in <= osc_c_ver_out;  
    end

    initial begin
	$dumpfile("couple.vcd");
        $dumpvars(0, couple_tb);

	ab_weight = 3'b100; // couple A and B positively
	bc_weight = 3'b000; // couple C and B negatively
	ac_weight = 3'b010; // Dont couple A and C

        rst_a = 1'b1;
        rst_b = 1'b1;
        rst_c = 1'b1;
	
        rstn = 1'b0;	
	#200;
	rstn = 1'b1;
	#10000;
	$finish();
    end
endmodule
