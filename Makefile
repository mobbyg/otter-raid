VASM ?= vasm6502_mot
VASMFLAGS ?= -Fbin

SRC ?= c64/otter_raid_c64.asm
OUT ?= otter_raid.prg

all: $(OUT)

$(OUT): $(SRC)
	$(VASM) $(VASMFLAGS) -o otter_raid.bin $<
	printf '\x01\x08' > $@
	cat otter_raid.bin >> $@
	rm -f otter_raid.bin

clean:
	rm -f $(OUT) otter_raid.bin

.PHONY: all clean
