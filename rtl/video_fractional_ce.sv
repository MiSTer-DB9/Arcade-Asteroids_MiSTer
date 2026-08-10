//============================================================================
//  Emits numerator/denominator enables per advancing input clock on average.
//  Holding advance preserves the current phase.
//============================================================================

module video_fractional_ce
#(
	parameter int WIDTH = 18
)
(
	input  logic                 clk,
	input  logic                 reset,
	input  logic                 advance,
	input  logic [WIDTH-1:0]     numerator,
	input  logic [WIDTH-1:0]     denominator,
	output logic                 ce
);

	logic [WIDTH-1:0] phase = '0;
	logic [WIDTH:0]   phase_sum;
	logic [WIDTH:0]   phase_wrapped;

	always_comb begin
		phase_sum = {1'b0, phase} + {1'b0, numerator};
		phase_wrapped = phase_sum - {1'b0, denominator};
	end

	always_ff @(posedge clk) begin
		ce <= 1'b0;
		if (reset) begin
			phase <= '0;
		end else if (advance) begin
			if (phase_sum >= {1'b0, denominator}) begin
				phase <= phase_wrapped[WIDTH-1:0];
				ce <= 1'b1;
			end else begin
				phase <= phase_sum[WIDTH-1:0];
			end
		end
	end

endmodule
