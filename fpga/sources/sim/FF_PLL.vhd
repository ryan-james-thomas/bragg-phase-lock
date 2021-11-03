library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FF_PLL is
--  Port ( );
end FF_PLL;

architecture Behavioral of FF_PLL is

COMPONENT PLL_Filter
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(39 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC
  );
END COMPONENT;

signal clkext10, clkint10, clk  :   std_logic;
signal aresetn  :   std_logic;
signal PERIOD_EXT   :   time    :=  100 ns;
constant PERIOD_INT :   time    :=  100 ns;
constant DELAY_INT  :   time    :=  0 ns;
--constant PERIOD_EXT :   time    :=  90 ns;
constant DELAY_EXT  :   time    :=  0 ns;
constant PERIOD_125:    time    :=  8 ns;

signal pll_ref_cnt  :   unsigned(15 downto 0);
signal pll_sys_syc  :   std_logic_vector(2 downto 0);
signal pll_sys_cnt  :   unsigned(20 downto 0);
signal pll_sys_val  :   std_logic;

signal ff_sys, ff_ref, ff_rst   :   std_logic;

signal pll_lo, pll_hi   :   std_logic_vector(1 downto 0);

signal pll_combined     :   signed(15 downto 0);
signal pll_filtered     :   std_logic_vector(39 downto 0);
signal pll_o            :   signed(15 downto 0);
signal pll_valid_o      :   std_logic;

begin
--
-- Clocking
--
Proc_Clock_Int_10MHz: process is
begin
    wait for DELAY_INT;
    clkint10 <= '0';
    wait for PERIOD_INT/2;
    clkint10 <= '1';
    wait for PERIOD_INT/2 - DELAY_INT;
end process;

Proc_Clock_Ext_10MHz: process is
begin
    wait for DELAY_EXT;
    clkext10 <= '0';
    wait for PERIOD_EXT/2;
    clkext10 <= '1';
    wait for PERIOD_EXT/2 - DELAY_EXT;
end process;

Proc_Clock_125MHz: process is
begin
    clk <= '0';
    wait for PERIOD_125/2;
    clk <= '1';
    wait for PERIOD_125/2;
end process;

--
-- PLL
--
P1: process(clkext10,aresetn) is
begin
    if aresetn = '0' then
        pll_ref_cnt <= (others => '0');
    elsif rising_edge(clkext10) then
        pll_ref_cnt <= pll_ref_cnt + 1;
    end if;
end process;

P2: process(clk,aresetn) is
begin
    if aresetn = '0' then
        pll_sys_syc <= (others => '0');
        pll_sys_cnt <= (others => '0');
        pll_sys_val <= '1';
    elsif rising_edge(clk) then
        pll_sys_syc <= pll_sys_syc(2 downto 1) & std_logic(pll_ref_cnt(13));
        
        if (pll_sys_syc(2) xor pll_sys_syc(1)) = '1' then
            pll_sys_cnt <= (0 => '1', others => '0');
        elsif pll_sys_cnt(20) = '0' then
            pll_sys_cnt <= pll_sys_cnt + 1;
        end if;
        
--        if (pll_sys_syc(2) xor pll_sys_syc(1)) = '1' then
----            if pll_sys_cnt > to_unsigned(102385,pll_sys_cnt'length) and pll_sys_cnt < to_unsigned(102415,pll_sys_cnt'length) then
----                pll_sys_val <= '1';
----            else
----                pll_sys_val <= '0';
----            end if;
--        elsif pll_sys_cnt(20) = '1' then
--            pll_sys_val <= '0';
--        end if;
    end if;
end process;

P3: process(clkint10,ff_rst,aresetn) is
begin
    if aresetn = '0' or falling_edge(ff_rst) then
        ff_sys <= '0';
    elsif rising_edge(clkint10) then
        ff_sys <= '1';
    end if;
end process;

P4: process(clkext10,ff_rst,aresetn) is
begin
    if aresetn = '0' or falling_edge(ff_rst) then
        ff_ref <= '0';
    elsif rising_edge(clkext10) then
        ff_ref <= '1';
    end if;
end process;

ff_rst <= not(ff_sys and ff_ref);

pll_lo <= (1 => '0', 0 => not(ff_sys) and pll_sys_val);
pll_hi <= (1 => '0', 0 => ff_ref or not(pll_sys_val));

pll_combined <= resize(signed(pll_hi),pll_combined'length) - resize(signed(pll_lo),pll_combined'length);

your_instance_name : PLL_Filter
  PORT MAP (
    aclk                => clk,
    aresetn             => aresetn,
    s_axis_data_tdata   => std_logic_vector(pll_combined),
    s_axis_data_tvalid  => '1',
    s_axis_data_tready  => open,
    m_axis_data_tdata   => pll_filtered,
    m_axis_data_tvalid  => pll_valid_o
  );

pll_o <= resize(shift_right(signed(pll_filtered),14),pll_o'length);

main: process is
begin
    aresetn <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait for 10 us;
    PERIOD_EXT <= 110 ns;
    wait for 10 us;
    PERIOD_EXT <= 90 ns;
    wait;
end process;


end Behavioral;
