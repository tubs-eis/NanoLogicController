## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


## main.py switches
constantMainDrawDAG = False

## NanoLogicController Constants
STACK_ADDR_WIDTH_MAX = 4
STACK_ADDR_WIDTH_REAL = 4
SAVE_REG_ADDR_WIDTH_MAX = 4
SAVE_REG_ADDR_WIDTH_REAL = 4
TEMP_REG_ADDR_WIDTH_MAX = 12
TEMP_REG_ADDR_WIDTH_REAL = 12
IMEM_ADDR_WIDTH_MAX = 16
IMEM_ADDR_WIDTH_REAL = 16
TEMP_REG_SIZE = 1120
OPCODES = {
    "OP_NOP": "0000",
    "OP_LUTI_0": "0001",
    "OP_ST": "0010",
    "OP_MEM_LD": "0011",
    "OP_EOC": "0100",
    "OP_LOAD_STR": "0101",
    "OP_SAVE": "0110",
    "OP_LUT_3": "0111",
    "OP_LUTR": "1000",
    "OP_LUTI_1": "1001",
    "OP_LUT_2": "1010",
    "OP_MEM_ST": "1011",
    "OP_LD" : "1100",
    "OP_LOAD_PLL": "1101",
    "OP_LUT_4": "1111",
}
