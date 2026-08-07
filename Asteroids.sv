//============================================================================
//  Asteroids for MiSTer
//
//  Written 2026 by Videodr0me
//
//  Original arcade hardware by Atari, 1979.
//============================================================================

// [MiSTer-DB9 BEGIN] - upstream claims status[126:124], so joy_type/joy_2p are
// relocated off the fleet-default 127:126/125. Must precede any status[] use.
// [MiSTer-DB9 RESERVED status bits: 65:64 63]
// [MiSTer-DB9 END]

module emu
(
	// [MiSTer-DB9 BEGIN] - inlined sys/emu_ports.vh, extended for DB9 (USER_OSD, USER_PP, 8-bit USER_IN/OUT)
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

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
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

	`ifdef MISTER_FB
	// Use framebuffer in DDRAM
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
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: OSD button, per-pin push-pull mask, 8-bit user port
	output        USER_OSD,
	output  [7:0] USER_PP,
	input   [7:0] USER_IN,
	output  [7:0] USER_OUT,
	// [MiSTer-DB9 END]

	input         OSD_STATUS
	// [MiSTer-DB9 END]
);

	`include "build_id.v"

	logic [127:0] status;
	logic [31:0] joystick_0;
	logic [31:0] joystick_1;
	logic [31:0] joystick;
	logic [15:0] analog_left;
	logic [15:0] analog_right;
	logic  [8:0] spinner_0;
	logic [24:0] ps2_mouse;
	logic  [1:0] buttons;
	logic        direct_video;
	wire  [21:0] gamma_bus;

	logic        ioctl_download;
	logic        ioctl_upload;
	logic        ioctl_upload_req;
	logic        ioctl_wr;
	logic [26:0] ioctl_addr;
	logic  [7:0] ioctl_dout;
	logic  [7:0] ioctl_din;
	logic [15:0] ioctl_index;

	logic clk_12;
	logic clk_render; // 128.520 MHz video, renderer, and SDRAM domain.
	logic pll_locked;

	logic [2:0] profile;
	logic       profile_off;
	logic       profile_touch;
	logic       profile_typical;
	logic       profile_overdriven;
	logic       profile_ultraviolet;
	logic       profile_red_alert;
	logic       profile_custom_1;
	logic       profile_custom_2;
	logic       profile_flashing;
	logic [2:0] custom_bloom_width;
	logic [2:0] custom_halo;
	logic       custom_active;
	logic       custom_bloom_off;
	logic       custom_halo_off;
	logic [1:0] off_tone_mapping;
	logic [1:0] custom_1_tone_mapping;
	logic [1:0] custom_2_tone_mapping;
	logic [27:0] custom_1_settings;
	logic [27:0] custom_2_settings;
	logic        custom_artwork_enable;
	logic  [2:0] custom_artwork_blend;
	logic        video_is_720p;
	logic        artwork_available;
	logic        artwork_available_meta = 1'b0;
	logic        artwork_available_ui = 1'b0;
	logic        artwork_ioctl_wait;
	logic        video_mode_toggle;
	logic        video_freeze;
	logic  [7:0] game_id = 8'd0;
	logic        game_is_deluxe;
	logic        game_is_lander;
	logic        info_req = 1'b0;
	logic  [7:0] info = 8'd0;

	assign game_is_deluxe = (game_id == 8'd1);
	assign game_is_lander = (game_id == 8'd2);
	assign profile = status[68:66] + 3'd2;
	assign profile_off        = (profile == 3'd0);
	assign profile_touch      = (profile == 3'd1);
	assign profile_typical    = (profile == 3'd2);
	assign profile_overdriven = (profile == 3'd3);
	assign profile_ultraviolet = (profile == 3'd5);
	assign profile_red_alert   = (profile == 3'd4);
	assign profile_custom_1   = (profile == 3'd6);
	assign profile_custom_2   = (profile == 3'd7);
	assign profile_flashing   = profile_ultraviolet || profile_red_alert;

	assign custom_bloom_width = profile_custom_2 ? status[99:97] : status[76:74];
	assign custom_halo = profile_custom_2 ? status[105:103] : status[82:80];
	assign custom_active = profile_custom_1 || profile_custom_2;
	assign custom_bloom_off = custom_active && (custom_bloom_width == 3'd0);
	assign custom_halo_off = custom_active && (custom_halo == 3'd0);

	assign off_tone_mapping = status[38:37] + 2'd3;
	assign custom_1_tone_mapping = status[73:72] + 2'd3;
	assign custom_2_tone_mapping = status[96:95] + 2'd3;
	assign custom_artwork_enable = profile_custom_2 ? status[57] : status[123];
	assign custom_artwork_blend = profile_custom_2 ? status[60:58] : status[126:124];

	assign custom_1_settings = {
		status[48:47],
		status[71:69], custom_1_tone_mapping,
		status[76:74], status[79:77], status[82:80], status[43:41],
		status[84:83],
		status[86:85], status[88:87], status[91:89]
	};

	assign custom_2_settings = {
		status[50:49],
		status[94:92], custom_2_tone_mapping,
		status[99:97], status[102:100], status[105:103], status[46:44],
		status[107:106],
		status[109:108], status[111:110], status[114:112]
	};

	localparam CONF_STR = {
		"Asteroids;;",
		"-;",
		"P3,Video Profiles & Effects;",
		"P3-;",
		"P3O[68:66],Profile,80s Cruise Control,80s Overdrive,Red Alert,Ultraviolet,Custom 1,Custom 2,Off,A Touch of CRT;",
		"h7P3O[30:28],Dot Scale,2x,2.5x,3x,4x,5x,1x,1.5x;",
		"h7P3O[38:37],Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"h7P3O[119:118],Inter-Frame Decay,Off,Short,Medium,Long;",
		"h7P3O[56:55],Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"h7P3-;",
		"h7P3-,For advanced settings and;",
		"h7P3-,artwork options select;",
		"h7P3-,Custom Profiles 1/2;",
		"h8P3-;",
		"h8P3-,Modern clarity with a touch;",
		"h8P3-,of old. Subtle halo & bloom;",
		"h8P3-,while vectors stay crisp.;",
		"h8P3-;",
		"h8P3-, For advanced settings;",
		"h8P3-, select Custom Profiles 1/2;",
		"h9P3-;",
		"h9P3-,The familiar vector CRT glow;",
		"h9P3-,richer halo, stronger bloom;",
		"h9P3-,and a restrained trail.;",
		"h9P3-;",
		"h9P3-, For advanced settings;",
		"h9P3-, select Custom Profiles 1/2;",
		"hAP3-;",
		"hAP3-,The arcade look you remember;",
		"hAP3-,hot vectors and heavy bloom;",
		"hAP3-,phosphor trails linger.;",
		"hAP3-;",
		"hAP3-, For advanced settings;",
		"hAP3-, select Custom Profiles 1/2;",
		"hAP3-;",
		"hBP3-;",
		"hBP3-,Voltage up. Rules dissolve.;",
		"hBP3-,Red or ultraviolet visions;",
		"hBP3-,glow beyond the real world.;",
		"hBP3-;",
		"hBP3-,     Epilepsy warning:;",
		"hBP3-,    excessive flashing;",
		"hBP3-,       bright lights;",
		"hBP3-;",
		"hBP3-,   Use Custom Profiles 1/2;",
		"hBP3-, to create your own effects;",
		"hDDCP3O[123],> Background,Off,On;",
		"hDDCP3O[126:124],> Background Blend,0,+1,+2,+3,-4,-3,-2,-1;",
		"hDP3O[71:69],> Dot Scale,2x,2.5x,3x,4x,5x,1x,1.5x;",
		"hDP3O[73:72],> Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"hDP3O[76:74],> Bloom Width,Off,Thin,Tight,Soft,Normal,Broad,Wide-,Wide;",
		"hDH5P3O[79:77],> Bloom Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"hDP3O[82:80],> Halo,Off,0.25x,0.33x,0.5x,0.75x,1.0x,1.25x,1.5x;",
		"hDH6P3O[43:41],> Halo Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"hDH6P3O[84:83],> Halo Spread,Original,Wide 1,Wide 2,Wide 3;",
		"hDH6P3O[48:47],> Halo Compression,Off,8,16,24;",
		"hDP3O[86:85],> Inter-Frame Decay,Off,Short,Medium,Long;",
		"hDP3O[88:87],> Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"hDP3O[91:89],> Vector Color,White,Deluxe Blue,Lunar Green,Red,Purple,Cyan,Yellow;",
		"hEDCP3O[57],> Background,Off,On;",
		"hEDCP3O[60:58],> Background Blend,0,+1,+2,+3,-4,-3,-2,-1;",
		"hEP3O[94:92],> Dot Scale,2x,2.5x,3x,4x,5x,1x,1.5x;",
		"hEP3O[96:95],> Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"hEP3O[99:97],> Bloom Width,Off,Thin,Tight,Soft,Normal,Broad,Wide-,Wide;",
		"hEH5P3O[102:100],> Bloom Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"hEP3O[105:103],> Halo,Off,0.25x,0.33x,0.5x,0.75x,1.0x,1.25x,1.5x;",
		"hEH6P3O[46:44],> Halo Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"hEH6P3O[107:106],> Halo Spread,Original,Wide 1,Wide 2,Wide 3;",
		"hEH6P3O[50:49],> Halo Compression,Off,8,16,24;",
		"hEP3O[109:108],> Inter-Frame Decay,Off,Short,Medium,Long;",
		"hEP3O[111:110],> Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"hEP3O[114:112],> Vector Color,White,Deluxe Blue,Lunar Green,Red,Purple,Cyan,Yellow;",
		"P6,Video Timing & Geometry;",
		"P6-;",
		"P6O[7:5],Orientation,Normal,Rotate 90 CW,Rotate 180,Rotate 90 CCW,Mirror Horizontal,Mirror Vertical,Mirror H + 90 CW,Mirror H + 90 CCW;",
		"P6O[3],Zoom,Normal,Wide;",
		"P6-;",
		"P6O[40:39],Buffer Mode,EOF + VBL,VBL,EOF;",
		"D3P6O[25],120Hz (720p only),Off,On;",
		"D1P6O[122],61.52Hz (Authentic),Off,On;",
		"h0P6O[115],Direct Video Scan Rate,15 kHz,31 kHz;",
		"P6-;",
		"P6-,Best left at default:;",
		"P6O[15:14],Aspect Ratio,Optimized,Stretched,Pixel Perfect;",
		"-;",
		"P2,Cabinet Audio Hardware;",
		"P2-;",
		"P2O[120],Main Board Filtering,On,Off;",
		"P2O[121],Cabinet Electronics,On,Off;",
		"-;",
		"P4,Input Controls;",
		"P4-;",
		"P4O[34],Rotation,Buttons,Spinner / Mouse;",
		"h4P4O[35],Spinner Direction,Normal,Reversed;",
		"P4-;",
		"h2P4O[33],Thrust,Button,Up / Button;",
		"H2P4O[31],Thrust Stick,Left,Right;",
		"H2P4O[32],Thrust Range,Half,Full;",
		"-;",
		"DIP;",
		"-;",
		"P5,Core Info;",
		"P5-;",
		"P5-,Atari Asteroids arcade core;",
		"P5-,     by Videodr0me 2026;",
		"P5-;",
		"P5-,If you enjoy reliving the;",
		"P5-,golden age of arcade games,;",
		"P5-,please support my work and;",
		"P5-,future updates:;",
		"P5-;",
		"P5-,buymeacoffee.com/videodr0me;",
		"hF-;",
		"hFOR,Autosave NVRAM,Off,On;",
		"hFT4,Save NVRAM;",
		"-;",
		"P1,Pause Options;",
		"P1O[116],Pause when OSD is open,Off,On;",
		"P1O[117],Dim video after 10s,On,Off;",
		"-;",
		"R[0],Reset;",
		// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (bits relocated, see RESERVED directive)
		"-;",
		"O[65:64],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
		"O[63],UserIO Players,1 Player,2 Players;",
		// [MiSTer-DB9-Pro END]
		"J1,Fire,Thrust,Hyperspace,Start 1,Start 2,Coin,Pause,Coin Right;",
		"jn,A,B,X,Start,Select,R,L,Y;",
		"I,",
		"Training Mission:\nLight Gravity\nFriction from Atmosphere\nControlled Rotation,",
		"Cadet Mission:\nModerate Gravity\nNo Friction\nControlled Rotation,",
		"Prime Mission:\nStrong Gravity\nNo Friction\nControlled Rotation,",
		"Command Mission:\nModerate Gravity\nNo Friction\nRotational Momentum;",
		"V,v1.1.", `BUILD_DATE
	};

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[65:64];   // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[63];
// SNAC cores: replace 1'b0 with the core's SNAC enable expression so SNAC
// preempts the joydb wrapper on shared USER_IO pins. Default 1'b0 is no-op.
wire         snac_active     = 1'b0;
// MT32-pi cores on primary USER_IO: replace 1'b0 with the core's MT32-active
// expression. Suppresses the OSD-open autodetect probe.
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
// Programmable-remap matrix (joydb_remap inside joydb): clk_sys carries the
// 0xFD selector load (HPS-bus domain, clk_12 here). joydb_*_mapped are the
// MiSTer-standard joystick words consumed at the USB merge point below.
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;
wire  [31:0] joystick_0_USB, joystick_1_USB;

joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_12             ),
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
assign USER_PP  = USER_PP_DRIVE;

// Gameplay merge: DB9 pad preempts the USB pad on its port; zeroed while the
// OSD is open so pad input drives menu navigation only (via joy_raw).
assign joystick_0 = joydb_1ena ? (OSD_STATUS ? 32'b0 : {16'b0, joydb_1_mapped})
                               : joystick_0_USB;
assign joystick_1 = joydb_2ena ? (OSD_STATUS ? 32'b0 : {16'b0, joydb_2_mapped})
                               : (joydb_1ena ? joystick_0_USB : joystick_1_USB);
// [MiSTer-DB9 END]

	hps_io #(.CONF_STR(CONF_STR)) hps_io_inst (
		.clk_sys(clk_12),
		.HPS_BUS(HPS_BUS),
		// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USB pads feed the joydb merge below
		.joystick_0(joystick_0_USB),
		.joystick_1(joystick_1_USB),
		.joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
		// programmable remap matrix selector load (UIO_DB9_MAP 0xFD)
		.db9_remap_cmd(db9_remap_cmd),
		.db9_remap_byte_cnt(db9_remap_byte_cnt),
		.db9_remap_din(db9_remap_din),
		// [MiSTer-DB9 END]
		// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
		.saturn_unlocked(saturn_unlocked),
		// [MiSTer-DB9-Pro END]
		.joystick_l_analog_0(analog_left),
		.joystick_r_analog_0(analog_right),
		.spinner_0(spinner_0),
		.ps2_mouse(ps2_mouse),
		.buttons(buttons),
		.forced_scandoubler(),
		.direct_video(direct_video),
		.new_vmode(video_mode_toggle),
		.gamma_bus(gamma_bus),
		.status(status),
		.info_req(info_req),
		.info(info),
		.status_menumask({
			game_is_deluxe, profile_custom_2, profile_custom_1,
			!artwork_available_ui,
			profile_flashing, profile_overdriven, profile_typical, profile_touch,
			profile_off, custom_halo_off, custom_bloom_off,
			status[34],
			!video_is_720p, !game_is_lander,
			(status[25] && video_is_720p) || game_is_lander,
			direct_video
		}),
		.ioctl_download(ioctl_download),
		.ioctl_upload(ioctl_upload),
		.ioctl_upload_req(ioctl_upload_req),
		.ioctl_upload_index(8'd4),
		.ioctl_wr(ioctl_wr),
		.ioctl_rd(),
		.ioctl_addr(ioctl_addr),
		.ioctl_dout(ioctl_dout),
		.ioctl_din(ioctl_din),
		.ioctl_index(ioctl_index),
		.ioctl_wait(artwork_ioctl_wait)
	);

	always_ff @(posedge clk_12) begin
		artwork_available_meta <= artwork_available;
		artwork_available_ui <= artwork_available_meta;
	end

	pll pll (
		.refclk(CLK_50M),
		.rst(1'b0),
		.outclk_0(clk_12),
		.outclk_1(),
		.outclk_2(clk_render),
		.locked(pll_locked)
	);

	logic [7:0] dip_switch [0:7];
	initial begin
		dip_switch[0] = 8'h84;
		dip_switch[1] = 8'h00;
		dip_switch[2] = 8'hff;
		dip_switch[3] = 8'hff;
		dip_switch[4] = 8'hff;
		dip_switch[5] = 8'hff;
		dip_switch[6] = 8'hff;
		dip_switch[7] = 8'hff;
	end

	always @(posedge clk_12) begin
		if (ioctl_wr && (ioctl_index == 16'd1))
			game_id <= ioctl_dout;

		if (ioctl_wr && (ioctl_index == 16'd254) && !ioctl_addr[26:3])
			dip_switch[ioctl_addr[2:0]] <= ioctl_dout;
	end

	assign joystick = joystick_0 | joystick_1;

	logic [23:0] paused_rgb;
	logic [7:0] raw_video_r;
	logic [7:0] raw_video_g;
	logic [7:0] raw_video_b;
	logic machine_reset;
	logic pause_cpu;
	logic rom_download;
	logic variant_download;
	logic nvram_download;
	logic nvram_host_write;
	logic [7:0] nvram_data_out;
	logic nvram_modified;
	logic nvram_dirty = 1'b0;

	assign rom_download = ioctl_download && (ioctl_index == 16'd0);
	assign variant_download = ioctl_download && (ioctl_index == 16'd1);
	assign nvram_download = ioctl_download && (ioctl_index == 16'd4);
	assign nvram_host_write = nvram_download && ioctl_wr;
	assign machine_reset = RESET || status[0] || buttons[1] ||
	                       rom_download || variant_download ||
	                       nvram_download || !pll_locked;

	always_ff @(posedge clk_12) begin
		if (!game_is_deluxe || variant_download) begin
			nvram_dirty <= 1'b0;
		end else begin
			if (nvram_download ||
			    (ioctl_upload && (ioctl_index == 16'd4)))
				nvram_dirty <= 1'b0;

			if (nvram_modified)
				nvram_dirty <= 1'b1;
		end
	end

	assign ioctl_upload_req = game_is_deluxe &&
	                          ((status[27] && nvram_dirty) || status[4]);
	assign ioctl_din = (ioctl_index == 16'd4) ? nvram_data_out : 8'h00;

	pause #(8, 8, 8, 12) pause_inst (
		.clk_sys(clk_12),
		.reset(machine_reset),
		.user_button(joystick[10]),
		.pause_request(1'b0),
		.options({~status[117], status[116]}),
		.OSD_STATUS(OSD_STATUS),
		.r(raw_video_r),
		.g(raw_video_g),
		.b(raw_video_b),
		.pause_cpu(pause_cpu),
		.rgb_out(paused_rgb)
	);

	logic signed [15:0] machine_audio;
	logic [10:0] dvg_x;
	logic [10:0] dvg_y;
	logic [7:0] dvg_z;
	logic       dvg_beam_on;
	logic       dvg_is_dot;
	logic       dvg_frame_done;
	logic [7:0] llander_thrust;
	logic       rotate_right;
	logic       rotate_left;
	logic [4:0] llander_lamps;
	logic [3:0] llander_mission_lamps_q = 4'b0000;

	llander_thrust_input thrust_input (
		.clk(clk_12),
		.reset(machine_reset),
		.analog_left_y($signed(analog_left[15:8])),
		.analog_right_y($signed(analog_right[15:8])),
		.select_right(status[31]),
		.full_range(status[32]),
		.digital_thrust(game_is_lander && joystick[4]),
		.thrust_level(llander_thrust)
	);

	asteroids_spinner_input spinner_input (
		.clk(clk_12),
		.reset(machine_reset),
		.pause(pause_cpu),
		.game_is_lander(game_is_lander),
		.spinner_mode(status[34]),
		.reverse(status[35]),
		.spinner(spinner_0),
		.mouse(ps2_mouse),
		.button_right(joystick[0]),
		.button_left(joystick[1]),
		.rotate_right(rotate_right),
		.rotate_left(rotate_left)
	);

	asteroids_core machine (
		.clk_12(clk_12),
		.reset(machine_reset),
		.pause(pause_cpu),
		.game_variant(game_id[1:0]),
		.main_board_audio_filter(!status[120]),
		.cabinet_audio_model(!status[121]),
		.coin_left(game_is_lander ? joystick[9] : 1'b0),
		.coin_center(game_is_lander ? 1'b0 : joystick[9]),
		.coin_right(joystick[11]),
		.slam(game_is_deluxe ? dip_switch[2][1] :
		      game_is_lander ? dip_switch[1][1] : 1'b0),
		.service(game_is_deluxe ? dip_switch[2][0] : dip_switch[1][0]),
		.diagnostic_step(game_is_deluxe
		                 ? 1'b0 :
		                 game_is_lander ? dip_switch[1][2] :
		                                  dip_switch[1][1]),
		.start_1(joystick[7]),
		.start_2(joystick[8]),
		.thrust(game_is_lander ? 1'b0 :
		        (joystick[5] || (status[33] && joystick[3]))),
		.thrust_level(llander_thrust),
		.abort(game_is_lander && joystick[5]),
		.rotate_right(rotate_right),
		.rotate_left(rotate_left),
		.fire(joystick[4]),
		.hyperspace(game_is_lander ? 1'b0 : joystick[6]),
		.cocktail(1'b0),
		.dsw_1(dip_switch[0]),
		.dsw_2(dip_switch[1]),
		.rom_write(ioctl_wr && rom_download),
		.rom_address(ioctl_addr[15:0]),
		.rom_data(ioctl_dout),
		.nvram_address(ioctl_addr[5:0]),
		.nvram_data_in(ioctl_dout),
		.nvram_write(nvram_host_write),
		.nvram_data_out(nvram_data_out),
		.nvram_modified(nvram_modified),
		.audio(machine_audio),
		.x_out(dvg_x),
		.y_out(dvg_y),
		.z_out(dvg_z),
		.beam_on(dvg_beam_on),
		.is_dot(dvg_is_dot),
		.frame_done(dvg_frame_done),
		.llander_lamps(llander_lamps),
		.dvg_halted()
	);

	always_ff @(posedge clk_12) begin
		info_req <= 1'b0;

		if (machine_reset || !game_is_lander) begin
			llander_mission_lamps_q <= 4'b0000;
			info <= 8'd0;
		end else begin
			llander_mission_lamps_q <= llander_lamps[3:0];

			if (llander_lamps[3:0] != llander_mission_lamps_q) begin
				case (llander_lamps[3:0])
					4'b1000: begin info <= 8'd1; info_req <= 1'b1; end
					4'b0100: begin info <= 8'd2; info_req <= 1'b1; end
					4'b0010: begin info <= 8'd3; info_req <= 1'b1; end
					4'b0001: begin info <= 8'd4; info_req <= 1'b1; end
					default: ;
				endcase
			end
		end
	end

	logic sdram_data_oe;
	logic [15:0] sdram_data_out;
	logic [1:0] sdram_dqm;
	logic video_hblank;
	logic video_vblank;
	logic fifo_full;

	assign SDRAM_CLK = ~clk_render;
	assign SDRAM_DQ = sdram_data_oe ? sdram_data_out : 16'hzzzz;
	assign SDRAM_DQML = sdram_dqm[0];
	assign SDRAM_DQMH = sdram_dqm[1];

	asteroids_video video (
		.clk_12(clk_12),
		.clk_50(CLK_50M),
		.clk_render(clk_render),
		.reset(machine_reset),
		.ddr_reset(machine_reset),
		.upload_reset(!pll_locked),
		.direct_video(direct_video),
		.direct_video_31khz(status[115]),
		.hdmi_height(HDMI_HEIGHT),
		.mode_120hz(status[25]),
		.authentic_timing(status[122] && !game_is_lander),
		.aspect_ratio(status[15:14]),
		.buffer_mode(status[40:39]),
		.geometry_orientation(status[7:5]),
		.geometry_zoom_wide(status[3]),
		.profile(profile),
		.game_is_deluxe(game_is_deluxe),
		.game_is_lander(game_is_lander),
		.artwork_enable(custom_artwork_enable),
		.artwork_blend(custom_artwork_blend),
		.ioctl_download(ioctl_download),
		.ioctl_wr(ioctl_wr),
		.ioctl_index(ioctl_index),
		.ioctl_addr(ioctl_addr),
		.ioctl_data(ioctl_dout),
		.off_dot_mode(status[30:28]),
		.off_tone_mapping(off_tone_mapping),
		.off_inter_frame_decay(status[119:118]),
		.off_intra_frame_decay(status[56:55]),
		.custom_1_settings(custom_1_settings),
		.custom_2_settings(custom_2_settings),
		.dvg_x(dvg_x),
		.dvg_y(dvg_y),
		.dvg_z(dvg_z),
		.dvg_beam_on(dvg_beam_on),
		.dvg_is_dot(dvg_is_dot),
		.frame_done(dvg_frame_done),
		.video_arx(VIDEO_ARX),
		.video_ary(VIDEO_ARY),
		.ce_pixel(CE_PIXEL),
		.hblank(video_hblank),
		.vblank(video_vblank),
		.video_r(raw_video_r),
		.video_g(raw_video_g),
		.video_b(raw_video_b),
		.hsync(VGA_HS),
		.vsync(VGA_VS),
		.mode_is_720p(video_is_720p),
		.fifo_full(fifo_full),
		.artwork_available(artwork_available),
		.ioctl_wait(artwork_ioctl_wait),
		.video_mode_toggle(video_mode_toggle),
		.video_freeze(video_freeze),
		.ddram_clk(DDRAM_CLK),
		.ddram_busy(DDRAM_BUSY),
		.ddram_burst_count(DDRAM_BURSTCNT),
		.ddram_address(DDRAM_ADDR),
		.ddram_data_out(DDRAM_DOUT),
		.ddram_data_ready(DDRAM_DOUT_READY),
		.ddram_read(DDRAM_RD),
		.ddram_data_in(DDRAM_DIN),
		.ddram_byte_enable(DDRAM_BE),
		.ddram_write(DDRAM_WE),
		.sdram_data_in(SDRAM_DQ),
		.sdram_data_out(sdram_data_out),
		.sdram_data_oe(sdram_data_oe),
		.sdram_cke(SDRAM_CKE),
		.sdram_ncs(SDRAM_nCS),
		.sdram_nras(SDRAM_nRAS),
		.sdram_ncas(SDRAM_nCAS),
		.sdram_nwe(SDRAM_nWE),
		.sdram_dqm(sdram_dqm),
		.sdram_address(SDRAM_A),
		.sdram_bank(SDRAM_BA)
	);

	assign CLK_VIDEO = clk_render;
	assign VGA_R = paused_rgb[23:16];
	assign VGA_G = paused_rgb[15:8];
	assign VGA_B = paused_rgb[7:0];
	assign VGA_DE = !(video_hblank || video_vblank);
	assign VGA_F1 = 1'b0;
	assign VGA_SL = 2'b00;
	assign VGA_SCALER = 1'b0;
	assign VGA_DISABLE = 1'b0;
	assign HDMI_FREEZE = video_freeze;
	assign HDMI_BLACKOUT = 1'b0;
	assign HDMI_BOB_DEINT = 1'b0;

	assign AUDIO_L = machine_audio;
	assign AUDIO_R = AUDIO_L;
	assign AUDIO_S = 1'b1;
	assign AUDIO_MIX = 2'b00;

	// Set to 1 only for a cabinet build that maps Lunar Lander's active-low
	// Start/Select and mission lamps onto MiSTer's LEDs.
	localparam logic ENABLE_LLANDER_MISTER_LEDS = 1'b0;
	assign LED_USER = fifo_full || ioctl_download ||
	                  (ENABLE_LLANDER_MISTER_LEDS &&
	                   game_is_lander && !llander_lamps[4]);
	assign LED_DISK = (ENABLE_LLANDER_MISTER_LEDS && game_is_lander)
	                ? {llander_lamps[2], llander_lamps[3]} : 2'b00;
	assign LED_POWER = (ENABLE_LLANDER_MISTER_LEDS && game_is_lander)
	                 ? {llander_lamps[0], llander_lamps[1]} : 2'b00;
	assign BUTTONS = 2'b00;

	assign ADC_BUS = 4'bzzzz;
	// [MiSTer-DB9 BEGIN] - USER_OUT is driven by the joydb wrapper (USER_OUT_DRIVE)
	// upstream: assign USER_OUT = 7'h7f;
	// [MiSTer-DB9 END]
	assign {UART_RTS, UART_TXD, UART_DTR} = 3'b000;
	assign {SD_SCK, SD_MOSI, SD_CS} = 3'bzzz;

`ifdef MISTER_FB
	assign FB_EN = 1'b0;
	assign FB_FORMAT = 5'd0;
	assign FB_WIDTH = 12'd0;
	assign FB_HEIGHT = 12'd0;
	assign FB_BASE = 32'd0;
	assign FB_STRIDE = 14'd0;
	assign FB_FORCE_BLANK = 1'b0;
`ifdef MISTER_FB_PALETTE
	assign FB_PAL_CLK = 1'b0;
	assign FB_PAL_ADDR = 8'd0;
	assign FB_PAL_DOUT = 24'd0;
	assign FB_PAL_WR = 1'b0;
`endif
`endif

`ifdef MISTER_DUAL_SDRAM
	assign SDRAM2_CLK = 1'bz;
	assign SDRAM2_A = 13'hzzz;
	assign SDRAM2_BA = 2'bzz;
	assign SDRAM2_DQ = 16'hzzzz;
	assign {SDRAM2_nCS, SDRAM2_nCAS, SDRAM2_nRAS, SDRAM2_nWE} = 4'hf;
`endif

endmodule
