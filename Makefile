# NanoCore-64 Build System
# ========================
# Canonical build entry points for the NanoCore-64 processor project.
#
# Usage:
#   make          - Compile RTL simulation binary
#   make test     - Run directed regression suite
#   make diff     - Run differential ISS/RTL regression on all tests
#   make synth    - Run Yosys synthesis and generate statistics
#   make clean    - Remove generated artifacts

PYTHON   ?= python3
IVERILOG ?= iverilog
VVP      ?= vvp
YOSYS    ?= yosys

SIM_BIN  := cpu_sim
RTL_SRC  := rtl/cpu.v rtl/alu.v rtl/regfile.v rtl/csr.v rtl/mmu.v rtl/timer.v
TB_SRC   := sim/cpu_tb.v
TEST_DIRS := tests/alu tests/branch tests/csr tests/exception tests/memory tests/mmu tests/timer

# Find all test .asm files, excluding common/
TEST_ASMS := $(shell find tests/ -name '*.asm' ! -path '*/common/*' | sort)

.PHONY: all test diff synth clean compile

all: compile

# Compile RTL to simulation binary
compile: $(SIM_BIN)

$(SIM_BIN): $(RTL_SRC) $(TB_SRC)
	$(IVERILOG) -g2012 -o $@ $(RTL_SRC) $(TB_SRC)

# Run directed regression (RTL only)
test: $(SIM_BIN)
	$(PYTHON) tools/regression.py

# Run differential ISS/RTL comparison on all tests
diff: $(SIM_BIN)
	@pass=0; fail=0; total=0; \
	for asm in $(TEST_ASMS); do \
		total=$$((total + 1)); \
		name=$$(basename $$asm .asm); \
		printf "  %-30s" "$$name"; \
		if $(PYTHON) tools/diff_test.py $$asm > /dev/null 2>&1; then \
			echo "MATCH"; \
			pass=$$((pass + 1)); \
		else \
			echo "DIFF FAIL"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "Differential: $$pass/$$total MATCH, $$fail failures"; \
	test $$fail -eq 0

# Seeded randomized differential testing
fuzz: $(SIM_BIN)
	$(PYTHON) tools/random_test.py --seeds 20

# Test the differential comparator itself (fault injection)
test-comparator:
	$(PYTHON) tools/test_comparator.py

# Yosys synthesis
synth:
	$(YOSYS) -p "read_verilog $(RTL_SRC); synth -top cpu; stat" \
		| tee synthesis/yosys_nanocore64.log
	@echo ""
	@echo "Synthesis complete. Log: synthesis/yosys_nanocore64.log"

# Clean generated artifacts
clean:
	rm -f $(SIM_BIN) *.vcd abc.history
	find tests/ -name '*.hex' -delete
	rm -rf reports/latest reports/archive
	rm -f synthesis/*.log
	find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
