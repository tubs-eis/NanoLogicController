## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


"""
Verilog-to-NanoLogicController Code Converter and Metrics Analyzer
===================================================

This script parses a synthesized Verilog netlist created through Yosys (via Pyverilog), extracts LUT
(Look-Up Table) instances, builds a dependency DAG of those LUTs, and generates
a low-level instruction stream suitable for the NanoLogicController.
It also tracks detailed execution metrics such as cycle count, instruction
count, stack/register usage, and the number of LUT/LOAD/STORE/SAVE operations.

Main Workflow:
--------------
1. Parse Verilog: Uses pyverilog.vparser to extract inputs, outputs,
   internal wires, registers, and LUT instances (LUT1..LUTn).
2. Build DAG: Constructs a directed acyclic graph (DAG) using networkx
   where nodes represent LUTs and edges represent signal dependencies.
3. Traverse DAG: Performs a depth-first traversal to generate NanoCode
   instructions for each LUT, managing stack state and temporary register slots.
4. Update Metrics: Tracks operation counts and resource utilization
   throughout traversal.
5. Visualization: Optionally draws the DAG to visualize LUT dependencies.
6. Output Artifacts:
   - result.mem: Generated NanoCode binary output.
   - result_metrics.json: Performance/resource metrics.
   - outputs_position.txt: Mapping of saved stack outputs.

Dependencies:
-------------
- pyverilog
- networkx
- matplotlib
- json
- constants
"""
import sys

from pyverilog.vparser.parser import parse
import networkx as nx
import matplotlib.pyplot as plt
import json
from constants import *
from collections import defaultdict


def update_metrics(
    init_cycle_count_inc: int = 0,
    cycle_count_inc: int = 0,
    instruction_count_inc: int = 0,
    current_needed_stack_inc: int = 0,
    current_temp_reg_inc: int = 0,
    current_save_reg_inc: int = 0,
    init_luti_operations_inc: int = 0,
    init_st_operations_inc: int = 0,
    luti_operations_inc: int = 0,
    lut_operations_inc: int = 0,
    ld_operations_inc: int = 0,
    st_operations_inc: int = 0,
    save_operations_inc: int = 0
):
    """Increment various execution and resource tracking metrics."""
    global current_needed_stack, current_needed_temp_reg, metrics

    # Update basic counts
    metrics["init_cycle_count"] += init_cycle_count_inc
    metrics["cycle_count"] += cycle_count_inc
    metrics["instruction_count"] += instruction_count_inc

    # Track current and peak stack usage
    current_needed_stack += current_needed_stack_inc
    metrics["needed_stack"] = max(
        metrics["needed_stack"], current_needed_stack)

    # Track current and peak temp register usage
    current_needed_temp_reg += current_temp_reg_inc
    metrics["needed_temp_reg"] = max(
        metrics["needed_temp_reg"], current_needed_temp_reg)

    # Track how many save registers are required in total
    metrics["needed_save_reg"] += current_save_reg_inc

    # Count individual operation types
    metrics["# init LUTI operations"] += init_luti_operations_inc
    metrics["# init ST operations"] += init_st_operations_inc
    metrics["# LUTI operations"] += luti_operations_inc
    metrics["# LUT operations"] += lut_operations_inc
    metrics["# LD operations"] += ld_operations_inc
    metrics["# ST operations"] += st_operations_inc
    metrics["# SAVE operations"] += save_operations_inc

def handle_const(const_value, opcode, code):
    key = (const_value, 0)
    added_code=""
    if key not in assignments_dict:
        return code

    for assignment in assignments_dict[key]:
        if assignment in outputs:
            added_code += OPCODES[opcode] + " "
            print("LUTI", assignment, "=", const_value, "\n")

            update_metrics(
                cycle_count_inc=1,
                instruction_count_inc=1,
                current_needed_stack_inc=1,
                luti_operations_inc=1
            )

            added_code += OPCODES["OP_SAVE"] + "\n"
            print("saving output ", assignment, "\n")

            update_metrics(
                cycle_count_inc=1,
                instruction_count_inc=1,
                current_needed_stack_inc=-1,
                current_save_reg_inc=1,
                save_operations_inc=1
            )

            saved_stack.append(assignment)
    return code + added_code
def slot_to_little_endian_bin(slot: int, num_bits: int):
    """
    Convert an integer to a binary string grouped in 4-bit nibbles,
    reversing nibbles for little-endian representation.
    """
    # Convert to binary string with padding
    bin_str = f"{slot:0{num_bits}b}"  # e.g., '00000111' for slot=7, num_bits=8

    # Split into 4-bit nibbles
    nibbles = []
    for i in range(0, len(bin_str), 4):
        nibbles.append(bin_str[i:i+4])

    # Reverse nibbles for little-endian
    nibbles.reverse()

    # Join with spaces
    return ' '.join(nibbles)


