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
	output logic        mode_is_720p,
	output logic        fifo_full,
	output logic        artwork_available,
	output logic        ioctl_wait,
	output logic        video_mode_toggle,
	output logic        video_freeze,

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

	logic direct_video_meta = 1'b0;
	logic direct_video_sync = 1'b0;
	logic scan_rate_meta = 1'b0;
	logic scan_rate_sync = 1'b0;
	logic [11:0] requested_height_meta = 12'd0;
	logic [11:0] requested_height_sync = 12'd0;
	logic [11:0] height_candidate = 12'd0;
	logic [11:0] stable_height = 12'd0;
	logic [24:0] height_timer = 25'd0;

	logic mode_120hz_meta = 1'b0;
	logic mode_120hz_sync = 1'b0;
	logic stable_120hz = 1'b0;
	logic [24:0] rate_timer = 25'd0;

	logic authentic_timing_meta = 1'b0;
	logic authentic_timing_sync = 1'b0;
	logic stable_authentic_timing = 1'b0;
	logic [24:0] timing_timer = 25'd0;
	logic upload_reset_50_meta = 1'b1;
	logic upload_reset_50 = 1'b1;
	logic startup_ready_50 = 1'b0;
	logic [24:0] startup_timer = 25'd0;

	always_ff @(posedge clk_50) begin
		upload_reset_50_meta <= upload_reset;
		upload_reset_50 <= upload_reset_50_meta;

		direct_video_meta <= direct_video;
		direct_video_sync <= direct_video_meta;
		scan_rate_meta <= direct_video_31khz;
		scan_rate_sync <= scan_rate_meta;

		requested_height_meta <= direct_video_sync ?
		                         (scan_rate_sync ? 12'd480 : 12'd240) :
		                         hdmi_height;
		requested_height_sync <= requested_height_meta;

		mode_120hz_meta <= mode_120hz;
		mode_120hz_sync <= mode_120hz_meta;
		authentic_timing_meta <= authentic_timing;
		authentic_timing_sync <= authentic_timing_meta;

		if (upload_reset_50) begin
			height_candidate <= 12'd0;
			stable_height <= 12'd0;
			height_timer <= 25'd0;
			stable_120hz <= 1'b0;
			rate_timer <= 25'd0;
			stable_authentic_timing <= 1'b0;
			timing_timer <= 25'd0;
			startup_ready_50 <= 1'b0;
			startup_timer <= 25'd0;
		end else begin
			if (stable_height == 12'd0) begin
				if ((requested_height_meta == requested_height_sync) &&
				    (requested_height_sync > 12'd200)) begin
					if (requested_height_sync != height_candidate) begin
						height_candidate <= requested_height_sync;
						height_timer <= 25'd0;
					end else if (height_timer < MODE_STABLE_CYCLES - 1'd1) begin
						height_timer <= height_timer + 1'd1;
					end else begin
						stable_height <= height_candidate;
						height_timer <= 25'd0;
					end
				end else begin
					height_candidate <= requested_height_sync;
					height_timer <= 25'd0;
				end
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

			if (!startup_ready_50) begin
				if ((stable_height != 12'd0) &&
				    (mode_120hz_meta == mode_120hz_sync) &&
				    (mode_120hz_sync == stable_120hz) &&
				    (rate_timer == 25'd0) &&
				    (authentic_timing_meta == authentic_timing_sync) &&
				    (authentic_timing_sync == stable_authentic_timing) &&
				    (timing_timer == 25'd0)) begin
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

	typedef struct packed {
		logic [11:0] fb_width;
		logic [11:0] fb_height;
		logic [11:0] x_center;
		logic [11:0] y_center;
		logic [12:0] optimized_arx;
		logic [12:0] optimized_ary;
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
	} video_mode_t;

	function automatic video_mode_t decode_video_mode(
		input logic [11:0] height,
		input logic        requested_120hz,
		input logic        requested_authentic_timing
	);
		video_mode_t mode;
		begin
			mode = '0;
			if ((height >= 12'd1080) && (height < 12'd1400)) begin
				mode.fb_width = 12'd1360;
				mode.fb_height = 12'd1080;
				mode.x_center = 12'd680;
				mode.y_center = 12'd540;
				mode.optimized_arx = 13'h1000 | 13'd1360;
				mode.optimized_ary = 13'h1000 | 13'd1080;
				mode.h_total = requested_authentic_timing ? 12'd1846 : 12'd1903;
				mode.v_total = requested_authentic_timing ? 12'd1130 : 12'd1124;
				mode.hs_start = 12'd1600;
				mode.hs_end = 12'd1688;
				mode.vs_start = 12'd1088;
				mode.vs_end = 12'd1093;
				mode.is_1080p = 1'b1;
			end else if (height < 12'd480) begin
				mode.fb_width = 12'd640;
				mode.fb_height = 12'd240;
				mode.x_center = 12'd320;
				mode.y_center = 12'd120;
				mode.optimized_arx = 13'h1000 | 13'd640;
				mode.optimized_ary = 13'h1000 | 13'd240;
				mode.h_total = requested_authentic_timing ? 12'd815 : 12'd817;
				mode.v_total = requested_authentic_timing ? 12'd255 : 12'd261;
				mode.hs_start = 12'd678;
				mode.hs_end = 12'd739;
				mode.vs_start = requested_authentic_timing ? 12'd243 : 12'd244;
				mode.vs_end = requested_authentic_timing ? 12'd246 : 12'd248;
				mode.is_240p = 1'b1;
			end else if (height < 12'd720) begin
				mode.fb_width = 12'd640;
				mode.fb_height = 12'd480;
				mode.x_center = 12'd320;
				mode.y_center = 12'd240;
				mode.optimized_arx = 13'h1000 | 13'd640;
				mode.optimized_ary = 13'h1000 | 13'd480;
				mode.h_total = requested_authentic_timing ? 12'd959 : 12'd1019;
				mode.v_total = requested_authentic_timing ? 12'd543 : 12'd524;
				mode.hs_start = 12'd720;
				mode.hs_end = 12'd816;
				mode.vs_start = 12'd490;
				mode.vs_end = 12'd492;
				mode.is_480p = 1'b1;
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
				mode.h_total = (requested_120hz || !requested_authentic_timing) ?
				               12'd1427 : 12'd1359;
				mode.v_total = (requested_120hz || !requested_authentic_timing) ?
				               12'd749 : 12'd767;
				mode.hs_start = 12'd1108;
				mode.hs_end = 12'd1196;
				mode.vs_start = 12'd728;
				mode.vs_end = 12'd733;
				mode.is_120hz = requested_120hz;
			end
			decode_video_mode = mode;
		end
	endfunction

	video_mode_t mode_q = decode_video_mode(12'd480, 1'b0, 1'b0);

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

	logic [11:0] height_meta = 12'd0;
	logic [11:0] height_sync = 12'd0;
	logic [11:0] height_sync_d = 12'd0;
	logic        rate_meta = 1'b0;
	logic        rate_sync = 1'b0;
	logic        rate_sync_d = 1'b0;
	logic        timing_meta = 1'b0;
	logic        timing_sync = 1'b0;
	logic        timing_sync_d = 1'b0;
	logic        bypass_meta = 1'b1;
	logic        bypass_sync = 1'b1;
	logic        bypass_sync_d = 1'b1;
	logic        bypass_stable = 1'b1;
	logic        startup_ready_meta = 1'b0;
	logic        startup_ready_sync = 1'b0;
	logic        startup_ready_sync_d = 1'b0;
	logic        upload_reset_render_meta = 1'b1;
	logic        upload_reset_render = 1'b1;

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

	video_mode_t requested_mode = decode_video_mode(12'd480, 1'b0, 1'b0);
	video_mode_t pending_mode_q = decode_video_mode(12'd480, 1'b0, 1'b0);
	logic        request_valid = 1'b0;
	logic        request_bypass = 1'b1;
	logic  [1:0] request_key = 2'b00;
	logic  [1:0] active_key_q = 2'b00;
	logic  [1:0] pending_key_q = 2'b00;

	wire next_request_120hz = rate_sync_d && (height_sync_d == 12'd720);
	wire next_request_authentic_timing =
		timing_sync_d && !next_request_120hz;
	wire next_request_valid = startup_ready_sync_d &&
		(startup_ready_sync == startup_ready_sync_d) &&
		(height_sync_d != 12'd0) &&
		(height_sync == height_sync_d) &&
		(rate_sync == rate_sync_d) &&
		(timing_sync == timing_sync_d) &&
		(bypass_sync == bypass_sync_d) &&
		(bypass_stable == bypass_sync_d);

	always_ff @(posedge clk_render) begin
		if (upload_reset_render) begin
			requested_mode <= decode_video_mode(12'd480, 1'b0, 1'b0);
			request_valid <= 1'b0;
			request_bypass <= 1'b1;
			request_key <= 2'b00;
		end else begin
			requested_mode <= decode_video_mode(height_sync_d,
			                                    next_request_120hz,
			                                    next_request_authentic_timing);
			request_valid <= next_request_valid;
			request_bypass <= bypass_stable;
			request_key <= {next_request_120hz,
			                next_request_authentic_timing};
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
	logic raw_path_vblank;
	logic processed_path_vblank;
	logic raw_path_vblank_q = 1'b1;
	logic processed_path_vblank_q = 1'b1;
	logic frame_wrap;
	logic mode_commit;
	wire raw_path_vblank_entry = raw_path_vblank && !raw_path_vblank_q;
	wire processed_path_vblank_entry =
		processed_path_vblank && !processed_path_vblank_q;
	wire active_path_vblank_entry = active_bypass_q ?
		raw_path_vblank_entry : processed_path_vblank_entry;
	wire target_path_vblank_entry = pending_bypass_q ?
		raw_path_vblank_entry : processed_path_vblank_entry;
	wire request_changed = (request_key != active_key_q) ||
	                       (request_bypass != active_bypass_q);

	assign video_mode_toggle = video_mode_toggle_q;
	assign video_freeze = video_freeze_q;

	always_ff @(posedge clk_render) begin
		if (upload_reset_render) begin
			raw_path_vblank_q <= 1'b1;
			processed_path_vblank_q <= 1'b1;
		end else begin
			raw_path_vblank_q <= raw_path_vblank;
			processed_path_vblank_q <= processed_path_vblank;
		end
	end

	always_ff @(posedge clk_render) begin
		if (upload_reset_render) begin
			mode_q <= decode_video_mode(12'd480, 1'b0, 1'b0);
			pending_mode_q <= decode_video_mode(12'd480, 1'b0, 1'b0);
			active_key_q <= 2'b00;
			pending_key_q <= 2'b00;
			active_bypass_q <= 1'b1;
			pending_bypass_q <= 1'b1;
			processed_path_prepare_q <= 1'b0;
			transition_timing_q <= 1'b0;
			mode_state <= MODE_WAIT_START;
			mode_ready <= 1'b0;
			video_freeze_q <= 1'b1;
		end else begin
			case (mode_state)
				MODE_WAIT_START: begin
					mode_ready <= 1'b0;
					video_freeze_q <= 1'b1;
					if (request_valid) begin
						mode_q <= requested_mode;
						pending_mode_q <= requested_mode;
						active_key_q <= request_key;
						pending_key_q <= request_key;
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
					if (request_valid && request_changed) begin
						pending_mode_q <= requested_mode;
						pending_key_q <= request_key;
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
						pending_key_q <= request_key;
						pending_bypass_q <= request_bypass;
						if (!request_bypass)
							processed_path_prepare_q <= 1'b1;
						if (active_path_vblank_entry) begin
							transition_timing_q <=
								(request_key != active_key_q);
							video_freeze_q <= 1'b1;
							mode_state <= (request_key != active_key_q) ?
								MODE_WAIT_TIMING_WRAP : MODE_WAIT_TARGET_VBLANK;
						end
					end
				end

				MODE_WAIT_TIMING_WRAP: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b1;
					if (frame_wrap) begin
						mode_q <= pending_mode_q;
						active_key_q <= pending_key_q;
						video_mode_toggle_q <= !video_mode_toggle_q;
						mode_state <= MODE_WAIT_TARGET_VBLANK;
					end
				end

				MODE_WAIT_TARGET_VBLANK: begin
					mode_ready <= 1'b1;
					video_freeze_q <= 1'b1;
					if (target_path_vblank_entry) begin
						active_key_q <= pending_key_q;
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
					if (target_path_vblank_entry) begin
						video_freeze_q <= 1'b0;
						mode_state <= MODE_RUN;
					end
				end

				default: begin
					mode_state <= MODE_WAIT_START;
					mode_ready <= 1'b0;
					video_freeze_q <= 1'b1;
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
		logic        is_1080p;
		logic        is_480p;
		logic        is_240p;
		logic        game_is_lander;
	} geometry_mode_t;

	geometry_mode_t geometry_mode_meta_12 = '0;
	geometry_mode_t geometry_mode_12 = '0;
	logic  [2:0] geometry_orientation_q = 3'd0;
	logic        geometry_zoom_wide_q = 1'b0;
	logic  [2:0] geometry_orientation_meta_12 = 3'd0;
	logic  [2:0] geometry_orientation_12 = 3'd0;
	logic        geometry_zoom_wide_meta_12 = 1'b0;
	logic        geometry_zoom_wide_12 = 1'b0;
	logic  [1:0] tone_mapping_meta_12 = 2'd0;
	logic  [1:0] tone_mapping_12 = 2'd0;
	logic signed [23:0] raster_x;
	logic signed [23:0] raster_y;
	logic               beam_in_bounds;

	always_ff @(posedge clk_render) begin
		if (reset) begin
			geometry_orientation_q <= 3'd0;
			geometry_zoom_wide_q <= 1'b0;
		end else begin
			geometry_orientation_q <= geometry_orientation;
			geometry_zoom_wide_q <= geometry_zoom_wide;
		end
	end

	always_ff @(posedge clk_12) begin
		if (reset) begin
			geometry_mode_meta_12 <= '0;
			geometry_mode_12 <= '0;
			geometry_orientation_meta_12 <= 3'd0;
			geometry_orientation_12 <= 3'd0;
			geometry_zoom_wide_meta_12 <= 1'b0;
			geometry_zoom_wide_12 <= 1'b0;
			tone_mapping_meta_12 <= 2'd0;
			tone_mapping_12 <= 2'd0;
		end else begin
			geometry_mode_meta_12.fb_width <= fb_width;
			geometry_mode_meta_12.fb_height <= fb_height;
			geometry_mode_meta_12.x_center <= x_center;
			geometry_mode_meta_12.y_center <= y_center;
			geometry_mode_meta_12.is_1080p <= is_1080p;
			geometry_mode_meta_12.is_480p <= is_480p;
			geometry_mode_meta_12.is_240p <= is_240p;
			geometry_mode_meta_12.game_is_lander <= game_is_lander;
			geometry_mode_12 <= geometry_mode_meta_12;
			geometry_orientation_meta_12 <= geometry_orientation_q;
			geometry_orientation_12 <= geometry_orientation_meta_12;
			geometry_zoom_wide_meta_12 <= geometry_zoom_wide_q;
			geometry_zoom_wide_12 <= geometry_zoom_wide_meta_12;
			tone_mapping_meta_12 <= effective_tone_mapping;
			tone_mapping_12 <= tone_mapping_meta_12;
		end
	end

	asteroids_geometry geometry (
		.source_x(dvg_x),
		.source_y(dvg_y),
		.game_is_lander(geometry_mode_12.game_is_lander),
		.mode_1080p(geometry_mode_12.is_1080p),
		.mode_480p(geometry_mode_12.is_480p),
		.mode_240p(geometry_mode_12.is_240p),
		.center_x(geometry_mode_12.x_center),
		.center_y(geometry_mode_12.y_center),
		.render_width(geometry_mode_12.fb_width),
		.render_height(geometry_mode_12.fb_height),
		.orientation(geometry_orientation_12),
		.zoom_wide(geometry_zoom_wide_12),
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
		.tone_mapping(tone_mapping_12),
		.mapped_intensity(mapped_intensity)
	);

	logic mode_ready_12_meta = 1'b0;
	logic mode_ready_12 = 1'b0;
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
		render_reset_sync <= {render_reset_sync[0], reset || !mode_ready};
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

	logic [2:0] clock_divider = 3'd0;
	logic [3:0] clock_divider_240 = 4'd0;
	logic [10:0] h_counter = 11'd0;
	logic [10:0] v_counter = 11'd0;
	logic timing_reset;
	logic h_end;
	logic v_end;
	logic raw_hsync;
	logic raw_vsync;
	logic raw_hblank;
	logic raw_vblank;
	(* preserve, dont_merge *) logic ce_pixel_overlay = 1'b0;

	assign timing_reset = !mode_ready;
	assign h_end = (h_counter >= h_total[10:0]);
	assign v_end = (v_counter >= v_total[10:0]);
	assign frame_wrap = ce_pixel && h_end && v_end;
	assign mode_commit =
		(mode_state == MODE_WAIT_TIMING_WRAP) && frame_wrap;

	always_ff @(posedge clk_render) begin
		if (timing_reset || mode_commit) begin
			ce_pixel <= 1'b0;
			ce_pixel_overlay <= 1'b0;
		end else if (is_1080p || is_120hz) begin
			ce_pixel <= 1'b1;
			ce_pixel_overlay <= 1'b1;
		end else if (is_240p) begin
			ce_pixel <= (clock_divider_240 == 4'd0);
			ce_pixel_overlay <= (clock_divider_240 == 4'd0);
		end else if (is_480p) begin
			ce_pixel <= (clock_divider[1:0] == 2'd0);
			ce_pixel_overlay <= (clock_divider[1:0] == 2'd0);
		end else begin
			ce_pixel <= (clock_divider[0] == 1'b0);
			ce_pixel_overlay <= (clock_divider[0] == 1'b0);
		end
	end

	always_ff @(posedge clk_render) begin
		if (timing_reset) begin
			clock_divider <= 3'd0;
			clock_divider_240 <= 4'd0;
			h_counter <= h_total[10:0];
			v_counter <= fb_height[10:0] + 11'd2;
		end else if (mode_commit) begin
			clock_divider <= 3'd0;
			clock_divider_240 <= 4'd0;
			h_counter <= 11'd0;
			v_counter <= 11'd0;
		end else begin
			clock_divider <= clock_divider + 1'd1;
			clock_divider_240 <= (clock_divider_240 == 4'd9) ?
			                         4'd0 : clock_divider_240 + 1'd1;
			if (ce_pixel) begin
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
		.VGA_R(video_r),
		.VGA_G(video_g),
		.VGA_B(video_b),
		.VGA_HS(hsync),
		.VGA_VS(vsync),
		.VGA_HBLANK(hblank),
		.VGA_VBLANK(vblank),

		.h_cnt(h_counter),
		.v_cnt(v_counter),
		.ce_pix(ce_pixel),
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

	always_comb mode_is_720p = mode_ready && !is_1080p && !is_480p && !is_240p;

endmodule
