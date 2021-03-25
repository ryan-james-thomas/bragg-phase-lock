library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseCalculation_tb is
--  Port ( );
end PhaseCalculation_tb;

architecture Behavioral of PhaseCalculation_tb is

component PhaseCalculation is
    port(
        clk             :   in  std_logic;          --Master system clock
        aresetn         :   in  std_logic;          --Asynchronous active-low reset
        
        adcData_i       :   in  t_adc;              --ADC data synchronous with clk
        
        freq_i          :   in  t_dds_phase;        --Frequency difference used for mixing DDS             
        reg0            :   in  t_param_reg;        --Bits [3,0]: log2(cicRate)
        regValid_i      :   in  std_logic;
        
        phase_o         :   out t_phase;            --Output phase
        valid_o         :   out std_logic           --Output phase valid signal
    );
end component;

COMPONENT MixerDDS_PhaseOffset
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

COMPONENT MixingDDS
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

constant CLK_T  :   time    :=  10 ns;

signal clk, aresetn :   std_logic;
signal adcData_i    :   t_adc;

signal freq_i       :   t_dds_phase;

signal reg0         :   t_param_reg;
signal regValid_i   :   std_logic;

--signal mem_bus      :   t_mem_bus   :=  INIT_MEM_BUS;

signal phase_o      :   t_phase;
signal valid_o      :   std_logic;

signal ddsfreq      :   std_logic_vector(31 downto 0);
signal ddsphase     :   std_logic_vector(31 downto 0);
signal ddsphaseValid:   std_logic;
signal dds_o        :   std_logic_vector(31 downto 0);
signal ddsValid_o   :   std_logic;

signal mixPhase_slv     :   std_logic_vector(31 downto 0);
signal dds_combined     :   std_logic_vector(31 downto 0);

begin

clk_proc: process is
begin
    clk <= '0';
    wait for CLK_T/2;
    clk <= '1';
    wait for CLK_T/2;
end process;

uut: PhaseCalculation
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    adcData_i   =>  adcData_i,
    freq_i      =>  freq_i,
    reg0        =>  reg0,
    regValid_i  =>  regValid_i,
    phase_o     =>  phase_o,
    valid_o     =>  valid_o
);

mixPhase_slv <= std_logic_vector(resize(freq_i,mixPhase_slv'length));
--MixGeneration: MixingDDS
--port map(
--    aclk                => clk,
--    aresetn             => aresetn,
--    s_axis_phase_tvalid => '1',
--    s_axis_phase_tdata  => mixPhase_slv,
--    m_axis_data_tvalid  => open,
--    m_axis_data_tdata   => dds_combined
--);
--adcData_i <= shift_left(resize(signed(dds_combined(15 downto 0)),adcData_i'length),4);


DataGet : MixerDDS_PhaseOffset
PORT MAP (
    aclk => clk,
    aresetn => aresetn,
    s_axis_phase_tvalid => '1',
    s_axis_phase_tdata => mixPhase_slv,
    s_axis_config_tvalid => ddsphaseValid,
    s_axis_config_tdata => ddsphase,
    m_axis_data_tvalid => ddsValid_o,
    m_axis_data_tdata => dds_o
);
adcData_i <= shift_left(resize(signed(dds_o(15 downto 0)),adcData_i'length),0) + to_signed(1024,adcData_i'length);

--test_data: process(clk,aresetn) is
--begin
--    if aresetn = '0' then
--        adcData_i <= (others => '0');
--    elsif rising_edge(clk) then
--        adcData_i <= adcData_i + to_signed(1,adcData_i'length);
--    end if;    
--end process;


main_proc: process
begin
    aresetn <= '0';
    freq_i <= to_unsigned(1073742,freq_i'length);
    reg0 <= X"00" & X"0000" & X"0a";
    regValid_i <= '0';
--    adcData_i <= to_signed(10,adcData_i'length);
    ddsphase <= std_logic_vector(to_signed(0,ddsphase'length));
    ddsphaseValid <= '0';
    wait for 200 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    regValid_i <= '1';
    wait until rising_edge(clk);
    regValid_i <= '0';
    wait for 60 us;
    wait until rising_edge(clk);
    ddsphase <= std_logic_vector(to_signed(33554432,ddsphase'length));
    ddsphaseValid <= '1';
    wait until rising_edge(clk);
    ddsphaseValid <= '0';
    wait until rising_edge(clk);

--    wait until rising_edge(clk);
--    reg0(7 downto 0) <= std_logic_vector(to_unsigned(10,8));
--    wait until rising_edge(clk);
--    regValid_i <= '1';
--    wait until rising_edge(clk);
--    regValid_i <= '0';
    
    
    wait;
end process;

end Behavioral;
