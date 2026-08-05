//============================================================================
//  Asteroids-family spinner input
//
//  Converts spinner and mouse movement into timed left/right presses.
//  A new event restarts the hold interval.
//============================================================================

module asteroids_spinner_input
(
	input  logic       clk,
	input  logic       reset,
	input  logic       pause,
	input  logic       game_is_lander,
	input  logic       spinner_mode,
	input  logic       reverse,
	input  logic [8:0] spinner,
	input  logic [24:0] mouse,
	input  logic       button_right,
	input  logic       button_left,
	output logic       rotate_right,
	output logic       rotate_left
);

	localparam logic [18:0] ASTEROIDS_HOLD_CYCLES = 19'd196608;
	localparam logic [18:0] LLANDER_HOLD_CYCLES   = 19'd294912;

	logic [18:0] hold_count = 19'd0;
	logic        held_right = 1'b0;
	logic        spinner_toggle_q = 1'b0;
	logic        mouse_toggle_q = 1'b0;
	logic signed [9:0] movement_event;

	wire spinner_event = spinner[8] != spinner_toggle_q;
	wire mouse_event = mouse[24] != mouse_toggle_q;

	always_comb begin
		movement_event = 10'sd0;
		if (spinner_event)
			movement_event = movement_event +
				$signed({{2{spinner[7]}}, spinner[7:0]});
		if (mouse_event)
			movement_event = movement_event +
				$signed({mouse[4], mouse[4], mouse[15:8]});
	end

	always_comb begin
		if (spinner_mode) begin
			rotate_right = (hold_count != 19'd0) && held_right;
			rotate_left = (hold_count != 19'd0) && !held_right;
		end else begin
			rotate_right = button_right;
			rotate_left = button_left;
		end
	end

	always_ff @(posedge clk) begin
		spinner_toggle_q <= spinner[8];
		mouse_toggle_q <= mouse[24];

		if (reset || pause || !spinner_mode) begin
			hold_count <= 19'd0;
			held_right <= 1'b0;
		end else if (movement_event != 10'sd0) begin
			hold_count <= game_is_lander
			            ? LLANDER_HOLD_CYCLES : ASTEROIDS_HOLD_CYCLES;
			held_right <= (!movement_event[9]) ^ reverse;
		end else if (hold_count != 19'd0) begin
			hold_count <= hold_count - 1'b1;
		end
	end

endmodule
