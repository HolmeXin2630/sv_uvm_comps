SIM_OUTPUT ?= $(CURDIR)/output

TEST ?= apb_smoke_test
WAIT_CYCLES ?= 0
INJECT_ERROR ?= 0

COMPILE_OPTS = -sverilog -full64 -timescale=1ns/1ps
COMPILE_OPTS += +define+UVM_PACKER_MAX_BYTES=1500000
COMPILE_OPTS += +define+UVM_DISABLE_AUTO_ITEM_RECORDING
COMPILE_OPTS += +incdir+../src
COMPILE_OPTS += +incdir+../tb
COMPILE_OPTS += +incdir+../test
COMPILE_OPTS += +define+WAIT_CYCLES=$(WAIT_CYCLES)
COMPILE_OPTS += +define+INJECT_ERROR=$(INJECT_ERROR)

all: comp run

comp:
	vcs $(COMPILE_OPTS) -o $(SIM_OUTPUT)/simv \
		../tb/apb_tb_top.sv

run:
	$(SIM_OUTPUT)/simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM

clean:
	rm -rf $(SIM_OUTPUT) csrc *.log *.key *.vpd *.vdb simv simv.daidir
