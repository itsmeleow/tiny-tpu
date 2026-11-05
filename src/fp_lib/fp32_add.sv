/*
 * FP32 Addition with exponent alignment and rounding.
 * Simplified version: rounding is not implemented yet.
 * Supports normal finite inputs and zero.
 * Subnormal results are flushed to zero.
 */

module fp32_add (
    input  fp_pkg::fp32_t a,
    input  fp_pkg::fp32_t b,
    output fp_pkg::fp32_t res
);

    logic        sign_result;
    logic [7:0]  exponent_a, exponent_b, exponent_diff;
    logic [8:0]  exponent_result;
    logic [22:0] fraction_a, fraction_b;

    // fraction a and b with hidden leading one restored
    logic [23:0] mantissa_a, mantissa_b;

    logic [24:0] mantissa_sum;

    always_comb begin
        exponent_a = a[30:23];
        exponent_b = b[30:23];
        fraction_a = a[22:0];
        fraction_b = b[22:0];

        mantissa_a = {1'b1, fraction_a};
        mantissa_b = {1'b1, fraction_b};

        // the larger magnitude determines the sign of the result
        if (a[30:0] >= b[30:0])
            sign_result = a[31];
        else
            sign_result = b[31];

        // align exponents (match the larger exponent)
        // we shift the fraction of the smaller exponent >> by the dif in the exponents
        if (exponent_a > exponent_b) begin
            exponent_diff   = exponent_a - exponent_b;
            mantissa_b      = mantissa_b >> exponent_diff;
            exponent_result = {1'b0, exponent_a};
        end else begin
            exponent_diff   = exponent_b - exponent_a;
            mantissa_a      = mantissa_a >> exponent_diff;
            exponent_result = {1'b0, exponent_b};
        end

        // add fractions, extend operands to account for potential carry-out
        if (a[31] == b[31]) begin
            mantissa_sum = {1'b0, mantissa_a}
                         + {1'b0, mantissa_b};
        end else if (a[30:0] >= b[30:0]) begin
            mantissa_sum = {1'b0, mantissa_a}
                         - {1'b0, mantissa_b};
        end else begin
            mantissa_sum = {1'b0, mantissa_b}
                         - {1'b0, mantissa_a};
        end

        // normalize
        if (mantissa_sum[24]) begin
            // carry-out - shift right and increase the exponent.
            mantissa_sum    = mantissa_sum >> 1;
            exponent_result = exponent_result + 9'd1;
        end else begin
            // subtraction may require left shifts to restore the leading 1
            for (int i = 0; i < 23; i++) begin
                if (!mantissa_sum[23] &&
                    mantissa_sum != 25'd0 &&
                    exponent_result > 9'd1) begin
                    mantissa_sum    = mantissa_sum << 1;
                    exponent_result = exponent_result - 9'd1;
                end
            end
        end

        // handle zero inputs, cancellation, overflow, and underflow
        if ((a[30:0] == 31'd0) && (b[30:0] == 31'd0))
            res = {a[31] & b[31], 31'd0};
        else if (a[30:0] == 31'd0)
            res = b;
        else if (b[30:0] == 31'd0)
            res = a;
        else if (mantissa_sum == 25'd0)
            res = 32'd0;
        else if (exponent_result >= 9'd255)
            res = {sign_result, 8'hFF, 23'd0};
        else if (!mantissa_sum[23])
            res = {sign_result, 31'd0};
        else
            res = {
                sign_result,
                exponent_result[7:0],
                mantissa_sum[22:0]
            };
    end
endmodule
