//============================================================================
//  Atari Lunar Lander thrust input
//
//  Written 2026 by Videodr0me
//
//  Converts the selected analog stick into the cabinet's 0..254 thrust range.
//  Half range uses center-to-up travel; full range uses the entire Y axis.
//  The output tracks the requested position at the board's 3 kHz rate.
//============================================================================

module llander_thrust_input
(
	input  logic              clk,
	input  logic              reset,
	input  logic signed [7:0] analog_left_y,
	input  logic signed [7:0] analog_right_y,
	input  logic              select_right,
	input  logic              full_range,
	input  logic              digital_thrust,
	output logic        [7:0] thrust_level
);

	logic signed [7:0] selected_y;
	logic signed [7:0] analog_y_q = 8'sd0;
	logic              full_range_q = 1'b0;
	logic              digital_thrust_q = 1'b0;
	logic              analog_active_q = 1'b0;
	logic        [8:0] analog_magnitude;
	logic signed [8:0] full_range_magnitude;
	logic        [9:0] scaled_magnitude;
	logic        [7:0] thrust_target;
	logic       [11:0] track_divider = 12'd0;

	assign selected_y = select_right ? analog_right_y : analog_left_y;

	always_comb begin
		analog_magnitude = 9'd0;
		full_range_magnitude = 9'sd0;
		scaled_magnitude = 10'd0;
		thrust_target = 8'd0;

		if (digital_thrust_q) begin
			thrust_target = 8'd254;
		end else if (analog_active_q && full_range_q) begin
			full_range_magnitude = 9'sd127 -
			                       $signed({analog_y_q[7], analog_y_q});
			thrust_target = (full_range_magnitude > 9'sd254)
			              ? 8'd254 : full_range_magnitude[7:0];
		end else if (analog_active_q && (analog_y_q < -8'sd16)) begin
			analog_magnitude =
				$unsigned(-$signed({analog_y_q[7], analog_y_q}) - 9'sd16);
			scaled_magnitude = (analog_magnitude << 1) +
			                   (analog_magnitude >> 2) +
			                   (analog_magnitude >> 5);
			thrust_target = (scaled_magnitude > 10'd254)
			              ? 8'd254 : scaled_magnitude[7:0];
		end
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			analog_y_q <= selected_y;
			full_range_q <= full_range;
			digital_thrust_q <= 1'b0;
			analog_active_q <= 1'b0;
			track_divider <= 12'd0;
			thrust_level <= 8'd0;
		end else begin
			analog_y_q <= selected_y;
			full_range_q <= full_range;
			digital_thrust_q <= digital_thrust;
			if (selected_y != analog_y_q)
				analog_active_q <= 1'b1;

			track_divider <= track_divider + 1'b1;
			if (track_divider == 12'hfff) begin
				if (thrust_level < thrust_target)
					thrust_level <= thrust_level + 1'b1;
				else if (thrust_level > thrust_target)
					thrust_level <= thrust_level - 1'b1;
			end
		end
	end

endmodule
