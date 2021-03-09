library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
--
-- The UNISIM library is needed for the IBUFGDS and BUFG components
--
library UNISIM;
use UNISIM.VComponents.all;

entity AXIS_Red_Pitaya_ADC is
    generic (
        ADC_DATA_WIDTH  :   natural :=  14;
        AXIS_TDATA_WIDTH:   natural :=  32
    );
    port (
        adc_clk_p   :   in  std_logic;
        adc_clk_n   :   in  std_logic;
        adc_data_a  :   in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
        adc_data_b  :   in  std_logic_vector(ADC_DATA_WIDTH-1 downto 0);

        adc_clk     :   out std_logic;
        adc_csn     :   out std_logic;
        
        m_axis_tvalid   :   out std_logic;
        m_axis_tdata    :   out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
    );
end AXIS_Red_Pitaya_ADC;

architecture Behavioural of AXIS_Red_Pitaya_ADC is
    
constant PADDING_WIDTH  :   natural :=  AXIS_TDATA_WIDTH/2 - ADC_DATA_WIDTH;
signal int_clk0, int_clk  :   std_logic;

begin
--
-- This component converts the differential clock into a single-ended clock
--
adc_clk_inst0: IBUFGDS
port map(
    O   =>  int_clk0,
    I   =>  adc_clk_p,
    IB  =>  adc_clk_n
);
--
-- This component provides additional global clock buffering
--
adc_clk_inst: BUFG
port map(
    I   =>  int_clk0,
    O   =>  int_clk
);

adc_clk <= int_clk;
adc_csn <= '1';
m_axis_tvalid <= '1';

--
-- This process puts both ADC signals into a single, 32-bit signal with appropriate padding
--
Main: process(int_clk) is
begin
    if rising_edge(int_clk) then
        m_axis_tdata(AXIS_TDATA_WIDTH-1 downto AXIS_TDATA_WIDTH-PADDING_WIDTH-1) <= (others => adc_data_b(ADC_DATA_WIDTH-1));
        m_axis_tdata(AXIS_TDATA_WIDTH-PADDING_WIDTH-2 downto AXIS_TDATA_WIDTH-PADDING_WIDTH-ADC_DATA_WIDTH) <= not adc_data_b(ADC_DATA_WIDTH-2 downto 0);
        m_axis_tdata(ADC_DATA_WIDTH+PADDING_WIDTH-1 downto ADC_DATA_WIDTH-1) <= (others => adc_data_a(ADC_DATA_WIDTH-1));
        m_axis_tdata(ADC_DATA_WIDTH-2 downto 0) <= not adc_data_a(ADC_DATA_WIDTH-2 downto 0);
    end if;
end process;
    
end architecture Behavioural;
