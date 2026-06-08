//============================================================================
//  Irem M90 for MiSTer FPGA
//
//  Copyright (C) 2023 Martin Donlon
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================


import board_pkg::*;

module emu
(
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [48:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        CLK_VIDEO,

    //Multiple resolutions are supported using different CE_PIXEL rates.
    //Must be based on CLK_VIDEO
    output        CE_PIXEL,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
    output [12:0] VIDEO_ARX,
    output [12:0] VIDEO_ARY,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)
    output        VGA_F1,
    output [1:0]  VGA_SL,
    output        VGA_SCALER, // Force VGA scaler
    output        VGA_DISABLE,

    input  [11:0] HDMI_WIDTH,
    input  [11:0] HDMI_HEIGHT,
    output        HDMI_FREEZE,

`ifdef MISTER_FB
    // Use framebuffer in DDRAM (USE_FB=1 in qsf)
    // FB_FORMAT:
    //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
    //    [3]   : 0=16bits 565 1=16bits 1555
    //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
    //
    // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
    output        FB_EN,
    output  [4:0] FB_FORMAT,
    output [11:0] FB_WIDTH,
    output [11:0] FB_HEIGHT,
    output [31:0] FB_BASE,
    output [13:0] FB_STRIDE,
    input         FB_VBL,
    input         FB_LL,
    output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output        FB_PAL_CLK,
    output  [7:0] FB_PAL_ADDR,
    output [23:0] FB_PAL_DOUT,
    input  [23:0] FB_PAL_DIN,
    output        FB_PAL_WR,
`endif
`endif

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    // I/O board button press simulation (active high)
    // b[1]: user button
    // b[0]: osd button
    output  [1:0] BUTTONS,

    input         CLK_AUDIO, // 24.576 MHz
    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
    output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

    //ADC
    inout   [3:0] ADC_BUS,

    //SD-SPI
    output        SD_SCK,
    output        SD_MOSI,
    input         SD_MISO,
    output        SD_CS,
    input         SD_CD,

    //High latency DDR3 RAM interface
    //Use for non-critical time purposes
    output        DDRAM_CLK,
    input         DDRAM_BUSY,
    output  [7:0] DDRAM_BURSTCNT,
    output [28:0] DDRAM_ADDR,
    input  [63:0] DDRAM_DOUT,
    input         DDRAM_DOUT_READY,
    output        DDRAM_RD,
    output [63:0] DDRAM_DIN,
    output  [7:0] DDRAM_BE,
    output        DDRAM_WE,

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
    //Secondary SDRAM
    //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
    input         SDRAM2_EN,
    output        SDRAM2_CLK,
    output [12:0] SDRAM2_A,
    output  [1:0] SDRAM2_BA,
    inout  [15:0] SDRAM2_DQ,
    output        SDRAM2_nCS,
    output        SDRAM2_nCAS,
    output        SDRAM2_nRAS,
    output        SDRAM2_nWE,
`endif

    input         UART_CTS,
    output        UART_RTS,
    input         UART_RXD,
    output        UART_TXD,
    output        UART_DTR,
    input         UART_DSR,

    // Open-drain User port.
    // 0 - D+/RX
    // 1 - D-/TX
    // 2..6 - USR2..USR6
    // Set USER_OUT to 1 to read from USER_IN.
    // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_OSD + per-pin push-pull mask, USER_IO widened to 8 bits
    output        USER_OSD,
    output  [7:0] USER_PP,
    input   [7:0] USER_IN,
    output  [7:0] USER_OUT,
    // [MiSTer-DB9 END]

    input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP driven by wrapper; USER_OUT driven by joydb (USER_OUT_DRIVE) below
assign USER_PP = USER_PP_DRIVE;
// [MiSTer-DB9 END]
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign CLK_VIDEO = clk_sys;

assign DDRAM_CLK = clk_sys;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;

assign AUDIO_S = 1;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[2:1];
wire [2:0] scandoubler_fx = status[31:29];
wire [1:0] scale = status[6:5];
wire pause_in_osd = status[7];
wire system_pause;

assign HDMI_FREEZE = 0; //system_pause;

wire [1:0] dbg_en_layers = ~status[65:64];
wire dbg_solid_sprites = status[67];

`include "build_id.v" 
localparam CONF_STR = {
    "IremM90;;",
    "-;",
    "P1,Video Settings;",
    "P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
    "P1O[31:29],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    "P1O[6:5],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
    "P1-;",
    "P1O[10],Orientation,Horz,Vert;",
    "P1-;",
    "P1O[11],Squished 224p,Off,On;",
    "P1-;",
    "P1O[21:17],Analog Video H-Pos,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1O[26:22],Analog Video V-Pos,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
    "-;",
    "O[7],OSD Pause,Off,On;",
    "-;",
    "O[8],Autosave Score Data,Off,On;",
    "-;",
    "DIP;",
    "-;",
    "P2,Debug;",
    "P2-;",
    "P2O[64],Layer 1,On,Off;",
    "P2O[65],Layer 2,On,Off;",
    "P2O[67],Solid Sprites,Off,On;",
    "-;",
    // [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
    "O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
    "O[125],UserIO Players, 1 Player,2 Players;",
    // [MiSTer-DB9-Pro END]
    "-;",
    "T[0],Reset;",
    "DEFMRA,/_Arcade/m90_test.mra;",
    "V,v",`BUILD_DATE
};

