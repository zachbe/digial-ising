

build:
	iverilog -o couple couple.v -I ../cells
	iverilog -o maxcut maxcut.v -I ../cells

test_all:
	vvp couple
	vvp maxcut

test_couple:
	vvp couple

test_maxcut:
	vvp maxcut
