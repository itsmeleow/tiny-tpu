"""E4M3FN multiplier reference. Port values are unsigned integer bit patterns."""

from operator import index

import ml_dtypes
import numpy as np


FP8 = ml_dtypes.float8_e4m3fn


def fp8_to_float32(bits: int) -> np.float32:
    """Decode a raw FP8 byte, including signed zero, subnormals, and NaNs."""
    bits = index(bits)
    if not 0 <= bits <= 0xFF:
        raise ValueError("expected an 8-bit E4M3FN encoding")
    return np.uint8(bits).view(FP8).astype(np.float32)


def fp8_mul_model(a_bits: int, b_bits: int) -> int:
    """Return the FP32 product bits, using the multiplier's canonical quiet NaN."""
    a = fp8_to_float32(a_bits)
    b = fp8_to_float32(b_bits)
    if np.isnan(a) or np.isnan(b):
        return 0x7FC00000
    # Every finite E4M3FN product is exactly representable in binary32.
    return int((a * b).view(np.uint32))
