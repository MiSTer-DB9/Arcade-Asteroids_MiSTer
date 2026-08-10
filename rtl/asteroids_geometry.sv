//============================================================================
//  Asteroids vector geometry
//
//  Written 2026 by Videodr0me
//
//  Maps the DVG's doubled presentation coordinates into each raster mode with
//  a uniform object scale, then applies orientation around the raster center.
//============================================================================

module asteroids_geometry
(
	input  logic       [10:0] source_x,
	input  logic       [10:0] source_y,
	input  logic              game_is_lander,
	input  logic              mode_1080p,
	input  logic              mode_480p,
	input  logic              mode_240p,
	input  logic       [11:0] center_x,
	input  logic       [11:0] center_y,
	input  logic       [11:0] render_width,
	input  logic       [11:0] render_height,
	input  logic        [2:0] orientation,
	input  logic              zoom_wide,
	output logic signed [23:0] raster_x,
	output logic signed [23:0] raster_y,
	output logic              beam_in_bounds
);

	logic signed [23:0] centered_x;
	logic signed [23:0] centered_y;
	logic signed [23:0] scaled_x;
	logic signed [23:0] scaled_y;
	logic signed [23:0] horizontal_scaled_x;
	logic signed [23:0] horizontal_scaled_y;
	logic signed [23:0] selected_x;
	logic signed [23:0] selected_y;
	logic signed [23:0] presented_y;
	logic signed [23:0] oriented_x;
	logic signed [23:0] oriented_y;
	logic               quarter_turn;
	logic               negate_x;
	logic               negate_y;

	always_comb begin
		centered_x = $signed({1'b0, source_x}) - 24'sd1024;
		// Lunar Lander uses source Y=788 as its center; Asteroids uses Y=1024.
		centered_y = $signed({1'b0, source_y}) -
		             (game_is_lander ? 24'sd788 : 24'sd1024);
		quarter_turn = (orientation == 3'd1) ||
		               (orientation == 3'd3) ||
		               (orientation == 3'd6) ||
		               (orientation == 3'd7);

		if (mode_1080p) begin
			if (!zoom_wide && !quarter_turn) begin
				// 21/32.
				scaled_x = ((centered_x << 4) + (centered_x << 2) + centered_x) >>> 5;
				scaled_y = ((centered_y << 4) + (centered_y << 2) + centered_y) >>> 5;
			end else if (!zoom_wide) begin
				// 1/2.
				scaled_x = centered_x >>> 1;
				scaled_y = centered_y >>> 1;
			end else if (!quarter_turn) begin
				// 5/8.
				scaled_x = ((centered_x << 2) + centered_x) >>> 3;
				scaled_y = ((centered_y << 2) + centered_y) >>> 3;
			end else begin
				// 15/32.
				scaled_x = ((centered_x << 4) - centered_x) >>> 5;
				scaled_y = ((centered_y << 4) - centered_y) >>> 5;
			end
		end else if (mode_480p || mode_240p) begin
			if (!zoom_wide && !quarter_turn) begin
				// 9/32.
				scaled_x = ((centered_x << 3) + centered_x) >>> 5;
				scaled_y = ((centered_y << 3) + centered_y) >>> 5;
			end else if (!zoom_wide) begin
				if (game_is_lander) begin
					// Preserve Lunar Lander's existing quarter-turn framing.
					scaled_x = ((centered_x << 3) - centered_x) >>> 5;
				end else begin
					// 15/64 maps source X=0..2047 to the full raster height.
					scaled_x = ((centered_x << 4) - centered_x) >>> 6;
				end
				scaled_y = ((centered_y << 3) - centered_y) >>> 5;
			end else if (!quarter_turn) begin
				// 17/64.
				scaled_x = ((centered_x << 4) + centered_x) >>> 6;
				scaled_y = ((centered_y << 4) + centered_y) >>> 6;
			end else begin
				// 13/64.
				scaled_x = ((centered_x << 3) + (centered_x << 2) + centered_x) >>> 6;
				scaled_y = ((centered_y << 3) + (centered_y << 2) + centered_y) >>> 6;
			end
		end else begin
			if (!zoom_wide && !quarter_turn) begin
				// 7/16.
				scaled_x = ((centered_x << 3) - centered_x) >>> 4;
				scaled_y = ((centered_y << 3) - centered_y) >>> 4;
			end else if (!zoom_wide) begin
				// 21/64.
				scaled_x = ((centered_x << 4) + (centered_x << 2) + centered_x) >>> 6;
				scaled_y = ((centered_y << 4) + (centered_y << 2) + centered_y) >>> 6;
			end else if (!quarter_turn) begin
				// 13/32.
				scaled_x = ((centered_x << 3) + (centered_x << 2) + centered_x) >>> 5;
				scaled_y = ((centered_y << 3) + (centered_y << 2) + centered_y) >>> 5;
			end else begin
				// 5/16.
				scaled_x = ((centered_x << 2) + centered_x) >>> 4;
				scaled_y = ((centered_y << 2) + centered_y) >>> 4;
			end
		end

		// The 720-wide low-resolution modes retain the former 640-wide crop.
		// Scale raster X by 720/640 directly from the source coordinate so
		// adjacent shadow-DVG coordinates still move by at most one pixel.
		horizontal_scaled_x = scaled_x;
		horizontal_scaled_y = scaled_y;
		if (mode_480p || mode_240p) begin
			if (!zoom_wide && !quarter_turn) begin
				if (game_is_lander) begin
					// Preserve Lunar Lander's existing horizontal framing.
					horizontal_scaled_x = ((centered_x << 6) +
					                       (centered_x << 4) + centered_x) >>> 8;
				end else begin
					// 45/128 maps source X=0..2047 to raster X=0..719.
					horizontal_scaled_x = (((centered_x << 5) +
					                        (centered_x << 4)) -
					                       ((centered_x << 1) + centered_x)) >>> 7;
				end
				horizontal_scaled_y = ((centered_y << 6) + (centered_y << 4) + centered_y) >>> 8;
			end else if (!zoom_wide) begin
				// (7/32) * (9/8) = 63/256.
				horizontal_scaled_x = ((centered_x << 6) - centered_x) >>> 8;
				horizontal_scaled_y = ((centered_y << 6) - centered_y) >>> 8;
			end else if (!quarter_turn) begin
				// (17/64) * (9/8) = 153/512.
				horizontal_scaled_x = ((centered_x << 7) + (centered_x << 4) +
				                       (centered_x << 3) + centered_x) >>> 9;
				horizontal_scaled_y = ((centered_y << 7) + (centered_y << 4) +
				                       (centered_y << 3) + centered_y) >>> 9;
			end else begin
				// (13/64) * (9/8) = 117/512.
				horizontal_scaled_x = ((centered_x << 7) - (centered_x << 3) -
				                       (centered_x << 1) - centered_x) >>> 9;
				horizontal_scaled_y = ((centered_y << 7) - (centered_y << 3) -
				                       (centered_y << 1) - centered_y) >>> 9;
			end
		end

		case (orientation)
			3'd0: begin selected_x = horizontal_scaled_x; negate_x = 1'b0;
			             selected_y = scaled_y; negate_y = 1'b1; end
			3'd1: begin selected_x = horizontal_scaled_y; negate_x = 1'b0;
			             selected_y = scaled_x; negate_y = 1'b0; end
			3'd2: begin selected_x = horizontal_scaled_x; negate_x = 1'b1;
			             selected_y = scaled_y; negate_y = 1'b0; end
			3'd3: begin selected_x = horizontal_scaled_y; negate_x = 1'b1;
			             selected_y = scaled_x; negate_y = 1'b1; end
			3'd4: begin selected_x = horizontal_scaled_x; negate_x = 1'b1;
			             selected_y = scaled_y; negate_y = 1'b1; end
			3'd5: begin selected_x = horizontal_scaled_x; negate_x = 1'b0;
			             selected_y = scaled_y; negate_y = 1'b0; end
			3'd6: begin selected_x = horizontal_scaled_y; negate_x = 1'b0;
			             selected_y = scaled_x; negate_y = 1'b1; end
			default: begin selected_x = horizontal_scaled_y; negate_x = 1'b1;
			               selected_y = scaled_x; negate_y = 1'b0; end
		endcase

		oriented_x = negate_x ? -selected_x : selected_x;
		presented_y = mode_240p ? (selected_y >>> 1) : selected_y;
		oriented_y = negate_y ? -presented_y : presented_y;
		raster_x = $signed({12'd0, center_x}) - (negate_x ? 24'sd1 : 24'sd0) + oriented_x;
		raster_y = $signed({12'd0, center_y}) - (negate_y ? 24'sd1 : 24'sd0) + oriented_y;
		beam_in_bounds = (raster_x >= 24'sd0) &&
		                 (raster_x < $signed({12'd0, render_width})) &&
		                 (raster_y >= 24'sd0) &&
		                 (raster_y < $signed({12'd0, render_height}));
	end

endmodule