def expand_signal(signal):
    """Expand a Verilog signal (possibly a bus) into a list of (name, bit_index) tuples."""
    if signal.width is not None:
        # Multi-bit signal: determine range and width
        msb = int(signal.width.msb.value)
        lsb = int(signal.width.lsb.value)
        start = min(msb, lsb)
        width = abs(msb - lsb) + 1
    else:
        # Single-bit signal
        start = 0
        width = 1

    # Return one (name, bit_index) entry per bit
    return [(signal.name, i) for i in range(start, start + width)]


def draw_dag_layers(G, title="DAG layout in topological order"):
    for layer, nodes in enumerate(nx.topological_generations(G)):
        for node in nodes:
            G.nodes[node]["layer"] = layer

    pos = nx.multipartite_layout(G, subset_key="layer")

    fig, ax = plt.subplots()
    nx.draw_networkx(
        G,
        pos=pos,
        ax=ax,
        with_labels=True,
        node_size=700,
        node_color="lightblue",
        arrows=True,
    )

    # Prepare edge labels: get 'wire' attribute from each edge if present
    edge_labels = {(u, v): d.get("wire", "") for u, v, d in G.edges(data=True)}
    nx.draw_networkx_edge_labels(G, pos, edge_labels=edge_labels, ax=ax)

    ax.set_title(title)
    fig.tight_layout()
    plt.show()


def lut1_to_lut2_string(verilog_str):
    """
    Convert a LUT1 INIT string from Verilog into a LUT2-style 4-bit binary string.
    Each bit of the LUT1 truth table is duplicated to match LUT2 format.
    """
    # Extract the hex value from the Verilog string (e.g., "1'h2" -> "2")
    hex_part = verilog_str.split("'h")[1]

    # Convert the hex value to a 2-bit binary string
    bin_str = bin(int(hex_part, 16))[2:].zfill(2)

    # Duplicate each bit to form a 4-bit LUT2 representation
    repeated_bits = ''.join(bit * 2 for bit in bin_str)

    return repeated_bits


def verilog_hex_to_little_endian_binary(verilog_str, size):
    """
    Convert a Verilog INIT hex string to a little-endian binary string.

    Each 4-bit “word” is reversed to match little-endian representation used
    in NanoCode output.
    """
    # Strip the Verilog prefix, e.g., "8'h69" -> "69"
    hex_str = verilog_str.split("'h")[1]

    # Convert hex to binary, pad to 2^size bits (or at least 4 bits)
    bin_str = bin(int(hex_str, 16))[2:].zfill(max(4, 2**size))

    # Break binary string into 4-bit words
    words = [bin_str[i:i+4] for i in range(0, len(bin_str), 4)]

    # Reverse the 4-bit words to get little-endian order
    words_le = words[::-1]

    # Join with spaces
    return " ".join(words_le)


def expand_assign(lst, side):
    var = side

    # walk down until we find a usable node
    while True:
        if hasattr(var, "ptr") and var.ptr is not None:
            # bit-select
            name = var.var.name if hasattr(
                var, "var") else getattr(var, "name", "DUMMY")
            lst.append((name, int(var.ptr.value)))
            return

        elif hasattr(var, "msb") and var.msb is not None:
            # range
            msb = int(var.msb.value)
            lsb = int(var.lsb.value)

            name = var.var.name if hasattr(
                var, "var") else getattr(var, "name", "DUMMY")
        
            for i in range(msb, lsb - 1, -1):
                lst.append((name, i))
            return

        elif hasattr(var, "name"):
            wire = [item for item in wires + regs if var.name == item[0]]
            lst.extend(reversed(wire))
            return
        

        elif hasattr(var, "var"):
            # go one level deeper
            var = var.var

        else:
            # fallback
            print("Unknown node:", side)
            lst.append((var.value[3], 0))
            return


def process_input_permutation(original_init, new_order, original_order):
    """
    Reorder a LUT's INIT value to match a new input signal order.

    LUT INIT values encode the output for all possible input combinations as a binary string.
    If the input signals are reordered, the INIT bits must be permuted accordingly so the
    logical function remains correct.

    Parameters
    ----------
    original_init : str
        Verilog-style INIT string (e.g., "4'h9") representing the LUT truth table.
    new_order : list
        Desired order of input signals.
    original_order : list
        Original order of input signals as defined in the LUT.

    Returns
    -------
    str
        Verilog-style INIT string (e.g., "4'h9") with bits reordered to match `new_order`.
    """
    width = len(original_order)         # Number of inputs to the LUT
    bit_len = 1 << width                # Number of bits in INIT (2^inputs)

    # Convert original INIT from hex to binary string, padded to full width
    hex_val = int(original_init.split("'h")[1], 16)
    bitstring = f"{hex_val:0{bit_len}b}"[
        ::-1]  # Reverse for LSB-first indexing

    # Map each original input signal to its position in the INIT bit index
    orig_pos = {var: i for i, var in enumerate(original_order)}

    # Prepare a new bitstring for the reordered LUT
    new_bits = ['0'] * bit_len

    # Iterate over every bit in the original INIT
    for old_index in range(bit_len):
        # Determine which bit in the new INIT this corresponds to
        bit_parts = []
        for var in reversed(new_order):
            # Extract the bit value for this input variable from the old index
            bit_val = (old_index >> orig_pos[var]) & 1
            bit_parts.append(str(bit_val))

        # Compute the new index in the reordered INIT
        new_index = int(''.join(bit_parts), 2)
        # Place the original bit at its new position
        new_bits[new_index] = bitstring[old_index]

    # Convert the new bitstring back to integer, reverse it to match Verilog order
    new_val = int(''.join(new_bits)[::-1], 2)
    # Return as a Verilog-style hex string with bit width
    return f"{bit_len}'h{new_val:x}"


