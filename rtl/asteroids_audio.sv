//============================================================================
//  Atari Asteroids audio system
//
//  Written 2026 by Videodr0me
//
//  Captures the CPU sound controls, reconstructs the main-board sound
//  circuits, and applies the regulator/audio-board and speaker-load response.
//  All timing remains in the 12.096 MHz master-clock domain.
//============================================================================

module asteroids_audio
(
	input  logic               clk,
	input  logic               reset,
	input  logic               pause,
	input  logic               deluxe_mode,
	input  logic               llander_mode,
	input  logic               deluxe_thrust_enable,
	input  logic               pokey_ce,
	input  logic         [7:0] pokey_audio,
	input  logic               main_board_filter,
	input  logic               cabinet_model,
	input  logic               explosion_write,
	input  logic         [7:0] explosion_data,
	input  logic               thump_write,
	input  logic         [7:0] thump_data,
	input  logic               sound_write,
	input  logic         [2:0] sound_address,
	input  logic               sound_data,
	input  logic               llander_write,
	input  logic         [5:0] llander_data,
	input  logic               noise_reset,
	output logic signed [15:0] audio
);

	logic [7:0] sample_divider = 8'd0;
	logic       sample_ce;

	logic [5:0] sound_enable = 6'd0;
	logic [1:0] explosion_pitch = 2'd0;
	logic [3:0] explosion_level = 4'd0;
	logic [3:0] thump_frequency = 4'd0;
	logic       thump_enable = 1'b0;

	logic               board_sample_valid;
	logic signed [15:0] board_sample;
	logic               llander_sample_valid;
	logic signed [15:0] llander_sample;
	logic               selected_board_valid;
	logic signed [15:0] selected_board_sample;
	logic               cabinet_sample_valid;
	logic signed [15:0] cabinet_sample;
	logic               main_board_filter_q = 1'b1;
	logic               cabinet_model_q = 1'b1;
	logic         [7:0] pokey_filtered;
	logic signed [23:0] pokey_target_q;
	logic signed [23:0] pokey_dc_q = 24'sd0;
	logic signed [23:0] pokey_ac_q = 24'sd0;
	logic signed [24:0] pokey_delta_q;
	logic signed [24:0] pokey_correction_q;
	logic signed [16:0] board_mix_q;
	logic signed [15:0] mixed_board_sample;
	logic         [5:0] llander_control = 6'd0;

	function automatic logic signed [15:0] clip17(
		input logic signed [16:0] value
	);
		begin
			if (value > 17'sd32767)
				clip17 = 16'sh7fff;
			else if (value < -17'sd32768)
				clip17 = 16'sh8000;
			else
				clip17 = value[15:0];
		end
	endfunction

	function automatic logic signed [15:0] gain_3_over_2(
		input logic signed [15:0] value
	);
		logic signed [16:0] extended;
		begin
			extended = $signed({value[15], value});
			gain_3_over_2 = clip17(extended + (extended >>> 1));
		end
	endfunction

	assign sample_ce = !pause && (sample_divider == 8'd251);
	assign pokey_target_q = $signed({1'b0, pokey_filtered, 7'd0});
	assign pokey_delta_q = $signed({pokey_target_q[23], pokey_target_q}) -
	                       $signed({pokey_dc_q[23], pokey_dc_q});
	assign pokey_correction_q = pokey_delta_q >>> 12;
	assign board_mix_q = $signed({board_sample[15], board_sample}) +
	                     $signed(pokey_ac_q[16:0]);
	assign mixed_board_sample = deluxe_mode ? clip17(board_mix_q) : board_sample;
	assign selected_board_valid = llander_mode
	                            ? llander_sample_valid : board_sample_valid;
	assign selected_board_sample = llander_mode
	                             ? llander_sample : mixed_board_sample;

	always_ff @(posedge clk) begin
		if (reset) begin
			sample_divider <= 8'd0;
			sound_enable <= 6'd0;
			explosion_pitch <= 2'd0;
			explosion_level <= 4'd0;
			thump_frequency <= 4'd0;
			thump_enable <= 1'b0;
			llander_control <= 6'd0;
			main_board_filter_q <= 1'b1;
			cabinet_model_q <= 1'b1;
			pokey_dc_q <= 24'sd0;
			pokey_ac_q <= 24'sd0;
			audio <= 16'sd0;
		end else if (pause) begin
			audio <= 16'sd0;
		end else begin
			sample_divider <= sample_ce ? 8'd0 : sample_divider + 1'b1;
			main_board_filter_q <= main_board_filter;
			cabinet_model_q <= cabinet_model;

			if (cabinet_model_q) begin
				if (cabinet_sample_valid)
					audio <= gain_3_over_2(cabinet_sample);
			end else if (selected_board_valid) begin
				audio <= gain_3_over_2(selected_board_sample);
			end

			if (llander_mode) begin
				sound_enable <= 6'd0;
				thump_frequency <= 4'd0;
				thump_enable <= 1'b0;
			end else if (deluxe_mode) begin
				sound_enable <= 6'd0;
				sound_enable[3] <= deluxe_thrust_enable;
				thump_frequency <= 4'd0;
				thump_enable <= 1'b0;
			end else begin
				if (sound_write && (sound_address < 3'd6))
					sound_enable[sound_address] <= sound_data;
				if (thump_write) begin
					thump_frequency <= thump_data[3:0];
					thump_enable <= thump_data[4];
				end
			end

			if (explosion_write) begin
				explosion_pitch <= explosion_data[7:6];
				explosion_level <= explosion_data[5:2];
			end
			if (llander_write)
				llander_control <= llander_data;

			if (sample_ce) begin
				if (deluxe_mode) begin
					pokey_dc_q <= pokey_dc_q +
					              $signed(pokey_correction_q[23:0]);
					pokey_ac_q <= pokey_target_q -
					              (pokey_dc_q +
					               $signed(pokey_correction_q[23:0]));
				end else begin
					pokey_dc_q <= 24'sd0;
					pokey_ac_q <= 24'sd0;
				end
			end
		end
	end

	atari_pokey_filter pokey_filter
	(
		.clk(clk),
		.reset(reset),
		.ce(pokey_ce && !pause),
		.enable(main_board_filter_q),
		.audio_in(pokey_audio),
		.audio_out(pokey_filtered)
	);

	asteroids_audio_board main_board
	(
		.clk(clk),
		.reset(reset),
		.enable(!pause),
		.sample_ce(sample_ce),
		.filter_enable(main_board_filter_q),
		.deluxe_mode(deluxe_mode),
		.sound_enable(sound_enable),
		.explosion_pitch(explosion_pitch),
		.explosion_level(explosion_level),
		.thump_frequency(thump_frequency),
		.thump_enable(thump_enable),
		.noise_reset(noise_reset),
		.sample_valid(board_sample_valid),
		.sample(board_sample)
	);

	llander_audio_board llander_board
	(
		.clk(clk),
		.reset(reset),
		.enable(!pause && llander_mode),
		.sample_ce(sample_ce),
		.filter_enable(main_board_filter_q),
		.control(llander_control),
		.noise_reset(noise_reset),
		.sample_valid(llander_sample_valid),
		.sample(llander_sample)
	);

	asteroids_cabinet_audio cabinet
	(
		.clk(clk),
		.reset(reset),
		.enable(!pause),
		.input_valid(selected_board_valid),
		.input_sample(selected_board_sample),
		.output_valid(cabinet_sample_valid),
		.output_sample(cabinet_sample)
	);

endmodule
