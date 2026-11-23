# tiny-tpu

A TPU-inspired accelerator targeting small neural network training and inference. Designed around a weight-stationary 2×2 systolic MAC array with FP8 (E4M3FN) operands and FP32 accumulation. Written in SystemVerilog, targeting ASIC implementation in SkyWater’s 130 nm process using the high-density standard-cell library.

This project aims to explore data parallelism and how hardware can accelerate machine learning (ML) workloads.

The accelerator will be used to train a nanoGPT model on Shakespeare verses, inspired by Andrej @karpathy.

**Status:** In Progress

Target timeline is tapeout on the Tiny Tapeout SKY 26e shuttle.

 

## Tiny Tapeout
### What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip. To learn more and get started, visit https://tinytapeout.com.

