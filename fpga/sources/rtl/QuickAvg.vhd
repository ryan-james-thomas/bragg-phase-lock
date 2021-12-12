library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

entity QuickAvg is
    generic(
        DATA_WIDTH  :   natural :=  14
    );
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        adcData1_i  :   in  std_logic_vector;
        adcData2_i  :   in  std_logic_vector;
        adcData1_o  :   out std_logic_vector;
        adcData2_o  :   out std_logic_vector;
        valid_o     :   out std_logic
    );
end QuickAvg;

architecture Behavioural of QuickAvg is

constant MAX_AVGS   :   natural :=  255;
constant PADDING    :   natural :=  8;  
constant EXT_WIDTH  :   natural :=  adcData1_i'length+PADDING; 

signal trig         :   std_logic_vector(1 downto 0)    :=  "00";

constant extraShift :   natural range 0 to 15   :=  adcData1_o'length - adcData1_i'length;
signal log2Avgs     :   natural range 0 to 15   :=  0;
signal numAvgs      :   unsigned(7 downto 0)    :=  to_unsigned(1,8);

signal avgCount     :   unsigned(numAvgs'length-1 downto 0) :=  (others => '0');

signal state        :   t_status    :=  idle;

signal adc1, adc1_tmp, adc2, adc2_tmp   :   signed(EXT_WIDTH-1 downto 0) :=  (others => '0');

begin

log2Avgs <= to_integer(unsigned(reg0(3 downto 0)));
numAvgs <= shift_left(to_unsigned(1,numAvgs'length),log2Avgs);

adc1_tmp <= resize(signed(adcData1_i),adc1_tmp'length);
adc2_tmp <= resize(signed(adcData2_i),adc2_tmp'length);

MainProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        avgCount <= (others => '0');
        adc1 <= (others => '0');
        adc2 <= (others => '0');
        valid_o <= '0';
        adcData1_o <= (others => '0');
        adcData2_o <= (others => '0');
    elsif rising_edge(clk) then
        if avgCount < numAvgs - 1 then
            adc1 <= adc1 + adc1_tmp;
            adc2 <= adc2 + adc2_tmp;
            avgCount <= avgCount + 1;
            valid_o <= '0';
        elsif avgCount = numAvgs - 1 then
            adcData1_o <= std_logic_vector(resize(shift_right(adc1 + adc1_tmp,log2Avgs + extraShift),adcData1_o'length));
            adcData2_o <= std_logic_vector(resize(shift_right(adc2 + adc2_tmp,log2Avgs + extraShift),adcData2_o'length));
            avgCount <= (others => '0');
            valid_o <= '1';
            adc1 <= (others => '0');
            adc2 <= (others => '0');
        else
            valid_o <= '0';
            avgCount <= (others => '0');       
            adc1 <= (others => '0'); 
            adc2 <= (others => '0'); 
        end if;
    end if;
end process;

end architecture Behavioural;