# ====================================================
# Viterbi Decoder Makefile
# Project Root: /home/shakti/Work/Project/ViterbiDecoder
# ====================================================

# Directory structure
PROJECT_ROOT := $(shell pwd)
TB_DIR := $(PROJECT_ROOT)/tb
SRC_DIR := $(PROJECT_ROOT)/src
RUN_DIR := $(PROJECT_ROOT)/run
TESTS_DIR := $(PROJECT_ROOT)/tests
SCRIPTS_DIR := $(PROJECT_ROOT)/scripts
GOLDEN_DIR := $(TB_DIR)/goldenReference

# Bluespec testbench config
TOPFILE := $(TB_DIR)/tbViterbiDecoder.bsv
TOPMODULE := mkTbViterbiDecoder

# Bluespec DUT-only config (for synthesis)
TOPFILE_DUT := $(SRC_DIR)/ViterbiDecoder.bsv
DUT_MODULE := mkViterbiDecoder

# Common Bluespec settings
BSVINCDIR := $(TB_DIR):$(SRC_DIR):$(SRC_DIR)/fp_adder:.:%/Libraries

# Verilog output and build dirs
VERILOGDIR := $(PROJECT_ROOT)/verilog
BUILDDIR_V := $(RUN_DIR)/build_verilog

# Bluesim build dir
BSIM_DIR := $(PROJECT_ROOT)/build_bsim

# Scripts
VITERBI_GEN := $(GOLDEN_DIR)/viterbi_output_generator.py

# FP Tolerance
FP_TOLERANCE ?= 2

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

.PHONY: all clean clean-all help test run-test test-all compile list-tests new-test run-negative-tests run-negative-test-single
.PHONY: verilog verilog-dut bsim bsim-run

#===============================================================================
# Default target
#===============================================================================
all: help

#===============================================================================
# Verilog generation
#===============================================================================
# Generate Verilog for RTL
# Code added to copy RegFile.v and FIFO2.v from BSV repository
generate_verilog:
	@echo "$(YELLOW)Generating Verilog for ($(DUT_MODULE))...$(NC)"
	@mkdir -p $(VERILOGDIR) $(BUILDDIR_V)
	@echo "$(YELLOW)Copying RegFile.v and FIFO1.v from BSV repo... $(NC)"
	@cp /opt/bsc-inst/lib/Verilog/RegFile.v $(VERILOGDIR)
	@cp /opt/bsc-inst/lib/Verilog/FIFO1.v $(VERILOGDIR)
	@bsc -u -verilog -elab \
		-g $(DUT_MODULE) \
		-vdir $(VERILOGDIR) -bdir $(BUILDDIR_V) -info-dir $(BUILDDIR_V) \
		+RTS -K4000M -RTS \
		-check-assert -keep-fires -opt-undetermined-vals \
		-remove-false-rules -remove-empty-rules -remove-starved-rules \
		-remove-dollar -unspecified-to X \
		-show-schedule -show-module-use \
		-suppress-warnings G0010:T0054:G0020:G0024:G0023:G0096:G0036:G0117:G0015 \
		-p $(BSVINCDIR) $(TOPFILE_DUT)

#===============================================================================
# Bluesim build and run
#===============================================================================
bsim:
	@echo "$(YELLOW)Building Bluesim...$(NC)"
	@mkdir -p $(BSIM_DIR)
	@bsc -u -sim -elab \
		-simdir $(BSIM_DIR) -bdir $(BSIM_DIR) -info-dir $(BSIM_DIR) \
		-p $(BSVINCDIR) -g $(TOPMODULE) $(TOPFILE)
	@bsc -e $(TOPMODULE) -sim \
		-o $(BSIM_DIR)/$(TOPMODULE)_bsim \
		-simdir $(BSIM_DIR) -bdir $(BSIM_DIR) -info-dir $(BSIM_DIR)
	@echo "$(GREEN)[DONE] Bluesim executable: $(BSIM_DIR)/$(TOPMODULE)_bsim$(NC)"

