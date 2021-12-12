library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity TimingController is
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
end TimingController;

architecture rtl of TimingController is

COMPONENT FIFO_DPG
  PORT (
    clk : IN STD_LOGIC;
    rst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(93 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(93 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

COMPONENT BlockMemoryController is
    port(
        wrclk       :   in  std_logic;
        rdclk       :   in  std_logic;
        aresetn     :   in  std_logic;
        --Write data
        data_i      :   in  t_mem_data_ext;
        valid_i     :   in  std_logic;
        --Read data
        bus_i       :   in  t_mem_bus_master;
        bus_o       :   out t_mem_bus_slave_ext
    );
end COMPONENT;

constant DPG_POW_WIDTH  :   natural :=  CORDIC_WIDTH;
constant DPG_FREQ_WIDTH :   natural :=  PHASE_WIDTH;
constant DPG_AMP_WIDTH  :   natural :=  AMP_MULT_WIDTH;
constant DPG_TIME_WIDTH :   natural :=  28;
constant DPG_FLAG_WIDTH :   natural :=  TC_FLAG_WIDTH;

type t_state_local is (ready,wait_for_delay,waiting,read_first_address);
signal state    :   t_state_local;

type t_write_state_local is (pow,freq,amp,duration);
signal mem_data_i       :   t_mem_data_ext;
signal memCount         :   unsigned(1 downto 0);
signal memState         :   t_write_state_local;
signal valid, start     :   std_logic;

signal wrTrig           :   std_logic;
signal mem_o            :   t_mem_data_ext;

signal delay            :   unsigned(DPG_TIME_WIDTH - 1 downto 0);
signal count            :   unsigned(DPG_TIME_WIDTH downto 0);
signal resetSync, startSync, wrSync        :   std_logic_vector(1 downto 0);

signal bus_i            :   t_mem_bus_master;
signal bus_o            :   t_mem_bus_slave_ext;

signal tc_data          :   t_timing_control;

begin

debug_o(1 downto 0) <=  "00" when memState = pow else 
                        "01" when memState = freq else 
                        "10" when memState = amp else
                        "11" when memState = duration;

debug_o(3 downto 2) <=  "00" when state = ready else
                        "01" when state = read_first_address else
                        "10" when state = wait_for_delay else
                        "11" when state = waiting;
                        
debug_o(15 downto 4) <= std_logic_vector(resize(bus_o.last,12));
debug_o(27 downto 16) <= std_logic_vector(resize(bus_i.addr,12));
debug_o(31 downto 28) <= (others => '0');
--
-- Generate data words for FIFO input
--
--rising_sync(clk,aresetn,valid_i,valid);
MakeFIFOInputs: process(wrclk,aresetn) is
begin
    if aresetn = '0' then
        mem_data_i <= (others => '0');
        memState <= pow;
        wrTrig <= '0';
    elsif rising_edge(wrclk) then
        if reset_i = '1' then
            wrTrig <= '0';
            memState <= pow;
            mem_data_i <= (others => '0');
        elsif valid_i = '1' then
            MemCase: case memState is
                when pow =>
                    mem_data_i(DPG_POW_WIDTH - 1 downto 0) <= std_logic_vector(resize(signed(data_i),DPG_POW_WIDTH));
                    memState <= freq;
                    
                when freq =>
                    mem_data_i(DPG_FREQ_WIDTH + DPG_POW_WIDTH - 1 downto DPG_POW_WIDTH) <= data_i(DPG_FREQ_WIDTH - 1 downto 0);
                    memState <= amp;
                    
                when amp =>
                    mem_data_i(DPG_AMP_WIDTH + DPG_FREQ_WIDTH + DPG_POW_WIDTH - 1 downto DPG_POW_WIDTH + DPG_FREQ_WIDTH) <= data_i(DPG_AMP_WIDTH - 1 downto 0);
                    memState <= duration;
                    
                when duration =>
                    mem_data_i(DPG_FLAG_WIDTH + DPG_TIME_WIDTH + DPG_AMP_WIDTH + DPG_FREQ_WIDTH + DPG_POW_WIDTH - 1 downto DPG_AMP_WIDTH + DPG_FREQ_WIDTH + DPG_POW_WIDTH) <= data_i(DPG_FLAG_WIDTH + DPG_TIME_WIDTH - 1 downto 0);
                    memState <= pow;
                    wrTrig <= '1';
            end case;
        else
            wrTrig <= '0';
        end if;
    end if;
end process;
--
-- Instantiate memory controller.  Reset signal is
-- routed directly to the bus reset signal
--
--bus_i.reset <= reset_i;
DPG_Storage: BlockMemoryController
port map(
    wrclk       =>  wrclk,
    rdclk       =>  rdclk,
    aresetn     =>  aresetn,
    data_i      =>  mem_data_i,
    valid_i     =>  wrTrig,
    bus_i       =>  bus_i,
    bus_o       =>  bus_o
);
--
-- Parses output data
--
tc_data.pow     <= resize(signed(bus_o.data(DPG_POW_WIDTH - 1 downto 0)),t_phase'length);
tc_data.df      <= resize(unsigned(bus_o.data(DPG_FREQ_WIDTH + DPG_POW_WIDTH - 1 downto DPG_POW_WIDTH)),t_dds_phase'length);
tc_data.amp     <= resize(unsigned(bus_o.data(DPG_AMP_WIDTH + DPG_FREQ_WIDTH + DPG_POW_WIDTH - 1 downto DPG_POW_WIDTH + DPG_FREQ_WIDTH)),t_amp_mult'length);
delay           <= resize(unsigned(bus_o.data(DPG_TIME_WIDTH + DPG_AMP_WIDTH + DPG_FREQ_WIDTH + DPG_POW_WIDTH - 1 downto DPG_AMP_WIDTH + DPG_FREQ_WIDTH + DPG_POW_WIDTH)),delay'length);
tc_data.flags   <= bus_o.data(DPG_FLAG_WIDTH + DPG_TIME_WIDTH + DPG_AMP_WIDTH + DPG_FREQ_WIDTH + DPG_POW_WIDTH - 1 downto DPG_TIME_WIDTH + DPG_AMP_WIDTH + DPG_FREQ_WIDTH + DPG_POW_WIDTH);

--
-- Main delay generator
--
signal_sync(rdclk,aresetn,start_i,startSync);
signal_sync(rdclk,aresetn,wrTrig,wrSync);
TimingProc: process(rdclk,aresetn) is
begin
    if aresetn = '0' then
        state <= ready;
        data_o <= INIT_TIMING_CONTROL;
        bus_i <= INIT_MEM_BUS_MASTER;
--        bus_i.addr <= (others => '0');
--        bus_i.trig <= '0';
--        bus_i.status <= idle;
--        bus_i.data <= (others => '0');
        count <= (others => '0');
    elsif rising_edge(rdclk) then
        if reset_i = '1' then
            --
            -- If a reset signal is applied, reset the memory controller
            --
            bus_i.reset <= '1';
            state <= ready;
            data_o <= INIT_TIMING_CONTROL;
            count <= (others => '0');
        else
            --
            -- Otherwise, make sure the mem_bus reset signal is low
            -- and execute the case statement
            --
            bus_i.reset <= '0';
            
            FSM: case (state) is
                when ready =>
                    if wrSync = "01" then
                        --
                        -- When new data is written, re-load the first address so that it
                        -- is always ready for execution
                        --
                        state <= read_first_address;
                        bus_i.addr <= (others => '0');
                        bus_i.trig <= '1';
                    elsif startSync = "01" then
                        --
                        -- When start trigger is received, issue new read request
                        -- and wait for the programmed delay
                        --
                        state <= wait_for_delay;
                        bus_i.addr <= (0 => '1', others => '0');
                        bus_i.trig <= '1';
                        data_o <= (enable => '1', valid => '1', df => tc_data.df, amp => tc_data.amp, pow => tc_data.pow, flags => tc_data.flags);
                    else
                        bus_i.trig <= '0';
                    end if;
                    
                
                when read_first_address =>
                    --
                    -- For for valid signal to be asserted
                    --
                    bus_i.trig <= '0';
                    if bus_o.valid = '1' then
                        count <= "0" & (delay - 3);
                        data_o <= (enable => '0', valid => '0', df => tc_data.df, amp => tc_data.amp, pow => tc_data.pow, flags => tc_data.flags);
                        state <= ready;
                    end if;
                    
                when wait_for_delay =>
                    --
                    -- Wait for the programmed delay
                    --
                    bus_i.trig <= '0';
                    data_o.valid <= '0';
                    if count(count'length - 1) = '0' then
                        count <= count - 1;
                    else
                        state <= waiting;
                    end if;
                    
                when waiting =>
                    if bus_o.status = idle then
                        --
                        -- When new data is ready, parse it according to the op-code
                        --
                        if delay = 0 then
                            --
                            -- A delay of 0 indicates the end-of-instructions
                            --
                            state <= read_first_address;
                            bus_i.addr <= (others => '0');
                            bus_i.trig <= '1';
                        else
                            data_o <= (enable => '1', valid => '1', df => tc_data.df, amp => tc_data.amp, pow => tc_data.pow, flags => tc_data.flags);
                            count <= "0" & (delay - 3);
                            bus_i.addr <= bus_i.addr + 1;
                            bus_i.trig <= '1';
                            state <= wait_for_delay;
                        end if;
                    else
                        --
                        -- If new data is not ready, make sure the trigger is lowered
                        --
                        bus_i.trig <= '0';
                    end if;
            end case;
        end if;
    end if;
end process;


end rtl;