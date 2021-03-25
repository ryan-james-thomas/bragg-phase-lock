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
end component;

COMPONENT MixerDDS_PhaseOffset
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

constant CLK_T  :   time    :=  10 ns;

signal clk, aresetn :   std_logic;
signal adcData_i    :   std_logic_vector(15 downto 0);

signal m_axis_tdata :   std_logic_vector(31 downto 0);
signal m_axis_tvalid:   std_logic;

signal addr_i       :   unsigned(AXI_ADDR_WIDTH-1 downto 0);
signal writeData_i, readData_o  :   std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal dataValid_i, resp_o  :   std_logic_vector(1 downto 0);

--
-- ADC data generation
--
signal ddsfreq      :   std_logic_vector(31 downto 0);
signal ddsphase     :   std_logic_vector(31 downto 0);
signal ddsphaseValid:   std_logic;
signal dds_o        :   std_logic_vector(31 downto 0);
signal ddsValid_o   :   std_logic;

signal mixPhase_slv     :   std_logic_vector(31 downto 0);
signal dds_combined     :   std_logic_vector(31 downto 0);

--
-- AXI data
--
type t_axi_addr_array is array(natural range <>) of t_axi_addr;
type t_axi_data_array is array(natural range <>) of t_axi_data;

constant axi_addresses    :   t_axi_addr_array(7 downto 0)  :=  (0  =>  X"00000000",
                                                                 1  =>  X"00000004",
                                                                 2  =>  X"00000008",
                                                                 3  =>  X"0000000C",
                                                                 4  =>  X"00000010",
                                                                 5  =>  X"00000014",
                                                                 6  =>  X"00000018",
                                                                 7  =>  X"0000001C");
                                                                 
signal axi_data :   t_axi_data_array(7 downto 0);

signal triggers :   t_param_reg;
signal topReg, freqOffsetReg, freqDiffReg, phaseControlSig, regPhase, regPhaseControl, fifoReg  :   t_param_reg;

signal startAXI     :   std_logic;
signal addrIndex    :   natural;

signal axiState     :   t_status;   
signal axiCount     :   natural;
signal axiSingleWrite   :   std_logic;
signal axiSingleRead:   std_logic;

signal axiAddr2 :   t_axi_addr;
signal axiData2 :   t_axi_data;

begin

clk_proc: process is
begin
    clk <= '0';
    wait for CLK_T/2;
    clk <= '1';
    wait for CLK_T/2;
end process;

uut: topmod
port map(
    clk         =>  clk,
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

mixPhase_slv <= std_logic_vector(resize(shift_left(signed(freqDiffReg),3),mixPhase_slv'length));
DataGet : MixerDDS_PhaseOffset
PORT MAP (
    aclk => clk,
    aresetn => aresetn,
    s_axis_phase_tvalid => '1',
    s_axis_phase_tdata => mixPhase_slv,
    s_axis_config_tvalid => ddsphaseValid,
    s_axis_config_tdata => ddsphase,
    m_axis_data_tvalid => ddsValid_o,
    m_axis_data_tdata => dds_o
);
adcData_i <= std_logic_vector(shift_left(resize(signed(dds_o(15 downto 0)),adcData_i'length),0) + to_signed(1024,adcData_i'length));

--
-- Assign AXI registers
--
axi_data <= (0  =>  triggers,
             1  =>  topReg,
             2  =>  freqOffsetReg,
             3  =>  freqDiffReg,
             4  =>  phaseControlSig,
             5  =>  regPhase,
             6  =>  regPhaseControl,
             7  =>  fifoReg);

AXITransfer: process(clk,aresetn) is
begin
    if aresetn = '0' then
        addrIndex <= 0;
        axiState <= idle;
        axiCount <= 0;
    elsif rising_edge(clk) then
        AXICase: case(axiState) is
            when idle =>
                if startAXI = '1' then
                    axiState <= writing;
                    addrIndex <= 0;
                end if;
                
            when writing =>
                if axiSingleRead = '1' then
                    addr_i <= axiAddr2;
                    dataValid_i <= "11";
                elsif axiSingleWrite = '1' then
                    addr_i <= axiAddr2;
                    writeData_i <= axiData2;
                    dataValid_i <= "01";
                else
                    addr_i <= axi_addresses(addrIndex);
                    writeData_i <= axi_data(addrIndex);
                    dataValid_i <= "01";
                end if;
                
                axiState <= waiting;
                
            when waiting =>
                if resp_o = "01" then
                    dataValid_i <= "00";
                    if axiSingleWrite = '1' or axiSingleRead = '1' then
                        axiState <= idle;
                    elsif addrIndex < axi_addresses'length - 1 then
                        addrIndex <= addrIndex + 1;
                        axiState <= counting;
                        axiCount <= 0;
                    else
                        axiState <= idle;
                    end if;
                elsif resp_o = "11" then
                    dataValid_i <= "00";
                    axiState <= idle;
                end if;
                
            when counting => 
                if axiCount < 4 then
                    axiCount <= axiCount + 1;
                else
                    axiCount <= 0;
                    axiState <= writing;
                end if;
                
            when others => null;
        end case;
    end if;
end process;


main_proc: process
begin
    aresetn <= '0';
    axiSingleWrite <= '0';
    ddsphase <= std_logic_vector(to_signed(0,ddsphase'length));
    ddsphaseValid <= '0';
    triggers <= (others => '0');
    topReg <= X"00000030";
    freqOffsetReg <= X"024dd2f2";
    freqDiffReg <= X"00020c4a";
    phaseControlSig <= X"00000000";
    regPhase <= X"0000080a";
    regPhaseControl <= X"0000000c";
    fifoReg <= (others => '0');
    wait for 200 ns;
    aresetn <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    startAXI <= '1';
    wait until rising_edge(clk);
    startAXI <= '0';
    wait for 1 us;
    wait until rising_edge(clk);
    axiAddr2 <= X"0000001C";
    axiData2 <= X"00000001";
    axiSingleWrite <= '1';
    startAXI <= '1';
    wait until rising_edge(clk);
    startAXI <= '0';
    wait until axiState = idle;
    axiSingleWrite <= '0';
    wait for 5 us;
    wait until rising_edge(clk);
    axiAddr2 <= X"01000004";
    axiSingleRead <= '1';
    startAXI <= '1';
    wait until rising_edge(clk);
    startAXI <= '0';
    wait until axiState = idle;
    axiSingleRead <= '0';
    
    
    wait;
end process;

end Behavioral;