# Run Bluesim with VCD dump enabled
bsim-run: bsim
	@echo "$(YELLOW)Running Bluesim (VCD enabled)...$(NC)"
	@cd $(BSIM_DIR) && \
		./$(TOPMODULE)_bsim -V
	@echo "$(GREEN)[DONE] Bluesim run complete$(NC)"
	@if [ -f "$(BSIM_DIR)/dump.vcd" ]; then \
		echo "$(GREEN)[VCD] $(BSIM_DIR)/dump.vcd$(NC)"; \
	else \
		echo "$(YELLOW)[WARN] dump.vcd not created (VCD may not be enabled in TB)$(NC)"; \
	fi

#===============================================================================
# Clean targets
#===============================================================================
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(RUN_DIR)/build $(BUILDDIR_V) $(BSIM_DIR)
	@echo "$(GREEN)[DONE] Clean complete$(NC)"

clean-all: clean
	@echo "$(YELLOW)Deep cleaning...$(NC)"
	@rm -f $(RUN_DIR)/*.exe $(RUN_DIR)/*.exe.so $(RUN_DIR)/*.log
	@rm -f $(RUN_DIR)/output.dat
	@rm -f $(BSIM_DIR)/N.dat $(BSIM_DIR)/A.dat $(BSIM_DIR)/B.dat $(BSIM_DIR)/input.dat
	@rm -rf $(VERILOGDIR)
	@find $(TESTS_DIR) -name "output.dat" -delete
	@find $(TESTS_DIR) -name "golden_output.dat" -delete
	@find $(TESTS_DIR) -name "dump.vcd" -delete
	@echo "$(GREEN)[DONE] Deep clean complete$(NC)"

#===============================================================================
# Single test target (runs bsim, moves outputs to test folder)
#===============================================================================
# Usage: make test TEST=test_0
test:
	@if [ -z "$(TEST)" ]; then \
		echo "$(RED)[ERROR] TEST variable not set$(NC)"; \
		echo "Usage: make test TEST=test_0"; \
		exit 1; \
	fi
	@$(MAKE) run-test TEST_NAME=$(TEST)

run-test:
	@echo "$(BLUE)===============================================================$(NC)"
	@echo "$(BLUE)Running test: $(TEST_NAME)$(NC)"
	@echo "$(BLUE)===============================================================$(NC)"
	
	@# Check if test directory exists
	@if [ ! -d "$(TESTS_DIR)/$(TEST_NAME)" ]; then \
		echo "$(RED)[ERROR] Test directory not found: $(TESTS_DIR)/$(TEST_NAME)$(NC)"; \
		exit 1; \
	fi
	
	@# Step 1: Find and copy input files to BSIM_DIR with standard names
	@echo "$(YELLOW)Step 1: Preparing input files...$(NC)"
	@mkdir -p $(BSIM_DIR)
	@cd $(TESTS_DIR)/$(TEST_NAME) && \
	N_FILE=$$(ls N*.dat 2>/dev/null | head -1); \
	A_FILE=$$(ls A*.dat 2>/dev/null | head -1); \
	B_FILE=$$(ls B*.dat 2>/dev/null | head -1); \
	INPUT_FILE=$$(ls input*.dat 2>/dev/null | head -1); \
	if [ -z "$$N_FILE" ] || [ -z "$$A_FILE" ] || [ -z "$$B_FILE" ] || [ -z "$$INPUT_FILE" ]; then \
		echo "$(RED)[FAIL] Missing input files$(NC)"; \
		exit 1; \
	fi; \
	echo "Found input files:"; \
	echo "  N: $$N_FILE -> N.dat"; \
	echo "  A: $$A_FILE -> A.dat"; \
	echo "  B: $$B_FILE -> B.dat"; \
	echo "  Input: $$INPUT_FILE -> input.dat"; \
	cp $$N_FILE $(BSIM_DIR)/N.dat; \
	cp $$A_FILE $(BSIM_DIR)/A.dat; \
	cp $$B_FILE $(BSIM_DIR)/B.dat; \
	cp $$INPUT_FILE $(BSIM_DIR)/input.dat
	@echo "$(GREEN)[DONE] Input files copied to $(BSIM_DIR)$(NC)"
	
	@# Step 2: Build and run Bluesim with VCD
	@echo "$(YELLOW)Step 2: Building & Running Bluesim...$(NC)"
	@$(MAKE) bsim-run
	
	@# Step 3: Move output.dat to test directory
	@echo "$(YELLOW)Step 3: Collecting outputs...$(NC)"
	@if [ -f "$(BSIM_DIR)/output.dat" ]; then \
		cp $(BSIM_DIR)/output.dat $(TESTS_DIR)/$(TEST_NAME)/; \
		echo "$(GREEN)[DONE] Copied output.dat to $(TEST_NAME)/$(NC)"; \
	else \
		echo "$(YELLOW)[WARN] output.dat not found in $(BSIM_DIR)$(NC)"; \
	fi
	
	@# Step 4: Move dump.vcd from Bluesim build to test dir
	@if [ -f "$(BSIM_DIR)/dump.vcd" ]; then \
		mv -f $(BSIM_DIR)/dump.vcd $(TESTS_DIR)/$(TEST_NAME)/; \
		echo "$(GREEN)[DONE] Moved dump.vcd to $(TEST_NAME)/$(NC)"; \
	else \
		echo "$(YELLOW)[WARN] dump.vcd not found in $(BSIM_DIR)$(NC)"; \
	fi
	
	@# Step 5: Clean up copied input files from BSIM_DIR
	@echo "$(YELLOW)Step 4: Cleaning up temporary files...$(NC)"
	@rm -f $(BSIM_DIR)/N.dat $(BSIM_DIR)/A.dat $(BSIM_DIR)/B.dat $(BSIM_DIR)/input.dat
	@echo "$(GREEN)[DONE] Cleaned up temporary input files$(NC)"
	
	@# Step 6: Generate golden reference
	@echo "$(YELLOW)Step 5: Generating golden reference...$(NC)"
	@cd $(TESTS_DIR)/$(TEST_NAME) && \
	N_FILE=$$(ls N*.dat 2>/dev/null | head -1); \
	A_FILE=$$(ls A*.dat 2>/dev/null | head -1); \
	B_FILE=$$(ls B*.dat 2>/dev/null | head -1); \
	INPUT_FILE=$$(ls input*.dat 2>/dev/null | head -1); \
	if [ -z "$$N_FILE" ] || [ -z "$$A_FILE" ] || [ -z "$$B_FILE" ] || [ -z "$$INPUT_FILE" ]; then \
		echo "$(RED)[FAIL] Missing input files$(NC)"; \
		exit 1; \
	fi; \
	python3 $(VITERBI_GEN) $$N_FILE $$A_FILE $$B_FILE $$INPUT_FILE golden_output.dat || { \
		echo "$(RED)[FAIL] Failed to generate golden reference$(NC)"; exit 1; \
	}
	@echo "$(GREEN)[DONE] Generated golden_output.dat$(NC)"
	
	@# Step 7: Compare outputs with proper exit code handling
	@echo "$(YELLOW)Step 6: Comparing outputs (FP tolerance=$(FP_TOLERANCE))...$(NC)"
	@if [ -f "$(SCRIPTS_DIR)/check_viterbi_output.py" ]; then \
		if python3 $(SCRIPTS_DIR)/check_viterbi_output.py \
			$(TESTS_DIR)/$(TEST_NAME)/output.dat \
			$(TESTS_DIR)/$(TEST_NAME)/golden_output.dat $(FP_TOLERANCE); then \
			echo "$(GREEN)[PASS] Outputs match$(NC)"; \
		else \
			echo "$(RED)[FAIL] Outputs differ$(NC)"; \
			exit 1; \
		fi; \
	else \
		echo "$(YELLOW)[WARN] Comparison skipped (check_viterbi_output.py not found)$(NC)"; \
	fi
	
	@echo "$(BLUE)===============================================================$(NC)"
	@echo "$(GREEN)Test $(TEST_NAME) complete!$(NC)"
	@echo "$(BLUE)===============================================================$(NC)"

# Usage: make run-negative-tests
# Reads tests from negative_tests.txt in tests directory
# PASS if [DUT][ERROR] appears in simulation log
# FAIL if no DUT errors are found

run-negative-tests:
	@if [ ! -f "$(TESTS_DIR)/negative_tests.txt" ]; then \
		echo "$(RED)[ERROR] Negative test list not found: $(TESTS_DIR)/negative_tests.txt$(NC)"; \
		echo "Create $(TESTS_DIR)/negative_tests.txt with one test name per line"; \
		exit 1; \
	fi
	@echo "$(BLUE)===============================================================$(NC)"
	@echo "$(BLUE)Running negative test suite from: $(TESTS_DIR)/negative_tests.txt$(NC)"
	@echo "$(BLUE)===============================================================$(NC)"
	@TMPFILE=$$(mktemp); \
	TOTAL=0; PASSED=0; FAILED=0; \
	while IFS= read -r test_name; do \
		[ -z "$$test_name" ] && continue; \
		echo "$$test_name" | grep -q "^#" && continue; \
		echo "$$test_name" | grep -q "^[[:space:]]*$$" && continue; \
		TOTAL=$$((TOTAL + 1)); \
		echo ""; \
		echo "$(BLUE)---------------------------------------------------------------$(NC)"; \
		echo "$(BLUE)Running NEGATIVE test: $$test_name$(NC)"; \
		echo "$(BLUE)---------------------------------------------------------------$(NC)"; \
		if $(MAKE) run-negative-test-single TEST_NAME=$$test_name; then \
			PASSED=$$((PASSED + 1)); \
			echo "$$test_name|PASS" >> $$TMPFILE; \
		else \
			FAILED=$$((FAILED + 1)); \
			echo "$$test_name|FAIL" >> $$TMPFILE; \
		fi; \
	done < "$(TESTS_DIR)/negative_tests.txt"; \
	echo ""; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	echo "$(BLUE) NEGATIVE TEST RESULTS$(NC)"; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	if [ -s "$$TMPFILE" ]; then \
		printf "$(CYAN)%-30s %s$(NC)\n" "TEST NAME" "STATUS"; \
		echo "---------------------------------------------------------------"; \
		while IFS='|' read -r test_name status; do \
			if [ "$$status" = "PASS" ]; then \
				printf "%-30s $(GREEN)%-10s$(NC)\n" "$$test_name" "[PASS]"; \
			else \
				printf "%-30s $(RED)%-10s$(NC)\n" "$$test_name" "[FAIL]"; \
			fi; \
		done < $$TMPFILE; \
	else \
		echo "$(YELLOW)No tests were executed$(NC)"; \
	fi; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	echo "$(BLUE) SUMMARY$(NC)"; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	printf "$(CYAN)%-20s$(NC) : %d\n" "Total Tests" "$$TOTAL"; \
	printf "$(GREEN)%-20s$(NC) : %d\n" "Passed" "$$PASSED"; \
	printf "$(RED)%-20s$(NC) : %d\n" "Failed" "$$FAILED"; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	rm -f $$TMPFILE; \
	if [ $$TOTAL -eq 0 ]; then \
		echo "$(YELLOW)[WARN] No tests found in negative_tests.txt$(NC)"; \
		exit 1; \
	elif [ $$FAILED -eq 0 ]; then \
		echo "$(GREEN)ALL NEGATIVE TESTS PASSED!$(NC)"; \
		exit 0; \
	else \
		echo "$(RED)SOME NEGATIVE TESTS FAILED$(NC)"; \
		exit 1; \
	fi

run-negative-test-single:
	@echo "$(YELLOW)Step 1: Preparing input files...$(NC)"
	@if [ ! -d "$(TESTS_DIR)/$(TEST_NAME)" ]; then \
		echo "$(RED)[ERROR] Test directory not found: $(TESTS_DIR)/$(TEST_NAME)$(NC)"; \
		exit 1; \
	fi
	@mkdir -p $(BSIM_DIR)
	@cd $(TESTS_DIR)/$(TEST_NAME) && \
	N_FILE=$$(ls N*.dat 2>/dev/null | head -1); \
	A_FILE=$$(ls A*.dat 2>/dev/null | head -1); \
	B_FILE=$$(ls B*.dat 2>/dev/null | head -1); \
	INPUT_FILE=$$(ls input*.dat 2>/dev/null | head -1); \
	if [ -z "$$N_FILE" ] || [ -z "$$A_FILE" ] || [ -z "$$B_FILE" ] || [ -z "$$INPUT_FILE" ]; then \
		echo "$(RED)[FAIL] Missing input files$(NC)"; \
		exit 1; \
	fi; \
	cp $$N_FILE $(BSIM_DIR)/N.dat; \
	cp $$A_FILE $(BSIM_DIR)/A.dat; \
	cp $$B_FILE $(BSIM_DIR)/B.dat; \
	cp $$INPUT_FILE $(BSIM_DIR)/input.dat
	@echo "$(GREEN)[DONE] Input files copied$(NC)"
	
	@echo "$(YELLOW)Step 2: Building & Running Bluesim...$(NC)"
	@$(MAKE) bsim 
	@cd $(BSIM_DIR) && ./$(TOPMODULE)_bsim -V 2>&1 | tee sim.log
	@echo "$(GREEN)[DONE] Bluesim run complete$(NC)"
	
	@echo "$(YELLOW)Step 3: Collecting outputs...$(NC)"
	@if [ -f "$(BSIM_DIR)/output.dat" ]; then \
		cp $(BSIM_DIR)/output.dat $(TESTS_DIR)/$(TEST_NAME)/; \
	fi
	@if [ -f "$(BSIM_DIR)/dump.vcd" ]; then \
		mv -f $(BSIM_DIR)/dump.vcd $(TESTS_DIR)/$(TEST_NAME)/; \
	fi
	@if [ -f "$(BSIM_DIR)/sim.log" ]; then \
		cp $(BSIM_DIR)/sim.log $(TESTS_DIR)/$(TEST_NAME)/; \
	fi
	
	@echo "$(YELLOW)Step 4: Cleaning up temporary files...$(NC)"
	@rm -f $(BSIM_DIR)/N.dat $(BSIM_DIR)/A.dat $(BSIM_DIR)/B.dat $(BSIM_DIR)/input.dat
	@echo "$(GREEN)[DONE] Cleaned up temporary input files$(NC)"
	
	@echo "$(YELLOW)Step 5: Checking for expected DUT errors...$(NC)"
	@if [ -f "$(BSIM_DIR)/sim.log" ]; then \
		if grep -q "\[DUT\]\[ERROR\]" $(BSIM_DIR)/sim.log; then \
			echo "$(GREEN)[PASS] DUT errors detected as expected$(NC)"; \
			grep "\[DUT\]\[ERROR\]" $(BSIM_DIR)/sim.log; \
			rm -f $(BSIM_DIR)/sim.log; \
			exit 0; \
		else \
			echo "$(RED)[FAIL] No DUT errors found (expected errors for negative test)$(NC)"; \
			rm -f $(BSIM_DIR)/sim.log; \
			exit 1; \
		fi; \
	else \
		echo "$(RED)[FAIL] sim.log not found$(NC)"; \
		exit 1; \
	fi

#===============================================================================
# Multiple tests target
#===============================================================================
# Usage: make test-all [TEST_LIST=custom_list.txt]
TEST_LIST ?= $(TESTS_DIR)/test_list.txt

test-all:
	@if [ ! -f "$(TEST_LIST)" ]; then \
		echo "$(RED)[ERROR] Test list not found: $(TEST_LIST)$(NC)"; \
		echo "Create $(TESTS_DIR)/test_list.txt with one test name per line"; \
		exit 1; \
	fi
	@echo "$(BLUE)===============================================================$(NC)"
	@echo "$(BLUE)Running test suite from: $(TEST_LIST)$(NC)"
	@echo "$(BLUE)===============================================================$(NC)"
	@TMPFILE=$$(mktemp); \
	TOTAL=0; PASSED=0; FAILED=0; \
	while IFS= read -r test_name || [ -n "$$test_name" ]; do \
		echo "$$test_name" | grep -q "^#" && continue; \
		[ -z "$$test_name" ] && continue; \
		TOTAL=$$((TOTAL + 1)); \
		echo ""; \
		if $(MAKE) run-test TEST_NAME=$$test_name 2>&1; then \
			PASSED=$$((PASSED + 1)); \
			echo "$$test_name|PASS" >> $$TMPFILE; \
		else \
			FAILED=$$((FAILED + 1)); \
			echo "$$test_name|FAIL" >> $$TMPFILE; \
		fi; \
	done < "$(TEST_LIST)"; \
	echo ""; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	echo "$(BLUE)                    TEST RESULTS$(NC)"; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	printf "$(CYAN)%-30s %s$(NC)\n" "TEST NAME" "STATUS"; \
	echo "---------------------------------------------------------------"; \
	while IFS='|' read -r test_name status; do \
		if [ "$$status" = "PASS" ]; then \
			printf "%-30s $(GREEN)%-10s$(NC)\n" "$$test_name" "[PASS]"; \
		else \
			printf "%-30s $(RED)%-10s$(NC)\n" "$$test_name" "[FAIL]"; \
		fi; \
	done < $$TMPFILE; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	echo "$(BLUE)                      SUMMARY$(NC)"; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	printf "$(CYAN)%-20s$(NC) : %d\n" "Total Tests" "$$TOTAL"; \
	printf "$(GREEN)%-20s$(NC) : %d\n" "Passed" "$$PASSED"; \
	printf "$(RED)%-20s$(NC) : %d\n" "Failed" "$$FAILED"; \
	echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"; \
	rm -f $$TMPFILE; \
	if [ $$FAILED -eq 0 ]; then \
		echo "$(GREEN)PASS - ALL TESTS PASSED!$(NC)"; \
		exit 0; \
	else \
		echo "$(RED)FAIL - SOME TESTS FAILED$(NC)"; \
		exit 0; \
	fi


#===============================================================================
# Utility targets
#===============================================================================
# Create a new test case
# Usage: make new-test TEST=test_2
new-test:
	@if [ -z "$(TEST)" ]; then \
		echo "$(RED)[ERROR] TEST variable not set$(NC)"; \
		echo "Usage: make new-test TEST=test_2"; \
		exit 1; \
	fi
	@mkdir -p $(TESTS_DIR)/$(TEST)
	@echo "# Test: $(TEST)" > $(TESTS_DIR)/$(TEST)/README.txt
	@echo "$(GREEN)[DONE] Created test directory: $(TESTS_DIR)/$(TEST)$(NC)"
	@echo "$(YELLOW)Please add input files: N*.dat, A*.dat, B*.dat, input*.dat$(NC)"
	@if [ ! -f "$(TEST_LIST)" ] || ! grep -q "^$(TEST)$$" $(TEST_LIST) 2>/dev/null; then \
		echo "$(TEST)" >> $(TEST_LIST); \
		echo "$(GREEN)[DONE] Added $(TEST) to test_list.txt$(NC)"; \
	fi

# List all available tests
list-tests:
	@echo "$(BLUE)Available tests:$(NC)"
	@for d in $(TESTS_DIR)/test_*; do \
		if [ -d "$$d" ]; then \
			basename "$$d"; \
		fi; \
	done

#===============================================================================
# Help target
#===============================================================================
help:
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)          Viterbi Decoder Build System$(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Simulation Targets:$(NC)"
	@echo "  $(GREEN)make bsim$(NC)              - Build Bluesim executable"
	@echo "  $(GREEN)make bsim-run$(NC)          - Build + Run Bluesim (creates dump.vcd)"
	@echo "  $(GREEN)make test TEST=test_0$(NC) - Run single test (bsim + VCD + compare)"
	@echo "  $(GREEN)make test-all$(NC)          - Run all tests from test_list.txt"
	@echo ""
	@echo "$(YELLOW)Verilog Generation:$(NC)"
	@echo "  $(GREEN)make generate_verilog$(NC)  - Generate Verilog for RTL"
	@echo ""
	@echo "$(YELLOW)Utilities:$(NC)"
	@echo "  $(GREEN)make new-test TEST=name$(NC) - Create new test directory"
	@echo "  $(GREEN)make list-tests$(NC)         - List all available tests"
	@echo "  $(GREEN)make clean$(NC)              - Remove build artifacts"
	@echo "  $(GREEN)make clean-all$(NC)          - Deep clean (incl. verilog/VCD)"
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  $(GREEN)FP_TOLERANCE$(NC)           - Set FP comparison tolerance (default: 2)"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make test TEST=test_0              # Run single test"
	@echo "  make test-all                      # Run all tests"
	@echo "  make test-all FP_TOLERANCE=5       # Run with tolerance=5"
	@echo "  make negative-tests       					# Run negative tests"
	@echo "  make generate_verilog              # Generate Verilog"
	@echo "  make bsim-run                      # Quick simulation run"
	@echo ""
	@echo "$(YELLOW)Project Structure:$(NC)"
	@echo "  tests/test_X/   Test cases (N*.dat, A*.dat, B*.dat, input*.dat)"
	@echo "  src/            RTL source files (ViterbiDecoder.bsv)"
	@echo "  tb/             Testbench (tbViterbiDecoder.bsv)"
	@echo "  verilog/        Generated Verilog output"
	@echo "  build_bsim/     Bluesim build artifacts"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════$(NC)"

