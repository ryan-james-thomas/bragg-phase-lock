library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PIController_tb is
end PIController_tb;

architecture rtl of PIController_tb is

component PIController is
    port(
        --
        -- Clocking and reset
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Inputs
        --
        meas_i      :   in  t_phase;
        control_i   :   in  t_phase;
        valid_i     :   in  std_logic;
        --
        -- Parameters
        --
        gains       :   in  t_param_reg;
        params      :   in  t_param_reg;
        --
        -- Outputs
        --
        valid_o     :   out std_logic;
        data_o      :   out t_phase
    );
end component;

--
-- Clocks and reset
--
constant SYS_CLK_T      :   time    :=  10 ns;
constant ADC_CLK_T      :   time    :=  10 ns;
signal sysclk, adcclk, aresetn :   std_logic;
--
-- Signals
--
signal meas_i, control_i    :   t_phase;
signal valid_i              :   std_logic;
signal gains, params        :   t_param_reg;

signal valid_o  :   std_logic;
signal data_o   :   t_phase;
signal act_o    :   unsigned(CORDIC_WIDTH - 1 downto 0);

--
-- Delay signal
--
signal measDelay    :   unsigned(15 downto 0);
signal count        :   unsigned(measDelay'length - 1 downto 0);

begin
--
-- Create clock
--
sys_clk_proc: process is
begin
    sysclk <= '0';
    wait for SYS_CLK_T/2;
    sysclk <= '1';
    wait for SYS_CLK_T/2;
end process;

adc_clk_proc: process is
begin
    adcclk <= '0';
    wait for ADC_CLK_T/2;
    adcclk <= '1';
    wait for ADC_CLK_T/2;
end process;
--
-- Unit under test
--
PI: PIController
port map(
    clk         =>  sysclk,
    aresetn     =>  aresetn,
    meas_i      =>  meas_i,
    control_i   =>  control_i,
    valid_i     =>  valid_i,
    gains       =>  gains,
    params      =>  params,
    valid_o     =>  valid_o,
    data_o      =>  data_o
);

MeasProc: process(sysclk,aresetn) is
begin
    if aresetn = '0' then
        valid_i <= '0';
        meas_i <= (others => '0');
        count <= (others => '0');
    elsif rising_edge(sysclk) then
        if count < measDelay then
            count <= count + 1;
            valid_i <= '0';
        else
            count <= (others => '0');
            valid_i <= '1';
            meas_i <= data_o;
        end if;
    end if;
end process;

main: process is
begin
    aresetn <= '0';
    control_i <= (others => '0');
    gains <= X"05001405";
    params <= (0 => '0', 1 => '0', others => '0');
    measDelay <= to_unsigned(20,measDelay'length);
    wait for 100 ns;
    wait until rising_edge(sysclk);
    aresetn <= '1';
    wait for 100 ns;
    params <= (0 => '0', 1 => '1', others => '0');
    control_i <= to_signed(1000,control_i'length);
    wait for 5 us;
    wait until rising_edge(sysclk);
    control_i <= to_signed(-1000,control_i'length);
    wait;
end process;


end architecture rtl;