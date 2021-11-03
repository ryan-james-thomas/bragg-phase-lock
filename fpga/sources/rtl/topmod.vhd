library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

--
-- Example top-level module for parsing simple AXI instructions
--
entity topmod is
    port (
        --
        -- Clocks and reset
        --
        sysclk          :   in  std_logic_vector(2 downto 0);
        adcclk          :   in  std_logic_vector(2 downto 0);
        aresetn         :   in  std_logic;
        --
        -- AXI-super-lite signals
        --      
        addr_i          :   in  unsigned(AXI_ADDR_WIDTH-1 downto 0);            --Address out
        writeData_i     :   in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to write
        dataValid_i     :   in  std_logic_vector(1 downto 0);                   --Data valid out signal
        readData_o      :   out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0);                   --Response in
        --
        -- External I/O
        --
        ext_i           :   in  std_logic_vector(7 downto 0);
        ext_o           :   out std_logic_vector(7 downto 0);
        --
        -- PLL outputs
        --
        pll_hi_o        :   out std_logic;
        pll_lo_o        :   out std_logic;
        --
        -- ADC data
        --
        adc_dat_a_i     :   in  std_logic_vector(13 downto 0);
        adc_dat_b_i     :   in  std_logic_vector(13 downto 0);
        --
        -- DAC data
        --
        dac_a_o         :   out std_logic_vector(DAC_WIDTH - 1 downto 0);
        dac_b_o         :   out std_logic_vector(DAC_WIDTH - 1 downto 0);
        dac_reset_o     :   out std_logic
        
    );
end topmod;


architecture Behavioural of topmod is

component DualChannelDDS is
    port(
        clk             :   in  std_logic;
        aresetn         :   in  std_logic;
        
        pow1            :   in  t_dds_phase;
        ftw1            :   in  t_dds_phase;
        ftw2            :   in  t_dds_phase;
        
        amp_i           :   in  t_amp_mult;
        
        dac_o           :   out t_dac_array
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
        
        phase_o         :   out t_phase;            --Output phase
        valid_o         :   out std_logic           --Output phase valid signal
    );
end component;

component PhaseControl is
    port(
        --
        -- Clocks and reset
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Register (0 => polarity, 1 => enable)
        -- Gains (31 downto 24 => divisor, 23 downto 16 => Kd,
        -- 15 downto 8 => Ki, 7 downto 0 => Kp)
        --
        reg0        :   in  t_param_reg;
        gains       :   in  t_param_reg;
        --
        -- Input data
        --
        phase_i     :   in  t_phase;
        valid_i     :   in  std_logic;
        --
        -- Input flags and control phase
        --
        tc_i        :   in  t_timing_control;
        phase_c     :   in  t_phase;
        --
        -- Output signals
        --
        dds_phase_o :   out t_dds_phase;
        phaseSum_o  :   out t_phase;
        valid_o     :   out std_logic
    );
end component;

component FIFOHandler is
    port(
        wr_clk      :   in  std_logic;
        rd_clk      :   in  std_logic;
--        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        
        data_i      :   in  std_logic_vector(FIFO_WIDTH-1 downto 0);
        valid_i     :   in  std_logic;
        
        bus_m       :   in  t_fifo_bus_master;
        bus_s       :   out t_fifo_bus_slave
    );
end component;

component TimingController is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        reset_i     :   in  std_logic;

        data_i      :   in  t_param_reg;
        valid_i     :   in  std_logic;

        start_i     :   in  std_logic;
        debug_o     :   out std_logic_vector(7 downto 0);
        data_o      :   out t_timing_control
    );
end component;

component SaveADCData is
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
signal f0, df,dfmod :   t_dds_phase     :=  (others => '0');
signal dfSet        :   t_dds_phase     :=  (others => '0');
signal dfmodManual  :   t_dds_phase     :=  (others => '0');
signal dfmod_i      :   t_dds_phase     :=  (others => '0');
signal pow          :   t_dds_phase     :=  (others => '0');
signal ftw1, ftw2   :   t_dds_phase     :=  (others => '0');
signal amp_i, ampSet:   t_amp_mult;
signal useSetDemod  :   std_logic;
signal dfshift      :   unsigned(3 downto 0);
signal useManual    :   std_logic;
signal useTCDemod   :   std_logic;
signal dac          :   t_dac_array;

