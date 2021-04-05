library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity TimingController is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;

        valid_i     :   in  std_logic;
        data_i      :   in  std_logic_vector(DATA_WIDTH-1 downto 0);

        start_i     :   in  std_logic;
        data_o      :   out t_timing_control
    );
end TimingController;

architecture rtl of TimingController is

component BlockMemHandler is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        data_i      :   in  std_logic_vector;
        valid_i     :   in  std_logic;
        
        bus_m       :   in  t_mem_bus_master;
        bus_s       :   out t_mem_bus_slave
    );
end component;

signal mem_bus  :   t_mem_bus   :=  INIT_MEM_BUS;

type t_state_local is (idle,preload,reading,executing,outputting);
signal state    :   t_status_local  :=  idle;

begin



StoreTimingData: BlockMemHandler
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    data_i      =>  data_i,
    valid_i     =>  valid_i,
    bus_m       =>  bus_m,
    bus_s       =>  bus_s
);


TimingProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        state <= idle;
        data_o <= INIT_TIMING_CONTROL;
        bus_m.m <= INIT_MEM_BUS_MASTER;

    elsif rising_edge(clk) then
        FSM: case (state) is
            when idle =>
                if valid_i = '1' then
                    state <= preload;
                elsif start_i = '1' then
                    state <= outputting;
                end if;

            when preload =>
                mem_bus.m.trig <= '1';
                

        end case;
    end if;
end process;


end rtl;