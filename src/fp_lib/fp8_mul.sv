/*
 * FP8 Multiplication 
 * Multiply two FP8 (E4M3FN) operands and produce an FP32 product.
 */

module fp8_mul
    import fp_pkg::*;
(
    input  fp8_e4m3_t a,
    input  fp8_e4m3_t b,
    output fp32_t     res
);
    // combined bias offset: FP32_BIAS (127) - 2 * FP8_BIAS (14) + 1 = 114
    localparam logic [7:0] EXP_OFFSET = 8'(FP32_BIAS - (2 * FP8_BIAS) + 1);

    logic       sign_result;
    logic [3:0] exponent_a, exponent_b;
    logic [3:0] eff_exp_a, eff_exp_b;
    logic [2:0] fraction_a, fraction_b;

    // fraction a and b with hidden leading one restored
    logic [3:0] mantissa_a, mantissa_b;
    logic [7:0] mantissa_product, mantissa_normalized;

    logic [2:0] lz;
    logic [7:0] exponent_sum, exponent_fp32;
    logic [22:0] fraction_fp32;

    always_comb begin
        sign_result = a[7] ^ b[7];

        exponent_a = a[6:3];
        exponent_b = b[6:3];
        fraction_a = a[2:0];
        fraction_b = b[2:0];

        // normal numbers have a hidden 1 while subnormals have a hidden 0
        mantissa_a = {(exponent_a != 4'b0), fraction_a};
        mantissa_b = {(exponent_b != 4'b0), fraction_b};

        mantissa_product = mantissa_a * mantissa_b;

        // subnormals use an effective exponent of 1 instead of 0
        eff_exp_a = (exponent_a == 4'd0) ? 4'd1 : exponent_a;
        eff_exp_b = (exponent_b == 4'd0) ? 4'd1 : exponent_b;

        // pre-sum biased exponents in parallel with multiply and normalization
        exponent_sum = {4'd0, eff_exp_a} + {4'd0, eff_exp_b} + EXP_OFFSET;

        // 3-stage binary lzc to shift the leading 1 into bit 7
        mantissa_normalized = mantissa_product;
        lz                  = 3'd0;
        if (mantissa_normalized[7:4] == 4'd0) begin
            lz[2]               = 1'b1;
            mantissa_normalized = {mantissa_normalized[3:0], 4'd0};
        end
        if (mantissa_normalized[7:6] == 2'd0) begin
            lz[1]               = 1'b1;
            mantissa_normalized = {mantissa_normalized[5:0], 2'd0};
        end
        if (mantissa_normalized[7] == 1'b0) begin
            lz[0]               = 1'b1;
            mantissa_normalized = {mantissa_normalized[6:0], 1'd0};
        end

        // adjust fp32 exponent by normalization shift count
        exponent_fp32 = exponent_sum - {5'd0, lz};

        // remove the hidden 1 and pad to 23 fraction bits
        fraction_fp32 = {mantissa_normalized[6:0], 16'b0};

        // E4M3FN NaN: exponent = 1111, fraction = 111
        if (((exponent_a == 4'hf) && (fraction_a == 3'h7)) ||
            ((exponent_b == 4'hf) && (fraction_b == 3'h7))) begin
            res = 32'h7fc0_0000;
        end else if (mantissa_product == 8'd0) begin
            res = {sign_result, 31'd0};
        end else begin
            // combine to form fp32 result
            res = {sign_result, exponent_fp32, fraction_fp32};
        end
    end
endmodule
