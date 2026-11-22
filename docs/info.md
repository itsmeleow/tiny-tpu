<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
# tiny-tpu

A TPU-inspired accelerator targeting small neural network training and inference. Designed around a weight-stationary 2×2 systolic MAC array with FP8 (E4M3FN) operands and FP32 accumulation. Written in SystemVerilog, targeting ASIC implementation in SkyWater’s 130 nm process using the high-density standard-cell library.

## How it works

The host writes four E4M3FN weights through `ui_in` and loads them into the 2×2 array. Each activation row contains two FP8 values. The array multiplies that row by the weight matrix and returns one FP32 sum per column.

## How to test

Assert `ena`, hold `rst_n` low across a rising clock edge, then release reset. Drive commands on `uio_in[2:0]` before each rising edge.

1. Write each weight with command 1, its FP8 byte on `ui_in`, its row on `uio_in[4]`, and its column on `uio_in[3]`. Issue command 2 once to load all four weights.
2. Stage the first activation byte with command 3 and push the second with command 4. For a simple test, use identity weights (0x38 on the diagonal, 0x00 elsewhere) and push 0x38 and 0x40 for the row [1, 2].
3. Issue command 5 to drain one step. Select command 6 to read status. Bit 0 of `uo_out` indicates column 0 is valid. Use command 0, select column 0 on `uio_in[5]`, and read its four bytes from `uo_out` by setting `uio_in[7:6]` to 0 through 3, least significant byte first. The expected FP32 word is 0x3F800000.
4. Drain one more step. Status bit 1 now indicates column 1 is valid. Select column 1 and read 0x40000000 the same way.

## External hardware

A digital host supplies the clock, drives the commands and operand bytes, and samples the result bus.
