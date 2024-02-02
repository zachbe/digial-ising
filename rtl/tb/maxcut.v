
`define SIM
`include "../cells/ising_axi.v"

`timescale 1ns/1ps

// Solve the following max-cut problem:
//
//
//         │
//         │
//    E────X──D─────┐
//    │    │  │     │
//    │    │  │     │
// ───X──┐ └──X──┐  C
//    │  │    │  │  │
//    │  │    │  │  │
//    A──X────B──X──┘
//       │       │
//       └───────┘
//
// Expected output:
//     A, C, D same phase
//     B, E    same phase
//

module maxcut_tb();

    reg         clk;
    reg         rstn;
    reg  [31:0] raddr;
    wire [31:0] rdata;
    reg  [31:0] waddr;
    reg  [31:0] wdata;
 
    // Create a 6x6 array of coupled cells
    // Cell F is the local field, which is positively coupled with all of the
    // other cells.
    ising_axi   #(.N(6),
	          .NUM_WEIGHTS(3),
		  .WIRE_DELAY(20)) dut(
		  .clk(clk),
		  .axi_rstn(rstn),
                  .arvalid_q(1'b1),
		  .araddr_q(raddr),
		  .rready(1'b0),
		  .rvalid(),
		  .rresp(),
		  .rdata(rdata),
		  .wready(1'b1),
		  .wr_addr(waddr),
		  .wdata(wdata));


    // Use a clock that's prime to wire delay
    always #51 clk = ~clk;

    integer i;

    initial begin
	$dumpfile("maxcut.vcd");
        $dumpvars(0, maxcut_tb);
	for (i = 0 ; i < 6; i = i+1) begin
            $dumpvars(0, dut.u_top_ising.u_sampler.phase_counters[i]);
            $dumpvars(0, dut.u_top_ising.u_sampler.phase_counters_nxt[i]);
	end

	clk = 0;
	raddr = 32'b0;
	waddr = 32'b0;
	wdata = 32'b0;
        rstn = 1'b0;

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
	rstn = 1'b1;

        @(posedge clk);
	waddr = `CTR_CUTOFF_ADDR;
	wdata = 32'h00004000;

	@(posedge clk);
	waddr = `CTR_MAX_ADDR;
	wdata = 32'h00008000;
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE;         //AB
	wdata = 32'h00000001;              //001
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 3*32;  //AE
	wdata = 32'h00000001;              //001
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 4*32;  //AF
	wdata = 32'h00000004;              //100

	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 5*32;  //BC
	wdata = 32'h00000001;              //001
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 6*32;  //BD
	wdata = 32'h00000001;              //001
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 8*32;  //BF
	wdata = 32'h00000004;              //100

	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 9*32;  //CD
	wdata = 32'h00000001;              //001
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 11*32; //CF
	wdata = 32'h00000004;              //100
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 12*32; //DE
	wdata = 32'h00000001;              //001
	
	@(posedge clk);
	waddr = `WEIGHT_ADDR_BASE + 13*32; //DF
	wdata = 32'h00000004;              //100
	
	@(posedge clk);
	waddr = `START_ADDR;
	wdata = 32'h00000001;

	#50000;
	
	@(posedge clk);
	raddr = `PHASE_ADDR_BASE;
	@(posedge clk);
	#1
	if(rdata[0] != 1) $display("!!! A FAILED !!!"); //A
	raddr = `PHASE_ADDR_BASE +   32;
	@(posedge clk);
	#1
	if(rdata[0] != 0) $display("!!! B FAILED !!!"); //B
	raddr = `PHASE_ADDR_BASE + 2*32;
	@(posedge clk);
	#1
	if(rdata[0] != 1) $display("!!! C FAILED !!!"); //C
	raddr = `PHASE_ADDR_BASE + 3*32;
	@(posedge clk);
	#1
	if(rdata[0] != 1) $display("!!! D FAILED !!!"); //D
	raddr = `PHASE_ADDR_BASE + 4*32;
	@(posedge clk);
	#1
	if(rdata[0] != 0) $display("!!! E FAILED !!!"); //E
	raddr = `PHASE_ADDR_BASE + 5*32;
	@(posedge clk);
	#1
	if(rdata[0] != 1) $display("!!! F FAILED !!!"); //F
        
        $display("If you got here with no fails, it passed!");	

	$finish();
    end
endmodule
