/*
 * Multiply two FP8 (E4M3FN) operands and produce an FP32 product.
 */

module fp8_mul (
    input  fp_pkg::fp8_e4m3_t a,
    input  fp_pkg::fp8_e4m3_t b,
    output fp_pkg::fp32_t     res
);

    import fp_pkg::FP8_BIAS;
    import fp_pkg::FP32_BIAS;

    logic       sign_bit;
    logic [3:0] exp_a, exp_b;
    logic [2:0] frac_a, frac_b;

    // fraction a and b with hidden leading one restored
    logic [3:0] frac_a_adj, frac_b_adj;
    logic [7:0] frac_product, normalized_product;

    logic signed [9:0]  exp_unbiased;
    logic        [7:0]  exp_fp32;
    logic        [22:0] frac_fp32;

    always_comb begin
        sign_bit = a[7] ^ b[7];
        
        exp_a  = a[6:3];
        exp_b  = b[6:3];
        frac_a = a[2:0];
        frac_b = b[2:0];

        // normal numbers have a hidden 1 while subnormals have a hidden 0
        frac_a_adj = {(exp_a != 4'b0), frac_a};
        frac_b_adj = {(exp_b != 4'b0), frac_b};

        frac_product = frac_a_adj * frac_b_adj;

        // initialize defaults
        normalized_product = frac_product;
        exp_unbiased = 10'sd0;
        exp_fp32     = 8'd0;
        frac_fp32    = 23'd0;
        res          = 32'd0;

        // E4M3FN NaN: exponent = 1111, fraction = 111
        if (((exp_a == 4'hf) && (frac_a == 3'h7) || (exp_b == 4'hf) && (frac_b == 3'h7))) begin
            res = 32'h7fc0_0000;
        end else if (frac_product == 8'd0) begin
            res = {sign_bit, 31'd0};
        end else begin
            // subnormals use an effective exponent of 1 - bias
            exp_unbiased = (exp_a == 4'd0)
                         ? (1 - FP8_BIAS)
                         : ($signed({6'b0, exp_a}) - FP8_BIAS);

            exp_unbiased = exp_unbiased + ((exp_b == 4'd0)
                         ? (1 - FP8_BIAS)
                         : ($signed({6'b0, exp_b}) - FP8_BIAS));

            // product has six fractional bits
            // normalizing with the leading 1 at bit 7 requires +1
            exp_unbiased = exp_unbiased + 10'sd1;

            // shift the leading 1 into bit 7, adjusting the exponent
            for (int i = 0; i < 7; i = i + 1) begin
                if (!normalized_product[7]) begin
                    normalized_product = normalized_product << 1;
                    exp_unbiased = exp_unbiased - 10'sd1;
                end
            end

            // re-bias the exponent and explicitly size it to 8 bits
            exp_fp32 = 8'($unsigned(exp_unbiased + FP32_BIAS));

            // remove the hidden 1 and pad to 23 fraction bits
            frac_fp32 = {normalized_product[6:0], 16'b0};

            // combine to form fp32 result
            res = {sign_bit, exp_fp32, frac_fp32};
        end
    end
endmodule
