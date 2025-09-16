-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.

use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nano_pkg.all;

entity tb is
end entity tb;

architecture rtl of tb is

    -- Testbench signals
    signal clk                   : std_logic := '0';
    signal clk_en                : std_logic := '1';
    signal reset_n               : std_logic := '0';
    signal reg_output            : std_logic_vector(REGISTER_ADDR_WIDTH ** 2 - 1 downto 0);
    signal saved_ack             : std_logic;
    signal saved_output          : std_logic_vector(2 ** SIMPLE_SHIFT_ADDR_WIDTH - 1 downto 0);
    signal sleep                 : std_logic;
    signal wake_i                : std_logic := '0';
    signal stream_bit_i          : std_logic := '0';
    signal stream_bit_ready_i    : std_logic := '0';
    signal stream_bit_ack_o      : std_logic;
    signal parallel_data_i       : std_logic_vector(2 ** REGISTER_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal parallel_data_ready_i : std_logic := '0';
    signal parallel_data_ack_o   : std_logic;
    signal imem_we_i             : std_logic := '0';
    signal imem_addr_i           : std_logic_vector(NANO_I_ADR_W_C - 1 downto 0);
    signal instr_i               : std_logic_vector(2*NANO_I_W_C - 1 downto 0);
    
    -- Output checking signals
    signal checkval              : std_logic;
    signal checkack              : std_logic;

    -- Clock period constant
    constant clk_period : time := 1 ns;

begin

    -------------------------------------------------------------------------
    -- DUT instantiation
    -------------------------------------------------------------------------
    top_module : entity work.nano_top
        port map(
            clk                   => clk,
            reset_n               => reset_n,
            reg_output            => reg_output,
            saved_ack             => saved_ack,
            saved_output          => saved_output,
            sleep_o               => sleep,
            -- New signals
            wake_i                => wake_i,
            imem_we_i             => imem_we_i,
            imem_addr_i           => imem_addr_i,
            instr_i               => instr_i,
            stream_bit_i          => stream_bit_i,
            stream_bit_ready_i    => stream_bit_ready_i,
            stream_bit_ack_o      => stream_bit_ack_o,
            parallel_data_i       => parallel_data_i,
            parallel_data_ready_i => parallel_data_ready_i,
            parallel_data_ack_o   => parallel_data_ack_o
        );
    clk_process : process
    begin
        while clk_en = '1' loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
        wait;
    end process;
    
    outcheck : process
        file f     : text open read_mode is "out.mem";
        variable l : line;
        variable v : bit;
        variable g : boolean;
    begin
        -- Read in output check values
        while not endfile(f) loop
            readline(f, l);
            g := true;
            while g loop
                read(l, v, g);
                if g then
                    checkval <= to_stdulogic(v);
                    wait until checkack'event and checkack = '1';
                end if;
            end loop; --g
        end loop;
        wait until checkack'event and checkack = '1';
        report "[FAILURE] No more out.mem check values, simulation fails." severity failure;
        wait;
    end process;
    
    stimulus : process
        file f     : text open read_mode is "code.mem";
        variable l : line;
        variable i : natural;
        variable v : bit_vector(NANO_I_W_C-1 downto 0);
        variable g : boolean;
    begin
        clk_en  <= '1';
        reset_n <= '0';
        imem_addr_i <= (others => '0');
        imem_we_i   <= '1';
        checkack <= '0';
        
        -- Read in instruction memory image
        i := NANO_I_W_C;
        while not endfile(f) loop
            readline(f, l);
            g := true;
            while g loop
                read(l, v, g);
                if g then
                    if i = (instr_i'length-NANO_I_W_C) then
                        instr_i <= (others => '0');
                    end if;
                    instr_i(i+NANO_I_W_C-1 downto i) <= to_stdlogicvector(v);
                    if i = 0 then
                        wait for clk_period;
                        imem_addr_i <= std_logic_vector(unsigned(imem_addr_i) + (instr_i'length/NANO_I_W_C));
                    end if;
                    i := (i + NANO_I_W_C) mod instr_i'length;
                end if;
            end loop; --g
        end loop;
        wait for clk_period;
        imem_we_i <= '0';
        wait for clk_period;
        
        -- Program execution (until SLEEP instruction)
        reset_n <= '1'; -- Deassert reset
        while sleep = '0' loop
            if saved_ack = '1' then
                report "[OUT] " & std_logic'image(saved_output(0)) & ", [CHECKVAL] " & std_logic'image(checkval);
                assert saved_output(0) = checkval;
                checkack <= '1';
            end if;
            wait for clk_period;
            checkack <= '0';
        end loop;
        
        -- End simulation by stopping clock events
        clk_en  <= '0';
        report "[SLEEP] Bye...";
        wait;
    end process;
end architecture rtl;
