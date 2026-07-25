//============================================================================
//  Atari Asteroids machine
//
//  Written 2026 by Videodr0me
//
//  The 12.096 MHz master clock drives the CPU, DVG, interrupt, watchdog, and
//  audio enables. The address map and RAM arbitration follow the Asteroids
//  main-board schematics.
//============================================================================

module asteroids_core
(
	input  logic        clk_12,
	input  logic        reset,
	input  logic        pause,
	input  logic  [1:0] game_variant,
	input  logic        main_board_audio_filter,
	input  logic        cabinet_audio_model,

	input  logic        coin_left,
	input  logic        coin_center,
	input  logic        coin_right,
	input  logic        slam,
	input  logic        service,
	input  logic        diagnostic_step,
	input  logic        start_1,
	input  logic        start_2,
	input  logic        thrust,
	input  logic  [7:0] thrust_level,
	input  logic        abort,
	input  logic        rotate_right,
	input  logic        rotate_left,
	input  logic        fire,
	input  logic        hyperspace,
	input  logic        cocktail,
	input  logic  [7:0] dsw_1,
	input  logic  [7:0] dsw_2,

	input  logic        rom_write,
	input  logic [15:0] rom_address,
	input  logic  [7:0] rom_data,
	input  logic  [5:0] nvram_address,
	input  logic  [7:0] nvram_data_in,
	input  logic        nvram_write,
	output logic  [7:0] nvram_data_out,
	output logic        nvram_modified,

	output logic signed [15:0] audio,
	output logic [10:0] x_out,
	output logic [10:0] y_out,
	output logic  [7:0] z_out,
	output logic        beam_on,
	output logic        is_dot,
	output logic        frame_done,
	output logic  [4:0] llander_lamps,
	output logic        dvg_halted
);

	localparam logic [1:0] GAME_ASTEROIDS = 2'd0;
	localparam logic [1:0] GAME_DELUXE    = 2'd1;
	localparam logic [1:0] GAME_LLANDER   = 2'd2;

	localparam logic [15:0] ASTEROIDS_VECTOR_BASE = 16'h1800;
	localparam logic [15:0] ASTEROIDS_STATE_BASE  = 16'h2000;
	localparam logic [15:0] DELUXE_VECTOR_BASE    = 16'h2000;
	localparam logic [15:0] DELUXE_STATE_BASE     = 16'h3000;
	localparam logic [15:0] LLANDER_VECTOR_BASE   = 16'h2000;
	localparam logic [15:0] LLANDER_STATE_BASE    = 16'h3800;

	(* ramstyle = "M10K" *) logic [7:0] program_ram [0:1023];
	(* ramstyle = "M10K" *) logic [7:0] program_rom [0:8191];
	(* ramstyle = "M10K" *) logic [7:0] vector_ram  [0:2047];
	(* ramstyle = "M10K" *) logic [7:0] vector_rom  [0:8191];

	logic game_is_asteroids;
	logic game_is_deluxe;
	logic game_is_lander;

	logic [2:0] clock_divider = 3'd0;
	logic [11:0] timer_divider = 12'd0;
	logic [3:0] nmi_divider = 4'd0;
	logic [7:0] watchdog_counter = 8'd0;
	logic [7:0] reset_hold = 8'hff;
	logic [15:0] cpu_cycle_counter = 16'd0;
	logic ce_cpu;
	logic ce_3m;
	logic timer_tick;
	logic machine_reset;
	logic nmi_n = 1'b1;

	logic [15:0] cpu_address;
	logic [14:0] cpu_address_masked;
	logic  [7:0] cpu_data_in;
	logic  [7:0] cpu_data_out;
	logic        cpu_rw_n;
	logic        cpu_write;

	logic [9:0] program_ram_address;
	logic [12:0] program_rom_address;
	logic [12:0] vector_rom_write_address;
	logic  [7:0] program_ram_q;
	logic  [7:0] program_rom_q;

	logic program_ram_select;
	logic program_rom_select;
	logic vector_ram_select;
	logic vector_rom_select;
	logic input_0_select;
	logic input_1_select;
	logic dip_select;
	logic [7:0] board_dsw_1;
	logic pokey_select;
	logic earom_read_select;
	logic earom_latch_write;
	logic earom_control_write;
	logic deluxe_output_write;
	logic llander_thrust_select;
	logic llander_audio_write;
	logic state_rom_write;
	logic vector_rom_write;

	logic [7:0] output_latch = 8'd0;
	logic       ram_select;
	logic       cocktail_flip;
	logic       dvg_go;
	logic       dvg_reset;
	logic       watchdog_clear;
	logic       explosion_write;
	logic       thump_write;
	logic       sound_write;
	logic       noise_reset;
	logic [7:0] pokey_data;
	logic [7:0] pokey_audio;
	logic [7:0] earom_data;

	logic        dvg_memory_request;
	logic [12:0] dvg_memory_address;
	logic        dvg_response_valid = 1'b0;
	logic  [7:0] dvg_response_data = 8'd0;
	logic        dvg_request_pending = 1'b0;
	logic [12:0] dvg_pending_address = 13'd0;
	logic [12:0] vector_port_address = 13'd0;
	logic        vector_port_ram_select;
	logic        vector_port_rom_select;
	logic        vector_port_owner_dvg = 1'b0;
	logic  [7:0] vector_port_q = 8'd0;
	logic        vector_owner_q = 1'b0;
	logic        vector_start;
	logic [11:0] vector_start_x;
	logic [11:0] vector_start_y;
	logic [10:0] vector_duration;
	logic  [9:0] vector_displacement_x;
	logic  [9:0] vector_displacement_y;
	logic        vector_x_negative;
	logic        vector_y_negative;
	logic  [3:0] vector_intensity;
	logic        vector_is_dot;
	logic [10:0] shadow_x;
	logic [10:0] shadow_y;

	assign game_is_asteroids = (game_variant == GAME_ASTEROIDS);
	assign game_is_deluxe = (game_variant == GAME_DELUXE);
	assign game_is_lander = (game_variant == GAME_LLANDER);
	assign ce_cpu = (clock_divider == 3'd0);
	assign ce_3m = (clock_divider[1:0] == 2'b10);
	assign timer_tick = (timer_divider == 12'hfff);
	assign machine_reset = (reset_hold != 8'd0);
	assign cpu_address_masked = cpu_address[14:0];
	assign cpu_write = ce_cpu && !cpu_rw_n;

	assign program_ram_select = game_is_lander
	                          ? (cpu_address_masked < 15'h2000)
	                          : (cpu_address_masked[14:10] == 5'b00000);
	assign program_rom_select = (game_is_deluxe || game_is_lander)
	                          ? (cpu_address_masked >= 15'h6000)
	                          : (cpu_address_masked >= 15'h6800);
	assign vector_ram_select = (cpu_address_masked[14:11] == 4'b1000);
	assign vector_rom_select = game_is_lander
	                         ? ((cpu_address_masked >= 15'h4800) &&
	                            (cpu_address_masked <= 15'h5fff))
	                         : game_is_deluxe
	                         ? ((cpu_address_masked >= 15'h4800) &&
	                            (cpu_address_masked <= 15'h57ff))
	                         : (cpu_address_masked[14:11] == 4'b1010);
	assign input_0_select = game_is_lander
	                      ? (cpu_address_masked == 15'h2000)
	                      : (cpu_address_masked[14:3] == 12'h400);
	assign input_1_select = (cpu_address_masked[14:3] == 12'h480);
	assign dip_select = (cpu_address_masked[14:2] == 13'h0a00);
	// Lunar fuel uses P8 switches 5, 7, and 8 around coinage on switch 6.
	assign board_dsw_1 = game_is_lander
	                   ? {dsw_1[6:4], dsw_1[7], dsw_1[3:0]}
	                   : dsw_1;
	assign llander_thrust_select = game_is_lander &&
	                               (cpu_address_masked == 15'h2c00);
	assign pokey_select = game_is_deluxe &&
	                      (cpu_address_masked[14:4] == 11'h2c0);
	assign earom_read_select = game_is_deluxe &&
	                           (cpu_address_masked >= 15'h2c40) &&
	                           (cpu_address_masked <= 15'h2c7f);

	assign ram_select = game_is_deluxe ? output_latch[4] :
	                    game_is_asteroids ? output_latch[2] : 1'b0;
	assign cocktail_flip = !game_is_lander && cocktail && ram_select;
	assign program_ram_address = game_is_lander
	                           ? {2'b00, cpu_address_masked[7:0]}
	                           : {
	                               cpu_address_masked[9],
	                               cpu_address_masked[8] ^
	                                 (ram_select && cpu_address_masked[9]),
	                               cpu_address_masked[7:0]
	                             };
	assign program_rom_address = (game_is_deluxe || game_is_lander)
	                           ? cpu_address_masked[12:0]
	                           : cpu_address_masked[12:0] - 13'h0800;
	// Downloads are stored at their actual DVG offsets from CPU $4000.
	assign vector_rom_write_address = game_is_asteroids
	                                ? rom_address[12:0] - 13'h0800
	                                : rom_address[12:0] + 13'h0800;
	assign vector_port_ram_select =
		(vector_port_address[12:11] == 2'b00);
	assign vector_port_rom_select = game_is_lander
	                              ? (vector_port_address >= 13'h0800)
	                              : game_is_deluxe
	                              ? ((vector_port_address >= 13'h0800) &&
	                                 (vector_port_address < 13'h1800))
	                              : ((vector_port_address >= 13'h1000) &&
	                                 (vector_port_address < 13'h1800));

	assign dvg_go = cpu_write && (cpu_address_masked == 15'h3000);
	assign dvg_reset = machine_reset ||
	                   (!game_is_lander && cpu_write &&
	                    (cpu_address_masked == 15'h3800));
	assign watchdog_clear = cpu_write && (cpu_address_masked == 15'h3400);
	assign explosion_write = cpu_write && !game_is_lander &&
	                         (cpu_address_masked == 15'h3600);
	assign thump_write = cpu_write && game_is_asteroids &&
	                     (cpu_address_masked == 15'h3a00);
	assign sound_write = cpu_write && game_is_asteroids &&
	                     (cpu_address_masked[14:3] == 12'h780);
	assign llander_audio_write = cpu_write && game_is_lander &&
	                             (cpu_address_masked == 15'h3c00);
	assign earom_latch_write = cpu_write && game_is_deluxe &&
	                           (cpu_address_masked >= 15'h3200) &&
	                           (cpu_address_masked <= 15'h323f);
	assign earom_control_write = cpu_write && game_is_deluxe &&
	                             (cpu_address_masked == 15'h3a00);
	assign deluxe_output_write = cpu_write && game_is_deluxe &&
	                             (cpu_address_masked[14:3] == 12'h780);
	assign noise_reset = cpu_write && (cpu_address_masked == 15'h3e00);
	assign state_rom_write = rom_write &&
	                         (rom_address[15:8] ==
	                          (game_is_lander
	                           ? LLANDER_STATE_BASE[15:8]
	                           : game_is_deluxe
	                           ? DELUXE_STATE_BASE[15:8]
	                           : ASTEROIDS_STATE_BASE[15:8]));
	assign vector_rom_write = rom_write &&
	                          (game_is_lander
	                           ? ((rom_address >= LLANDER_VECTOR_BASE) &&
	                              (rom_address < LLANDER_STATE_BASE))
	                           : game_is_deluxe
	                           ? ((rom_address >= DELUXE_VECTOR_BASE) &&
	                              (rom_address < DELUXE_STATE_BASE))
	                           : ((rom_address >= ASTEROIDS_VECTOR_BASE) &&
	                              (rom_address < ASTEROIDS_STATE_BASE)));

	function automatic logic selected_input_0(input logic [2:0] offset);
		begin
			case (offset)
				3'd0: selected_input_0 = 1'b0;
				3'd1: selected_input_0 = cpu_cycle_counter[8];
				3'd2: selected_input_0 = !dvg_halted;
				3'd3: selected_input_0 = hyperspace;
				3'd4: selected_input_0 = fire;
				3'd5: selected_input_0 = diagnostic_step;
				3'd6: selected_input_0 = slam;
				default: selected_input_0 = service;
			endcase
		end
	endfunction

	function automatic logic selected_input_1(input logic [2:0] offset);
		begin
			if (game_is_lander) begin
				case (offset)
					3'd0: selected_input_1 = start_1;
					3'd1: selected_input_1 = !coin_left;
					3'd2: selected_input_1 = coin_center;
					3'd3: selected_input_1 = !coin_right;
					3'd4: selected_input_1 = start_2;
					3'd5: selected_input_1 = abort;
					3'd6: selected_input_1 = rotate_right;
					default: selected_input_1 = rotate_left;
				endcase
			end else begin
				case (offset)
					3'd0: selected_input_1 = coin_left;
					3'd1: selected_input_1 = coin_center;
					3'd2: selected_input_1 = coin_right;
					3'd3: selected_input_1 = start_1;
					3'd4: selected_input_1 = start_2;
					3'd5: selected_input_1 = thrust;
					3'd6: selected_input_1 = rotate_right;
					default: selected_input_1 = rotate_left;
				endcase
			end
		end
	endfunction

	function automatic logic [1:0] selected_dip(
		input logic [7:0] switches,
		input logic [1:0] offset
	);
		begin
			case (offset)
				2'd0: selected_dip = switches[7:6];
				2'd1: selected_dip = switches[5:4];
				2'd2: selected_dip = switches[3:2];
				default: selected_dip = switches[1:0];
			endcase
		end
	endfunction

	always_comb begin
		cpu_data_in = 8'hff;
		if (input_0_select) begin
			if (game_is_lander)
				cpu_data_in = {
					!diagnostic_step,
					cpu_cycle_counter[8],
					3'b111,
					!slam,
					!service,
					dvg_halted
				};
			else
				cpu_data_in = selected_input_0(cpu_address_masked[2:0])
				            ? 8'h80 : 8'h7f;
		end
		else if (input_1_select)
			cpu_data_in = selected_input_1(cpu_address_masked[2:0])
			            ? 8'h80 : 8'h7f;
		else if (dip_select)
			cpu_data_in = {
				6'b111111,
				selected_dip(board_dsw_1, cpu_address_masked[1:0])
			};
		else if (llander_thrust_select)
			cpu_data_in = thrust_level;
		else if (pokey_select)
			cpu_data_in = pokey_data;
		else if (earom_read_select)
			cpu_data_in = earom_data;
		else if (program_ram_select)
			cpu_data_in = program_ram_q;
		else if (vector_ram_select || vector_rom_select)
			cpu_data_in = vector_port_q;
		else if (program_rom_select)
			cpu_data_in = program_rom_q;
	end

	always_ff @(posedge clk_12) begin
		clock_divider <= clock_divider + 1'b1;

		if (reset || machine_reset) begin
			timer_divider <= 12'd0;
			cpu_cycle_counter <= 16'd0;
		end else begin
			timer_divider <= timer_divider + 1'b1;
			if (ce_cpu)
				cpu_cycle_counter <= cpu_cycle_counter + 1'b1;
		end

		if (reset)
			reset_hold <= 8'hff;
		else if (!pause && timer_tick && (watchdog_counter == 8'hff))
			reset_hold <= 8'hff;
		else if (reset_hold != 8'd0)
			reset_hold <= reset_hold - 1'b1;

		if (machine_reset || pause || watchdog_clear)
			watchdog_counter <= 8'd0;
		else if (timer_tick)
			watchdog_counter <= watchdog_counter + 1'b1;

		if (machine_reset || service) begin
			nmi_divider <= 4'd0;
			nmi_n <= 1'b1;
		end else begin
			if (timer_tick) begin
				if (nmi_divider == 4'd11) begin
					nmi_divider <= 4'd0;
					nmi_n <= 1'b0;
				end else begin
					nmi_divider <= nmi_divider + 1'b1;
				end
			end else if (ce_cpu && !nmi_n) begin
				nmi_n <= 1'b1;
			end
		end

		program_ram_q <= program_ram[program_ram_address];
		if (program_rom_select)
			program_rom_q <= program_rom[program_rom_address];
		if (cpu_write && program_ram_select)
			program_ram[program_ram_address] <= cpu_data_out;

		if (rom_write &&
		    (rom_address < (game_is_asteroids
		                    ? ASTEROIDS_VECTOR_BASE
		                    : DELUXE_VECTOR_BASE)))
			program_rom[rom_address[12:0]] <= rom_data;
		if (vector_rom_write)
			vector_rom[vector_rom_write_address] <= rom_data;

		if (vector_port_ram_select)
			vector_port_q <= vector_ram[vector_port_address[10:0]];
		else if (vector_port_rom_select)
			vector_port_q <= vector_rom[vector_port_address];
		else
			vector_port_q <= 8'hff;
		vector_owner_q <= vector_port_owner_dvg;
		dvg_response_data <= vector_port_q;
		dvg_response_valid <= vector_owner_q;

		if (machine_reset) begin
			dvg_request_pending <= 1'b0;
			vector_port_address <= 13'd0;
			vector_port_owner_dvg <= 1'b0;
			vector_owner_q <= 1'b0;
			dvg_response_valid <= 1'b0;
		end else if (dvg_memory_request) begin
			dvg_request_pending <= 1'b1;
			dvg_pending_address <= dvg_memory_address;
		end

		if (machine_reset) begin
			vector_port_address <= 13'd0;
			vector_port_owner_dvg <= 1'b0;
		end else if (vector_ram_select || vector_rom_select) begin
			vector_port_address <= cpu_address_masked[12:0];
			vector_port_owner_dvg <= 1'b0;
		end else if (dvg_request_pending) begin
			vector_port_address <= dvg_pending_address;
			vector_port_owner_dvg <= 1'b1;
			dvg_request_pending <= 1'b0;
		end else begin
			vector_port_owner_dvg <= 1'b0;
		end

		if (cpu_write && vector_ram_select)
			vector_ram[cpu_address_masked[10:0]] <= cpu_data_out;

		if (machine_reset)
			output_latch <= 8'd0;
		else if (cpu_write && !game_is_deluxe &&
		         (cpu_address_masked == 15'h3200))
			output_latch <= cpu_data_out;
		else if (deluxe_output_write)
			output_latch[cpu_address_masked[2:0]] <= cpu_data_out[7];
	end

	asteroids_cpu cpu
	(
		.clk(clk_12),
		.reset_n(!machine_reset),
		.enable(ce_cpu),
		.ready(!pause),
		.irq_n(1'b1),
		.nmi_n(nmi_n),
		.data_in(cpu_data_in),
		.address(cpu_address),
		.data_out(cpu_data_out),
		.rw_n(cpu_rw_n),
		.sync()
	);

	asteroids_dvg dvg
	(
		.clk(clk_12),
		.reset(machine_reset),
		.ce_1p5(ce_cpu),
		.go(dvg_go),
		.dvg_reset(dvg_reset),
		.memory_request(dvg_memory_request),
		.memory_address(dvg_memory_address),
		.memory_response_valid(dvg_response_valid),
		.memory_response_data(dvg_response_data),
		.prom_write(state_rom_write),
		.prom_address(rom_address[7:0]),
		.prom_data(rom_data[3:0]),
		.x_out(),
		.y_out(),
		.z_out(),
		.beam_on(),
		.is_dot(),
		.vector_start(vector_start),
		.vector_start_x(vector_start_x),
		.vector_start_y(vector_start_y),
		.vector_duration(vector_duration),
		.vector_displacement_x(vector_displacement_x),
		.vector_displacement_y(vector_displacement_y),
		.vector_x_negative(vector_x_negative),
		.vector_y_negative(vector_y_negative),
		.vector_intensity(vector_intensity),
		.vector_is_dot(vector_is_dot),
		.halted(dvg_halted),
		.frame_done(frame_done)
	);

	asteroids_dvg_shadow shadow_dvg
	(
		.clk(clk_12),
		.reset(dvg_reset || dvg_go),
		.ce_3m(ce_3m),
		.vector_start(vector_start),
		.vector_start_x(vector_start_x),
		.vector_start_y(vector_start_y),
		.vector_duration(vector_duration),
		.vector_displacement_x(vector_displacement_x),
		.vector_displacement_y(vector_displacement_y),
		.vector_x_negative(vector_x_negative),
		.vector_y_negative(vector_y_negative),
		.vector_intensity(vector_intensity),
		.vector_is_dot(vector_is_dot),
		.x_out(shadow_x),
		.y_out(shadow_y),
		.z_out(z_out),
		.beam_on(beam_on),
		.is_dot(is_dot),
		.busy()
	);

	asteroids_audio sound
	(
		.clk(clk_12),
		.reset(machine_reset),
		.pause(pause),
		.deluxe_mode(game_is_deluxe),
		.llander_mode(game_is_lander),
		.deluxe_thrust_enable(output_latch[3]),
		.pokey_ce(ce_cpu),
		.pokey_audio(pokey_audio),
		.main_board_filter(main_board_audio_filter),
		.cabinet_model(cabinet_audio_model),
		.explosion_write(explosion_write),
		.explosion_data(cpu_data_out),
		.thump_write(thump_write),
		.thump_data(cpu_data_out),
		.sound_write(sound_write),
		.sound_address(cpu_address_masked[2:0]),
		.sound_data(cpu_data_out[7]),
		.llander_write(llander_audio_write),
		.llander_data(cpu_data_out[5:0]),
		.noise_reset(noise_reset),
		.audio(audio)
	);

	assign x_out = cocktail_flip ? (11'd2047 - shadow_x) : shadow_x;
	assign y_out = cocktail_flip ? (11'd2047 - shadow_y) : shadow_y;
	assign llander_lamps = game_is_lander ? output_latch[4:0] : 5'd0;

	pokey pokey_inst
	(
		.ADDR(cpu_address_masked[3:0]),
		.DIN(cpu_data_out),
		.DOUT(pokey_data),
		.DOUT_OE_L(),
		.RW_L(cpu_rw_n),
		.CS(1'b1),
		.CS_L(!pokey_select),
		.AUDIO_OUT(pokey_audio),
		.PIN(~dsw_2),
		.ENA(ce_cpu && !pause),
		.CLK(clk_12)
	);

	atari_er2055 earom
	(
		.clk(clk_12),
		.reset(machine_reset),
		.latch_write(earom_latch_write),
		.latch_address(cpu_address_masked[5:0]),
		.latch_data(cpu_data_out),
		.control_write(earom_control_write),
		.control_data(cpu_data_out[3:0]),
		.data_out(earom_data),
		.modified(nvram_modified),
		.host_address(nvram_address),
		.host_data_in(nvram_data_in),
		.host_write(nvram_write),
		.host_data_out(nvram_data_out)
	);

endmodule
