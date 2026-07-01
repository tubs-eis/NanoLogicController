## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


import os
import sys

BASE = "../rtl"

def run_cmd(cmd):
    print("Running:", cmd)
    ret = os.system(cmd)
    if ret != 0:
        print("Error occurred. Stopping.")
        sys.exit(ret)

# Clean
run_cmd("ghdl --clean")
run_cmd("rm -f *.o *.cf work-obj* tb")

# Compile top_level library FIRST
run_cmd(f"ghdl -a --std=08 --work=top_level {BASE}/top_level/clkgate.behav.vhdl")

# Compile rest (work library)
vhdl_files = [
    f"{BASE}/nano.pkg.vhdl",
    f"{BASE}/aux.pkg.vhdl",
    f"{BASE}/my_types.vhd",
    f"{BASE}/shift_reg.vhdl",
    f"{BASE}/simple_shift_reg.vhdl",
    f"{BASE}/temp_reg.vhdl",
    f"{BASE}/accumulator.vhd",
    f"{BASE}/lut.vhd",
    f"{BASE}/nano_ctrl.vhdl",
    f"{BASE}/nano_data.vhd",
    f"{BASE}/nano_imem.vhdl",
    f"{BASE}/nano_imem.arch.scm.vhdl",
    f"{BASE}/nano_dmem.vhdl",
    f"{BASE}/nano_top.vhdl",
    f"testbench_ghdl.vhdl"
]

for file in vhdl_files:
    run_cmd(f"ghdl -a --std=08 --ieee=synopsys --warn-no-binding {file}")

# Elaborate
run_cmd("ghdl -e --std=08 tb")

# Run
run_cmd("ghdl -r --std=08 tb --stop-time=2000000ns --max-stack-alloc=256")
#run_cmd("ghdl -r --std=08 tb --stop-time=2000000ns --max-stack-alloc=256 --vcdgz=tb.vcd.gz")


# Clean again (optional)
run_cmd("ghdl --clean")
run_cmd("rm -f *.o *.cf work-obj* tb")