def process_lut(lut_instance, input_values_map):
    """
    Generate NanoLogicController instructions for a single LUT instance.

    This function handles:
    - Preparing LUT inputs in the correct order for code emission.
    - Removing inputs from the runtime stack that are consumed by this LUT.
    - Generating OP_LUTI or OP_LUT instructions depending on LUT size.
    - Appending the LUT output back to the runtime stack.

    Parameters
    ----------
    lut_instance : dict
        Metadata of the LUT including inputs, output, size, and INIT value.
    input_values_map : dict
        Mapping of input signals to their current values.

    Returns
    -------
    str
        NanoLogicController code representing this LUT's operation.
    """
    global current_stack, saved_stack, ff_dict, assignments_dict
    code = ""
    
    # Original input order from LUT definition
    inputs_original_order = lut_instance["inputs"]
    inputs_new_order = []
    # Handle the runtime stack by popping the used inputs
    inputs_new_order = []
    last_index = {}

    # 1) record last occurrence index
    for i, lut_output in enumerate(current_stack):
        if lut_output in inputs_original_order:
            last_index[lut_output] = i

    # 2) walk forward and collect in last-use order
    for i, lut_output in enumerate(current_stack):
        if last_index.get(lut_output) == i:
            inputs_new_order.append(lut_output)

    # 3) remove used inputs from the stack
    for idx in sorted(last_index.values(), reverse=True):
        current_stack.pop(idx)

    # Push LUT inputs as immediate values if they are module inputs and push FF outputs if they are needed ---
    for lut_input in reversed(inputs_original_order):
        if lut_input in inputs:
            value = input_values_map[lut_input]
            code += OPCODES[f"OP_LUTI_{value}"] + " "
            print("LUTI", lut_input, "=", value, "\n")
            update_metrics(
                cycle_count_inc=1,
                instruction_count_inc=1,
                current_needed_stack_inc=1,
                luti_operations_inc=1
            )
            inputs_new_order.append(lut_input)
        key = lut_input if lut_input in ff_dict['ff_q'] else None
        if key is None:
            for k in ff_dict['ff_q']:
                if lut_input in assignments_dict.get(k, []):
                    key = k
                    break
        if key is not None:
            slot = occupied_slots[key]

            code += f"{OPCODES['OP_LD']} {slot_to_little_endian_bin(slot, TEMP_REG_ADDR_WIDTH_MAX)}\n"
            print("Loading temp ", slot, "\n")

            update_metrics(
                cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
                instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
                current_needed_stack_inc=1,
                ld_operations_inc=1
            )        
            inputs_new_order.append(lut_input)
    if len(inputs_new_order) != len(inputs_original_order):
        raise ValueError(
            f"Not enough inputs fed to LUT. "
            f"Expected {len(inputs_original_order)}, got {len(inputs_new_order)}. "
            f"Missing: {set(inputs_original_order) - set(inputs_new_order)}"
        )
    # --- Generate LUT instruction ---
    if lut_instance['size'] == 1:
        # Special case for 1-input LUTs: use OP_LUTI + OP_LUT_2
        code += OPCODES["OP_LUTI_0"] + " " + OPCODES["OP_LUT_2"] + \
            " " + lut1_to_lut2_string(lut_instance["init"]) + " "
        print("LUT1 processing : LUTI 0; LUT2 ",
              lut1_to_lut2_string(lut_instance["init"]), "\n")
        update_metrics(
            cycle_count_inc=1+2,
            instruction_count_inc=1+2,
            current_needed_stack_inc=1,
            luti_operations_inc=1,
            lut_operations_inc=1
        )
        update_metrics(current_needed_stack_inc=-1)
    else:
        # General case for n-input LUTs
        lut_key = OPCODES[f"OP_LUT_{lut_instance['size']}"]
        # Reorder inputs and convert INIT to little-endian binary
        permuted_init = process_input_permutation(
            lut_instance["init"],
            list(reversed(inputs_new_order)),
            inputs_original_order
        )
        code += lut_key + " " + \
            verilog_hex_to_little_endian_binary(
                permuted_init, lut_instance['size']) + " "
        print("LUT", lut_instance['size'], " ", verilog_hex_to_little_endian_binary(
            permuted_init, lut_instance['size']), "\n")
        update_metrics(
            cycle_count_inc=1 + (2 ** lut_instance['size']) // 4,
            instruction_count_inc=1 + (2 ** lut_instance['size']) // 4,
            current_needed_stack_inc=1 - lut_instance['size'],
            lut_operations_inc=1
        )
    # --- Push the LUT output back to the stack ---
    current_stack.append(lut_instance['output'])

    return code


