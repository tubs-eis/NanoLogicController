-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;
use work.nano_pkg.all;

package my_types is
    -- In a package or right above the entity
    type sulv_array_shift is array (natural range <>) of std_logic_vector(SHIFTREG_I_W_C - 1 downto 0);
end my_types;
