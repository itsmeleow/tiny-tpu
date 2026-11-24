module controller (
	clk,
	rst_n,
	s_axis_tdata,
	s_axis_tvalid,
	s_axis_tready,
	s_axis_tlast,
	m_axis_tvalid,
	m_axis_tready,
	m_axis_tlast,
	ser_done,
	mxu_en,
	weight_load,
	out_fmt,
	vpu_op
);
	reg _sv2v_0;
	parameter DATA_W = 8;
	parameter CNT_W = 4;
	input wire clk;
	input wire rst_n;
	input wire [DATA_W - 1:0] s_axis_tdata;
	input wire s_axis_tvalid;
	output reg s_axis_tready;
	input wire s_axis_tlast;
	output wire m_axis_tvalid;
	input wire m_axis_tready;
	output wire m_axis_tlast;
	input wire ser_done;
	output wire mxu_en;
	output wire weight_load;
	output wire [1:0] out_fmt;
	output wire [2:0] vpu_op;
	reg [2:0] state;
	reg [2:0] next_state;
	wire s_handshake;
	assign s_handshake = s_axis_tvalid && s_axis_tlast;
	reg [DATA_W - 1:0] cmd_reg;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			state <= 3'b000;
			cmd_reg <= 8'b00000000;
		end
		else
			state <= next_state;
		case (state)
			3'b000:
				if (s_handshake)
					cmd_reg <= s_axis_tdata;
			3'b001, 3'b010:
				if (s_handshake)
					cmd_reg <= s_axis_tdata;
			3'b011: cmd_reg <= s_axis_tdata;
			3'b100: cmd_reg <= s_axis_tdata;
			3'b101: cmd_reg <= s_axis_tdata;
			default:
				;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		s_axis_tready = 1'b0;
	end
	initial _sv2v_0 = 0;
