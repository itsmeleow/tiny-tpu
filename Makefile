FP_PACKAGE := src/fp_lib/fp_pkg.sv
SV_SOURCES := $(shell find src -type f -name '*.sv' ! -path '$(FP_PACKAGE)' | sort)
GENERATED  := src/tpu_generated.v

# sv2v (SystemVerilog -> Verilog)
# TT Yosys is configured for Verilog support, therefore, SystemVerilog slang is not supported.
# This approach utilizes the sv2v tool to convert all (.sv) files into a single (.v) file
.PHONY: sv2v
sv2v:
	sv2v -I src -I src/fp_lib $(FP_PACKAGE) $(SV_SOURCES) > $(GENERATED).tmp
	mv $(GENERATED).tmp $(GENERATED)
