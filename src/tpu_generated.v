module axis_out_ser (
	clk,
	rst_n,
	ser_load,
	ser_en,
	ser_last,
	out_fmt,
	fp32_in,
	fp8_in,
	ser_done,
	m_axis_tdata,
	m_axis_tvalid,
	m_axis_tready,
	m_axis_tlast
);
	parameter DATA_WIDTH = 8;
	parameter ACC_WIDTH = 32;
	input wire clk;
	input wire rst_n;
	input wire ser_load;
	input wire ser_en;
	input wire ser_last;
	input wire out_fmt;
	input wire [31:0] fp32_in;
	input wire [7:0] fp8_in;
	output wire ser_done;
	output wire [7:0] m_axis_tdata;
	output wire m_axis_tvalid;
	input wire m_axis_tready;
	output wire m_axis_tlast;
	reg [31:0] shift_reg;
	reg [1:0] bytes_left;
	assign m_axis_tvalid = ser_en;
	assign m_axis_tdata = shift_reg[7:0];
	assign m_axis_tlast = (ser_en && ser_last) && (bytes_left == 2'd0);
	assign ser_done = (ser_en && m_axis_tready) && (bytes_left == 2'd0);
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			shift_reg <= 32'd0;
			bytes_left <= 2'd0;
		end
		else if (ser_load) begin
			shift_reg <= (out_fmt ? {24'd0, fp8_in} : fp32_in);
			bytes_left <= (out_fmt ? 2'd0 : 2'd3);
		end
		else if ((ser_en && m_axis_tready) && (bytes_left != 2'd0)) begin
			shift_reg <= {8'd0, shift_reg[31:8]};
			bytes_left <= bytes_left - 2'd1;
		end
endmodule
module controller (
	clk,
	rst_n,
	s_axis_tdata,
	s_axis_tvalid,
	s_axis_tready,
	s_axis_tlast,
	mxu_weight_load,
	mxu_weight_in,
	mxu_step_en,
	act_in_valid,
	act_in,
	mxu_res_valid,
	mxu_res,
	vpu_data,
	ser_done,
	ser_load,
	ser_last,
	ser_en,
	out_fmt,
	vpu_op
);
	reg _sv2v_0;
	parameter ARRAY_SIZE = 2;
	parameter DATA_WIDTH = 8;
	parameter ACC_WIDTH = 32;
	parameter MATMUL_CYCLES = 3 * ARRAY_SIZE;
	input wire clk;
	input wire rst_n;
	input wire [DATA_WIDTH - 1:0] s_axis_tdata;
	input wire s_axis_tvalid;
	output reg s_axis_tready;
	input wire s_axis_tlast;
	output reg mxu_weight_load;
	output wire [((ARRAY_SIZE * ARRAY_SIZE) * DATA_WIDTH) - 1:0] mxu_weight_in;
	output reg mxu_step_en;
	output reg [0:ARRAY_SIZE - 1] act_in_valid;
	output reg [(ARRAY_SIZE * DATA_WIDTH) - 1:0] act_in;
	input wire [0:ARRAY_SIZE - 1] mxu_res_valid;
	input wire [(ARRAY_SIZE * ACC_WIDTH) - 1:0] mxu_res;
	output wire [ACC_WIDTH - 1:0] vpu_data;
	input wire ser_done;
	output reg ser_load;
	output reg ser_last;
	output reg ser_en;
	output wire out_fmt;
	output wire [2:0] vpu_op;
	localparam [2:0] CMD_LD_WEIGHT = 3'b001;
	localparam [2:0] CMD_LD_ACT = 3'b010;
	localparam [2:0] CMD_MATMUL = 3'b011;
	reg [2:0] state;
	reg [2:0] next_state;
	reg [DATA_WIDTH - 1:0] cmd_reg;
	reg [((ARRAY_SIZE * ARRAY_SIZE) * DATA_WIDTH) - 1:0] weight_buffer;
	reg [DATA_WIDTH - 1:0] act_buffer [0:ARRAY_SIZE - 1][0:ARRAY_SIZE - 1];
	reg [ACC_WIDTH - 1:0] res_buffer [0:ARRAY_SIZE - 1][0:ARRAY_SIZE - 1];
	reg [3:0] count;
	reg res_wr_row [0:ARRAY_SIZE - 1];
	wire s_handshake;
	assign s_handshake = s_axis_tvalid && s_axis_tready;
	assign mxu_weight_in = weight_buffer;
	assign out_fmt = cmd_reg[3];
	assign vpu_op = cmd_reg[2:0];
	assign vpu_data = res_buffer[count[1]][count[0]];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			state <= 3'b000;
			cmd_reg <= 8'd0;
			count <= 4'd0;
			begin : sv2v_autoblock_1
				reg signed [31:0] i;
				for (i = 0; i < ARRAY_SIZE; i = i + 1)
					begin
						res_wr_row[i] <= 1'b0;
						begin : sv2v_autoblock_2
							reg signed [31:0] j;
							for (j = 0; j < ARRAY_SIZE; j = j + 1)
								begin
									weight_buffer[((((ARRAY_SIZE - 1) - i) * ARRAY_SIZE) + ((ARRAY_SIZE - 1) - j)) * DATA_WIDTH+:DATA_WIDTH] <= 1'sb0;
									act_buffer[i][j] <= 1'sb0;
									res_buffer[i][j] <= 1'sb0;
								end
						end
					end
			end
		end
		else begin
			state <= next_state;
			case (state)
				3'b000: begin
					count <= 4'd0;
					begin : sv2v_autoblock_3
						reg signed [31:0] c;
						for (c = 0; c < ARRAY_SIZE; c = c + 1)
							res_wr_row[c] <= 1'b0;
					end
					if (s_handshake)
						cmd_reg <= s_axis_tdata;
				end
				3'b001:
					if (count < 4'd4) begin
						if (s_handshake) begin
							weight_buffer[((((ARRAY_SIZE - 1) - count[1]) * ARRAY_SIZE) + ((ARRAY_SIZE - 1) - count[0])) * DATA_WIDTH+:DATA_WIDTH] <= s_axis_tdata;
							count <= (s_axis_tlast ? 4'd4 : count + 4'd1);
						end
					end
					else
						count <= 4'd0;
				3'b010:
					if (s_handshake) begin
						act_buffer[count[1]][count[0]] <= s_axis_tdata;
						count <= ((count == 4'd3) || s_axis_tlast ? 4'd0 : count + 4'd1);
					end
				3'b011: begin
					count <= (count == (MATMUL_CYCLES - 1) ? 4'd0 : count + 4'd1);
					begin : sv2v_autoblock_4
						reg signed [31:0] c;
						for (c = 0; c < ARRAY_SIZE; c = c + 1)
							if (mxu_res_valid[c]) begin
								res_buffer[res_wr_row[c]][c] <= mxu_res[((ARRAY_SIZE - 1) - c) * ACC_WIDTH+:ACC_WIDTH];
								res_wr_row[c] <= res_wr_row[c] + 1'b1;
							end
					end
				end
				3'b100:
					;
				3'b101:
					if (ser_done)
						count <= (count == 4'd3 ? 4'd0 : count + 4'd1);
				default:
					;
			endcase
		end
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		s_axis_tready = 1'b0;
		mxu_weight_load = 1'b0;
		mxu_step_en = 1'b0;
		ser_load = 1'b0;
		ser_en = 1'b0;
		ser_last = count == 4'd3;
		begin : sv2v_autoblock_5
			reg signed [31:0] r;
			for (r = 0; r < ARRAY_SIZE; r = r + 1)
				begin
					act_in[((ARRAY_SIZE - 1) - r) * DATA_WIDTH+:DATA_WIDTH] = 1'sb0;
					act_in_valid[r] = 1'b0;
				end
		end
		case (state)
			3'b000: begin
				s_axis_tready = 1'b1;
				if (s_handshake)
					case (s_axis_tdata[7:5])
						CMD_LD_WEIGHT: next_state = 3'b001;
						CMD_LD_ACT: next_state = 3'b010;
						CMD_MATMUL: next_state = 3'b011;
						default: next_state = 3'b000;
					endcase
			end
			3'b001:
				if (count < 4'd4)
					s_axis_tready = 1'b1;
				else begin
					mxu_weight_load = 1'b1;
					next_state = 3'b000;
				end
			3'b010: begin
				s_axis_tready = 1'b1;
				if (s_handshake && ((count == 4'd3) || s_axis_tlast))
					next_state = 3'b011;
			end
			3'b011: begin
				mxu_step_en = 1'b1;
				if (count < ARRAY_SIZE) begin : sv2v_autoblock_6
					reg signed [31:0] r;
					for (r = 0; r < ARRAY_SIZE; r = r + 1)
						begin
							act_in[((ARRAY_SIZE - 1) - r) * DATA_WIDTH+:DATA_WIDTH] = act_buffer[count[0]][r];
							act_in_valid[r] = 1'b1;
						end
				end
				if (count == (MATMUL_CYCLES - 1))
					next_state = 3'b100;
			end
			3'b100: begin
				ser_load = 1'b1;
				next_state = 3'b101;
			end
			3'b101: begin
				ser_en = 1'b1;
				if (ser_done)
					next_state = (count == 4'd3 ? 3'b000 : 3'b100);
			end
			default: next_state = 3'b000;
		endcase
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
	reg a_ge_b;
	reg sign_result;
	reg [7:0] exp_big;
	reg [7:0] exp_small;
	reg [7:0] exp_diff;
	reg [23:0] mant_big;
	reg [23:0] mant_small;
	reg [23:0] mant_small_aligned;
	reg [24:0] mant_sum;
	reg [23:0] norm_mant;
	reg [4:0] lz;
	reg [8:0] exp_carry;
	reg [7:0] exp_sub;
	always @(*) begin
		if (_sv2v_0)
			;
		a_ge_b = a[30:0] >= b[30:0];
		sign_result = (a_ge_b ? a[31] : b[31]);
		exp_big = (a_ge_b ? a[30:23] : b[30:23]);
		exp_small = (a_ge_b ? b[30:23] : a[30:23]);
		mant_big = (a_ge_b ? {1'b1, a[22:0]} : {1'b1, b[22:0]});
		mant_small = (a_ge_b ? {1'b1, b[22:0]} : {1'b1, a[22:0]});
		exp_diff = exp_big - exp_small;
		mant_small_aligned = (exp_diff >= 8'd24 ? 24'd0 : mant_small >> exp_diff[4:0]);
		if (a[31] == b[31])
			mant_sum = {1'b0, mant_big} + {1'b0, mant_small_aligned};
		else
			mant_sum = {1'b0, mant_big} - {1'b0, mant_small_aligned};
		norm_mant = mant_sum[23:0];
		lz = 5'd0;
		if (norm_mant[23:8] == 16'd0) begin
			lz[4] = 1'b1;
			norm_mant = {norm_mant[7:0], 16'd0};
		end
		if (norm_mant[23:16] == 8'd0) begin
			lz[3] = 1'b1;
			norm_mant = {norm_mant[15:0], 8'd0};
		end
		if (norm_mant[23:20] == 4'd0) begin
			lz[2] = 1'b1;
			norm_mant = {norm_mant[19:0], 4'd0};
		end
		if (norm_mant[23:22] == 2'd0) begin
			lz[1] = 1'b1;
			norm_mant = {norm_mant[21:0], 2'd0};
		end
		if (norm_mant[23] == 1'b0) begin
			lz[0] = 1'b1;
			norm_mant = {norm_mant[22:0], 1'd0};
		end
		exp_carry = {1'b0, exp_big} + 9'd1;
		exp_sub = exp_big - {3'd0, lz};
		if ((a[30:0] == 31'd0) && (b[30:0] == 31'd0))
			res = {a[31] & b[31], 31'd0};
		else if (a[30:0] == 31'd0)
			res = b;
		else if (b[30:0] == 31'd0)
			res = a;
		else if (mant_sum == 25'd0)
			res = 32'd0;
		else if (mant_sum[24]) begin
			if (exp_carry >= 9'd255)
				res = {sign_result, 31'h7f800000};
			else
				res = {sign_result, exp_carry[7:0], mant_sum[23:1]};
		end
		else if (exp_big <= {3'd0, lz})
			res = {sign_result, 31'd0};
		else
			res = {sign_result, exp_sub, norm_mant[22:0]};
	end
	initial _sv2v_0 = 0;
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
	localparam fp_pkg_FP32_BIAS = 10'sd127;
	localparam fp_pkg_FP8_BIAS = 10'sd7;
	function automatic signed [7:0] sv2v_cast_8_signed;
		input reg signed [7:0] inp;
		sv2v_cast_8_signed = inp;
	endfunction
	localparam [7:0] EXP_OFFSET = sv2v_cast_8_signed((fp_pkg_FP32_BIAS - (2 * fp_pkg_FP8_BIAS)) + 1);
	reg sign_result;
	reg [3:0] exponent_a;
	reg [3:0] exponent_b;
	reg [3:0] eff_exp_a;
	reg [3:0] eff_exp_b;
	reg [2:0] fraction_a;
	reg [2:0] fraction_b;
	reg [3:0] mantissa_a;
	reg [3:0] mantissa_b;
	reg [7:0] mantissa_product;
	reg [7:0] mantissa_normalized;
	reg [2:0] lz;
	reg [7:0] exponent_sum;
	reg [7:0] exponent_fp32;
	reg [22:0] fraction_fp32;
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
		eff_exp_a = (exponent_a == 4'd0 ? 4'd1 : exponent_a);
		eff_exp_b = (exponent_b == 4'd0 ? 4'd1 : exponent_b);
		exponent_sum = ({4'd0, eff_exp_a} + {4'd0, eff_exp_b}) + EXP_OFFSET;
		mantissa_normalized = mantissa_product;
		lz = 3'd0;
		if (mantissa_normalized[7:4] == 4'd0) begin
			lz[2] = 1'b1;
			mantissa_normalized = {mantissa_normalized[3:0], 4'd0};
		end
		if (mantissa_normalized[7:6] == 2'd0) begin
			lz[1] = 1'b1;
			mantissa_normalized = {mantissa_normalized[5:0], 2'd0};
		end
		if (mantissa_normalized[7] == 1'b0) begin
			lz[0] = 1'b1;
			mantissa_normalized = {mantissa_normalized[6:0], 1'd0};
		end
		exponent_fp32 = exponent_sum - {5'd0, lz};
		fraction_fp32 = {mantissa_normalized[6:0], 16'b0000000000000000};
		if (((exponent_a == 4'hf) && (fraction_a == 3'h7)) || ((exponent_b == 4'hf) && (fraction_b == 3'h7)))
			res = 32'h7fc00000;
		else if (mantissa_product == 8'd0)
			res = {sign_result, 31'd0};
		else
			res = {sign_result, exponent_fp32, fraction_fp32};
	end
	initial _sv2v_0 = 0;
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
	reg [31:0] product_reg;
	wire [31:0] product_wire;
	reg [7:0] weight_reg;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			weight_reg <= 8'd0;
			activation_out <= 8'd0;
			psum_out <= 32'd0;
			out_valid <= 1'b0;
		end
		else begin
			product_reg <= product_wire;
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
		.res(product_wire)
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
	rst_n,
	s_axis_tdata,
	s_axis_tvalid,
	s_axis_tready,
	s_axis_tlast,
	m_axis_tdata,
	m_axis_tvalid,
	m_axis_tready,
	m_axis_tlast
);
	parameter ARRAY_SIZE = 2;
	parameter DATA_WIDTH = 8;
	parameter ACC_WIDTH = 32;
	input wire clk;
	input wire rst_n;
	input wire [DATA_WIDTH - 1:0] s_axis_tdata;
	input wire s_axis_tvalid;
	output wire s_axis_tready;
	input wire s_axis_tlast;
	output wire [DATA_WIDTH - 1:0] m_axis_tdata;
	output wire m_axis_tvalid;
	input wire m_axis_tready;
	output wire m_axis_tlast;
	wire mxu_weight_load;
	wire [((ARRAY_SIZE * ARRAY_SIZE) * DATA_WIDTH) - 1:0] mxu_weight_in;
	wire mxu_step_en;
	wire [0:ARRAY_SIZE - 1] act_in_valid;
	wire [(ARRAY_SIZE * DATA_WIDTH) - 1:0] act_in;
	wire [0:ARRAY_SIZE - 1] mxu_res_valid;
	wire [(ARRAY_SIZE * ACC_WIDTH) - 1:0] mxu_res;
	wire [ACC_WIDTH - 1:0] vpu_data;
	wire [2:0] vpu_op;
	wire ser_done;
	wire ser_load;
	wire ser_last;
	wire ser_en;
	wire out_fmt;
	wire [0:ARRAY_SIZE - 1] skewed_act_valid;
	wire [(ARRAY_SIZE * DATA_WIDTH) - 1:0] skewed_act;
	wire [DATA_WIDTH - 1:0] vpu_fp8_out;
	wire [ACC_WIDTH - 1:0] vpu_fp32_out;
	controller #(
		.ARRAY_SIZE(ARRAY_SIZE),
		.DATA_WIDTH(DATA_WIDTH)
	) controller_inst(
		.clk(clk),
		.rst_n(rst_n),
		.s_axis_tdata(s_axis_tdata),
		.s_axis_tvalid(s_axis_tvalid),
		.s_axis_tready(s_axis_tready),
		.s_axis_tlast(s_axis_tlast),
		.mxu_weight_load(mxu_weight_load),
		.mxu_weight_in(mxu_weight_in),
		.mxu_step_en(mxu_step_en),
		.act_in_valid(act_in_valid),
		.act_in(act_in),
		.mxu_res_valid(mxu_res_valid),
		.mxu_res(mxu_res),
		.vpu_data(vpu_data),
		.ser_done(ser_done),
		.ser_load(ser_load),
		.ser_last(ser_last),
		.ser_en(ser_en),
		.out_fmt(out_fmt),
		.vpu_op(vpu_op)
	);
	systolic_data_setup #(
		.ARRAY_SIZE(ARRAY_SIZE),
		.DATA_WIDTH(DATA_WIDTH)
	) skew_inst(
		.clk(clk),
		.rst_n(rst_n),
		.step_en(mxu_step_en),
		.act_in_valid(act_in_valid),
		.act_in(act_in),
		.act_out_valid(skewed_act_valid),
		.act_out(skewed_act)
	);
	mxu #(
		.ARRAY_SIZE(ARRAY_SIZE),
		.DATA_WIDTH(DATA_WIDTH),
		.ACC_WIDTH(ACC_WIDTH)
	) mxu_inst(
		.clk(clk),
		.rst_n(rst_n),
		.step_en(mxu_step_en),
		.weight_load(mxu_weight_load),
		.weight_in(mxu_weight_in),
		.activation_in_valid(skewed_act_valid),
		.activation_in(skewed_act),
		.result_valid(mxu_res_valid),
		.result(mxu_res)
	);
	vpu vpu_inst(
		.fp32_in(vpu_data),
		.vpu_op(vpu_op),
		.fp8_out(vpu_fp8_out),
		.fp32_out(vpu_fp32_out)
	);
	axis_out_ser axis_out_inst(
		.clk(clk),
		.rst_n(rst_n),
		.ser_load(ser_load),
		.ser_en(ser_en),
		.ser_last(ser_last),
		.out_fmt(out_fmt),
		.fp32_in(vpu_fp32_out),
		.fp8_in(vpu_fp8_out),
		.ser_done(ser_done),
		.m_axis_tdata(m_axis_tdata),
		.m_axis_tvalid(m_axis_tvalid),
		.m_axis_tready(m_axis_tready),
		.m_axis_tlast(m_axis_tlast)
	);
endmodule
`default_nettype none
module tt_um_leowang_tpu (
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
	localparam signed [31:0] DATA_WIDTH = 8;
	assign uio_oe = 8'b01010010;
	wire s_axis_tvalid;
	wire s_axis_tready;
	wire s_axis_tlast;
	wire m_axis_tvalid;
	wire m_axis_tready;
	wire m_axis_tlast;
	assign s_axis_tvalid = uio_in[0];
	assign s_axis_tlast = uio_in[2];
	assign m_axis_tready = uio_in[5];
	assign uio_out = {1'b0, m_axis_tlast, 1'b0, m_axis_tvalid, 2'b00, s_axis_tready, 1'b0};
	wire [7:0] s_axis_tdata;
	wire [7:0] m_axis_tdata;
	assign s_axis_tdata = ui_in[7:0];
	assign uo_out[7:0] = m_axis_tdata;
	tiny_tpu tpu_inst(
		.clk(clk),
		.rst_n(rst_n),
		.s_axis_tdata(s_axis_tdata),
		.s_axis_tvalid(s_axis_tvalid),
		.s_axis_tready(s_axis_tready),
		.s_axis_tlast(s_axis_tlast),
		.m_axis_tdata(m_axis_tdata),
		.m_axis_tvalid(m_axis_tvalid),
		.m_axis_tready(m_axis_tready),
		.m_axis_tlast(m_axis_tlast)
	);
	wire _unused = &{ena, uio_in[7:6], uio_in[4:3], uio_in[1], 1'b0};
endmodule
module vpu (
	fp32_in,
	vpu_op,
	fp8_out,
	fp32_out
);
	reg _sv2v_0;
	parameter DATA_WIDTH = 8;
	parameter ACC_WIDTH = 32;
	input wire [ACC_WIDTH - 1:0] fp32_in;
	input wire [2:0] vpu_op;
	output reg [DATA_WIDTH - 1:0] fp8_out;
	output reg [ACC_WIDTH - 1:0] fp32_out;
	always @(*) begin
		if (_sv2v_0)
			;
		case (vpu_op)
			3'b000: fp32_out = fp32_in;
			3'b001: fp32_out = (fp32_in[31] ? {ACC_WIDTH {1'sb0}} : fp32_in);
			default: fp32_out = fp32_in;
		endcase
	end
	wire s32;
	wire [7:0] e32;
	wire [2:0] m32_top;
	wire [7:0] e8_unbiased;
	assign s32 = fp32_out[31];
	assign e32 = fp32_out[30:23];
	assign m32_top = fp32_out[22:20];
	assign e8_unbiased = e32 - 8'd120;
	always @(*) begin
		if (_sv2v_0)
			;
		if ((e32 == 8'hff) && (fp32_out[22:0] != 23'd0))
			fp8_out = {s32, 7'b1111111};
		else if (e32 < 8'd121)
			fp8_out = 8'h00;
		else if ((e32 > 8'd135) || ((e32 == 8'd135) && (m32_top == 3'b111)))
			fp8_out = {s32, 7'b1111110};
		else
			fp8_out = {s32, e8_unbiased[3:0], m32_top};
	end
	initial _sv2v_0 = 0;
endmodule
