# NanoLogicController
A Minimal Open-Source ASIP for Accelerated Gate-Level Netlist Emulation
---
Following Moore’s Law, the ever-increasing complexity, i.e., the number of logic gates, of ultra-large-scale digital systems poses significant challenges for verification at the netlist (i.e., logic gate) level.
On the one hand, the inherent bit-level parallelism exposed by netlists cannot be efficiently exploited to accelerate simulations on traditional multicore general-purpose processors.
On the other hand, emulation systems based on multiple FPGA devices suffer from netlist partitioning overhead as well as excessively long EDA runtime for synthesis and place-and-route.

In order to solve these issues, a manycore system based on specialized logic emulation processor cores can be used to exploit the inherent netlist parallelism, while reducing preparation time and providing improved debugging facilities via utilizing a software compiler instead of hardware EDA tools.
*NanoLogicController* is an open-source logic emulation processor core, implementing an application-specific instruction-set for gate-level circuit emulation.
The architecture features a minimal control path and a lookup-table-based data path design, specialized for the evaluation of logic functions in netlists of digital circuits, which are converted into program code via a Verilog netlist parser and a custom code generation tool.
Due to stack-based data organization inside the data path, a very compact 4-bit-wide instruction-set and instruction encoding can be exploited to improve program code density and reduce instruction memory requirements. 

## Table of Contents

