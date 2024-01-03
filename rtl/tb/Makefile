

build:
	iverilog -o couple couple.v -pfileline=1
	iverilog -o maxcut maxcut.v -pfileline=1

test_all:
	vvp couple
	vvp maxcut

test_couple:
	vvp couple

test_maxcut:
	vvp maxcut
