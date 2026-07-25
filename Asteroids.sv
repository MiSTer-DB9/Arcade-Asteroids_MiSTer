//============================================================================
//  Asteroids for MiSTer
//
//  Written 2026 by Videodr0me
//
//  Original arcade hardware by Atari, 1979.
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

	`include "build_id.v"

	logic [127:0] status;
	logic [31:0] joystick_0;
	logic [31:0] joystick_1;
	logic [31:0] joystick;
	logic [15:0] analog_0;
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
	logic clk_125;
	logic pll_locked;

	logic [2:0] profile;
	logic       profile_off;
	logic       profile_touch;
	logic       profile_typical;
	logic       profile_overdriven;
	logic       profile_neon;
	logic       profile_stranger;
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
	logic [22:0] custom_1_settings;
	logic [22:0] custom_2_settings;
	logic        video_is_720p;
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
	assign profile_neon       = (profile == 3'd4);
	assign profile_stranger   = (profile == 3'd5);
	assign profile_custom_1   = (profile == 3'd6);
	assign profile_custom_2   = (profile == 3'd7);
	assign profile_flashing   = profile_neon || profile_stranger;

	assign custom_bloom_width = profile_custom_2 ? status[99:97] : status[76:74];
	assign custom_halo = profile_custom_2 ? status[105:103] : status[82:80];
	assign custom_active = profile_custom_1 || profile_custom_2;
	assign custom_bloom_off = custom_active && (custom_bloom_width == 3'd0);
	assign custom_halo_off = custom_active && (custom_halo == 3'd0);

	assign off_tone_mapping = status[38:37] + 2'd3;
	assign custom_1_tone_mapping = status[73:72] + 2'd3;
	assign custom_2_tone_mapping = status[96:95] + 2'd3;

	assign custom_1_settings = {
		status[71:69], custom_1_tone_mapping,
		status[76:74], status[79:77], status[82:80], status[84:83],
		status[86:85], status[88:87], status[91:89]
	};

	assign custom_2_settings = {
		status[94:92], custom_2_tone_mapping,
		status[99:97], status[102:100], status[105:103], status[107:106],
		status[109:108], status[111:110], status[114:112]
	};

	localparam CONF_STR = {
		"Asteroids;;",
		"-;",
		"P3,Video Options;",
		"P3-;",
		"P3O[15:14],Aspect ratio,Optimized,Stretched,Pixel Perfect;",
		"D3P3O[25],120Hz (720p only),Off,On;",
		"D1P3O[122],61.52Hz (Authentic),Off,On;",
		"h0P3O[115],Direct Video Scan Rate,15 kHz,31 kHz;",
		"P3O[40:39],Buffer Mode,EOF + VBL,VBL,EOF;",
		"P3-;",
		"P3O[68:66],Profile,80s Cruise Control,80s Overdrive,Neon Fever Dream,Purple Haze,Custom 1,Custom 2,Off,A Touch of CRT;",
		"h7P3O[30:28],Dot Scale,2x,2.5x,3x,1x;",
		"h7P3O[38:37],Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"h7P3O[119:118],Inter-Frame Decay,Off,Short,Medium,Long;",
		"h7P3O[56:55],Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"h7P3-;",
		"h7P3-, For advanced settings;",
		"h7P3-, select Custom Profiles 1/2;",
		"h8P3-;",
		"h8P3-,This profile adds a subtle;",
		"h8P3-,CRT halo and bloom effect,;",
		"h8P3-,to modern AA vector drawing;",
		"h8P3-;",
		"h8P3-,   Use Custom Profiles 1/2;",
		"h8P3-, to create your own effects;",
		"h9P3-;",
		"h9P3-,Step away from the modern..;",
		"h9P3-,Richer halos and blooming;",
		"h9P3-,bring back the arcade glow.;",
		"h9P3-,Long phosphor persistence;",
		"h9P3-,adds a restrained trail.;",
		"h9P3-;",
		"h9P3-,Warning: Overdrive is next;",
		"hAP3-;",
		"hAP3-,A remote arcade in the 80s:;",
		"hAP3-,CRTs overdriven and abused;",
		"hAP3-,pulsate with vector glow.;",
		"hAP3-;",
		"hAP3-,Phosphor decay simulation;",
		"hAP3-,depends highly on your;",
		"hAP3-,monitor's panel type and;",
		"hAP3-,settings.;",
		"hAP3-;",
		"hBP3-;",
		"hBP3-,     Epilepsy warning:;",
		"hBP3-,    excessive flashing;",
		"hBP3-,       bright lights;",
		"hBP3-;",
		"hBP3-,   Use Custom Profiles 1/2;",
		"hBP3-, to create your own effects;",
		"hDP3O[71:69],> Dot Scale,2x,2.5x,3x,1x;",
		"hDP3O[73:72],> Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"hDP3O[76:74],> Bloom Width,Off,Thin,Tight,Soft,Normal,Broad,Wide-,Wide;",
		"hDD5P3O[79:77],> Bloom Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"hDP3O[82:80],> Halo,Off,0.25x,0.33x,0.5x,0.75x,1.0x,1.25x,1.5x;",
		"hDD6P3O[84:83],> Halo Spread,Original,Wide 1,Wide 2,Wide 3;",
		"hDP3O[86:85],> Inter-Frame Decay,Off,Short,Medium,Long;",
		"hDP3O[88:87],> Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"hDP3O[91:89],> Vector Color,White,Red,Lunar Green,Deluxe,Cyan,Purple,Yellow;",
		"hEP3O[94:92],> Dot Scale,2x,2.5x,3x,1x;",
		"hEP3O[96:95],> Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"hEP3O[99:97],> Bloom Width,Off,Thin,Tight,Soft,Normal,Broad,Wide-,Wide;",
		"hED5P3O[102:100],> Bloom Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"hEP3O[105:103],> Halo,Off,0.25x,0.33x,0.5x,0.75x,1.0x,1.25x,1.5x;",
		"hED6P3O[107:106],> Halo Spread,Original,Wide 1,Wide 2,Wide 3;",
		"hEP3O[109:108],> Inter-Frame Decay,Off,Short,Medium,Long;",
		"hEP3O[111:110],> Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"hEP3O[114:112],> Vector Color,White,Red,Lunar Green,Deluxe,Cyan,Purple,Yellow;",
		"P6,Video Geometry;",
		"P6-;",
		"P6O[7:5],Orientation,Normal,Rotate 90 CW,Rotate 180,Rotate 90 CCW,Mirror Horizontal,Mirror Vertical,Mirror H + 90 CW,Mirror H + 90 CCW;",
		"P6O[3],Zoom,Normal,Wide;",
		"-;",
		"P2,Cabinet Audio Hardware;",
		"P2-;",
		"P2O[120],Main Board Filtering,On,Off;",
		"P2O[121],Cabinet Electronics,On,Off;",
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
		"J1,Fire,Thrust,Hyperspace,Start 1,Start 2,Coin,Pause,Coin Right;",
		"jn,A,B,X,Start,Select,R,L,Y;",
		"I,",
		"Training Mission:\nLight Gravity\nFriction from Atmosphere\nControlled Rotation,",
		"Cadet Mission:\nModerate Gravity\nNo Friction\nControlled Rotation,",
		"Prime Mission:\nStrong Gravity\nNo Friction\nControlled Rotation,",
		"Command Mission:\nModerate Gravity\nNo Friction\nRotational Momentum;",
		"V,v1.0.", `BUILD_DATE
	};

	hps_io #(.CONF_STR(CONF_STR)) hps_io_inst (
		.clk_sys(clk_12),
		.HPS_BUS(HPS_BUS),
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
		.joystick_l_analog_0(analog_0),
		.buttons(buttons),
		.forced_scandoubler(),
		.direct_video(direct_video),
		.gamma_bus(gamma_bus),
		.status(status),
		.info_req(info_req),
		.info(info),
		.status_menumask({
			game_is_deluxe, profile_custom_2, profile_custom_1, 1'b0,
			profile_flashing, profile_overdriven, profile_typical, profile_touch,
			profile_off, custom_halo_off, custom_bloom_off, 1'b0,
			!video_is_720p, 1'b0,
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
		.ioctl_index(ioctl_index)
	);

	pll pll (
		.refclk(CLK_50M),
		.rst(1'b0),
		.outclk_0(),
		.outclk_1(clk_12),
		.outclk_2(),
		.outclk_3(clk_125),
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
	logic [4:0] llander_lamps;
	logic [3:0] llander_mission_lamps_q = 4'b0000;

	llander_thrust_input thrust_input (
		.clk(clk_12),
		.reset(machine_reset),
		.analog_y($signed(analog_0[15:8])),
		.digital_thrust(game_is_lander && joystick[4]),
		.thrust_level(llander_thrust)
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
		.thrust(game_is_lander ? 1'b0 : joystick[5]),
		.thrust_level(llander_thrust),
		.abort(game_is_lander && joystick[5]),
		.rotate_right(joystick[0]),
		.rotate_left(joystick[1]),
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

	assign SDRAM_CLK = ~clk_125;
	assign SDRAM_DQ = sdram_data_oe ? sdram_data_out : 16'hzzzz;
	assign SDRAM_DQML = sdram_dqm[0];
	assign SDRAM_DQMH = sdram_dqm[1];

	asteroids_video video (
		.clk_12(clk_12),
		.clk_50(CLK_50M),
		.clk_125(clk_125),
		.reset(machine_reset),
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

	assign CLK_VIDEO = clk_125;
	assign VGA_R = paused_rgb[23:16];
	assign VGA_G = paused_rgb[15:8];
	assign VGA_B = paused_rgb[7:0];
	assign VGA_DE = !(video_hblank || video_vblank);
	assign VGA_F1 = 1'b0;
	assign VGA_SL = 2'b00;
	assign VGA_SCALER = 1'b0;
	assign VGA_DISABLE = 1'b0;
	assign HDMI_FREEZE = 1'b0;
	assign HDMI_BLACKOUT = 1'b0;
	assign HDMI_BOB_DEINT = 1'b0;

	assign AUDIO_L = machine_audio;
	assign AUDIO_R = AUDIO_L;
	assign AUDIO_S = 1'b1;
	assign AUDIO_MIX = 2'b00;

	// Lunar Lander exposes Start/Select, Training, Cadet, Prime, and Command
	// lamps in bits 4..0. Set this parameter to route them across MiSTer's
	// USER, DISK, and POWER indicators for a cabinet-specific build.
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
	assign USER_OUT = 7'h7f;
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
