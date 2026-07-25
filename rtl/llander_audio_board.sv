//============================================================================
//  Atari Lunar Lander main-board audio
//
//  Written 2026 by Videodr0me
//
//  Models the 12 kHz noise source, thrust and explosion filters, and the
//  fixed 3 kHz and 6 kHz tones at a 48 kHz output sample rate.
//============================================================================

module llander_audio_board
(
	input  logic               clk,
	input  logic               reset,
	input  logic               enable,
	input  logic               sample_ce,
	input  logic               filter_enable,
	input  logic         [5:0] control,
	input  logic               noise_reset,
	output logic               sample_valid,
	output logic signed [15:0] sample
);

	// Signed Q1.15 coefficients at 48 kHz.
	localparam logic signed [17:0] ALPHA_NOISE_RC = 18'sd302;
	localparam logic signed [17:0] THRUST_SVF_F = 18'sd384;
	localparam logic signed [17:0] THRUST_SVF_DAMPING = 18'sd4312;
	localparam logic signed [17:0] ALPHA_OUTPUT = 18'sd2306;

	typedef enum logic [2:0]
	{
		ST_IDLE,
		ST_NOISE_RC,
		ST_THRUST_LOW,
		ST_THRUST_HIGH,
		ST_THRUST_BAND,
		ST_OUTPUT_FILTER,
		ST_OUTPUT
	} engine_state_t;

	engine_state_t state = ST_IDLE;

	logic [15:0] noise_lfsr = 16'd0;
	logic  [1:0] noise_divider = 2'd0;
	logic  [2:0] tone_3k_divider = 3'd0;
	logic  [1:0] tone_6k_divider = 2'd0;
	logic        tone_3k = 1'b0;
	logic        tone_6k = 1'b0;

	logic signed [23:0] noise_raw = 24'sd0;
	logic signed [23:0] noise_low = 24'sd0;
	logic signed [23:0] thrust_low = 24'sd0;
	logic signed [23:0] thrust_high = 24'sd0;
	logic signed [23:0] thrust_band = 24'sd0;
	logic signed [23:0] output_low = 24'sd0;

	logic signed [23:0] mac_value;
	logic signed [17:0] mac_coefficient;
	logic signed [41:0] mac_product;
	logic signed [23:0] filter_delta;
	logic signed [23:0] filter_next;
	logic signed [23:0] explosion_component;
	logic signed [23:0] filtered_effects;
	logic signed [23:0] tone_component;
	logic signed [25:0] output_sum;

	function automatic logic signed [23:0] noise_level(
		input logic [2:0] level,
		input logic       polarity
	);
		logic signed [23:0] magnitude;
		begin
			case (level)
				3'd0: magnitude = 24'sd0;
				3'd1: magnitude = 24'sd2048;
				3'd2: magnitude = 24'sd4096;
				3'd3: magnitude = 24'sd6144;
				3'd4: magnitude = 24'sd8192;
				3'd5: magnitude = 24'sd10240;
				3'd6: magnitude = 24'sd12288;
				default: magnitude = 24'sd14336;
			endcase
			noise_level = polarity ? magnitude : -magnitude;
		end
	endfunction

	function automatic logic signed [23:0] explosion_gain(
		input logic signed [23:0] value
	);
		begin
			// 1.65625 approximates the schematic's 1000/600 gain ratio.
			explosion_gain = value + (value >>> 1) +
			                 (value >>> 3) + (value >>> 5);
		end
	endfunction

	function automatic logic signed [15:0] clip26(
		input logic signed [25:0] value
	);
		begin
			if (value > 26'sd32767)
				clip26 = 16'sh7fff;
			else if (value < -26'sd32768)
				clip26 = 16'sh8000;
			else
				clip26 = value[15:0];
		end
	endfunction

	assign mac_product = mac_value * mac_coefficient;
	assign filter_delta = $signed(mac_product[38:15]);
	assign explosion_component = control[3]
	                           ? explosion_gain(filter_enable
	                                            ? noise_low : noise_raw)
	                           : 24'sd0;
	assign filtered_effects = filter_enable
	                        ? output_low
	                        : noise_raw + explosion_component;
	assign tone_component =
		(control[4] ? (tone_3k ? 24'sd192 : -24'sd192) : 24'sd0) +
		(control[5] ? (tone_6k ? 24'sd192 : -24'sd192) : 24'sd0);
	assign output_sum = $signed({{2{filtered_effects[23]}}, filtered_effects}) +
	                    $signed({{2{tone_component[23]}}, tone_component});

	always_comb begin
		mac_value = 24'sd0;
		mac_coefficient = 18'sd0;
		filter_next = 24'sd0;

		case (state)
			ST_NOISE_RC: begin
				mac_value = noise_raw - noise_low;
				mac_coefficient = ALPHA_NOISE_RC;
				filter_next = noise_low + filter_delta;
			end
			ST_THRUST_LOW: begin
				mac_value = thrust_band;
				mac_coefficient = THRUST_SVF_F;
				filter_next = thrust_low + filter_delta;
			end
			ST_THRUST_HIGH: begin
				mac_value = thrust_band;
				mac_coefficient = THRUST_SVF_DAMPING;
				filter_next = noise_low - thrust_low - filter_delta;
			end
			ST_THRUST_BAND: begin
				mac_value = thrust_high;
				mac_coefficient = THRUST_SVF_F;
				filter_next = thrust_band + filter_delta;
			end
			ST_OUTPUT_FILTER: begin
				mac_value = thrust_band + explosion_component - output_low;
				mac_coefficient = ALPHA_OUTPUT;
				filter_next = output_low + filter_delta;
			end
			default: begin
				mac_value = 24'sd0;
				mac_coefficient = 18'sd0;
				filter_next = 24'sd0;
			end
		endcase
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			state <= ST_IDLE;
			noise_lfsr <= 16'd0;
			noise_divider <= 2'd0;
			tone_3k_divider <= 3'd0;
			tone_6k_divider <= 2'd0;
			tone_3k <= 1'b0;
			tone_6k <= 1'b0;
			noise_raw <= 24'sd0;
			noise_low <= 24'sd0;
			thrust_low <= 24'sd0;
			thrust_high <= 24'sd0;
			thrust_band <= 24'sd0;
			output_low <= 24'sd0;
			sample_valid <= 1'b0;
			sample <= 16'sd0;
		end else begin
			sample_valid <= 1'b0;

			if (enable) begin
				if (noise_reset) begin
					noise_lfsr <= 16'd0;
					noise_divider <= 2'd0;
				end

				case (state)
					ST_IDLE: begin
						if (sample_ce) begin
							noise_raw <= noise_level(control[2:0],
							                         noise_reset
							                         ? 1'b0
							                         : noise_lfsr[14]);

							if (!noise_reset) begin
								if (noise_divider == 2'd3) begin
									noise_divider <= 2'd0;
									noise_lfsr <= {
										noise_lfsr[14:0],
										~(noise_lfsr[6] ^ noise_lfsr[14])
									};
								end else begin
									noise_divider <= noise_divider + 1'b1;
								end
							end

							if (tone_3k_divider == 3'd7) begin
								tone_3k_divider <= 3'd0;
								tone_3k <= ~tone_3k;
							end else begin
								tone_3k_divider <= tone_3k_divider + 1'b1;
							end

							if (tone_6k_divider == 2'd3) begin
								tone_6k_divider <= 2'd0;
								tone_6k <= ~tone_6k;
							end else begin
								tone_6k_divider <= tone_6k_divider + 1'b1;
							end

							state <= ST_NOISE_RC;
						end
					end
					ST_NOISE_RC: begin
						noise_low <= filter_next;
						state <= ST_THRUST_LOW;
					end
					ST_THRUST_LOW: begin
						thrust_low <= filter_next;
						state <= ST_THRUST_HIGH;
					end
					ST_THRUST_HIGH: begin
						thrust_high <= filter_next;
						state <= ST_THRUST_BAND;
					end
					ST_THRUST_BAND: begin
						thrust_band <= filter_next;
						state <= ST_OUTPUT_FILTER;
					end
					ST_OUTPUT_FILTER: begin
						output_low <= filter_next;
						state <= ST_OUTPUT;
					end
					ST_OUTPUT: begin
						sample <= clip26(output_sum);
						sample_valid <= 1'b1;
						state <= ST_IDLE;
					end
					default: state <= ST_IDLE;
				endcase
			end
		end
	end

endmodule
