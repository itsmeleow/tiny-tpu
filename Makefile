FP_PACKAGE := src/fp_lib/fp_pkg.sv
SV_SOURCES := $(shell find src -type f -name '*.sv' ! -path '$(FP_PACKAGE)' | sort)
GENERATED  := src/tiny_tpu_generated.v

.PHONY: sv2v
sv2v:
	sv2v -I src -I src/fp_lib $(FP_PACKAGE) $(SV_SOURCES) > $(GENERATED).tmp
	mv $(GENERATED).tmp $(GENERATED)
