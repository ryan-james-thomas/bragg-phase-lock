--Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
--Date        : Fri Aug 13 11:55:01 2021
--Host        : RSPE-056285 running 64-bit major release  (build 9200)
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
    adc_csn_o : out STD_LOGIC;
    adc_dat_a_i : in STD_LOGIC_VECTOR ( 13 downto 0 );
    adc_dat_b_i : in STD_LOGIC_VECTOR ( 13 downto 0 );
    adc_enc_n_o : out STD_LOGIC;
    adc_enc_p_o : out STD_LOGIC;
    dac_clk_o : out STD_LOGIC;
    dac_dat_o : out STD_LOGIC_VECTOR ( 13 downto 0 );
    dac_pwm_o : out STD_LOGIC_VECTOR ( 3 downto 0 );
    dac_rst_o : out STD_LOGIC;
    dac_sel_o : out STD_LOGIC;
    dac_wrt_o : out STD_LOGIC;
    daisy_n_i : in STD_LOGIC_VECTOR ( 1 downto 0 );
    daisy_n_o : out STD_LOGIC_VECTOR ( 1 downto 0 );
    daisy_p_i : in STD_LOGIC_VECTOR ( 1 downto 0 );
    daisy_p_o : out STD_LOGIC_VECTOR ( 1 downto 0 );
    exp_n_tri_io : in STD_LOGIC_VECTOR ( 7 downto 0 );
    exp_p_tri_io : out STD_LOGIC_VECTOR ( 7 downto 0 );
    led_o : out STD_LOGIC_VECTOR ( 7 downto 0 )
  );
end system_wrapper;

architecture STRUCTURE of system_wrapper is
  component system is
  port (
    adc_dat_a_i : in STD_LOGIC_VECTOR ( 13 downto 0 );
    adc_dat_b_i : in STD_LOGIC_VECTOR ( 13 downto 0 );
    adc_clk_p_i : in STD_LOGIC;
    adc_clk_n_i : in STD_LOGIC;
    adc_enc_p_o : out STD_LOGIC;
    adc_enc_n_o : out STD_LOGIC;
    adc_csn_o : out STD_LOGIC;
    dac_dat_o : out STD_LOGIC_VECTOR ( 13 downto 0 );
    dac_clk_o : out STD_LOGIC;
    dac_rst_o : out STD_LOGIC;
    dac_sel_o : out STD_LOGIC;
    dac_wrt_o : out STD_LOGIC;
    dac_pwm_o : out STD_LOGIC_VECTOR ( 3 downto 0 );
    daisy_p_o : out STD_LOGIC_VECTOR ( 1 downto 0 );
    daisy_n_o : out STD_LOGIC_VECTOR ( 1 downto 0 );
    daisy_p_i : in STD_LOGIC_VECTOR ( 1 downto 0 );
    daisy_n_i : in STD_LOGIC_VECTOR ( 1 downto 0 );
    led_o : out STD_LOGIC_VECTOR ( 7 downto 0 );
    exp_n_tri_io : in STD_LOGIC_VECTOR ( 7 downto 0 );
    exp_p_tri_io : out STD_LOGIC_VECTOR ( 7 downto 0 );
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
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC
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
      adc_csn_o => adc_csn_o,
      adc_dat_a_i(13 downto 0) => adc_dat_a_i(13 downto 0),
      adc_dat_b_i(13 downto 0) => adc_dat_b_i(13 downto 0),
      adc_enc_n_o => adc_enc_n_o,
      adc_enc_p_o => adc_enc_p_o,
      dac_clk_o => dac_clk_o,
      dac_dat_o(13 downto 0) => dac_dat_o(13 downto 0),
      dac_pwm_o(3 downto 0) => dac_pwm_o(3 downto 0),
      dac_rst_o => dac_rst_o,
      dac_sel_o => dac_sel_o,
      dac_wrt_o => dac_wrt_o,
      daisy_n_i(1 downto 0) => daisy_n_i(1 downto 0),
      daisy_n_o(1 downto 0) => daisy_n_o(1 downto 0),
      daisy_p_i(1 downto 0) => daisy_p_i(1 downto 0),
      daisy_p_o(1 downto 0) => daisy_p_o(1 downto 0),
      exp_n_tri_io(7 downto 0) => exp_n_tri_io(7 downto 0),
      exp_p_tri_io(7 downto 0) => exp_p_tri_io(7 downto 0),
      led_o(7 downto 0) => led_o(7 downto 0)
    );
end STRUCTURE;
