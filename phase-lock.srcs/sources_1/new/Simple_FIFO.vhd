library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity Simple_FIFO is
    generic(
        DATA_WIDTH  :   natural :=  16
    );
    port (
        wr_clk  :   in  std_logic;
        rd_clk  :   in  std_logic;
        aresetn :   in  std_logic;
        
        data_i  :   in  std_logic_vector(31 downto 0);
        data_o  :   out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end Simple_FIFO;

architecture Behavioral of Simple_FIFO is

constant BUF_SIZE   :   integer :=  4;
constant BUF_LENGTH :   integer :=  2;

subtype t_adc_data is std_logic_vector(DATA_WIDTH-1 downto 0);
type t_adc_fifo is array(integer range 0 to BUF_SIZE-1) of t_adc_data;

signal fifo_data        :   t_adc_fifo  :=  (others => (others => '0'));
signal wr_ptr, rd_ptr   :   unsigned(BUF_LENGTH-1 downto 0)   :=  (others => '0');

begin

WriteProc: process(wr_clk,aresetn) is
begin
    if aresetn = '0' then
        fifo_data <= (others => (others => '0'));
        wr_ptr <= (others => '0');
    elsif rising_edge(wr_clk) then
        fifo_data(to_integer(wr_ptr)) <= data_i;
        wr_ptr <= wr_ptr + 1;
    end if;    
end process;

ReadProc: process(rd_clk,aresetn) is
begin
    if aresetn = '0' then
        rd_ptr <= (others => '0');
    elsif rising_edge(rd_clk) then
        if rd_ptr /= wr_ptr then
            data_o <= fifo_data(to_integer(rd_ptr));
            rd_ptr <= rd_ptr + 1;
        end if;        
    end if;    
end process;

end Behavioral;
