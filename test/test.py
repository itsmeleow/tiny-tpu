# SPDX-FileCopyrightText: © 2026 Leo Wang (itsmeleow)
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import Timer

from sim.matmul_model import matmul_model


@cocotb.test()
async def test_matrix_multiply(dut):
    """Load weights, stream two activation rows, and read both result columns."""
    WRITE_WEIGHT, LOAD_WEIGHTS, STAGE_A0, PUSH_ROW, DRAIN, READ_STATUS = range(1, 7)

    async def tick(command, data=0):
        dut.uio_in.value = command
        dut.ui_in.value = data
        await Timer(50, unit="ns")
        dut.clk.value = 1
        await Timer(50, unit="ns")
        dut.clk.value = 0

    async def read(command):
        dut.uio_in.value = command
        await Timer(50, unit="ns")
        return int(dut.uo_out.value)

    dut.clk.value = 0
    dut.ena.value = 1
    dut.rst_n.value = 0
    await tick(0)
    dut.rst_n.value = 1
    assert await read(READ_STATUS) == 0

    weights = [[0x42, 0xB8], [0x38, 0x40]]
    rows = [[0x38, 0x40], [0xBC, 0x41]]
    expected = matmul_model(rows, weights)
    for row, weight_row in enumerate(weights):
        for col, weight in enumerate(weight_row):
            await tick(WRITE_WEIGHT | (row << 4) | (col << 3), weight)
    await tick(LOAD_WEIGHTS)

    for step in range(len(rows) + 2):
        if step < len(rows):
            a0, a1 = rows[step]
            await tick(STAGE_A0, a0)
            await tick(PUSH_ROW, a1)
        else:
            await tick(DRAIN)

        # Column 0 is valid one step after the push, column 1 one step later.
        status = await read(READ_STATUS)
        for col in range(2):
            row = step - col - 1
            valid = 0 <= row < len(rows)
            assert ((status >> col) & 1) == valid, (step, col, status)
            if valid:
                word = 0
                for lane in range(4):
                    byte = await read((lane << 6) | (col << 5))
                    word |= byte << (8 * lane)
                assert word == expected[row][col], (row, col, hex(word), hex(expected[row][col]))
