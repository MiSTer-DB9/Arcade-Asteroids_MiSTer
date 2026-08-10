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
	logic       profile_custom_1;
	logic       profile_custom_2;
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
	logic        video_supports_120hz;
	logic        video_is_15khz;
	logic        video_is_480line;
	logic        video_field;
	logic        video_mode_restart;
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
	assign profile_custom_1   = (profile == 3'd6);
	assign profile_custom_2   = (profile == 3'd7);

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
		"H9H8H7P3O[30:28],Dot Scale,2x,2.5x,3x,4x,5x,1x,1.5x;",
		"H9H8H7P3O[38:37],Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"H9H8H7P3O[119:118],Inter-Frame Decay,Off,Short,Medium,Long;",
		"H9H8H7P3O[56:55],Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"H9H8H7P3-;",
		"H9H8H7P3-,For advanced settings and;",
		"H9H8H7P3-,artwork options select;",
		"H9H8H7P3-,Custom Profiles 1/2;",
		"H9H8h7P3-;",
		"H9H8h7P3-,Modern clarity with a touch;",
		"H9H8h7P3-,of old. Subtle halo & bloom;",
		"H9H8h7P3-,while vectors stay crisp.;",
		"H9H8h7P3-;",
		"H9H8h7P3-, For advanced settings;",
		"H9H8h7P3-, select Custom Profiles 1/2;",
		"H9h8H7P3-;",
		"H9h8H7P3-,The familiar vector CRT glow;",
		"H9h8H7P3-,richer halo, stronger bloom;",
		"H9h8H7P3-,and a restrained trail.;",
		"H9h8H7P3-;",
		"H9h8H7P3-, For advanced settings;",
		"H9h8H7P3-, select Custom Profiles 1/2;",
		"H9h8h7P3-;",
		"H9h8h7P3-,The arcade look you remember;",
		"H9h8h7P3-,hot vectors and heavy bloom;",
		"H9h8h7P3-,phosphor trails linger.;",
		"H9h8h7P3-;",
		"H9h8h7P3-, For advanced settings;",
		"H9h8h7P3-, select Custom Profiles 1/2;",
		"H9h8h7P3-;",
		"h9H8P3-;",
		"h9H8P3-,Voltage up. Rules dissolve.;",
		"h9H8P3-,Red or ultraviolet visions;",
		"h9H8P3-,glow beyond the real world.;",
		"h9H8P3-;",
		"h9H8P3-,     Epilepsy warning:;",
		"h9H8P3-,    excessive flashing;",
		"h9H8P3-,       bright lights;",
		"h9H8P3-;",
		"h9H8P3-,   Use Custom Profiles 1/2;",
		"h9H8P3-, to create your own effects;",
		"h9h8H7DAP3O[123],> Background,Off,On;",
		"h9h8H7DAP3O[126:124],> Background Blend,0,+1,+2,+3,-4,-3,-2,-1;",
		"h9h8H7P3O[71:69],> Dot Scale,2x,2.5x,3x,4x,5x,1x,1.5x;",
		"h9h8H7P3O[73:72],> Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"h9h8H7P3O[76:74],> Bloom Width,Off,Thin,Tight,Soft,Normal,Broad,Wide-,Wide;",
		"h9h8H7H5P3O[79:77],> Bloom Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"h9h8H7P3O[82:80],> Halo,Off,0.25x,0.33x,0.5x,0.75x,1.0x,1.25x,1.5x;",
		"h9h8H7H6P3O[43:41],> Halo Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"h9h8H7H6P3O[84:83],> Halo Spread,Original,Wide 1,Wide 2,Wide 3;",
		"h9h8H7H6P3O[48:47],> Halo Compression,Off,8,16,24;",
		"h9h8H7P3O[86:85],> Inter-Frame Decay,Off,Short,Medium,Long;",
		"h9h8H7P3O[88:87],> Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"h9h8H7P3O[91:89],> Vector Color,White,Deluxe Blue,Lunar Green,Red,Purple,Cyan,Yellow;",
		"h9h8h7DAP3O[57],> Background,Off,On;",
		"h9h8h7DAP3O[60:58],> Background Blend,0,+1,+2,+3,-4,-3,-2,-1;",
		"h9h8h7P3O[94:92],> Dot Scale,2x,2.5x,3x,4x,5x,1x,1.5x;",
		"h9h8h7P3O[96:95],> Tone Mapping,Off,Linear 1,Linear 2,Bright;",
		"h9h8h7P3O[99:97],> Bloom Width,Off,Thin,Tight,Soft,Normal,Broad,Wide-,Wide;",
		"h9h8h7H5P3O[102:100],> Bloom Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"h9h8h7P3O[105:103],> Halo,Off,0.25x,0.33x,0.5x,0.75x,1.0x,1.25x,1.5x;",
		"h9h8h7H6P3O[46:44],> Halo Curve,Minimal,Min+,Mild,Mild+,Moderate,Mod+,Strong-,Strong;",
		"h9h8h7H6P3O[107:106],> Halo Spread,Original,Wide 1,Wide 2,Wide 3;",
		"h9h8h7H6P3O[50:49],> Halo Compression,Off,8,16,24;",
		"h9h8h7P3O[109:108],> Inter-Frame Decay,Off,Short,Medium,Long;",
		"h9h8h7P3O[111:110],> Intra-Frame Decay,Off,LUT A,LUT B,LUT C;",
		"h9h8h7P3O[114:112],> Vector Color,White,Deluxe Blue,Lunar Green,Red,Purple,Cyan,Yellow;",
		"P6,Video Timing & Geometry;",
		"P6-;",
		"P6O[7:5],Orientation,Normal,Rotate 90 CW,Rotate 180,Rotate 90 CCW,Mirror Horizontal,Mirror Vertical,Mirror H + 90 CW,Mirror H + 90 CCW;",
		"P6O[3],Zoom,Normal,Wide;",
		"P6-;",
		"P6O[40:39],Buffer Mode,EOF + VBL,VBL,EOF;",
		"D3P6O[25],120Hz (720p only),Off,On;",
		"h2D1P6O[122],61.52Hz (Authentic),Off,On;",
		"h0P6O[115],Direct Video Scan Rate,15 kHz,31 kHz;",
		"hCP6O[127],15 kHz Format,480i,240p;",
		"hDP6O[12:10],CRT Vertical Position,0,+4,+8,+12,-4,-8,-10;",
		"hEP6O[12:10],CRT Vertical Position,0,+2,+4,+6,-2,-4,-6;",
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
		"hB-;",
		"hBOR,Autosave NVRAM,Off,On;",
		"hBT4,Save NVRAM;",
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
		"V,v1.2.", `BUILD_DATE
	};

	hps_io #(.CONF_STR(CONF_STR)) hps_io_inst (
		.clk_sys(clk_12),
		.HPS_BUS(HPS_BUS),
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
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
		// Profile bits control visibility of the custom settings.
		.status_menumask({
			1'b0, video_is_15khz && !video_is_480line,
			video_is_480line, video_is_15khz, game_is_deluxe,
			!artwork_available_ui, profile[2], profile[1], profile[0],
			custom_halo_off, custom_bloom_off,
			status[34],
			!video_supports_120hz, !game_is_lander,
			(status[25] && video_supports_120hz) || game_is_lander,
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
	logic machine_reset_base;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic [1:0] video_mode_restart_12 = 2'b00;
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
	assign machine_reset_base = RESET || status[0] || buttons[1] ||
	                            rom_download || variant_download ||
	                            nvram_download || !pll_locked;

	always_ff @(posedge clk_12)
		video_mode_restart_12 <= {video_mode_restart_12[0], video_mode_restart};

	assign machine_reset = machine_reset_base || video_mode_restart_12[1];

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
		.crt_15khz_480i(!status[127]),
		.crt_vertical_position(status[12:10]),
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
		.field(video_field),
		.mode_supports_120hz(video_supports_120hz),
		.mode_is_15khz(video_is_15khz),
		.mode_is_480line(video_is_480line),
		.fifo_full(fifo_full),
		.artwork_available(artwork_available),
		.ioctl_wait(artwork_ioctl_wait),
		.video_mode_toggle(video_mode_toggle),
		.video_freeze(video_freeze),
		.mode_restart(video_mode_restart),
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
	assign VGA_F1 = video_field;
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
