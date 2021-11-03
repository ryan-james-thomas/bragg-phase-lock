library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity SimpleAXIBuffer is
    port(
        sysclk      :   in  std_logic;
        adcclk      :   in  std_logic;
        aresetn     :   in  std_logic;

        --
        -- Master signals
        --
        addr_i      :   in  unsigned(AXI_ADDR_WIDTH - 1 downto 0);
        addr_o      :   out unsigned(AXI_ADDR_WIDTH - 1 downto 0);
        writeData_i :   in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
        writeData_o :   out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
        dataValid_i :   in  std_logic_vector(1 downto 0);
        dataValid_o :   out std_logic_vector(1 downto 0);

        --
        -- Slave signals
        --
        readData_i  :   in  std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
        readData_o  :   out std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
        resp_i      :   in  std_logic_vector(1 downto 0);
        resp_o      :   out std_logic_vector(1 downto 0)
    );
end SimpleAXIBuffer;

architecture Behavioural of SimpleAXIBuffer is


begin

--
-- sysclk to adcclk process
--
Sys2ADC: process(adcclk,aresetn) is
begin
    if aresetn = '0' then
        addr_o <= (others => '0');
        writeData_o <= (others => '0');
        dataValid_o <= (others => '0');
    elsif rising_edge(adcclk) then
        addr_o <= addr_i;
        writeData_o <= writeData_i;
        dataValid_o <= dataValid_i;
    end if;
end process;
--
-- adcclk to sysclk process
--
ADC2Sys: process(sysclk,aresetn) is
begin
    if aresetn = '0' then
        readData_o <= (others => '0');
        resp_o <= (others => '0');
    elsif rising_edge(sysclk) then
        readData_o <= readData_i;
        resp_o <= resp_i;
    end if;
end process;

end Behavioural;