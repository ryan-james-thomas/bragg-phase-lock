library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity DualChannelDDS is
    port(
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        
        pow1            :   in  t_dds_phase;
        ftw1            :   in  t_dds_phase;
        ftw2            :   in  t_dds_phase;
        
        m_axis_tdata    :   out std_logic_vector(31 downto 0);
        m_axis_tvalid   :   out std_logic
    );    
end DualChannelDDS;

architecture Behavioral of DualChannelDDS is

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

signal dds1_phase_slv   :   std_logic_vector(63 downto 0);
signal dds1_tdata       :   std_logic_vector(15 downto 0);
signal dds1_tvalid      :   std_logic;
signal dds2_phase_slv   :   std_logic_vector(31 downto 0);
signal dds2_tdata       :   std_logic_vector(15 downto 0);
signal dds2_tvalid      :   std_logic;

begin

dds1_phase_slv <= std_logic_vector(pow1) & std_logic_vector(ftw1);
DDS1: FreqPhaseStreamDDS
port map(
    aclk                =>  clk,
    aresetn             =>  aresetn,
    s_axis_phase_tvalid =>  '1',
    s_axis_phase_tdata  =>  dds1_phase_slv,
    m_axis_data_tvalid  =>  dds1_tvalid,
    m_axis_data_tdata   =>  dds1_tdata
);

dds2_phase_slv <= std_logic_vector(ftw2);
DDS2: FreqStreamDDS
port map(
    aclk                =>  clk,
    aresetn             =>  aresetn,
    s_axis_phase_tvalid =>  '1',
    s_axis_phase_tdata  =>  dds2_phase_slv,
    m_axis_data_tvalid  =>  dds2_tvalid,
    m_axis_data_tdata   =>  dds2_tdata
);

m_axis_tvalid <= dds1_tvalid and dds2_tvalid;
m_axis_tdata <= dds1_tdata & dds2_tdata;

end Behavioral;
