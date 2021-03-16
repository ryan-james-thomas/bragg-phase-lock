library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;
 
entity topmod is
    port (
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
 
        addr_i          :   in  unsigned(AXI_ADDR_WIDTH-1 downto 0);            --Address out
        writeData_i     :   in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to write
        dataValid_i     :   in  std_logic_vector(1 downto 0);                   --Data valid out signal
        readData_o      :   out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0);                   --Response in
        
        m_axis_tdata    :   out std_logic_vector(31 downto 0);
        m_axis_tvalid   :   out std_logic;
        
        adcData_i       :   in  std_logic_vector(15 downto 0)
    );
end topmod;
 
 
architecture Behavioural of topmod is

ATTRIBUTE X_INTERFACE_INFO : STRING;
ATTRIBUTE X_INTERFACE_INFO of m_axis_tdata: SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TDATA";
ATTRIBUTE X_INTERFACE_INFO of m_axis_tvalid: SIGNAL is "xilinx.com:interface:axis:1.0 m_axis TVALID";
ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
ATTRIBUTE X_INTERFACE_PARAMETER of m_axis_tdata: SIGNAL is "CLK_DOMAIN system_processing_system7_0_0_FCLK_CLK0,FREQ_HZ 125000000";
ATTRIBUTE X_INTERFACE_PARAMETER of m_axis_tvalid: SIGNAL is "CLK_DOMAIN system_processing_system7_0_0_FCLK_CLK0,FREQ_HZ 125000000";

component DualChannelDDS is
    port(
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        
        pow1            :   in  t_dds_phase;
        ftw1            :   in  t_dds_phase;
        ftw2            :   in  t_dds_phase;
        
        m_axis_tdata    :   out std_logic_vector(31 downto 0);
        m_axis_tvalid   :   out std_logic
    );    
end component;

component PhaseCalculation is
    port(
        clk             :   in  std_logic;          --Master system clock
        aresetn         :   in  std_logic;          --Asynchronous active-low reset
        
        adcData_i       :   in  t_adc;              --ADC data synchronous with clk
        
        freq_i          :   in  t_dds_phase;        --Frequency difference used for mixing DDS             
        reg0            :   in  t_param_reg;        --Bits [31,28]: memSwitch, [3,0]: log2(cicRate)
        regValid_i      :   in  std_logic;
        
        mem_bus_m       :   in  t_mem_bus_master;   --Master memory bus
        mem_bus_s       :   out t_mem_bus_slave;    --Slave memory bus
        
        phase_o         :   out t_phase;            --Output phase
        valid_o         :   out std_logic           --Output phase valid signal
    );
end component;


--
-- Communication signals
--
signal comState :   t_status            :=  idle;
signal bus_m    :   t_axi_bus_master    :=  INIT_AXI_BUS_MASTER;
signal bus_s    :   t_axi_bus_slave     :=  INIT_AXI_BUS_SLAVE;
signal triggers :   t_param_reg         :=  (others => '0');

--
-- DDS parameters
--
signal f0, df,df8   :   t_dds_phase     :=  (others => '0');
signal pow          :   t_dds_phase     :=  (others => '0');
signal ftw1, ftw2   :   t_dds_phase     :=  (others => '0');


--
-- Phase calculation signals
--
signal adc          :   t_adc       :=  (others => '0');
signal phase        :   t_phase     :=  (others => '0');
signal phaseValid   :   std_logic   :=  '0';
signal mem_bus      :   t_mem_bus   :=  INIT_MEM_BUS;
signal regPhase     :   t_param_reg :=  (others => '0');
signal regPhaseValid:   std_logic   :=  '0';

begin

--
-- DDS output signals
--

ftw1 <= f0 + df;
ftw2 <= f0 - df;
DDS_2Channel: DualChannelDDS
port map(
    clk             =>  clk,
    aresetn         =>  aresetn,
    pow1            =>  pow,
    ftw1            =>  ftw1,
    ftw2            =>  ftw2,
    m_axis_tvalid   =>  m_axis_tvalid,
    m_axis_tdata    =>  m_axis_tdata
);

--
-- Phase calculation
--
adc <= signed(adcData_i(adc'length-1 downto 0));
df8 <= shift_left(df,3);
regPhaseValid <= triggers(0);
PhaseCalc: PhaseCalculation
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    adcData_i   =>  adc,
    freq_i      =>  df8,
    reg0        =>  regPhase,
    regValid_i  =>  regPhaseValid,
    mem_bus_m   =>  mem_bus.m,
    mem_bus_s   =>  mem_bus.s,
    phase_o     =>  phase,
    valid_o     =>  phaseValid
);


--
-- Parse AXI data
-- 
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;
Parse: process(clk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        bus_s <= INIT_AXI_BUS_SLAVE;
        triggers <= (others => '0');
        f0 <= to_unsigned(37580964,f0'length);  --35 MHz
        df <= to_unsigned(1073742,df'length);   --1 MHz
        pow <= to_unsigned(0,pow'length);
        regPhase <= X"00000008";                --CIC filter decimation rate of 2^8 = 256
        
        mem_bus.m.addr <= (others => '0');
        mem_bus.m.trig <= '0';
        mem_bus.m.status <= idle;
    elsif rising_edge(clk) then
        FSM: case(comState) is
            when idle =>
                triggers <= (others => '0');
                bus_s.resp <= "00";
                if bus_m.valid(0) = '1' then
                    comState <= processing;
                end if;
 
            when processing =>
                AddrCase: case(bus_m.addr(31 downto 24)) is
                    --
                    -- Parameter parsing
                    --
                    when X"00" =>
                    ParamCase: case(bus_m.addr(23 downto 0)) is
                        
                        when X"000000" => rw(bus_m,bus_s,comState,triggers);
                        when X"000004" => rw(bus_m,bus_s,comState,f0);
                        when X"000008" => rw(bus_m,bus_s,comState,df);
                        when X"00000C" => rw(bus_m,bus_s,comState,pow);
                        when X"000010" => rw(bus_m,bus_s,comState,regPhase);
                        
                        when others => 
                            comState <= finishing;
                            bus_s.resp <= "11";
                    end case;
                    
                    --
                    -- Read only cases
                    --
                    when X"01" =>
                        ParamCaseReadOnly: case(bus_m.addr(23 downto 0)) is
                            when X"000000" => readOnly(bus_m,bus_s,comState,mem_bus.s.last);
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;
                        
                    --
                    -- Read phase data
                    --
                    when X"02" =>
                        if bus_m.valid(1) = '0' then
                            bus_s.resp <= "11";
                            comState <= finishing;
                            mem_bus.m.trig <= '0';
                            mem_bus.m.status <= idle;
                        elsif mem_bus.s.valid = '1' then
                            bus_s.data <= X"0000" & mem_bus.s.data;
                            comState <= finishing;
                            bus_s.resp <= "01";
                            mem_bus.m.status <= idle;
                            mem_bus.m.trig <= '0';
                        elsif mem_bus.m.status = idle then
                            mem_bus.m.addr <= bus_m.addr(MEM_ADDR_WIDTH+1 downto 2);
                            mem_bus.m.status <= waiting;
                            mem_bus.m.trig <= '1';
                         else
                            mem_bus.m.trig <= '0';
                        end if;       
                        
                    when others => 
                        comState <= finishing;
                        bus_s.resp <= "11";             
                                                
                end case;
 
            when finishing =>
                triggers <= (others => '0');
                bus_s.resp <= "00";
                comState <= idle;
 
            when others => comState <= idle;
        end case;
    end if;
end process;
 
end architecture Behavioural;