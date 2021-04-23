library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity TimingController_tb is
--  Port ( );
end TimingController_tb;

architecture Behavioral of TimingController_tb is

component TimingController is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        reset       :   in  std_logic;

        data_i      :   in  t_param_reg;
        valid_i     :   in  std_logic;

        start_i     :   in  std_logic;
        data_o      :   out t_timing_control
    );
end component;

constant CLK_T      :   time    :=  10 ns;
signal clk, aresetn :   std_logic;

signal reset    :   std_logic;
signal data_i   :   std_logic_vector(31 downto 0);
signal valid_i,start_i  :   std_logic;
signal data_o   :   t_timing_control;

signal count    :   unsigned(7 downto 0);
signal loadDataEnable   :   std_logic;

type t_data_array is array(natural range <>) of std_logic_vector(31 downto 0);
constant DATA   :   t_data_array(8 downto 0):= (    0   =>  X"00849fa0",
                                                    1   =>  X"00000182",
                                                    2   =>  X"0000000a",
                                                    3   =>  X"003894f2",
                                                    4   =>  X"0012900a",
                                                    5   =>  X"00000005",
                                                    6   =>  X"00849fa0",
                                                    7   =>  X"00000182",
                                                    8   =>  X"00000003");
                                                    
begin

clk_proc: process is
begin
    clk <= '0';
    wait for CLK_T/2;
    clk <= '1';
    wait for CLK_T/2;
end process;

uut: TimingController
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    reset       =>  reset,
    data_i      =>  data_i,
    valid_i     =>  valid_i,
    start_i     =>  start_i,
    data_o      =>  data_o
);

LoadData: process(clk,aresetn) is
begin
    if aresetn = '0' then
        data_i <= (others => '0');
        valid_i <= '0';
        count <= (others => '0');
    elsif rising_edge(clk) then
        if loadDataEnable = '1' and count < DATA'length then
            data_i <= DATA(to_integer(count));
            valid_i <= '1';
            count <= count + 1;
        elsif reset = '1' then
            count <= (others => '0');
        else
            valid_i <= '0';
        end if;
            
    end if;
end process;

main: process
begin
    aresetn <= '0';
    reset <= '0';
    loadDataEnable <= '0';
    start_i <= '0';
    wait for 200 ns;
    wait until clk'event and clk = '1';
    aresetn <= '1';
    loadDataEnable <= '1';
    wait for 200 ns;
    wait until clk'event and clk = '1';
    loadDataEnable <= '0';
    start_i <= '1';
    wait until clk'event and clk = '1';
    start_i <= '0';
    wait for 200 ns;
    wait until clk'event and clk = '1';
    reset <= '1';
    wait until clk'event and clk = '1';
    reset <= '0';
    wait for 200 ns;
    loadDataEnable <= '1';
    wait for 200 ns;
    wait until clk'event and clk = '1';
    loadDataEnable <= '0';
    start_i <= '1';
    wait until clk'event and clk = '1';
    start_i <= '0';
    wait;
end process;

end Behavioral;
