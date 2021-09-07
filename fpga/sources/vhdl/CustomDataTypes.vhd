library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 

--
-- This package contains both constants and data types
--
package CustomDataTypes is

--
-- Constants
--
constant PARAM_WIDTH        :   natural :=  32;
constant PHASE_WIDTH        :   natural :=  27;
constant CORDIC_WIDTH       :   natural :=  24;
constant FIFO_WIDTH         :   natural :=  32;
constant FIFO_TIMEOUT       :   unsigned(27 downto 0)   :=  to_unsigned(125000000,28);

subtype t_param_reg is std_logic_vector(PARAM_WIDTH-1 downto 0);
subtype t_adc_combined is std_logic_vector(31 downto 0);
subtype t_adc is signed(13 downto 0);
subtype t_dds_phase is unsigned(PHASE_WIDTH-1 downto 0);
subtype t_phase is signed(31 downto 0);

--type t_param_reg_array is array(natural range <>) of t_param_reg;

--
-- Defines AXI address and data widths
--
constant MEM_ADDR_WIDTH :   natural :=  13;
constant MEM_DATA_WIDTH :   natural :=  16;

--
-- Defines MEM address and data signals
--
subtype t_mem_addr is unsigned(MEM_ADDR_WIDTH-1 downto 0);
subtype t_mem_data is std_logic_vector(MEM_DATA_WIDTH-1 downto 0);

type t_status is (idle,waiting,reading,writing,processing,running,finishing,counting);

--
-- Defines data buses for handling block memories
--
type t_mem_bus_master is record
    addr    :   t_mem_addr;
    trig    :   std_logic;
    reset   :   std_logic;
    status  :   t_status;
    data    :   t_mem_data;
end record t_mem_bus_master;

type t_mem_bus_slave is record
    data    :   t_mem_data;
    valid   :   std_logic;
    last    :   t_mem_addr;
    status  :   t_status;
end record t_mem_bus_slave;

type t_mem_bus is record
    m   :   t_mem_bus_master;
    s   :   t_mem_bus_slave;
end record t_mem_bus;

type t_mem_bus_master_array is array(natural range <>) of t_mem_bus_master;
type t_mem_bus_slave_array is array(natural range <>) of t_mem_bus_slave;

--
-- Define initial values
--
constant INIT_MEM_BUS_MASTER    :  t_mem_bus_master :=  (addr   =>  (others => '0'),
                                                         trig   =>  '0',
                                                         reset  =>  '0',
                                                         status =>  idle,
                                                         data   =>  (others => '0'));
constant INIT_MEM_BUS_SLAVE     :   t_mem_bus_slave :=  (data   =>  (others => '0'),
                                                         valid  =>  '0',
                                                         last   =>  (others => '0'),
                                                         status =>  idle);
constant INIT_MEM_BUS           :   t_mem_bus       :=  (m  =>  INIT_MEM_BUS_MASTER,
                                                         s  =>  INIT_MEM_BUS_SLAVE);

type t_fifo_bus_master is record
    status  :   t_status;
    reset   :   std_logic;
    rd_en   :   std_logic;
    count   :   unsigned(27 downto 0);
end record t_fifo_bus_master;

type t_fifo_bus_slave is record
    data    :   std_logic_vector(FIFO_WIDTH-1 downto 0);
    valid   :   std_logic;
    empty   :   std_logic;
    full    :   std_logic;
end record t_fifo_bus_slave;

type t_fifo_bus is record
    m   :   t_fifo_bus_master;
    s   :   t_fifo_bus_slave;
end record t_fifo_bus;

type t_fifo_bus_array is array(natural range <>) of t_fifo_bus;

constant INIT_FIFO_BUS_MASTER    :  t_fifo_bus_master :=(rd_en  =>  '0',
                                                         reset  =>  '0',
                                                         status =>  idle,
                                                         count  =>  (others => '0'));
constant INIT_FIFO_BUS_SLAVE     :   t_fifo_bus_slave :=(data   =>  (others => '0'),
                                                         empty  =>  '0',
                                                         full   =>  '0',
                                                         valid  =>  '0');
constant INIT_FIFO_BUS           :   t_FIFO_bus       :=(m  =>  INIT_FIFO_BUS_MASTER,
                                                         s  =>  INIT_FIFO_BUS_SLAVE);


type t_control is record
    enable  :   std_logic;
    start   :   std_logic;
    stop    :   std_logic;
    debug   :   std_logic_vector(3 downto 0);
end record t_control;

constant INIT_CONTROL_DISABLED      :   t_control       :=  (enable =>  '0',
                                                             start  =>  '0',
                                                             stop   =>  '0',
                                                             debug  =>  (others => '0'));

constant INIT_CONTROL_ENABLED       :   t_control       :=  (enable =>  '1',
                                                             start  =>  '0',
                                                             stop   =>  '0',
                                                             debug  =>  (others => '0'));

type t_module_status is record
    started :   std_logic;
    running :   std_logic;
    done    :   std_logic;
end record t_module_status;
	
constant INIT_MODULE_STATUS     :   t_module_status :=  (started    =>  '0',
                                                         running    =>  '0',
                                                         done       =>  '0');
                                                         
type t_iq_data is record
    I       :   signed(23 downto 0);
    Q       :   signed(23 downto 0);
    valid   :   std_logic;
end record t_iq_data;

constant INIT_IQ_DATA   :   t_iq_data   :=  (I  =>  (others => '0'), Q => (others => '0'), valid => '0');



                                                     


type t_timing_control is record
    enable  :   std_logic;
    df      :   t_dds_phase;
    pow     :   t_phase;
    valid   :   std_logic;
end record t_timing_control;

constant INIT_TIMING_CONTROL    :   t_timing_control    :=  (enable => '0',
                                                             valid  => '0',
                                                             df     => (others => '0'),
                                                             pow    => (others => '0'));


function resizePhase ( ARG: signed) return t_dds_phase;

end CustomDataTypes;

--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
package body CustomDataTypes is

function resizePhase ( ARG: signed) return t_dds_phase is
    constant PHASE_2PI  :   unsigned(CORDIC_WIDTH-1 downto 0)   :=  shift_left(to_unsigned(1,CORDIC_WIDTH),CORDIC_WIDTH-2);
    variable actScale   :   signed(CORDIC_WIDTH-1 downto 0);
    variable act2pi     :   unsigned(CORDIC_WIDTH-1 downto 0);
    variable RESULT     :   t_dds_phase                         := (others => '0');
begin
    actScale := resize(ARG,CORDIC_WIDTH);
    if actScale > 0 then
        act2pi := unsigned(actScale);
    else
        act2pi := PHASE_2PI - unsigned(abs(actScale));
    end if;
    RESULT := shift_left(resize(act2pi,PHASE_WIDTH),PHASE_WIDTH - 1 - CORDIC_WIDTH + 3);
    return RESULT;
end resizePhase;

end CustomDataTypes;
