

build:
	iverilog -o osc_tb osc_tb.v
	iverilog -o couple couple.v

test_all:
	vvp osc_tb
	vvp couple

test_osc:
	vvp osc_tb

test_couple:
	vvp couple
