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

entity nano_ctrl is
  port (
    clk_i                 : in  std_logic;
    rst_n_i               : in  std_logic;
    instr_i               : in  std_logic_vector(NANO_I_W_C - 1 downto 0);
    wake_i                : in  std_logic;
    wake_addr_i           : in  std_logic_vector(NANO_I_ADR_W_C - 1 downto 0);
    stream_bit_i          : in  std_logic;
    stream_bit_ready_i    : in  std_logic;
    stream_bit_ack_o      : out std_logic;
    parallel_data_i       : in  std_logic_vector(REGISTER_WIDTH - 1 downto 0);
    parallel_data_ready_i : in  std_logic;
    parallel_data_ack_o   : out std_logic;
    memory_read_data_i    : in  std_logic_vector(REGISTER_WIDTH - 1 downto 0);
    sleep_o               : out std_logic;
    cw_o                  : out std_logic_vector(CW_WIDTH - 1 downto 0) -- Datapath Control Word
  );
end entity nano_ctrl;
architecture edge of nano_ctrl is

  -- Control Registers
  signal pc                : std_logic_vector(NANO_I_ADR_W_C - 1 downto 0); -- Program Counter
  signal ir                : std_logic_vector(NANO_I_W_C - 1 downto 0);     -- Instruction Register
  signal lut_size_flag     : std_logic;                                     -- Determines size of LUT used
  signal operands          : std_logic_vector(OPERANDS_WIDTH - 1 downto 0); -- To store operands 
  signal saved_operands    : std_logic_vector(OPERANDS_WIDTH - 1 downto 0); -- To store operands for repeat lut 
  signal saved_stack_op    : std_logic_vector(STACK_I_W_C - 1 downto 0);    -- To store stack operation for repeat lut 
  signal counter           : std_logic_vector(COUNTER_WIDTH - 1 downto 0);  -- counts the cycles since fetching the intructions
  signal first_instr_flag  : std_logic;                                     -- indicates that this is the first cycle after a reset
  signal is_sleeping       : std_logic;                                     -- indicates processor is sleeping now
  signal stream_bit_ack    : std_logic;                                     -- acknowledges streambit was read
  signal parallel_data_ack : std_logic;                                     -- acknowledges parallel data was read
  signal lut_truth_table   : std_logic_vector(OPERANDS_WIDTH - 1 downto 0);
  -- Control State
  type ctrl_state_t is (FETCH, REGFETCH, EXECUTE);
  signal state : ctrl_state_t;
  -- Control Logic
  signal cw : std_logic_vector(CW_WIDTH - 1 downto 0);
