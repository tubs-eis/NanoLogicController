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
use work.nano_pkg.all; -- Assumes OP_SHIFTREG_ constants are defined here
use work.my_types.all; -- Assumes sulv_array and SHIFTREG_I_W_C are defined here

entity shift_register is
    generic (
        DATA_ADDR_WIDTH : natural := 4; -- 4 bits => register size = 2**4 = 16
        DATA_WIDTH      : natural := 2**4
    );
    port (
        clk       : in  std_logic;
        D         : in  std_logic;
        -- The opcode for each bit in the register.
        opcode    : in  sulv_array_shift(DATA_WIDTH - 1 downto 0);
        -- Output register
        Q         : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        init_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity shift_register;

architecture rtl of shift_register is

    -- Internal register signal
    signal reg : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

begin

    process (clk)
    begin
        if rising_edge(clk) then
            for i in 0 to DATA_WIDTH - 1 loop
                case opcode(i) is
                    when OP_SHIFTREG_HOLD =>
                        reg(i) <= reg(i); -- Hold the current value
                    when OP_SHIFTREG_LOAD =>
                        reg(i) <= init_data(i);
                    when OP_SHIFTREG_SHIFT_LEFT =>
                        if i = 0 then
                            reg(i) <= D;
                        else
                            reg(i) <= reg(i - 1);
                        end if;

                    when OP_SHIFTREG_SHIFT_RIGHT =>
                        if i = DATA_WIDTH - 1 then
                            -- For a right shift, the MSB is set to '0'
                            reg(i) <= '0';
                        else
                            reg(i) <= reg(i + 1);
                        end if;

                    when OP_SHIFTREG_LUT_2 =>
                        -- Bit i takes the value of bit i+2 if in range; otherwise '0'
                        if (i + 1) < DATA_WIDTH then
                            reg(i) <= reg(i + 1);
                        else
                            reg(i) <= '0';
                        end if;
                    when OP_SHIFTREG_LUT_3 =>
                        -- Bit i takes the value of bit i+2 if in range; otherwise '0'
                        if (i + 2) < DATA_WIDTH then
                            reg(i) <= reg(i + 2);
                        else
                            reg(i) <= '0';
                        end if;

                    when OP_SHIFTREG_LUT_4 =>
                        -- Bit i takes the value of bit i+3 if in range; otherwise '0'
                        if (i + 3) < DATA_WIDTH then
                            reg(i) <= reg(i + 3);
                        else
                            reg(i) <= '0';
                        end if;
                    when others =>
                        -- Default: hold the current value
                        reg(i) <= reg(i);
                end case;
            end loop;
        end if;
    end process;

    -- Drive the output
    Q <= reg;

end architecture rtl;
