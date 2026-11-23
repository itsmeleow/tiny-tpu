/*
 * Multiply two FP8 (E4M3FN) operands and produce an FP32 product.
 */


module fp8_mul 
    import fp_pkg::*; 
(
    input  fp8_e4m3_t a,
    input  fp8_e4m3_t b,
    output fp32_t     res
);
    logic       sign_result;
    logic [3:0] exponent_a, exponent_b;
    logic [2:0] fraction_a, fraction_b;

    // fraction a and b with hidden leading one restored
    logic [3:0] mantissa_a, mantissa_b;
    logic [7:0] mantissa_product, mantissa_normalized;

    logic signed [9:0] exponent_unbiased;
    logic        [7:0] exponent_fp32;
    logic       [22:0] fraction_fp32;

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

        // initialize defaults
        mantissa_normalized = mantissa_product;
        exponent_unbiased  = 10'sd0;
        exponent_fp32      = 8'd0;
        fraction_fp32      = 23'd0;
        res                = 32'd0;

        // E4M3FN NaN: exponent = 1111, fraction = 111
        if (((exponent_a == 4'hf) && (fraction_a == 3'h7) ||
             (exponent_b == 4'hf) && (fraction_b == 3'h7))) begin
            res = 32'h7fc0_0000;
        end else if (mantissa_product == 8'd0) begin
            res = {sign_result, 31'd0};
        end else begin
            // subnormals use an effective exponent of 1 - bias
            exponent_unbiased = (exponent_a == 4'd0)
                              ? (10'sd1 - FP8_BIAS)
                              : ($signed({6'b0, exponent_a}) - FP8_BIAS);

            exponent_unbiased = exponent_unbiased + ((exponent_b == 4'd0)
                              ? (10'sd1 - FP8_BIAS)
                              : ($signed({6'b0, exponent_b}) - FP8_BIAS));

            // product has six fractional bits
            // normalizing with the leading 1 at bit 7 requires +1
            exponent_unbiased = exponent_unbiased + 10'sd1;

            // shift the leading 1 into bit 7, adjusting the exponent
            for (int i = 0; i < 7; i++) begin
                if (!mantissa_normalized[7]) begin
                    mantissa_normalized = mantissa_normalized << 1;
                    exponent_unbiased = exponent_unbiased - 10'sd1;
                end
            end

            // re-bias the exponent and explicitly size it to 8 bits
            exponent_fp32 = 8'($unsigned(exponent_unbiased + FP32_BIAS));

            // remove the hidden 1 and pad to 23 fraction bits
            fraction_fp32 = {mantissa_normalized[6:0], 16'b0};

            // combine to form fp32 result
            res = {sign_result, exponent_fp32, fraction_fp32};
        end
    end
endmodule
