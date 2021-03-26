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

        phase_i     :   in  t_phase;
        valid_i     :   in  std_logic;
        phase_c     :   in  t_phase;

        dds_phase_o :   out t_dds_phase;
        act_phase_o :   out unsigned(CORDIC_WIDTH-1 downto 0);
        valid_o     :   out std_logic
    );
end PhaseControl;

architecture Behavioural of PhaseControl is

signal polarity     :   std_logic;
signal enable       :   std_logic;
signal divPower     :   unsigned(3 downto 0);

signal phaseNew, phaseOld   :   t_phase;
signal phaseDiff            :   t_phase;
signal phaseSum             :   t_phase;
constant PHASE_POS_PI       :   t_phase     :=  to_signed(65535,phaseSum'length);

signal err, control, act    :   t_phase;

signal actScale             :   signed(CORDIC_WIDTH-1 downto 0);
signal act2pi               :   unsigned(CORDIC_WIDTH-1 downto 0);
constant PHASE_2PI          :   unsigned(CORDIC_WIDTH-1 downto 0)   :=  shift_left(to_unsigned(1,CORDIC_WIDTH),CORDIC_WIDTH-2);

signal dds_phase_corr, dds_phase       :   t_dds_phase;

signal validWrap            :   std_logic;

type t_status_local is (idle,wrapping,summing,output);
signal state    :   t_status_local  :=  idle;

begin

--
-- Unwrap phase
--
polarity <= reg0(0);
enable <= reg0(1);
divPower <= unsigned(reg0(5 downto 2));

PhaseWrap: process(clk,aresetn) is
begin
    if aresetn = '0' then
        phaseDiff <= (others => '0');
        phaseNew <= (others => '0');
        phaseOld <= (others => '0');
        phaseSum <= (others => '0');
        state <= idle;
        dds_phase <= (others => '0');
        valid_o <= '0';
    elsif rising_edge(clk) then
        PhaseCase: case(state) is
            when idle =>
                valid_o <= '0';
                if valid_i = '1' then
                    phaseOld <= phaseNew;
                    phaseNew <= phase_i;
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
                state <= output;
                if enable = '1' then
                    phaseSum <= phaseSum + phaseDiff;
                    validWrap <= '1';
                elsif enable = '0' then
                    phaseSum <= (others => '0');
                end if;
                
            when output =>
                valid_o <= '1';
                state <= idle;
                if enable = '1' then
                    dds_phase <= dds_phase + dds_phase_corr;
                else
                    dds_phase <= dds_phase_corr;
                end if;
        
        end case;
    end if;
end process;


err <= phase_c - phaseSum when polarity = '0' else phaseSum - phase_c;
act <= shift_right(err,to_integer(divPower));

actScale <= resize(act,CORDIC_WIDTH);
act2pi <= unsigned(actScale) when actScale > 0 else PHASE_2PI - unsigned(abs(actScale));
dds_phase_corr <=  shift_left(resize(act2pi,PHASE_WIDTH),PHASE_WIDTH - 1 - CORDIC_WIDTH + 3);

dds_phase_o <= dds_phase;
act_phase_o <= act2pi;

end Behavioural;