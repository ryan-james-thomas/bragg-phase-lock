library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;
 
entity topmod is
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
        
        m_axis3_tdata   :   out std_logic_vector(31 downto 0);
        m_axis3_tvalid  :   out std_logic
    );
end topmod;
 
 
architecture Behavioural of topmod is

--
-- Communication signals
--
signal comState :   t_status    :=  idle;
signal bus_m    :   t_axi_bus_master   :=  INIT_AXI_BUS_MASTER;
signal bus_s    :   t_axi_bus_slave   :=  INIT_AXI_BUS_SLAVE;

--
-- DDS parameters
--
signal f0, df       :   unsigned(31 downto 0)   :=  (others => '0');
signal pow          :   unsigned(31 downto 0)   :=  (others => '0');



begin
 
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;


m_axis1_tdata <= std_logic_vector(pow) & std_logic_vector(f0 + df);
m_axis1_tvalid <= '1';
m_axis2_tdata <= std_logic_vector(f0 - df);
m_axis2_tvalid <= '1';
m_axis3_tdata <= std_logic_vector(shift_left(df,3));
m_axis3_tvalid <= '1';
 
Parse: process(clk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        bus_s <= INIT_AXI_BUS_SLAVE;
        f0 <= to_unsigned(37580964,f0'length);  --35 MHz
        df <= to_unsigned(1073742,df'length);   --1 MHz
        pow <= to_unsigned(0,pow'length);
    elsif rising_edge(clk) then
        FSM: case(comState) is
            when idle =>
                bus_s.resp <= "00";
                if bus_m.valid(0) = '1' then
                    comState <= processing;
                end if;
 
            when processing =>
                AddrCase: case(bus_m.addr) is
                    when X"00000000" => rw(bus_m,bus_s,comState,f0);
                    when X"00000004" => rw(bus_m,bus_s,comState,df);
                    when X"00000008" => rw(bus_m,bus_s,comState,pow);
                    
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