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
        reset_i     :   in  std_logic;

        data_i      :   in  t_param_reg;
        valid_i     :   in  std_logic;

        start_i     :   in  std_logic;
        debug_o     :   out std_logic_vector(7 downto 0);
        data_o      :   out t_timing_control
    );
end TimingController;

architecture rtl of TimingController is

COMPONENT FIFO_DPG
  PORT (
    clk : IN STD_LOGIC;
    rst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(77 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(77 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

constant FIFO_POW_WIDTH :   natural :=  CORDIC_WIDTH;
constant FIFO_FREQ_WIDTH:   natural :=  PHASE_WIDTH;
constant FIFO_TIME_WIDTH:   natural :=  27;

type t_state_local is (wait_for_trigger,waiting);
signal state    :   t_state_local  :=  wait_for_trigger;

subtype t_fifo_local is std_logic_vector(77 downto 0);
type t_fifo_state_local is (pow,freq,duration);
signal fifo_i   :   t_fifo_local;
signal fifoCount:   unsigned(1 downto 0);
signal fifoState:   t_fifo_state_local;
signal valid    :   std_logic;

signal empty, full   :   std_logic;
signal wrTrig, rdTrig       :   std_logic;
signal fifo_o   :   t_fifo_local;

signal delay, delayCount    :   unsigned(FIFO_TIME_WIDTH downto 0);
signal enabled  :   std_logic;
signal reset    :   std_logic;
begin

debug_o(1 downto 0) <= "00" when fifoState = pow else "01" when fifoState = freq else "10" when fifoState = duration;
debug_o(2) <= '0' when state = wait_for_trigger else '1';
debug_o(3) <= enabled;

--
-- Generate data words for FIFO input
--
rising_sync(clk,aresetn,valid_i,valid);
MakeFIFOInputs: process(clk,aresetn) is
begin
    if aresetn = '0' then
        fifo_i <= (others => '0');
        fifoState <= pow;
        wrTrig <= '0';
        reset <= '1';
    elsif rising_edge(clk) then
        if reset_i = '1' then
            reset <= '1';
            wrTrig <= '0';
            fifoState <= pow;
            fifo_i <= (others => '0');
        elsif valid = '1' then
            if fifoState = pow then
                fifo_i(FIFO_POW_WIDTH - 1 downto 0) <= std_logic_vector(resize(signed(data_i),FIFO_POW_WIDTH));
                fifoState <= freq;
                wrTrig <= '0';
            elsif fifoState = freq then
                fifo_i(FIFO_FREQ_WIDTH + FIFO_POW_WIDTH - 1 downto FIFO_POW_WIDTH) <= data_i(FIFO_FREQ_WIDTH - 1 downto 0);
                fifoState <= duration;
                wrTrig <= '0';
            elsif fifoState = duration then
                fifo_i(fifo_i'length - 1 downto FIFO_FREQ_WIDTH + FIFO_POW_WIDTH) <= data_i(FIFO_TIME_WIDTH - 1 downto 0);
                fifoState <= pow;
                wrTrig <= '1';
            end if;
        else
            wrTrig <= '0';
            reset <= '0';
        end if;
    end if;
end process;

DPG_Storage: FIFO_DPG
port map(
    clk     =>  clk,
    rst     =>  reset,
    din     =>  fifo_i,
    wr_en   =>  wrTrig,
    rd_en   =>  rdTrig,
    empty   =>  empty,
    full    =>  full,
    dout    =>  fifo_o
);

--
-- Main delay generator
--
TimingProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        state <= wait_for_trigger;
        data_o <= INIT_TIMING_CONTROL;
        rdTrig <= '0';
        enabled <= '0';
        delay <= (others => '0');
        
    elsif rising_edge(clk) then
        if reset = '1' then
            state <= wait_for_trigger;
            enabled <= '0';
            data_o <= INIT_TIMING_CONTROL;
            rdTrig <= '0';
            delay <= (others => '0');
        else
            FSM: case (state) is
                --
                -- Wait for start trigger
                --
                when wait_for_trigger =>
                    data_o.pow <= resize(signed(fifo_o(FIFO_POW_WIDTH - 1 downto 0)),data_o.pow'length);
                    data_o.df <= unsigned(fifo_o(FIFO_FREQ_WIDTH + FIFO_POW_WIDTH - 1 downto FIFO_POW_WIDTH));
                    delay <= resize(unsigned(fifo_o(fifo_o'length - 1 downto FIFO_FREQ_WIDTH + FIFO_POW_WIDTH)),delay'length) - 3;
                    
                    if start_i = '1' or (empty = '0' and enabled = '1') then
                        state <= waiting;
                        rdTrig <= '1';
                        data_o.valid <= '1';
                        data_o.enable <= '1';
                        enabled <= '1';
                    else
                        rdTrig <= '0';
                        data_o.valid <= '0';
                        enabled <= '0';
                        data_o.enable <= '0';
                    end if;
                    
                when waiting =>
                    rdTrig <= '0';
                    data_o.valid <= '0';
                    if delay(delay'length-1) = '0' then
                        delay <= delay - 1;
                    else
                        state <= wait_for_trigger;
                    end if;
    
            end case;
        end if;
    end if;
end process;


end rtl;