def dfs_process(node, G, lut_dict, input_values_map, visited, remaining_uses,
                code_accum, free_slots, occupied_slots):
    """
    Recursively traverse the LUT dependency graph to generate NanoLogicController code.

    This function walks the DAG of LUTs in depth-first order. It ensures that each LUT's
    inputs are evaluated before the LUT itself, respecting signal dependencies. While doing
    so, it handles temporary slot allocation, stack updates, and code emission for the
    NanoLogicController instruction set.

    Parameters:
    ----------
    node : str
        Current LUT node in the DAG being processed.
    G : networkx.DiGraph
        The LUT dependency graph where edges represent signal dependencies.
    lut_dict : dict
        Mapping from LUT names to their metadata (inputs, outputs, INIT value, etc.).
    input_values_map : dict
        Mapping of input signals to their simulation values.
    visited : set
        LUT nodes already processed to avoid revisiting.
    remaining_uses : dict
        Tracks how many more times each LUT output is needed by its successors.
    code_accum : str, optional
        Accumulated NanoLogicController code generated so far.
    free_slots : set, optional
        Available temporary slots for storing intermediate LUT results.
    occupied_slots : dict, optional
        Mapping of output signals to currently occupied temporary slots.

    Returns:
    -------
    str
        Updated NanoLogicController code.
    """
    global current_stack, saved_stack, outputs, ff_dict
    lut_instance = lut_dict[node]
    lut_output = lut_instance["output"]

    # --- Node already processed ---
    if node in visited:
        # If this LUT output was stored in a temporary slot, load it back to the stack
        assert lut_output in occupied_slots
        slot = occupied_slots[lut_output]
        code_accum += f"{OPCODES['OP_LD']} {slot_to_little_endian_bin(slot,TEMP_REG_ADDR_WIDTH_MAX)}\n"
        print("Loading temp ", slot, "\n")
        update_metrics(
            cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            current_needed_stack_inc=1,
            ld_operations_inc=1
        )
        current_stack.append(lut_instance["output"])
        # No further processing needed for this node
        return code_accum

    visited.add(node)

    # Ensures that all LUT inputs are available before generating code for this LUT
    for dep in G.predecessors(node):
        code_accum = dfs_process(
            dep, G, lut_dict, input_values_map,
            visited, remaining_uses,
            code_accum, free_slots, occupied_slots
        )

    # Generate NanoLogicController instructions for this LUT
    print("processing LUT:", lut_instance.get("name", str(node)))
    code_accum += process_lut(lut_instance, input_values_map)

    key = lut_output
    targets = set()
    if key in outputs:
        targets.add(key)
    if key in assignments_dict:
        for dest in assignments_dict[key]:
            if dest in outputs:
                targets.add(dest)
    slot = None
    feeds_ff = lut_output in ff_dict["ff_nxt"] or any(val in ff_dict["ff_nxt"] for val in assignments_dict.get(lut_output, []))
    # If this LUT output is used more than once, save it in a free temporary slot.
    # Special case: if the output is a circuit output needed later by another LUT, it must be saved to avoid being lost.
    # Special case: if the output is a ff input it must be always saved to already allocated slot.
    if remaining_uses[node] >= 2 or (len(targets) == 1 and remaining_uses[node] >= 1) or len(targets) > 1 or feeds_ff:
        if any(val in ff_dict["ff_nxt"] for val in assignments_dict.get(lut_output, [])):
            for val in assignments_dict.get(lut_output, []):
                if val in ff_dict["ff_nxt"]:
                    code_accum += f"{OPCODES['OP_ST']} {slot_to_little_endian_bin(occupied_slots[val],TEMP_REG_ADDR_WIDTH_MAX)}\n"
                    print("Storing temp ", slot, "\n")
                    update_metrics(
                        cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
                        instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
                        st_operations_inc=1
                    )
                    break
        if lut_output in ff_dict["ff_nxt"]:
            assert lut_output in occupied_slots
            slot = occupied_slots[lut_output]
        else:
            if not free_slots:
                raise RuntimeError("No free slots available!")
            slot = min(free_slots)        # pick the smallest available slot
            free_slots.remove(slot)       # mark it as used
            occupied_slots[lut_output] = slot
            update_metrics(current_temp_reg_inc=1)
        # Emit instruction to store the LUT output into this slot
        code_accum += f"{OPCODES['OP_ST']} {slot_to_little_endian_bin(slot,TEMP_REG_ADDR_WIDTH_MAX)}\n"
        print("Storing temp ", slot, "\n")
        update_metrics(
            cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            st_operations_inc=1
        )

    for dep in G.predecessors(node):
        dep_output = lut_dict[dep]["output"]
        # Decrement remaining uses of dependencies
        remaining_uses[dep] -= 1
        # Free up slots of dependencies that are no longer needed(only if they are not ff inputs)
        if remaining_uses[dep] == 0 and dep_output in occupied_slots and dep_output not in ff_dict["ff_nxt"]:
            slot_to_free = occupied_slots.pop(dep_output)
            free_slots.add(slot_to_free)
            update_metrics(current_temp_reg_inc=-1)

    # Case 0: nothing to do
    if len(targets) == 0:
        return code_accum

    elif len(targets) == 1:
        target = next(iter(targets))

        code_accum += OPCODES["OP_SAVE"] + "\n"
        print("saving output ", target, "\n")

        update_metrics(
            cycle_count_inc=1,
            instruction_count_inc=1,
            current_needed_stack_inc=-1,
            current_save_reg_inc=1,
            save_operations_inc=1
        )

        current_stack.remove(lut_output)

        saved_stack.append(target)

    elif len(targets) > 1:
        first_time = True
        for target in targets:
            if not first_time:
                code_accum += f"{OPCODES['OP_LD']} {slot_to_little_endian_bin(slot, TEMP_REG_ADDR_WIDTH_MAX)}\n"
                print("Loading temp ", target, "\n")

                update_metrics(
                    cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
                    instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
                    current_needed_stack_inc=1,
                    ld_operations_inc=1
                )

            # save each target
            code_accum += OPCODES["OP_SAVE"] + "\n"
            print("saving output ", target, "\n")

            update_metrics(
                cycle_count_inc=1,
                instruction_count_inc=1,
                current_needed_stack_inc=-1,
                current_save_reg_inc=1,
                save_operations_inc=1
            )
            saved_stack.append(target)
            first_time = False
    if remaining_uses[node] >= 1:
        # Reload the saved output back to the stack if it will be used immediately
        code_accum += f"{OPCODES['OP_LD']} {slot_to_little_endian_bin(slot,TEMP_REG_ADDR_WIDTH_MAX)}\n"
        print("Loading temp ", slot, "\n")
        update_metrics(
            cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            current_needed_stack_inc=1,
            ld_operations_inc=1
        )
        current_stack.append(lut_output)

    return code_accum


