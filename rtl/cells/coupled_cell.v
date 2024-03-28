
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
	               input  wire sout,
		       input  wire din ,
		       output wire dout,

		       // Synchronous AXI write interface
		       input  wire        clk,
		       input  wire        axi_rstn,
                       input  wire        wready,
		       input  wire        wr_addr_match,
		       input  wire [31:0] wdata,
		       output wire [31:0] rdata
	               );
    genvar i;

    // Local registers for storing weights.
    reg  [$clog2(NUM_WEIGHTS)-1:0] weight;
    wire [$clog2(NUM_WEIGHTS)-1:0] weight_nxt;

    assign rdata = weight;

    assign weight_nxt = (wready & wr_addr_match) ? wdata[NUM_WEIGHTS-1:0] :
	                                           weight                 ;
    always @(posedge clk) begin
	if (!axi_rstn) begin
      	    weight <= (NUM_WEIGHTS/2); //NUM_WEIGHTS must be odd.
        end else begin
            weight <= weight_nxt;
        end
    end

    wire [NUM_WEIGHTS-1:0] weight_oh;
    generate for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
        assign weight_oh[i] = (weight == i);
    end endgenerate

    // If coupling is positive, we want to slow down the destination
    // oscillator when it doesn't match the source oscillator, and speed it up
    // otherwise.
    //
    // If coupling is negative, we want to slow down the destination
    // oscillator when it does match the source oscillator, and speed it up
    // otherwise.
   
    // This sampling removes the "combinational loop" and also prevents
    // ringing. 
    `ifdef SIM
    reg sout_samp_pos;
    reg sout_samp_neg;
    always @(posedge din) begin
        sout_samp_pos <= sout;
    end
    always @(negedge din) begin
        sout_samp_neg <= sout;
    end
    `else 
    wire sout_samp_pos;
    wire sout_samp_neg;
        (* dont_touch = "yes" *) FDPE d_neg_latch (.Q(sout_samp_neg), .D(sout), .C(~din), .CE(1'b1), .PRE(1'b0)); 
        (* dont_touch = "yes" *) FDPE d_pos_latch (.Q(sout_samp_pos), .D(sout), .C( din), .CE(1'b1), .PRE(1'b0)); 
    `endif

    assign mismatch_d  = din ? ~sout_samp_pos : sout_samp_neg;
    
    wire [NUM_WEIGHTS-1:0] d_buf;
  
    // Select our pair of possible delay elements using the weight array
    wire [NUM_WEIGHTS-1:0] d_sel_ma;
    wire [NUM_WEIGHTS-1:0] d_sel_mi;

    generate for (i = 0; i < NUM_WEIGHTS; i = i + 1) begin
        assign d_sel_ma[i] = weight_oh[NUM_WEIGHTS-1-i] & d_buf[i];
        assign d_sel_mi[i] = weight_oh[i              ] & d_buf[i];
    end endgenerate
    
    wire d_ma;
    wire d_mi;

    assign d_ma = |d_sel_ma;
    assign d_mi = |d_sel_mi;
    
    // Select correct option based on mismatch status
    wire dout_int;
    assign dout_int = mismatch_d ? d_mi : d_ma; 
    assign dout = dout_int;

    // Array of generic delay buffers
    // TODO: Potentially replace this with an asynchronous counter and
    // comparator to allow for greater weight resolution per LUT used.
    buffer #(NUM_LUTS) buf0d(.in(din   ), .out(d_buf[0]));
    generate for (i = 1; i < NUM_WEIGHTS; i = i + 1) begin
        buffer #(NUM_LUTS) bufid(.in(d_buf[i-1]), .out(d_buf[i]));
    end endgenerate

endmodule
