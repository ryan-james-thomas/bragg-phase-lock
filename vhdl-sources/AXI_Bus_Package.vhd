library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

--
-- This package contains both constants and functions used for
-- servo control.
--
package AXI_Bus_Package is

constant NASLV : std_logic_vector(0 downto 1) := (others => '0');

--
-- Defines AXI address and data widths
--
constant AXI_ADDR_WIDTH     :   natural :=  32;
constant AXI_DATA_WIDTH     :   natural :=  32;
constant AXI_MASTER_WIDTH   :   natural :=  AXI_DATA_WIDTH + AXI_ADDR_WIDTH + 2;
constant AXI_SLAVE_WIDTH    :   natural :=  AXI_DATA_WIDTH + 2;

--
-- Defines AXI address and data signals
--
subtype t_axi_addr is unsigned(AXI_ADDR_WIDTH-1 downto 0);
subtype t_axi_data is std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

--
-- Defines a data bus controlled by the master
--
type t_axi_bus_master is record
    addr    :   t_axi_addr;
    data    :   t_axi_data;
    valid   :   std_logic_vector(1 downto 0);
end record t_axi_bus_master;

--
-- Defines a data bus controlled by the slave
--
type t_axi_bus_slave is record
    data    :   t_axi_data;
    resp    :   std_logic_vector(1 downto 0);
end record t_axi_bus_slave;

--
-- Defines a total data bus of master and slave parts
--
type t_axi_bus is record
    m       :   t_axi_bus_master;
    s       :   t_axi_bus_slave;
end record t_axi_bus;

--
-- Define initial values
--
constant INIT_AXI_BUS_MASTER    :  t_axi_bus_master     :=  (addr    =>  (others => '0'),
                                                             data    =>  (others => '0'),
                                                             valid  =>  "00");
constant INIT_AXI_BUS_SLAVE     :   t_axi_bus_slave     :=  (data   =>  (others => '0'),
                                                             resp   =>  "00");
constant INIT_AXI_BUS           :   t_axi_bus           :=  (m      =>  INIT_AXI_BUS_MASTER,
                                                             s      =>  INIT_AXI_BUS_SLAVE);

--
-- Conversion functions for AXI buses
--
function axi_master_to_slv(bus_m: t_axi_bus_master) return std_logic_vector;
function slv_to_axi_master(slv: std_logic_vector) return t_axi_bus_master;
function axi_slave_to_slv(bus_s: t_axi_bus_slave) return std_logic_vector;
function slv_to_axi_slave(slv: std_logic_vector) return t_axi_bus_slave;

                                                             
function resize ( ARG: std_logic_vector; NEW_SIZE: NATURAL) return std_logic_vector;

procedure rw(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   inout   std_logic);

procedure rw(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   inout   std_logic_vector);

procedure rw(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   inout   unsigned);

procedure rw(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   inout   signed);
    
procedure readOnly(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   in      unsigned);

procedure memRead(
    signal axi_m    :   in      t_axi_bus_master;
    signal axi_s    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal mem_m    :   inout   t_mem_bus_master;
    signal mem_s    :   in      t_mem_bus_slave);

procedure fifoRead(
    signal axi_m    :   in      t_axi_bus_master;
    signal axi_s    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal fifo_m   :   inout   t_fifo_bus_master;
    signal fifo_s   :   in      t_fifo_bus_slave);
    
    
end AXI_Bus_Package;

--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
package body AXI_Bus_Package is

--
-- AXI bus conversion functions
--
function axi_master_to_slv(bus_m: t_axi_bus_master) return std_logic_vector is
    variable result : std_logic_vector(AXI_ADDR_WIDTH + AXI_DATA_WIDTH + 2 - 1 downto 0);
begin
    result := std_logic_vector(bus_m.addr) & bus_m.data & bus_m.valid;
    return result;
end axi_master_to_slv;

function slv_to_axi_master(slv: std_logic_vector) return t_axi_bus_master is
    variable result :   t_axi_bus_master;
begin
    result.valid    :=  slv(1 downto 0);
    result.data     :=  slv(AXI_DATA_WIDTH + 2 - 1 downto 2);
    result.addr     :=  unsigned(slv(AXI_ADDR_WIDTH + AXI_DATA_WIDTH + 2 - 1 downto AXI_DATA_WIDTH + 2));
    return result; 
end slv_to_axi_master;

function axi_slave_to_slv(bus_s: t_axi_bus_slave) return std_logic_vector is
    variable result : std_logic_vector(AXI_DATA_WIDTH + 2 - 1 downto 0);
begin
    result := bus_s.data & bus_s.resp;
    return result;
end axi_slave_to_slv;

function slv_to_axi_slave(slv: std_logic_vector) return t_axi_bus_slave is
    variable result :   t_axi_bus_slave;
begin
    result.resp     :=  slv(1 downto 0);
    result.data     :=  slv(AXI_DATA_WIDTH + 2 - 1 downto 2);
    return result; 
end slv_to_axi_slave;


