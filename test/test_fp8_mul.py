import cocotb
from cocotb.triggers import Timer

from sim.fp8_model import fp8_mul_model

# Tests all valid fp8 multiplication pairs - 65,536 pairs
@cocotb.test()
async def test_fp8_mul(dut):
    # multiply from [0x00 * 0xFF], [0x00 * 0xFE], ... [0xFF * 0x00]
    a = 0x00
    b = 0xFF
    checked = 0

    for a in range(256):
        b = 0xFF
        for b in range(255, -1, -1):
            expected = fp8_mul_model(a,b)
            dut.a.value = a
            dut.b.value = b
            await Timer(1, unit="ns")
            actual = int(dut.res.value)
            assert actual == expected, (
                f"a: 0x{a:02X}, b: 0x{b:02X} | "
                f"expected 0x{expected:08X}, got 0x{actual:08X}"
            )
            checked+=1
    expected_checks = 256 * 256
    assert checked == expected_checks
    dut._log.info("=====Verified %d/%d fp8 multiplication pairs!====", expected_checks, 256*256)
            

    