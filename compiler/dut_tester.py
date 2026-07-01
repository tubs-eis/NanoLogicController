## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


import subprocess
import re
import time
from collections import defaultdict


# -------------------------
# read input_order.txt
# -------------------------

def read_input_order(filename):

    signals = []

    with open(filename) as f:
        for line in f:
            line = line.strip()

            if not line:
                continue

            name, width = line.split()
            signals.append((name, int(width)))

    return signals


# -------------------------
# read outputs_position.txt
# -------------------------

def read_output_positions(filename):

    mapping = defaultdict(dict)

    with open(filename) as f:
        for line in f:

            line = line.strip()

            m = re.match(r"(\d+): \('(.+)', (\d+)\)", line)

            if not m:
                continue

            vec_index = int(m.group(1))
            signal = m.group(2)
            bit = int(m.group(3))

            mapping[signal][bit] = vec_index

    return mapping


# -------------------------
# detect clock
# -------------------------

def detect_clock_signal_from_verilog(verilog_file):
    with open(verilog_file) as f:
        for line in f:
            line = line.strip()

            if not line.startswith("input"):
                continue

            # remove comments
            line = line.split("//")[0]

            # replace separators with spaces
            line = line.replace(",", " ").replace(";", " ")

            tokens = line.split()

            # skip the "input" keyword
            for name in tokens[1:]:
                n = name.lower()

                if n == "ck" or "clk" in n or "clock" in n:
                    return name

    return None


# -------------------------
# detect reset
# -------------------------

def detect_reset_signal_from_verilog(verilog_file):

    with open(verilog_file) as f:
        for line in f:
            line = line.strip()

            if not line.startswith("input"):
                continue

            # remove comments
            line = line.split("//")[0]

            # replace separators with spaces
            line = line.replace(",", " ").replace(";", " ")

            tokens = line.split()

            # skip the "input" keyword
            for name in tokens[1:]:
                n = name.lower()

                if "rst" in n or "reset" in n:
                    return name
    return None

# -------------------------
# generate input connections (MSB FIRST)
# -------------------------

def generate_input_connections(signals, clock_name, reset_name):

    connections = []

    total_width = sum(width for _, width in signals)
    pos = total_width

    for name, width in signals:

        pos -= width
        start = pos
        end = pos + width - 1

        if width == 1:
            slice_str = f"inputs[{start}]"
        else:
            slice_str = f"inputs[{end}:{start}]"

        connections.append(f".{name}({slice_str})")

    if clock_name is not None:
        connections.append(f".{clock_name}(clk)")

    if reset_name is not None:
        connections.append(f".{reset_name}(rst)")

    return connections, total_width


# -------------------------
# generate output connections
# -------------------------

def generate_output_connections(mapping):

    connections = []
    max_index = -1

    for signal in mapping:

        bit_map = mapping[signal]
        width = max(bit_map.keys()) + 1

        if width == 1:

            vec_index = bit_map[0]
            connections.append(f".{signal}(outputs[{vec_index}])")
            max_index = max(max_index, vec_index)

        else:

            bits = []

            for bit in reversed(range(width)):
                vec_index = bit_map[bit]
                bits.append(f"outputs[{vec_index}]")
                max_index = max(max_index, vec_index)

            concat = "{" + ",".join(bits) + "}"
            connections.append(f".{signal}({concat})")

    return connections, max_index + 1


# -------------------------
# combine connections
# -------------------------

def generate_port_connections(input_signals, output_mapping, clock_name, reset_name):

    in_conns, in_width = generate_input_connections(input_signals, clock_name, reset_name)
    out_conns, out_width = generate_output_connections(output_mapping)

    all_connections = in_conns + out_conns

    text = ",\n".join(all_connections)

    return text, in_width, out_width


# -------------------------
# read inputs.txt
# -------------------------

def load_input_bits():

    with open("inputs.txt") as f:
        bits = f.read().strip()

    return bits


# -------------------------
# detect module name
# -------------------------

def detect_module_name(verilog_file):

    with open(verilog_file) as f:
        for line in f:
            m = re.search(r"module\s+(\w+)", line)
            if m and m.group(1)!= "dff":
                return m.group(1)

    raise RuntimeError("Could not detect module name")


# -------------------------
# generate testbench
# -------------------------

def generate_testbench(template_file,
                       module_name,
                       connections,
                       in_w,
                       out_w,
                       input_bits,
                       num_cycles):

    if len(input_bits) != in_w:
        raise ValueError("Input width mismatch")

    with open(template_file) as f:
        tb = f.read()

    tb = tb.replace("MODULE_NAME", module_name)
    tb = tb.replace("PORT_CONNECTIONS", connections)
    tb = tb.replace("INPUT_WIDTH", str(in_w))
    tb = tb.replace("OUTPUT_WIDTH", str(out_w))
    tb = tb.replace("INPUT_VALUE", f"{in_w}'b{input_bits}")
    tb = tb.replace("NUM_CYCLES", str(num_cycles))

    with open("testbench.v", "w") as f:
        f.write(tb)


# -------------------------
# run icarus
# -------------------------

def run_icarus(verilog_file):

    subprocess.run(
        f"iverilog -o sim.out testbench.v {verilog_file}",
        shell=True,
        check=True
    )

    subprocess.run(
        "vvp sim.out",
        shell=True,
        check=True
    )


# -------------------------
# MAIN
# -------------------------

verilog_file = "../yosys_flow/sample_design.v"
NUM_CYCLES = 10

input_signals = read_input_order("input_order.txt")
output_mapping = read_output_positions("outputs_position.txt")

clock_signal = detect_clock_signal_from_verilog(verilog_file)
reset_signal = detect_reset_signal_from_verilog(verilog_file)

connections, in_width, out_width = generate_port_connections(
    input_signals,
    output_mapping,
    clock_signal,
    reset_signal
)

input_bits = load_input_bits()
module_name = detect_module_name(verilog_file)

generate_testbench(
    "testbench_template.v",
    module_name,
    connections,
    in_width,
    out_width,
    input_bits,
    NUM_CYCLES
)

print("Generated testbench.v")
print("Module:", module_name)
print("Clock:", clock_signal)
print("Reset:", reset_signal)

print(f"=== {time.strftime('%Y-%m-%d %H:%M:%S')} === Simulation started ===")

run_icarus(verilog_file)

print(f"=== {time.strftime('%Y-%m-%d %H:%M:%S')} === Simulation finished ===")

with open("outputs_dut.txt") as f:
    print("Output per cycle:")
    print(f.read().strip())
