library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity Simple_FIFO_tb is
--  Port ( );
end Simple_FIFO_tb;

architecture Behavioral of Simple_FIFO_tb is

component Simple_FIFO is
    port (
        wr_clk  :   in  std_logic;
        rd_clk  :   in  std_logic;
        aresetn :   in  std_logic;
        
        data_i  :   in  std_logic_vector;
        data_o  :   out std_logic_vector
    );
end component;

constant WR_CLK_T : time    :=  10.0 ns;
constant RD_CLK_T : time    :=  10.1 ns;
   

signal wr_clk, rd_clk, aresetn  :   std_logic   :=  '0';
signal data_i, data_o   :   std_logic_vector(13 downto 0)   :=  (others => '0');
signal tst_ptr, tst2  :   unsigned(1 downto 0)    :=  (others => '0');

begin

wr_clk_proc: process is
begin
    wr_clk <= '0';
    wait for WR_CLK_T/2;
    wr_clk <= '1';
    wait for WR_CLK_T/2;
end process;

rd_clk_proc: process is
begin
    rd_clk <= '0';
    wait for RD_CLK_T/2;
    rd_clk <= '1';
    wait for RD_CLK_T/2;
end process;

uut: Simple_FIFO
port map(
    wr_clk  =>  wr_clk,
    rd_clk  =>  rd_clk,
    aresetn =>  aresetn,
    data_i  =>  data_i,
    data_o  =>  data_o
);

wr_proc: process(wr_clk,aresetn) is
begin
    if aresetn = '0' then
        data_i <= (others => '0');
--        tst_ptr <= (others => '0');
--        tst2 <= (others => '0');
    elsif rising_edge(wr_clk) then
        data_i <= data_i + 1;
--        tst_ptr <= tst_ptr + 1;
--        tst2 <= tst2 + "01";
    end if;
end process;


main_proc: process
begin
    aresetn <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait;
end process;


end Behavioral;
