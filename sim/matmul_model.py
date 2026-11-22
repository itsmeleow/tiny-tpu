"""Matrix result reference for the weight-stationary MXU."""

from collections.abc import Sequence

from .pe_model import pe_model


def matmul_model(
    activations: Sequence[Sequence[int]], weights: Sequence[Sequence[int]]
) -> list[list[int]]:
    """Multiply row-major M×K activations by K×N weights, given as finite FP8 bytes.

    Result [row][col] is the FP32 word on result[col] for that activation row.
    Each column accumulates from the top PE down, starting from positive zero.
    """
    depth = len(weights)
    if depth == 0 or len(weights[0]) == 0:
        raise ValueError("weights must have at least one row and column")
    columns = len(weights[0])
    if any(len(row) != columns for row in weights):
        raise ValueError("weight rows must all have the same length")

    results = []
    for row in activations:
        if len(row) != depth:
            raise ValueError("activation row length must equal the number of weight rows")
        sums = [0] * columns
        for activation, weight_row in zip(row, weights):
            for col, weight in enumerate(weight_row):
                sums[col] = pe_model(activation, weight, sums[col])
        results.append(sums)
    return results
