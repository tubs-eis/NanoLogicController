-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity lut is
    generic (
        addr_width : integer := 4
    );
    port (
        addr   : in std_logic_vector(addr_width - 1 downto 0);
        data   : in std_logic_vector(2 ** addr_width - 1 downto 0);
        result : out std_logic
    );
end lut;

architecture behavioral of lut is
begin
    result <= data(to_integer(unsigned(addr)));
end behavioral;