# region Main Execution
"""
Main execution workflow

1. Load input values from JSON and map them to signals.
2. Parse the synthesized Verilog file to extract:
   - Inputs, outputs, wires, regs, inouts
   - LUT instances (LUT1..LUTn)
3. Build a directed acyclic graph (DAG) of LUT dependencies.
4. Topologically sort the DAG and visualize it.
5. Traverse the DAG in reverse topological order, generating
   NanoCode instructions for each LUT while managing:
   - Current stack
   - Saved stack
   - Free/occupied temporary slots
   - Resource usage metrics
6. Write outputs:
   - `result.mem` — final NanoCode
   - `result_metrics.json` — metrics
   - `outputs_position.txt` — saved stack mapping
"""
# --- Load input values ---
with open("input_order.txt") as f:
    inputs = []
    for line in f:
        name, width = line.split()
        inputs.append((name, int(width)))

with open("inputs.txt") as f:
    bits = f.read().strip()

pos = 0
input_values_map = {}

for name, width in inputs:

    chunk = bits[pos:pos + width]
    pos += width

    # chunk is MSB → LSB (left → right)
    for i, b in enumerate(chunk):
        bit_index = width - 1 - i   # convert to LSB indexing
        input_values_map[(name, bit_index)] = int(b)

# Initialize lists to store signals
inputs = []
outputs = []
inouts = []
wires = []
regs = []
lut_instances = []
ff_dict = {
    "ff_q": [],
    "ff_nxt": [],
    "ff_init": []
}
assignments_dict = defaultdict(list)
# Verilog file to parse
f = "../yosys_flow/synth.v"

# --- Parse the Verilog file ---
inter_result = parse([f])[0]
result = inter_result.description.definitions
# Dump the parsed structure to JSON for debugging or inspection
with open("output.json", "w") as ggg:
    json.dump(inter_result, ggg, indent=4, default=lambda o: o.__dict__)

#get the right design from parsing
if len(result) == 1:
    items = result[0].items
elif len(sys.argv) > 1:
    design_name = sys.argv[1]
    print("Got argument:", design_name)
    match = next((r for r in result if r.name == design_name), None)
    if match is None:
        raise ValueError(f"Design '{design_name}' not found")
    items = match.items
else:
    raise ValueError("design_name argument is required")


