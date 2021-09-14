library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseControl is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;

        reg0        :   in  t_param_reg;
        gains       :   in  t_param_reg;

        phase_i     :   in  t_phase;
        valid_i     :   in  std_logic;
        phase_c     :   in  t_phase;

        dds_phase_o :   out t_dds_phase;
        act_phase_o :   out unsigned(CORDIC_WIDTH-1 downto 0);
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
        gains       :   in  t_param_reg;
        params      :   in  t_param_reg;
        --
        -- Outputs
        --
        valid_o     :   out std_logic;
        data_o      :   out t_dds_phase;
        act_o       :   out unsigned(CORDIC_WIDTH-1 downto 0)
    );
end component;

signal polarity     :   std_logic;
signal enable       :   std_logic;
signal divPower     :   unsigned(3 downto 0);

signal phaseNew, phaseOld   :   t_phase;
signal phaseDiff            :   t_phase;
signal phaseSum             :   t_phase;
constant PHASE_POS_PI       :   t_phase     :=  to_signed(65535,phaseSum'length);

signal validWrap            :   std_logic;
signal validPI             :   std_logic;

signal pi_o     :   t_phase;

type t_status_local is (idle,wrapping,summing,output);
signal state    :   t_status_local  :=  idle;

signal dds_phase    :   t_dds_phase;

begin

PI: PIController
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    meas_i      =>  phaseSum,
    control_i   =>  phase_c,
    valid_i     =>  validWrap,
    gains       =>  gains,
    params      =>  reg0,
    valid_o     =>  validPI,
    data_o      =>  dds_phase,
    act_o       =>  act_phase_o
);

--OutputClocking: process(clk,aresetn) is
--begin
--    if aresetn = '0' then
--        dds_phase_o <= (others => '0');
--        valid_o <= '0';
--        phaseSum_o <= (others => '0');
--    elsif rising_edge(clk) then
--        if enable = '1' then
--            dds_phase_o <= dds_phase;
--            valid_o <= validPI;
--        else
--            dds_phase_o <= resizePhase(phase_c);
--            valid_o <= validWrap;
--        end if;
--        phaseSum_o <= phaseSum;
--    end if;
--end process;
dds_phase_o <= dds_phase when enable = '1' else resizePhase(phase_c);
valid_o <= validPI when enable = '1' else validWrap;
phaseSum_o <= phaseSum;
--
-- Unwrap phase
--
polarity <= reg0(0);
enable <= reg0(1);

PhaseWrap: process(clk,aresetn) is
begin
    if aresetn = '0' then
        phaseDiff <= (others => '0');
        phaseNew <= (others => '0');
        phaseOld <= (others => '0');
        phaseSum <= (others => '0');
        state <= idle;
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
                if enable = '1' then
                    phaseSum <= phaseSum + phaseDiff;
                elsif enable = '0' then
                    phaseSum <= (others => '0');
                end if;
            
            when others => null;
        
        end case;
    end if;
end process;


end Behavioural;