--
-- Phase calculation signals
--
signal adc          :   t_adc       :=  (others => '0');
signal phase        :   t_phase     :=  (others => '0');
signal phaseValid   :   std_logic   :=  '0';
signal regPhaseCalc :   t_param_reg :=  (others => '0');
signal regPhaseValid:   std_logic   :=  '0';

--
-- Phase control signals
--
signal phaseControlManual   :   std_logic;
signal regPhaseControl  :   t_param_reg;
signal regControlGains  :   t_param_reg;
signal phaseControlSig  :   t_phase;
signal phase_c          :   t_phase;
signal powControl       :   t_dds_phase;
signal powControlValid  :   std_logic;
signal actPhase         :   unsigned(CORDIC_WIDTH-1 downto 0);
signal phaseSum         :   t_phase;
--
-- Block memory signals
--
signal topReg           :   t_param_reg;
signal memData_i        :   t_mem_data;
signal memDataValid_i   :   std_logic;
signal mem_bus          :   t_mem_bus;
signal numSamples       :   t_mem_addr;
signal memtrig          :   std_logic;

--
-- FIFO signals
--
constant NUM_FIFOS  :   natural :=  3;
type t_fifo_data_array is array(natural range <>) of std_logic_vector(FIFO_WIDTH-1 downto 0);
signal fifoData     :   t_fifo_data_array(NUM_FIFOS-1 downto 0);
signal fifoValid    :   std_logic_vector(NUM_FIFOS-1 downto 0);
signal fifo_bus     :   t_fifo_bus_array(NUM_FIFOS-1 downto 0)  :=  (others => INIT_FIFO_BUS);
signal fifoReg      :   t_param_reg;
signal enableFIFO   :   std_logic;
signal debugCount   :   unsigned(7 downto 0);

signal resetExtended:   std_logic;
signal resetCount   :   unsigned(7 downto 0);

--
-- Timing controller signals
--
signal tcValid      :   std_logic;
signal tcData       :   t_param_reg;
signal tcReset      :   std_logic;
signal tcStart      :   std_logic;
signal tc_o         :   t_timing_control;
signal debug_o      :   std_logic_vector(7 downto 0);


begin
--
-- PLL outputs
--
pll_hi_o <= '0';
pll_lo_o <= '1';

