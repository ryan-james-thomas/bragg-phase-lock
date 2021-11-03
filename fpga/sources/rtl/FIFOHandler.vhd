library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity FIFOHandler is
    port(
        wr_clk      :   in  std_logic;
        rd_clk      :   in  std_logic;
--        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        data_i      :   in  std_logic_vector(FIFO_WIDTH-1 downto 0);
        valid_i     :   in  std_logic;
        
        bus_m       :   in  t_fifo_bus_master;
        bus_s       :   out t_fifo_bus_slave
    );
end FIFOHandler;

architecture Behavioral of FIFOHandler is

COMPONENT FIFO_Continuous
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

signal rst  :   std_logic;

begin

rst <= not(aresetn) or bus_m.reset;

ValidDelay: process(rd_clk,aresetn) is
begin
    if aresetn = '0' then
        bus_s.valid <= '0';
    elsif rising_edge(rd_clk) then
        if bus_m.rd_en = '1' then
            bus_s.valid <= '1';
        else
            bus_s.valid <= '0';
        end if;
    end if;    
end process;

FIFO: FIFO_Continuous
port map(
    wr_clk      =>  wr_clk,
    rd_clk      =>  rd_clk,
--    clk         =>  clk,
    rst         =>  rst,
    din         =>  data_i,
    wr_en       =>  valid_i,
    rd_en       =>  bus_m.rd_en,
    dout        =>  bus_s.data,
    full        =>  bus_s.full,
    empty       =>  bus_s.empty
);


end Behavioral;
