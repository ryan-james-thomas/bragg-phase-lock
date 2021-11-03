library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.CustomDataTypes.all;


entity ADC_Data_Input is
    port(
        --
        -- Input clocks
        --
        adc_clk_250     :   in  std_logic;
        adc_clk_125     :   in  std_logic;
        adc_clk_10      :   in  std_logic;
        sys_clk_200     :   in  std_logic;
        aresetn         :   in  std_logic;
        --
        -- Input data
        --
        adc_dat_a_n_i   :   in  std_logic_vector(6 downto 0);
        adc_dat_a_p_i   :   in  std_logic_vector(6 downto 0);
        adc_dat_b_n_i   :   in  std_logic_vector(6 downto 0);
        adc_dat_b_p_i   :   in  std_logic_vector(6 downto 0);
        --
        -- Output clock and data
        --
        adc_clk_o       :   out std_logic_vector(2 downto 0);
        adc_dat_a_o     :   out std_logic_vector(13 downto 0);
        adc_dat_b_o     :   out std_logic_vector(13 downto 0)
    );
end ADC_Data_Input;

architecture Behavioral of ADC_Data_Input is

constant ADC_WIDTH_I    :   natural :=  adc_dat_a_n_i'length;
constant ADC_WIDTH_O    :   natural :=  14;

signal adc_dat_a_ibuf, adc_dat_b_ibuf   :   std_logic_vector(ADC_WIDTH_I - 1 downto 0);
signal adc_dat_a_idly, adc_dat_b_idly   :   std_logic_vector(ADC_WIDTH_I - 1 downto 0);
signal adc_dat_a, adc_dat_b :   std_logic_vector(ADC_WIDTH_O - 1 downto 0);

--
-- IDELAY signals
--
signal idlyctrl_rst     :   std_logic;
signal idly_rdy         :   std_logic;
signal idly_rst, idly_ce, idly_inc    :   std_logic_vector(ADC_WIDTH_O - 1 downto 0);

type t_cnt is array(natural range <>) of std_logic_vector(4 downto 0);
signal idly_cnt :   t_cnt(ADC_WIDTH_O - 1 downto 0);


begin
adc_clk_o <= (0 => adc_clk_125, 1 => adc_clk_250, 2 => adc_clk_10);
--
-- Convert differential ADC data to single-ended data
-- for each ADC (A and B)
--
ADC_Input_Buffer: for I in 0 to ADC_WIDTH_I - 1 generate
    IBUFDS_A_X: IBUFDS
    port map(
        I   =>  adc_dat_a_p_i(I),
        IB  =>  adc_dat_a_n_i(I),
        O   =>  adc_dat_a_ibuf(I)
    );
    IBUFDS_B_X: IBUFDS
    port map(
        I   =>  adc_dat_b_p_i(I),
        IB  =>  adc_dat_b_n_i(I),
        O   =>  adc_dat_b_ibuf(I)
    );
end generate ADC_Input_Buffer;
--
-- Weird input delay control for non-obvious purpose
--
idlyctrl_rst <= not(aresetn);
IDELAYCTRL_i: IDELAYCTRL
port map(
    RDY     =>  idly_rdy,
    REFCLK  =>  sys_clk_200,
    RST     =>  idlyctrl_rst
);

idly_rst <= (others => '0');

IDELAY_GEN: for I in 0 to ADC_WIDTH_I - 1 generate
    IDELAY_A: IDELAYE2
    generic map(
        DELAY_SRC               =>  "IDATAIN",
        HIGH_PERFORMANCE_MODE   =>  "TRUE",
        IDELAY_TYPE             =>  "VARIABLE",
        IDELAY_VALUE            =>  0,
        PIPE_SEL                =>  "FALSE",
        REFCLK_FREQUENCY        =>  200.0,
        SIGNAL_PATTERN          =>  "DATA"
    )
    port map(
        CNTVALUEOUT =>  idly_cnt(I),
        DATAOUT     =>  adc_dat_a_idly(I),
        C           =>  adc_clk_125,
        CE          =>  idly_ce(I),
        CINVCTRL    =>  '0',
        CNTVALUEIN  =>  "00000",
        DATAIN      =>  '0',
        IDATAIN     =>  adc_dat_a_ibuf(I),
        INC         =>  idly_inc(I),
        LD          =>  idly_rst(I),
        LDPIPEEN    =>  '0',
        REGRST      =>  '0'
    );
    
    IDELAY_B: IDELAYE2
    generic map(
        DELAY_SRC               =>  "IDATAIN",
        HIGH_PERFORMANCE_MODE   =>  "TRUE",
        IDELAY_TYPE             =>  "VARIABLE",
        IDELAY_VALUE            =>  0,
        PIPE_SEL                =>  "FALSE",
        REFCLK_FREQUENCY        =>  200.0,
        SIGNAL_PATTERN          =>  "DATA"
    )
    port map(
        CNTVALUEOUT =>  idly_cnt(I + ADC_WIDTH_I),
        DATAOUT     =>  adc_dat_b_idly(I),
        C           =>  adc_clk_125,
        CE          =>  idly_ce(I + ADC_WIDTH_I),
        CINVCTRL    =>  '0',
        CNTVALUEIN  =>  "00000",
        DATAIN      =>  '0',
        IDATAIN     =>  adc_dat_b_ibuf(I),
        INC         =>  idly_inc(I + ADC_WIDTH_I),
        LD          =>  idly_rst(I + ADC_WIDTH_I),
        LDPIPEEN    =>  '0',
        REGRST      =>  '0'
    );
end generate IDELAY_GEN;
--
-- Convert single-ended double-data-rate (DDR) ADC data to 
-- single-data-rate (SDR) synchronous with the 250 MHz ADC clock
--
ADC_DDR: for I in 0 to ADC_WIDTH_I - 1 generate
    I_DDR_A: IDDR
    generic map(
        DDR_CLK_EDGE    =>  "SAME_EDGE_PIPELINED"
    )
    port map(
        Q1  =>  adc_dat_a(2*I),
        Q2  =>  adc_dat_a(2*I+1),
        C   =>  adc_clk_250,
        CE  =>  '1',
        D   =>  adc_dat_a_idly(I),
        R   =>  '0',
        S   =>  '0'
    );
    
    I_DDR_B: IDDR
    generic map(
        DDR_CLK_EDGE    =>  "SAME_EDGE_PIPELINED"
    )
    port map(
        Q1  =>  adc_dat_b(2*I),
        Q2  =>  adc_dat_b(2*I+1),
        C   =>  adc_clk_250,
        CE  =>  '1',
        D   =>  adc_dat_b_idly(I),
        R   =>  '0',
        S   =>  '0'
    );
end generate ADC_DDR;

adc_dat_a_o <= adc_dat_a;
adc_dat_b_o <= adc_dat_b;

end Behavioral;
