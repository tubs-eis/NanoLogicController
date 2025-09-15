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
use work.aux_pkg.all;
use work.nano_pkg.all;
use work.my_types.all;   -- Assumes sulv_array and SHIFTREG_I_W_C are defined here
entity accumulator is
    generic (
        stack_addr_width : integer := 4; -- e.g. 4 => shift_register size = 16 bits
        data_width       : natural := 2**4
    );
    port (
        clk        : in  std_logic;
        new_result : in  std_logic; -- Will feed into shift_register's D input
        op_code    : in  std_logic_vector(STACK_I_W_C - 1 downto 0);

        init_data  : in  std_logic_vector(data_width - 1 downto 0);
        output     : out std_logic_vector(data_width - 1 downto 0)
    );
end entity accumulator;

architecture behavioral of accumulator is

    signal shift_reg_opcode : sulv_array_shift(data_width - 1 downto 0);
    signal shift_reg_out    : std_logic_vector(data_width - 1 downto 0);

begin

    -- SHIFT REGISTER INSTANTIATION
    U_shift_reg : entity work.shift_register
        generic map(
            DATA_ADDR_WIDTH => stack_addr_width,
            DATA_WIDTH      => data_width
        )
        port map(
            clk       => clk,
            D         => new_result,
            opcode    => shift_reg_opcode,
            Q         => shift_reg_out,
            init_data => init_data
        );

    -- Combinational process: decode stack op_code into the shift register opcode array.
    -- As soon as op_code changes or reset_n changes, shift_reg_opcode updates.
    process (op_code)

    begin
        -- Interpret the "stack" op_code and generate a shift_register opcode.
        case op_code is
            when OP_STACK_NOP =>
                shift_reg_opcode    <= (others => OP_SHIFTREG_HOLD);
            when OP_STACK_INIT =>
                shift_reg_opcode    <= (others => OP_SHIFTREG_LOAD);
            when OP_STACK_PUSH =>
                -- Example: shift left when we see a PUSH.
                shift_reg_opcode    <= (others => OP_SHIFTREG_SHIFT_LEFT);
            when OP_STACK_POP =>
                -- Example: shift right on POP.
                shift_reg_opcode    <= (others => OP_SHIFTREG_SHIFT_RIGHT);
            when OP_STACK_LUT_3 =>
                -- Here: index 0 gets 'OP_SHIFTREG_PUSH', everything else gets 'OP_SHIFTREG_LUT_3'.
                shift_reg_opcode    <= (others => OP_SHIFTREG_LUT_3);
                shift_reg_opcode(0) <= OP_SHIFTREG_SHIFT_LEFT;
            when OP_STACK_LUT_4 =>
                -- Here: index 0 gets 'OP_SHIFTREG_PUSH', everything else gets 'OP_SHIFTREG_LUT_4'.
                shift_reg_opcode    <= (others => OP_SHIFTREG_LUT_4);
                shift_reg_opcode(0) <= OP_SHIFTREG_SHIFT_LEFT;
            when OP_STACK_LUT_2 =>
                -- Here: index 0 gets 'OP_SHIFTREG_PUSH', everything else gets 'OP_SHIFTREG_LUT_4'.
                shift_reg_opcode    <= (others => OP_SHIFTREG_LUT_2);
                shift_reg_opcode(0) <= OP_SHIFTREG_SHIFT_LEFT;

            when others =>
                -- Default: hold the shift_reg contents.
                shift_reg_opcode    <= (others => OP_SHIFTREG_HOLD);
        end case;

    end process;

    -- Drive the output with the shift register's output.
    output <= shift_reg_out;

end architecture behavioral;
