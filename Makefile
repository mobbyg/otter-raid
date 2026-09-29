# Otter Raid C64 build
#
# Default:
#   make
#
# Useful targets:
#   make prg       Build build/otter_raid.prg for VICE/C64
#   make bin       Build build/otter_raid.bin (raw assembled bytes)
#   make run       Build and launch with VICE (x64sc)
#   make clean     Remove build output
#
# Override tools/paths as needed:
#   make VASM=/path/to/vasm6502_mot
#   make VICE=/path/to/x64sc
#   make SRC=c64/my_test.asm

VASM ?= vasm6502_mot
VASMFLAGS ?= -Fbin
VICE ?= x64sc

SRC ?= c64/river_prototype.asm
BUILD_DIR ?= build
BIN ?= $(BUILD_DIR)/otter_raid.bin
PRG ?= $(BUILD_DIR)/otter_raid.prg

.PHONY: all prg bin run clean

all: prg

prg: $(PRG)

bin: $(BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN): $(SRC) | $(BUILD_DIR)
	$(VASM) $(VASMFLAGS) -o $@ $<

# C64 PRG files begin with the two-byte load address.
# The current source is assembled for $0801.
$(PRG): $(BIN)
	printf '\001\010' > $@
	cat $< >> $@

run: $(PRG)
	$(VICE) $(PRG)

clean:
	rm -rf $(BUILD_DIR)