function resize ( ARG: std_logic_vector; NEW_SIZE: NATURAL) return std_logic_vector is
    constant ARG_LEFT:INTEGER:= ARG'length-1;
    alias XARG: std_logic_vector(ARG_LEFT downto 0) is ARG;
    variable RESULT: std_logic_vector(NEW_SIZE-1 downto 0) := (others=>'0');
begin
    if (NEW_SIZE < 1) then 
        return NASLV; 
    end if;
    if XARG'length = 0 then 
        return RESULT;
    end if;
    if (RESULT'length < ARG'length) then
        RESULT(RESULT'left downto 0) := XARG(RESULT'left downto 0);
    else
        RESULT(RESULT'left downto XARG'left+1) := (others => '0');
        RESULT(XARG'left downto 0) := XARG;
    end if;
    return RESULT;
end resize;

procedure rw(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   inout   std_logic) is 
begin
    bus_o.resp <= "01";
    state <= finishing;
    if bus_i.valid(1) = '0' then
        param <= bus_i.data(0);
    else
        bus_o.data <= (0 => param, others => '0');
    end if;
end rw;

procedure rw(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   inout   std_logic_vector) is 
begin
    bus_o.resp <= "01";
    state <= finishing;
    if bus_i.valid(1) = '0' then
        param <= resize(bus_i.data,param'length);
    else
        bus_o.data <= resize(param,AXI_DATA_WIDTH);
    end if;
end rw;

procedure rw(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   inout   unsigned) is 
begin
    bus_o.resp <= "01";
    state <= finishing;
    if bus_i.valid(1) = '0' then
        param <= resize(unsigned(bus_i.data),param'length);
    else
        bus_o.data <= resize(std_logic_vector(param),AXI_DATA_WIDTH);
    end if;
end rw;

procedure rw(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   inout   signed) is 
begin
    bus_o.resp <= "01";
    state <= finishing;
    if bus_i.valid(1) = '0' then
        param <= resize(signed(bus_i.data),param'length);
    else
        bus_o.data <= resize(std_logic_vector(param),AXI_DATA_WIDTH);
    end if;
end rw;

procedure readOnly(
    signal bus_i    :   in      t_axi_bus_master;
    signal bus_o    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal param    :   in      unsigned) is 
begin
    state <= finishing;
    if bus_i.valid(1) = '0' then
        bus_o.resp <= "11";
    else
        bus_o.resp <= "01";
        bus_o.data <= resize(std_logic_vector(param),AXI_DATA_WIDTH);
    end if;
end readOnly;

procedure memRead(
    signal axi_m    :   in      t_axi_bus_master;
    signal axi_s    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal mem_m    :   inout   t_mem_bus_master;
    signal mem_s    :   in      t_mem_bus_slave) is
begin
    if axi_m.valid(1) = '0' then
        axi_s.resp <= "11";
        state <= finishing;
        mem_m.trig <= '0';
        mem_m.status <= idle;
    elsif mem_s.valid = '1' then
        axi_s.data <= resize(mem_s.data,axi_s.data'length);
        state <= finishing;
        axi_s.resp <= "01";
        mem_m.status <= idle;
        mem_m.trig <= '0';
    elsif mem_m.status = idle then
        mem_m.addr <= axi_m.addr(MEM_ADDR_WIDTH+1 downto 2);
        mem_m.status <= waiting;
        mem_m.trig <= '1';
     else
        mem_m.trig <= '0';
    end if;
end memRead;

procedure fifoRead(
    signal axi_m    :   in      t_axi_bus_master;
    signal axi_s    :   out     t_axi_bus_slave;
    signal state    :   inout   t_status;
    signal fifo_m   :   inout   t_fifo_bus_master;
    signal fifo_s   :   in      t_fifo_bus_slave) is
begin
    if axi_m.valid(1) = '0' then
        axi_s.resp <= "11";
        state <= finishing;
        fifo_m.rd_en <= '0';
        fifo_m.status <= idle;
        fifo_m.count <= (others => '0');
    elsif fifo_s.valid = '1' then
        axi_s.data <= resize(fifo_s.data,axi_s.data'length);
        state <= finishing;
        axi_s.resp <= "01";
        fifo_m.status <= idle;
        fifo_m.count <= (others => '0');
        fifo_m.rd_en <= '0';
    elsif fifo_m.status = idle then
        if fifo_s.empty = '0' then
            fifo_m.status <= waiting;
            fifo_m.rd_en <= '1';
            fifo_m.count <= (others => '0');
        elsif fifo_m.count < FIFO_TIMEOUT then
            fifo_m.count <= fifo_m.count + 1;
        else
            fifo_m.count <= (others => '0');
            axi_s.resp <= "11";
            state <= finishing;
            fifo_m.rd_en <= '0';
            fifo_m.status <= idle;
        end if; 
     else
        fifo_m.rd_en <= '0';
        fifo_m.count <= (others => '0');
    end if;
end fifoRead;

end AXI_Bus_Package;
