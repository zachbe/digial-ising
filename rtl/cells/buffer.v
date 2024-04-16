
`ifndef BUFFER
`define BUFFER

// Generic buffer for simulation
module buffer #(parameter NUM_LUTS = 2)
               (input  wire in,
	        output wire out);

    `ifdef SIM
        reg o_reg;
        assign out = o_reg;
        always @(in) begin
            #NUM_LUTS o_reg = in;
        end
    `else
	wire [NUM_LUTS-1 : 0] lut_out;
        (* dont_touch = "yes" *) LUT1 #(.INIT(2'b10)) buf_lut_0 (.I0(in), .O(lut_out[0]));
        genvar i;
	generate for (i = 1; i < NUM_LUTS; i = i+1) begin	
            (* dont_touch = "yes" *) LUT1 #(.INIT(2'b10)) buf_lut_i (.I0(lut_out[i-1]), .O(lut_out[i]));
	end endgenerate
	assign out = lut_out[NUM_LUTS-1];
    `endif
endmodule

`endif
