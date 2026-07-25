//============================================================================
//  Atari Asteroids Digital Vector Generator
//
//  Written 2026 by Videodr0me
//
//  PROM-driven DVG sequencer with the original cascaded rate-multiplier
//  behavior. Vector-memory requests use a tagged response contract so CPU
//  accesses can retain hardware priority without corrupting a DVG fetch.
//============================================================================

module asteroids_dvg
(
	input  logic        clk,
	input  logic        reset,
	input  logic        ce_1p5,
	input  logic        go,
	input  logic        dvg_reset,

	output logic        memory_request,
	output logic [12:0] memory_address,
	input  logic        memory_response_valid,
	input  logic  [7:0] memory_response_data,

	input  logic        prom_write,
	input  logic  [7:0] prom_address,
	input  logic  [3:0] prom_data,

	output logic  [9:0] x_out,
	output logic  [9:0] y_out,
	output logic  [7:0] z_out,
	output logic        beam_on,
	output logic        is_dot,

	output logic        vector_start,
	output logic [11:0] vector_start_x,
	output logic [11:0] vector_start_y,
	output logic [10:0] vector_duration,
	output logic  [9:0] vector_displacement_x,
	output logic  [9:0] vector_displacement_y,
	output logic        vector_x_negative,
	output logic        vector_y_negative,
	output logic  [3:0] vector_intensity,
	output logic        vector_is_dot,

	output logic        halted,
	output logic        frame_done
);

	logic [3:0] state_prom [0:255];
	logic [3:0] state = 4'd0;
	logic [3:0] opcode = 4'd0;
	logic       halt_flag = 1'b1;

	logic [11:0] pc = 12'd0;
	logic [11:0] stack [0:3];
	logic  [1:0] stack_pointer = 2'd0;
	logic [11:0] delta_x = 12'd0;
	logic [11:0] delta_y = 12'd0;
	logic  [3:0] scale = 4'd0;
	logic  [3:0] intensity = 4'd0;

	logic        fetch_pending = 1'b0;
	logic        response_pending = 1'b0;
	logic  [7:0] response_data = 8'd0;

	logic        draw_active = 1'b0;
	logic [11:0] draw_steps = 12'd0;
	logic [11:0] position_x = 12'd512;
	logic [11:0] position_y = 12'd512;
	logic  [9:0] rate_counter = 10'd0;
	logic  [9:0] magnitude_x = 10'd0;
	logic  [9:0] magnitude_y = 10'd0;
	logic        direction_x_negative = 1'b0;
	logic        direction_y_negative = 1'b0;
	logic        draw_is_dot = 1'b0;

	logic  [7:0] prom_lookup_address;
	logic  [3:0] next_state;
	logic        next_action;
	logic [12:0] next_memory_address;

	function automatic logic rate_pulse
	(
		input logic [9:0] counter,
		input logic [9:0] magnitude
	);
		logic carry;
		integer bit_index;
		begin
			carry = 1'b1;
			rate_pulse = 1'b0;
			for (bit_index = 0; bit_index < 10; bit_index = bit_index + 1) begin
				if (!counter[bit_index] && carry && magnitude[9-bit_index])
					rate_pulse = 1'b1;
				carry = carry && counter[bit_index];
			end
		end
	endfunction

	function automatic logic [11:0] vector_length(input logic [3:0] scale_value);
		begin
			case (scale_value)
				4'd0: vector_length = 12'd2;
				4'd1: vector_length = 12'd4;
				4'd2: vector_length = 12'd8;
				4'd3: vector_length = 12'd16;
				4'd4: vector_length = 12'd32;
				4'd5: vector_length = 12'd64;
				4'd6: vector_length = 12'd128;
				4'd7: vector_length = 12'd256;
				4'd8: vector_length = 12'd512;
				4'd9: vector_length = 12'd1024;
				default: vector_length = 12'd0;
			endcase
		end
	endfunction

	function automatic logic [9:0] vector_displacement
	(
		input logic  [9:0] magnitude,
		input logic [11:0] length
	);
		logic [10:0] extended_magnitude;
		logic [10:0] rounded_displacement;
		begin
			extended_magnitude = {1'b0, magnitude};
			case (length)
				12'd2:    rounded_displacement = (extended_magnitude + 11'd256) >> 9;
				12'd4:    rounded_displacement = (extended_magnitude + 11'd128) >> 8;
				12'd8:    rounded_displacement = (extended_magnitude + 11'd64)  >> 7;
				12'd16:   rounded_displacement = (extended_magnitude + 11'd32)  >> 6;
				12'd32:   rounded_displacement = (extended_magnitude + 11'd16)  >> 5;
				12'd64:   rounded_displacement = (extended_magnitude + 11'd8)   >> 4;
				12'd128:  rounded_displacement = (extended_magnitude + 11'd4)   >> 3;
				12'd256:  rounded_displacement = (extended_magnitude + 11'd2)   >> 2;
				12'd512:  rounded_displacement = (extended_magnitude + 11'd1)   >> 1;
				12'd1024: rounded_displacement = extended_magnitude;
				default:  rounded_displacement = 11'd0;
			endcase
			vector_displacement = rounded_displacement[9:0];
		end
	endfunction

	always_comb begin
		prom_lookup_address = {
			~halt_flag,
			opcode[3] ? opcode[2:0] : 3'b000,
			state
		};
		next_state = state_prom[prom_lookup_address];
		next_action = next_state[3];
		next_memory_address = {pc, next_state[0]};
	end

	always_ff @(posedge clk) begin : dvg_sequencer
		logic [3:0] effective_scale;
		logic [11:0] working_delta_x;
		logic [11:0] working_delta_y;
		logic [11:0] requested_length;
		logic pulse_x;
		logic pulse_y;

		memory_request <= 1'b0;
		frame_done <= 1'b0;
		vector_start <= 1'b0;

		if (prom_write)
			state_prom[prom_address] <= prom_data;

		if (memory_response_valid) begin
			response_data <= memory_response_data;
			response_pending <= 1'b1;
		end

		if (reset || dvg_reset) begin
			memory_address <= 13'd0;
			state <= 4'd0;
			opcode <= 4'd0;
			halt_flag <= 1'b1;
			pc <= 12'd0;
			stack_pointer <= 2'd0;
			delta_x <= 12'd0;
			delta_y <= 12'd0;
			scale <= 4'd0;
			intensity <= 4'd0;
			fetch_pending <= 1'b0;
			response_pending <= 1'b0;
			draw_active <= 1'b0;
			draw_steps <= 12'd0;
			position_x <= 12'd512;
			position_y <= 12'd512;
			rate_counter <= 10'd0;
			magnitude_x <= 10'd0;
			magnitude_y <= 10'd0;
			direction_x_negative <= 1'b0;
			direction_y_negative <= 1'b0;
			draw_is_dot <= 1'b0;
			vector_start_x <= 12'd0;
			vector_start_y <= 12'd0;
			vector_duration <= 11'd0;
			vector_displacement_x <= 10'd0;
			vector_displacement_y <= 10'd0;
			vector_x_negative <= 1'b0;
			vector_y_negative <= 1'b0;
			vector_intensity <= 4'd0;
			vector_is_dot <= 1'b0;
		end else if (go) begin
			// VGGO clears HALT and primes the first DVG instruction fetch.
			halt_flag <= 1'b0;
			opcode <= 4'd0;
			delta_y <= 12'd0;
			fetch_pending <= 1'b0;
			response_pending <= 1'b0;
			draw_active <= 1'b0;
			draw_steps <= 12'd0;
		end else if (ce_1p5) begin
			if (draw_active && (draw_steps != 12'd0)) begin
				pulse_x = rate_pulse(rate_counter, magnitude_x);
				pulse_y = rate_pulse(rate_counter, magnitude_y);

				if (pulse_x)
					position_x <= direction_x_negative ? position_x - 1'b1
					                                           : position_x + 1'b1;
				if (pulse_y)
					position_y <= direction_y_negative ? position_y - 1'b1
					                                           : position_y + 1'b1;

				rate_counter <= rate_counter + 1'b1;
				draw_steps <= draw_steps - 1'b1;
			end else if (!halt_flag) begin
				// The final coordinate was visible throughout the preceding DVG
				// tick. Continue the PROM sequence without an extra idle tick.
				if (draw_active)
					draw_active <= 1'b0;
				if (next_action && !response_pending) begin
					if (!fetch_pending) begin
						memory_address <= next_memory_address;
						memory_request <= 1'b1;
						fetch_pending <= 1'b1;
					end
				end else begin
					state <= next_state;

					if (next_action) begin
						fetch_pending <= 1'b0;
						response_pending <= 1'b0;
					end

					if (next_action) begin
						case (next_state[2:0])
							3'd0: begin
								if (!opcode[0]) begin
									stack_pointer <= stack_pointer + 1'b1;
									stack[stack_pointer + 1'b1] <= pc;
								end
							end

							3'd1: begin
								if (opcode[0]) begin
									pc <= stack[stack_pointer];
									stack_pointer <= stack_pointer - 1'b1;
								end else begin
									pc <= delta_y;
								end
							end

							3'd2: begin
								working_delta_x = delta_x;
								working_delta_y = delta_y;
								if (opcode == 4'hf) begin
									effective_scale = scale + {
										working_delta_x[11],
										~working_delta_x[11],
										working_delta_y[11]
									};
									working_delta_x[7:0] = 8'd0;
									working_delta_y[7:0] = 8'd0;
									delta_x[7:0] <= 8'd0;
									delta_y[7:0] <= 8'd0;
								end else begin
									effective_scale = scale + opcode;
								end

								requested_length = vector_length(effective_scale);
								draw_steps <= requested_length;
								draw_active <= (requested_length != 12'd0);
								rate_counter <= 10'd0;
								magnitude_x <= working_delta_x[9:0];
								magnitude_y <= working_delta_y[9:0];
								direction_x_negative <= working_delta_x[10];
								direction_y_negative <= working_delta_y[10];
								draw_is_dot <= (working_delta_x[9:0] == 10'd0) &&
								               (working_delta_y[9:0] == 10'd0);

								if (requested_length != 12'd0) begin
									vector_start <= 1'b1;
									vector_start_x <= position_x;
									vector_start_y <= position_y;
									vector_duration <= requested_length[10:0];
									vector_displacement_x <= vector_displacement(
										working_delta_x[9:0], requested_length);
									vector_displacement_y <= vector_displacement(
										working_delta_y[9:0], requested_length);
									vector_x_negative <= working_delta_x[10];
									vector_y_negative <= working_delta_y[10];
									vector_intensity <= intensity;
									vector_is_dot <= (working_delta_x[9:0] == 10'd0) &&
									                 (working_delta_y[9:0] == 10'd0);
								end
							end

							3'd3: begin
								halt_flag <= opcode[0];
								if (opcode[0]) begin
									frame_done <= 1'b1;
								end else begin
									position_x <= delta_x;
									position_y <= delta_y;
								end
							end

							3'd4: begin
								delta_y[7:0] <= 8'd0;
								if (opcode == 4'hf) begin
									delta_x[11:8] <= response_data[3:0];
									intensity <= response_data[7:4];
								end else begin
									delta_y[7:0] <= response_data;
								end
								pc <= pc + 1'b1;
							end

							3'd5: begin
								delta_y[11:8] <= response_data[3:0];
								opcode <= response_data[7:4];
								if (response_data[7:4] == 4'hf) begin
									delta_x[7:0] <= 8'd0;
									delta_y[7:0] <= 8'd0;
								end
							end

							3'd6: begin
								delta_x[7:0] <= 8'd0;
								if (opcode != 4'hf)
									delta_x[7:0] <= response_data;
								if (opcode[1] && opcode[3])
									scale <= intensity;
								pc <= pc + 1'b1;
							end

							default: begin
								delta_x[11:8] <= response_data[3:0];
								intensity <= response_data[7:4];
							end
						endcase
					end
				end
			end
		end
	end

	assign x_out = position_x[9:0];
	assign y_out = position_y[9:0];
	assign z_out = {intensity, 4'b0000};
	assign beam_on = draw_active && (intensity != 4'd0) &&
	                 (position_x[11:10] == 2'b00) &&
	                 (position_y[11:10] == 2'b00);
	assign is_dot = draw_is_dot;
	assign halted = halt_flag;

endmodule
