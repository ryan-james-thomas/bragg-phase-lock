library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseWrapping is
    port map(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        phase_i     :   in  t_phase;
        valid_i     :   in  std_logic;
        phase_o     :   out t_phase;
        valid_o     :   out std_logic
    );
end PhaseWrapping;

architecture Behavioural of PhaseWrapping is

signal phaseNew, phaseOld   :   t_phase;
constant PHASE_POS_PI       :   t_phase     :=  to_signed(25735,16);
constant PHASE_NEG_PI       :   t_phase     :=  to_signed(-25735,16);


begin

PhaseWrap: process(clk,aresetn) is
begin
    if aresetn = '0' then

    elsif rising_edge(clk) then
        
    end if;

end process;




end Behavioural;