/*
 * Vector Processing Unit (VPU)
 */

module vpu #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
) (
    input  logic [ACC_WIDTH-1:0]  fp32_in,
    input  logic [2:0]            vpu_op,

    output logic [DATA_WIDTH-1:0] fp8_out,
    output logic [ACC_WIDTH-1:0]  fp32_out
);
    typedef enum logic [2:0] {
        BYPASS = 3'b000,
        RELU   = 3'b001
    } vpu_op_t;

    // activation stage, simple bypass + relu for now
    always_comb begin
        case (vpu_op)
            BYPASS:  fp32_out = fp32_in;
            RELU:    fp32_out = fp32_in[31] ? '0 : fp32_in;
            default: fp32_out = fp32_in;
        endcase
    end

    // FP32 -> FP8 (E4M3) downcast (truncation, flush subnormals to 0)
    logic       s32;
    logic [7:0] e32;
    logic [2:0] m32_top;
    logic [7:0] e8_unbiased;

    assign s32         = fp32_out[31];
    assign e32         = fp32_out[30:23];
    assign m32_top     = fp32_out[22:20];
    assign e8_unbiased = e32 - 8'd120; // bias_32 (127) - bias_e4m3 (7) = 120

    always_comb begin
        if (e32 == 8'hFF && fp32_out[22:0] != 23'd0) begin
            // FP32 NaN -> E4M3 NaN (0x7F / 0xFF)
            fp8_out = {s32, 4'b1111, 3'b111};
        end else if (e32 < 8'd121) begin
            // Zero or underflow (< 2^-6) -> flush to +0.0
            fp8_out = 8'h00;
        end else if (e32 > 8'd135 || (e32 == 8'd135 && m32_top == 3'b111)) begin
            // Overflow (> 448.0) or FP32 Inf -> saturate to +-448.0 (avoid E4M3 NaN)
            fp8_out = {s32, 4'b1111, 3'b110};
        end else begin
            // Normal range (e32 in 121..135 -> e8 in 1..15)
            fp8_out = {s32, e8_unbiased[3:0], m32_top};
        end
    end
endmodule
