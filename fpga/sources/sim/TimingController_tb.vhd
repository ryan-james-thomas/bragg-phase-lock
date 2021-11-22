library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;
use work.DataPackage.all;

entity TimingController_tb is
--  Port ( );
end TimingController_tb;

architecture Behavioral of TimingController_tb is

component TimingController is
    port(
        wrclk       :   in  std_logic;
        rdclk       :   in  std_logic;
        aresetn     :   in  std_logic;
        reset_i     :   in  std_logic;

        data_i      :   in  t_param_reg;
        valid_i     :   in  std_logic;

        start_i     :   in  std_logic;
        debug_o     :   out std_logic_vector(31 downto 0);
        data_o      :   out t_timing_control
    );
end component;

constant WR_PERIOD          :   time    :=  8 ns;
constant RD_PERIOD          :   time    :=  4 ns;
signal wrclk, rdclk, aresetn     :   std_logic;

signal reset    :   std_logic;
signal data_i   :   std_logic_vector(31 downto 0);
signal valid_i,start_i  :   std_logic;
signal data_o   :   t_timing_control;

signal count            :   unsigned(31 downto 0);
signal loadDataEnable   :   std_logic;
signal debug_o          :   std_logic_vector(31 downto 0);

type t_state_local is (ready,sending,waiting);
signal state    :   t_state_local;

--type t_data_array is array(natural range <>) of std_logic_vector(31 downto 0);
--constant DATA   :   t_data_array(15 downto 0):= (    0   =>  std_logic_vector(to_signed(500,32)),
--                                                    1   =>  X"00000182",
--                                                    2   =>  X"000000ff",
--                                                    3   =>  X"1000000a",
--                                                    4   =>  std_logic_vector(to_signed(-500,32)),
--                                                    5   =>  X"00000582",
--                                                    6   =>  X"00000002",
--                                                    7   =>  X"10000010",
--                                                    8   =>  std_logic_vector(to_signed(1500,32)),
--                                                    9   =>  X"000fb829",
--                                                    10  =>  X"000000f0",
--                                                    11  =>  X"1000000e",
--                                                    12  =>  std_logic_vector(to_signed(1500,32)),
--                                                    13  =>  X"000fb829",
--                                                    14  =>  X"000000f0",
--                                                    15  =>  X"10000000");
                                                    
begin

wr_clk_proc: process is
begin
    wrclk <= '0';
    wait for WR_PERIOD/2;
    wrclk <= '1';
    wait for WR_PERIOD/2;
end process;

rd_clk_proc: process is
begin
    rdclk <= '0';
    wait for RD_PERIOD/2;
    rdclk <= '1';
    wait for RD_PERIOD/2;
end process;

uut: TimingController
port map(
    wrclk       =>  wrclk,
    rdclk       =>  rdclk,
    aresetn     =>  aresetn,
    reset_i     =>  reset,
    data_i      =>  data_i,
    valid_i     =>  valid_i,
    start_i     =>  start_i,
    debug_o     =>  debug_o,
    data_o      =>  data_o
);

LoadData: process(wrclk,aresetn) is
begin
    if aresetn = '0' then
        data_i <= (others => '0');
        valid_i <= '0';
        count <= (others => '0');
        state <= ready;
    elsif rising_edge(wrclk) then
        LoadFSM: case state is
            when ready =>
                if loadDataEnable = '1' then
                    count <= (others => '0');
                    state <= sending;
                end if;
                
            when sending =>
                data_i <= DATA(to_integer(count));
                valid_i <= '1';
                count <= count + 1;
                state <= waiting;
                
            when waiting =>
                valid_i <= '0';
                if count < DATA'length then
                    state <= sending;
                else
                    state <= ready;
                end if;
                
        end case;
    end if;
end process;

main: process
begin
    aresetn <= '0';
    reset <= '0';
    loadDataEnable <= '0';
    start_i <= '0';
    wait for 200 ns;
    wait until rising_edge(wrclk);
    aresetn <= '1';
    loadDataEnable <= '1';
    wait until rising_edge(wrclk);
    loadDataEnable <= '0';
    wait until state = ready;
    wait for 500 ns;
    wait until rising_edge(wrclk);
    start_i <= '1';
    wait until rising_edge(wrclk);
    start_i <= '0';
--    wait until data_o.enable = '0';
--    wait for 200 ns;
--    wait until rising_edge(clk);
--    start_i <= '1';
--    wait until rising_edge(clk);
--    start_i <= '0';
--    wait until data_o.enable = '0';
--    wait until rising_edge(clk);
--    reset <= '1';
--    wait until rising_edge(clk);
--    reset <= '0';
--    wait for 100 ns;
--    loadDataEnable <= '1';
--    wait until rising_edge(clk);
--    loadDataEnable <= '0';
--    wait for 1000 ns;
--    wait until rising_edge(clk);
--    start_i <= '1';
--    wait until rising_edge(clk);
--    start_i <= '0';
    wait;
end process;

end Behavioral;
