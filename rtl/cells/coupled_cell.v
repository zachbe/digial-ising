
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
                      parameter NUM_LUTS    = 1 ) (
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
		       input  wire        vh,
		       input  wire [31:0] wdata,
		       output wire [31:0] rdata
	               );
    genvar i;

    // Local registers for storing weights.
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight_vh;
    wire [$clog2(NUM_WEIGHTS)-1:0] weight_vh_nxt;
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight_hv;
    wire [$clog2(NUM_WEIGHTS)-1:0] weight_hv_nxt;

    assign rdata = vh ? weight_vh : weight_hv;

    assign weight_vh_nxt = (wready & wr_addr_match &  vh) ? wdata[NUM_WEIGHTS-1:0] :
	                                                    weight_vh              ;
    assign weight_hv_nxt = (wready & wr_addr_match & ~vh) ? wdata[NUM_WEIGHTS-1:0] :
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
  
    assign mismatch_lb  = ~(lin ^ tout);
    assign mismatch_bl  = ~(bin ^ rout);
    assign mismatch_rt  = ~(rin ^ bout);
    assign mismatch_tr  = ~(tin ^ lout);

    // Build our delayed signals
    wire [$clog2(NUM_WEIGHTS)-2:0] l_buf_ma;
    wire [$clog2(NUM_WEIGHTS)-2:0] l_buf_mi;
    wire [$clog2(NUM_WEIGHTS)-2:0] b_buf_ma;
    wire [$clog2(NUM_WEIGHTS)-2:0] b_buf_mi;
    wire [$clog2(NUM_WEIGHTS)-2:0] r_buf_ma;
    wire [$clog2(NUM_WEIGHTS)-2:0] r_buf_mi;
    wire [$clog2(NUM_WEIGHTS)-2:0] t_buf_ma;
    wire [$clog2(NUM_WEIGHTS)-2:0] t_buf_mi;

    // Depending on the weight bit, either add a delay or don't
    generate for (i = 0; i < $clog2(NUM_WEIGHTS) - 1; i = i + 1) begin
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

	//------------------------------------------------------------------
        // Delay line structure:
	// ---------------------
	//
	// Each weight bit corresponds to one verical slice of delay cells.
	// The total weight is divided between the two couplings in each cell.
	//
	// For example, if weight = 7 = 4'b0111, delay line A, B, C, and D
	// would all have delay 2.
	//
	// If weight = 14 = 4'b1110, delay line A would have delay 4, while delay
	// line B would have delay 0. Also, delay line C would have delay 4,
	// while delay like D would have delay 1. This corresponds to a total
	// delay of +7.
	//
	// If weight = 4 = 4'b0100, delay line A would have delay 1, while
	// delay line B would have delay 2. Delay line C would have delay 1,
	// while delay line D would have delay 3. This corresponds to a total
	// delay of -3.
	//
	//   bit:  1   2   3 
        //        ┌─┐ ┌─┐ ┌─┐
        // A:  ┌──┤1├─┤1├─┤2├─┐ ┌─┐
        //     │  └─┘ └─┘ └─┘ └─┤ └─┐
        //  in─┤                │mux├──
        //     │      ┌─┐ ┌─┐ ┌─┤ ┌─┘
        // B:  └──────┤1├─┤2├─┘ └─┘
        //            └─┘ └─┘
	//  bit:      ~2  ~3
	//
	//
	//   bit:  1   2   3 
        //        ┌─┐ ┌─┐ ┌─┐
        // C:  ┌──┤1├─┤1├─┤2├─┐ ┌─┐
        //     │  └─┘ └─┘ └─┘ └─┤ └─┐
        //  in─┤                │mux├──
        //     │  ┌─┐ ┌─┐ ┌─┐ ┌─┤ ┌─┘
        // D:  └──┤1├─┤1├─┤2├─┘ └─┘
        //        └─┘ └─┘ └─┘
	//   bit: ~0  ~2  ~3 
	//
	//
	// This design consumes O(n) hardware resources, while using
	// a multipliexor tree for selecting a signal from a tapped delay
	// line consumes O(n log(n)) hardware resources.
	// It also inserts less unecessary logic in the delay line.
	//------------------------------------------------------------------
	
	wire l_buf_ma_out, l_buf_mi_out;
	wire b_buf_ma_out, b_buf_mi_out;
	wire r_buf_ma_out, r_buf_mi_out;
	wire t_buf_ma_out, t_buf_mi_out;

	if (i == 0) begin
	    // Use a buffer for our skipped slice to factor in the mux delay
	    // TODO: Should this only be in sim???
            buffer #(1) buf_l_mi(.in(l_buf_mi_in), .out(l_buf_mi[i]));
            buffer #(1) buf_b_mi(.in(b_buf_mi_in), .out(b_buf_mi[i]));
	    // Only 3 delays per coupling for our first slice
            buffer #(NUM_LUTS) buf_r_mi(.in(r_buf_mi_in), .out(r_buf_mi_out));
            buffer #(NUM_LUTS) buf_t_mi(.in(t_buf_mi_in), .out(t_buf_mi_out));
            buffer #(NUM_LUTS) buf_l_ma(.in(l_buf_ma_in), .out(l_buf_ma_out));
            buffer #(NUM_LUTS) buf_b_ma(.in(b_buf_ma_in), .out(b_buf_ma_out));
            buffer #(NUM_LUTS) buf_r_ma(.in(r_buf_ma_in), .out(r_buf_ma_out));
            buffer #(NUM_LUTS) buf_t_ma(.in(t_buf_ma_in), .out(t_buf_ma_out));
	    // TODO: Should these be built using LUTs manually?
	    assign r_buf_mi[i] = ~weight_vh[0] ? r_buf_mi_out : r_buf_mi_in;
	    assign t_buf_mi[i] = ~weight_hv[0] ? t_buf_mi_out : t_buf_mi_in;
	    assign l_buf_ma[i] =  weight_vh[1] ? l_buf_ma_out : l_buf_ma_in;
	    assign b_buf_ma[i] =  weight_hv[1] ? b_buf_ma_out : b_buf_ma_in;
	    assign r_buf_ma[i] =  weight_vh[1] ? r_buf_ma_out : r_buf_ma_in;
	    assign t_buf_ma[i] =  weight_hv[1] ? t_buf_ma_out : t_buf_ma_in;
	end else begin
	    // 4 delays per coupling for future slices
            buffer #(NUM_LUTS * (2^(i-1))) buf_l_mi(.in(l_buf_mi_in), .out(l_buf_mi_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_b_mi(.in(b_buf_mi_in), .out(b_buf_mi_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_r_mi(.in(r_buf_mi_in), .out(r_buf_mi_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_t_mi(.in(t_buf_mi_in), .out(t_buf_mi_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_l_ma(.in(l_buf_ma_in), .out(l_buf_ma_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_b_ma(.in(b_buf_ma_in), .out(b_buf_ma_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_r_ma(.in(r_buf_ma_in), .out(r_buf_ma_out));
            buffer #(NUM_LUTS * (2^(i-1))) buf_t_ma(.in(t_buf_ma_in), .out(t_buf_ma_out));
	    // TODO: Should these be built using LUTs manually?
	    assign l_buf_mi[i] = ~weight_vh[i+1] ? l_buf_mi_out : l_buf_mi_in;
	    assign b_buf_mi[i] = ~weight_hv[i+1] ? b_buf_mi_out : b_buf_mi_in;
	    assign r_buf_mi[i] = ~weight_vh[i+1] ? r_buf_mi_out : r_buf_mi_in;
	    assign t_buf_mi[i] = ~weight_hv[i+1] ? t_buf_mi_out : t_buf_mi_in;
	    assign l_buf_ma[i] =  weight_vh[i+1] ? l_buf_ma_out : l_buf_ma_in;
	    assign b_buf_ma[i] =  weight_hv[i+1] ? b_buf_ma_out : b_buf_ma_in;
	    assign r_buf_ma[i] =  weight_vh[i+1] ? r_buf_ma_out : r_buf_ma_in;
	    assign t_buf_ma[i] =  weight_hv[i+1] ? t_buf_ma_out : t_buf_ma_in;
	end
        
    end endgenerate

    // Select output based on mismatch status
    wire rout_mis;
    wire tout_mis;
    wire lout_mis;
    wire bout_mis;
    assign rout_mis = mismatch_lb ? l_buf_mi[$clog2(NUM_WEIGHTS)-2] : l_buf_ma[$clog2(NUM_WEIGHTS)-2];
    assign tout_mis = mismatch_bl ? b_buf_mi[$clog2(NUM_WEIGHTS)-2] : b_buf_ma[$clog2(NUM_WEIGHTS)-2];
    assign lout_mis = mismatch_rt ? r_buf_mi[$clog2(NUM_WEIGHTS)-2] : r_buf_ma[$clog2(NUM_WEIGHTS)-2];
    assign bout_mis = mismatch_tr ? t_buf_mi[$clog2(NUM_WEIGHTS)-2] : t_buf_ma[$clog2(NUM_WEIGHTS)-2];

    // Prevent glitching: An output should never switch from the current
    // input value, only to that value.
    wire rout_pre;
    wire tout_pre;
    wire lout_pre;
    wire bout_pre;
    assign rout_pre = (rout == lin) ? rout     : rout_mis ;
    assign tout_pre = (tout == bin) ? tout     : tout_mis ;
    assign lout_pre = (lout == rin) ? lout     : lout_mis ;
    assign bout_pre = (bout == tin) ? bout     : bout_mis ;
    
    // When resetting, pass the input through directly
    wire rout_rst;
    wire tout_rst;
    wire lout_rst;
    wire bout_rst;
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
