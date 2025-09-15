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

use work.aux_pkg.all;

library top_level;

entity temp_bit_reg_file is
    generic (
        ADDR_WIDTH : natural := 4;  -- 4 bits => 16 registers (1 bit each)
        REG_COUNT  : natural := 2**4
    );
    port (
        clk  : in  std_logic;
        en   : in  std_logic; -- enable for write
        rw   : in  std_logic; -- '0' = read, '1' = write
        addr : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
        din  : in  std_logic; -- 1-bit input
        dout : out std_logic  -- 1-bit output
    );
end temp_bit_reg_file;

architecture Behavioral of temp_bit_reg_file is
    signal reg_file : std_logic_vector(REG_COUNT - 1 downto 0) := (others => '0');
    signal wen      : std_logic_vector(2**ADDR_WIDTH - 1 downto 0);
begin
    wen <= dectree(en and rw, addr);

    process (clk)
    begin
        if rising_edge(clk) then
            for i in 0 to REG_COUNT-1 loop
                if wen(i) = '1' then
                    reg_file(i) <= din; -- write bit
                end if;
            end loop; --i
        end if;
    end process;

    -- Read path: always outputs the bit at addr
    process(reg_file, addr)
        variable dvec : std_logic_vector(2**ADDR_WIDTH-1 downto 0);
        variable ovec : std_logic_vector(0 downto 0);
    begin
        dvec := (others => '-');
        dvec(REG_COUNT-1 downto 0) := reg_file;
        ovec := muxtree(dvec, addr, 1);
        dout <= ovec(0);
    end process;
end Behavioral;