[Getting started](#Getting-started)

- [Repository Structure](#Repository-Structure)
- [Installation](#Installation)
- [Minimum Application Example](#Minimum-Application-Example)
- [Compiler Tool Flow](#Compiler-Tool-Flow)

[Contributors](#Contributors)

[License](#License)

[Citation](#Citation)

## Getting started

This repository contains the *open-source RTL implementation* of the NanoLogicController architecture, a minimum *simulation environment* for analyzing and verifying the functionality using a commented minimum application example of a 3-bit adder netlist, and the *tool flow* for compiling Verilog gate-level netlists to NanoLogicController program code.
The simulation environment uses the open-source VHDL simulator **GHDL**.
The compiler tool flow is based on the open-source logic synthesis tool **YoSys**, the open-source Verilog parser **PyVerilog** and a custom set of Python scripts.

### Repository Structure

| Directory    | Description |
|--------------|-------------|
| `compiler`   | Contains the Python scripts of the compiler tool, and serves as a working directory for it. |
| `rtl`        | Contains the VHDL source code of the open-source RTL implementation of the NanoLogicController architecture. |
| `sim`        | Simulation environment using GHDL. Contains a commented minimum application example. |
| `yosys_flow` | Directory for YoSys synthesis flow to convert an input netlist in Verilog to a LUT-based representation in Verilog. |

### Installation

For simulation, **GHDL** (https://ghdl.github.io/ghdl/) needs to installed.
For the code generation tool flow, **YoSys** (https://yosyshq.net/yosys/), **PyVerilog** (https://github.com/PyHDI/Pyverilog), and the Python package **NetworkX** (https://networkx.org/) need to be installed.

On Ubuntu 24.04, install the following packages first:
```bash
sudo apt-get install ghdl yosys iverilog graphviz python3-networkx python3-jinja2 python3-ply python3-pygraphviz
```

Then checkout the *PyVerilog* repository and install:
```
git clone https://github.com/PyHDI/Pyverilog
cd Pyverilog
sudo python3 setup.py install
cd ..
```

Then, clone this repository:
```bash
git clone https://github.com/tubs-eis/NanoLogicController
```

### Minimum Application Example

Run the simulation testbench using:

```bash
cd NanoLogicController
make sim
```

The simulation of *NanoLogicController* code execution should run and finish for a minimum application example (3-bit ripple-carry adder).
If the environment is properly set up, a successful simulation should produce the following terminal output:

```
cd sim; \
ghdl -a --warn-no-binding -C --ieee=synopsys --work=top_level ../rtl/top_level/clkgate.behav.vhdl; \
ghdl -a --warn-no-binding -C --ieee=synopsys ../rtl/nano.pkg.vhdl ../rtl/aux.pkg.vhdl ../rtl/my_types.vhd ../rtl/shift_reg.vhdl ../rtl/simple_shift_reg.vhdl ../rtl/temp_reg.vhdl ../rtl/accumulator.vhd ../rtl/lut.vhd ../rtl/nano_ctrl.vhdl ../rtl/nano_data.vhd ../rtl/nano_imem.vhdl ../rtl/nano_imem.arch.scm.vhdl ../rtl/nano_dmem.vhdl ../rtl/nano_top.vhdl ../sim/vhdl/tb.vhdl; \
ghdl -r --warn-no-binding -C --ieee=synopsys tb --vcdgz=tb.vcd.gz; \
cd ..;
../../src/ieee/v93/numeric_std-body.vhdl:2098:7:@0ms:(assertion warning): NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
../sim/vhdl/tb.vhdl:139:21:@0ms:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@0ms:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@1ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@1ns:(report note): [IMEM] 0111
../sim/vhdl/tb.vhdl:139:21:@2ns:(report note): [IMEM] 1000
../sim/vhdl/tb.vhdl:139:21:@2ns:(report note): [IMEM] 1110
../sim/vhdl/tb.vhdl:139:21:@3ns:(report note): [IMEM] 0010
../sim/vhdl/tb.vhdl:139:21:@3ns:(report note): [IMEM] 0000
../sim/vhdl/tb.vhdl:139:21:@4ns:(report note): [IMEM] 0000
../sim/vhdl/tb.vhdl:139:21:@4ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@5ns:(report note): [IMEM] 0001
../sim/vhdl/tb.vhdl:139:21:@5ns:(report note): [IMEM] 1000
../sim/vhdl/tb.vhdl:139:21:@6ns:(report note): [IMEM] 0010
../sim/vhdl/tb.vhdl:139:21:@6ns:(report note): [IMEM] 0001
../sim/vhdl/tb.vhdl:139:21:@7ns:(report note): [IMEM] 0000
../sim/vhdl/tb.vhdl:139:21:@7ns:(report note): [IMEM] 0001
../sim/vhdl/tb.vhdl:139:21:@8ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@8ns:(report note): [IMEM] 1000
../sim/vhdl/tb.vhdl:139:21:@9ns:(report note): [IMEM] 0110
../sim/vhdl/tb.vhdl:139:21:@9ns:(report note): [IMEM] 1100
../sim/vhdl/tb.vhdl:139:21:@10ns:(report note): [IMEM] 0001
../sim/vhdl/tb.vhdl:139:21:@10ns:(report note): [IMEM] 0000
../sim/vhdl/tb.vhdl:139:21:@11ns:(report note): [IMEM] 0001
../sim/vhdl/tb.vhdl:139:21:@11ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@12ns:(report note): [IMEM] 0111
../sim/vhdl/tb.vhdl:139:21:@12ns:(report note): [IMEM] 0110
../sim/vhdl/tb.vhdl:139:21:@13ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@13ns:(report note): [IMEM] 0110
../sim/vhdl/tb.vhdl:139:21:@14ns:(report note): [IMEM] 1100
../sim/vhdl/tb.vhdl:139:21:@14ns:(report note): [IMEM] 0000
../sim/vhdl/tb.vhdl:139:21:@15ns:(report note): [IMEM] 0000
../sim/vhdl/tb.vhdl:139:21:@15ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@16ns:(report note): [IMEM] 0001
../sim/vhdl/tb.vhdl:139:21:@16ns:(report note): [IMEM] 1000
../sim/vhdl/tb.vhdl:139:21:@17ns:(report note): [IMEM] 0110
../sim/vhdl/tb.vhdl:139:21:@17ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@18ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@18ns:(report note): [IMEM] 1001
../sim/vhdl/tb.vhdl:139:21:@19ns:(report note): [IMEM] 1000
../sim/vhdl/tb.vhdl:139:21:@19ns:(report note): [IMEM] 0110
../sim/vhdl/tb.vhdl:139:21:@20ns:(report note): [IMEM] 0100
../sim/vhdl/tb.vhdl:156:17:@55ns:(report note): [OUT] '1', [CHECKVAL] '1'
../sim/vhdl/tb.vhdl:156:17:@69ns:(report note): [OUT] '0', [CHECKVAL] '0'
../sim/vhdl/tb.vhdl:156:17:@81ns:(report note): [OUT] '0', [CHECKVAL] '0'
../sim/vhdl/tb.vhdl:156:17:@91ns:(report note): [OUT] '1', [CHECKVAL] '1'
../sim/vhdl/tb.vhdl:166:9:@92ns:(report note): [SLEEP] Bye...
```

### Compiler Tool Flow

Run the different scripts of the compiler tool flow in correct order using:

```bash
make yosys gen_inputs run dut ghdl compare DESIGN="s15850"
```

For `DESIGN`, following ISCAS circuits are provided as Verilog input within the repo ( taken from https://github.com/santoshsmalagi/Benchmarks ):

- c3540
- c5315
- c6288
- c7552
- s5378
- s9234
- s13207
- s15850

In the compiler flow, these should pass the final `compare` test between original netlist simulation (`dut`) and execution of the compiled *NanoLogicController* program code (`ghdl`) with random input stimuli.
Final result metrics of the compiled code can be found in `compiler/result_metrics.json`.

## Contributors

- Moritz Weißbrich (TU Braunschweig): General conception and development, project maintainer
- Mohamed Wassim Chebili (TU Braunschweig): Architecture & compiler development
- Guillermo Payá-Vayá (TU Braunschweig): General conception and supervision

## License

This open-source project is distributed under the MIT license.

## Citation

Coming soon.