# --- Go through all module items ---
for decl in items:
    # Handle signal declarations
    if decl.__class__.__name__ == "Decl":
        for item in decl.list:
            cls = item.__class__.__name__

            # Expand multi-bit signals into individual bits
            if cls == "Input":
                inputs.extend(expand_signal(item))
            elif cls == "Output":
                outputs.extend(expand_signal(item))
            elif cls == "Inout":
                inouts.extend(expand_signal(item))
            elif cls == "Wire":
                wires.extend(expand_signal(item))
            elif cls == "Reg":
                regs.extend(expand_signal(item))

    # Handle LUT modules like LUT2, LUT3, LUT4, etc.
    elif decl.__class__.__name__ == "InstanceList" and decl.module.startswith("LUT"):
        # get LUT size from the module name, e.g. "LUT3" -> 3
        size = int(decl.module[3:])
        init_value = None

        # Find the INIT parameter if it exists (defines the LUT's truth table)
        if hasattr(decl, "parameterlist") and decl.parameterlist:
            for param in decl.parameterlist:
                if param.paramname == "INIT":
                    init_value = param.argname.value

        # Go through each instance of this LUT
        for inst in decl.instances:
            lut_inputs = []
            output = None

            # Parse its port connections
            for port in inst.portlist:
                arg = port.argname

                if arg.__class__.__name__ == "Pointer":
                    # Vector signal like signal_name[3]
                    tup = (arg.var.name, int(arg.ptr.value))
                elif arg.__class__.__name__ == "Identifier":
                    # Scalar signal
                    tup = (arg.name, 0)
                else:
                    tup = ("UNKNOWN", -1)

                # The port named "O" is the LUT's output
                if port.portname == "O":
                    output = tup
                else:
                    lut_inputs.append(tup)

            # Record this LUT with its metadata
            lut_instances.append(
                (
                    inst.name,
                    {
                        "name": inst.name,
                        "size": size,
                        "init": init_value,
                        "inputs": lut_inputs,
                        "output": output,
                    },
                )
            )
    elif decl.__class__.__name__ == "Always":
        stmt = decl.statement

        # Case 1: With reset (IfStatement)
        if stmt.__class__.__name__ == "IfStatement":
            # false branch → next state
            var_right = stmt.false_statement.right.var
            var_left = stmt.false_statement.left.var

            resolved_left = getattr(var_left, "var", None)
            ff_dict["ff_q"].append((
                resolved_left.name if resolved_left else var_left.name,
                int(var_left.ptr.value) if resolved_left else 0
            ))

            resolved_right = getattr(var_right, "var", None)
            ff_dict["ff_nxt"].append((
                resolved_right.name if resolved_right else var_right.name,
                int(var_right.ptr.value) if resolved_right else 0
            ))

            # init from true branch
            ff_dict["ff_init"].append(
                int(stmt.true_statement.right.var.value[-1])
            )

        # Case 2: No reset (direct assignment)
        else:
            var_right = stmt.right.var
            var_left = stmt.left.var

            resolved_left = getattr(var_left, "var", None)
            ff_dict["ff_q"].append((
                resolved_left.name if resolved_left else var_left.name,
                int(var_left.ptr.value) if resolved_left else 0
            ))

            resolved_right = getattr(var_right, "var", None)
            if resolved_right:
                ff_dict["ff_nxt"].append((
                    resolved_right.name,
                    int(var_right.ptr.value)
                ))
            elif hasattr(var_right, "name"):
                ff_dict["ff_nxt"].append((var_right.name, 0))
            #Handle example like \DFF_136.Q  <= 1'h1;
            elif hasattr(var_right, "value"):
                ff_dict["ff_nxt"].append(int(var_right.value[-1]))
            else:
                ff_dict["ff_nxt"].append(0)

            # No reset → default init
            ff_dict["ff_init"].append(0)
    elif decl.__class__.__name__ == "Assign":
        rhs_list = []
        lhs_list = []
        expand_assign(lhs_list, decl.left)
        if hasattr(decl.right.var, "list"):
            for part in decl.right.var.list:
                expand_assign(rhs_list, part)
        else:
            expand_assign(rhs_list, decl.right)

        if len(lhs_list) != len(rhs_list):
            raise ValueError("width mismatch")
        for l, r in zip(lhs_list, rhs_list):
            assignments_dict[r].append(l)
G = nx.DiGraph()
G.add_nodes_from(lut_instances)

# Map each signal output to the LUT that produces it
signal_to_producer = {info["output"]: name for name, info in lut_instances}

# Add edges between LUTs: connect producer outputs to consumer inputs
for lut_name, info in lut_instances:
    for in_signal in info["inputs"]:
        producer = signal_to_producer.get(in_signal)
        if producer and producer != lut_name:
            G.add_edge(producer, lut_name, wire=in_signal)

# Sort the graph topologically (execution order) and draw it for visualization
sorted_nodes = list(nx.topological_sort(G))
if constantMainDrawDAG:
    draw_dag_layers(G)

