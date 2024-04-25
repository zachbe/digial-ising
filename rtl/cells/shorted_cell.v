
`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "buffer.v"
`endif

module shorted_cell #(parameter NUM_LUTS = 2) (
	               input  wire ising_rstn,
	               input  wire tin ,
	               input  wire rin ,
		       output wire tout,
		       output wire rout,

		       // Synchronous AXI write interface
                       input  wire        clk,
                       input  wire        axi_rstn,
                       input  wire        wready,
                       input  wire        wr_addr_match,
                       input  wire [31:0] wdata,
                       output wire [31:0] rdata
	               );

    //--------------------------------------------------------------------
    // Local registers for storing start spins.
    reg  spin;
    wire spin_nxt;

    assign rdata = spin;

    assign spin_nxt = (wready & wr_addr_match) ? wdata[0] :
                                                 spin     ;
    always @(posedge clk) begin
        if (!axi_rstn) begin
            spin <= 1'b0;
        end else begin
            spin <= spin_nxt;
        end
    end

    //--------------------------------------------------------------------
    // AND-gate coupling means that we send out the faster coupling on the
    // falling edge, and the slower coupling on the rising edge.

    wire out_int;
    assign out_int = ~(tin & rin);

    wire out_rst;
    wire out;
    assign out = ising_rstn ? out_rst : spin ;
    
    assign tout = out;
    assign rout = out;

    //--------------------------------------------------------------------
    // Latches here trick the tool into not thinking there's
    // a combinational loop in the design.
    `ifdef SIM
        assign out_rst = out_int;
    `else
        (* dont_touch = "yes" *) LDCE o_latch (.Q(out_rst), .D(out_int), .G(ising_rstn), .GE(1'b1), .CLR(1'b0)); 
    `endif
endmodule
