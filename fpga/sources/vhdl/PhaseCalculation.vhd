library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseCalculation is
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
end PhaseCalculation;

architecture Behavioral of PhaseCalculation is

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

COMPONENT MultMixer
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;

COMPONENT CIC_Decimate
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tready : OUT STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(55 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC
  );
END COMPONENT;

COMPONENT PhaseCalc
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tready : OUT STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;

component BlockMemHandler is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        data_i      :   in  std_logic_vector;
        valid_i     :   in  std_logic;
        
        bus_m       :   in  t_mem_bus_master;
        bus_s       :   out t_mem_bus_slave
    );
end component;

--
-- Mixing signals
--
signal mixPhase_slv     :   std_logic_vector(31 downto 0);
signal dds_combined     :   std_logic_vector(31 downto 0);
signal dds_sin          :   std_logic_vector(9 downto 0);
signal dds_cos          :   std_logic_vector(9 downto 0);
signal I, Q             :   std_logic_vector(23 downto 0);
signal scaleFactor      :   unsigned(3 downto 0);

--
-- Downsampling/fast averaging signals
--
signal cicRate              :   unsigned(7 downto 0);
signal regValid             :   std_logic;
signal cicConfig_i          :   std_logic_vector(15 downto 0);
signal cicI_i, cicQ_i       :   std_logic_vector(23 downto 0);

signal cicI_o, cicQ_o       :   std_logic_vector(55 downto 0);
signal validIcic, validQcic :   std_logic;

signal Iphase_i, Qphase_i   :   std_logic_vector(23 downto 0);
signal validPhase_i         :   std_logic;

--
-- Phase calculation signals
--
signal tdataPhase   :   std_logic_vector(47 downto 0);
signal phase        :   std_logic_vector(23 downto 0);
signal validPhase   :   std_logic;


begin

--
-- Parse parameters
--
cicRate <= unsigned(reg0(7 downto 0));
scaleFactor <= unsigned(reg0(11 downto 8));

--
-- Generate mixing signals
--
mixPhase_slv <= std_logic_vector(resize(freq_i,mixPhase_slv'length));
MixGeneration: MixingDDS
port map(
    aclk                => clk,
    aresetn             => aresetn,
    s_axis_phase_tvalid => '1',
    s_axis_phase_tdata  => mixPhase_slv,
    m_axis_data_tvalid  => open,
    m_axis_data_tdata   => dds_combined
);

--
-- Multiply the input signal with the I and Q mixing signals
--
dds_cos <= std_logic_vector(shift_left(resize(signed(dds_combined(15 downto 0)),dds_cos'length),0));
dds_sin <= std_logic_vector(shift_left(resize(signed(dds_combined(31 downto 16)),dds_sin'length),0));

I_Mixer: MultMixer
port map(
    CLK =>  clk,
    A   =>  std_logic_vector(adcData_i),
    B   =>  dds_cos,
    P   =>  I
);

Q_Mixer: MultMixer
port map(
    CLK =>  clk,
    A   =>  std_logic_vector(adcData_i),
    B   =>  dds_sin,
    P   =>  Q
);

--
-- Filter I and Q
--
cicConfig_i(11 downto 0) <= std_logic_vector(shift_left(to_unsigned(1,12),to_integer(cicRate)));
cicConfig_i(15 downto 12) <= (others => '0');
cicI_i <= std_logic_vector(resize(signed(I),cicI_i'length));
cicQ_i <= std_logic_vector(resize(signed(Q),cicQ_i'length));
rising_sync(clk,aresetn,regValid_i,regValid);
I_decimate: CIC_Decimate
port map(
    aclk                    => clk,
    aresetn                 => aresetn,
    s_axis_config_tdata     => cicConfig_i,
    s_axis_config_tvalid    => regValid,
    s_axis_config_tready    => open,
    s_axis_data_tdata       => cicI_i,
    s_axis_data_tvalid      => '1',
    s_axis_data_tready      => open,
    m_axis_data_tdata       => cicI_o,
    m_axis_data_tvalid      => validIcic
);

Q_decimate: CIC_Decimate
port map(
    aclk                    => clk,
    aresetn                 => aresetn,
    s_axis_config_tdata     => cicConfig_i,
    s_axis_config_tvalid    => regValid,
    s_axis_config_tready    => open,
    s_axis_data_tdata       => cicQ_i,
    s_axis_data_tvalid      => '1',
    s_axis_data_tready      => open,
    m_axis_data_tdata       => cicQ_o,
    m_axis_data_tvalid      => validQcic
);

--
-- Compute phase via arctan
--
validPhase_i <= validQcic and validIcic;
Iphase_i <= std_logic_vector(resize(shift_right(signed(cicI_o),to_integer(cicRate+cicRate+cicRate)),Iphase_i'length));
Qphase_i <= std_logic_vector(resize(shift_right(signed(cicQ_o),to_integer(cicRate+cicRate+cicRate)),Qphase_i'length));
tdataPhase <= Qphase_i & Iphase_i;
--iq_o <= (I => signed(Iphase_i), Q => signed(Qphase_i), valid => validPhase_i);
--iq_o <= (I => resize(shift_right(signed(cicI_o),to_integer(cicRate+cicRate+cicRate)),Iphase_i'length),
--         Q => resize(shift_right(signed(cicQ_o),to_integer(cicRate+cicRate+cicRate)),Qphase_i'length),
--         valid => validPhase_i);
MakePhase: PhaseCalc
PORT MAP (
    aclk                    => clk,
    aresetn                 => aresetn,
    s_axis_cartesian_tvalid => validPhase_i,
    s_axis_cartesian_tready => open,
    s_axis_cartesian_tdata  => tdataPhase,
    m_axis_dout_tvalid      => validPhase,
    m_axis_dout_tdata       => phase
);

valid_o <= validPhase;
phase_o <= resize(signed(phase),phase_o'length);

end Behavioral;
