library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;


entity BlockMemHandlerRAM is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        bus_m_wr    :   in  t_mem_bus_master;
        bus_m_rd    :   in  t_mem_bus_master;
        bus_s       :   out t_mem_bus_slave
    );
end BlockMemHandlerRAM;

architecture Behavioral of BlockMemHandlerRAM is

COMPONENT BlockMem
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;

signal trig         :   std_logic_vector(1 downto 0)    :=  "00";
signal wea          :   std_logic_vector(0 downto 0)    :=  "0";
signal addra        :   t_mem_addr :=  (others => '0');

signal state        :   natural range 0 to 3    :=  0;
signal dina         :   std_logic_vector(15 downto 0)   :=  (others => '0');

begin

dina(bus_m_wr.data'length-1 downto 0) <= bus_m_wr.data;
dina(dina'length-1 downto bus_m_wr.data'length) <= (others => '0');

--
-- Instantiate the block memory
--
BlockMem_inst : BlockMem
PORT MAP (
    clka => clk,
    wea => wea,
    addra => std_logic_vector(bus_m_wr.addr),
    dina => dina,
    clkb => clk,
    addrb => std_logic_vector(bus_m_rd.addr),
    doutb => bus_s_rd.data
);

--
-- Write ADC data to memory
-- On the rising edge of 'trig' we write numSamples to memory
-- On the falling edge of 'trig' we reset the counter
--
wea(0) <= bus_m_wr.trig;
WriteProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        bus_s.last <= (others => '0');
    elsif rising_edge(clk) then
        if bus_m_wr.reset = '1' then
            bus_s.last <= (others => '0');
        elsif bus_m_wr.trig = '1' and bus_m_wr.addr > bus_s.last then
            bus_s.last <= bus_m_wr.addr;
        end if;
    end if;
end process;

--
-- Reads data from the memory address provided by the user
-- Note that we need an extra clock cycle to read data compared to writing it
--
ReadProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        state <= 0;
        bus_s.valid <= '0';
        bus_s.status <= idle;
    elsif rising_edge(clk) then
        if state = 0 and bus_m_rd.trig = '1' then
            state <= 1;
            bus_s.valid <= '0';
            bus_s.status <= waiting;
        elsif state > 0 and state < 2 then
            state <= state + 1;
        elsif state = 2 then
            state <= 0;
            bus_s.valid <= '1';
            bus_s.status <= finishing;
        else
            bus_s.valid <= '0';
            bus_s.status <= idle;
        end if;
    end if;
end process;

end Behavioral;
