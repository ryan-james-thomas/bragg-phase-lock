library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseControl_tb is
--  Port ( );
end PhaseControl_tb;

architecture Behavioral of PhaseControl_tb is

component PhaseControl is
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
        valid_o     :   out std_logic
    );
end component;

constant CLK_T      :   time    :=  10 ns;
signal clk, aresetn :   std_logic;

signal reg0, gains :   t_param_reg;
signal phase_i, phase_c :   t_phase;
signal valid_i, valid_o :   std_logic;
signal dds_phase_o  :   t_dds_phase;
signal dds_phase_signed, dds_phase_pi :   t_phase;

signal count    :   natural;

constant PHASE_PI   :   t_phase :=  shift_left(to_signed(1,phase_i'length),CORDIC_WIDTH-3);

begin

clk_proc: process is
begin
    clk <= '0';
    wait for CLK_T/2;
    clk <= '1';
    wait for CLK_T/2;
end process;

uut: PhaseControl
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    reg0        =>  reg0,
    gains       =>  gains,
    phase_i     =>  phase_i,
    valid_i     =>  valid_i,
    phase_c     =>  phase_c,
    dds_phase_o =>  dds_phase_o,
    valid_o     =>  valid_o
);

dds_phase_signed <= resize(signed(shift_right(dds_phase_o,PHASE_WIDTH - 1 - CORDIC_WIDTH + 3)),phase_i'length);
dds_phase_pi <= dds_phase_signed when dds_phase_signed < PHASE_PI else dds_phase_signed - shift_left(PHASE_PI,1);

PhaseProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
--        phase_i <= (others => '0');
        phase_i <= to_signed(100,phase_i'length);
        valid_i <= '0';
        count <= 0;
    elsif rising_edge(clk) then
        if valid_o = '1' then
            phase_i <= shift_right(phase_i + shift_left(dds_phase_pi,2),0);
        else
--            phase_i <= phase_i + to_signed(1,phase_i'length);
        end if;
        
        if count < 32 then
            count <= count + 1;
            valid_i <= '0';
        else
            count <= 0;
            phase_i <= phase_i + to_signed(1,phase_i'length);
            valid_i <= '1';
        end if;
    end if;    
end process;

main_proc: process
begin
    aresetn <= '0';
    reg0(31 downto 6) <= (others => '0');
    reg0(5 downto 2) <= X"2";
    reg0(1 downto 0) <= "00";
    gains <= X"02" & X"00" & X"01" & X"01";
--    phase_i <= (others => '0');
    phase_c <= (others => '0');
    wait for 200 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
--    valid_i <= '1';
    wait until rising_edge(clk);
--    valid_i <= '0';
    wait for 1000 ns;
    wait until rising_edge(clk);
    reg0(1 downto 0) <= "10";
--    phase_c <= to_signed(-4096,phase_c'length);
--    valid_i <= '1';
    wait until rising_edge(clk);
--    valid_i <= '0';
    wait;
end process;

end Behavioral;
