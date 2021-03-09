library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PhaseCalculation is
    port(
        sysClk          :   in  std_logic;
        adcClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        
        s_axis1_tdata   :   std_logic_vector(31 downto 0);
        s_axis1_tvalid  :   std_logic;
        
        s_axis2_tdata   :   std_logic_vector(31 downto 0);
        s_axis2_tvalid  :   std_logic

    );
end PhaseCalculation;

architecture Behavioral of PhaseCalculation is

component Simple_FIFO is
    port (
        wr_clk  :   in  std_logic;
        rd_clk  :   in  std_logic;
        aresetn :   in  std_logic;
        
        data_i  :   in  std_logic_vector;
        data_o  :   out std_logic_vector
    );
end component;

COMPONENT MultMixer
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(27 DOWNTO 0)
  );
END COMPONENT;

component QuickAvg is
    generic(
        DATA_WIDTH  :   natural :=  14
    );
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        adcData1_i  :   in  std_logic_vector(DATA_WIDTH-1 downto 0);
        adcData2_i  :   in  std_logic_vector(DATA_WIDTH-1 downto 0);
        adcData1_o  :   out std_logic_vector(DATA_WIDTH-1 downto 0);
        adcData2_o  :   out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_o     :   out std_logic
    );
end component;

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


signal fifo_i   :   std_logic_vector(13 downto 0);
signal fifo_o   :   std_logic_vector(13 downto 0);
signal dds_sin  :   std_logic_vector(13 downto 0);
signal dds_cos  :   std_logic_vector(13 downto 0);

signal I, Q     :   std_logic_vector(27 downto 0);
signal Ids, Qds :   std_logic_vector(13 downto 0);
signal validAvg :   std_logic;
signal reduceReg:   t_param_reg;

signal Ilp, Qlp :   std_logic_vector(13 downto 0);
signal lpParam  :   t_param_reg;
signal validLP  :   std_logic;

signal tdataPhase   :   std_logic_vector(31 downto 0);
signal phase        :   std_logic_vector(15 downto 0);
signal validPhase   :   std_logic;


begin

--
-- Use a very simple FIFO to switch ADC data from
-- adcClk to sysClk
--
fifo_i <= s_axis1_tdata(13 downto 0);
FIFO1: Simple_FIFO
port map(
    wr_clk  =>  adcClk,
    rd_clk  =>  sysClk,
    aresetn =>  aresetn,
    data_i  =>  fifo_i,
    data_o  =>  fifo_o
);

--
-- Multiply the input signal with the I and Q mixing signals
--
dds_cos <= s_axis2_tdata(13 downto 0);
dds_sin <= s_axis2_tdata(29 downto 16);

I_Mixer: MultMixer
port map(
    CLK =>  sysClk,
    A   =>  fifo_o,
    B   =>  dds_cos,
    P   =>  I
);

Q_Mixer: MultMixer
port map(
    CLK =>  sysClk,
    A   =>  fifo_o,
    B   =>  dds_sin,
    P   =>  Q
);

--
-- Filter I and Q
--
SampleReduce: QuickAvg
generic map(
    DATA_WIDTH  =>  I'length
)
port map(
    clk         =>  sysClk,
    aresetn     =>  aresetn,
    reg0        =>  reduceReg,
    adcData1_i  =>  I,
    adcData2_i  =>  Q,
    adcData1_o  =>  Ids,
    adcData2_o  =>  Qds,
    valid_o     =>  validAvg
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

end Behavioral;
