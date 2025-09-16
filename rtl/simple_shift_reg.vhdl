-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity simple_shift_reg is
    generic (
        ADDR_WIDTH : natural := 4 -- 4 bits => register size = 2**4 = 16
    );
    port (
        clk  : in  std_logic;
        en   : in  std_logic; -- enable signal
        din  : in  std_logic; -- serial input
        ack  : out std_logic;
        dout : out std_logic_vector(2 ** ADDR_WIDTH - 1 downto 0) -- register output
    );
end simple_shift_reg;

architecture Behavioral of simple_shift_reg is
    constant DATA_WIDTH : natural := 2 ** ADDR_WIDTH;
    signal reg : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin
    process (clk)
    begin
        if rising_edge(clk) then
            ack <= en;
            if en = '1' then
                reg <= reg(DATA_WIDTH - 2 downto 0) & din; -- shift left
            end if;
        end if;
    end process;
    dout <= reg;
end Behavioral;
