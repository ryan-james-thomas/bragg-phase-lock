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

        bus_m_i     :   in  t_mem_bus_master;

        start_i     :   in  std_logic;
        data_o      :   out t_timing_control
    );
end TimingController;

architecture rtl of TimingController is

component BlockMemHandlerRAM is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        bus_m_wr    :   in  t_mem_bus_master;
        bus_m_rd    :   in  t_mem_bus_master;
        bus_s       :   out t_mem_bus_slave
    );
end component;

signal mem_bus  :   t_mem_bus   :=  INIT_MEM_BUS;

type t_state_local is (idle,preload_reading,preload_waiting,reading,finishing);
signal state    :   t_status_local  :=  idle;

begin

--
-- Store timing data in a block RAM
--
StoreTimingData: BlockMemHandlerRAM
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    bus_m_wr    =>  bus_m_i,
    bus_m_rd    =>  mem_bus.m,
    bus_s       =>  mem_bus.s
);

--
-- Main delay generator
--
TimingProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        state <= idle;
        data_o <= INIT_TIMING_CONTROL;
        mem_bus.m <= INIT_MEM_BUS_MASTER;

    elsif rising_edge(clk) then
        FSM: case (state) is
            --
            -- Wait for either memory bus trigger or start trigger.
            -- Memory bus trigger initiates pre-loading of first data words
            -- Start trigger starts going through stored data
            --
            when idle =>
                if bus_m_i.trig = '1' then
                    state <= preload_reading;
                elsif start_i = '1' then
                    data_o.valid <= '1';
                    data_o.enable <= '1';
                    mem_bus.m.trig <= '1';
                    mem_bus.m.addr <= mem_bus.m.addr + 1;
                    state <= reading;
                end if;

            when reading =>
                mem_bus.m.trig <= '0';
                data_o.valid <= '0';
                if mem_bus.s.valid = '1' then
                    data_o.df <= mem_bus.s.data(data_o.df'length-1 downto 0);
                    data_o.pow <= mem_bus.s.data(data_o.df'length+data_o.pow'length-1 downto data_o.df'length);
                    if mem_bus.m.addr = mem_bus.s.last then
                        state <= finishing;
                    else
                        state <= idle;
                    end if;
                end if;

                

            when preload_reading =>
                mem_bus.m.trig <= '1';
                mem_bus.m.addr <= (others => '0');
                state <= preload_waiting;

            when preload_waiting =>
                mem_bus.m.trig <= '0';
                if mem_bus.s.valid = '1' then
                    data_o.df <= mem_bus.s.data(data_o.df'length-1 downto 0);
                    data_o.pow <= mem_bus.s.data(data_o.df'length+data_o.pow'length-1 downto data_o.df'length);
                    state <= idle;
                end if;
                

        end case;
    end if;
end process;


end rtl;