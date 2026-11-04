/*
 * =========================================
 * FP8 Floating-Point Formats
 *
 * Reference: "FP8 Formats for Deep Learning" (arxiv 2209.05433)
 *
 * FP8 defines two encodings:
 *   E4M3: 1 sign bit, 4 exponent bits, 3 fraction bits.
 *   E5M2: 1 sign bit, 5 exponent bits, 2 fraction bits.
 *
 * The paper recommends:
 *   E4M3 for weights and activations.
 *   E5M2 for gradients.
 *
 * E4M3 bit layout: S EEEE FFF
 *   [7]   : Sign bit (1 = negative).
 *   [6:3] : Exponent, stored with a bias of 7.
 *   [2:0] : Fraction (trailing significand).
 *
 * For normal finite values:
 *   value = (-1)^S * 2^(E - 7) * (1 + F/8)
 *
 * The implied leading 1 is not stored in the fraction field.
 *
 * Minimum positive normal value: 2^-6
 * Maximum positive finite value: 448
 * 
 * =========================================
 *
 * FP32 Floating-Point Format (IEEE-754 binary32)
 *
 * FP32 consists of:
 *   1 sign bit, 8 exponent bits, and 23 fraction bits.
 *
 * Bit layout: S EEEEEEEE FFFFFFFFFFFFFFFFFFFFFFF
 *   [31]    : Sign bit (1 = negative).
 *   [30:23] : Exponent, stored with a bias of 127.
 *   [22:0]  : Fraction (trailing significand).
 *
 * For normal finite values (1 <= E <= 254):
 *   value = (-1)^S * 2^(E - 127) * (1 + F/2^23)
 *
 * The implied leading 1 is not stored in the fraction field.
 * Normal values therefore have 24 bits of significand precision.
 *
 * Special encodings:
 *   E =   0, F = 0 : Signed zero.
 *   E =   0, F > 0 : Subnormal; no implied leading 1.
 *   E = 255, F = 0 : Signed infinity.
 *   E = 255, F > 0 : NaN (Not a Number).
 *
 * Minimum positive normal value:    2^-126
 * Minimum positive subnormal value: 2^-149
 * Maximum positive finite value:    (2 - 2^-23) * 2^127
 *                                  approximately 3.4028235e38
 * =========================================
 */

package fp_pkg;
    // constants for FP8
    localparam FP8_EXP_WIDTH = 4;
    localparam FP8_FRA_WIDTH = 3;

    // constants for FP32
    localparam FP32_EXP_WIDTH = 8;
    localparam FP32_FRA_WIDTH = 23;

    localparam int signed FP8_BIAS  = 7;
    localparam int signed FP32_BIAS = 127;
    
    typedef struct packed {
        logic                     sign;
        logic [FP8_EXP_WIDTH-1:0] exponent;
        logic [FP8_FRA_WIDTH-1:0] fraction;
    } fp8_e4m3_t;

    typedef struct packed {
        logic                      sign;
        logic [FP32_EXP_WIDTH-1:0] exponent;
        logic [FP32_FRA_WIDTH-1:0] fraction;
    } fp32_t;
endpackage