# --- Initialize traversal and state tracking ---
start_address = 0
visited = set()
full_code = ""
lut_dict = {name: info for name, info in lut_instances}
remaining_uses = {node: len(list(G.successors(node))) for node in G.nodes}
ff_count = len(ff_dict["ff_q"])
# Free/occupied LUT slots and runtime stack info
free_slots = set(range(TEMP_REG_SIZE))
occupied_slots = {}
current_stack = []
saved_stack = []
# Initialize runtime and resource metrics
metrics = {
    "stack size": STACK_ADDR_WIDTH_MAX,
    "temp_stack size": TEMP_REG_ADDR_WIDTH_MAX,
    "saved_stack size": SAVE_REG_ADDR_WIDTH_MAX,
    "instruction_count": 0,
    "init_cycle_count": 0,
    "cycle_count": 0,
    "needed_temp_reg": 0,
    "needed_save_reg": 0,
    "needed_stack": 0,
    "# init LUTI operations": 0,
    "# init ST operations": 0,
    "# LUTI operations": 0,
    "# LUT operations": 0,
    "# ST operations": 0,
    "# LD operations": 0,
    "# SAVE operations": 0,
}
current_needed_stack = 0
current_needed_temp_reg = 0

# --- Generate NanoCode ---
# initialize the ff values and reserve slots for all ff_q and ff_nxt
for i in range(ff_count):
    config_singleInit = True  # FOR PAPER EVALUATION: only single LUTI required if all register init values are the same! Disable again for general-purpose netlist processing
    if config_singleInit and i == 0:
        full_code += OPCODES[f"OP_LUTI_{ff_dict['ff_init'][i]}"] + " "
        print("LUTI", ff_dict['ff_q'][i], "=", ff_dict['ff_init'][i], "\n")
        start_address += 1
        update_metrics(
            init_cycle_count_inc=1,
            instruction_count_inc=1,
            current_needed_stack_inc=0,
            init_luti_operations_inc=1
        )
    assert free_slots
    # reserve slot for ff_q(pair slots always for ff_q due to EOC operation)
    slot = 2*i
    free_slots.remove(slot)       # mark it as used
    occupied_slots[ff_dict['ff_q'][i]] = slot
    # Emit instruction to store the FF initial value into this slot
    full_code += f"{OPCODES['OP_ST']} {slot_to_little_endian_bin(slot,TEMP_REG_ADDR_WIDTH_MAX)}\n"
    # start address increases by 2(LUTI and ST) plus number of words for temp reg address
    start_address += 1 + TEMP_REG_ADDR_WIDTH_MAX // 4
    print("Storing temp ", slot, "\n")
    update_metrics(
        init_cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
        instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
        current_temp_reg_inc=1,
        init_st_operations_inc=1
    )
    slot = 2*i + 1        # reserve slot for ff_nxt
    free_slots.remove(slot)       # mark it as used
    occupied_slot_ff_nxt = ff_dict['ff_nxt'][i] 
    if occupied_slot_ff_nxt is not int:
        if ff_dict["ff_nxt"][i] in ff_dict["ff_q"] : occupied_slot_ff_nxt = (occupied_slot_ff_nxt[0] + "_nxt", occupied_slot_ff_nxt[1])
        occupied_slots[occupied_slot_ff_nxt] = slot
    
    update_metrics(current_temp_reg_inc=1)



# Traverse the graph in reverse topological order
for node in reversed(sorted_nodes):
    if node not in visited:
        full_code = dfs_process(
            node,
            G,
            lut_dict,
            input_values_map,
            visited,
            remaining_uses,
            full_code,
            free_slots,
            occupied_slots
        )
# If output is a FF output save it
for i in range(ff_count):
    key = ff_dict["ff_q"][i]
    targets = set()

    # Case 1: direct output
    if key in outputs:
        targets.add((key, key))  # (ff, output)

    # Case 2: propagated outputs via assignments_dict
    if key in assignments_dict:
        for dest in assignments_dict[key]:
            if dest in outputs:
                targets.add((key, dest))  # (ff, output)

    # Execute for all valid targets
    for src, target in targets:
        slot = occupied_slots[src]

        # Load instruction
        full_code += f"{OPCODES['OP_LD']} {slot_to_little_endian_bin(slot, TEMP_REG_ADDR_WIDTH_MAX)}\n"
        print("Loading temp ", slot, "\n")

        update_metrics(
            cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            current_needed_stack_inc=1,
            ld_operations_inc=1
        )

        # Save instruction
        full_code += OPCODES["OP_SAVE"] + "\n"
        print("saving output ", target, "\n")

        update_metrics(
            cycle_count_inc=1,
            instruction_count_inc=1,
            current_save_reg_inc=1,
            save_operations_inc=1
        )

        saved_stack.append(target)
# If input is a design output or save it
for input in inputs:
    key = input
    targets = set()
    if key in outputs:
        targets.add(key)
    if key in assignments_dict:
        for dest in assignments_dict[key]:
            if dest in outputs:
                targets.add(dest)
    for target in targets:
        value = input_values_map[input]
        full_code += OPCODES[f"OP_LUTI_{value}"] + " "
        print("LUTI", input, "=", value, "\n")
        update_metrics(
            cycle_count_inc=1,
            instruction_count_inc=1,
            current_needed_stack_inc=1,
            luti_operations_inc=1
        )
        full_code += OPCODES["OP_SAVE"] + "\n"
        print("saving output ", target, "\n")

        update_metrics(
            cycle_count_inc=1,
            instruction_count_inc=1,
            current_needed_stack_inc=-1,
            current_save_reg_inc=1,
            save_operations_inc=1
        )
        saved_stack.append(target)
