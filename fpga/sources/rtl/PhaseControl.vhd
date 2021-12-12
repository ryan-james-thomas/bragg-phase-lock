library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseControl is
    port(
        --
        -- Clocks and reset
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Register (0 => polarity, 1 => enable)
        -- Gains (31 downto 24 => divisor, 23 downto 16 => Kd,
        -- 15 downto 8 => Ki, 7 downto 0 => Kp)
        --
        reg0        :   in  t_param_reg;
        gains       :   in  t_param_reg;
        --
        -- Input data
        --
        phase_i     :   in  t_phase;
        valid_i     :   in  std_logic;
        --
        -- Input flags and control phase
        --
        tc_i        :   in  t_timing_control;
        phase_c     :   in  t_phase;
        --
        -- Output signals
        --
        dds_phase_o :   out t_dds_phase;
        phaseSum_o  :   out t_phase;
        valid_o     :   out std_logic
    );
end PhaseControl;

architecture Behavioural of PhaseControl is

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
        enable_i    :   in  std_logic;
        polarity_i  :   in  std_logic;
        hold_i      :   in  std_logic;
        gains       :   in  t_param_reg;
        --
        -- Outputs
        --
        valid_o     :   out std_logic;
        data_o      :   out t_phase
    );
end component;

signal polarity     :   std_logic;
signal enable       :   std_logic;
signal hold         :   std_logic;

signal phaseNew, phaseOld   :   t_phase;
signal phaseDiff            :   t_phase;
signal phaseSum             :   t_phase;
constant PHASE_POS_PI       :   t_phase     :=  shift_left(to_signed(1,phaseSum'length),CORDIC_WIDTH - 3);

signal validWrap            :   std_logic;
signal validPI              :   std_logic;

type t_status_local is (idle,wrapping,summing,output);
signal state    :   t_status_local  :=  idle;

signal phase_o      :   t_phase;
signal dds_phase    :   t_dds_phase;

begin
--
-- Parse parameters and timing controller flags
--
polarity <= reg0(0);
enable <= reg0(1) when tc_i.enable = '0' else tc_i.flags(0);
hold <= tc_i.flags(1);
--
-- Instantiate PID controller
--
PI: PIController
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    meas_i      =>  phaseSum,
    control_i   =>  phase_c,
    valid_i     =>  validWrap,
    gains       =>  gains,
    enable_i    =>  enable,
    polarity_i  =>  polarity,
    hold_i      =>  hold,
    valid_o     =>  validPI,
    data_o      =>  phase_o
);
--
-- Create output signals
--
dds_phase_o <= convertPhase(phase_o) when enable = '1' else convertPhase(phase_c);
valid_o <= validPI when enable = '1' else validWrap;
phaseSum_o <= phaseSum;
--
-- Unwrap phase
--
PhaseWrap: process(clk,aresetn) is
begin
    if aresetn = '0' then
        phaseDiff <= (others => '0');
        phaseNew <= (others => '0');
        phaseOld <= (others => '0');
        phaseSum <= (others => '0');
        state <= idle;
        validWrap <= '0';
    elsif rising_edge(clk) then
        PhaseCase: case(state) is
            when idle =>
                validWrap <= '0';
                if valid_i = '1' then
                    phaseOld <= phaseNew;
                    phaseNew <= resize(phase_i,phaseNew'length);
                    state <= wrapping;
                end if;
                
            when wrapping =>
                state <= summing;
                if phaseNew - phaseOld > PHASE_POS_PI then
                    phaseDiff <= phaseNew - phaseOld - shift_left(PHASE_POS_PI,1);
                elsif phaseNew - phaseOld < -PHASE_POS_PI then
                    phaseDiff <= phaseNew - phaseOld + shift_left(PHASE_POS_PI,1);
                else
                    phaseDiff <= phaseNew - phaseOld;
                end if;
                
            when summing =>
                state <= idle;
                validWrap <= '1';
                if enable = '1' and hold = '0' then
                    phaseSum <= phaseSum + phaseDiff;                  
                elsif enable = '0' then
                    phaseSum <= (others => '0');
                end if;
            
            when others => null;
        
        end case;
    end if;
end process;


end Behavioural;