endmodule
module fp32_add (
	a,
	b,
	res
);
	reg _sv2v_0;
	localparam fp_pkg_FP32_EXP_WIDTH = 8;
	localparam fp_pkg_FP32_FRA_WIDTH = 23;
	input wire [31:0] a;
	input wire [31:0] b;
	output reg [31:0] res;
	reg sign_result;
	reg [7:0] exponent_a;
	reg [7:0] exponent_b;
	reg [7:0] exponent_diff;
	reg [8:0] exponent_result;
	reg [22:0] fraction_a;
	reg [22:0] fraction_b;
	reg [23:0] mantissa_a;
	reg [23:0] mantissa_b;
	reg [24:0] mantissa_sum;
	always @(*) begin
		if (_sv2v_0)
			;
		exponent_a = a[30:23];
		exponent_b = b[30:23];
		fraction_a = a[22:0];
		fraction_b = b[22:0];
		mantissa_a = {1'b1, fraction_a};
		mantissa_b = {1'b1, fraction_b};
		if (a[30:0] >= b[30:0])
			sign_result = a[31];
		else
			sign_result = b[31];
		if (exponent_a > exponent_b) begin
			exponent_diff = exponent_a - exponent_b;
			mantissa_b = mantissa_b >> exponent_diff;
			exponent_result = {1'b0, exponent_a};
		end
		else begin
			exponent_diff = exponent_b - exponent_a;
			mantissa_a = mantissa_a >> exponent_diff;
			exponent_result = {1'b0, exponent_b};
		end
		if (a[31] == b[31])
			mantissa_sum = {1'b0, mantissa_a} + {1'b0, mantissa_b};
		else if (a[30:0] >= b[30:0])
			mantissa_sum = {1'b0, mantissa_a} - {1'b0, mantissa_b};
		else
			mantissa_sum = {1'b0, mantissa_b} - {1'b0, mantissa_a};
		if (mantissa_sum[24]) begin
			mantissa_sum = mantissa_sum >> 1;
			exponent_result = exponent_result + 9'd1;
		end
		else begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < 23; i = i + 1)
				if ((!mantissa_sum[23] && (mantissa_sum != 25'd0)) && (exponent_result > 9'd1)) begin
					mantissa_sum = mantissa_sum << 1;
					exponent_result = exponent_result - 9'd1;
				end
		end
		if ((a[30:0] == 31'd0) && (b[30:0] == 31'd0))
			res = {a[31] & b[31], 31'd0};
		else if (a[30:0] == 31'd0)
			res = b;
		else if (b[30:0] == 31'd0)
			res = a;
		else if (mantissa_sum == 25'd0)
			res = 32'd0;
		else if (exponent_result >= 9'd255)
			res = {sign_result, 31'h7f800000};
		else if (!mantissa_sum[23])
			res = {sign_result, 31'd0};
		else
			res = {sign_result, exponent_result[7:0], mantissa_sum[22:0]};
	end
	initial _sv2v_0 = 0;
endmodule
module fp32_mul (
	a,
	b,
	res
);
	localparam fp_pkg_FP32_EXP_WIDTH = 8;
	localparam fp_pkg_FP32_FRA_WIDTH = 23;
	input wire [31:0] a;
	input wire [31:0] b;
	output wire [31:0] res;
endmodule
module fp32_to_fp8 (
	in,
	out
);
	localparam fp_pkg_FP32_EXP_WIDTH = 8;
	localparam fp_pkg_FP32_FRA_WIDTH = 23;
	input wire [31:0] in;
	localparam fp_pkg_FP8_EXP_WIDTH = 4;
	localparam fp_pkg_FP8_FRA_WIDTH = 3;
	output wire [7:0] out;
endmodule
module fp8_mul (
	a,
	b,
	res
);
	reg _sv2v_0;
	localparam fp_pkg_FP8_EXP_WIDTH = 4;
	localparam fp_pkg_FP8_FRA_WIDTH = 3;
	input wire [7:0] a;
	input wire [7:0] b;
	localparam fp_pkg_FP32_EXP_WIDTH = 8;
	localparam fp_pkg_FP32_FRA_WIDTH = 23;
	output reg [31:0] res;
	reg sign_result;
	reg [3:0] exponent_a;
	reg [3:0] exponent_b;
	reg [2:0] fraction_a;
	reg [2:0] fraction_b;
	reg [3:0] mantissa_a;
	reg [3:0] mantissa_b;
	reg [7:0] mantissa_product;
	reg [7:0] mantissa_normalized;
	reg signed [9:0] exponent_unbiased;
	reg [7:0] exponent_fp32;
	reg [22:0] fraction_fp32;
	localparam fp_pkg_FP32_BIAS = 10'sd127;
	localparam fp_pkg_FP8_BIAS = 10'sd7;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		sign_result = a[7] ^ b[7];
		exponent_a = a[6:3];
		exponent_b = b[6:3];
		fraction_a = a[2:0];
		fraction_b = b[2:0];
		mantissa_a = {exponent_a != 4'b0000, fraction_a};
		mantissa_b = {exponent_b != 4'b0000, fraction_b};
		mantissa_product = mantissa_a * mantissa_b;
		mantissa_normalized = mantissa_product;
		exponent_unbiased = 10'sd0;
		exponent_fp32 = 8'd0;
		fraction_fp32 = 23'd0;
		res = 32'd0;
		if (((exponent_a == 4'hf) && (fraction_a == 3'h7)) || ((exponent_b == 4'hf) && (fraction_b == 3'h7)))
			res = 32'h7fc00000;
		else if (mantissa_product == 8'd0)
			res = {sign_result, 31'd0};
		else begin
			exponent_unbiased = (exponent_a == 4'd0 ? 10'sd1 - fp_pkg_FP8_BIAS : $signed({6'b000000, exponent_a}) - fp_pkg_FP8_BIAS);
			exponent_unbiased = exponent_unbiased + (exponent_b == 4'd0 ? 10'sd1 - fp_pkg_FP8_BIAS : $signed({6'b000000, exponent_b}) - fp_pkg_FP8_BIAS);
			exponent_unbiased = exponent_unbiased + 10'sd1;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < 7; i = i + 1)
					if (!mantissa_normalized[7]) begin
						mantissa_normalized = mantissa_normalized << 1;
						exponent_unbiased = exponent_unbiased - 10'sd1;
					end
			end
			exponent_fp32 = sv2v_cast_8($unsigned(exponent_unbiased + fp_pkg_FP32_BIAS));
			fraction_fp32 = {mantissa_normalized[6:0], 16'b0000000000000000};
			res = {sign_result, exponent_fp32, fraction_fp32};
		end
	end
	initial _sv2v_0 = 0;
endmodule
module fp8_to_fp32 (
	in,
	out
);
	localparam fp_pkg_FP8_EXP_WIDTH = 4;
	localparam fp_pkg_FP8_FRA_WIDTH = 3;
	input wire [7:0] in;
	localparam fp_pkg_FP32_EXP_WIDTH = 8;
	localparam fp_pkg_FP32_FRA_WIDTH = 23;
	output wire [31:0] out;
endmodule
module mxu (
	clk,
	rst_n,
	step_en,
	weight_load,
	weight_in,
	activation_in_valid,
	activation_in,
	result_valid,
	result
);
	parameter ARRAY_SIZE = 2;
	parameter DATA_WIDTH = 8;
	parameter ACC_WIDTH = 32;
	input wire clk;
	input wire rst_n;
	input wire step_en;
	input wire weight_load;
	input wire [((ARRAY_SIZE * ARRAY_SIZE) * DATA_WIDTH) - 1:0] weight_in;
	input wire [0:ARRAY_SIZE - 1] activation_in_valid;
	input wire [(ARRAY_SIZE * DATA_WIDTH) - 1:0] activation_in;
	output wire [0:ARRAY_SIZE - 1] result_valid;
	output wire [(ARRAY_SIZE * ACC_WIDTH) - 1:0] result;
	wire activation_valid_bus [0:ARRAY_SIZE - 1][0:ARRAY_SIZE + 0];
	wire [DATA_WIDTH - 1:0] activation_bus [0:ARRAY_SIZE - 1][0:ARRAY_SIZE + 0];
	wire [ACC_WIDTH - 1:0] psum_bus [0:ARRAY_SIZE + 0][0:ARRAY_SIZE - 1];
	genvar _gv_row_1;
	generate
		for (_gv_row_1 = 0; _gv_row_1 < ARRAY_SIZE; _gv_row_1 = _gv_row_1 + 1) begin : activation_load_loop
			localparam row = _gv_row_1;
			assign activation_bus[row][0] = activation_in[((ARRAY_SIZE - 1) - row) * DATA_WIDTH+:DATA_WIDTH];
			assign activation_valid_bus[row][0] = activation_in_valid[row];
		end
	endgenerate
	genvar _gv_col_1;
	generate
		for (_gv_col_1 = 0; _gv_col_1 < ARRAY_SIZE; _gv_col_1 = _gv_col_1 + 1) begin : psum_edge_loop
			localparam col = _gv_col_1;
			assign psum_bus[0][col] = 1'sb0;
			assign result[((ARRAY_SIZE - 1) - col) * ACC_WIDTH+:ACC_WIDTH] = psum_bus[ARRAY_SIZE][col];
			assign result_valid[col] = activation_valid_bus[ARRAY_SIZE - 1][col + 1];
		end
	endgenerate
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < ARRAY_SIZE; _gv_i_1 = _gv_i_1 + 1) begin : row_loop
			localparam i = _gv_i_1;
			genvar _gv_j_1;
			for (_gv_j_1 = 0; _gv_j_1 < ARRAY_SIZE; _gv_j_1 = _gv_j_1 + 1) begin : col_loop
				localparam j = _gv_j_1;
				pe #(
					.DATA_WIDTH(DATA_WIDTH),
					.ACC_WIDTH(ACC_WIDTH)
				) pe_inst(
					.clk(clk),
					.rst_n(rst_n),
					.step_en(step_en),
					.weight_load(weight_load),
					.in_valid(activation_valid_bus[i][j]),
					.out_valid(activation_valid_bus[i][j + 1]),
					.weight_in(weight_in[((((ARRAY_SIZE - 1) - i) * ARRAY_SIZE) + ((ARRAY_SIZE - 1) - j)) * DATA_WIDTH+:DATA_WIDTH]),
					.activation_in(activation_bus[i][j]),
					.activation_out(activation_bus[i][j + 1]),
					.psum_in(psum_bus[i][j]),
					.psum_out(psum_bus[i + 1][j])
				);
			end
		end
	endgenerate
endmodule
module pe (
	clk,
	rst_n,
	step_en,
	weight_load,
	in_valid,
	out_valid,
	weight_in,
	activation_in,
	activation_out,
	psum_in,
	psum_out
);
	parameter DATA_WIDTH = 8;
	parameter ACC_WIDTH = 32;
	input wire clk;
	input wire rst_n;
	input wire step_en;
	input wire weight_load;
	input wire in_valid;
	output reg out_valid;
	input wire [DATA_WIDTH - 1:0] weight_in;
	input wire [DATA_WIDTH - 1:0] activation_in;
	output reg [DATA_WIDTH - 1:0] activation_out;
	input wire [ACC_WIDTH - 1:0] psum_in;
	output reg [ACC_WIDTH - 1:0] psum_out;
	wire [31:0] sum_reg;
	wire [31:0] product_reg;
	reg [7:0] weight_reg;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			weight_reg <= 8'd0;
			activation_out <= 8'd0;
			psum_out <= 32'd0;
			out_valid <= 1'b0;
		end
		else begin
			if (weight_load)
				weight_reg <= weight_in;
			if (step_en) begin
				out_valid <= in_valid;
				if (in_valid) begin
					activation_out <= activation_in;
					psum_out <= sum_reg;
				end
			end
		end
	fp8_mul fp8_mul_inst(
		.a(activation_in),
		.b(weight_reg),
		.res(product_reg)
	);
	fp32_add fp32_add_inst(
		.a(psum_in),
		.b(product_reg),
		.res(sum_reg)
	);
endmodule
module systolic_data_setup (
	clk,
	rst_n,
	step_en,
	act_in_valid,
	act_in,
	act_out_valid,
	act_out
);
	parameter ARRAY_SIZE = 2;
	parameter DATA_WIDTH = 8;
	input wire clk;
	input wire rst_n;
	input wire step_en;
	input wire [0:ARRAY_SIZE - 1] act_in_valid;
	input wire [(ARRAY_SIZE * DATA_WIDTH) - 1:0] act_in;
	output wire [0:ARRAY_SIZE - 1] act_out_valid;
	output wire [(ARRAY_SIZE * DATA_WIDTH) - 1:0] act_out;
	genvar _gv_row_2;
	generate
		for (_gv_row_2 = 0; _gv_row_2 < ARRAY_SIZE; _gv_row_2 = _gv_row_2 + 1) begin : gen_row
			localparam row = _gv_row_2;
			if (row == 0) begin : passthrough
				assign act_out[(ARRAY_SIZE - 1) * DATA_WIDTH+:DATA_WIDTH] = act_in[(ARRAY_SIZE - 1) * DATA_WIDTH+:DATA_WIDTH];
				assign act_out_valid[0] = act_in_valid[0];
			end
			else begin : skew_pipe
				reg [DATA_WIDTH - 1:0] data_pipe [0:row - 1];
				reg valid_pipe [0:row - 1];
				always @(posedge clk or negedge rst_n)
					if (!rst_n) begin : sv2v_autoblock_1
						reg signed [31:0] k;
						for (k = 0; k < row; k = k + 1)
							begin
								data_pipe[k] <= 1'sb0;
								valid_pipe[k] <= 1'b0;
							end
					end
					else if (step_en) begin
						data_pipe[0] <= act_in[((ARRAY_SIZE - 1) - row) * DATA_WIDTH+:DATA_WIDTH];
						valid_pipe[0] <= act_in_valid[row];
						begin : sv2v_autoblock_2
							reg signed [31:0] k;
							for (k = 1; k < row; k = k + 1)
								begin
									data_pipe[k] <= data_pipe[k - 1];
									valid_pipe[k] <= valid_pipe[k - 1];
								end
						end
					end
				assign act_out[((ARRAY_SIZE - 1) - row) * DATA_WIDTH+:DATA_WIDTH] = data_pipe[row - 1];
				assign act_out_valid[row] = valid_pipe[row - 1];
			end
		end
	endgenerate
endmodule
module tiny_tpu (
	clk,
	rst_n
);
	input wire clk;
	input wire rst_n;
endmodule
`default_nettype none
module tt_um_itsmeleow_tiny_tpu (
	ui_in,
	uo_out,
	uio_in,
	uio_out,
	uio_oe,
	ena,
	clk,
	rst_n
);
	input wire [7:0] ui_in;
	output wire [7:0] uo_out;
	input wire [7:0] uio_in;
	output wire [7:0] uio_out;
	output wire [7:0] uio_oe;
	input wire ena;
	input wire clk;
	input wire rst_n;
	localparam [2:0] CMD_WRITE_WEIGHT = 3'd1;
	localparam [2:0] CMD_LOAD_WEIGHTS = 3'd2;
	localparam [2:0] CMD_STAGE_A0 = 3'd3;
	localparam [2:0] CMD_PUSH_ROW = 3'd4;
	localparam [2:0] CMD_DRAIN = 3'd5;
	localparam [2:0] CMD_READ_STATUS = 3'd6;
	wire [2:0] cmd;
	wire step_en;
	wire weight_load;
	wire push_row;
	reg [31:0] weight_regs;
	reg [7:0] staged_a0;
	reg [7:0] delayed_a1;
	reg delayed_a1_valid;
	wire [15:0] activation_in;
	wire [0:1] activation_in_valid;
	wire [63:0] result;
	wire [0:1] result_valid;
	wire [31:0] selected_result;
	assign cmd = uio_in[2:0];
	assign push_row = ena && (cmd == CMD_PUSH_ROW);
	assign step_en = push_row || (ena && (cmd == CMD_DRAIN));
	assign weight_load = ena && (cmd == CMD_LOAD_WEIGHTS);
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			begin : sv2v_autoblock_1
				reg signed [31:0] row;
				for (row = 0; row < 2; row = row + 1)
					begin : sv2v_autoblock_2
						reg signed [31:0] col;
						for (col = 0; col < 2; col = col + 1)
							weight_regs[(((1 - row) * 2) + (1 - col)) * 8+:8] <= 1'sb0;
					end
			end
			staged_a0 <= 1'sb0;
			delayed_a1 <= 1'sb0;
			delayed_a1_valid <= 1'b0;
		end
		else if (ena) begin
			if (cmd == CMD_WRITE_WEIGHT)
				weight_regs[(((1 - uio_in[4]) * 2) + (1 - uio_in[3])) * 8+:8] <= ui_in;
			if (cmd == CMD_STAGE_A0)
				staged_a0 <= ui_in;
			if (step_en) begin
				delayed_a1_valid <= push_row;
				if (push_row)
					delayed_a1 <= ui_in;
			end
		end
	assign activation_in[8+:8] = staged_a0;
	assign activation_in_valid[0] = push_row;
	assign activation_in[0+:8] = delayed_a1;
	assign activation_in_valid[1] = delayed_a1_valid;
	mxu mxu_inst(
		.clk(clk),
		.rst_n(rst_n),
		.step_en(step_en),
		.weight_load(weight_load),
		.weight_in(weight_regs),
		.activation_in_valid(activation_in_valid),
		.activation_in(activation_in),
		.result_valid(result_valid),
		.result(result)
	);
	assign selected_result = result[(1 - uio_in[5]) * 32+:32];
	assign uo_out = (cmd == CMD_READ_STATUS ? {6'b000000, result_valid[1], result_valid[0]} : selected_result[8 * uio_in[7:6]+:8]);
	assign uio_out = 1'sb0;
	assign uio_oe = 1'sb0;
endmodule
module unified_buffer (
	clk,
	rst_n
);
	input wire clk;
	input wire rst_n;
endmodule
module vpu (
	a,
	b,
	result
);
	localparam fp_pkg_FP32_EXP_WIDTH = 8;
	localparam fp_pkg_FP32_FRA_WIDTH = 23;
	input wire [31:0] a;
	input wire [31:0] b;
	output wire [31:0] result;
	assign result = a + b;
endmodule
