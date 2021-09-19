library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;


entity topmod_tb is
--  Port ( );
end topmod_tb;

architecture Behavioral of topmod_tb is

component topmod is
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
end component;

component AXI_Tester is
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
end component;

COMPONENT MixerDDS_PhaseOffset
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

COMPONENT FreqPhaseStreamDDS
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;

--
-- Clocks and reset
--
constant SYS_CLK_T      :   time    :=  10 ns;
constant ADC_CLK_T      :   time    :=  10 ns;
signal sysclk, adcclk, aresetn :   std_logic;
--
-- ADC and DAC data
--
signal adcData_i    :   std_logic_vector(31 downto 0);
signal m_axis_tdata :   std_logic_vector(31 downto 0);
signal m_axis_tvalid:   std_logic;
signal enable       :   std_logic;
--
-- AXI signals
--
signal addr_i                   :   unsigned(AXI_ADDR_WIDTH-1 downto 0);
signal writeData_i, readData_o  :   std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal dataValid_i, resp_o      :   std_logic_vector(1 downto 0);
signal bus_m                    :   t_axi_bus_master;
signal bus_s                    :   t_axi_bus_slave;
--
-- ADC data generation
--
signal ddsfreq          :   std_logic_vector(31 downto 0);
signal ddsphase         :   std_logic_vector(31 downto 0);
signal ddsphaseValid    :   std_logic;
signal dds_o            :   std_logic_vector(15 downto 0);
signal ddsValid_o       :   std_logic;
signal mixPhase_slv     :   std_logic_vector(63 downto 0);

--
-- AXI data
--
constant axi_addresses   :   t_axi_addr_array(18 downto 0)  :=  (0  =>  X"00000004",
                                                                 1  =>  X"00000008",
                                                                 2  =>  X"0000000C",
                                                                 3  =>  X"00000010",
                                                                 4  =>  X"00000014",
                                                                 5  =>  X"00000018",
                                                                 6  =>  X"0000001C",
                                                                 7  =>  X"00000020",
                                                                 8  =>  X"00000024",
                                                                 9  =>  X"00000000",
                                                                10  =>  X"00000034",
                                                                11  =>  X"00000034",
                                                                12  =>  X"00000034",
                                                                13  =>  X"00000034",
                                                                14  =>  X"00000034",
                                                                15  =>  X"00000034",
                                                                16  =>  X"00000034",
                                                                17  =>  X"00000034",
                                                                18  =>  X"00000034");
                                                                 
