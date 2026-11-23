/* 
 * Vector Processing Unit (VPU)
 *
 */

module vpu 
    import fp_pkg::*;
(
    input  fp32_t a,
    input  fp32_t b,
    output fp32_t result
);

    // Simple vector addition for now
    assign result = a + b;

endmodule
