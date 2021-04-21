library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;
 
entity topmod is
    port (
        sysclk          :   in  std_logic;
        adcclk          :   in  std_logic;
        aresetn         :   in  std_logic;
 
        addr_i          :   in  unsigned(AXI_ADDR_WIDTH-1 downto 0);            --Address out
        writeData_i     :   in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to write
        dataValid_i     :   in  std_logic_vector(1 downto 0);                   --Data valid out signal
        readData_o      :   out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0);                   --Response in
        
        m_axis_tdata    :   out std_logic_vector(31 downto 0);
        m_axis_tvalid   :   out std_logic;
        
        adcData_i       :   in  std_logic_vector(31 downto 0)
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
        reg0            :   in  t_param_reg;        --Bits [3,0]: log2(cicRate)
        regValid_i      :   in  std_logic;
        
        iq_o            :   out t_iq_data;          --Output I/Q data
        
        phase_o         :   out t_phase;            --Output phase
        valid_o         :   out std_logic           --Output phase valid signal
    );
end component;

component BlockMemHandler is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        data_i      :   in  std_logic_vector;
        valid_i     :   in  std_logic;
        
        bus_m       :   in  t_mem_bus_master;
        bus_s       :   out t_mem_bus_slave
    );
end component;

component PhaseControl is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;

        reg0        :   in  t_param_reg;

        phase_i     :   in  t_phase;
        valid_i     :   in  std_logic;
        phase_c     :   in  t_phase;

        dds_phase_o :   out t_dds_phase;
        act_phase_o :   out unsigned(CORDIC_WIDTH-1 downto 0);
        valid_o     :   out std_logic
    );
end component;

component FIFOHandler is
    port(
        wr_clk      :   in  std_logic;
        rd_clk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        data_i      :   in  std_logic_vector(FIFO_WIDTH-1 downto 0);
        valid_i     :   in  std_logic;
        
        bus_m       :   in  t_fifo_bus_master;
        bus_s       :   out t_fifo_bus_slave
    );
end component;

--
-- Testing
--
COMPONENT CIC_BigDecimation
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(55 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC
  );
END COMPONENT;

constant CIC_SHIFT  :   natural :=  39;
signal adcCICvalid_o, adcCICvalid_i  :   std_logic;
signal adcCICdata   :   std_logic_vector(55 downto 0);
signal adcCIC       :   signed(15 downto 0);

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
signal regPhase     :   t_param_reg :=  (others => '0');
signal regPhaseValid:   std_logic   :=  '0';

signal iqData       :   t_iq_data   :=  INIT_IQ_DATA;

--
-- Phase control signals
--
signal regPhaseControl  :   t_param_reg;
signal phaseControlSig  :   t_phase;
signal powControl       :   t_dds_phase;
signal powControlValid  :   std_logic;
signal actPhase         :   unsigned(CORDIC_WIDTH-1 downto 0);

--
-- Block memory signals
--
signal topReg       :   t_param_reg;
signal mem_bus      :   t_mem_bus   :=  INIT_MEM_BUS;
signal memSwitch    :   std_logic_vector(3 downto 0);
signal memData_i    :   std_logic_vector(15 downto 0);
signal memValid_i   :   std_logic;

--
-- FIFO signals
--
constant NUM_FIFOS  :   natural :=  5;
type t_fifo_data_array is array(natural range <>) of std_logic_vector(FIFO_WIDTH-1 downto 0);
signal fifoData     :   t_fifo_data_array(NUM_FIFOS-1 downto 0);
signal fifoValid    :   std_logic_vector(NUM_FIFOS-1 downto 0);
signal fifo_bus     :   t_fifo_bus_array(NUM_FIFOS-1 downto 0)  :=  (others => INIT_FIFO_BUS);
signal fifoReg      :   t_param_reg;
signal enableFIFO   :   std_logic;
signal debugCount   :   unsigned(7 downto 0);

signal resetExtended:   std_logic;
signal resetCount   :   unsigned(7 downto 0);

begin

CICBig: CIC_BigDecimation
PORT MAP (
    aclk                =>  clk,
    aresetn             =>  aresetn,
    s_axis_data_tdata   =>  adcData_i,
    s_axis_data_tvalid  =>  '1',
    s_axis_data_tready  =>  open,
    m_axis_data_tdata   =>  adcCICdata,
    m_axis_data_tvalid  =>  adcCICvalid_o
);