# Handle design inputs as ff inputs
for input in inputs:
    key = input
    targets = set()
    if key in ff_dict["ff_nxt"]:
        targets.add(key)
    if key in assignments_dict:
        for dest in assignments_dict[key]:
            if dest in ff_dict["ff_nxt"]:
                targets.add(dest)
    for target in targets:
        value = input_values_map[input]
        full_code += OPCODES[f"OP_LUTI_{value}"] + " "
        print("LUTI", input, "=", value, "\n")
        update_metrics(
            cycle_count_inc=1,
            instruction_count_inc=1,
            current_needed_stack_inc=1,
            luti_operations_inc=1
        )
        slot = occupied_slots[target]
        full_code += f"{OPCODES['OP_ST']} {slot_to_little_endian_bin(slot,TEMP_REG_ADDR_WIDTH_MAX)}\n"
        print("Storing temp ", slot, "\n")
        update_metrics(
            cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            st_operations_inc=1
        )
# Handle ff_q as ff_input
for i, ff_nxt in enumerate(ff_dict["ff_nxt"]):

    # Check direct match OR inside assignment_dict for any ff_q key
    matching_key = None

    for key in ff_dict["ff_q"]:
        if ff_nxt in assignments_dict.get(key, []):
            matching_key = key
            break

    if ff_nxt in ff_dict["ff_q"] or matching_key is not None:

        # Decide which key to use
        key = ff_nxt if ff_nxt in ff_dict["ff_q"] else matching_key
        ff_q_slot = occupied_slots[key]

        full_code += f"{OPCODES['OP_LD']} {slot_to_little_endian_bin(ff_q_slot, TEMP_REG_ADDR_WIDTH_MAX)}\n"
        print("Loading temp ", ff_q_slot, "\n")

        update_metrics(
            cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            current_needed_stack_inc=1,
            ld_operations_inc=1
        )

        current_stack.append(ff_nxt)

        full_code += f"{OPCODES['OP_ST']} {slot_to_little_endian_bin(occupied_slots[ff_dict['ff_q'][i]]+1, TEMP_REG_ADDR_WIDTH_MAX)}\n"
        print("Storing temp ", occupied_slots[ff_dict['ff_q'][i]]+1, "\n")

        update_metrics(
            cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            st_operations_inc=1
        )

# If ouput is static save it
full_code = handle_const("0", "OP_LUTI_0", full_code)
full_code = handle_const("1", "OP_LUTI_1", full_code)

#Handle static flilflops inputs        
for i, ff_nxt in enumerate(ff_dict['ff_nxt']):
    if isinstance(ff_nxt, int):
        full_code += OPCODES[f"OP_LUTI_{ff_nxt}"] + " "
        print(OPCODES[f"OP_LUTI_{ff_nxt}"])
        print("LUTI", ff_nxt, "=", value, " for ff_nxt \n")
        update_metrics(
            cycle_count_inc=1,
            instruction_count_inc=1,
            current_needed_stack_inc=1,
            luti_operations_inc=1
        )
        slot = occupied_slots[ff_dict['ff_q'][i]] + 1
        full_code += f"{OPCODES['OP_ST']} {slot_to_little_endian_bin(slot,TEMP_REG_ADDR_WIDTH_MAX)}\n"
        print("Storing temp ", slot, "\n")
        update_metrics(
            cycle_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            instruction_count_inc=1 + TEMP_REG_ADDR_WIDTH_MAX // 4,
            st_operations_inc=1
        )
        
full_code += f"{OPCODES['OP_EOC']} {slot_to_little_endian_bin(start_address,IMEM_ADDR_WIDTH_MAX)}\n"

# --- Write results to disk ---
# Save metrics for later inspection
with open("result_metrics.json", "w") as f:
    json.dump(metrics, f, indent=2)

# Write NanoCode to a .mem file used by the simulator
header = """// memory data file (do not edit the following line - required for mem load use)
// instance=/tb/top_module/u_nano_imem/imem
// format=bin addressradix=h dataradix=b version=1.0 wordsperline=1 noaddress
"""
with open("result.mem", "w") as file:
    file.write(header + full_code)
with open("code_ghdl.mem", "w") as file:
    chunks = full_code.strip().split()   # split on spaces/newlines
    file.write("\n".join(chunks))        # one chunk per line
# Record the mapping of saved outputs to stack positions
saved_stack.reverse()
with open("outputs_position.txt", "w") as file:
    for index, value in enumerate(saved_stack):
        line = f"{index}: {value}\n"
        file.write(line)

# For quick debugging: print the generated NanoCode
print(full_code)
# Check if number of  Outputs is correct
if len(saved_stack) != len(outputs):
    print(f"Mismatch: Code has {len(saved_stack)}, Design has {len(outputs)}")

    missing = set(outputs) - set(saved_stack)
    print("Missing outputs:", missing)
else:
    print("Number of outputs is correct")
# endregion
