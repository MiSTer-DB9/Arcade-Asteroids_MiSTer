//============================================================================
//  Asteroids vector video presentation
//
//  Written 2026 by Videodr0me
//
//  Maps DVG coordinates into the selected raster mode and connects
//  the vector stream to the sparse framebuffer and CRT effect pipeline.
//============================================================================

module asteroids_video
#(
	parameter logic [24:0] MODE_STABLE_CYCLES = 25'd25_000_000
)
(
	input  logic        clk_12,
	input  logic        clk_50,
	input  logic        clk_render,
	input  logic        reset,
	input  logic        ddr_reset,
	input  logic        upload_reset,

	input  logic        direct_video,
	input  logic        direct_video_31khz,
	input  logic [11:0] hdmi_height,
	input  logic        mode_120hz,
	input  logic        authentic_timing,
	input  logic        crt_15khz_480i,
	input  logic  [2:0] crt_vertical_position,
	input  logic  [1:0] aspect_ratio,
	input  logic  [1:0] buffer_mode,
	input  logic  [2:0] geometry_orientation,
	input  logic        geometry_zoom_wide,

	input  logic  [2:0] profile,
	input  logic        game_is_deluxe,
	input  logic        game_is_lander,
	input  logic        artwork_enable,
	input  logic  [2:0] artwork_blend,
	input  logic        ioctl_download,
	input  logic        ioctl_wr,
	input  logic [15:0] ioctl_index,
	input  logic [26:0] ioctl_addr,
	input  logic  [7:0] ioctl_data,
	input  logic  [2:0] off_dot_mode,
	input  logic  [1:0] off_tone_mapping,
	input  logic  [1:0] off_inter_frame_decay,
	input  logic  [1:0] off_intra_frame_decay,
	input  logic [27:0] custom_1_settings,
	input  logic [27:0] custom_2_settings,

	input  logic [10:0] dvg_x,
	input  logic [10:0] dvg_y,
	input  logic  [7:0] dvg_z,
	input  logic        dvg_beam_on,
	input  logic        dvg_is_dot,
	input  logic        frame_done,

	output logic [12:0] video_arx,
	output logic [12:0] video_ary,
	output logic        ce_pixel,
	output logic        hblank,
	output logic        vblank,
	output logic  [7:0] video_r,
	output logic  [7:0] video_g,
	output logic  [7:0] video_b,
	output logic        hsync,
	output logic        vsync,
	output logic        field,
	output logic        mode_supports_120hz,
	output logic        mode_is_15khz,
	output logic        mode_is_480line,
	output logic        fifo_full,
	output logic        artwork_available,
	output logic        ioctl_wait,
	output logic        video_mode_toggle,
	output logic        video_freeze,
	output logic        mode_restart,

	output logic        ddram_clk,
	input  logic        ddram_busy,
	output logic  [7:0] ddram_burst_count,
	output logic [28:0] ddram_address,
	input  logic [63:0] ddram_data_out,
	input  logic        ddram_data_ready,
	output logic        ddram_read,
	output logic [63:0] ddram_data_in,
	output logic  [7:0] ddram_byte_enable,
	output logic        ddram_write,

	input  logic [15:0] sdram_data_in,
	output logic [15:0] sdram_data_out,
	output logic        sdram_data_oe,
	output logic        sdram_cke,
	output logic        sdram_ncs,
	output logic        sdram_nras,
	output logic        sdram_ncas,
	output logic        sdram_nwe,
	output logic  [1:0] sdram_dqm,
	output logic [12:0] sdram_address,
	output logic  [1:0] sdram_bank
);

	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic direct_video_meta = 1'b0, direct_video_sync = 1'b0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic direct_31khz_meta = 1'b0, direct_31khz_sync = 1'b0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic [11:0] requested_height_meta = 12'd0, requested_height_sync = 12'd0;
	logic [11:0] height_candidate = 12'd0;
	logic [11:0] stable_height = 12'd0;
	logic [24:0] height_timer = 25'd0;

	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic mode_120hz_meta = 1'b0, mode_120hz_sync = 1'b0;
	logic stable_120hz = 1'b0;
	logic [24:0] rate_timer = 25'd0;

	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic authentic_timing_meta = 1'b0, authentic_timing_sync = 1'b0;
	logic stable_authentic_timing = 1'b0;
	logic [24:0] timing_timer = 25'd0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic format_480i_meta = 1'b0, format_480i_sync = 1'b0;
	logic format_480i_stable = 1'b0;
	logic [24:0] format_timer = 25'd0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic [2:0] crt_position_meta = 3'd0, crt_position_sync = 3'd0;
	logic [2:0] stable_crt_position = 3'd0;
	logic [24:0] position_timer = 25'd0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic upload_reset_50_meta = 1'b1, upload_reset_50 = 1'b1;
	logic startup_ready_50 = 1'b0;
	logic [24:0] startup_timer = 25'd0;

	always_ff @(posedge clk_50) begin
		upload_reset_50_meta <= upload_reset;
		upload_reset_50 <= upload_reset_50_meta;

		direct_video_meta <= direct_video;
		direct_video_sync <= direct_video_meta;
		direct_31khz_meta <= direct_video_31khz;
		direct_31khz_sync <= direct_31khz_meta;

		// Direct Video selects its scan-rate bracket;
		// scaled output follows HDMI_HEIGHT.
		requested_height_meta <= direct_video_sync ?
			(direct_31khz_sync ? 12'd480 : 12'd240) : hdmi_height;
		requested_height_sync <= requested_height_meta;

		mode_120hz_meta <= mode_120hz;
		mode_120hz_sync <= mode_120hz_meta;
		authentic_timing_meta <= authentic_timing;
		authentic_timing_sync <= authentic_timing_meta;
		format_480i_meta <= crt_15khz_480i;
		format_480i_sync <= format_480i_meta;
		crt_position_meta <= crt_vertical_position;
		crt_position_sync <= crt_position_meta;

		if (upload_reset_50) begin
			height_candidate <= 12'd0;
			stable_height <= 12'd0;
			height_timer <= 25'd0;
			stable_120hz <= 1'b0;
			rate_timer <= 25'd0;
			stable_authentic_timing <= 1'b0;
			timing_timer <= 25'd0;
			format_480i_stable <= 1'b0;
			format_timer <= 25'd0;
			stable_crt_position <= 3'd0;
			position_timer <= 25'd0;
			startup_ready_50 <= 1'b0;
			startup_timer <= 25'd0;
		end else begin
			if ((stable_height == 12'd0) || direct_video_sync) begin
				if ((requested_height_meta == requested_height_sync) &&
				    (requested_height_sync > 12'd200)) begin
					if (requested_height_sync != height_candidate) begin
						height_candidate <= requested_height_sync;
						height_timer <= 25'd0;
					end else if ((requested_height_sync != stable_height) &&
					             (height_timer < MODE_STABLE_CYCLES - 1'd1)) begin
						height_timer <= height_timer + 1'd1;
					end else if (requested_height_sync != stable_height) begin
						stable_height <= height_candidate;
						height_timer <= 25'd0;
					end else begin
						height_timer <= 25'd0;
					end
				end else begin
					height_candidate <= requested_height_sync;
					height_timer <= 25'd0;
				end
			end else begin
				height_candidate <= stable_height;
				height_timer <= 25'd0;
			end

			if (mode_120hz_meta != mode_120hz_sync) begin
				rate_timer <= 25'd0;
			end else if (mode_120hz_sync != stable_120hz) begin
				if (rate_timer < MODE_STABLE_CYCLES - 1'd1)
					rate_timer <= rate_timer + 1'd1;
				else begin
					stable_120hz <= mode_120hz_sync;
					rate_timer <= 25'd0;
				end
			end else begin
				rate_timer <= 25'd0;
			end

			if (authentic_timing_meta != authentic_timing_sync) begin
				timing_timer <= 25'd0;
			end else if (authentic_timing_sync != stable_authentic_timing) begin
				if (timing_timer < MODE_STABLE_CYCLES - 1'd1)
					timing_timer <= timing_timer + 1'd1;
				else begin
					stable_authentic_timing <= authentic_timing_sync;
					timing_timer <= 25'd0;
				end
			end else begin
				timing_timer <= 25'd0;
			end

			if (format_480i_meta != format_480i_sync) begin
				format_timer <= 25'd0;
			end else if (format_480i_sync != format_480i_stable) begin
				if (format_timer < MODE_STABLE_CYCLES - 1'd1)
					format_timer <= format_timer + 1'd1;
				else begin
					format_480i_stable <= format_480i_sync;
					format_timer <= 25'd0;
				end
			end else begin
				format_timer <= 25'd0;
			end

			if (crt_position_meta != crt_position_sync) begin
				position_timer <= 25'd0;
			end else if (crt_position_sync != stable_crt_position) begin
				if (position_timer < MODE_STABLE_CYCLES - 1'd1)
					position_timer <= position_timer + 1'd1;
				else begin
					stable_crt_position <= crt_position_sync;
					position_timer <= 25'd0;
				end
			end else begin
				position_timer <= 25'd0;
			end

			if (!startup_ready_50) begin
				if ((stable_height != 12'd0) &&
				    (mode_120hz_meta == mode_120hz_sync) &&
				    (mode_120hz_sync == stable_120hz) &&
				    (rate_timer == 25'd0) &&
				    (authentic_timing_meta == authentic_timing_sync) &&
				    (authentic_timing_sync == stable_authentic_timing) &&
				    (timing_timer == 25'd0) &&
				    (format_480i_meta == format_480i_sync) &&
				    (format_480i_sync == format_480i_stable) &&
				    (format_timer == 25'd0) &&
				    (crt_position_meta == crt_position_sync) &&
				    (crt_position_sync == stable_crt_position) &&
				    (position_timer == 25'd0)) begin
					if (startup_timer < MODE_STABLE_CYCLES - 1'd1)
						startup_timer <= startup_timer + 1'd1;
					else begin
						startup_ready_50 <= 1'b1;
						startup_timer <= 25'd0;
					end
				end else begin
					startup_timer <= 25'd0;
				end
			end
		end
	end

	logic [2:0] effective_dot_mode;
	logic [1:0] effective_tone_mapping;
	logic [2:0] effective_bloom_width;
	logic [2:0] effective_bloom_curve;
	logic [2:0] effective_halo_filter;
	logic [2:0] effective_halo_curve;
	logic [1:0] effective_halo_spread;
	logic [1:0] effective_halo_knee;
	logic [1:0] effective_inter_frame_decay;
	logic [1:0] effective_intra_frame_decay;
	logic [2:0] effective_presentation_color;
	logic       effective_full_bypass;
	logic       effective_artwork_enable;
	logic [2:0] effective_artwork_blend;

	function automatic logic signed [4:0] decode_crt_vertical_position(
		input logic [2:0] selection
	);
		begin
			case (selection)
				3'd1: decode_crt_vertical_position = 5'sd4;
				3'd2: decode_crt_vertical_position = 5'sd8;
				3'd3: decode_crt_vertical_position = 5'sd12;
				3'd4: decode_crt_vertical_position = -5'sd4;
				3'd5: decode_crt_vertical_position = -5'sd8;
				3'd6: decode_crt_vertical_position = -5'sd10;
				default: decode_crt_vertical_position = 5'sd0;
			endcase
		end
	endfunction

	function automatic logic signed [4:0] decode_crt_vertical_position_240p(
		input logic [2:0] selection
	);
		begin
			case (selection)
				3'd1: decode_crt_vertical_position_240p = 5'sd2;
				3'd2: decode_crt_vertical_position_240p = 5'sd4;
				3'd3: decode_crt_vertical_position_240p = 5'sd6;
				3'd4: decode_crt_vertical_position_240p = -5'sd2;
				3'd5: decode_crt_vertical_position_240p = -5'sd4;
				3'd6: decode_crt_vertical_position_240p = -5'sd6;
				default: decode_crt_vertical_position_240p = 5'sd0;
			endcase
		end
	endfunction

	typedef struct packed {
		logic [11:0] fb_width;
		logic [11:0] fb_height;
		logic [11:0] x_center;
		logic [11:0] y_center;
		logic [12:0] optimized_arx;
		logic [12:0] optimized_ary;
		// Inclusive terminal values; total samples equal last + 1.
		logic [11:0] h_total;
		logic [11:0] v_total;
		logic [11:0] hs_start;
		logic [11:0] hs_end;
		logic [11:0] vs_start;
		logic [11:0] vs_end;
		logic        is_1080p;
		logic        is_480p;
		logic        is_240p;
		logic        is_120hz;
		logic        is_authentic;
		logic        is_interlaced;
		logic signed [4:0] crt_vertical_offset;
	} video_mode_t;

	function automatic video_mode_t decode_video_mode(
		input logic [11:0] height,
		input logic        mode_120hz,
		input logic        authentic,
		input logic        interlaced,
		input logic  [2:0] crt_position
	);
		video_mode_t mode;
		logic signed [4:0] vertical_offset;
		logic signed [12:0] shifted_vs_start;
		logic signed [12:0] shifted_vs_end;
		begin
			mode = '0;
			vertical_offset = (height < 12'd480) ?
				decode_crt_vertical_position_240p(crt_position) :
				decode_crt_vertical_position(crt_position);
			mode.is_authentic = authentic;
			if ((height >= 12'd1080) && (height < 12'd1400)) begin
				mode.fb_width = 12'd1360;
				mode.fb_height = 12'd1080;
				mode.x_center = 12'd680;
				mode.y_center = 12'd540;
				mode.optimized_arx = 13'h1000 | 13'd1360;
				mode.optimized_ary = 13'h1000 | 13'd1080;
				mode.h_total = authentic ? 12'd1846 : 12'd1903;
				mode.v_total = authentic ? 12'd1130 : 12'd1124;
				mode.hs_start = 12'd1600;
				mode.hs_end = 12'd1688;
				mode.vs_start = 12'd1088;
				mode.vs_end = 12'd1093;
				mode.is_1080p = 1'b1;
			end else if (height < 12'd480) begin
				mode.fb_width = 12'd720;
				mode.fb_height = 12'd240;
				mode.x_center = 12'd360;
				mode.y_center = 12'd120;
				mode.optimized_arx = 13'h1000 | 13'd720;
				mode.optimized_ary = 13'h1000 | 13'd240;
				mode.h_total = authentic ? 12'd873 : 12'd883;
				mode.v_total = authentic ? 12'd259 : 12'd263;
				mode.hs_start = authentic ? 12'd740 : 12'd755;
				mode.hs_end = authentic ? 12'd806 : 12'd821;
				shifted_vs_start = 13'sd246 - vertical_offset;
				shifted_vs_end = 13'sd249 - vertical_offset;
				mode.vs_start = shifted_vs_start[11:0];
				mode.vs_end = shifted_vs_end[11:0];
				mode.is_240p = 1'b1;
				mode.crt_vertical_offset = vertical_offset;
			end else if (height < 12'd720) begin
				mode.fb_width = 12'd720;
				mode.fb_height = 12'd480;
				mode.x_center = 12'd360;
				mode.y_center = 12'd240;
				mode.optimized_arx = 13'h1000 | 13'd720;
				mode.optimized_ary = 13'h1000 | 13'd480;
				mode.h_total = authentic ? 12'd873 : 12'd883;
				mode.v_total = authentic ?
				               (interlaced ? 12'd520 : 12'd519) :
				               12'd528;
				mode.hs_start = authentic ? 12'd740 : 12'd755;
				mode.hs_end = authentic ? 12'd806 : 12'd821;
				shifted_vs_start = 13'sd493 - vertical_offset;
				shifted_vs_end = 13'sd499 - vertical_offset;
				mode.vs_start = shifted_vs_start[11:0];
				mode.vs_end = shifted_vs_end[11:0];
				mode.is_480p = 1'b1;
				mode.is_interlaced = interlaced;
				mode.crt_vertical_offset = vertical_offset;
			end else begin
				mode.fb_width = 12'd916;
				mode.fb_height = 12'd720;
				mode.x_center = 12'd458;
				mode.y_center = 12'd360;
				mode.optimized_arx = (height >= 12'd1440) ?
				                     (13'h1000 | 13'd1832) :
				                     (13'h1000 | 13'd916);
				mode.optimized_ary = (height >= 12'd1440) ?
				                     (13'h1000 | 13'd1440) :
				                     (13'h1000 | 13'd720);
				mode.h_total = (mode_120hz || !authentic) ?
				               12'd1427 : 12'd1359;
				mode.v_total = (mode_120hz || !authentic) ?
				               12'd749 : 12'd767;
				mode.hs_start = 12'd1108;
				mode.hs_end = 12'd1196;
				mode.vs_start = 12'd728;
				mode.vs_end = 12'd733;
				mode.is_120hz = mode_120hz;
			end
			decode_video_mode = mode;
		end
	endfunction

	video_mode_t mode_q = decode_video_mode(
		12'd480, 1'b0, 1'b0, 1'b0, 3'd0);

	wire [11:0] fb_width = mode_q.fb_width;
	wire [11:0] fb_height = mode_q.fb_height;
	wire [11:0] x_center = mode_q.x_center;
	wire [11:0] y_center = mode_q.y_center;
	wire [12:0] optimized_arx = mode_q.optimized_arx;
	wire [12:0] optimized_ary = mode_q.optimized_ary;
	wire [11:0] h_total = mode_q.h_total;
	wire [11:0] v_total = mode_q.v_total;
	wire [11:0] hs_start = mode_q.hs_start;
	wire [11:0] hs_end = mode_q.hs_end;
	wire [11:0] vs_start = mode_q.vs_start;
	wire [11:0] vs_end = mode_q.vs_end;
	wire        is_1080p = mode_q.is_1080p;
	wire        is_480p = mode_q.is_480p;
	wire        is_240p = mode_q.is_240p;
	wire        is_120hz = mode_q.is_120hz;
	wire        is_authentic = mode_q.is_authentic;
	wire        is_interlaced = mode_q.is_interlaced;
	wire signed [4:0] crt_vertical_offset = mode_q.crt_vertical_offset;

	vfb_profile_resolver profile_resolver (
		.profile(profile),
		.fb_height(fb_height),
		.game_is_deluxe(game_is_deluxe),
		.game_is_lander(game_is_lander),
		.off_dot_mode(off_dot_mode),
		.off_tonemapping(off_tone_mapping),
		.off_inter_frame_decay(off_inter_frame_decay),
		.off_intra_frame_decay(off_intra_frame_decay),
		.custom1_settings(custom_1_settings),
		.custom2_settings(custom_2_settings),
		.custom_artwork_enable(artwork_enable),
		.custom_artwork_blend(artwork_blend),
		.dot_mode(effective_dot_mode),
		.tonemapping(effective_tone_mapping),
		.bloom_width(effective_bloom_width),
		.bloom_curve(effective_bloom_curve),
		.halo_filter(effective_halo_filter),
		.halo_curve(effective_halo_curve),
		.halo_spread(effective_halo_spread),
		.halo_knee(effective_halo_knee),
		.inter_frame_decay(effective_inter_frame_decay),
		.intra_frame_decay(effective_intra_frame_decay),
		.presentation_color(effective_presentation_color),
		.full_bypass(effective_full_bypass),
		.artwork_enable(effective_artwork_enable),
		.artwork_blend(effective_artwork_blend)
	);

	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic [11:0] height_meta = 12'd0, height_sync = 12'd0;
	logic [11:0] height_sync_d = 12'd0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic        rate_meta = 1'b0, rate_sync = 1'b0;
	logic        rate_sync_d = 1'b0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic        timing_meta = 1'b0, timing_sync = 1'b0;
	logic        timing_sync_d = 1'b0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic        format_480i_stable_meta = 1'b0,
	             format_480i_stable_sync = 1'b0;
	logic        format_480i_stable_d = 1'b0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic  [2:0] position_meta = 3'd0, position_sync = 3'd0;
	logic  [2:0] position_sync_d = 3'd0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic        bypass_meta = 1'b1, bypass_sync = 1'b1;
	logic        bypass_sync_d = 1'b1;
	logic        bypass_stable = 1'b1;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic        startup_ready_meta = 1'b0, startup_ready_sync = 1'b0;
	logic        startup_ready_sync_d = 1'b0;
	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic        upload_reset_render_meta = 1'b1, upload_reset_render = 1'b1;

	always_ff @(posedge clk_render) begin
		height_meta <= stable_height;
		height_sync <= height_meta;
		height_sync_d <= height_sync;
		rate_meta <= stable_120hz;
		rate_sync <= rate_meta;
		rate_sync_d <= rate_sync;
		timing_meta <= stable_authentic_timing;
		timing_sync <= timing_meta;
		timing_sync_d <= timing_sync;
		format_480i_stable_meta <= format_480i_stable;
		format_480i_stable_sync <= format_480i_stable_meta;
		format_480i_stable_d <= format_480i_stable_sync;
		position_meta <= stable_crt_position;
		position_sync <= position_meta;
		position_sync_d <= position_sync;
		bypass_meta <= effective_full_bypass;
		bypass_sync <= bypass_meta;
		bypass_sync_d <= bypass_sync;
		if (bypass_sync == bypass_sync_d)
			bypass_stable <= bypass_sync;
		startup_ready_meta <= startup_ready_50;
		startup_ready_sync <= startup_ready_meta;
		startup_ready_sync_d <= startup_ready_sync;
		upload_reset_render_meta <= upload_reset;
		upload_reset_render <= upload_reset_render_meta;
	end

	video_mode_t requested_mode = decode_video_mode(
		12'd480, 1'b0, 1'b0, 1'b0, 3'd0);
	video_mode_t pending_mode_q = decode_video_mode(
		12'd480, 1'b0, 1'b0, 1'b0, 3'd0);
	typedef struct packed {
		logic [2:0] crt_position;
		logic       mode_120hz;
		logic       authentic;
		logic       is_15khz;
		logic       interlaced;
	} video_key_t;
	logic        request_valid = 1'b0;
	logic        request_bypass = 1'b1;
	video_key_t  request_key = '0, key_active_q = '0, key_pending_q = '0;

	wire height_supports_120hz = (height_sync_d >= 12'd720) &&
	                              (height_sync_d <= 12'd768);
	wire request_120hz = rate_sync_d && height_supports_120hz;
	wire request_authentic = timing_sync_d && !request_120hz;
	wire request_15khz = height_sync_d < 12'd480;
	wire request_480i = format_480i_stable_d && request_15khz;
	wire [11:0] request_height = request_480i ?
		12'd480 : height_sync_d;
	wire [2:0] request_crt_position = (request_height < 12'd720) ?
		position_sync_d : 3'd0;
	wire request_inputs_stable = startup_ready_sync_d &&
		(startup_ready_sync == startup_ready_sync_d) &&
		(height_sync_d != 12'd0) &&
		(height_sync == height_sync_d) &&
		(rate_sync == rate_sync_d) &&
		(timing_sync == timing_sync_d) &&
		(format_480i_stable_sync == format_480i_stable_d) &&
		(position_sync == position_sync_d) &&
		(bypass_sync == bypass_sync_d) &&
		(bypass_stable == bypass_sync_d);

	always_ff @(posedge clk_render) begin
		if (upload_reset_render) begin
			requested_mode <= decode_video_mode(
				12'd480, 1'b0, 1'b0, 1'b0, 3'd0);
			request_valid <= 1'b0;
			request_bypass <= 1'b1;
			request_key <= '0;
		end else begin
			requested_mode <= decode_video_mode(request_height,
			                                    request_120hz,
			                                    request_authentic,
			                                    request_480i,
			                                    request_crt_position);
			request_valid <= request_inputs_stable;
			request_bypass <= bypass_stable;
			request_key.crt_position <= request_crt_position;
			request_key.mode_120hz   <= request_120hz;
			request_key.authentic    <= request_authentic;
			request_key.is_15khz     <= request_15khz;
			request_key.interlaced   <= request_480i;
		end
	end

	typedef enum logic [2:0] {
		MODE_WAIT_START,
		MODE_START_TIMING,
		MODE_START_HOLD,
		MODE_RUN,
		MODE_WAIT_ACTIVE_VBLANK,
		MODE_WAIT_TIMING_WRAP,
		MODE_WAIT_TARGET_VBLANK,
		MODE_HOLD_TARGET_FRAME
	} mode_state_t;

	mode_state_t mode_state = MODE_WAIT_START;
	logic mode_ready = 1'b0;
	logic video_mode_toggle_q = 1'b0;
	logic video_freeze_q = 1'b1;
	logic active_bypass_q = 1'b1;
	logic pending_bypass_q = 1'b1;
	logic processed_path_prepare_q = 1'b0;
	logic transition_timing_q = 1'b0;
	logic transition_restart_q = 1'b0;
	logic mode_restart_q = 1'b0;
	logic raw_path_vblank;
	logic processed_path_vblank;
	logic raw_path_vblank_q = 1'b1;
	logic processed_path_vblank_q = 1'b1;
	logic output_vblank_q = 1'b1;
	logic output_vblank_entry_q = 1'b0;
	logic frame_wrap;
	logic mode_commit;
	wire raw_path_vblank_entry = raw_path_vblank && !raw_path_vblank_q;
	wire processed_path_vblank_entry =
		processed_path_vblank && !processed_path_vblank_q;
	wire progressive_active_vblank_entry = active_bypass_q ?
		raw_path_vblank_entry : processed_path_vblank_entry;
	wire progressive_target_vblank_entry = pending_bypass_q ?
		raw_path_vblank_entry : processed_path_vblank_entry;
	wire active_path_vblank_entry = key_active_q.interlaced ?
		output_vblank_entry_q : progressive_active_vblank_entry;
	wire target_path_vblank_entry = key_pending_q.interlaced ?
		output_vblank_entry_q : progressive_target_vblank_entry;
	wire request_changed = (request_key != key_active_q) ||
	                       (request_bypass != active_bypass_q);
	wire profile_path_commit =
		(mode_state == MODE_WAIT_TARGET_VBLANK) &&
		!transition_restart_q &&
		target_path_vblank_entry &&
		(pending_bypass_q != active_bypass_q);

	assign video_mode_toggle = video_mode_toggle_q;
	assign video_freeze = video_freeze_q;
	assign mode_restart = mode_restart_q;

	always_ff @(posedge clk_render) begin
		if (upload_reset_render) begin
			raw_path_vblank_q <= 1'b1;
			processed_path_vblank_q <= 1'b1;
			output_vblank_q <= 1'b1;
			output_vblank_entry_q <= 1'b0;
		end else begin
			raw_path_vblank_q <= raw_path_vblank;
			processed_path_vblank_q <= processed_path_vblank;
			output_vblank_entry_q <=
				ce_pixel && vblank && !output_vblank_q;
			if (ce_pixel)
				output_vblank_q <= vblank;
		end
	end

	always_ff @(posedge clk_render) begin
		if (upload_reset_render) begin
			mode_q <= decode_video_mode(
				12'd480, 1'b0, 1'b0, 1'b0, 3'd0);
			pending_mode_q <= decode_video_mode(
				12'd480, 1'b0, 1'b0, 1'b0, 3'd0);
			key_active_q <= '0;
			key_pending_q <= '0;
			active_bypass_q <= 1'b1;
			pending_bypass_q <= 1'b1;
			processed_path_prepare_q <= 1'b0;
			transition_timing_q <= 1'b0;
			transition_restart_q <= 1'b0;
			mode_restart_q <= 1'b0;
			mode_state <= MODE_WAIT_START;
			mode_ready <= 1'b0;
			video_freeze_q <= 1'b1;
		end else begin
			case (mode_state)
				MODE_WAIT_START: begin
					mode_ready <= 1'b0;
					video_freeze_q <= 1'b1;
					mode_restart_q <= 1'b0;
					if (request_valid) begin
						mode_q <= requested_mode;
						pending_mode_q <= requested_mode;
						key_active_q <= request_key;
						key_pending_q <= request_key;
						active_bypass_q <= request_bypass;
						pending_bypass_q <= request_bypass;
						processed_path_prepare_q <= !request_bypass;
						mode_state <= MODE_START_TIMING;
					end
				end

				MODE_START_TIMING: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b1;
					mode_state <= MODE_START_HOLD;
				end

				MODE_START_HOLD: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b1;
					if (frame_wrap) begin
						video_freeze_q <= 1'b0;
						mode_state <= MODE_RUN;
					end
				end

				MODE_RUN: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b0;
					mode_restart_q <= 1'b0;
					transition_restart_q <= 1'b0;
					if (request_valid && request_changed) begin
						pending_mode_q <= requested_mode;
						key_pending_q <= request_key;
						pending_bypass_q <= request_bypass;
						if (!request_bypass)
							processed_path_prepare_q <= 1'b1;
						mode_state <= MODE_WAIT_ACTIVE_VBLANK;
					end
				end

				MODE_WAIT_ACTIVE_VBLANK: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b0;
					if (request_valid && !request_changed) begin
						processed_path_prepare_q <= !active_bypass_q;
						mode_state <= MODE_RUN;
					end else if (request_valid) begin
						pending_mode_q <= requested_mode;
						key_pending_q <= request_key;
						pending_bypass_q <= request_bypass;
						if (!request_bypass)
							processed_path_prepare_q <= 1'b1;
						if (active_path_vblank_entry) begin
							transition_timing_q <=
								(request_key != key_active_q);
							transition_restart_q <=
								(requested_mode.fb_width != mode_q.fb_width) ||
								(requested_mode.fb_height != mode_q.fb_height) ||
								(requested_mode.is_interlaced != mode_q.is_interlaced);
							video_freeze_q <= 1'b1;
							mode_state <= (request_key != key_active_q) ?
								MODE_WAIT_TIMING_WRAP : MODE_WAIT_TARGET_VBLANK;
						end
					end
				end

				MODE_WAIT_TIMING_WRAP: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b1;
					if (frame_wrap) begin
						mode_q <= pending_mode_q;
						key_active_q <= key_pending_q;
						video_mode_toggle_q <= !video_mode_toggle_q;
						mode_restart_q <= transition_restart_q;
						mode_state <= MODE_WAIT_TARGET_VBLANK;
					end
				end

				MODE_WAIT_TARGET_VBLANK: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b1;
					if (transition_restart_q && frame_wrap) begin
						mode_restart_q <= 1'b0;
						key_active_q <= key_pending_q;
						active_bypass_q <= pending_bypass_q;
						processed_path_prepare_q <= !pending_bypass_q;
						mode_state <= MODE_HOLD_TARGET_FRAME;
					end else if (!transition_restart_q && target_path_vblank_entry) begin
						key_active_q <= key_pending_q;
						active_bypass_q <= pending_bypass_q;
						processed_path_prepare_q <= !pending_bypass_q;
						if (!transition_timing_q)
							video_mode_toggle_q <= !video_mode_toggle_q;
						mode_state <= MODE_HOLD_TARGET_FRAME;
					end
				end

				MODE_HOLD_TARGET_FRAME: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b1;
					if (transition_restart_q && frame_wrap) begin
						transition_restart_q <= 1'b0;
						video_freeze_q <= 1'b0;
						mode_state <= MODE_RUN;
					end else if (!transition_restart_q && target_path_vblank_entry) begin
						video_freeze_q <= 1'b0;
						mode_state <= MODE_RUN;
					end
				end

				default: begin
					mode_state <= MODE_WAIT_START;
					mode_ready <= 1'b0;
					video_freeze_q <= 1'b1;
					mode_restart_q <= 1'b0;
				end
			endcase
		end
	end

	always_comb begin
		case (aspect_ratio)
			2'd0: begin
				video_arx = optimized_arx;
				video_ary = optimized_ary;
			end
			2'd1: begin
				video_arx = 13'd0;
				video_ary = 13'd0;
			end
			default: begin
				video_arx = 13'h1000 | {1'b0, fb_width};
				video_ary = 13'h1000 | {1'b0, fb_height};
			end
		endcase
	end

	typedef struct packed {
		logic [11:0] fb_width;
		logic [11:0] fb_height;
		logic [11:0] x_center;
		logic [11:0] y_center;
		logic  [2:0] orientation;
		logic        zoom_wide;
		logic  [1:0] tone_mapping;
		logic        is_1080p;
		logic        is_480p;
		logic        is_240p;
		logic        game_is_lander;
	} raster_cfg_t;

	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	raster_cfg_t raster_cfg_meta_12 = '0, raster_cfg_12 = '0;
	logic signed [23:0] raster_x;
	logic signed [23:0] raster_y;
	logic               beam_in_bounds;

	always_ff @(posedge clk_12) begin
		if (reset) begin
			raster_cfg_meta_12 <= '0;
			raster_cfg_12 <= '0;
		end else begin
			raster_cfg_meta_12.fb_width <= fb_width;
			raster_cfg_meta_12.fb_height <= fb_height;
			raster_cfg_meta_12.x_center <= x_center;
			raster_cfg_meta_12.y_center <= y_center;
			raster_cfg_meta_12.orientation <= geometry_orientation;
			raster_cfg_meta_12.zoom_wide <= geometry_zoom_wide;
			raster_cfg_meta_12.tone_mapping <= effective_tone_mapping;
			raster_cfg_meta_12.is_1080p <= is_1080p;
			raster_cfg_meta_12.is_480p <= is_480p;
			raster_cfg_meta_12.is_240p <= is_240p;
			raster_cfg_meta_12.game_is_lander <= game_is_lander;
			raster_cfg_12 <= raster_cfg_meta_12;
		end
	end

	asteroids_geometry geometry (
		.source_x(dvg_x),
		.source_y(dvg_y),
		.game_is_lander(raster_cfg_12.game_is_lander),
		.mode_1080p(raster_cfg_12.is_1080p),
		.mode_480p(raster_cfg_12.is_480p),
		.mode_240p(raster_cfg_12.is_240p),
		.center_x(raster_cfg_12.x_center),
		.center_y(raster_cfg_12.y_center),
		.render_width(raster_cfg_12.fb_width),
		.render_height(raster_cfg_12.fb_height),
		.orientation(raster_cfg_12.orientation),
		.zoom_wide(raster_cfg_12.zoom_wide),
		.raster_x(raster_x),
		.raster_y(raster_y),
		.beam_in_bounds(beam_in_bounds)
	);

	logic raw_beam_on;
	logic [7:0] mapped_intensity;
	assign raw_beam_on = dvg_beam_on && (dvg_z != 8'd0);

	vfb_tone_mapper tone_mapper (
		.clk_source(clk_12),
		.reset(reset),
		.beam_on(raw_beam_on),
		.raw_intensity(dvg_z),
		.tone_mapping(raster_cfg_12.tone_mapping),
		.mapped_intensity(mapped_intensity)
	);

	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic mode_ready_12_meta = 1'b0, mode_ready_12 = 1'b0;
	always_ff @(posedge clk_12) begin
		mode_ready_12_meta <= mode_ready;
		mode_ready_12 <= mode_ready_12_meta;
	end

	logic source_reset;
	assign source_reset = reset || !mode_ready_12;

	(* altera_attribute = {"-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS"} *)
	logic [1:0] render_reset_sync = 2'b11;
	logic       render_reset;
	always_ff @(posedge clk_render)
		render_reset_sync <= {
			render_reset_sync[0], reset || !mode_ready || mode_restart_q
		};
	assign render_reset = render_reset_sync[1];

	logic [10:0] vector_x_q = 11'd0;
	logic [10:0] vector_y_q = 11'd0;
	logic  [7:0] vector_z_q = 8'd0;
	logic  [3:0] vector_color_q = 4'd0;
	logic        vector_is_dot_q = 1'b0;
	logic        vector_beam_on_q = 1'b0;
	logic        frame_done_q = 1'b0;

	always_ff @(posedge clk_12) begin
		if (source_reset) begin
			vector_x_q <= 11'd0;
			vector_y_q <= 11'd0;
			vector_z_q <= 8'd0;
			vector_color_q <= 4'd0;
			vector_is_dot_q <= 1'b0;
			vector_beam_on_q <= 1'b0;
			frame_done_q <= 1'b0;
		end else begin
			vector_x_q <= raster_x[10:0];
			vector_y_q <= raster_y[10:0];
			vector_z_q <= mapped_intensity;
			vector_color_q <= 4'b1111;
			vector_is_dot_q <= dvg_is_dot;
			vector_beam_on_q <= raw_beam_on && beam_in_bounds;
			frame_done_q <= frame_done;
		end
	end

	logic half_rate_phase = 1'b0;
	logic [19:0] fractional_numerator;
	logic [19:0] fractional_denominator;
	logic        fractional_ce;
	logic        progressive_ce_pixel = 1'b0;
	logic [10:0] h_counter = 11'd0;
	logic [10:0] v_counter = 11'd0;
	logic timing_reset;
	logic h_end;
	logic v_end;
	logic v_end_q = 1'b0;
	logic raw_hsync;
	logic raw_vsync;
	logic raw_hblank;
	logic raw_vblank;
	logic [7:0] progressive_video_r;
	logic [7:0] progressive_video_g;
	logic [7:0] progressive_video_b;
	logic       progressive_hsync;
	logic       progressive_vsync;
	logic       progressive_hblank;
	logic       progressive_vblank;
	(* preserve, dont_merge *) logic ce_pixel_overlay = 1'b0;

	assign timing_reset = !mode_ready;
	assign h_end = (h_counter >= h_total[10:0]);
	assign v_end = v_end_q;
	assign frame_wrap = progressive_ce_pixel && h_end && v_end;
	assign mode_commit =
		(mode_state == MODE_WAIT_TIMING_WRAP) && frame_wrap;

	always_comb begin
		if (is_480p) begin
			fractional_numerator = is_authentic ?
			                       (is_interlaced ? 20'd227677 : 20'd5681) :
			                       20'd116909;
			fractional_denominator = is_authentic ?
			                         (is_interlaced ? 20'd1044480 : 20'd26112) :
			                         20'd536035;
		end else begin
			fractional_numerator = is_authentic ? 20'd5681 : 20'd58344;
			fractional_denominator = is_authentic ? 20'd52224 : 20'd536035;
		end
	end

	video_fractional_ce #(.WIDTH(20)) pixel_enable_nco (
		.clk(clk_render),
		.reset(timing_reset || mode_commit),
		.advance(is_240p || is_480p),
		.numerator(fractional_numerator),
		.denominator(fractional_denominator),
		.ce(fractional_ce)
	);

	always_ff @(posedge clk_render) begin
		if (timing_reset || mode_commit) begin
			progressive_ce_pixel <= 1'b0;
			ce_pixel_overlay <= 1'b0;
		end else if (is_1080p || is_120hz) begin
			progressive_ce_pixel <= 1'b1;
			ce_pixel_overlay <= 1'b1;
		end else if (is_240p || is_480p) begin
			progressive_ce_pixel <= fractional_ce;
			ce_pixel_overlay <= fractional_ce;
		end else begin
			progressive_ce_pixel <= !half_rate_phase;
			ce_pixel_overlay <= !half_rate_phase;
		end
	end

	always_ff @(posedge clk_render) begin
		if (timing_reset || mode_commit)
			v_end_q <= 1'b0;
		else
			v_end_q <= (v_counter >= v_total[10:0]);
	end

	always_ff @(posedge clk_render) begin
		if (timing_reset) begin
			half_rate_phase <= 1'b0;
			h_counter <= h_total[10:0];
			v_counter <= fb_height[10:0] + 11'd2;
		end else if (mode_commit) begin
			half_rate_phase <= 1'b0;
			h_counter <= 11'd0;
			v_counter <= 11'd0;
		end else begin
			half_rate_phase <= !half_rate_phase;
			if (progressive_ce_pixel) begin
				if (h_end) begin
					h_counter <= 11'd0;
					v_counter <= v_end ? 11'd0 : v_counter + 1'd1;
				end else begin
					h_counter <= h_counter + 1'd1;
				end
			end
		end
	end

	always_comb begin
		raw_hsync  = !((h_counter >= hs_start[10:0]) &&
		               (h_counter < hs_end[10:0]));
		raw_vsync  = !((v_counter >= vs_start[10:0]) &&
		               (v_counter < vs_end[10:0]));
		raw_hblank = (h_counter >= fb_width[10:0]);
		raw_vblank = (v_counter >= fb_height[10:0]);
	end

	vfb_top framebuffer (
		.clk_sys(clk_render),
		.clk_12(clk_12),
		.clk_io(clk_12),
		.reset(render_reset),
		.source_reset(source_reset),
		.ddr_reset(ddr_reset),
		.upload_reset(upload_reset),
		.video_timing_reset(timing_reset),

		.X_VECTOR(vector_x_q),
		.Y_VECTOR(vector_y_q),
		.Z_VECTOR(vector_z_q),
		.COLOR(vector_color_q),
		.IS_DOT(vector_is_dot_q),
		.BEAM_ON(vector_beam_on_q),

		.DDRAM_CLK(ddram_clk),
		.DDRAM_BUSY(ddram_busy),
		.DDRAM_BURSTCNT(ddram_burst_count),
		.DDRAM_ADDR(ddram_address),
		.DDRAM_DOUT(ddram_data_out),
		.DDRAM_DOUT_READY(ddram_data_ready),
		.DDRAM_RD(ddram_read),
		.DDRAM_DIN(ddram_data_in),
		.DDRAM_BE(ddram_byte_enable),
		.DDRAM_WE(ddram_write),

		.SDRAM_DQ_IN(sdram_data_in),
		.SDRAM_DQ_OUT(sdram_data_out),
		.SDRAM_DQ_OE(sdram_data_oe),
		.SDRAM_CKE(sdram_cke),
		.SDRAM_nCS(sdram_ncs),
		.SDRAM_nRAS(sdram_nras),
		.SDRAM_nCAS(sdram_ncas),
		.SDRAM_nWE(sdram_nwe),
		.SDRAM_DQM(sdram_dqm),
		.SDRAM_A(sdram_address),
		.SDRAM_BA(sdram_bank),

		.RENDER_WIDTH(fb_width),
		.RENDER_HEIGHT(fb_height),
		.VGA_R(progressive_video_r),
		.VGA_G(progressive_video_g),
		.VGA_B(progressive_video_b),
		.VGA_HS(progressive_hsync),
		.VGA_VS(progressive_vsync),
		.VGA_HBLANK(progressive_hblank),
		.VGA_VBLANK(progressive_vblank),

		.h_cnt(h_counter),
		.v_cnt(v_counter),
		.ce_pix(progressive_ce_pixel),
		.ce_pix_overlay(ce_pixel_overlay),
		.hsync(raw_hsync),
		.vsync(raw_vsync),
		.hblank(raw_hblank),
		.vblank(raw_vblank),

		.FLASH_PARAM(8'd0),
		.OSD_120HZ(is_120hz),
		.FRAME_DONE(frame_done_q),
		.BUFFER_MODE(buffer_mode),
		.DOT_MODE(effective_dot_mode),
		.FIFO_FULL_LED(fifo_full),
		.osd_bloom_width(effective_bloom_width),
		.osd_bloom_curve(effective_bloom_curve),
		.osd_halo_filter(effective_halo_filter),
		.osd_halo_curve(effective_halo_curve),
		.osd_phosphor_mode(effective_intra_frame_decay),
		.osd_inter_frame_phosphor_mode(effective_inter_frame_decay),
		.osd_halo_spread(effective_halo_spread),
		.osd_halo_knee(effective_halo_knee),
		.osd_color_space(1'b0),
		.osd_presentation_color(effective_presentation_color),
		.osd_slot_mask(1'b0),
		.osd_slot_mask_rows(1'b1),
		.full_bypass_active(active_bypass_q),
		.processed_path_prepare(processed_path_prepare_q),
		.artwork_enable(effective_artwork_enable),
		.artwork_blend(effective_artwork_blend),
		.ioctl_download(ioctl_download),
		.ioctl_wr(ioctl_wr),
		.ioctl_index(ioctl_index),
		.ioctl_addr(ioctl_addr),
		.ioctl_data(ioctl_data),
		.artwork_available(artwork_available),
		.ioctl_wait(ioctl_wait),
		.raw_path_vblank(raw_path_vblank),
		.processed_path_vblank(processed_path_vblank)
	);

	localparam logic [1:0] INTERLACER_PATH_RESTART_CYCLES = 2'd3;
	logic [1:0] interlacer_restart_count = 2'd0;
	logic       interlacer_mode_commit_q = 1'b0;
	always_ff @(posedge clk_render) begin
		if (upload_reset_render || timing_reset)
			interlacer_mode_commit_q <= 1'b0;
		else
			interlacer_mode_commit_q <= mode_commit;
	end

	always_ff @(posedge clk_render) begin
		if (upload_reset_render || timing_reset || !is_interlaced)
			interlacer_restart_count <= 2'd0;
		else if (profile_path_commit)
			interlacer_restart_count <= INTERLACER_PATH_RESTART_CYCLES;
		else if (interlacer_restart_count != 2'd0)
			interlacer_restart_count <= interlacer_restart_count - 1'd1;
	end

	vfb_interlacer interlacer (
		.clk_sys(clk_render),
		.reset(timing_reset || interlacer_mode_commit_q || mode_restart_q ||
		       !is_interlaced ||
		       (interlacer_restart_count != 2'd0)),
		.enable(is_interlaced),
		.authentic_timing(is_authentic),
		.vertical_offset(crt_vertical_offset),
		.ce_pix_in(progressive_ce_pixel),
		.r_in(progressive_video_r),
		.g_in(progressive_video_g),
		.b_in(progressive_video_b),
		.hsync_in(progressive_hsync),
		.vsync_in(progressive_vsync),
		.hblank_in(progressive_hblank),
		.vblank_in(progressive_vblank),
		.ce_pix_out(ce_pixel),
		.r_out(video_r),
		.g_out(video_g),
		.b_out(video_b),
		.hsync_out(hsync),
		.vsync_out(vsync),
		.hblank_out(hblank),
		.vblank_out(vblank),
		.field_out(field)
	);

	always_comb mode_supports_120hz = mode_ready && height_supports_120hz;
	always_comb mode_is_15khz = mode_ready && (is_240p || is_interlaced);
	always_comb mode_is_480line = mode_ready && is_480p;

endmodule
