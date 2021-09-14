library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity clockSync_tb is
--  Port ( );
end clockSync_tb;

architecture Behavioral of clockSync_tb is

signal sysclk, adcclk, aresetn :   std_logic;
constant sysclkperiod  :   time    :=  10 ns;
constant adcclkperiod  :   time    :=  10.1 ns;

signal trig :   std_logic;
signal trig_o   :   std_logic_vector(1 downto 0);

procedure signal_sync(
    signal clk_i   :   in       std_logic;
    signal aresetn :   in       std_logic;
    signal trig_i  :   in       std_logic;
    signal trig_o  :   inout    std_logic_vector(1 downto 0)) is
begin
    if aresetn = '0' then
        trig_o <= (others => trig_i);
    elsif rising_edge(clk_i) then
        trig_o <= trig_o(0) & trig_i;
    end if;
end signal_sync;    

begin

sys_clk_proc: process is
begin
    sysclk <= '0';
    wait for sysclkperiod;
    sysclk <= '1';
    wait for sysclkperiod;
end process;

adc_clk_proc: process is
begin
    adcclk <= '0';
    wait for adcclkperiod;
    adcclk <= '1';
    wait for adcclkperiod;
end process;

signal_sync(adcclk,aresetn,trig,trig_o);

main: process is
begin
    aresetn <= '0';
    trig <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(sysclk);
    trig <= '1';
    wait until rising_edge(sysclk);
    trig <= '0';
    wait;
end process;

end Behavioral;
