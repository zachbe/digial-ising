
`timescale 1ns/1ps

`include "defines.vh"

`ifdef SIM
    `include "buffer.v"
`endif

module shorted_cell #(parameter NUM_LUTS = 2) (
	               input  wire ising_rstn,
	               input  wire sin ,
		       output wire dout,

		       // Synchronous AXI write interface
                       input  wire        clk,
                       input  wire        axi_rstn,
                       input  wire        wready,
                       input  wire        wr_addr_match,
                       input  wire [31:0] wdata,
                       output wire [31:0] rdata
	               );

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

    //--------------------------

    wire s_int;
    assign out = ising_rstn ? s_int : spin ;

    buffer #(NUM_LUTS) dbuf(.in(~out), .out(dout));

    // Latches here trick the tool into not thinking there's
    // a combinational loop in the design.
    `ifdef SIM
        assign s_int = ising_rstn ? sin : 1'b0;
    `else
        (* dont_touch = "yes" *) LDCE s_latch (.Q(s_int), .D(sin), .G(ising_rstn), .GE(1'b1), .CLR(1'b0)); 
    `endif
endmodule
