
`include "../cells/coupled_cell.v"
`include "../cells/shorted_cell.v"

`timescale 1ns/1ps
module couple_tb();

    reg rstn;

    // Create a 3x3 array of coupled cells
    //
    //  0 | 1 | 2 | 0
    //  --S--->---V--M
    //  1 |   |   |
    //  --V---S--->--M
    //  2 |   |   |
    //  -->---V---S--M
    //  0 |   |   |
    //    M   M   M
    //
    wire [2:0] osc_a_hor;
    wire [2:0] osc_a_ver;
    wire [2:0] osc_b_hor;
    wire [2:0] osc_b_ver;
    wire [2:0] osc_c_hor;
    wire [2:0] osc_c_ver;

    reg [2:0] ab_weight;
    reg [2:0] bc_weight;
    reg [2:0] ac_weight;

    reg rst_a, rst_b, rst_c;

    // 3 shorted cells
    shorted_cell a_short(.sin (rstn ? osc_a_hor[0] : rst_a),
	                 .din (rstn ? osc_a_ver[0] : rst_a),
                         .sout(osc_a_hor[1]),
			 .dout(osc_a_ver[1]));
    shorted_cell b_short(.sin (rstn ? osc_b_hor[1] : rst_b),
	                 .din (rstn ? osc_b_ver[1] : rst_b),
                         .sout(osc_b_hor[2]),
			 .dout(osc_b_ver[2]));
    shorted_cell c_short(.sin (rstn ? osc_c_hor[2] : rst_c),
	                 .din (rstn ? osc_c_ver[2] : rst_c),
                         .sout(osc_c_hor[0]),
			 .dout(osc_c_ver[0]));

    // A x B coupling
    coupled_cell ab_right(.weight(ab_weight),
	                  .sin   (osc_b_ver[0]),
			  .din   (osc_a_hor[1]),
			  .sout  (osc_b_ver[1]),
			  .dout  (osc_a_hor[2]));
    coupled_cell ab_left (.weight(ab_weight),
	                  .sin   (osc_b_hor[0]),
			  .din   (osc_a_ver[1]),
			  .sout  (osc_b_hor[1]),
			  .dout  (osc_a_ver[2]));

    // A x C coupling
    coupled_cell ac_right(.weight(ac_weight),
	                  .sin   (osc_a_hor[2]),
			  .din   (osc_c_ver[0]),
			  .sout  (osc_a_hor[0]),
			  .dout  (osc_c_ver[1]));
    coupled_cell ac_left (.weight(ac_weight),
	                  .sin   (osc_a_ver[2]),
			  .din   (osc_c_hor[0]),
			  .sout  (osc_a_ver[0]),
			  .dout  (osc_c_hor[1]));

    // B x C coupling
    coupled_cell bc_right(.weight(bc_weight),
	                  .sin   (osc_c_ver[1]),
			  .din   (osc_b_hor[2]),
			  .sout  (osc_c_ver[2]),
			  .dout  (osc_b_hor[0]));
    coupled_cell bc_left (.weight(bc_weight),
	                  .sin   (osc_c_hor[1]),
			  .din   (osc_b_ver[2]),
			  .sout  (osc_c_hor[2]),
			  .dout  (osc_b_ver[0]));

    wire a_osc_v, a_osc_h;
    wire b_osc_v, b_osc_h;
    wire c_osc_v, c_osc_h;

    assign a_osc_v = osc_a_ver[2];
    assign b_osc_v = osc_b_ver[2];
    assign c_osc_v = osc_c_ver[2];
    assign a_osc_h = osc_a_hor[2];
    assign b_osc_h = osc_b_hor[2];
    assign c_osc_h = osc_c_hor[2];

    initial begin
	$dumpfile("couple.vcd");
        $dumpvars(0, couple_tb);

	ab_weight = 3'b011; // couple A and B positively
	bc_weight = 3'b000; // couple C and B negatively
	ac_weight = 3'b010; // Dont couple A and C

        rst_a = 1'b1;
        rst_b = 1'b0;
        rst_c = 1'b0;
	
        rstn = 1'b0;	
	#50;
	rstn = 1'b1;
	#150;
	$finish();
    end
endmodule
