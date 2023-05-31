--Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
--Date        : Sun Nov 21 19:35:28 2021
--Host        : gottfreid running 64-bit Ubuntu 20.04.3 LTS
--Command     : generate_target system_wrapper.bd
--Design      : system_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity system_wrapper is
  port (
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_cas_n : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    adc_clk_n_i : in STD_LOGIC;
    adc_clk_p_i : in STD_LOGIC;
    adc_dat_a_n_i : in STD_LOGIC_VECTOR ( 6 downto 0 );
    adc_dat_a_p_i : in STD_LOGIC_VECTOR ( 6 downto 0 );
    adc_dat_b_n_i : in STD_LOGIC_VECTOR ( 6 downto 0 );
    adc_dat_b_p_i : in STD_LOGIC_VECTOR ( 6 downto 0 );
    adc_sync_o : out STD_LOGIC;
    dac_a_o : out STD_LOGIC_VECTOR ( 13 downto 0 );
    dac_b_o : out STD_LOGIC_VECTOR ( 13 downto 0 );
    dac_pwm_o : out STD_LOGIC_VECTOR ( 3 downto 0 );
    dac_reset_o : out STD_LOGIC;
    exp_n_io : in STD_LOGIC_VECTOR ( 7 downto 0 );
    exp_p_io : out STD_LOGIC_VECTOR ( 7 downto 0 );
    trig_i  :   in  STD_LOGIC;
    led_o : out STD_LOGIC_VECTOR ( 7 downto 0 );
    pll_hi_o : out STD_LOGIC;
    pll_lo_o : out STD_LOGIC;
    vinn_i : in STD_LOGIC_VECTOR ( 4 downto 0 );
    vinp_i : in STD_LOGIC_VECTOR ( 4 downto 0 )
  );
end system_wrapper;

architecture STRUCTURE of system_wrapper is
  component system is
  port (
    dac_pwm_o : out STD_LOGIC_VECTOR ( 3 downto 0 );
    led_o : out STD_LOGIC_VECTOR ( 7 downto 0 );
    vinp_i : in STD_LOGIC_VECTOR ( 4 downto 0 );
    vinn_i : in STD_LOGIC_VECTOR ( 4 downto 0 );
    exp_n_io : in STD_LOGIC_VECTOR ( 7 downto 0 );
    exp_p_io : out STD_LOGIC_VECTOR ( 7 downto 0 );
    trig_i  :   in  STD_LOGIC;
    dac_a_o : out STD_LOGIC_VECTOR ( 13 downto 0 );
    dac_b_o : out STD_LOGIC_VECTOR ( 13 downto 0 );
    dac_reset_o : out STD_LOGIC;
    pll_hi_o : out STD_LOGIC;
    pll_lo_o : out STD_LOGIC;
    adc_dat_a_p_i : in STD_LOGIC_VECTOR ( 6 downto 0 );
    adc_dat_a_n_i : in STD_LOGIC_VECTOR ( 6 downto 0 );
    adc_dat_b_p_i : in STD_LOGIC_VECTOR ( 6 downto 0 );
    adc_dat_b_n_i : in STD_LOGIC_VECTOR ( 6 downto 0 );
    adc_clk_p_i : in STD_LOGIC;
    adc_clk_n_i : in STD_LOGIC;
    adc_sync_o : out STD_LOGIC;
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    DDR_cas_n : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 )
  );
  end component system;
begin
system_i: component system
     port map (
      DDR_addr(14 downto 0) => DDR_addr(14 downto 0),
      DDR_ba(2 downto 0) => DDR_ba(2 downto 0),
      DDR_cas_n => DDR_cas_n,
      DDR_ck_n => DDR_ck_n,
      DDR_ck_p => DDR_ck_p,
      DDR_cke => DDR_cke,
      DDR_cs_n => DDR_cs_n,
      DDR_dm(3 downto 0) => DDR_dm(3 downto 0),
      DDR_dq(31 downto 0) => DDR_dq(31 downto 0),
      DDR_dqs_n(3 downto 0) => DDR_dqs_n(3 downto 0),
      DDR_dqs_p(3 downto 0) => DDR_dqs_p(3 downto 0),
      DDR_odt => DDR_odt,
      DDR_ras_n => DDR_ras_n,
      DDR_reset_n => DDR_reset_n,
      DDR_we_n => DDR_we_n,
      FIXED_IO_ddr_vrn => FIXED_IO_ddr_vrn,
      FIXED_IO_ddr_vrp => FIXED_IO_ddr_vrp,
      FIXED_IO_mio(53 downto 0) => FIXED_IO_mio(53 downto 0),
      FIXED_IO_ps_clk => FIXED_IO_ps_clk,
      FIXED_IO_ps_porb => FIXED_IO_ps_porb,
      FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
      adc_clk_n_i => adc_clk_n_i,
      adc_clk_p_i => adc_clk_p_i,
      adc_dat_a_n_i(6 downto 0) => adc_dat_a_n_i(6 downto 0),
      adc_dat_a_p_i(6 downto 0) => adc_dat_a_p_i(6 downto 0),
      adc_dat_b_n_i(6 downto 0) => adc_dat_b_n_i(6 downto 0),
      adc_dat_b_p_i(6 downto 0) => adc_dat_b_p_i(6 downto 0),
      adc_sync_o => adc_sync_o,
      dac_a_o(13 downto 0) => dac_a_o(13 downto 0),
      dac_b_o(13 downto 0) => dac_b_o(13 downto 0),
      dac_pwm_o(3 downto 0) => dac_pwm_o(3 downto 0),
      dac_reset_o => dac_reset_o,
      exp_n_io(7 downto 0) => exp_n_io(7 downto 0),
      exp_p_io(7 downto 0) => exp_p_io(7 downto 0),
      trig_i    =>  trig_i,
      led_o(7 downto 0) => led_o(7 downto 0),
      pll_hi_o => pll_hi_o,
      pll_lo_o => pll_lo_o,
      vinn_i(4 downto 0) => vinn_i(4 downto 0),
      vinp_i(4 downto 0) => vinp_i(4 downto 0)
    );
end STRUCTURE;
