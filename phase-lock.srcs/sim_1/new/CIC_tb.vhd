library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity CIC_tb is
--  Port ( );
end CIC_tb;

architecture Behavioral of CIC_tb is

COMPONENT CIC_Decimate
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tready : OUT STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC
  );
END COMPONENT;

constant CLK_T      :   time    :=  10 ns;
signal clk, aresetn :   std_logic;

signal config_tdata :   std_logic_vector(15 downto 0);
signal config_tvalid:   std_logic;
signal config_tready:   std_logic;

signal tdata        :   std_logic_vector(15 downto 0);
signal tvalid       :   std_logic;
signal tready       :   std_logic;


signal tdata_o      :   std_logic_vector(47 downto 0);
signal tvalid_o     :   std_logic;

signal shift_o      :   signed(15 downto 0);

begin

uut: CIC_Decimate
port map(
    aclk                    => clk,
    aresetn                 => aresetn,
    s_axis_config_tdata     => config_tdata,
    s_axis_config_tvalid    => config_tvalid,
    s_axis_config_tready    => config_tready,
    s_axis_data_tdata       => tdata,
    s_axis_data_tvalid      => tvalid,
    s_axis_data_tready      => tready,
    m_axis_data_tdata       => tdata_o,
    m_axis_data_tvalid      => tvalid_o
);

shift_o <= resize(shift_right(signed(tdata_o),24),shift_o'length);

clk_proc: process is
begin
    clk <= '0';
    wait for CLK_T/2;
    clk <= '1';
    wait for CLK_T/2;
end process;

--test_data: process(clk,aresetn) is
--begin
--    if aresetn = '0' then
--        adcData_i <= (others => '0');
--    elsif rising_edge(clk) then
--        adcData_i <= adcData_i + to_signed(1,adcData_i'length);
--    end if;    
--end process;


main_proc: process
begin
    aresetn <= '0';
    config_tdata <= std_logic_vector(to_unsigned(256,config_tdata'length));
    config_tvalid <= '0';
    tdata <= std_logic_vector(to_signed(10,tdata'length));
    tvalid <= '0';
    wait for 200 ns;
    aresetn <= '1';
    wait until clk'event and clk = '1';
    config_tvalid <= '1';
    wait until clk'event and clk = '1';
--    config_tvalid <= '0';
    wait for 100 ns;
    wait until clk'event and clk = '1';
    tvalid <= '1';
    wait;
end process;

end Behavioral;