--
-- Parse top register and triggers
--
dfshift <= unsigned(topReg(3 downto 0));    --Integer shift right for demodulation frequency
useSetDemod <= topReg(4);                   --Use a set demodulation frequency '1' or a shifted one '0'
useManual <= topReg(5);                     --Use manual frequencies and phases '1' or timing controller based ones '0'
useTCDemod <= topReg(6);                    --Use TC df output as FTW1 and demod frequency inputs
ampSet <= unsigned(topReg(31 downto 32 - ampSet'length));

regPhaseValid <= triggers(0);               --Indicates that a new CIC filter rate is valid
tcStart <= triggers(1);                     --Start the timing controller
--triggers(2) is used in the extended FIFO reset
--tcReset <= triggers(3);                     --Resets the timing controller FIFO

--
-- DDS output signals.  dfSet is the static frequency difference set by the user
-- pow1 and ftw1 are connected to OUT1 on the board as the least-significant 16 bits
-- ftw2 is connected to OUT2 on the board as the most-significant 16 bits
--
df <= dfSet when useManual = '1' else tc_o.df;  --Use dfSet when manual (set in parse process) or timing controller value
ftw1 <= f0 + df when useManual = '1' or useTCDemod = '0' else tc_o.df;
ftw2 <= f0 - df when useManual = '1' or useTCDemod = '0' else tc_o.df;
amp_i <= ampSet when useManual = '1' else tc_o.amp;
DDS_2Channel: DualChannelDDS
port map(
    clk             =>  adcclk(1),
    aresetn         =>  aresetn,
    pow1            =>  powControl,
    ftw1            =>  ftw1,
    ftw2            =>  ftw2,
    amp_i           =>  amp_i,
    dac_o           =>  dac
);

DAC_Output_Proc: process(adcclk(1),aresetn) is
begin
    if aresetn = '0' then
        dac_a_o <= (others => '1');
        dac_b_o <= (others => '1');
    elsif rising_edge(adcclk(1)) then
        dac_a_o <= not(std_logic_vector(dac(0)));
        dac_b_o <= not(std_logic_vector(dac(1)));
    end if;
end process;    

--
-- Phase calculation
--
adc <= resize(signed(adc_dat_b_i),adc'length);
--
-- Demodulation frequency is either a shifted version of the one used for freq generation
-- or it's a fixed one set by the user. The fixed one is allowed only for manual control
--
dfmod_i <= shift_left(df,to_integer(dfShift)) when (useSetDemod = '0' or useManual = '0') and useTCDemod = '0' else
           tc_o.df when useManual = '0' and useTCDemod = '1' else
           dfmod;
PhaseCalc: PhaseCalculation
port map(
    clk         =>  adcclk(1),
    aresetn     =>  aresetn,
    adcData_i   =>  adc,
    freq_i      =>  dfmod_i,
    reg0        =>  regPhaseCalc,
    regValid_i  =>  regPhaseValid,
    phase_o     =>  phase,
    valid_o     =>  phaseValid
);

--
-- Phase control
-- Phase as calculated from PhaseCalc is passed to this module.  The control signal is either the manually supplied
-- signal or the one from the TimingController.  The output phase is connected to the input of the 2-channel DDS
-- module.  When the PI loop inside MainPhaseControl is disabled, the output phase that is connected to the 2-channel
-- DDS module is fixed at 0.  
--
phase_c <= phaseControlSig when useManual = '1' else tc_o.pow;
MainPhaseControl: PhaseControl
port map(
    clk         =>  adcclk(1),
    aresetn     =>  aresetn,
    reg0        =>  regPhaseControl,
    gains       =>  regControlGains,
    phase_i     =>  phase,
    valid_i     =>  phaseValid,
    phase_c     =>  phase_c,
    tc_i        =>  tc_o,
    dds_phase_o =>  powControl,
    phaseSum_o  =>  phaseSum,
    valid_o     =>  powControlValid
);
               
--
-- FIFO buffering for long data sets
--
--
-- Extends FIFO reset signals
--
ResetExtend: process(sysclk(0),aresetn) is
begin
    if aresetn = '0' then
        resetExtended <= '0';
        tcReset <= '0';
        resetCount <= (others => '0');
    elsif rising_edge(sysclk(0)) then
        if triggers(3) = '1' then
            tcReset <= '1';
            resetExtended <= '1';
            resetCount <= X"01";
        elsif triggers(2) = '1' then
            resetExtended <= '1';
            resetCount <= X"01";
        elsif resetCount > 0 and resetCount < 20 then
            resetCount <= resetCount + 1;
        else
            resetExtended <= '0';
            tcReset <= '0';
        end if;
    end if;
end process;
--
-- Generate FIFO buffers. We save the measured phase, the phase unwrapped phase relative to the phase
-- when the PI controller is enabled, and the output phase generated by the PI controller (which is
-- connected directly to the 2-channel DDS module to control the OUT1 phase).
--
enableFIFO <= fifoReg(0) or tc_o.enable;
fifoData(0) <= std_logic_vector(resize(phase,FIFO_WIDTH));
fifoData(1) <= std_logic_vector(resize(phaseSum,FIFO_WIDTH));
fifoData(2) <= std_logic_vector(resize(powControl,FIFO_WIDTH));
FIFO_GEN: for I in 0 to NUM_FIFOS-1 generate
    fifo_bus(I).m.reset <= resetExtended;
    
    fifoValid(I) <= powControlValid and enableFIFO;
    PhaseMeas_FIFO_NORMAL_X: FIFOHandler
    port map(
        wr_clk      =>  adcclk(1),
        rd_clk      =>  sysclk(0),
        aresetn     =>  aresetn,
        data_i      =>  fifoData(I),
        valid_i     =>  fifoValid(I),
        bus_m       =>  fifo_bus(I).m,
        bus_s       =>  fifo_bus(I).s
    );
end generate FIFO_GEN;

--
-- Timing controller
--
TC: TimingController
port map(
    clk         =>  adcclk(1),
    aresetn     =>  aresetn,
    reset_i     =>  tcReset,
    data_i      =>  tcData,
    valid_i     =>  tcValid,
    start_i     =>  tcStart,
    data_o      =>  tc_o,
    debug_o     =>  debug_o
);
--
-- Save ADC data
--
memData_i <= std_logic_vector(resize(signed(adc_dat_a_i),16)) & std_logic_vector(resize(signed(adc_dat_b_i),16));
memDataValid_i <= '1';
memTrig <= triggers(4);
SaveData: SaveADCData
port map(
    readClk     =>  sysclk(0),
    writeClk    =>  adcclk(1),
    aresetn     =>  aresetn,
    data_i      =>  memData_i,
    valid_i     =>  memDataValid_i,
    numSamples  =>  numSamples,
    trig_i      =>  memTrig,
    bus_m       =>  mem_bus.m,
    bus_s       =>  mem_bus.s  
);
--
-- Parse AXI data
-- 
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;
Parse: process(sysclk(0),aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        bus_s <= INIT_AXI_BUS_SLAVE;
        triggers <= (others => '0');
        f0 <= to_unsigned(37580964,f0'length);      --35 MHz
        dfSet <= to_unsigned(134218,dfSet'length);     -- 0.125 MHz
        dfmod <= to_unsigned(1073744,dfmod'length); -- 1 MHz
        phaseControlSig <= to_signed(0,phaseControlSig'length);
        regPhaseCalc <= X"00000a08";                --CIC filter decimation rate of 2^8 = 256
        regPhaseControl <= X"000000" & X"08";
        regControlGains <= (others => '0');
        phaseControlSig <= (others => '0');
        topReg <= (others => '0');
        fifoReg <= (others => '0');
        numSamples <= to_unsigned(1000,numSamples'length);
        
        fifo_bus(0).m.status <= idle;
        fifo_bus(1).m.status <= idle;
        fifo_bus(2).m.status <= idle;
        
        tcValid <= '0';
        tcData <= (others => '0');
        
        mem_bus.m <= INIT_MEM_BUS_MASTER;
    elsif rising_edge(sysclk(0)) then
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
                        when X"00000C" => rw(bus_m,bus_s,comState,dfSet);
                        when X"000010" => rw(bus_m,bus_s,comState,dfmod);
                        when X"000014" => rw(bus_m,bus_s,comState,phaseControlSig);
                        when X"000018" => rw(bus_m,bus_s,comState,regPhaseCalc);
                        when X"00001C" => rw(bus_m,bus_s,comState,regPhaseControl);
                        when X"000020" => rw(bus_m,bus_s,comState,regControlGains);
                        --
                        -- FIFO control and data retrieval
                        --
                        when X"000024" => rw(bus_m,bus_s,comState,fifoReg);
                        when X"000028" => fifoRead(bus_m,bus_s,comState,fifo_bus(0).m,fifo_bus(0).s);
                        when X"00002C" => fifoRead(bus_m,bus_s,comState,fifo_bus(1).m,fifo_bus(1).s);
                        when X"000030" => fifoRead(bus_m,bus_s,comState,fifo_bus(2).m,fifo_bus(2).s);
                        --
                        -- Write data to timing controller
                        --
                        when X"000034" =>
                            bus_s.resp <= "01";
                            comState <= finishing;
                            tcData <= resize(bus_m.data,tcData'length);
                            tcValid <= '1';
                        
                        when X"000038" => rw(bus_m,bus_s,comState,numSamples);
                        
                        when others => 
                            comState <= finishing;
                            bus_s.resp <= "11";
                    end case;
                    
                    --
                    -- Read only cases
                    --
                    when X"01" =>
                        ParamCaseReadOnly: case(bus_m.addr(23 downto 0)) is
                            when X"000000" => readOnly(bus_m,bus_s,comState,df);
                            when X"000004" => readOnly(bus_m,bus_s,comState,dfmod_i);
                            when X"000008" => readOnly(bus_m,bus_s,comState,tc_o.df);
                            when X"00000C" => readOnly(bus_m,bus_s,comState,tc_o.amp);
                            when X"000010" => readOnly(bus_m,bus_s,comState,tc_o.pow);
                            when X"000014" => readOnly(bus_m,bus_s,comState,tc_o.flags);
                            when X"000018" => readOnly(bus_m,bus_s,comState,phase_c);
                            when X"00001C" => readOnly(bus_m,bus_s,comState,debug_o);
                            when X"000020" => readOnly(bus_m,bus_s,comState,mem_bus.s.last);
                            when X"000024" => readOnly(bus_m,bus_s,comState,memData_i);
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
                            bus_s.data <= mem_bus.s.data;
                            comState <= finishing;
                            bus_s.resp <= "01";
                            mem_bus.m.status <= idle;
                            mem_bus.m.trig <= '0';
                        elsif mem_bus.s.status = idle then
                            mem_bus.m.addr <= bus_m.addr(MEM_ADDR_WIDTH + 1 downto 2);
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
                tcValid <= '0';
                bus_s.resp <= "00";
                comState <= idle;
 
            when others => comState <= idle;
        end case;
    end if;
end process;

    
end architecture Behavioural;