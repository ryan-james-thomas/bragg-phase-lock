library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseCalculation is
    port(
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        
        adcData_i       :   in  t_adc;
        freqDiff        :   in  unsigned;
        
        
        reg0            :   in  t_param_reg;
        reg1            :   in  t_param_reg;
        mem_bus_m       :   in  t_mem_bus_master;
        mem_bus_s       :   out t_mem_bus_slave

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
    B : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(27 DOWNTO 0)
  );
END COMPONENT;

COMPONENT CIC_Decimate
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tready : OUT STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC
  );
END COMPONENT;

component SimpleLowPass is
    generic(
        DATA_WIDTH  :   natural :=  14;
        FILT_WIDTH  :   natural :=  16
    );
    port(
        clk     :   in  std_logic;
        aresetn :   in  std_logic;
        
        trig_i  :   in  std_logic;
        data1_i :   in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data2_i :   in  std_logic_vector(DATA_WIDTH-1 downto 0);
        param   :   in  t_param_reg;
        data1_o :   out std_logic_vector(DATA_WIDTH-1 downto 0);
        data2_o :   out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_o :   out std_logic
    );
end component;

COMPONENT PhaseCalc
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tready : OUT STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
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
signal mixPhase_slv     :   std_logic_vector(PHASE_WIDTH-1 downto 0);
signal dds_combined     :   std_logic_vector(31 downto 0);
signal dds_sin          :   std_logic_vector(13 downto 0);
signal dds_cos          :   std_logic_vector(13 downto 0);
signal I, Q             :   std_logic_vector(27 downto 0);

--
-- Downsampling/fast averaging signals
--
signal cicRate          :   unsigned(10 downto 0);
signal cicConfig_i      :   std_logic_vector(15 downto 0);
signal cicI_i, cicQ_i   :   std_logic_vector(15 downto 0);

signal cicI_o, cicQ_o   :   std_logic_vector(47 downto 0);
signal validIcic, validQcic         :   std_logic;

--
-- Low-pass filter signals
--
signal Ilp, Qlp :   std_logic_vector(13 downto 0);
signal lpParam  :   t_param_reg;
signal validLP  :   std_logic;

--
-- Phase calculation signals
--
signal tdataPhase   :   std_logic_vector(31 downto 0);
signal phase        :   std_logic_vector(15 downto 0);
signal validPhase   :   std_logic;

--
-- Memory signals
--
signal memSwitch    :   std_logic_vector(3 downto 0);
signal memData_i    :   std_logic_vector(15 downto 0);
signal memValid_i   :   std_logic;

begin

--
-- Generate mixing signals
--
mixPhase_slv <= std_logic_vector(resize(freqDiff,PHASE_WIDTH));
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
dds_cos <= std_logic_vector(resize(signed(dds_combined(9 downto 0)),dds_cos'length));
dds_sin <= std_logic_vector(resize(signed(dds_combined(29 downto 16)),dds_sin'length));

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
cicRate <= unsigned(reg1(3 downto 0));
cicConfig_i(11 downto 0) <= std_logic_vector(shift_left(to_unsigned(1,12),to_integer(cicRate)));
cicConfig_i(15 downto 12) <= (others => '0');
cicI_i <= std_logic_vector(resize(signed(I),cicI_i'length));
cicQ_i <= std_logic_vector(resize(signed(Q),cicQ_i'length));

I_decimate: CIC_Decimate
port map(
    aclk                    => clk,
    aresetn                 => aresetn,
    s_axis_config_tdata     => cicConfig_i,
    s_axis_config_tvalid    => '1',
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
    s_axis_config_tvalid    => '1',
    s_axis_config_tready    => open,
    s_axis_data_tdata       => cicQ_i,
    s_axis_data_tvalid      => '1',
    s_axis_data_tready      => open,
    m_axis_data_tdata       => cicQ_o,
    m_axis_data_tvalid      => validQcic
);

LP: SimpleLowPass
generic map(
    DATA_WIDTH      =>  I'length,
    FILT_WIDTH      =>  16
)
port map(
    clk         =>  sysClk,
    aresetn     =>  aresetn,
    trig_i      =>  validAvg,
    data1_i     =>  Ids,
    data2_i     =>  Qds,
    param       =>  lpParam,
    data1_o     =>  Ilp,
    data2_o     =>  Qlp,
    valid_o     =>  validLP
);

--
-- Compute phase via arctan
--
MakePhase: PhaseCalc
PORT MAP (
    aclk                    => sysClk,
    aresetn                 => aresetn,
    s_axis_cartesian_tvalid => validLP,
    s_axis_cartesian_tready => open,
    s_axis_cartesian_tdata  => tdataPhase,
    m_axis_dout_tvalid      => validPhase,
    m_axis_dout_tdata       => phase
);

--
-- Save data
--
memSwitch <= reg0(3 downto 0);

memData_i <=    std_logic_vector(resize(signed(fifo_o),memData_i'length)) when memSwitch = X"F" else
                phase;
memValid_i <=   '1' when memSwitch = X"F" else
                validPhase;                

SaveData: BlockMemHandler
port map(
    clk         =>  sysClk,
    aresetn     =>  aresetn,
    data_i      =>  memData_i,
    valid_i     =>  memValid_i,
    bus_m       =>  mem_bus_m,
    bus_s       =>  mem_bus_s
);

end Behavioral;
