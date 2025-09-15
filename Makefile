## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


.PHONY: sim wave clean

TB = tb

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


## simulation toolchain (should be in PATH variable)
GHDL     = ghdl
GTKW     = gtkwave

## GHDL flags
GHDLFLAGS = --warn-no-binding -C --ieee=synopsys

## misc tools
RM = rm -rf

## simulation targets
sim:
	cd sim; \
	$(GHDL) -a $(GHDLFLAGS) --work=top_level $(VHDL_SRC_TOP_LEVEL); \
	$(GHDL) -a $(GHDLFLAGS) $(VHDL_SRC_WORK); \
	$(GHDL) -r $(GHDLFLAGS) $(TB) --vcdgz=$(TB).vcd.gz; \
	cd ..;

wave:
	$(GTKW) sim/$(TB).vcd.gz

clean:
	$(RM) sim/*.cf
	$(RM) sim/*.vcd.gz
