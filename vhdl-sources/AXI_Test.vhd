library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;
 
entity AXI_Test is
    port (
        clk     :   in  std_logic;
        aresetn :   in  std_logic;
 
        addr_i          :   in  unsigned(AXI_ADDR_WIDTH-1 downto 0);            --Address out
        writeData_i     :   in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to write
        dataValid_i     :   in  std_logic_vector(1 downto 0);                   --Data valid out signal
        readData_o      :   out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0);                   --Response in
        
        m_axis1_tdata    :   out std_logic_vector(63 downto 0);
        m_axis1_tvalid   :   out std_logic;
        
        m_axis2_tdata   :   out std_logic_vector(31 downto 0);
        m_axis2_tvalid  :   out std_logic;
        
        s_axis1_tdata   :   in  std_logic_vector(15 downto 0);
        s_axis1_tvalid  :   in  std_logic;
        
        s_axis2_tdata   :   in  std_logic_vector(15 downto 0);
        s_axis2_tvalid  :   in  std_logic;  
        
        m_axis_tdata   :    out std_logic_vector(31 downto 0);
        m_axis_tvalid  :    out std_logic
    );
end AXI_Test;
 
 
architecture Behavioural of AXI_Test is
 
signal comState :   t_status    :=  idle;
 
signal bus_m    :   t_axi_bus_master   :=  INIT_AXI_BUS_MASTER;
signal bus_s    :   t_axi_bus_slave   :=  INIT_AXI_BUS_SLAVE;
signal a        :   std_logic   :=  '0';
signal b        :   std_logic_vector(15 downto 0)   :=  (others => '0');
signal c        :   unsigned(23 downto 0)   :=  (others => '0');
signal d        :   signed(23 downto 0)   :=  (others => '0');
signal ftw1, ftw2      :   std_logic_vector(31 downto 0)   :=  (others => '0');
signal pow1      :   std_logic_vector(31 downto 0)   :=  (others => '0');
 
begin
 
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;

m_axis1_tdata <= pow1 & ftw1;
m_axis1_tvalid <= '1';
m_axis2_tdata <= ftw2;
m_axis2_tvalid <= '1';

m_axis_tdata <= std_logic_vector(shift_left(signed(s_axis1_tdata),4)) & std_logic_vector(shift_left(signed(s_axis2_tdata),4));
m_axis_tvalid <= s_axis1_tvalid or s_axis2_tvalid;
 
 
Parse: process(clk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        bus_s <= INIT_AXI_BUS_SLAVE;
        ftw1 <= std_logic_vector(to_unsigned(1073742,ftw1'length));
        ftw2 <= std_logic_vector(to_unsigned(1073742,ftw2'length));
        pow1 <= std_logic_vector(to_unsigned(0,pow1'length));
    elsif rising_edge(clk) then
        FSM: case(comState) is
            when idle =>
                bus_s.resp <= "00";
                if bus_m.valid(0) = '1' then
                    comState <= processing;
                end if;
 
            when processing =>
                AddrCase: case(bus_m.addr) is
                    when X"00000000" => rw(bus_m,bus_s,comState,a);
                    when X"00000004" => rw(bus_m,bus_s,comState,b);
                    when X"00000008" => rw(bus_m,bus_s,comState,c);
                    when X"0000000c" => rw(bus_m,bus_s,comState,d);
                    when X"00000010" => rw(bus_m,bus_s,comState,ftw1);
                    when X"00000014" => rw(bus_m,bus_s,comState,ftw2);
                    when X"00000018" => rw(bus_m,bus_s,comState,pow1);
                    
                    when others => 
                        comState <= finishing;
                        bus_s.resp <= "11";
                end case;
 
            when finishing =>
                bus_s.resp <= "00";
                comState <= idle;
 
            when others => comState <= idle;
        end case;
    end if;
end process;
 
end architecture Behavioural;