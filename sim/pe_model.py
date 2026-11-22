"""Arithmetic reference for a valid PE step with an already-loaded weight."""

from operator import index

from .fp8_model import fp8_mul_model


def fp32_add_model(a_bits: int, b_bits: int) -> int:
    """Add raw FP32 words with the TPU's truncating alignment and normalization.

    The adder specifies normal finite operands and signed zeros. An overflow
    produces signed infinity, and a subnormal result flushes to signed zero.
    """
    a, b = index(a_bits), index(b_bits)
    for word in (a, b):
        if not 0 <= word <= 0xFFFFFFFF:
            raise ValueError("expected a 32-bit FP32 encoding")
        magnitude = word & 0x7FFFFFFF
        if magnitude and not 0x00800000 <= magnitude < 0x7F800000:
            raise ValueError("FP32 accumulator operands must be normal or zero")

    if (a & 0x7FFFFFFF) == 0 and (b & 0x7FFFFFFF) == 0:
        return a & b  # -0 + -0 gives -0
    if (a & 0x7FFFFFFF) == 0:
        return b
    if (b & 0x7FFFFFFF) == 0:
        return a

    exponent_a = (a >> 23) & 0xFF
    exponent_b = (b >> 23) & 0xFF
    exponent = max(exponent_a, exponent_b)
    # Truncate magnitudes before applying signs, including for subtraction.
    mantissa_a = (0x800000 | (a & 0x7FFFFF)) >> (exponent - exponent_a)
    mantissa_b = (0x800000 | (b & 0x7FFFFF)) >> (exponent - exponent_b)
    total = (-mantissa_a if a >> 31 else mantissa_a) + (
        -mantissa_b if b >> 31 else mantissa_b
    )
    if total == 0:
        return 0

    sign = 0x80000000 if total < 0 else 0
    magnitude = abs(total)
    shift = magnitude.bit_length() - 24
    exponent += shift
    if exponent <= 0:
        return sign
    if exponent >= 255:
        return sign | 0x7F800000
    normalized = magnitude >> shift if shift >= 0 else magnitude << -shift
    return sign | (exponent << 23) | (normalized & 0x7FFFFF)


def pe_model(activation_bits: int, weight_bits: int, psum_bits: int = 0) -> int:
    """Return psum_out bits for finite FP8 operands and a normal or zero psum."""
    return fp32_add_model(psum_bits, fp8_mul_model(activation_bits, weight_bits))