begin
  -- Sequential FSM: Control State
  seq : process (clk_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      -- Reset necessary registers and state
      pc               <= (others => '0');
      first_instr_flag <= '1';
      state            <= FETCH;
      is_sleeping      <= '0';
    elsif rising_edge(clk_i) then
      case state is
        --
        when FETCH =>
          if is_sleeping = '1' then
            pc               <= wake_addr_i;
            state            <= FETCH;
            first_instr_flag <= '1';
            is_sleeping      <= not wake_i;
          else
            pc <= std_logic_vector(unsigned(pc) + 1);
            if first_instr_flag = '1' then -- this is the first cycle we only neeed to delay the whole process a cycle to wait for instruction to be read
              state            <= FETCH;
              first_instr_flag <= '0';
            else
              ir            <= instr_i(3 downto 0);
              lut_size_flag <= instr_i(3);
              case instr_i(3 downto 0) is --current instruction
                when OP_LUT_2 | OP_LUT_3 | OP_LUT_4 | OP_LD | OP_ST | OP_MEM_LD | OP_MEM_ST =>
                  state       <= REGFETCH;
                when OP_SLEEP =>
                  state       <= FETCH;
                  is_sleeping <= '1';
                when OP_NOP =>
                  state       <= FETCH;
                when others =>
                  state       <= EXECUTE;
              end case;
              counter <= (0 => '1', others => '0');
            end if;
          end if;
        when REGFETCH =>
          pc      <= std_logic_vector(unsigned(pc) + 1);
          counter <= counter(counter'length-2 downto 0) & '0';
          for i in 0 to COUNTER_WIDTH-1 loop
            if counter(i) = '1' then
              operands(4*i+3 downto 4*i+0) <= instr_i;
            end if;
          end loop;
          case ir is
            when OP_LUT_3 =>
              if (counter(1) = '1') then
                state <= EXECUTE;
              end if;
            when OP_LUT_4 =>
              if (counter(3) = '1') then
                state <= EXECUTE;
              end if;
            when OP_LUT_2 =>
              state <= EXECUTE;
            when OP_LD | OP_ST =>
              if counter((TEMP_REG_ADDR_WIDTH / NANO_I_W_C) - 1) = '1' then
                state <= EXECUTE;
              end if;
            when OP_MEM_LD | OP_MEM_ST =>
              if counter((NANO_D_ADR_W_C / NANO_I_W_C) - 1) = '1' then
                state <= EXECUTE;
              end if;
            when others =>
          end case;
        when EXECUTE =>
          case ir is
            when OP_LUT_3 | OP_LUT_2 | OP_LUT_4 =>
              state          <= FETCH;
              saved_operands <= cw(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA);
              saved_stack_op <= cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP);
            when OP_LUTI_0 | OP_LUTI_1 | OP_LD | OP_ST | OP_MEM_LD | OP_MEM_ST | OP_LUTR | OP_SAVE =>
              state          <= FETCH;
            when OP_LOAD_PLL | OP_LOAD_STR =>
              if (stream_bit_ack = '1' or parallel_data_ack = '1') then
                state <= FETCH;
              end if;
            when others =>
          end case;
      end case;
    end if;
  end process seq;

  comb : process (state, pc, operands, ir, lut_size_flag, memory_read_data_i, stream_bit_i, stream_bit_ready_i, parallel_data_i, parallel_data_ready_i, wake_i)
  begin
    cw <= (others => '-');
    cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP) <= OP_STACK_NOP;
    cw(CW_IMEM_WE)     <= '0';
    cw(CW_IMEM_OE)     <= '0';
    cw(CW_IMEM_ADDR + NANO_I_ADR_W_C - 1 downto CW_IMEM_ADDR) <= pc;
    cw(CW_DMEM_OE)     <= '0';
    cw(CW_DMEM_WE)     <= '0';
    cw(CW_SAVE_TOP)    <= '0';
    stream_bit_ack     <= '0';
    parallel_data_ack  <= '0';
    cw(CW_TEMP_REG_RW) <= '0';
    cw(CW_TEMP_REG_EN) <= '0';

    case state is
      when FETCH =>
        cw(CW_IMEM_OE) <= '1';
      when REGFETCH =>
        cw(CW_IMEM_OE) <= '1';
      when EXECUTE =>
        case ir is
          when OP_LUTI_0 | OP_LUTI_1 =>
            cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)         <= OP_STACK_PUSH;
            cw(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA) <= (others => lut_size_flag); --load data of lut with imeediate value
          when OP_LUT_4 =>
            cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)         <= OP_STACK_LUT_4;
            cw(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA) <= operands(2 ** LUT_ADDR_WIDTH - 1 downto 0);
          when OP_LUT_3 =>
            cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)         <= OP_STACK_LUT_3;
            cw(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA) <= operands((2 ** LUT_ADDR_WIDTH) / 2 - 1 downto 0) & operands((2 ** LUT_ADDR_WIDTH) / 2 - 1 downto 0);
          when OP_LUT_2 =>
            cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)         <= OP_STACK_LUT_2;
            cw(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA) <= operands((2 ** LUT_ADDR_WIDTH) / 4 - 1 downto 0) & operands((2 ** LUT_ADDR_WIDTH) / 4 - 1 downto 0) &
                                                                            operands((2 ** LUT_ADDR_WIDTH) / 4 - 1 downto 0) & operands((2 ** LUT_ADDR_WIDTH) / 4 - 1 downto 0);
          when OP_LUTR =>
            cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)         <= saved_stack_op;
            cw(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA) <= saved_operands;
          when OP_ST =>
            cw(CW_TEMP_REG_RW) <= '1';
            cw(CW_TEMP_REG_EN) <= '1';
            cw(CW_TEMP_REG_ADDR + TEMP_REG_ADDR_WIDTH - 1 downto CW_TEMP_REG_ADDR) <= operands(TEMP_REG_ADDR_WIDTH - 1 downto 0);
          when OP_LD =>
            cw(CW_TEMP_REG_RW) <= '0';
            cw(CW_TEMP_REG_EN) <= '1';
            cw(CW_TEMP_REG_ADDR + TEMP_REG_ADDR_WIDTH - 1 downto CW_TEMP_REG_ADDR) <= operands(TEMP_REG_ADDR_WIDTH - 1 downto 0);
            cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)                   <= OP_STACK_PUSH;
          when OP_MEM_LD | OP_MEM_ST =>
            if lut_size_flag = LOAD then
              cw(CW_DMEM_ADDR + NANO_D_ADR_W_C - 1 downto CW_DMEM_ADDR)   <= operands(NANO_D_ADR_W_C - 1 downto 0);
              cw(CW_DMEM_OE) <= '1';
              cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)        <= OP_STACK_INIT;
              cw(CW_LOADI_DATA + REGISTER_WIDTH - 1 downto CW_LOADI_DATA) <= memory_read_data_i;
            else
              cw(CW_DMEM_ADDR + NANO_D_ADR_W_C - 1 downto CW_DMEM_ADDR)   <= operands(NANO_D_ADR_W_C - 1 downto 0);
              cw(CW_DMEM_WE) <= '1';
            end if;
          when OP_LOAD_PLL | OP_LOAD_STR =>
            if lut_size_flag = STREAM_LOAD and stream_bit_ready_i = '1' then
              cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)         <= OP_STACK_PUSH;
              cw(CW_LUT_DATA + 2 ** LUT_ADDR_WIDTH - 1 downto CW_LUT_DATA) <= (others => stream_bit_i); --load data of lut with stream input
              stream_bit_ack <= '1';
            elsif lut_size_flag = PARALLEL_LOAD and parallel_data_ready_i = '1' then
              cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP)        <= OP_STACK_INIT;
              cw(CW_LOADI_DATA + REGISTER_WIDTH - 1 downto CW_LOADI_DATA) <= parallel_data_i;
              parallel_data_ack <= '1';
            end if;
          when OP_SAVE =>
            cw(CW_STACK_OP + STACK_I_W_C - 1 downto CW_STACK_OP) <= OP_STACK_POP;
            cw(CW_SAVE_TOP) <= '1'; 
          when others =>
        end case;
    end case;
  end process comb;
  sleep_o             <= is_sleeping;
  cw_o                <= cw;
  stream_bit_ack_o    <= stream_bit_ack;
  parallel_data_ack_o <= parallel_data_ack;
end architecture;

