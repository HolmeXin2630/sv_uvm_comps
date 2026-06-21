SIM_OUTPUT ?= $(CURDIR)/output

TEST ?= apb_smoke_test
WAIT_CYCLES ?= 0
INJECT_ERROR ?= 0

UVM_HOME ?= /opt/synopsys/vcs/W-2024.09/etc/uvm-1.2

COMPILE_OPTS = -sverilog -full64 -timescale=1ns/1ps
COMPILE_OPTS += +define+UVM_PACKER_MAX_BYTES=1500000
COMPILE_OPTS += +define+UVM_DISABLE_AUTO_ITEM_RECORDING
COMPILE_OPTS += +incdir+../src
COMPILE_OPTS += +incdir+../tb
COMPILE_OPTS += +incdir+../test
COMPILE_OPTS += +incdir+$(UVM_HOME)/src
COMPILE_OPTS += +define+WAIT_CYCLES=$(WAIT_CYCLES)
COMPILE_OPTS += +define+INJECT_ERROR=$(INJECT_ERROR)
COMPILE_OPTS += -ignore initializer_driver_checks
COMPILE_OPTS += -LDFLAGS "-L$(VCS_HOME)/linux64/lib -lnativeuvm"

all: comp run

comp:
	@mkdir -p $(SIM_OUTPUT)
	vcs $(COMPILE_OPTS) -o $(SIM_OUTPUT)/simv \
		$(UVM_HOME)/src/uvm_pkg.sv \
		$(UVM_HOME)/dpi/uvm_dpi.cc \
		../src/apb_defines.svh \
		../src/apb_interface.sv \
		../src/apb_pkg.sv \
		../tb/apb_slave_ram.sv \
		../tb/apb_tb_pkg.sv \
		../tb/apb_tb_top.sv \
		-CFLAGS "-DVCS" \
		-LDFLAGS "-L$(VCS_HOME)/linux64/lib"

run:
	$(SIM_OUTPUT)/simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM \
		-sv_lib $(VCS_HOME)/linux64/lib/libnativeuvm \
		+UVM_NO_DPI

clean:
	rm -rf $(SIM_OUTPUT) csrc *.log *.key *.vpd *.vdb simv simv.daidir

regression: comp
	@echo "=== Running Regression Tests ==="
	@for test in apb_smoke_test apb_directed_test apb_random_test apb_slverr_test apb_wait_state_test apb_reset_test; do \
		echo "=== Running $$test ===" && \
		$(SIM_OUTPUT)/simv +UVM_TESTNAME=$$test +UVM_VERBOSITY=UVM_MEDIUM \
			-sv_lib $(VCS_HOME)/linux64/lib/libnativeuvm \
			+UVM_NO_DPI 2>&1 | grep -E "(UVM_ERROR|UVM_FATAL|PASSED|FAILED|Report)" | tail -5; \
	done
	@echo "=== Regression Complete ==="

verify: comp
	@./verify_regression.sh
