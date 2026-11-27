/*
 * FP32 Addition
 * Add two FP32 operands and produce a FP32 result.
 * - Supports normal finite inputs and zero; subnormal results are flushed to zero.
 */
module fp32_add
    import fp_pkg::*;
(
    input  fp32_t a,
    input  fp32_t b,
    output fp32_t res
);
    logic        a_ge_b;
    logic        sign_result;
    logic [7:0]  exp_big, exp_small, exp_diff;
    logic [23:0] mant_big, mant_small, mant_small_aligned;
    logic [24:0] mant_sum;

    logic [23:0] norm_mant;
    logic [4:0]  lz;
    logic [8:0]  exp_carry;
    logic [7:0]  exp_sub;

    always_comb begin
        // order by magnitude so big >= small always
        a_ge_b      = (a[30:0] >= b[30:0]);
        sign_result = a_ge_b ? a[31]           : b[31];
        exp_big     = a_ge_b ? a[30:23]        : b[30:23];
        exp_small   = a_ge_b ? b[30:23]        : a[30:23];
        mant_big    = a_ge_b ? {1'b1, a[22:0]} : {1'b1, b[22:0]};
        mant_small  = a_ge_b ? {1'b1, b[22:0]} : {1'b1, a[22:0]};

        // single exponent subtractor + single 5-bit alignment shifter
        exp_diff = exp_big - exp_small;
        mant_small_aligned = (exp_diff >= 8'd24) ? 24'd0 : (mant_small >> exp_diff[4:0]);

        // single 25-bit add/sub (non-negative because big >= small)
        if (a[31] == b[31])
            mant_sum = {1'b0, mant_big} + {1'b0, mant_small_aligned};
        else
            mant_sum = {1'b0, mant_big} - {1'b0, mant_small_aligned};

        // 5-stage binary LZC + fused left-normalizer
        norm_mant = mant_sum[23:0];
        lz        = 5'd0;
        if (norm_mant[23:8]  == 16'd0) begin lz[4] = 1'b1; norm_mant = {norm_mant[7:0],  16'd0}; end
        if (norm_mant[23:16] ==  8'd0) begin lz[3] = 1'b1; norm_mant = {norm_mant[15:0],  8'd0}; end
        if (norm_mant[23:20] ==  4'd0) begin lz[2] = 1'b1; norm_mant = {norm_mant[19:0],  4'd0}; end
        if (norm_mant[23:22] ==  2'd0) begin lz[1] = 1'b1; norm_mant = {norm_mant[21:0],  2'd0}; end
        if (norm_mant[23]    ==  1'b0) begin lz[0] = 1'b1; norm_mant = {norm_mant[22:0],  1'd0}; end

        exp_carry = {1'b0, exp_big} + 9'd1;
        exp_sub   = exp_big - {3'd0, lz};

        // pack result (zero, cancellation, overflow, underflow)
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
                res = {sign_result, 8'hFF, 23'd0};
            else
                res = {sign_result, exp_carry[7:0], mant_sum[23:1]};
        end else begin
            if (exp_big <= {3'd0, lz})
                res = {sign_result, 31'd0};
            else
                res = {sign_result, exp_sub, norm_mant[22:0]};
        end
    end
endmodule
