library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 

--
-- This module implements a simple AXI4-Lite interface.  It can be used to write to and read from registers, 
-- which can include data collected by an ADC.  For a description of the AXI4-lite protocol, 
-- see https://forums.xilinx.com/xlnx/attachments/xlnx/NewUser/34911/1/designing_a_custom_axi_slave_rev1.pdf
--
entity AXI_Parse is
    generic (
        ADDR_WIDTH  :   natural :=  32;
        DATA_WIDTH  :   natural :=  32;
        OFFSET_ADDR :   unsigned(31 downto 0) :=  X"40000000"
    );
    port (
        --
        -- Clock and reset signals
        --
        s_axi_aclk      :   in  std_logic;  --AXI clock signal
        s_axi_aresetn   :   in  std_logic;  --Active-low asynchronous reset
        --
        -- Master write address channel - slave read address channel
        --
        s_axi_awaddr    :   in  std_logic_vector(ADDR_WIDTH-1 downto 0);    --Address from master for writing to slave
        s_axi_awvalid   :   in  std_logic;                                  --Is address from master valid?
        s_axi_awready   :   out std_logic;                                  --Is slave ready to receive address?
        --
        -- Master write data channel - slave read data channel
        --
        s_axi_wdata     :   in  std_logic_vector(DATA_WIDTH-1 downto 0);    --Data coming from master
        s_axi_wstrb     :   in  std_logic_vector(3 downto 0);               --4-bit strobe indicating which bytes are valid data
        s_axi_wvalid    :   in  std_logic;                                  --Is the data from master valid?
        s_axi_wready    :   out std_logic;                                  --Is the slave ready to receive data?
        --
        -- Master read address channel - slave write address channel
        --
        s_axi_araddr    :   in  std_logic_vector(ADDR_WIDTH-1 downto 0);    --Address from master for reading from slave
        s_axi_arvalid   :   in  std_logic;                                  --Is address from master valid?
        s_axi_arready   :   out std_logic;                                  --Is slave ready to receive address?
        --
        -- Master read data channel - slave write data channel
        --
        s_axi_rdata     :   out std_logic_vector(DATA_WIDTH-1 downto 0);    --Data sent from slave to master
        s_axi_rresp     :   out std_logic_vector(1 downto 0);               --2-bit response indicating if an error occurred. "00" is NO ERROR
        s_axi_rvalid    :   out std_logic;                                  --Is data from slave valid?
        s_axi_rready    :   in  std_logic;                                  --Is master ready to receive data?
        --
        -- Master write response channel - slave read response channel
        --
        s_axi_bresp     :   out std_logic_vector(1 downto 0);               --Response from slave indicating if an error occurred during writing.  "00" is NO ERROR
        s_axi_bvalid    :   out std_logic;                                  --Is slave ready to send write response error?
        s_axi_bready    :   in  std_logic;                                  --Is master ready to read the write response error?
        --
        -- Simplified input/output registers
        --
        addr_o          :   out unsigned(ADDR_WIDTH-1 downto 0);            --Address out
        dataValid_o     :   out std_logic_vector(1 downto 0);               --Data valid out signal
        writeData_o     :   out std_logic_vector(DATA_WIDTH-1 downto 0);    --Data to write
        readData_i      :   in  std_logic_vector(DATA_WIDTH-1 downto 0);    --Data to read
        resp_i          :   in  std_logic_vector(1 downto 0)                --Response in
    );
end AXI_Parse;

architecture rtl of AXI_Parse is
    
signal state    :   unsigned(3 downto 0)    :=  X"0";

begin

