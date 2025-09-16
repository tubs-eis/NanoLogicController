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
use work.my_types.all;
use work.nano_pkg.all;
entity nano_data is
    generic (
        register_addr_width     : integer := 4;
        register_width          : natural := 2**register_addr_width;
        lut_addr_width          : integer := 4;
        simple_shift_addr_width : integer := 4
    );
    port (
        clk          : in  std_logic;
        cw           : in  std_logic_vector(CW_WIDTH - 1 downto 0);
        reg_output   : out std_logic_vector(register_width - 1 downto 0);
        saved_ack    : out std_logic;
        saved_output : out std_logic_vector(2 ** simple_shift_addr_width - 1 downto 0)
    );
end nano_data;

architecture behavioral of nano_data is

    signal lut_result           : std_logic;
    signal register_out_intern  : std_logic_vector(register_width - 1 downto 0);
    signal lut_addr_reg         : std_logic_vector(lut_addr_width - 1 downto 0);
    -- Control word signals
    signal lut_data             : std_logic_vector(2 ** lut_addr_width - 1 downto 0);
    signal lut_sel              : std_logic_vector((lut_addr_width - 1) * REGISTER_ADDR_WIDTH - 1 downto 0);
    signal op_code_intern       : std_logic_vector(STACK_I_W_C - 1 downto 0);
    signal stack_pointer_intern : signed(register_addr_width downto 0);
    signal address_temp_reg     : STD_LOGIC_VECTOR(TEMP_REG_ADDR_WIDTH -1 downto 0);
    signal init_data_intern     : std_logic_vector(register_width - 1 downto 0);
    signal enable_shift         : std_logic;
    signal enable_temp_reg      : std_logic;
    signal rw_temp_reg          : std_logic;
    signal rw_bit_out           : std_logic;
    signal rw_bit_in            : std_logic;
    signal top_of_stack         : std_logic;
    signal saved_dout           : std_logic_vector(2 ** simple_shift_addr_width - 1 downto 0);
    signal acc_output_mux       : std_logic;
begin
    shift_inst: entity work.simple_shift_reg
        generic map (
            ADDR_WIDTH => simple_shift_addr_width
        )
        port map (
            clk  => clk,
            en   => enable_shift,
            din  => top_of_stack,
            ack  => saved_ack,
            dout => saved_dout
        );
    temp_reg_inst: entity work.temp_bit_reg_file
    generic map (
        ADDR_WIDTH => TEMP_REG_ADDR_WIDTH,
        REG_COUNT  => TEMP_REG_WIDTH
    )
    port map (
        clk  => clk,
        en   => enable_temp_reg,  -- enable for writing
        rw   => rw_temp_reg,      -- '1' = write, '0' = read
        addr => address_temp_reg, -- address for read/write
        din  => rw_bit_in,        -- input bit
        dout => rw_bit_out        -- output bit
    );

    acc_inst : entity work.accumulator
        generic map(
            stack_addr_width => register_addr_width, -- Match your desired address width
            data_width       => register_width
        )
        port map(
            clk        => clk,
            new_result => acc_output_mux,            -- Feeds into shift_register's D input
            op_code    => op_code_intern,            -- Connect to your internal opcode signal
            init_data  => init_data_intern,
            output     => register_out_intern
        );

    lut_inst : entity work.lut
        generic map(
            addr_width => lut_addr_width
        )
        port map(
            addr   => lut_addr_reg,
            data   => lut_data,
            result => lut_result
        );
    reg_output       <= register_out_intern;
    saved_output     <= saved_dout;
    rw_bit_in        <= register_out_intern(0);
    acc_output_mux   <= lut_result when enable_temp_reg = '0' else rw_bit_out;
    -- Extract Control word bits
    lut_data         <= CW(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA);
    op_code_intern   <= cw(CW_STACK_OP + 2 downto CW_STACK_OP); -- Extract 3 bits for stack_op
    lut_addr_reg     <= register_out_intern(3 downto 0);
    init_data_intern <= cw(CW_LOADI_DATA + register_width - 1 downto CW_LOADI_DATA);
    enable_shift     <= cw(CW_SAVE_TOP);
    enable_temp_reg  <= cw(CW_TEMP_REG_EN);
    rw_temp_reg      <= cw(CW_TEMP_REG_RW);
    address_temp_reg <= cw(CW_TEMP_REG_ADDR + TEMP_REG_ADDR_WIDTH - 1 downto CW_TEMP_REG_ADDR);
    top_of_stack     <= register_out_intern(0);
end behavioral;
