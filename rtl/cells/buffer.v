
`ifndef BUFFER
`define BUFFER

// Generic buffer for simulation
module buffer(input  wire in,
	      output wire out);
    reg o_reg;
    assign out = o_reg;
    always @(in) begin
        #1 o_reg = in;
    end
endmodule

`endif