wire        forced_scandoubler;
wire  [1:0] buttons;
wire [127:0] status;
wire [10:0] ps2_key;

wire ioctl_rom_wait;
wire ioctl_hs_upload_req;
wire ioctl_m90_upload_req;
wire [7:0] ioctl_hs_din;
wire [7:0] ioctl_m90_din;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req = ioctl_hs_upload_req | ioctl_m90_upload_req;
wire  [7:0] ioctl_index;
wire  [7:0] ioctl_upload_index;
wire        ioctl_wr;
wire        ioctl_rd;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din = ioctl_m90_din | ioctl_hs_din;
wire        ioctl_wait = ioctl_rom_wait;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: rename USB joystick wires (P1/P2 get DB9 routing; P3/P4 stay USB)
wire [15:0] joystick_p1_USB, joystick_p2_USB;
wire [15:0] joystick_p3, joystick_p4;
// [MiSTer-DB9 END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
// SNAC cores: replace 1'b0 with the core's SNAC enable expression so SNAC
// preempts the joydb wrapper on shared USER_IO pins. Default 1'b0 is no-op.
wire         snac_active     = 1'b0;
// MT32-pi cores on primary USER_IO: replace 1'b0 with the core's MT32-active
// expression. Default 1'b0 (no MT32 on this core).
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;

