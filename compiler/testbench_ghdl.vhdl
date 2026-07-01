-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.nano_pkg.all;

entity tb is
end entity tb;

architecture rtl of tb is

    signal clk                   : std_logic := '0';
    signal clk_en                : std_logic := '1';
    signal reset_n               : std_logic := '0';
    signal reg_output            : std_logic_vector(REGISTER_WIDTH - 1 downto 0);
    signal saved_output          : std_logic_vector(2 ** SIMPLE_SHIFT_ADDR_WIDTH - 1 downto 0);
    signal wake_i                : std_logic := '1';
    signal wake_ack_o            : std_logic;
    signal stream_bit_i          : std_logic := '0';
    signal stream_bit_ready_i    : std_logic := '0';
    signal stream_bit_ack_o      : std_logic;
    signal parallel_data_i       : std_logic_vector(REGISTER_WIDTH - 1 downto 0) := (others => '0');
    signal parallel_data_ready_i : std_logic := '0';
    signal parallel_data_ack_o   : std_logic;
    signal imem_we_i             : std_logic := '0';
    signal imem_addr_i           : std_logic_vector(NANO_I_ADR_W_C - 1 downto 0);
    signal instr_i               : std_logic_vector(2*NANO_I_W_C - 1 downto 0);

    constant clk_period : time := 10 ns;

begin
     top_module : entity work.nano_top
        port map(
            clk                   => clk,
            reset_n               => reset_n,
            reg_output            => reg_output,
            saved_output          => saved_output,
            wake_i                => wake_i,
            wake_ack_o            => wake_ack_o,
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

    stimulus : process
        file f : text open read_mode is "code_ghdl.mem";
        file out_file  : text open write_mode is "outputs_ghdl.txt";

        variable l     : line;
        variable l_out : line;
        variable i     : natural;
        variable v     : bit_vector(NANO_I_W_C-1 downto 0);
        variable g     : boolean;
        variable count : integer := 0;
    begin
	report "STIMULUS STARTED";
        clk_en  <= '1';
        reset_n <= '0';
        imem_addr_i <= (others => '0');
        imem_we_i   <= '1';

        -- load memory
        i := NANO_I_W_C;

        while not endfile(f) loop
            readline(f, l);
            g := true;
            while g loop
                read(l, v, g);
                if g then
                    if i = (instr_i'length - NANO_I_W_C) then
                        instr_i <= (others => '0');
                    end if;

                    instr_i(i + NANO_I_W_C - 1 downto i) <= to_stdlogicvector(v);
                    if i = 0 then
                        wait for clk_period;
                        imem_addr_i <= std_logic_vector(unsigned(imem_addr_i) + (instr_i'length / NANO_I_W_C));
                    end if;

                    i := (i + NANO_I_W_C) mod instr_i'length;
                end if;
            end loop;
        end loop;

        wait for clk_period;
        imem_we_i <= '0';
        wait for clk_period;

        reset_n <= '1';

        -- run for fixed time
        for j in 0 to 1000000 loop
            if wake_ack_o = '1' then
            	report "EOC REACHED";
                write(l_out, saved_output);
                writeline(out_file, l_out);
                count := count + 1;

        	if count = 11 then
            		exit;
        	end if;
            end if;

            wait for clk_period;

        end loop;

        clk_en <= '0';
        wait;

    end process;

end architecture rtl;
