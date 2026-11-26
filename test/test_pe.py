import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly


@cocotb.test()
async def test_pe(dut):
    Clock(dut.clk, 100, unit="ns").start(start_high=False)

    # reset pe
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0

    # preload weight
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.weight_load.value = 1
    dut.weight_in.value = 0x40
    dut.step_en.value = 0
    await RisingEdge(dut.clk)

    # compute pe
    dut.weight_load.value = 0
    dut.weight_in.value = 0x48
    dut.step_en.value = 1
    dut.in_valid.value = 1
    dut.activation_in.value = 0x44
    dut.psum_in.value = 0x3F800000

    await RisingEdge(dut.clk)
    await ReadOnly()

    # check that pe streams activation out
    assert int(dut.out_valid.value) == 1
    assert int(dut.activation_out.value) == 0x44

    # assert for correct pe partial sum output
    actual = int(dut.psum_out.value)
    expected = 0x40E00000
    assert actual == expected, (f"PE output: expected 0x{expected:08X}, got 0x{actual:08X}")


    # Test 2
    