signal axi_data         :   t_axi_data_array(axi_addresses'length - 1 downto 0);
--
-- AXI_tester signals
--
signal startAXI         :   std_logic;
signal axi_addr_single  :   t_axi_addr;
signal axi_data_single  :   t_axi_data;
signal start_single_i   :   std_logic_vector(1 downto 0);
--
-- topmod registers
--
signal triggers         :   t_param_reg;
signal topReg           :   t_param_reg;
signal f0               :   t_param_reg;
signal dfSet            :   t_param_reg;
signal dfmod            :   t_param_reg;
signal phase_c          :   t_param_reg;
signal regPhaseCalc     :   t_param_reg;
signal regPhaseControl  :   t_param_reg;
signal regControlGains  :   t_param_reg;
signal fifoReg          :   t_param_reg;

begin
--
-- Create clock
--
sys_clk_proc: process is
begin
    sysclk <= '0';
    wait for SYS_CLK_T/2;
    sysclk <= '1';
    wait for SYS_CLK_T/2;
end process;

adc_clk_proc: process is
begin
    adcclk <= '0';
    wait for ADC_CLK_T/2;
    adcclk <= '1';
    wait for ADC_CLK_T/2;
end process;
--
-- Instantiate topmod as UUT
--
uut: topmod
port map(
    sysclk      =>  sysclk,
    adcclk      =>  adcclk,
    aresetn     =>  aresetn,
    addr_i      =>  addr_i,
    writeData_i =>  writeData_i,
    dataValid_i =>  dataValid_i,
    readData_o  =>  readData_o,
    resp_o      =>  resp_o,
    m_axis_tdata=>  m_axis_tdata,
    m_axis_tvalid   =>  m_axis_tvalid,
    adcData_i   =>  adcData_i
);
--
-- Generate AXI signals
--
AXI: AXI_Tester
port map(
    clk             =>  sysClk,
    aresetn         =>  aresetn,
    axi_addresses   =>  axi_addresses,
    axi_data        =>  axi_data,
    start_i         =>  startAXI,
    axi_addr_single =>  axi_addr_single,
    axi_data_single =>  axi_data_single,
    start_single_i  =>  start_single_i,
    bus_m           =>  bus_m,
    bus_s           =>  bus_s
);
addr_i <= bus_m.addr;
writeData_i <= bus_m.data;
dataValid_i <= bus_m.valid;
bus_s.data <= readData_o;
bus_s.resp <= resp_o;
--
-- Create DDS data for testing phase measurement
--
mixPhase_slv(31 downto 0) <= std_logic_vector(resize(shift_left(unsigned(dfSet),to_integer(unsigned(topReg(3 downto 0)))),32)) when topReg(4) = '0' else
                             std_logic_vector(resize(unsigned(dfmod),32));
mixPhase_slv(63 downto 32) <= ddsphase;
DataGet : FreqPhaseStreamDDS
PORT MAP (
    aclk => adcclk,
    aresetn => aresetn,
    s_axis_phase_tvalid => '1',
    s_axis_phase_tdata => mixPhase_slv,
    m_axis_data_tvalid => ddsValid_o,
    m_axis_data_tdata => dds_o
);
--
-- Generate ADC data
--
--adcData_i <= std_logic_vector(shift_left(resize(signed(dds_o(15 downto 0)),adcData_i'length),0) + to_signed(0,adcData_i'length));
adcData_i <= X"0000" & std_logic_vector(signed(dds_o(15 downto 0))) when enable = '0' 
             else X"0000" & std_logic_vector(m_axis_tdata(15 downto 0));
--
-- Assign AXI registers
--
axi_data <= (0  =>  topReg,
             1  =>  f0,
             2  =>  dfSet,
             3  =>  dfmod,
             4  =>  phase_c,
             5  =>  regPhaseCalc,
             6  =>  regPhaseControl,
             7  =>  regControlGains,
             8  =>  fifoReg,
             9  =>  triggers,
            10  =>  X"00000000",
            11  =>  X"00020C4A",
            12  =>  X"0000000a",
            13  =>  X"000000F0",
            14  =>  X"00020C8A",
            15  =>  X"00000005",
            16  =>  X"00000A00",
            17  =>  X"00020CCA",
            18  =>  X"00000008");

--
-- Main process
--
main_proc: process
begin
    --
    -- Initiate reset
    --
    aresetn <= '0';
    -- AXI signals
    axi_addr_single <= (others => '0');
    axi_data_single <= (others => '0');
    start_single_i <= "00";
    startAXI <= '0';
    -- DDS signals
    ddsphase <= std_logic_vector(to_signed(0,ddsphase'length));
    ddsphaseValid <= '0';
    enable <= '0';
    -- Register values
    triggers        <= (0 => '1', others => '0');
    topReg          <= X"fff000" & "0011" & X"3";
    f0              <= std_logic_vector(to_unsigned(536871,32));
    dfSet           <= X"00000000";
    dfmod           <= std_logic_vector(to_unsigned(536871,32));
    phase_c         <= X"00000000";
    regPhaseCalc    <= X"00000008";
    regPhaseControl <= X"00000000";
    regControlGains <= X"0d196419";
    fifoReg <= (others => '0');
    wait for 200 ns;
    --
    -- Disable reset
    --
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(sysclk);
    --
    -- Start AXI transfer
    --
    startAXI <= '1';
    wait until rising_edge(sysclk);
    startAXI <= '0';
    enable <= '1';
--    wait for 50 us;
----    ddsphase <= std_logic_vector(to_unsigned(262144,32));
--    wait until rising_edge(sysclk);
--    axi_addr_single <= X"00000014";
--    axi_data_single <= std_logic_vector(to_signed(65536,32));
--    start_single_i <= "01";
--    wait until rising_edge(sysclk);
--    start_single_i <= "00";
    wait for 50 us;
    --
    -- Enable PID controller
    --
    axi_addr_single <= X"0000001C";
    axi_data_single <= X"00000003";   
    start_single_i <= "01";
    enable <= '1';
    wait until rising_edge(sysclk);
    start_single_i <= "00";
    wait for 150 us;
    wait until rising_edge(sysclk);
    --
    -- Change the control phase
    --
    axi_addr_single <= X"00000014";
    axi_data_single <= std_logic_vector(to_unsigned(1048576,32));   
    start_single_i <= "01";
    wait until rising_edge(sysclk);
    start_single_i <= "00";
    
    
--    axiAddr2 <= X"00000004";
--    axiData2 <= X"00000023";
--    startAxi <= '1';
--    axiSingleWrite <= '1';
--    wait until rising_edge(sysclk);
--    startAXI <= '0';
--    wait until axiState = idle;
--    axiSingleWrite <= '0';
--    wait for 5 us;
--    wait until rising_edge(sysclk);
--    axiAddr2 <= X"00000000";
--    axiData2 <= X"00000002";
--    axiSingleWrite <= '1';
--    startAXI <= '1';
--    wait until rising_edge(sysclk);
--    startAXI <= '0';
--    wait until axiState = idle;
--    axiSingleWrite <= '0';
--    wait for 1 us;
--    wait until rising_edge(sysclk);
--    startAXI <= '1';
--    startAddr <= 10;
--    wait until rising_edge(sysclk);
--    startAXI <= '0';
--    wait for 2 us;
--    wait until rising_edge(clk);
--    axiAddr2 <= X"00000000";
--    axiData2 <= X"00000002";
--    axiSingleWrite <= '1';
--    startAXI <= '1';
--    wait until rising_edge(clk);
--    startAXI <= '0';
--    wait until axiState = idle;
--    axiSingleWrite <= '0';
--    wait for 1 us;
    wait;
end process;

end Behavioral;
