-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;

use work.aux_pkg.all;

entity nano_imem is
  generic(DEPTH      : natural;
          DEPTH_LOG2 : natural;
          WIDTH_BITS : natural
         );
  port(clk1_i  : in  std_logic;
       oe_i    : in  std_logic;
       we_i    : in  std_logic;
       addr_i  : in  std_logic_vector(DEPTH_LOG2-1 downto 0);
       -- 8 bit load, load 2 4-bit instructions parallel
       instr_i : in  std_logic_vector(2*WIDTH_BITS-1 downto 0);
       instr_o : out std_logic_vector(WIDTH_BITS-1 downto 0)
      );
end entity nano_imem;

