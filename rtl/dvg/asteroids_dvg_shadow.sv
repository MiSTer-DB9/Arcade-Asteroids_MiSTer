//============================================================================
//  Atari Asteroids high-resolution DVG presentation
//
//  Written 2026 by Videodr0me
//
//  Re-rasterizes each DVG vector at twice the coordinate and step density
//  without changing PROM timing.
//============================================================================

module asteroids_dvg_shadow
(
	input  logic        clk,
	input  logic        reset,
	input  logic        ce_3m,

	input  logic        vector_start,
	input  logic [11:0] vector_start_x,
	input  logic [11:0] vector_start_y,
	input  logic [10:0] vector_duration,
	input  logic  [9:0] vector_displacement_x,
	input  logic  [9:0] vector_displacement_y,
	input  logic        vector_x_negative,
	input  logic        vector_y_negative,
	input  logic  [3:0] vector_intensity,
	input  logic        vector_is_dot,

	output logic [10:0] x_out,
	output logic [10:0] y_out,
	output logic  [7:0] z_out,
	output logic        beam_on,
	output logic        is_dot,
	output logic        busy
);

	logic [12:0] position_x = 13'd1024;
	logic [12:0] position_y = 13'd1024;
	logic [11:0] period = 12'd0;
	logic [10:0] numerator_x = 11'd0;
	logic [10:0] numerator_y = 11'd0;
	logic [12:0] error_x = 13'd0;
	logic [12:0] error_y = 13'd0;
	logic [11:0] remaining = 12'd0;
	logic        direction_x_negative = 1'b0;
	logic        direction_y_negative = 1'b0;
	logic  [3:0] intensity = 4'd0;
	logic        dot = 1'b0;
	logic        finish_pending = 1'b0;

	always_ff @(posedge clk) begin : shadow_dda
		logic [12:0] sum_x;
		logic [12:0] sum_y;

		if (reset) begin
			position_x <= 13'd1024;
			position_y <= 13'd1024;
			period <= 12'd0;
			numerator_x <= 11'd0;
			numerator_y <= 11'd0;
			error_x <= 13'd0;
			error_y <= 13'd0;
			remaining <= 12'd0;
			direction_x_negative <= 1'b0;
			direction_y_negative <= 1'b0;
			intensity <= 4'd0;
			dot <= 1'b0;
			finish_pending <= 1'b0;
			busy <= 1'b0;
		end else if (vector_start) begin
			position_x <= {vector_start_x, 1'b0};
			position_y <= {vector_start_y, 1'b0};
			period <= {vector_duration, 1'b0};
			numerator_x <= {vector_displacement_x, 1'b0};
			numerator_y <= {vector_displacement_y, 1'b0};
			error_x <= {2'b00, vector_duration};
			error_y <= {2'b00, vector_duration};
			remaining <= {vector_duration, 1'b0};
			direction_x_negative <= vector_x_negative;
			direction_y_negative <= vector_y_negative;
			intensity <= vector_intensity;
			dot <= vector_is_dot;
			finish_pending <= 1'b0;
			busy <= (vector_duration != 11'd0);
		end else if (finish_pending) begin
			finish_pending <= 1'b0;
			busy <= 1'b0;
		end else if (busy && ce_3m) begin
			sum_x = error_x + {2'b00, numerator_x};
			sum_y = error_y + {2'b00, numerator_y};

			if (sum_x >= {1'b0, period}) begin
				error_x <= sum_x - {1'b0, period};
				position_x <= direction_x_negative ? position_x - 13'd1
				                                           : position_x + 13'd1;
			end else begin
				error_x <= sum_x;
			end

			if (sum_y >= {1'b0, period}) begin
				error_y <= sum_y - {1'b0, period};
				position_y <= direction_y_negative ? position_y - 13'd1
				                                           : position_y + 13'd1;
			end else begin
				error_y <= sum_y;
			end

			remaining <= remaining - 12'd1;
			if (remaining == 12'd1)
				finish_pending <= 1'b1;
		end
	end

	assign x_out = position_x[10:0];
	assign y_out = position_y[10:0];
	assign z_out = {intensity, 4'b0000};
	assign beam_on = busy && (intensity != 4'd0) &&
	                 (position_x[12:11] == 2'b00) &&
	                 (position_y[12:11] == 2'b00);
	assign is_dot = dot;

endmodule
