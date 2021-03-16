library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;
 
entity AXI_Stream_Combine is
    port(   
        aclk            :   in  std_logic;
        aresetn         :   in  std_logic;
        
        s_axi1_tdata    :   in  std_logic_vector(15 downto 0);
        s_axi1_tvalid   :   in  std_logic;
        
        s_axi2_tdata    :   in  std_logic_vector(15 downto 0);
        s_axi2_tvalid   :   in  std_logic;
        
        m_axi_tdata     :   out std_logic_vector(31 downto 0);
        m_axi_tvalid    :   out std_logic 
    );    
end AXI_Stream_Combine;

architecture Behavioral of AXI_Stream_Combine is

attribute X_INTERFACE_INFO  :   string;
attribute X_INTERFACE_INFO of aclk: signal is "xilinx:signal:clock:1.0 aclk CLK";
attribute X_INTERFACE_PARAMETER : string;
attribute X_INTERFACE_PARAMETER of aclk : signal is "FREQ_HZ 125000000";
attribute X_INTERFACE_PARAMETER of s_axi1 : signal is "CLK_DOMAIN aclk, FREQ_HZ 125000000";


begin

m_axi_tvalid <= s_axi1_tvalid or s_axi2_tvalid;
m_axi_tdata <= s_axi1_tdata & s_axi2_tdata;


end Behavioral;
