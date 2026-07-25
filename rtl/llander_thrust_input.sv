//============================================================================
//  Atari Lunar Lander thrust input
//
//  Written 2026 by Videodr0me
//
//  Converts the upper half of a self-centering analog stick into the
//  cabinet's 0..254 thrust range. The output tracks the requested position
//  one count at a time at the board's 3 kHz rate. A digital button requests
//  full thrust. Analog input is ignored until activity proves that a source
//  is present.
//============================================================================

module llander_thrust_input
(
	input  logic              clk,
	input  logic              reset,
	input  logic signed [7:0] analog_y,
	input  logic              digital_thrust,
	output logic        [7:0] thrust_level
);

	logic signed [7:0] analog_y_q = 8'sd0;
	logic              digital_thrust_q = 1'b0;
	logic              analog_active_q = 1'b0;
	logic        [8:0] analog_magnitude;
	logic        [9:0] scaled_magnitude;
	logic        [7:0] thrust_target;
	logic       [11:0] track_divider = 12'd0;

	always_comb begin
		analog_magnitude = 9'd0;
		scaled_magnitude = 10'd0;
		thrust_target = 8'd0;

		if (digital_thrust_q) begin
			thrust_target = 8'd254;
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
			analog_y_q <= analog_y;
			digital_thrust_q <= 1'b0;
			analog_active_q <= 1'b0;
			track_divider <= 12'd0;
			thrust_level <= 8'd0;
		end else begin
			analog_y_q <= analog_y;
			digital_thrust_q <= digital_thrust;
			if (analog_y != analog_y_q)
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
