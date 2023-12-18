

build:
	iverilog -o osc_tb osc_tb.v -pfileline=1
	iverilog -o couple couple.v -pfileline=1

test_all:
	vvp osc_tb
	vvp couple

test_osc:
	vvp osc_tb

test_couple:
	vvp couple
