library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
 
entity knight_rider_vhd is
port (
    clk :   in  std_logic;
    led :   out std_logic_vector(7 downto 0)      
);
end knight_rider_vhd;
 
architecture Behavioral of knight_rider_vhd is
 
signal leds :   unsigned(led'length+1 downto 0) :=  "1100000000";
signal dir  :   std_logic   :=  '1';
signal pos  :   unsigned(3 downto 0)    :=  X"8";
 
begin
 
led <= std_logic_vector(leds(leds'length-2 downto 1));
 
Blink: process(clk) is
begin
    if rising_edge(clk) then
        if dir = '0' then
            leds <= shift_left(leds,1);
        else
            leds <= shift_right(leds,1);
        end if;
 
        pos <= pos + 1;
 
    end if;
end process;
 
ChangeDir: process(pos) is
begin
    if pos < 8 then
        dir <= '0';
    else
        dir <= '1';
    end if;
end process;
 
 
end Behavioral;