MainProcess: process(s_axi_aclk,s_axi_aresetn) is
begin
    if s_axi_aresetn = '0' then
        state <= X"0";
        dataValid_o <= "00";
        addr_o <= (others => '0');
        --
        -- Reset signals for the MOSI process
        --
        s_axi_awready <= '0';
        s_axi_wready <= '0';
        s_axi_bvalid <= '0';
        s_axi_bresp <= "00";
        addr_o <= (others => '0');
        writeData_o <= (others => '0');
        --
        -- Reset signals for the MISO process
        --
        s_axi_arready <= '0';
        s_axi_rvalid <= '0';
        s_axi_rdata <= (others => '0');
        s_axi_rresp <= "00";

    elsif rising_edge(s_axi_aclk) then
        MainCase: case(state) is
            --
            -- The first phase of the MOSI process is to wait for a valid address from the master
            --
            when "0000" =>
                if s_axi_awvalid = '0' and s_axi_arvalid = '0' then
                    --
                    -- If neither write nor read address valid signal is asserted, then stay in the WAIT FOR VALID phase
                    --

                    -- MOSI signals
                    s_axi_wready <= '0';    --This indicates that the slave is not ready to accept new data from the master
                    s_axi_awready <= '1';   --This indicates that the slave is ready to accept a new address from the master
                    s_axi_bvalid <= '0';
                    s_axi_bresp <= "00";
                    -- MISO signals
                    s_axi_arready <= '1';   --Tell the master that the slave is ready to accept a new read address
                    s_axi_rresp <= "00";    --Set the read response to NO ERROR
                    s_axi_rvalid <= '0';    --Indicate that the data on the s_axi_rdata bus is NOT VALID
                elsif s_axi_awvalid = '1' then
                    --
                    -- When the master has asserted that the write address is valid, then store the address and move to the next state
                    --
                    addr_o <= unsigned(s_axi_awaddr) - OFFSET_ADDR;
                    s_axi_wready <= '1';
                    s_axi_awready <= '0';
                    state <= "0001";
                elsif s_axi_arvalid = '1' then
                    --
                    -- When the master indicates that the address on the s_axi_araddr is valid, then read that address
                    --
                    addr_o <= unsigned(s_axi_araddr) - OFFSET_ADDR;
                    s_axi_arready <= '0';
                    state <= "1001";
                end if;

            --
            -- The second phase is to wait for valid data from the master.  This is a MOSI only state
            --
            when "0001" =>
                if s_axi_wvalid = '1' then
                    --
                    -- Store data from the master when the write valid signal is high
                    --
                    -- The write strobe (wstrb) signals indicate which bytes from the master are valid data
                    --
                    if s_axi_wstrb(0) = '1' then
                        writeData_o(7 downto 0) <= s_axi_wdata(7 downto 0);
                    end if;
                    if s_axi_wstrb(1) = '1' then
                        writeData_o(15 downto 8) <= s_axi_wdata(15 downto 8);
                    end if;
                    if s_axi_wstrb(2) = '1' then
                        writeData_o(23 downto 16) <= s_axi_wdata(23 downto 16);
                    end if;
                    if s_axi_wstrb(3) = '1' then
                        writeData_o(31 downto 24) <= s_axi_wdata(31 downto 24);
                    end if;

                    s_axi_wready <= '0';
                    dataValid_o <= "01";
                    state <= state + 1;
                end if;

            --
            -- Wait for response
            --
            when "0010" =>
                if resp_i(0) = '1' then
                    dataValid_o <= "00";
                    s_axi_bvalid <= '1';
                    state <= state + 1;
                    if resp_i(1) = '0' then
                        s_axi_bresp <= "00";    --No errors occurred in writing data
                    else
                        s_axi_bresp <= "11";    --An error occurred in writing data
                    end if;
                end if;
            
            --
            -- The final phase is to wait for the master to indicate that it is ready to receive a valid write response
            --
            when "0011" =>
                if s_axi_bready = '1' then
                    s_axi_bvalid <= '0';
                    state <= X"0";     --Once the master has indicated that it is ready, go back to the initial state
                end if;

            --
            -- Signal that the address is valid for the MISO process
            --
            when "1001" =>
                dataValid_o <= "11";
                state <= state + 1;
            
            --
            -- Wait for valid data for the MISO process
            --
            when "1010" =>
                if resp_i(0) = '1' then
                    s_axi_rvalid <= '1';
                    state <= state + 1;
                    dataValid_o <= "00";
                    if resp_i(1) = '0' then
                        s_axi_rdata <= readData_i;
                        s_axi_rresp <= "00";
                    else
                        s_axi_rresp <= "11";
                    end if;
                end if;

            --
            -- Return to initial state
            --
            when "1011" =>
                if s_axi_rready = '1' then
                    s_axi_rvalid <= '0';
                    state <= X"0";
                end if;
            
            when others => null;

        end case;
    end if;

end process;

end architecture rtl;