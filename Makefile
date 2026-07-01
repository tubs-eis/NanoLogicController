## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


.PHONY: sim wave yosys gen_inputs run dut ghdl compare clean

#DESIGN ?= c3540
#DESIGN ?= c5315
#DESIGN ?= c6288
#DESIGN ?= c7552
#DESIGN ?= s5378
#DESIGN ?= s9234
#DESIGN ?= s13207
DESIGN ?= s15850

# Variables
TB           = tb
YOSYS_SCRIPT = lut_synth.ys

## COMPILER scripts
PYTHON_SCRIPT_GEN     = inputs_generator.py
PYTHON_SCRIPT_COMPILE = main.py
PYTHON_SCRIPT_DUT     = dut_tester.py
PYTHON_SCRIPT_GHDL    = tester.py
PYTHON_SCRIPT_COMPARE = outputs_comparer.py

## target sources
VHDL_SRC_TOP_LEVEL = \
  ../rtl/top_level/clkgate.behav.vhdl

VHDL_SRC_WORK = \
  ../rtl/nano.pkg.vhdl \
  ../rtl/aux.pkg.vhdl \
  ../rtl/my_types.vhd \
  ../rtl/shift_reg.vhdl \
  ../rtl/simple_shift_reg.vhdl \
  ../rtl/temp_reg.vhdl \
  ../rtl/accumulator.vhd \
  ../rtl/lut.vhd \
  ../rtl/nano_ctrl.vhdl \
  ../rtl/nano_data.vhd \
  ../rtl/nano_imem.vhdl \
  ../rtl/nano_imem.arch.scm.vhdl \
  ../rtl/nano_dmem.vhdl \
  ../rtl/nano_top.vhdl \
  ../sim/vhdl/tb.vhdl


## toolchain (should be in PATH variable)
GHDL     = ghdl
GTKW     = gtkwave
PYTHON   = python3
YOSYS    = yosys

## GHDL flags
GHDLFLAGS = --warn-no-binding -C --ieee=synopsys

## misc tools
CP = cp -f
RM = rm -rf


## simulation targets (architecture test for 3-bit adder example)
sim:
	cd sim; \
	$(GHDL) -a $(GHDLFLAGS) --work=top_level $(VHDL_SRC_TOP_LEVEL); \
	$(GHDL) -a $(GHDLFLAGS) $(VHDL_SRC_WORK); \
	$(GHDL) -r $(GHDLFLAGS) $(TB) --max-stack-alloc=256 --vcdgz=$(TB).vcd.gz; \
	cd ..;

wave:
	$(GTKW) sim/$(TB).vcd.gz


### COMPILER targets
## YoSys targets
yosys:
	cd yosys_flow; \
	$(CP) $(DESIGN).v sample_design.v; \
	$(YOSYS) -s $(YOSYS_SCRIPT); \
	cd ..

# generate random inputs for verification
gen_inputs:
	cd compiler; \
	$(PYTHON) $(PYTHON_SCRIPT_GEN) "$(DESIGN)"; \
	cd ..

# Run the Python compiler script
run: 
	cd compiler; \
	$(PYTHON) $(PYTHON_SCRIPT_COMPILE) "$(DESIGN)"; \
	cd ..

# Simulate the DUT with generated inputs for verification
dut:
	cd compiler; \
	$(PYTHON) $(PYTHON_SCRIPT_DUT); \
	cd ..

# Simulate the NanoLogicController program execution testbench (ghdl)	for verification
ghdl:
	cd compiler; \
	$(PYTHON) $(PYTHON_SCRIPT_GHDL); \
	cd ..

# Compare/verify simulation results of DUT and NanoLogicController program execution
compare:
	cd compiler; \
	$(PYTHON) $(PYTHON_SCRIPT_COMPARE); \
	cd ..

clean:
	$(RM) sim/*.cf; \
	$(RM) sim/*.vcd.gz; \
	$(RM) yosys_flow/sample_design.v; \
	$(RM) yosys_flow/synth.v; \
	$(RM) compiler/__pycache__/; \
	$(RM) compiler/*.mem; \
	$(RM) compiler/input*.txt; \
	$(RM) compiler/output*.txt; \
	$(RM) compiler/*.json; \
	$(RM) compiler/*.out; \
	$(RM) compiler/parsetab.py; \
	$(RM) compiler/*.vcd.gz; \
	$(RM) compiler/testbench.v

