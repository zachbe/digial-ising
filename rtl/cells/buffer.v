
`ifndef BUFFER
`define BUFFER

// Generic buffer for simulation
module buffer(input  wire i,
	      output wire o);
    reg o_reg;
    assign o = o_reg;
    always @(i) begin
        #1 o_reg = i;
    end
endmodule

`endif
