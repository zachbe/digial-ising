
// Mismatches are measured at different points, and affect the
// propagation delay from that point.
//
// Intended to be instantiated in an NxN array.

`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "buffer.v"
`endif

module coupled_cell #(parameter NUM_WEIGHTS = 15,
                      parameter NUM_LUTS    = 2 ) (
		       // Oscillator RST
		       input  wire ising_rstn,

		       // Asynchronous phase IO
	               input  wire lin,
	               input  wire rin,
	               input  wire tin,
	               input  wire bin,
	               output wire lout,
	               output wire rout,
	               output wire tout,
	               output wire bout,

		       // Synchronous AXI write interface
		       input  wire        clk,
		       input  wire        axi_rstn,
                       input  wire        wready,
		       input  wire        wr_addr_match,
		       input  wire        s_gt_d,
		       input  wire [31:0] wdata,
		       output wire [31:0] rdata
	               );
    genvar i;

    // Local registers for storing weights.
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight_vh;
    wire [$clog2(NUM_WEIGHTS)-1:0] weight_vh_nxt;
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight_hv;
    wire [$clog2(NUM_WEIGHTS)-1:0] weight_hv_nxt;

    assign rdata = s_gt_d ? weight_vh : weight_hv;

    assign weight_vh_nxt = (wready & wr_addr_match &  s_gt_d) ? wdata[NUM_WEIGHTS-1:0] :
	                                                        weight_vh              ;
    assign weight_hv_nxt = (wready & wr_addr_match & ~s_gt_d) ? wdata[NUM_WEIGHTS-1:0] :
	                                                        weight_hv              ;
    always @(posedge clk) begin
	if (!axi_rstn) begin
      	    weight_hv <= (NUM_WEIGHTS/2); //NUM_WEIGHTS must be odd.
      	    weight_vh <= (NUM_WEIGHTS/2); //NUM_WEIGHTS must be odd.
        end else begin
            weight_vh <= weight_vh_nxt;
            weight_hv <= weight_hv_nxt;
        end
    end

    // If coupling is positive, we want to slow down the destination
    // oscillator when it doesn't match the source oscillator, and speed it up
    // otherwise.
    //
    // If coupling is negative, we want to slow down the destination
    // oscillator when it does match the source oscillator, and speed it up
    // otherwise.
  
    assign mismatch_lb  = (lin ^ tout);
    assign mismatch_bl  = (bin ^ rout);
    assign mismatch_rt  = (rin ^ bout);
    assign mismatch_tr  = (tin ^ lout);

    // Build our delayed signals
    wire [$clog2(NUM_WEIGHTS)-1:0] l_buf_ma;
    wire [$clog2(NUM_WEIGHTS)-2:0] l_buf_mi;
    wire [$clog2(NUM_WEIGHTS)-1:0] b_buf_ma;
    wire [$clog2(NUM_WEIGHTS)-2:0] b_buf_mi;
    wire [$clog2(NUM_WEIGHTS)-1:0] r_buf_ma;
    wire [$clog2(NUM_WEIGHTS)-2:0] r_buf_mi;
    wire [$clog2(NUM_WEIGHTS)-1:0] t_buf_ma;
    wire [$clog2(NUM_WEIGHTS)-2:0] t_buf_mi;

    // Depending on the weight bit, either add a delay or don't
    generate for (i = 0; i < $clog2(NUM_WEIGHTS); i = i + 1) begin
	wire l_buf_ma_in, l_buf_mi_in ;
	wire b_buf_ma_in, b_buf_mi_in ;
	wire r_buf_ma_in, r_buf_mi_in ;
	wire t_buf_ma_in, t_buf_mi_in ;

	if (i == 0) begin
            assign l_buf_ma_in = lin;
            assign l_buf_mi_in = lin;
            assign b_buf_ma_in = bin;
            assign b_buf_mi_in = bin;
            assign r_buf_ma_in = rin;
            assign r_buf_mi_in = rin;
            assign t_buf_ma_in = tin;
            assign t_buf_mi_in = tin;
        end else begin
	    assign l_buf_ma_in = l_buf_ma[i-1];
	    assign l_buf_mi_in = l_buf_mi[i-1];
	    assign b_buf_ma_in = b_buf_ma[i-1];
	    assign b_buf_mi_in = b_buf_mi[i-1];
	    assign r_buf_ma_in = r_buf_ma[i-1];
	    assign r_buf_mi_in = r_buf_mi[i-1];
	    assign t_buf_ma_in = t_buf_ma[i-1];
	    assign t_buf_mi_in = t_buf_mi[i-1];
        end

	wire l_buf_ma_out, l_buf_mi_out;
	wire b_buf_ma_out, b_buf_mi_out;
	wire r_buf_ma_out, r_buf_mi_out;
	wire t_buf_ma_out, t_buf_mi_out;

	//------------------------------------------------------------------
        // Delay line structure:
	// ---------------------
	//
	// Each weight bit corresponds to one verical slice of delay cells.
	//
	// For example, if weight = 7 = 4'b0111, the top delay line would
	// have delay 4, and so would the bottom.
	//
	// If weight = 14 = 4'b1110, the top delay line would have delay 7,
	// while the bottom would have delay 0.
	//
	//   bit:  0   1   2   3
        //        ┌─┐ ┌─┐ ┌─┐ ┌─┐
        //     ┌──┤1├─┤1├─┤2├─┤4├──┐ ┌─┐
        //     │  └─┘ └─┘ └─┘ └─┘  └─┤ └─┐
        //  in─┤                     │mux├──
        //     │      ┌─┐ ┌─┐ ┌─┐  ┌─┤ ┌─┘
        //     └──────┤1├─┤2├─┤4├──┘ └─┘
        //            └─┘ └─┘ └─┘
	//
	// This design consumes O(n) hardware resources, while using
	// a multipliexor tree for selecting a signal from a tapped delay
	// line consumes O(n log(n)) hardware resources.
	// It also inserts less unecessary logic in the delay line.
	//------------------------------------------------------------------

	if (i == 0) begin
	    assign l_buf_mi_out = l_buf_mi_in; // Hopefully these get optimzied out
	    assign b_buf_mi_out = b_buf_mi_in;
	    assign r_buf_mi_out = r_buf_mi_in;
	    assign t_buf_mi_out = t_buf_mi_in;
            buffer #(NUM_LUTS) buf_l_ma(.in(l_buf_ma_in), .out(l_buf_ma_out));
            buffer #(NUM_LUTS) buf_b_ma(.in(b_buf_ma_in), .out(b_buf_ma_out));
            buffer #(NUM_LUTS) buf_r_ma(.in(r_buf_ma_in), .out(r_buf_ma_out));
            buffer #(NUM_LUTS) buf_t_ma(.in(t_buf_ma_in), .out(t_buf_ma_out));
	end else begin
            buffer #(NUM_LUTS * (2^(i-1))) buf_l_mi(.in(l_buf_mi_in), .out(l_buf_mi_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_b_mi(.in(b_buf_mi_in), .out(b_buf_mi_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_r_mi(.in(r_buf_mi_in), .out(r_buf_mi_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_t_mi(.in(t_buf_mi_in), .out(t_buf_mi_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_l_ma(.in(l_buf_ma_in), .out(l_buf_ma_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_b_ma(.in(b_buf_ma_in), .out(b_buf_ma_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_r_ma(.in(r_buf_ma_in), .out(r_buf_ma_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_t_ma(.in(t_buf_ma_in), .out(t_buf_ma_out));
	end
        
	assign l_buf_ma[i] =  weight_vh[i] ? l_buf_ma_out : l_buf_ma_in;
	assign l_buf_mi[i] = ~weight_vh[i] ? l_buf_mi_out : l_buf_mi_in;
	assign b_buf_ma[i] =  weight_hv[i] ? b_buf_ma_out : b_buf_ma_in;
	assign b_buf_mi[i] = ~weight_hv[i] ? b_buf_mi_out : b_buf_mi_in;
	assign r_buf_ma[i] =  weight_vh[i] ? r_buf_ma_out : r_buf_ma_in;
	assign r_buf_mi[i] = ~weight_vh[i] ? r_buf_mi_out : r_buf_mi_in;
	assign t_buf_ma[i] =  weight_hv[i] ? t_buf_ma_out : t_buf_ma_in;
	assign t_buf_mi[i] = ~weight_hv[i] ? t_buf_mi_out : t_buf_mi_in;
    end endgenerate

    // Select output based on mismatch status
    wire rout_mis;
    wire tout_mis;
    wire lout_mis;
    wire bout_mis;
    assign rout_mis = mismatch_lb ? l_buf_mi[$clog2(NUM_WEIGHTS)-1] : l_buf_ma[$clog2(NUM_WEIGHTS)-1];
    assign tout_mis = mismatch_bl ? b_buf_mi[$clog2(NUM_WEIGHTS)-1] : b_buf_ma[$clog2(NUM_WEIGHTS)-1];
    assign lout_mis = mismatch_rt ? r_buf_mi[$clog2(NUM_WEIGHTS)-1] : r_buf_ma[$clog2(NUM_WEIGHTS)-1];
    assign bout_mis = mismatch_tr ? t_buf_mi[$clog2(NUM_WEIGHTS)-1] : t_buf_ma[$clog2(NUM_WEIGHTS)-1];

    // Prevent glitching: An output should never switch from the current
    // input value, only to that value.
    wire rout_pre;
    wire tout_pre;
    wire lout_pre;
    wire bout_pre;
    assign rout_pre = (rout == rin) ? rout     : rout_mis ;
    assign tout_pre = (tout == tin) ? tout     : tout_mis ;
    assign lout_pre = (lout == lin) ? lout     : lout_mis ;
    assign bout_pre = (bout == bin) ? bout     : bout_mis ;
    
    // When resetting, pass the input through directly
    wire rout_pre;
    wire tout_pre;
    wire lout_pre;
    wire bout_pre;
    assign rout_rst = ising_rstn    ? rout_pre : lin      ;
    assign tout_rst = ising_rstn    ? tout_pre : bin      ;
    assign lout_rst = ising_rstn    ? lout_pre : rin      ;
    assign bout_rst = ising_rstn    ? bout_pre : tin      ;
    
    // One more buffer to keep the output-input
    // feedback loop stable
    buffer #(NUM_LUTS) bufr(.in(rout_rst), .out(rout_int));
    buffer #(NUM_LUTS) buft(.in(tout_rst), .out(tout_int));
    buffer #(NUM_LUTS) bufl(.in(lout_rst), .out(lout_int));
    buffer #(NUM_LUTS) bufb(.in(bout_rst), .out(bout_int));

    // Latches here trick the tool into not thinking there's
    // a combinational loop in the design.
    `ifdef SIM
        assign rout = rout_int;
        assign tout = tout_int;
        assign lout = lout_int;
        assign bout = bout_int;
    `else
        (* dont_touch = "yes" *) LDCE r_latch (.Q(rout), .D(rout_int), .G(1'b1), .GE(1'b1), .CLR(1'b0));
        (* dont_touch = "yes" *) LDCE t_latch (.Q(tout), .D(tout_int), .G(1'b1), .GE(1'b1), .CLR(1'b0));
        (* dont_touch = "yes" *) LDCE l_latch (.Q(lout), .D(lout_int), .G(1'b1), .GE(1'b1), .CLR(1'b0));
        (* dont_touch = "yes" *) LDCE b_latch (.Q(bout), .D(bout_int), .G(1'b1), .GE(1'b1), .CLR(1'b0));
    `endif

endmodule
