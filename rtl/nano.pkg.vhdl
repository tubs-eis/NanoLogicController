-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;

package nano_pkg is

  -- Architectural Parameters
  constant NANO_I_W_C              : integer := 4;              -- Instruction Width
  constant NANO_I_ADR_W_C          : integer := 7;              -- Instruction Memory Address Width
  constant NANO_I_D_C              : natural := 2**7;
  constant REGISTER_ADDR_WIDTH     : integer := 4;
  constant REGISTER_WIDTH          : natural := 2**4;
  constant LUT_ADDR_WIDTH          : integer := 4;
  constant OPERANDS_WIDTH          : integer := 16;
  constant COUNTER_WIDTH           : integer := 4;
  constant STACK_I_W_C             : integer := 3;
  constant SHIFTREG_I_W_C          : integer := 3;
  constant NANO_D_ADR_W_C          : integer := 4;
  constant SIMPLE_SHIFT_ADDR_WIDTH : integer := 4;
  constant TEMP_REG_ADDR_WIDTH     : INTEGER := 4;
  constant TEMP_REG_WIDTH          : natural := 2**4;


  -- Datapath Control Word Bits
  constant CW_STACK_OP      : natural := 0;
  constant CW_LUT_OP        : natural := CW_STACK_OP      + STACK_I_W_C;
  constant CW_LUT_DATA      : natural := CW_LUT_OP        + 1;
  constant CW_TEMP_REG_RW   : natural := CW_LUT_DATA      + 2 ** LUT_ADDR_WIDTH;
  constant CW_TEMP_REG_EN   : natural := CW_TEMP_REG_RW   + 1;
  constant CW_TEMP_REG_ADDR : natural := CW_TEMP_REG_EN   + 1;
  constant CW_IMEM_OE       : natural := CW_TEMP_REG_ADDR + TEMP_REG_ADDR_WIDTH;
  constant CW_IMEM_WE       : natural := CW_IMEM_OE       + 1;
  constant CW_IMEM_ADDR     : natural := CW_IMEM_WE       + 1;
  constant CW_LOADI_DATA    : natural := CW_IMEM_ADDR     + NANO_I_ADR_W_C;
  constant CW_DMEM_OE       : natural := CW_LOADI_DATA    + REGISTER_WIDTH;      
  constant CW_DMEM_WE       : natural := CW_DMEM_OE       + 1;    
  constant CW_DMEM_ADDR     : natural := CW_DMEM_WE       + 1;
  constant CW_SAVE_TOP      : natural := CW_DMEM_ADDR     + 1;
  constant CW_WIDTH         : natural := CW_SAVE_TOP      + NANO_D_ADR_W_C;


  -- Opcode definitions
  constant OP_LUT_3    : std_logic_vector(NANO_I_W_C -1 downto 0) := "0111";
  constant OP_LUT_4    : std_logic_vector(NANO_I_W_C -1 downto 0) := "1111";
  constant OP_LUTI_0   : std_logic_vector(NANO_I_W_C -1 downto 0) := "0001";
  constant OP_LUTI_1   : std_logic_vector(NANO_I_W_C -1 downto 0) := "1001";
  constant OP_ST       : std_logic_vector(NANO_I_W_C -1 downto 0) := "0010";
  constant OP_LD       : std_logic_vector(NANO_I_W_C -1 downto 0) := "1100";
  constant OP_LUT_2    : std_logic_vector(NANO_I_W_C -1 downto 0) := "1010";
  constant OP_MEM_LD   : std_logic_vector(NANO_I_W_C -1 downto 0) := "0011";
  constant OP_MEM_ST   : std_logic_vector(NANO_I_W_C -1 downto 0) := "1011";
  constant OP_SLEEP    : std_logic_vector(NANO_I_W_C -1 downto 0) := "0100";
  constant OP_LOAD_STR : std_logic_vector(NANO_I_W_C -1 downto 0) := "0101";
  constant OP_LOAD_PLL : std_logic_vector(NANO_I_W_C -1 downto 0) := "1101";
  constant OP_NOP      : std_logic_vector(NANO_I_W_C -1 downto 0) := "0000";
  constant OP_LUTR     : std_logic_vector(NANO_I_W_C -1 downto 0) := "1000";
  constant OP_SAVE     : std_logic_vector(NANO_I_W_C -1 downto 0) := "0110";


  -- Stack Opcode definitions
  constant OP_STACK_NOP   : std_logic_vector(STACK_I_W_C -1 downto 0) := "000";
  constant OP_STACK_POP   : std_logic_vector(STACK_I_W_C -1 downto 0) := "001";
  constant OP_STACK_LUT_3 : std_logic_vector(STACK_I_W_C -1 downto 0) := "010";
  constant OP_STACK_LUT_4 : std_logic_vector(STACK_I_W_C -1 downto 0) := "011";
  constant OP_STACK_PUSH  : std_logic_vector(STACK_I_W_C -1 downto 0) := "101";
  constant OP_STACK_INIT  : std_logic_vector(STACK_I_W_C -1 downto 0) := "110";
  constant OP_STACK_LUT_2 : std_logic_vector(STACK_I_W_C -1 downto 0) := "111";
  -- Shift-register Opcode definitions
  constant OP_SHIFTREG_HOLD        : std_logic_vector(SHIFTREG_I_W_C -1 downto 0) := "000";
  constant OP_SHIFTREG_SHIFT_LEFT  : std_logic_vector(SHIFTREG_I_W_C -1 downto 0) := "001";
  constant OP_SHIFTREG_SHIFT_RIGHT : std_logic_vector(SHIFTREG_I_W_C -1 downto 0) := "010";
  constant OP_SHIFTREG_LUT_3       : std_logic_vector(SHIFTREG_I_W_C -1 downto 0) := "011";
  constant OP_SHIFTREG_LUT_4       : std_logic_vector(SHIFTREG_I_W_C -1 downto 0) := "100";
  constant OP_SHIFTREG_LOAD        : std_logic_vector(SHIFTREG_I_W_C -1 downto 0) := "110";
  constant OP_SHIFTREG_LUT_2       : std_logic_vector(SHIFTREG_I_W_C -1 downto 0) := "111";


  -- LUT size flag definition
  constant FL_LUT_3      : std_logic := '0';
  constant FL_LUT_4      : std_logic := '1';
  constant STREAM_LOAD   : std_logic := '0';
  constant PARALLEL_LOAD : std_logic := '1';
  constant LOAD          : std_logic := '0';
  constant STORE         : std_logic := '1';

end nano_pkg;
