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
use work.nano_pkg.all;

entity nano_top is
  port (
    clk                   : in  std_logic;
    reset_n               : in  std_logic;
    reg_output            : out std_logic_vector(REGISTER_WIDTH - 1 downto 0);
    saved_output          : out std_logic_vector(2 ** SIMPLE_SHIFT_ADDR_WIDTH - 1 downto 0);
    wake_i                : in  std_logic;
    imem_we_i             : in  std_logic;
    imem_addr_i           : in  std_logic_vector(NANO_I_ADR_W_C - 1 downto 0);
    instr_i               : in  std_logic_vector(2*NANO_I_W_C - 1 downto 0);
    stream_bit_i          : in  std_logic;
    stream_bit_ready_i    : in  std_logic;
    stream_bit_ack_o      : out std_logic;
    parallel_data_i       : in  std_logic_vector(REGISTER_WIDTH - 1 downto 0);
    parallel_data_ready_i : in  std_logic;
    parallel_data_ack_o   : out std_logic
  );
end entity nano_top;

architecture rtl of nano_top is

  -- Signals for internal connections
  signal cw                       : std_logic_vector(CW_WIDTH - 1 downto 0);
  signal instr_out                : std_logic_vector(NANO_I_W_C - 1 downto 0);
  signal lut_data                 : std_logic_vector(2 ** LUT_ADDR_WIDTH - 1 downto 0);
  signal imem_we                  : std_logic;
  signal imem_oe                  : std_logic;
  signal imem_addr, imem_addr_mux : std_logic_vector(NANO_I_ADR_W_C - 1 downto 0);
  signal stack_op                 : std_logic_vector(2 downto 0); -- 3 bits for stack operation
  signal init_data                : std_logic_vector(REGISTER_WIDTH - 1 downto 0);
  signal memory_read_data         : std_logic_vector(REGISTER_WIDTH - 1 downto 0);
  signal dmem_oe                  : std_logic;
  signal dmem_we                  : std_logic;
  signal dmem_addr                : std_logic_vector(NANO_D_ADR_W_C - 1 downto 0);
  signal wake_addr                : std_logic_vector(REGISTER_WIDTH - 1 downto 0);
  signal reg_output_int           : std_logic_vector(REGISTER_WIDTH - 1 downto 0);
begin

  lut_data   <= cw(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA);
  stack_op   <= cw(CW_STACK_OP + 2 downto CW_STACK_OP); -- Extract 3 bits for stack_op
  imem_we    <= cw(CW_IMEM_WE);
  imem_oe    <= cw(CW_IMEM_OE);
  init_data  <= cw(CW_LOADI_DATA + REGISTER_WIDTH - 1 downto CW_LOADI_DATA);
  imem_addr  <= cw(CW_IMEM_ADDR + NANO_I_ADR_W_C - 1 downto CW_IMEM_ADDR);
  dmem_oe    <= cw(CW_DMEM_OE);
  dmem_we    <= cw(CW_DMEM_WE);
  dmem_addr  <= cw(CW_DMEM_ADDR + NANO_D_ADR_W_C - 1 downto CW_DMEM_ADDR);
  reg_output <= reg_output_int;
  -- Instance of nano_data
  u_nano_data : entity work.nano_data
    generic map(
      register_addr_width     => REGISTER_ADDR_WIDTH,
      register_width          => REGISTER_WIDTH,
      lut_addr_width          => LUT_ADDR_WIDTH,
      simple_shift_addr_width => SIMPLE_SHIFT_ADDR_WIDTH
    )
    port map(
      clk          => clk,
      cw           => cw,
      reg_output   => reg_output_int,
      saved_output => saved_output
    );
  -- Instance of nano_imem
  imem_addr_mux <= imem_addr_i when reset_n = '0' else imem_addr;
  u_nano_imem : entity work.nano_imem(edge_ram)
    generic map(
      DEPTH      => NANO_I_D_C,
      DEPTH_LOG2 => NANO_I_ADR_W_C,
      WIDTH_BITS => NANO_I_W_C
    )
    port map(
      clk1_i  => clk,
      oe_i    => imem_oe,
      we_i    => imem_we_i,
      addr_i  => imem_addr_mux,
      instr_i => instr_i,
      instr_o => instr_out
    );
  -- Instance of nano_ctrl
  u_nano_ctrl : entity work.nano_ctrl
    port map(
      clk_i                 => clk,
      rst_n_i               => reset_n,
      instr_i               => instr_out,
      cw_o                  => cw,
      wake_i                => wake_i,
      wake_addr_i           => wake_addr(NANO_I_ADR_W_C - 1 downto 0),
      stream_bit_i          => stream_bit_i,
      stream_bit_ready_i    => stream_bit_ready_i,
      stream_bit_ack_o      => stream_bit_ack_o,
      parallel_data_i       => parallel_data_i,
      parallel_data_ready_i => parallel_data_ready_i,
      parallel_data_ack_o   => parallel_data_ack_o,
      memory_read_data_i    => memory_read_data
    );
  -- Instance of dmem
  u_nano_dmem : entity work.nano_dmem
    generic map(
      DEPTH_LOG2 => NANO_D_ADR_W_C,
      WIDTH_BITS => REGISTER_WIDTH,
      FUNC_OUTS  => 1
    )
    port map(
      clk1_i => clk,
      oe_i   => dmem_oe,
      we_i   => dmem_we,
      addr_i => dmem_addr,
      data_i => reg_output_int,
      data_o => memory_read_data,
      func_o => wake_addr
    );

end architecture;
