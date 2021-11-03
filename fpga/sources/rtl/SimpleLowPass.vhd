library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity SimpleLowPass is
    generic(
        DATA_WIDTH  :   natural :=  14;
        FILT_WIDTH  :   natural :=  16
    );
    port(
        clk     :   in  std_logic;
        aresetn :   in  std_logic;
        
        trig_i  :   in  std_logic;
        data1_i :   in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data2_i :   in  std_logic_vector(DATA_WIDTH-1 downto 0);
        param   :   in  t_param_reg;
        data1_o :   out std_logic_vector(DATA_WIDTH-1 downto 0);
        data2_o :   out std_logic_vector(DATA_WIDTH-1 downto 0);
        valid_o :   out std_logic
    );
end SimpleLowPass;

architecture Behavioral of SimpleLowPass is

COMPONENT MultFilter
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(29 DOWNTO 0)
  );
END COMPONENT;

constant MULT_LATENCY   :   natural :=  5;

signal state        :   t_status :=  idle;

signal count        :   unsigned(3 downto 0)    :=  (others => '0');
signal filt         :   std_logic_vector(15 downto 0);
signal filtShift    :   unsigned(15 downto 0);

signal I_i,Q_i      :   std_logic_vector(DATA_WIDTH-1 downto 0);
signal I_c,Q_c      :   std_logic_vector(DATA_WIDTH-1 downto 0);
signal c1,c2        :   std_logic_vector(DATA_WIDTH+FILT_WIDTH-1 downto 0);
signal I_p,Q_p      :   std_logic_vector(DATA_WIDTH+FILT_WIDTH-1 downto 0);

begin

IMult: MultFilter
port map(
    CLK     =>  clk,
    A       =>  I_i,
    B       =>  filt,
    P       =>  c1
);

QMult: MultFilter
port map(
    CLK     =>  clk,
    A       =>  Q_i,
    B       =>  filt,
    P       =>  c2
);

filt <= param(15 downto 0);
filtShift <= unsigned(param(31 downto 16));

FilterProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        data1_o <= (others => '0');
        data2_o <= (others => '0');
        valid_o <= '0';
        I_i <= (others => '0');
        Q_i <= (others => '0');
        I_c <= (others => '0');
        Q_c <= (others => '0');
        state <= idle;
        count <= (others => '0');
    elsif rising_edge(clk) then
        AvgCase: case state is
            when idle =>
                valid_o <= '0';
                count <= (others => '0');
                if trig_i = '1' then
                    state <= processing;
                    I_i <= std_logic_vector(signed(data1_i)- signed(I_c));
                    Q_i <= std_logic_vector(signed(data2_i) - signed(Q_c));
                end if;     
                
            when processing =>
                if count < MULT_LATENCY then
                    count <= count + 1;
                else
                    I_c <= std_logic_vector(resize(shift_right(signed(c1),to_integer(filtShift)),I_c'length) + signed(I_c));
                    Q_c <= std_logic_vector(resize(shift_right(signed(c2),to_integer(filtShift)),Q_c'length) + signed(Q_c));
                    state <= finishing;
                end if;           
                
            when finishing =>
                data1_o <= I_c;
                data2_o <= Q_c;
                valid_o <= '1';
                state <= idle;
        end case;
    end if;    
end process;


end Behavioral;
