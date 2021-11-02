library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity AXI_Tester is
    port (
        --
        -- Clocking and reset
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Main AXI data to transfer
        --
        axi_addresses   :   in  t_axi_addr_array;
        axi_data        :   in  t_axi_data_array;
        start_i         :   in  std_logic;
        --
        -- Single data to transfer
        --
        axi_addr_single :   in  t_axi_addr;
        axi_data_single :   in  t_axi_data;
        start_single_i  :   in  std_logic_vector(1 downto 0);
        --
        -- Signals
        --
        bus_m           :   out t_axi_bus_master;
        bus_s           :   in  t_axi_bus_slave
    );
end entity AXI_Tester;

architecture rtl of AXI_Tester is

type t_status_local is (idle,waiting,reading,writing,processing,running,finishing,counting);

signal addrIndex    :   natural;
signal startAddr    :   natural;

signal state        :   t_status_local;   
signal axiCount     :   natural;

begin
    

AXITransfer: process(clk,aresetn) is
begin
    if aresetn = '0' then
        addrIndex <= 0;
        state <= idle;
        axiCount <= 0;
        bus_m <= INIT_AXI_BUS_MASTER;
    elsif rising_edge(clk) then
        AXICase: case(state) is
            when idle =>
                if start_i = '1' then
                    state <= writing;
                    addrIndex <= 0;
                elsif start_single_i(1) = '1' then
                    bus_m.addr <= axi_addr_single;
                    bus_m.valid <= "11";
                    state <= waiting;
                elsif start_single_i(0) = '1' then
                    bus_m.addr <= axi_addr_single;
                    bus_m.data <= axi_data_single;
                    bus_m.valid <= "01";
                    state <= waiting;
                end if;
                
            when writing =>
                    bus_m.addr <= axi_addresses(addrIndex);
                    bus_m.data <= axi_data(addrIndex);
                    bus_m.valid <= "01";
                    state <= waiting;
                
            when waiting =>
                if bus_s.resp = "01" then
                    bus_m.valid <= "00";
                    if start_single_i(1) = '1' or start_single_i(0) = '1' then
                        state <= idle;
                    elsif addrIndex < axi_addresses'length - 1 then
                        addrIndex <= addrIndex + 1;
                        state <= counting;
                        axiCount <= 0;
                    else
                        state <= idle;
                    end if;
                elsif bus_s.resp = "11" then
                    bus_m.valid <= "00";
                    state <= idle;
                end if;
                
            when counting => 
                if axiCount < 4 then
                    axiCount <= axiCount + 1;
                else
                    axiCount <= 0;
                    state <= writing;
                end if;
                
            when others => null;
        end case;
    end if;
end process;  
    
end architecture rtl;