--------------------------------------------------------------------------
-- Copyright 2021-2024 The Aerospace Corporation.
-- This file is a part of SatCat5, licensed under CERN-OHL-W v2 or later.
--------------------------------------------------------------------------
--
-- Port-type wrapper for "port_rgmii"
--
-- Xilinx IP-cores can only use simple std_logic and std_logic_vector types.
-- This shim provides that conversion.
--

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     work.common_functions.all;
use     work.common_primitives.all;
use     work.ptp_types.all;
use     work.switch_types.all;

entity wrap_port_rgmii is
    generic (
    PTP_ENABLE  : boolean := false; -- Enable PTP timestamps?
    PTP_REF_HZ  : integer := 0;     -- Vernier reference frequency
    PTP_TAU_MS  : integer := 50;    -- Tracking time constant (msec)
    PTP_AUX_EN  : boolean := true;  -- Enable extra tracking filter?
    RXCLK_ALIGN : boolean := false; -- Enable precision clock-buffer deskew
    RXCLK_LOCAL : boolean := false; -- Enable input clock buffer (local)
    RXCLK_GLOBL : boolean := true;  -- Enable input clock buffer (global)
    RXCLK_DELAY : integer := 0;     -- Input clock delay, in picoseconds (typ. 0 or 2000)
    RXDAT_DELAY : integer := 0);    -- Input data/control delay, in picoseconds
    port (
    -- External RGMII interface.
    rgmii_txc   : out std_logic;
    rgmii_txd   : out std_logic_vector(3 downto 0);
    rgmii_txctl : out std_logic;
    rgmii_rxc   : in  std_logic;
    rgmii_rxd   : in  std_logic_vector(3 downto 0);
    rgmii_rxctl : in  std_logic;

    -- Network port
    sw_rx_clk   : out std_logic;
    sw_rx_data  : out std_logic_vector(7 downto 0);
    sw_rx_last  : out std_logic;
    sw_rx_write : out std_logic;
    sw_rx_error : out std_logic;
    sw_rx_rate  : out std_logic_vector(15 downto 0);
    sw_rx_status: out std_logic_vector(7 downto 0);
    sw_rx_tsof  : out std_logic_vector(47 downto 0);
    sw_rx_tfreq : out std_logic_vector(39 downto 0);
    sw_rx_reset : out std_logic;
    sw_tx_clk   : out std_logic;
    sw_tx_data  : in  std_logic_vector(7 downto 0);
    sw_tx_last  : in  std_logic;
    sw_tx_valid : in  std_logic;
    sw_tx_ready : out std_logic;
    sw_tx_error : out std_logic;
    sw_tx_pstart: out std_logic;
    sw_tx_tnow  : out std_logic_vector(47 downto 0);
    sw_tx_tfreq : out std_logic_vector(39 downto 0);
    sw_tx_reset : out std_logic;

    -- Vernier reference time (optional)
    tref_vclka  : in  std_logic;
    tref_vclkb  : in  std_logic;
    tref_tnext  : in  std_logic;
    tref_tstamp : in  std_logic_vector(47 downto 0);

    -- Reference clock and reset.
    clk_125     : in  std_logic;    -- Main reference clock
    clk_txc     : in  std_logic;    -- Same clock or delayed clock
    reset_p     : in  std_logic);   -- Reset / port shutdown
end wrap_port_rgmii;

architecture wrap_port_rgmii of wrap_port_rgmii is

constant VCONFIG : vernier_config := create_vernier_config(
    value_else_zero(PTP_REF_HZ, PTP_ENABLE), real(PTP_TAU_MS), PTP_AUX_EN);

signal rx_data  : port_rx_m2s;
signal tx_data  : port_tx_s2m;
signal tx_ctrl  : port_tx_m2s;
signal ref_time : port_timeref;

begin

-- Convert port signals.
sw_rx_clk       <= rx_data.clk;
sw_rx_data      <= rx_data.data;
sw_rx_last      <= rx_data.last;
sw_rx_write     <= rx_data.write;
sw_rx_error     <= rx_data.rxerr;
sw_rx_rate      <= rx_data.rate;
sw_rx_tsof      <= std_logic_vector(rx_data.tsof);
sw_rx_tfreq     <= std_logic_vector(rx_data.tfreq);
sw_rx_status    <= rx_data.status;
sw_rx_reset     <= rx_data.reset_p;
sw_tx_clk       <= tx_ctrl.clk;
sw_tx_ready     <= tx_ctrl.ready;
sw_tx_pstart    <= tx_ctrl.pstart;
sw_tx_tnow      <= std_logic_vector(tx_ctrl.tnow);
sw_tx_tfreq     <= std_logic_vector(tx_ctrl.tfreq);
sw_tx_error     <= tx_ctrl.txerr;
sw_tx_reset     <= tx_ctrl.reset_p;
tx_data.data    <= sw_tx_data;
tx_data.last    <= sw_tx_last;
tx_data.valid   <= sw_tx_valid;

-- Convert Vernier signals.
ref_time.vclka  <= tref_vclka;
ref_time.vclkb  <= tref_vclkb;
ref_time.tnext  <= tref_tnext;
ref_time.tstamp <= unsigned(tref_tstamp);

-- Unit being wrapped.
-- Note: Unit conversion from picoseconds (integer) to nanoseconds (real)
--       is a workaround for bugs in certain Vivado versions.  See also:
--       https://www.xilinx.com/support/answers/58038.html
u_wrap : entity work.port_rgmii
    generic map(
    RXCLK_ALIGN => RXCLK_ALIGN,
    RXCLK_LOCAL => RXCLK_LOCAL,
    RXCLK_GLOBL => RXCLK_GLOBL,
    RXCLK_DELAY => 0.001 * real(RXCLK_DELAY),
    RXDAT_DELAY => 0.001 * real(RXDAT_DELAY),
    VCONFIG     => VCONFIG)
    port map(
    rgmii_txc   => rgmii_txc,
    rgmii_txd   => rgmii_txd,
    rgmii_txctl => rgmii_txctl,
    rgmii_rxc   => rgmii_rxc,
    rgmii_rxd   => rgmii_rxd,
    rgmii_rxctl => rgmii_rxctl,
    rx_data     => rx_data,
    tx_data     => tx_data,
    tx_ctrl     => tx_ctrl,
    ref_time    => ref_time,
    clk_125     => clk_125,
    clk_txc     => clk_txc,
    reset_p     => reset_p);

end wrap_port_rgmii;
