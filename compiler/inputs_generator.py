## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


import sys

from pyverilog.vparser.parser import parse
import json
import random 

inputs = []
total_width=0
f = "../yosys_flow/synth.v"

# Parse once (you were parsing twice before)
ast, _ = parse([f])
result = ast.description.definitions
#get the right design from parsing
if len(result) == 1:
    wires = result[0].items
elif len(sys.argv) > 1:
    design_name = sys.argv[1]
    print("Got argument:", design_name)
    match = next((r for r in result if r.name == design_name), None)
    if match is None:
        raise ValueError(f"Design '{design_name}' not found")
    wires = match.items
else:
    raise ValueError("design_name argument is required")

for decl in wires:
    if decl.__class__.__name__ == "Decl":
        for item in decl.list:
            cls = item.__class__.__name__
            if cls == "Input":
                name = item.name
                name_lower = name.lower()
                is_clock = "clk" in name_lower or "clock" in name_lower or "ck" == name_lower
                is_reset = "rst" in name_lower or "reset" in name_lower
                if not (is_clock or is_reset):
                    width = item.width

                    if width:
                        w = int(width.msb.value) - int(width.lsb.value) + 1
                    else:
                        w = 1

                    inputs.append((name, w))
                    total_width += w

with open("input_order.txt", "w") as f:
    for name, width in inputs:
        f.write(f"{name} {width}\n")

# assume total_width already computed
binary_str = format(random.randint(0, 2**total_width - 1), f"0{total_width}b")

with open("inputs.txt", "w") as f:
    f.write(binary_str + "\n")
           