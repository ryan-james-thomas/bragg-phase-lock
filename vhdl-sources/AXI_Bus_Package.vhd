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

--
-- Defines AXI address and data widths
--
constant AXI_ADDR_WIDTH :   natural :=  32;
constant AXI_DATA_WIDTH :   natural :=  32;

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
	
end AXI_Bus_Package;

--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
package body AXI_Bus_Package is

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
        param <= bus_i.data(param'length-1 downto 0);
    else
        bus_o.data <= (AXI_DATA_WIDTH-1 downto param'length => '0') & param;
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
        param <= unsigned(bus_i.data(param'length-1 downto 0));
    else
        bus_o.data <= (AXI_DATA_WIDTH-1 downto param'length => '0') & std_logic_vector(param);
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
        param <= signed(bus_i.data(param'length-1 downto 0));
    else
        bus_o.data <= (AXI_DATA_WIDTH-1 downto param'length => '0') & std_logic_vector(param);
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
        bus_o.data <= (AXI_DATA_WIDTH-1 downto param'length => '0') & std_logic_vector(param);
    end if;
end readOnly;

end AXI_Bus_Package;
