library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

--
-- This module simplifies writing data from a pair of ADCs to a block memory and reading it back later.
-- The read and write clocks can be different.
--
entity SaveADCData is
    port(
        readClk     :   in  std_logic;          --Clock for reading data
        writeClk    :   in  std_logic;          --Clock for writing data
        aresetn     :   in  std_logic;          --Asynchronous reset
        
        data_i      :   in  std_logic_vector;   --Input data, maximum length of 32 bits
        valid_i     :   in  std_logic;          --High for one clock cycle when data_i is valid
        
        numSamples  :   in  t_mem_addr;         --Number of samples to save
        trig_i      :   in  std_logic;          --Start trigger
        
        bus_m       :   in  t_mem_bus_master;   --Master memory bus
        bus_s       :   out t_mem_bus_slave     --Slave memory bus
    );
end SaveADCData;

architecture Behavioral of SaveADCData is
--
-- This is the actual block memory component
--
COMPONENT BlockMem
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

signal wea              :   std_logic_vector(0 downto 0)    :=  "0";                --Write-enable signal for the block memory
signal addra            :   t_mem_addr                      :=  (others => '0');    --Write address

signal state            :   natural range 0 to 3            :=  0;                  --State of the state machine controlling the read process
signal dina             :   std_logic_vector(31 downto 0)   :=  (others => '0');    --Data to write

signal resetSync, trigSync        :   std_logic_vector(1 downto 0)    :=  "00";     --Reset and trigger signals synchronized to the write clock

type t_state_local is (idle,write_enabled);
signal writeState    :   t_state_local;                                             --State of the state machine controlling the write process

signal enable  :   std_logic;                                                       --Enable signal for the writing process

begin
--
-- Match input data to write data length
--
dina(data_i'length-1 downto 0) <= data_i;
dina(dina'length-1 downto data_i'length) <= (others => '0');
--
-- Generate writeClk-synchronous address reset signal
--
signal_sync(writeClk,aresetn,bus_m.reset,resetSync);
signal_sync(writeClk,aresetn,trig_i,trigSync);
--
-- Instantiate the block memory
--
BlockMem_inst : BlockMem
PORT MAP (
    clka => writeClk,
    wea => wea,
    addra => std_logic_vector(addra),
    dina => dina,
    clkb => readClk,
    addrb => std_logic_vector(bus_m.addr),
    doutb => bus_s.data
);

--
-- Write ADC data to memory
-- On the rising edge of 'trig' we write numSamples to memory
-- On the rising edge of the reset signal we reset the address and state
--
wea(0) <= valid_i and enable;
bus_s.last <= addra;
WriteProc: process(writeClk,aresetn) is
begin
    if aresetn = '0' then
        addra <= (others => '0');
        writeState <= idle;
    elsif rising_edge(writeClk) then
        if resetSync = "01" then
            addra <= (others => '0');
            writeState <= idle;
        else
            WriteCase: case writeState is
                when idle =>
                    if trigSync = "01" then
                        addra <= (others => '0');
                        enable <= '1';
                        writeState <= write_enabled;
                    else
                        enable <= '0';
                    end if;
                    
                when write_enabled =>
                    if valid_i = '1' and addra < numSamples then
                        addra <= addra + 1;
                    elsif addra >= numSamples then
                        enable <= '0';
                        writeState <= idle;
                    end if;
            end case;
        end if;
    end if;
end process;
--
-- Reads data from the memory address provided by the user
-- Note that we need an extra clock cycle to read data compared to writing it
--
ReadProc: process(readClk,aresetn) is
begin
    if aresetn = '0' then
        state <= 0;
        bus_s.valid <= '0';
        bus_s.status <= idle;
    elsif rising_edge(readClk) then
        if state = 0 and bus_m.trig = '1' then
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
