library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PIController is
    port(
        --
        -- Clocking and reset
        --
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        --
        -- Inputs
        --
        meas_i      :   in  t_phase;
        control_i   :   in  t_phase;
        valid_i     :   in  std_logic;
        --
        -- Parameters
        --
        gains       :   in  t_param_reg;
        params      :   in  t_param_reg;
        --
        -- Outputs
        --
        valid_o     :   out std_logic;
        data_o      :   out t_dds_phase;
        act_o       :   out unsigned(CORDIC_WIDTH-1 downto 0)
    );
end PIController;

architecture Behavioral of PIController is

COMPONENT PID_Multipliers
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(27 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(35 DOWNTO 0)
  );
END COMPONENT;

--
-- Constants
--
constant MULT_LATENCY   :   unsigned(3 downto 0)    :=  X"5";
constant IN_WIDTH       :   natural :=  meas_i'length;
constant EXP_WIDTH      :   natural :=  28;
constant GAIN_WIDTH     :   natural :=  8;
constant MULT_WIDTH     :   natural :=  EXP_WIDTH + GAIN_WIDTH;

--
-- Type definitions
--
type t_state_local      is (idle,multiplying,dividing,summing,outputting);
subtype t_input_local   is signed(EXP_WIDTH-1 downto 0);
subtype t_gain_local    is std_logic_vector(GAIN_WIDTH-1 downto 0);
subtype t_mult_local    is signed(MULT_WIDTH-1 downto 0);
subtype t_phase_local   is signed(PHASE_WIDTH-1 downto 0);

signal state                :   t_state_local;
signal multCount            :   unsigned(3 downto 0);

signal polarity, enable     :   std_logic;
signal measurement, control :   t_input_local;
signal err, err0, err1      :   t_input_local;
signal prop_i, int_i        :   t_input_local;
signal gainP, gainI         :   t_gain_local;
signal divisor              :   natural range 0 to 255;

signal prop_o, int_o        :   std_logic_vector(MULT_WIDTH - 1 downto 0);
signal pidSum, pidDivide    :   t_mult_local;

signal actSigned            :   t_mult_local;

signal actScale             :   signed(CORDIC_WIDTH-1 downto 0);
signal act2pi               :   unsigned(CORDIC_WIDTH-1 downto 0);
constant PHASE_2PI          :   unsigned(CORDIC_WIDTH-1 downto 0)   :=  shift_left(to_unsigned(1,CORDIC_WIDTH),CORDIC_WIDTH-2);

signal dds_phase_corr, dds_phase       :   t_dds_phase;

begin

--
-- Parse inputs
--
polarity <= params(0);
enable <= params(1);

gainP <= gains(7 downto 0);
gainI <= gains(15 downto 8);
--gainD <= gains(23 downto 16);
divisor <= to_integer(unsigned(gains(31 downto 24)));

--
-- Resize inputs
--
measurement <= resize(meas_i,measurement'length);
control <= resize(control_i,control'length);
err <= (control - measurement) when polarity = '0' else (measurement - control);

--
-- Mutiply terms with gains
PropMult: PID_Multipliers
port map(
    clk     =>  clk,
    A       =>  std_logic_vector(gainP),
    B       =>  std_logic_vector(prop_i),
    P       =>  prop_o
);

IntMult: PID_Multipliers
port map(
    clk     =>  clk,
    A       =>  std_logic_vector(gainI),
    B       =>  std_logic_vector(int_i),
    P       =>  int_o
);

--
-- Sum outputs of multipliers and divide to get correct output
--
pidSum <= signed(prop_o) + signed(int_o);
pidDivide <= shift_right(pidSum,divisor);
--
-- Resize and wrap output values to 2*pi 
--
actScale <= resize(pidDivide,CORDIC_WIDTH);
act2pi <= unsigned(actScale) when actScale > 0 else PHASE_2PI - unsigned(abs(actScale));
dds_phase_corr <=  shift_left(resize(act2pi,PHASE_WIDTH),PHASE_WIDTH - 1 - CORDIC_WIDTH + 3);
--
-- Generate output
--
data_o <= dds_phase;
act_o <= act2pi;

PID: process(clk,aresetn) is
begin
    if aresetn = '0' then
        state <= idle;
        multCount <= X"0";
        err0 <= (others => '0');
        err1 <= (others => '0');
        dds_phase <= (others => '0');
        valid_o <= '0';
    elsif rising_edge(clk) then
        PID_FSM: case(state) is
            --
            -- Wait for input valid signal
            --
            when idle =>
                multCount <= X"0";
                valid_o <= '0';
                if enable = '1' and valid_i = '1' then
                    --
                    -- Calculate the various PI terms
                    -- 
                    prop_i <= err - err1;
                    int_i <= shift_right(err + err1,1);
                    
                    --
                    -- Update error signals
                    --
                    err1 <= err;
                    --
                    -- Change state
                    --
                    state <= multiplying;
                elsif enable = '0' then
                    --
                    -- Reset values as needed
                    --
                    prop_i <= (others => '0');
                    int_i <= (others => '0');
                    err1 <= (others => '0');
                    dds_phase <= (others => '0');
                end if;
                
            --
            -- Wait for multiplication to finish
            --
            when multiplying =>
                if multCount < MULT_LATENCY then
                    multCount <= multCount + X"1";
                else
                    --
                    -- Add actuator correction pidSum to the old value of actuator pidDivide
                    -- Note that this addition takes place before the right-shift by divisor bits
                    --
                    multCount <= X"0";
                    state <= summing;
                end if;
                
            --
            -- Sum correction and output
            --
            when summing =>
                state <= idle;
                dds_phase <= dds_phase + dds_phase_corr;
                valid_o <= '1';

               
            when others => null;
        end case;
        
    end if;
end process;


end Behavioral;
