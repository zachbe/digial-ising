

build:
	iverilog -o couple couple.v
	iverilog -o maxcut maxcut.v

test_all:
	vvp couple
	vvp maxcut

test_couple:
	vvp couple

test_maxcut:
	vvp maxcut
