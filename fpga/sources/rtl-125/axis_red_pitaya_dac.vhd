library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
--
-- The UNISIM library is needed for the IBUFGDS and BUFG components
--
library UNISIM;
use UNISIM.VComponents.all;

entity AXIS_Red_Pitaya_DAC is
    generic(
        DAC_DATA_WIDTH  :   integer :=  14;
        AXIS_TDATA_WIDTH:   integer :=  32
    );
    port(
        -- PLL Signals
        aclk            :   in  std_logic;
        ddr_clk         :   in  std_logic;
        locked          :   in  std_logic;
        -- DAC Signals
        dac_clk         :   out std_logic;
        dac_rst         :   out std_logic;
        dac_sel         :   out std_logic;
        dac_wrt         :   out std_logic;
        dac_dat         :   out std_logic_vector(DAC_DATA_WIDTH - 1 downto 0);
        -- Slave side
        s_axis_tready   :   out std_logic;
        s_axis_tdata    :   in  std_logic_vector(AXIS_TDATA_WIDTH - 1 downto 0);
        s_axis_tvalid   :   in  std_logic
    );
end AXIS_Red_Pitaya_DAC;

architecture rtl of AXIS_Red_Pitaya_DAC is

ATTRIBUTE X_INTERFACE_INFO : STRING;
ATTRIBUTE X_INTERFACE_INFO of s_axis_tdata: SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TDATA";
ATTRIBUTE X_INTERFACE_INFO of s_axis_tvalid: SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TVALID";
ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
ATTRIBUTE X_INTERFACE_PARAMETER of s_axis_tdata: SIGNAL is "CLK_DOMAIN system_processing_system7_0_0_FCLK_CLK0,FREQ_HZ 125000000";
ATTRIBUTE X_INTERFACE_PARAMETER of s_axis_tvalid: SIGNAL is "CLK_DOMAIN system_processing_system7_0_0_FCLK_CLK0,FREQ_HZ 125000000";
    
signal int_dat_a, int_dat_b :   std_logic_vector(DAC_DATA_WIDTH - 1 downto 0);
signal dac_a, dac_b         :   std_logic_vector(DAC_DATA_WIDTH - 1 downto 0);
signal int_rst              :   std_logic;

begin

dac_a <= s_axis_tdata(DAC_DATA_WIDTH - 1 downto 0);
dac_b <= s_axis_tdata(AXIS_TDATA_WIDTH/2 + DAC_DATA_WIDTH - 1 downto AXIS_TDATA_WIDTH/2);
    
PLLProc: process(aclk) is
begin
    if rising_edge(aclk) then
        if locked = '0' or s_axis_tvalid = '0' then
            int_dat_a <= (others => '0');
            int_dat_b <= (others => '0');
        else
            int_dat_a <= dac_a(dac_a'length - 1) & not(dac_a(dac_a'length - 2 downto 0));
            int_dat_b <= dac_b(dac_b'length - 1) & not(dac_b(dac_b'length - 2 downto 0));
        end if;
        int_rst <= not(locked) or not(s_axis_tvalid);
    end if;
end process;

ODDR_rst: ODDR
port map(
    Q       =>  dac_rst,
    D1      =>  int_rst,
    D2      =>  int_rst,
    C       =>  aclk,
    CE      =>  '1',
    R       =>  '0',
    S       =>  '0'
);

ODDR_sel: ODDR
port map(
    Q       =>  dac_sel,
    D1      =>  '0',
    D2      =>  '1',
    C       =>  aclk,
    CE      =>  '1',
    R       =>  '0',
    S       =>  '0'
);

ODDR_wrt: ODDR
port map(
    Q       =>  dac_wrt,
    D1      =>  '0',
    D2      =>  '1',
    C       =>  ddr_clk,
    CE      =>  '1',
    R       =>  '0',
    S       =>  '0'
);

ODDR_clk: ODDR
port map(
    Q       =>  dac_clk,
    D1      =>  '0',
    D2      =>  '1',
    C       =>  ddr_clk,
    CE      =>  '1',
    R       =>  '0',
    S       =>  '0'
);

DDR_GEN: for I in 0 to DAC_DATA_WIDTH - 1 generate
    ODDR_inst: ODDR
    port map(
        Q   =>  dac_dat(I),
        D1  =>  int_dat_a(I),
        D2  =>  int_dat_b(I),
        C   =>  aclk,
        CE  =>  '1',
        R   =>  '0',
        S   =>  '0'
    );
end generate DDR_GEN;

s_axis_tready <= '1';
    
end architecture rtl;