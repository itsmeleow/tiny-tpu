/*
 * FP32 Addition with exponent alignment and rounding.
 */

module fp32_add (
    input  fp_pkg::fp32_t a,
    input  fp_pkg::fp32_t b,
    output fp_pkg::fp32_t res
);

    import fp_pkg::FP32_BIAS;

    logic        sign_bit;
    logic [7:0]  exp_a, exp_b, exp_diff;
    logic [22:0] frac_a, frac_b;

    // fraction a and b with hidden leading one restored
    logic [23:0] frac_a_adj, frac_b_adj;

    logic [23:0] frac_sum;

    always_comb begin
        sign_bit = a[31] ^ b[31];

        exp_a  = a[30:23];
        exp_b  = b[30:23];
        frac_a = a[22:0];
        frac_b = b[22:0];

        frac_a_adj = {{1'b1}, frac_a};
        frac_b_adj = {{1'b1}, frac_b};

        // align exponents (match the larger exponent)
        // we shift the fraction of the smaller exponent >> by the dif in the exponents
        if (exp_a > exp_b) begin
            exp_diff = exp_a - exp_b;
            frac_b_adj = frac_b_adj >> exp_diff;
            exp_b = exp_a;
        end else begin
            exp_diff = exp_b - exp_a;
            frac_a_adj = frac_a_adj >> exp_diff;
            exp_a = exp_b;
        end

        frac_sum = frac_a_adj + frac_b_adj;

        // normalize 
        



    end




endmodule