adcCIC <= resize(shift_right(signed(adcCICdata),CIC_SHIFT),adcCIC'length);


--
-- DDS output signals
--
ftw1 <= f0 + df;
ftw2 <= f0 - df;
DDS_2Channel: DualChannelDDS
port map(
    clk             =>  adcclk,
    aresetn         =>  aresetn,
    pow1            =>  powControl,
    ftw1            =>  ftw1,
    ftw2            =>  ftw2,
    m_axis_tvalid   =>  m_axis_tvalid,
    m_axis_tdata    =>  m_axis_tdata
);

--
-- Phase calculation
--
adc <= signed(adcData_i(adc'length-1 downto 0));
--df8 <= shift_left(df,to_integer(unsigned(topReg(7 downto 4))));
RegPhaseValid_Sync: process(adcclk,aresetn) is
begin
    if aresetn = '0' then
        regPhaseValid <= '0';
    elsif rising_edge(adcclk) then
        if triggers(0) = '1' then
            regPhaseValid <= '1';
        else
            regPhaseValid <= '0';
        end if;
    end if;
end process;

PhaseCalc: PhaseCalculation
port map(
    clk         =>  adcclk,
    aresetn     =>  aresetn,
    adcData_i   =>  adc,
    freq_i      =>  df8,
    reg0        =>  regPhase,
    regValid_i  =>  regPhaseValid,
    iq_o        =>  iqData,
    phase_o     =>  phase,
    valid_o     =>  phaseValid
);

--
-- Phase control
--
MainPhaseControl: PhaseControl
port map(
    clk         =>  adcclk,
    aresetn     =>  aresetn,
    reg0        =>  regPhaseControl,
    phase_i     =>  phase,
    valid_i     =>  phaseValid,
    phase_c     =>  phaseControlSig,
    dds_phase_o =>  powControl,
    act_phase_o =>  actPhase,
    valid_o     =>  powControlValid
);


--
-- Save data
--
--memSwitch <= topReg(3 downto 0);
--mem_bus.m.reset <= triggers(1); --This serves as a "start" trigger, and the memory will save data up to its size
--memData_i <=    std_logic_vector(resize(signed(adcData_i),memData_i'length)) when memSwitch = X"F" else
--                std_logic_vector(resize(phase,memData_i'length));
--memValid_i <=   '1' when memSwitch = X"F" else
--                phaseValid;      

--SaveData: BlockMemHandler
--port map(
--    clk         =>  clk,
--    aresetn     =>  aresetn,
--    data_i      =>  memData_i,
--    valid_i     =>  memValid_i,
--    bus_m       =>  mem_bus.m,
--    bus_s       =>  mem_bus.s
--);
               
--
-- FIFO buffering for long data sets
--
ResetExtend: process(adcclk,aresetn) is
begin
    if aresetn = '0' then
        resetExtended <= '0';
        resetCount <= (others => '0');
    elsif rising_edge(adcclk) then
        if triggers(2) = '1' then
            resetExtended <= '1';
            resetCount <= X"01";
        elsif resetCount < 20 then
            resetCount <= resetCount + 1;
        else
            resetExtended <= '0';
        end if;
    end if;
end process;

enableFIFO <= fifoReg(0);
--fifoData(0) <= std_logic_vector(debugCount) & std_logic_vector(resize(phase,FIFO_WIDTH-8));
fifoData(0) <= std_logic_vector(resize(phase,FIFO_WIDTH));
fifoData(1) <= std_logic_vector(resize(actPhase,FIFO_WIDTH));
fifoData(2) <= std_logic_vector(resize(powControl,FIFO_WIDTH));
fifoData(3) <= std_logic_vector(resize(iqData.I,FIFO_WIDTH));
fifoData(4) <= std_logic_vector(resize(iqData.Q,FIFO_WIDTH));
FIFO_GEN: for I in 0 to NUM_FIFOS-1 generate
    fifo_bus(I).m.reset <= resetExtended;
    
    NORMAL_OP: if I < 3 generate
        fifoValid(I) <= powControlValid and enableFIFO;
        PhaseMeas_FIFO_NORMAL_X: FIFOHandler
        port map(
            wr_clk      =>  adcclk,
            rd_clk      =>  sysclk,
            aresetn     =>  aresetn,
            data_i      =>  fifoData(I),
            valid_i     =>  fifoValid(I),
            bus_m       =>  fifo_bus(I).m,
            bus_s       =>  fifo_bus(I).s
        );
    end generate NORMAL_OP;
    
    ABNORMAL_OP: if I >= 3 generate
        fifoValid(I) <= iqData.valid and enableFIFO;
        PhaseMeas_FIFO_IQ_X: FIFOHandler
        port map(
            wr_clk      =>  adcclk,
            rd_clk      =>  sysclk,
            aresetn     =>  aresetn,
            data_i      =>  fifoData(I),
            valid_i     =>  fifoValid(I),
            bus_m       =>  fifo_bus(I).m,
            bus_s       =>  fifo_bus(I).s
        );
    end generate ABNORMAL_OP;
end generate FIFO_GEN;

--DebugCountProc: process(clk,aresetn) is
--begin
--    if aresetn = '0' then
--        debugCount <= (others => '0');
--    elsif fifoValid(1) = '1' then
--        debugCount <= debugCount + X"1";
--    end if;
--end process;

--PhaseMeas_FIFO: FIFOHandler
--port map(
--    clk         =>  clk,
--    aresetn     =>  aresetn,
--    data_i      =>  fifoData(0),
--    valid_i     =>  fifoValid(0),
--    bus_m       =>  fifo_bus(0).m,
--    bus_s       =>  fifo_bus(0).s
--);


--
-- Parse AXI data
-- 
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;
Parse: process(sysclk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        bus_s <= INIT_AXI_BUS_SLAVE;
        triggers <= (others => '0');
        f0 <= to_unsigned(37580964,f0'length);  --35 MHz
        df <= to_unsigned(1073742,df'length);   --1 MHz
        df8 <= to_unsigned(8*1073742,df8'length);
        phaseControlSig <= to_signed(0,phaseControlSig'length);
        regPhase <= X"00000a08";                --CIC filter decimation rate of 2^8 = 256
        regPhaseControl <= X"000000" & X"08";
        phaseControlSig <= (others => '0');
        topReg <= (others => '0');
        fifoReg <= (others => '0');
        
        mem_bus.m.addr <= (others => '0');
        mem_bus.m.trig <= '0';
        mem_bus.m.status <= idle;
        
        fifo_bus(0).m.status <= idle;
        fifo_bus(1).m.status <= idle;
        fifo_bus(2).m.status <= idle;
        fifo_bus(3).m.status <= idle;
        fifo_bus(4).m.status <= idle;
    elsif rising_edge(sysclk) then
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
                        when X"000004" => rw(bus_m,bus_s,comState,topReg);
                        when X"000008" => rw(bus_m,bus_s,comState,f0);
                        when X"00000C" => rw(bus_m,bus_s,comState,df);
                        when X"000010" => rw(bus_m,bus_s,comState,phaseControlSig);
                        when X"000014" => rw(bus_m,bus_s,comState,regPhase);
                        when X"000018" => rw(bus_m,bus_s,comState,regPhaseControl);
                        when X"00001C" => rw(bus_m,bus_s,comState,fifoReg);
                        when X"000020" => fifoRead(bus_m,bus_s,comState,fifo_bus(0).m,fifo_bus(0).s);
                        when X"000024" => fifoRead(bus_m,bus_s,comState,fifo_bus(1).m,fifo_bus(1).s);
                        when X"000028" => fifoRead(bus_m,bus_s,comState,fifo_bus(2).m,fifo_bus(2).s);
                        when X"00002C" => fifoRead(bus_m,bus_s,comState,fifo_bus(3).m,fifo_bus(3).s);
                        when X"000030" => fifoRead(bus_m,bus_s,comState,fifo_bus(4).m,fifo_bus(4).s);
                        when X"000034" => rw(bus_m,bus_s,comState,df8);
                        
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
--                            when X"000004" => fifoRead(bus_m,bus_s,comState,fifo_bus.m,fifo_bus.s);
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;
                        
                    --
                    -- Read phase data
                    --
--                    when X"02" => memRead(bus_m,bus_s,comState,mem_bus.m,mem_bus.s); 
                        
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