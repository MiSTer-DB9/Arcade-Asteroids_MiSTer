//============================================================================
//  Atari vector cabinet audio response
//
//  Written 2026 by Videodr0me
//
//  Models the cabinet amplifier's input, feedback, and 500 uF speaker-coupling
//  networks at 48 kHz.
//============================================================================

module asteroids_cabinet_audio
(
	input  logic               clk,
	input  logic               reset,
	input  logic               enable,
	input  logic               input_valid,
	input  logic signed [15:0] input_sample,
	output logic               output_valid,
	output logic signed [15:0] output_sample
);

	// Filter coefficients are signed Q1.15 values at a 48 kHz sample rate.
	localparam logic signed [17:0] ALPHA_INPUT_COUPLING = 18'sd68;
	localparam logic signed [17:0] ALPHA_AMP_INPUT = 18'sd7;
	localparam logic signed [17:0] ALPHA_AMP_FEEDBACK = 18'sd145;
	localparam logic signed [17:0] AMP_FEEDBACK_RATIO = 18'sd31340;
	localparam logic signed [17:0] ALPHA_SPEAKER_COUPLING = 18'sd170;

	typedef enum logic [2:0]
	{
		ST_IDLE,
		ST_INPUT_COUPLING,
		ST_AMP_INPUT,
		ST_AMP_FEEDBACK,
		ST_AMP_GAIN,
		ST_SPEAKER_COUPLING
	} cabinet_state_t;

	cabinet_state_t state = ST_IDLE;

	logic signed [23:0] input_q = 24'sd0;
	logic signed [23:0] input_coupling_low = 24'sd0;
	logic signed [23:0] amp_input_low = 24'sd0;
	logic signed [23:0] amp_feedback_low = 24'sd0;
	logic signed [23:0] speaker_low = 24'sd0;
	logic signed [23:0] differential_input = 24'sd0;
	logic signed [23:0] coupled_input = 24'sd0;
	logic signed [23:0] amplified = 24'sd0;

	logic signed [23:0] mac_value;
	logic signed [17:0] mac_coefficient;
	logic signed [41:0] mac_product;
	logic signed [23:0] filter_delta;
	logic signed [23:0] filter_next;
	logic signed [23:0] output_next;

	function automatic logic signed [15:0] clip16(input logic signed [23:0] value);
		begin
			if (value > 24'sd32767)
				clip16 = 16'sh7fff;
			else if (value < -24'sd32768)
				clip16 = 16'sh8000;
			else
				clip16 = value[15:0];
		end
	endfunction

	assign mac_product = mac_value * mac_coefficient;
	assign filter_delta = $signed(mac_product[38:15]);

	always_comb begin
		mac_value = 24'sd0;
		mac_coefficient = 18'sd0;
		filter_next = 24'sd0;
		output_next = 24'sd0;

		case (state)
			ST_INPUT_COUPLING: begin
				mac_value = input_q - input_coupling_low;
				mac_coefficient = ALPHA_INPUT_COUPLING;
				filter_next = input_coupling_low + filter_delta;
				output_next = input_q - (filter_next >>> 1);
			end
			ST_AMP_INPUT: begin
				mac_value = differential_input - amp_input_low;
				mac_coefficient = ALPHA_AMP_INPUT;
				filter_next = amp_input_low + filter_delta;
				output_next = differential_input - filter_next;
			end
			ST_AMP_FEEDBACK: begin
				mac_value = coupled_input - amp_feedback_low;
				mac_coefficient = ALPHA_AMP_FEEDBACK;
				filter_next = amp_feedback_low + filter_delta;
			end
			ST_AMP_GAIN: begin
				mac_value = amp_feedback_low;
				mac_coefficient = AMP_FEEDBACK_RATIO;
				output_next = coupled_input - filter_delta;
			end
			ST_SPEAKER_COUPLING: begin
				mac_value = amplified - speaker_low;
				mac_coefficient = ALPHA_SPEAKER_COUPLING;
				filter_next = speaker_low + filter_delta;
				output_next = amplified - filter_next;
			end
			default: begin
				mac_value = 24'sd0;
				mac_coefficient = 18'sd0;
				filter_next = 24'sd0;
				output_next = 24'sd0;
			end
		endcase
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			state <= ST_IDLE;
			output_valid <= 1'b0;
			output_sample <= 16'sd0;
			input_q <= 24'sd0;
			input_coupling_low <= 24'sd0;
			amp_input_low <= 24'sd0;
			amp_feedback_low <= 24'sd0;
			speaker_low <= 24'sd0;
			differential_input <= 24'sd0;
			coupled_input <= 24'sd0;
			amplified <= 24'sd0;
		end else begin
			output_valid <= 1'b0;

			if (enable) begin
				case (state)
				ST_IDLE: begin
					if (input_valid) begin
						input_q <= {{8{input_sample[15]}}, input_sample};
						state <= ST_INPUT_COUPLING;
					end
				end
				ST_INPUT_COUPLING: begin
					input_coupling_low <= filter_next;
					differential_input <= output_next;
					state <= ST_AMP_INPUT;
				end
				ST_AMP_INPUT: begin
					amp_input_low <= filter_next;
					coupled_input <= output_next;
					state <= ST_AMP_FEEDBACK;
				end
				ST_AMP_FEEDBACK: begin
					amp_feedback_low <= filter_next;
					state <= ST_AMP_GAIN;
				end
				ST_AMP_GAIN: begin
					amplified <= output_next;
					state <= ST_SPEAKER_COUPLING;
				end
				ST_SPEAKER_COUPLING: begin
					speaker_low <= filter_next;
					output_sample <= clip16(output_next);
					output_valid <= 1'b1;
					state <= ST_IDLE;
				end
				default: state <= ST_IDLE;
				endcase
			end
		end
	end

endmodule
