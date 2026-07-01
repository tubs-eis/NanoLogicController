## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


import re
from collections import defaultdict

# ----------------------------
# Read mapping file
# ----------------------------
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


# ----------------------------
# Build reverse mapping
# index -> (signal, bit)
# ----------------------------
def build_reverse_mapping(mapping):
    reverse = {}
    for signal, bits in mapping.items():
        for bit, idx in bits.items():
            reverse[idx] = (signal, bit)
    return reverse


# ----------------------------
# MAIN
# ----------------------------
mapping = read_output_positions("outputs_position.txt")
reverse_mapping = build_reverse_mapping(mapping)

# ----------------------------
# Read files
# ----------------------------
with open("outputs_dut.txt", "r") as f:
    dut_lines = [line.strip() for line in f if line.strip()]

with open("outputs_ghdl.txt", "r") as f:
    ghdl_lines = [line.strip() for line in f if line.strip()]

# Trim to minimum length
min_len = min(len(dut_lines), len(ghdl_lines))
dut_lines = dut_lines[:min_len]
ghdl_lines = ghdl_lines[:min_len]

# Track result
passed = True

# ----------------------------
# Compare cycle by cycle
# ----------------------------
for i in range(min_len):
    dut = dut_lines[i]
    ghdl = ghdl_lines[i]

    # Align lengths (your original logic)
    ghdl_trimmed = ghdl[-len(dut):]

    # 🔥 IMPORTANT: reverse due to Verilog %b
    dut_r = dut[::-1]
    ghdl_r = ghdl_trimmed[::-1]

    if dut_r != ghdl_r:
        print(f"\nTest failed at cycle {i}")
        print(f"  DUT       : {dut}")
        print(f"  EMULATION : {ghdl_trimmed}")

        # ----------------------------
        # Find incorrect bits
        # ----------------------------
        for idx, (d, g) in enumerate(zip(dut_r, ghdl_r)):
            if d != g:
                signal, bit = reverse_mapping.get(idx, ("UNKNOWN", "?"))
                print(f"    -> Index {idx}: {signal}[{bit}] expected {d} got {g}")

        passed = False

# ----------------------------
# Final result
# ----------------------------
if passed:
    print("Test passed")