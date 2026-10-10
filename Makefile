# Otter Raid C64 build
#
# Default:
#   make
#
# Useful targets:
#   make prg       Build build/otter_raid.prg for VICE/C64
#   make run       Build and launch with VICE (x64sc)
#   make assets    Regenerate graphics data from gfx/ sources (needs python3)
#   make clean     Remove the PRG and listing (keeps previews)
#
# Override tools/paths as needed:
#   make VASM=/path/to/vasm6502_oldstyle
#   make VICE=/path/to/x64sc

VASM ?= vasm6502_oldstyle
VASMFLAGS ?= -Fbin -cbm-prg -dotdir -quiet
VICE ?= x64sc
PYTHON ?= python3

SRC ?= c64/main.asm
BUILD_DIR ?= build
PRG ?= $(BUILD_DIR)/otter_raid.prg
LIST ?= $(BUILD_DIR)/otter_raid.lst

# Every assembler source can be pulled in through includes.
ASM_DEPS := $(wildcard c64/*.asm c64/*/*.asm)

.PHONY: all prg run assets clean

all: prg

prg: $(PRG)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# vasm writes the two-byte PRG load address itself (-cbm-prg).
$(PRG): $(ASM_DEPS) | $(BUILD_DIR)
	$(VASM) $(VASMFLAGS) -L $(LIST) -o $@ $(SRC)

run: $(PRG)
	$(VICE) -autostart $(PRG)

assets:
	$(PYTHON) tools/gfx.py

clean:
	rm -f $(PRG) $(LIST)