// [MiSTer-DB9 BEGIN] - DB9 programmable-remap matrix wires
// joydb_*_mapped = MiSTer-standard joystick words (consumed in Layer B);
// db9_remap_* = 0xFD selector stream driven by the hps_io instance.
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;
// [MiSTer-DB9 END]
joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_sys            ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .remap_cmd       ( db9_remap_cmd      ),
  .remap_byte_cnt  ( db9_remap_byte_cnt ),
  .remap_din       ( db9_remap_din      ),
  .joydb_1_mapped  ( joydb_1_mapped     ),
  .joydb_2_mapped  ( joydb_2_mapped     ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open; remap joydb bits to Irem M90 order
// M90 consumer layout (per <core>.sv + rtl/m90.sv + MRA button names):
//   p1_input[3:0] = directions U/D/L/R   <- joystick[3:0]
//   p1_input[4]   = Fire  (Drop Bomb / B) <- joystick[4]
//   p1_input[5]   = Fire2 (Detonate / A)  <- joystick[5]
//   m_start1      = joystick_p1[10]
//   m_coin1       = joystick_p1[11]
//   m_pause       = joystick_combined[13]
// 2-button core (MRA num_buttons=2). joydb_1 source bits:
//   [3:0]=R/L/D/U [4]=A [5]=B [6]=C [10]=Start [11]=Mode/Select/R-trigger
//   Fire    <- joydb_1[4]  (A)
//   Fire2   <- joydb_1[5]  (B)
//   Start   <- joydb_1[10] (Start)            -> output bit 10
//   Coin    <- joydb_1[11]|(joydb_1[10]&joydb_1[5])  (Select, OR Start+B chord
//              so a 3-button MD pad can still insert coins) -> output bit 11
//   Pause   <- joydb_1[6]  (C, spare face button)        -> output bit 13
// Output bits [9:6] and [12] left 0 (unused face buttons / P2-start-alt).
wire [15:0] joystick_p1 = joydb_1ena ? (OSD_STATUS ? 16'b0 :
       { 2'b0, joydb_1[6], 1'b0, joydb_1[11]|(joydb_1[10]&joydb_1[5]), joydb_1[10], 4'b0, joydb_1[5:0] })
       : joystick_p1_USB;
wire [15:0] joystick_p2 = joydb_2ena ? (OSD_STATUS ? 16'b0 :
       { 2'b0, joydb_2[6], 1'b0, joydb_2[11]|(joydb_2[10]&joydb_2[5]), joydb_2[10], 4'b0, joydb_2[5:0] })
       : joydb_1ena ? joystick_p1_USB : joystick_p2_USB;
// [MiSTer-DB9-Pro END]

wire [21:0] gamma_bus;
wire        direct_video;
wire        video_rotated;
wire        no_rotate = ~status[10];
wire        flip = 0;
wire        rotate_ccw = 1;

wire        autosave = status[8];

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),
    .EXT_BUS(),
    .gamma_bus(gamma_bus),
    .direct_video(direct_video),

    .forced_scandoubler(forced_scandoubler),
    .new_vmode(0),
    .video_rotated(video_rotated),

    .buttons(buttons),
    .status(status),
    .status_menumask({direct_video}),

    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_upload_index(ioctl_upload_index),
    .ioctl_upload_req(ioctl_upload_req & autosave),
    .ioctl_wr(ioctl_wr),
    .ioctl_rd(ioctl_rd),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(ioctl_din),
    .ioctl_index(ioctl_index),
    .ioctl_wait(ioctl_wait),

    .joystick_0(joystick_p1_USB),
    .joystick_1(joystick_p2_USB),
    .joystick_2(joystick_p3),
    .joystick_3(joystick_p4),

    // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
    .joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
    // programmable remap matrix selector load (UIO_DB9_MAP 0xFD)
    .db9_remap_cmd(db9_remap_cmd),
    .db9_remap_byte_cnt(db9_remap_byte_cnt),
    .db9_remap_din(db9_remap_din),
    // [MiSTer-DB9 END]

    .ps2_key(ps2_key),

    // [MiSTer-DB9-Pro BEGIN] - Saturn key gate
    .saturn_unlocked(saturn_unlocked)
    // [MiSTer-DB9-Pro END]
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
wire clk_ram;
wire pll_locked;
pll pll
(
    .refclk(CLK_50M),
    .rst(0),
    .outclk_0(clk_ram),
    .outclk_1(clk_sys),
    .locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1] | rom_load_busy;

///////////////////////////////////////////////////////////////////////
// SDRAM
///////////////////////////////////////////////////////////////////////
wire [63:0] sdr_bg_dout;
wire [24:0] sdr_bg_addr;
wire sdr_bg_req, sdr_bg_rdy, sdr_bg_64bit;

wire [63:0] sdr_cpu_dout;
wire [24:0] sdr_cpu_addr;
wire sdr_cpu_req;

reg [24:0] sdr_rom_addr;
reg [15:0] sdr_rom_data;
reg [1:0] sdr_rom_be;
reg sdr_rom_req;

wire rom_load_busy;
wire sdr_rom_write = rom_load_busy;

wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_cpu_addr;
wire [15:0] sdr_ch3_din = sdr_rom_data;
wire [1:0] sdr_ch3_be = sdr_rom_write ? sdr_rom_be : 2'b00;
wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : 1'b1;
wire sdr_ch3_req = sdr_rom_write ? sdr_rom_req : sdr_cpu_req;
wire sdr_ch3_rdy;
wire sdr_cpu_rdy = sdr_ch3_rdy;
wire sdr_rom_rdy = sdr_ch3_rdy;

wire [19:0] bram_addr;
wire [7:0] bram_data;
wire [4:0] bram_cs;
wire bram_wr;

board_cfg_t board_cfg;

sdram sdram
(
    .*,
    .doRefresh(1),
    .init(~pll_locked),
    .clk(clk_ram),

    .ch1_addr(sdr_bg_addr[24:1]),
    .ch1_dout(sdr_bg_dout),
    .ch1_req(sdr_bg_req),
    .ch1_ready(sdr_bg_rdy),
    .ch1_64bit(sdr_bg_64bit),

    .ch2_addr(0),
    .ch2_dout(),
    .ch2_req(0),
    .ch2_ready(),

    // multiplexed with rom download and cpu read/writes
    .ch3_addr(sdr_ch3_addr[24:1]),
    .ch3_din(sdr_ch3_din),
    .ch3_dout(sdr_cpu_dout),
    .ch3_be(sdr_ch3_be),
    .ch3_rnw(sdr_ch3_rnw),
    .ch3_req(sdr_ch3_req),
    .ch3_ready(sdr_ch3_rdy),

    .ch4_addr(0),
    .ch4_dout(),
    .ch4_req(0),
    .ch4_ready()
);


wire rom_data_wait;
wire rom_data_strobe;
wire [7:0] rom_data;

wire   [7:0] ROTATE_DDRAM_BURSTCNT, ROM_DDRAM_BURSTCNT;
wire  [28:0] ROTATE_DDRAM_ADDR, ROM_DDRAM_ADDR;
wire         ROTATE_DDRAM_RD, ROM_DDRAM_RD;
wire   [7:0] ROTATE_DDRAM_BE, ROM_DDRAM_BE;
wire         ROTATE_DDRAM_WE, ROM_DDRAM_WE;

assign DDRAM_BURSTCNT = rom_load_busy ? ROM_DDRAM_BURSTCNT : ROTATE_DDRAM_BURSTCNT;
assign DDRAM_ADDR     = rom_load_busy ? ROM_DDRAM_ADDR     : ROTATE_DDRAM_ADDR;
assign DDRAM_RD       = rom_load_busy ? ROM_DDRAM_RD       : ROTATE_DDRAM_RD;
assign DDRAM_BE       = rom_load_busy ? ROM_DDRAM_BE       : ROTATE_DDRAM_BE;
assign DDRAM_WE       = rom_load_busy ? ROM_DDRAM_WE       : ROTATE_DDRAM_WE;

ddr_download_adaptor ddr_download(
    .clk(clk_sys),

    .ioctl_download,
    .ioctl_addr,
    .ioctl_index,
    .ioctl_wr,
    .ioctl_data(ioctl_dout),
    .ioctl_wait(ioctl_rom_wait),

    .busy(rom_load_busy),
    
    .data_wait(rom_data_wait),
    .data_strobe(rom_data_strobe),
    .data(rom_data),

	.DDRAM_BUSY,
	.DDRAM_DOUT,
    .DDRAM_DOUT_READY,
	.DDRAM_BURSTCNT(ROM_DDRAM_BURSTCNT),
	.DDRAM_ADDR(ROM_DDRAM_ADDR),
	.DDRAM_BE(ROM_DDRAM_BE),
	.DDRAM_WE(ROM_DDRAM_WE),
	.DDRAM_RD(ROM_DDRAM_RD)
);

rom_loader rom_loader(
    .sys_clk(clk_sys),
    .ram_clk(clk_ram),

    .ioctl_wr(rom_data_strobe),
    .ioctl_data(rom_data),
    .ioctl_wait(rom_data_wait),

    .sdr_addr(sdr_rom_addr),
    .sdr_data(sdr_rom_data),
    .sdr_be(sdr_rom_be),
    .sdr_req(sdr_rom_req),
    .sdr_rdy(sdr_rom_rdy),

    .bram_addr(bram_addr),
    .bram_data(bram_data),
    .bram_cs(bram_cs),
    .bram_wr(bram_wr),

    .board_cfg(board_cfg)
);


// DIP SWITCHES
reg [7:0] dip_sw[8];	// Active-LOW
always @(posedge clk_sys) begin
    if(ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3])
        dip_sw[ioctl_addr[2:0]] <= ioctl_dout;
end


//////////////////  Arcade Buttons/Interfaces   ///////////////////////////
wire [15:0] keyboard_p1, keyboard_p2, keyboard_p3, keyboard_p4;

wire [15:0] merged_p1 = keyboard_p1 | joystick_p1;
wire [15:0] merged_p2 = keyboard_p2 | joystick_p2;
wire [15:0] merged_p3 = keyboard_p3 | joystick_p3;
wire [15:0] merged_p4 = keyboard_p4 | joystick_p4;

wire [15:0] joystick_combined = joystick_p1 | joystick_p2 | joystick_p3 | joystick_p4;
wire [3:0] key_coin, key_start;
wire key_pause;

mame_keys mame_keys(
    .clk(clk_sys),
    .reset(reset),

    .ps2_key(ps2_key),

    .start(key_start),
    .coin(key_coin),

    .p1(keyboard_p1),
    .p2(keyboard_p2),
    .p3(keyboard_p3),
    .p4(keyboard_p4),

    .pause(key_pause)
);

//Start/coin
wire m_start1   = joystick_p1[10] | key_start[0];
wire m_start2   = joystick_p2[10] | joystick_combined[12] | key_start[1];
wire m_start3   = joystick_p3[10] | key_start[2];
wire m_start4   = joystick_p4[10] | key_start[3];
wire m_coin1    = joystick_p1[11] | key_coin[0];
wire m_coin2    = joystick_p2[11] | key_coin[1];
wire m_coin3    = joystick_p3[11] | key_coin[2];
wire m_coin4    = joystick_p4[11] | key_coin[3];
wire m_pause    = joystick_combined[13] | key_pause;

//////////////////////////////////////////////////////////////////

wire [7:0] core_r, core_g, core_b;
wire core_hb, core_vb, core_hs, core_vs;
wire [7:0] shrink_r, shrink_g, shrink_b;
wire shrink_hb, shrink_vb, shrink_hs, shrink_vs;
wire resync_hs, resync_vs;
wire ce_pix;

m90 m90(
    .clk_sys(clk_sys),
    .clk_ram(clk_ram),
    .ce_pix(ce_pix),
    .reset_n(~reset),
    .HBlank(core_hb),
    .VBlank(core_vb),
    .HSync(core_hs),
    .VSync(core_vs),
    .R(core_r),
    .G(core_g),
    .B(core_b),
    .AUDIO_L(AUDIO_L),
    .AUDIO_R(AUDIO_R),

    .board_cfg(board_cfg),

    .coin({m_coin4, m_coin3, m_coin2, m_coin1}),
    .start_buttons({m_start4, m_start3, m_start2, m_start1}),
    
    .p1_input(merged_p1[9:0]),
    .p2_input(merged_p2[9:0]),
    .p3_input(merged_p3[9:0]),
    .p4_input(merged_p4[9:0]),
   
    .dip_sw({dip_sw[2], dip_sw[1], dip_sw[0]}),

    .sdr_bg_addr(sdr_bg_addr),
    .sdr_bg_dout(sdr_bg_dout),
    .sdr_bg_req(sdr_bg_req),
    .sdr_bg_rdy(sdr_bg_rdy),
    .sdr_bg_64bit(sdr_bg_64bit),

    .sdr_cpu_dout(sdr_cpu_dout),
    .sdr_cpu_addr(sdr_cpu_addr),
    .sdr_cpu_req(sdr_cpu_req),
    .sdr_cpu_rdy(sdr_cpu_rdy),

    .clk_bram(clk_sys),
    .bram_addr(bram_addr),
    .bram_data(bram_data),
    .bram_cs(bram_cs),
    .bram_wr(bram_wr),

    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	
    .ioctl_upload(ioctl_upload),
    .ioctl_upload_index(ioctl_upload_index),
	.ioctl_din(ioctl_m90_din),
	.ioctl_rd(ioctl_rd),
    .ioctl_upload_req(ioctl_m90_upload_req),

    .pause_rq(system_pause),
    .cpu_paused(cpu_paused),
    .cpu_turbo(0),

    .hs_address,
    .hs_din,
    .hs_dout,
    .hs_write,
    .hs_read,

    .dbg_en_layers(dbg_en_layers),
    .dbg_solid_sprites(dbg_solid_sprites)
);

wire enable_vshrink = status[11];
vshrink vshrink(
    .clk(CLK_VIDEO),
    .ce_pix,

    .enable(enable_vshrink),
    .debug(0),

    .hs_in(core_hs),
    .vs_in(core_vs),
    .hb_in(core_hb),
    .vb_in(core_vb),
    .r_in(core_r),
    .g_in(core_g),
    .b_in(core_b),

    .hs_out(shrink_hs),
    .vs_out(shrink_vs),
    .hb_out(shrink_hb),
    .vb_out(shrink_vb),
    .r_out(shrink_r),
    .g_out(shrink_g),
    .b_out(shrink_b)
);

// H/V offset
wire [4:0]	hoffset = status[21:17];
wire [4:0]	voffset = status[26:22];
jtframe_resync #(5) jtframe_resync
(
	.clk(CLK_VIDEO),
	.pxl_cen(ce_pix),
	.hs_in(shrink_hs),
	.vs_in(shrink_vs),
	.LVBL(~shrink_vb),
	.LHBL(~shrink_hb),
	.hoffset(-hoffset), // flip the sign
	.voffset(-voffset),
	.hs_out(resync_hs),
	.vs_out(resync_vs)
);

wire VGA_DE_MIXER;

wire [2:0] sl = scandoubler_fx ? scandoubler_fx - 1'd1 : 3'd0;
wire use_scandoubler = scandoubler_fx || forced_scandoubler;

assign VGA_SL  = sl[1:0];

video_mixer #(.LINE_LENGTH(324), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.CLK_VIDEO(CLK_VIDEO),
	.ce_pix(ce_pix),
	.CE_PIXEL(CE_PIXEL),

	.scandoubler(use_scandoubler),
	.hq2x(scandoubler_fx == 1),
	.gamma_bus(gamma_bus),

	.HBlank(shrink_hb),
	.VBlank(shrink_vb),
	.HSync(resync_hs),
	.VSync(resync_vs),

	.R(shrink_r),
	.G(shrink_g),
	.B(shrink_b),

	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE_MIXER)
);

video_freak video_freak(
    .CLK_VIDEO(CLK_VIDEO),
    .CE_PIXEL(CE_PIXEL),
    .VGA_VS(VGA_VS),
    .HDMI_WIDTH(HDMI_WIDTH),
    .HDMI_HEIGHT(HDMI_HEIGHT),
    .VGA_DE(VGA_DE),
    .VIDEO_ARX(VIDEO_ARX),
    .VIDEO_ARY(VIDEO_ARY),

    .VGA_DE_IN(VGA_DE_MIXER),
    .ARX((!ar) ? ( no_rotate ? 12'd4 : 12'd3 ) : (ar - 1'd1)),
    .ARY((!ar) ? ( no_rotate ? 12'd3 : 12'd4 ) : 12'd0),
    .CROP_SIZE(0),
    .CROP_OFF(0),
    .SCALE(scale)
);


pause pause(
    .clk_sys(clk_sys),
    .reset(reset),
    .user_button(m_pause),
    .pause_request(hs_pause),
    .options({1'b0, pause_in_osd}),
    .pause_cpu(system_pause),
    .OSD_STATUS(OSD_STATUS)
);

screen_rotate screen_rotate(
    .DDRAM_CLK(), // it's clk_sys and clk_video
    .DDRAM_BUSY,
    .DDRAM_BURSTCNT(ROTATE_DDRAM_BURSTCNT),
    .DDRAM_ADDR(ROTATE_DDRAM_ADDR),
    .DDRAM_DIN,
    .DDRAM_BE(ROTATE_DDRAM_BE),
    .DDRAM_WE(ROTATE_DDRAM_WE),
    .DDRAM_RD(ROTATE_DDRAM_RD),
    .*
);

//HISCORE

wire [19:0]     hs_address;
wire [7:0]      hs_din;
wire [7:0]      hs_dout;
wire hs_write;
wire hs_read;
wire hs_pause;
wire hs_configured;
wire cpu_paused;
reg hs_data_ready;

always_ff @(posedge clk_sys) begin
    hs_data_ready <= hs_read | hs_write;
end

hiscore #(
                .HS_ADDRESSWIDTH(20),
                .CFG_LENGTHWIDTH(2)
) hi (
        .*,
        .ioctl_upload_req(ioctl_hs_upload_req),
        .clk(clk_sys),
        .paused(cpu_paused),
        .autosave(status[8]),
        .ram_address(hs_address),
        .v_sync(core_vs),
        .data_ready(hs_data_ready),
        .data_from_ram(hs_dout),
        .data_to_ram(hs_din),
        .data_from_hps(ioctl_dout),
        .data_to_hps(ioctl_hs_din),
        .ram_write(hs_write),
        .ram_read(hs_read),
        .ram_intent_read(),
        .ram_intent_write(),
        .pause_cpu(hs_pause),
        .configured(hs_configured)
);
endmodule
