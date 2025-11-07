VASM ?= vasm6502_mot
VASMFLAGS ?= -Fbin

all: otter_raid.prg

otter_raid.prg: otter_raid.asm
	$(VASM) $(VASMFLAGS) -o otter_raid.bin $<
	printf '\x01\x08' > $@
	cat otter_raid.bin >> $@
	rm -f otter_raid.bin

clean:
	rm -f otter_raid.prg otter_raid.bin

.PHONY: all clean
