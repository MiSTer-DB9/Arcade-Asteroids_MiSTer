//============================================================================
//  Atari Asteroids main-board audio circuits
//
//  Written 2026 by Videodr0me
//
//  Recreates the seven discrete sound sources and the LM324 summing stage.
//============================================================================

module asteroids_audio_board
(
	input  logic               clk,
	input  logic               reset,
	input  logic               enable,
	input  logic               sample_ce,
	input  logic               filter_enable,
	input  logic               deluxe_mode,
	input  logic         [5:0] sound_enable,
	input  logic         [1:0] explosion_pitch,
	input  logic         [3:0] explosion_level,
	input  logic         [3:0] thump_frequency,
	input  logic               thump_enable,
	input  logic               noise_reset,
	output logic               sample_valid,
	output logic signed [15:0] sample
);

	// NCO increments use 2^32 phase units at the 48 kHz sample rate.
	localparam logic [31:0] HZ_PHASE_STEP = 32'd89478;
	localparam logic [31:0] SAUCER_BASE_SMALL = 32'd67108864;
	localparam logic [31:0] SAUCER_BASE_LARGE = 32'd44739243;
	localparam logic [31:0] WARBLE_STEP_SMALL = 32'd738198;
	localparam logic [31:0] WARBLE_STEP_LARGE = 32'd514501;
	localparam logic [31:0] SHIP_FIRE_START = 32'd73372358;
	localparam logic [31:0] SHIP_FIRE_END = 32'd9842633;
	localparam logic [31:0] SHIP_FIRE_DECAY = 32'd4727;
	localparam logic [31:0] SAUCER_FIRE_START = 32'd74267143;
	localparam logic [31:0] SAUCER_FIRE_END = 32'd56371446;
	localparam logic [31:0] SAUCER_FIRE_DECAY = 32'd1332;

	// Filter and state-variable coefficients are signed Q1.15 values.
	localparam logic signed [17:0] ALPHA_THUMP = 18'sd2005;
	localparam logic signed [17:0] ALPHA_SAUCER = 18'sd28688;
	localparam logic signed [17:0] ALPHA_SHIP_FIRE = 18'sd28688;
	localparam logic signed [17:0] ALPHA_SAUCER_FIRE = 18'sd21205;
	localparam logic signed [17:0] ALPHA_EXPLOSION = 18'sd224;
	localparam logic signed [17:0] ALPHA_THRUST_INPUT = 18'sd309;
	localparam logic signed [17:0] THRUST_SVF_F = 18'sd384;
	localparam logic signed [17:0] THRUST_SVF_DAMPING = 18'sd4312;
	localparam logic signed [17:0] ALPHA_THRUST_OUTPUT = 18'sd679;

	// Relative gains follow the seven input resistors of the LM324 mixer.
	localparam logic signed [17:0] MIX_THUMP = 18'sd132;
	localparam logic signed [17:0] MIX_SAUCER = 18'sd76;
	localparam logic signed [17:0] MIX_LIFE = 18'sd100;
	localparam logic signed [17:0] MIX_SAUCER_FIRE = 18'sd50;
	localparam logic signed [17:0] MIX_SHIP_FIRE = 18'sd53;
	localparam logic signed [17:0] MIX_EXPLOSION = 18'sd1000;
	localparam logic signed [17:0] MIX_THRUST_ASTEROIDS = 18'sd600;
	// Deluxe uses 3.3 kOhm instead of 4.7 kOhm at the summing input.
	localparam logic signed [17:0] MIX_THRUST_DELUXE = 18'sd855;

	typedef enum logic [4:0]
	{
		ST_IDLE,
		ST_SAUCER_INCREMENT,
		ST_FILTER_THUMP,
		ST_FILTER_SAUCER,
		ST_FILTER_SHIP_FIRE,
		ST_FILTER_SAUCER_FIRE,
		ST_FILTER_EXPLOSION,
		ST_THRUST_INPUT,
		ST_THRUST_LOW,
		ST_THRUST_HIGH,
		ST_THRUST_BAND,
		ST_FILTER_THRUST,
		ST_MIX_THUMP,
		ST_MIX_SAUCER,
		ST_MIX_LIFE,
		ST_MIX_SAUCER_FIRE,
		ST_MIX_SHIP_FIRE,
		ST_MIX_EXPLOSION,
		ST_MIX_THRUST,
		ST_OUTPUT
	} engine_state_t;

	engine_state_t state = ST_IDLE;

	logic [9:0] noise_divider = 10'd0;
	logic [11:0] life_divider = 12'd0;
	logic signed [8:0] life_integral = 9'sd0;
	logic signed [8:0] life_contribution;
	logic signed [8:0] life_integral_next;
	logic signed [16:0] life_integral_extended;
	logic signed [16:0] life_decimated;
	logic [15:0] noise_lfsr = 16'd0;
	logic        noise_bit = 1'b0;
	logic [3:0] explosion_divider = 4'd0;
	logic       explosion_noise = 1'b0;

	logic [31:0] thump_phase = 32'd0;
	logic [31:0] warble_phase = 32'd0;
	logic [31:0] saucer_phase = 32'd0;
	logic [31:0] saucer_increment = SAUCER_BASE_SMALL;
	logic  [9:0] warble_frequency = 10'd0;
	logic [31:0] ship_fire_phase = 32'd0;
	logic [31:0] ship_fire_increment = SHIP_FIRE_START;
	logic [23:0] ship_fire_envelope = 24'd8388352;
	logic [31:0] saucer_fire_phase = 32'd0;
	logic [31:0] saucer_fire_increment = SAUCER_FIRE_START;
	logic [23:0] saucer_fire_envelope = 24'd8388352;
	logic  [5:0] sound_enable_previous = 6'd0;
	logic signed [17:0] thrust_mix_gain_q = MIX_THRUST_ASTEROIDS;

	logic signed [23:0] thump_raw = 24'sd0;
	logic signed [23:0] saucer_raw = 24'sd0;
	logic signed [23:0] life_raw = 24'sd0;
	logic signed [23:0] ship_fire_raw = 24'sd0;
	logic signed [23:0] saucer_fire_raw = 24'sd0;
	logic signed [23:0] explosion_raw = 24'sd0;
	logic signed [23:0] thrust_raw = 24'sd0;

	logic signed [23:0] thump_filtered = 24'sd0;
	logic signed [23:0] saucer_filtered = 24'sd0;
	logic signed [23:0] ship_fire_filtered = 24'sd0;
	logic signed [23:0] saucer_fire_filtered = 24'sd0;
	logic signed [23:0] explosion_filtered = 24'sd0;
	logic signed [23:0] thrust_input_filtered = 24'sd0;
	logic signed [23:0] thrust_low = 24'sd0;
	logic signed [23:0] thrust_band = 24'sd0;
	logic signed [23:0] thrust_high = 24'sd0;
	logic signed [23:0] thrust_filtered = 24'sd0;

	logic signed [23:0] mac_value;
	logic signed [17:0] mac_coefficient;
	logic signed [41:0] mac_product;
	logic signed [23:0] mac_q15_result;
	logic signed [41:0] mix_accumulator = 42'sd0;
	logic signed [41:0] mix_complete;
	logic signed [31:0] mix_base;
	logic signed [31:0] mix_scaled;
	logic signed [15:0] saucer_triangle;
	logic        [15:0] explosion_level_amplitude;

	// Nominal 555/DAC frequencies from the Asteroids board schematic.
	function automatic logic [31:0] thump_phase_step(input logic [3:0] value);
		begin
			case (value)
				4'h0: thump_phase_step = 32'd7303010;
				4'h1: thump_phase_step = 32'd7506944;
				4'h2: thump_phase_step = 32'd7680761;
				4'h3: thump_phase_step = 32'd7772623;
				4'h4: thump_phase_step = 32'd7828049;
				4'h5: thump_phase_step = 32'd7814579;
				4'h6: thump_phase_step = 32'd7747158;
				4'h7: thump_phase_step = 32'd7649847;
				4'h8: thump_phase_step = 32'd7324893;
				4'h9: thump_phase_step = 32'd7117192;
				4'ha: thump_phase_step = 32'd6823102;
				4'hb: thump_phase_step = 32'd6541223;
				4'hc: thump_phase_step = 32'd6063252;
				4'hd: thump_phase_step = 32'd5700083;
				4'he: thump_phase_step = 32'd5221750;
				default: thump_phase_step = 32'd4787984;
			endcase
		end
	endfunction

	function automatic logic [3:0] explosion_reload(input logic [1:0] value);
		begin
			case (value)
				2'b00: explosion_reload = 4'd11;
				2'b01: explosion_reload = 4'd5;
				2'b10: explosion_reload = 4'd2;
				default: explosion_reload = 4'd4;
			endcase
		end
	endfunction

	function automatic logic [15:0] explosion_amplitude(input logic [3:0] value);
		logic [15:0] result;
		begin
			result = 16'd0;
			if (value[0]) result = result + 16'd2121;
			if (value[1]) result = result + 16'd4532;
			if (value[2]) result = result + 16'd8309;
			if (value[3]) result = result + 16'd17805;
			explosion_amplitude = result;
		end
	endfunction

	function automatic logic [9:0] triangle_u10(input logic [31:0] phase);
		begin
			triangle_u10 = phase[31] ? ~phase[30:21] : phase[30:21];
		end
	endfunction

	function automatic logic [9:0] warble_hz(input logic [9:0] position);
		logic [19:0] scaled;
		logic [19:0] rounded;
		begin
			scaled = ({10'd0, position} << 10) -
			         ({10'd0, position} << 6) -
			         ({10'd0, position} << 5) -
			         ({10'd0, position} << 3);
			rounded = scaled + 20'd512;
			warble_hz = rounded[19:10];
		end
	endfunction

	function automatic logic signed [15:0] triangle_q15(input logic [31:0] phase);
		logic [16:0] unsigned_triangle;
		logic signed [16:0] centered_triangle;
		begin
			unsigned_triangle = phase[31]
			                  ? {1'b0, ~phase[30:15]}
			                  : {1'b0, phase[30:15]};
			centered_triangle = $signed(unsigned_triangle) - 17'sd32768;
			triangle_q15 = centered_triangle[15:0];
		end
	endfunction

	function automatic logic [7:0] ship_fire_duty(input logic [31:0] increment);
		begin
			// The schematic gives an approximate duty cycle of 67% + 2250/frequency.
			if      (increment >= 32'd67108864) ship_fire_duty = 8'd179;
			else if (increment >= 32'd58161015) ship_fire_duty = 8'd180;
			else if (increment >= 32'd49213167) ship_fire_duty = 8'd181;
			else if (increment >= 32'd40265318) ship_fire_duty = 8'd183;
			else if (increment >= 32'd31317470) ship_fire_duty = 8'd186;
			else if (increment >= 32'd24606583) ship_fire_duty = 8'd190;
			else if (increment >= 32'd20132659) ship_fire_duty = 8'd195;
			else if (increment >= 32'd15658735) ship_fire_duty = 8'd200;
			else if (increment >= 32'd12526988) ship_fire_duty = 8'd208;
			else if (increment >= 32'd11184811) ship_fire_duty = 8'd215;
			else if (increment >= 32'd10290027) ship_fire_duty = 8'd220;
			else                                     ship_fire_duty = 8'd224;
		end
	endfunction

	function automatic logic [7:0] saucer_fire_duty(input logic [31:0] increment);
		begin
			if      (increment >= 32'd71582788) saucer_fire_duty = 8'd185;
			else if (increment >= 32'd62634940) saucer_fire_duty = 8'd187;
			else                                     saucer_fire_duty = 8'd190;
		end
	endfunction

	function automatic logic signed [15:0] clip16(input logic signed [31:0] value);
		begin
			if (value > 32'sd32767)
				clip16 = 16'sh7fff;
			else if (value < -32'sd32768)
				clip16 = 16'sh8000;
			else
				clip16 = value[15:0];
		end
	endfunction

	assign mac_product = mac_value * mac_coefficient;
	assign mix_complete = mix_accumulator + mac_product;
	assign mac_q15_result = $signed(mac_product[38:15]);
	assign mix_base = $signed(mix_accumulator[41:11]);
	assign mix_scaled = mix_base + (mix_base >>> 4);
	assign saucer_triangle = triangle_q15(saucer_phase);
	assign explosion_level_amplitude = explosion_amplitude(explosion_level);
	assign life_contribution = sound_enable[5]
	                         ? (life_divider[11] ? 9'sd1 : -9'sd1)
	                         : 9'sd0;
	assign life_integral_next = life_integral + life_contribution;
	assign life_integral_extended = {{8{life_integral_next[8]}},
	                                 life_integral_next};
	assign life_decimated = (life_integral_extended <<< 7) +
	                        (life_integral_extended <<< 1);

	always_comb begin
		mac_value = 24'sd0;
		mac_coefficient = 18'sd0;
		case (state)
			ST_SAUCER_INCREMENT: begin
				mac_value = $signed({14'd0, warble_frequency});
				mac_coefficient = $signed(HZ_PHASE_STEP[17:0]);
			end
			ST_FILTER_THUMP: begin
				mac_value = thump_raw - thump_filtered;
				mac_coefficient = ALPHA_THUMP;
			end
			ST_FILTER_SAUCER: begin
				mac_value = saucer_raw - saucer_filtered;
				mac_coefficient = ALPHA_SAUCER;
			end
			ST_FILTER_SHIP_FIRE: begin
				mac_value = ship_fire_raw - ship_fire_filtered;
				mac_coefficient = ALPHA_SHIP_FIRE;
			end
			ST_FILTER_SAUCER_FIRE: begin
				mac_value = saucer_fire_raw - saucer_fire_filtered;
				mac_coefficient = ALPHA_SAUCER_FIRE;
			end
			ST_FILTER_EXPLOSION: begin
				mac_value = explosion_raw - explosion_filtered;
				mac_coefficient = ALPHA_EXPLOSION;
			end
			ST_THRUST_INPUT: begin
				mac_value = thrust_raw - thrust_input_filtered;
				mac_coefficient = ALPHA_THRUST_INPUT;
			end
			ST_THRUST_LOW: begin
				mac_value = thrust_band;
				mac_coefficient = THRUST_SVF_F;
			end
			ST_THRUST_HIGH: begin
				mac_value = thrust_band;
				mac_coefficient = THRUST_SVF_DAMPING;
			end
			ST_THRUST_BAND: begin
				mac_value = thrust_high;
				mac_coefficient = THRUST_SVF_F;
			end
			ST_FILTER_THRUST: begin
				mac_value = thrust_band - thrust_filtered;
				mac_coefficient = ALPHA_THRUST_OUTPUT;
			end
			ST_MIX_THUMP: begin
				mac_value = filter_enable ? thump_filtered : thump_raw;
				mac_coefficient = MIX_THUMP;
			end
			ST_MIX_SAUCER: begin
				mac_value = filter_enable ? saucer_filtered : saucer_raw;
				mac_coefficient = MIX_SAUCER;
			end
			ST_MIX_LIFE: begin
				mac_value = life_raw;
				mac_coefficient = MIX_LIFE;
			end
			ST_MIX_SAUCER_FIRE: begin
				mac_value = filter_enable ? saucer_fire_filtered
				                          : saucer_fire_raw;
				mac_coefficient = MIX_SAUCER_FIRE;
			end
			ST_MIX_SHIP_FIRE: begin
				mac_value = filter_enable ? ship_fire_filtered : ship_fire_raw;
				mac_coefficient = MIX_SHIP_FIRE;
			end
			ST_MIX_EXPLOSION: begin
				mac_value = filter_enable ? explosion_filtered : explosion_raw;
				mac_coefficient = MIX_EXPLOSION;
			end
			ST_MIX_THRUST: begin
				mac_value = filter_enable ? thrust_filtered
				                          : (sound_enable[3] ? thrust_raw : 24'sd0);
				mac_coefficient = thrust_mix_gain_q;
			end
			default: begin
				mac_value = 24'sd0;
				mac_coefficient = 18'sd0;
			end
		endcase
	end

	always_ff @(posedge clk) begin
		if (reset)
			thrust_mix_gain_q <= MIX_THRUST_ASTEROIDS;
		else
			thrust_mix_gain_q <= deluxe_mode ? MIX_THRUST_DELUXE
			                                : MIX_THRUST_ASTEROIDS;
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			noise_divider <= 10'd0;
			life_divider <= 12'd0;
			life_integral <= 9'sd0;
			noise_lfsr <= 16'd0;
			noise_bit <= 1'b0;
			explosion_divider <= 4'd0;
			explosion_noise <= 1'b0;
		end else if (enable) begin
			life_divider <= life_divider + 1'b1;
			life_integral <= sample_ce ? 9'sd0 : life_integral_next;

			if (noise_reset) begin
				noise_divider <= 10'd0;
				noise_lfsr <= 16'd0;
				noise_bit <= 1'b0;
			end else if (noise_divider == 10'd1023) begin
				noise_divider <= 10'd0;
				noise_bit <= ~(noise_lfsr[6] ^ noise_lfsr[14]);
				noise_lfsr <= {noise_lfsr[14:0],
				               ~(noise_lfsr[6] ^ noise_lfsr[14])};

				if (explosion_divider == 4'd0) begin
					explosion_divider <= explosion_reload(explosion_pitch);
					explosion_noise <= ~(noise_lfsr[6] ^ noise_lfsr[14]);
				end else begin
					explosion_divider <= explosion_divider - 1'b1;
				end
			end else begin
				noise_divider <= noise_divider + 1'b1;
			end
		end
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			state <= ST_IDLE;
			sample_valid <= 1'b0;
			sample <= 16'sd0;
			thump_phase <= 32'd0;
			warble_phase <= 32'd0;
			saucer_phase <= 32'd0;
			saucer_increment <= SAUCER_BASE_SMALL;
			warble_frequency <= 10'd0;
			ship_fire_phase <= 32'd0;
			ship_fire_increment <= SHIP_FIRE_START;
			ship_fire_envelope <= 24'd8388352;
			saucer_fire_phase <= 32'd0;
			saucer_fire_increment <= SAUCER_FIRE_START;
			saucer_fire_envelope <= 24'd8388352;
			sound_enable_previous <= 6'd0;
			thump_raw <= 24'sd0;
			saucer_raw <= 24'sd0;
			life_raw <= 24'sd0;
			ship_fire_raw <= 24'sd0;
			saucer_fire_raw <= 24'sd0;
			explosion_raw <= 24'sd0;
			thrust_raw <= 24'sd0;
			thump_filtered <= 24'sd0;
			saucer_filtered <= 24'sd0;
			ship_fire_filtered <= 24'sd0;
			saucer_fire_filtered <= 24'sd0;
			explosion_filtered <= 24'sd0;
			thrust_input_filtered <= 24'sd0;
			thrust_low <= 24'sd0;
			thrust_band <= 24'sd0;
			thrust_high <= 24'sd0;
			thrust_filtered <= 24'sd0;
			mix_accumulator <= 42'sd0;
		end else begin
			sample_valid <= 1'b0;

			if (enable && sample_ce) begin
				sound_enable_previous <= sound_enable;
				warble_frequency <= warble_hz(triangle_u10(warble_phase));

				if (thump_enable) begin
					thump_raw <= thump_phase[31] ? 24'sd32767 : -24'sd32768;
					thump_phase <= thump_phase + thump_phase_step(thump_frequency);
				end else begin
					thump_raw <= 24'sd0;
					thump_phase <= 32'd0;
				end

				if (sound_enable[0]) begin
					saucer_raw <= {{8{saucer_triangle[15]}}, saucer_triangle};
					saucer_phase <= saucer_phase + saucer_increment;
					warble_phase <= warble_phase +
					                 (sound_enable[2] ? WARBLE_STEP_LARGE
					                                  : WARBLE_STEP_SMALL);
				end else begin
					saucer_raw <= 24'sd0;
					saucer_phase <= 32'd0;
					warble_phase <= 32'd0;
				end

				life_raw <= {{7{life_decimated[16]}}, life_decimated};

				if (!sound_enable[4]) begin
					ship_fire_raw <= 24'sd0;
					ship_fire_phase <= 32'd0;
					ship_fire_increment <= SHIP_FIRE_START;
					ship_fire_envelope <= 24'd8388352;
				end else if (!sound_enable_previous[4]) begin
					ship_fire_raw <= 24'sd32767;
					ship_fire_phase <= SHIP_FIRE_START;
					ship_fire_increment <= SHIP_FIRE_START;
					ship_fire_envelope <= 24'd8388352;
				end else begin
					ship_fire_raw <= (ship_fire_phase[31:24] <
					                  ship_fire_duty(ship_fire_increment))
					               ? $signed({8'd0, ship_fire_envelope[23:8]})
					               : -$signed({8'd0, ship_fire_envelope[23:8]});
					ship_fire_phase <= ship_fire_phase + ship_fire_increment;
					if (ship_fire_increment > SHIP_FIRE_END + SHIP_FIRE_DECAY)
						ship_fire_increment <= ship_fire_increment - SHIP_FIRE_DECAY;
					else
						ship_fire_increment <= SHIP_FIRE_END;
					if (ship_fire_envelope > (24'd4327 << 8) +
					    (ship_fire_envelope >> 12) +
					    (ship_fire_envelope >> 16))
						ship_fire_envelope <= ship_fire_envelope -
						                      (ship_fire_envelope >> 12) -
						                      (ship_fire_envelope >> 16);
					else
						ship_fire_envelope <= 24'd4327 << 8;
				end

				if (!sound_enable[1]) begin
					saucer_fire_raw <= 24'sd0;
					saucer_fire_phase <= 32'd0;
					saucer_fire_increment <= SAUCER_FIRE_START;
					saucer_fire_envelope <= 24'd8388352;
				end else if (!sound_enable_previous[1]) begin
					saucer_fire_raw <= 24'sd32767;
					saucer_fire_phase <= SAUCER_FIRE_START;
					saucer_fire_increment <= SAUCER_FIRE_START;
					saucer_fire_envelope <= 24'd8388352;
				end else begin
					saucer_fire_raw <= (saucer_fire_phase[31:24] <
					                    saucer_fire_duty(saucer_fire_increment))
					                 ? $signed({8'd0, saucer_fire_envelope[23:8]})
					                 : -$signed({8'd0, saucer_fire_envelope[23:8]});
					saucer_fire_phase <= saucer_fire_phase + saucer_fire_increment;
					if (saucer_fire_increment > SAUCER_FIRE_END + SAUCER_FIRE_DECAY)
						saucer_fire_increment <= saucer_fire_increment - SAUCER_FIRE_DECAY;
					else
						saucer_fire_increment <= SAUCER_FIRE_END;
					if (saucer_fire_envelope > (24'd4634 << 8) +
					    (saucer_fire_envelope >> 14) +
					    (saucer_fire_envelope >> 17))
						saucer_fire_envelope <= saucer_fire_envelope -
						                        (saucer_fire_envelope >> 14) -
						                        (saucer_fire_envelope >> 17);
					else
						saucer_fire_envelope <= 24'd4634 << 8;
				end

				if (explosion_level == 4'd0)
					explosion_raw <= 24'sd0;
				else if (explosion_noise)
					explosion_raw <= $signed({8'd0, explosion_level_amplitude});
				else
					explosion_raw <= -$signed({8'd0, explosion_level_amplitude});

				thrust_raw <= noise_bit ? 24'sd32767 : -24'sd32768;
				state <= ST_SAUCER_INCREMENT;
			end else if (enable) begin
				case (state)
					ST_SAUCER_INCREMENT: begin
						saucer_increment <=
							(sound_enable[2] ? SAUCER_BASE_LARGE
							                 : SAUCER_BASE_SMALL) + mac_product[31:0];
						state <= ST_FILTER_THUMP;
					end
					ST_FILTER_THUMP: begin
						thump_filtered <= thump_filtered + mac_q15_result;
						state <= ST_FILTER_SAUCER;
					end
					ST_FILTER_SAUCER: begin
						saucer_filtered <= saucer_filtered + mac_q15_result;
						state <= ST_FILTER_SHIP_FIRE;
					end
					ST_FILTER_SHIP_FIRE: begin
						ship_fire_filtered <= ship_fire_filtered + mac_q15_result;
						state <= ST_FILTER_SAUCER_FIRE;
					end
					ST_FILTER_SAUCER_FIRE: begin
						saucer_fire_filtered <= saucer_fire_filtered + mac_q15_result;
						state <= ST_FILTER_EXPLOSION;
					end
					ST_FILTER_EXPLOSION: begin
						explosion_filtered <= explosion_filtered + mac_q15_result;
						state <= ST_THRUST_INPUT;
					end
					ST_THRUST_INPUT: begin
						thrust_input_filtered <= thrust_input_filtered + mac_q15_result;
						state <= ST_THRUST_LOW;
					end
					ST_THRUST_LOW: begin
						thrust_low <= thrust_low + mac_q15_result;
						state <= ST_THRUST_HIGH;
					end
					ST_THRUST_HIGH: begin
						thrust_high <= (sound_enable[3]
						                ? thrust_input_filtered : 24'sd0) -
						               thrust_low - mac_q15_result;
						state <= ST_THRUST_BAND;
					end
					ST_THRUST_BAND: begin
						thrust_band <= thrust_band + mac_q15_result;
						state <= ST_FILTER_THRUST;
					end
					ST_FILTER_THRUST: begin
						thrust_filtered <= thrust_filtered + mac_q15_result;
						state <= ST_MIX_THUMP;
					end
					ST_MIX_THUMP: begin
						mix_accumulator <= mac_product;
						state <= ST_MIX_SAUCER;
					end
					ST_MIX_SAUCER: begin
						mix_accumulator <= mix_accumulator + mac_product;
						state <= ST_MIX_LIFE;
					end
					ST_MIX_LIFE: begin
						mix_accumulator <= mix_accumulator + mac_product;
						state <= ST_MIX_SAUCER_FIRE;
					end
					ST_MIX_SAUCER_FIRE: begin
						mix_accumulator <= mix_accumulator + mac_product;
						state <= ST_MIX_SHIP_FIRE;
					end
					ST_MIX_SHIP_FIRE: begin
						mix_accumulator <= mix_accumulator + mac_product;
						state <= ST_MIX_EXPLOSION;
					end
					ST_MIX_EXPLOSION: begin
						mix_accumulator <= mix_accumulator + mac_product;
						state <= ST_MIX_THRUST;
					end
					ST_MIX_THRUST: begin
						mix_accumulator <= mix_complete;
						state <= ST_OUTPUT;
					end
					ST_OUTPUT: begin
						sample <= clip16(mix_scaled);
						sample_valid <= 1'b1;
						state <= ST_IDLE;
					end
					default: state <= ST_IDLE;
				endcase
			end
		end
	end

endmodule
