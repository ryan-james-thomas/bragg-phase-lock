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
        enable_i    :   in  std_logic;
        polarity_i  :   in  std_logic;
        hold_i      :   in  std_logic;
        gains       :   in  t_param_reg;
        --
        -- Outputs
        --
        valid_o     :   out std_logic;
        data_o      :   out t_phase
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
constant MULT_LATENCY   :   natural :=  3;
constant EXP_WIDTH      :   natural :=  28;
constant GAIN_WIDTH     :   natural :=  8;
constant MULT_WIDTH     :   natural :=  EXP_WIDTH + GAIN_WIDTH;
--
-- Type definitions
--
type t_state_local          is (idle,multiplying,dividing,summing,outputting);
subtype t_input_local       is signed(EXP_WIDTH-1 downto 0);
subtype t_gain_local        is std_logic_vector(GAIN_WIDTH-1 downto 0);
subtype t_mult_local        is signed(MULT_WIDTH-1 downto 0);
subtype t_phase_local       is signed(PHASE_WIDTH-1 downto 0);
type t_input_local_array    is array(natural range <>) of t_input_local;
--
-- Parameters
--
signal Kp, Ki, Kd           :   t_gain_local;
signal divisor              :   natural range 0 to 255;
--
-- Signals
--
signal err                      :   t_input_local_array(2 downto 0);
signal measurement, control     :   t_input_local;
signal prop_i, int_i, deriv_i   :   t_input_local;
signal prop_o, int_o, deriv_o   :   std_logic_vector(MULT_WIDTH - 1 downto 0);
signal pidSum, pidAccumulate    :   t_mult_local;

signal valid_p                  :   std_logic_vector(7 downto 0);

begin
--
-- Parse PID gains
--
Kp <= gains(7 downto 0);
Ki <= gains(15 downto 8);
Kd <= gains(23 downto 16);
divisor <= to_integer(unsigned(gains(31 downto 24)));
--
-- Resize inputs
--
measurement <= resize(meas_i,measurement'length);
control <= resize(control_i,control'length);
--
-- Create terms for multiplication and multiply
--
prop_i <= err(0) - err(1);
int_i <= shift_right(err(0) + err(1),1);
deriv_i <= err(0) - shift_left(err(1),1) + err(2);

PropMult: PID_Multipliers
port map(
    clk     =>  clk,
    A       =>  Kp,
    B       =>  std_logic_vector(prop_i),
    P       =>  prop_o
);

IntMult: PID_Multipliers
port map(
    clk     =>  clk,
    A       =>  Ki,
    B       =>  std_logic_vector(int_i),
    P       =>  int_o
);

DerivMult: PID_Multipliers
port map(
    clk     =>  clk,
    A       =>  Kd,
    B       =>  std_logic_vector(deriv_i),
    P       =>  deriv_o
);
--
-- Sum outputs of multipliers and divide to get correct output
--
pidSum <= signed(prop_o) + signed(int_o) + signed(deriv_o);
--
-- Main process
--
PID: process(clk,aresetn) is
begin
    if aresetn = '0' then
        err <= (others => (others => '0'));
        valid_o <= '0';
        valid_p <= (others => '0');
        pidAccumulate <= (others => '0');
        data_o <= (others => '0');
    elsif rising_edge(clk) then
        if enable_i = '1' then
            --
            -- First pipeline stage
            --
            valid_p(0) <= valid_i;
            if valid_i = '1' then
                --
                -- Get new data
                --
                if polarity_i = '0' then
                    err(0) <= control - measurement;
                else
                    err(0) <= measurement - control;
                end if;
                --
                -- Store previous data
                --
                err(1) <= err(0);
                err(2) <= err(1);
            end if;
            --
            -- Step through pipeline stages to account for multiplication latency
            --
            for I in 0 to MULT_LATENCY - 1 loop
                valid_p(I + 1) <= valid_p(I);
            end loop;
            --
            -- Sum new values
            --
            if valid_p(MULT_LATENCY) = '1' and hold_i = '0' then
                pidAccumulate <= pidAccumulate + pidSum;
            end if;
            valid_p(1 + MULT_LATENCY) <= valid_p(MULT_LATENCY);
            --
            -- Produce output
            --
            if valid_p(1 + MULT_LATENCY) = '1' then
                data_o <= resize(shift_right(pidAccumulate,divisor),data_o'length);
            end if;
            valid_o <= valid_p(1 + MULT_LATENCY);
        else
            err <= (others => (others => '0'));
            valid_p <= (others => '0');
            pidAccumulate <= (others => '0');
            data_o <= (others => '0');
            valid_o <= '0';
        end if;
    end if;
end process;


end Behavioral;
