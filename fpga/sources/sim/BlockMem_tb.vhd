library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity BlockMem_tb is
--  Port ( );
end BlockMem_tb;

architecture Behavioral of BlockMem_tb is

COMPONENT BlockMemDPG
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(127 DOWNTO 0)
  );
END COMPONENT;

constant PERIOD :   time    :=  10 ns;
signal clk, aresetn :   std_logic;

signal wea  :   std_logic_vector(0 downto 0);

begin


end Behavioral;
