library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.CustomDataTypes.all;

--
-- This module simplifies writing and reading to a block memory
--
entity BlockMemoryController is
    port(
        wrclk       :   in  std_logic;
        rdclk       :   in  std_logic;
        aresetn     :   in  std_logic;
        --Write data
        data_i      :   in  t_mem_data_ext;
        valid_i     :   in  std_logic;
        --Read data
        bus_i       :   in  t_mem_bus_master;
        bus_o       :   out t_mem_bus_slave_ext
    );
end BlockMemoryController;

architecture Behavioral of BlockMemoryController is
--
-- The block memory component
--
COMPONENT BlockMemDPG
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(107 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(107 DOWNTO 0)
  );
END COMPONENT;

subtype t_mem_addr_local is unsigned(11 downto 0);
constant MAX_ADDR   :   t_mem_addr_local  :=  (others => '1');

type t_status_local is (idle,waiting,outputting);
signal rd_state    :   t_status_local;

signal addra    :   t_mem_addr_local;
signal addrb    :   t_mem_addr_local;
signal wea      :   std_logic_vector(0 downto 0);
signal resetSync:   std_logic_vector(1 downto 0);

signal state    :   unsigned(1 downto 0);

begin

--
-- Instantiate block memory
--
addrb <= resize(bus_i.addr,addrb'length);
BM: BlockMemDPG
port map(
    clka    =>  wrclk,
    wea     =>  wea,
    addra   =>  std_logic_vector(addra),
    dina    =>  data_i,
    clkb    =>  rdclk,
    addrb   =>  std_logic_vector(addrb),
    doutb   =>  bus_o.data
);
--
-- Generate write-clock synchronous reset signal
--
signal_sync(wrclk,aresetn,bus_i.reset,resetSync);
--
-- Write data to memory. The process counts how many samples it has written.
-- When the primary input bus tells it to reset, it resets the current address
-- to 0.
--
wea(0) <= valid_i;
bus_o.last <= resize(addra,t_mem_addr'length);
WriteProc: process(wrclk,aresetn) is
begin
    if aresetn = '0' then
        addra <= (others => '0');
    elsif rising_edge(wrclk) then
        if resetSync = "01" then
            addra <= (others => '0');
        elsif valid_i = '1' and addra < MAX_ADDR then
            addra <= addra + 1;
        end if;
    end if;
end process;
--
-- Reads data from the memory based on address provided by the user.
-- Note that we need an extra clock cycle to read data compared to writing it
--
ReadProc: process(rdclk,aresetn) is
begin
    if aresetn = '0' then
        rd_state <= idle;
        bus_o.valid <= '0';
        bus_o.status <= idle;
    elsif rising_edge(rdclk) then
        ReadCase: case rd_state is
            when idle =>
                bus_o.valid <= '0';
                if bus_i.trig = '1' then
                    rd_state <= outputting;
                    bus_o.status <= reading;
                else
                    bus_o.status <= idle;
                end if;
                
            when outputting =>
                bus_o.valid <= '1';
                rd_state <= idle;
                bus_o.status <= idle;
            
            when others => null;
        end case;    
    end if;
end process;

end Behavioral;
