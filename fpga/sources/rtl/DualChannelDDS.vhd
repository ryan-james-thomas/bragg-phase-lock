library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

--
-- This module generates two sinusoidal signals with different frequencies and amplitudes and with
-- a programmable phase difference between them
--
entity DualChannelDDS is
    port(
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        
        pow1            :   in  t_dds_phase;
        ftw1            :   in  t_dds_phase;
        ftw2            :   in  t_dds_phase;
        
        amp_i           :   in  t_amp_array;
        
        dac_o           :   out t_dac_array
    );    
end DualChannelDDS;

architecture Behavioral of DualChannelDDS is
--
-- This component generates a sinusoidal signal with a stream-able phase
-- This means that the phase can be updated very fast
--
COMPONENT FreqPhaseStreamDDS
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;
--
-- For interferometry we only need to control the relative phase,
-- so to save "space" on the FPGA we only have a frequency streaming
-- version for the second DDS
--
COMPONENT FreqStreamDDS
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;
--
-- For amplitude control we need to multiply the DDS output
-- with a scale factor
--
COMPONENT OutputMultiplier
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(21 DOWNTO 0)
  );
END COMPONENT;
--
-- Various signals
--
signal dds1_phase_slv   :   std_logic_vector(63 downto 0);
signal dds1_tdata       :   std_logic_vector(15 downto 0);
signal dds1_tvalid      :   std_logic;
signal dds2_phase_slv   :   std_logic_vector(31 downto 0);
signal dds2_tdata       :   std_logic_vector(15 downto 0);
signal dds2_tvalid      :   std_logic;

signal dds1_mult_i, dds2_mult_i :   std_logic_vector(9 downto 0);
signal dds1_mult_o, dds2_mult_o :   std_logic_vector(21 downto 0);
signal amp_slv_1, amp_slv_2  :   std_logic_vector(t_amp_mult'length - 1 downto 0);

begin
--
-- Generate DDS data
--
dds1_phase_slv <= std_logic_vector(resize(pow1,32)) & std_logic_vector(resize(ftw1,32));
DDS1: FreqPhaseStreamDDS
port map(
    aclk                =>  clk,
    aresetn             =>  aresetn,
    s_axis_phase_tvalid =>  '1',
    s_axis_phase_tdata  =>  dds1_phase_slv,
    m_axis_data_tvalid  =>  dds1_tvalid,
    m_axis_data_tdata   =>  dds1_tdata
);

dds2_phase_slv <= std_logic_vector(resize(ftw2,32));
DDS2: FreqStreamDDS
port map(
    aclk                =>  clk,
    aresetn             =>  aresetn,
    s_axis_phase_tvalid =>  '1',
    s_axis_phase_tdata  =>  dds2_phase_slv,
    m_axis_data_tvalid  =>  dds2_tvalid,
    m_axis_data_tdata   =>  dds2_tdata
);
--
-- Output scaling
--
amp_slv_1 <= std_logic_vector(amp_i(0));
amp_slv_2 <= std_logic_vector(amp_i(1));
dds1_mult_i <= std_logic_vector(resize(signed(dds1_tdata),dds1_mult_i'length));
dds2_mult_i <= std_logic_vector(resize(signed(dds2_tdata),dds2_mult_i'length));
Mult1: OutputMultiplier
port map(
    clk =>  clk,
    A   =>  dds1_mult_i,
    B   =>  amp_slv_1,
    P   =>  dds1_mult_o
);

Mult2: OutputMultiplier
port map(
    clk =>  clk,
    A   =>  dds2_mult_i,
    B   =>  amp_slv_2,
    P   =>  dds2_mult_o
);
--
-- Create output data
--
dac_o(0) <= resize(shift_right(signed(dds1_mult_o),8),DAC_WIDTH);
dac_o(1) <= resize(shift_right(signed(dds2_mult_o),8),DAC_WIDTH);

end Behavioral;
