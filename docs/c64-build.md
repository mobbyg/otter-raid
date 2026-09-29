# C64 Build and VICE Test Workflow

The rewrite uses VASM to assemble the 6502 source and produces both a raw binary and a C64 PRG.

## Requirements

- vasm6502_mot in PATH
- make
- VICE (x64sc) for emulator testing

## Build

From the repository root:

    make

The default target creates:

    build/otter_raid.prg

The PRG includes the C64 load address ($0801) and can be opened directly in VICE.

## Raw binary

To generate only the assembled machine-code bytes:

    make bin

This creates:

    build/otter_raid.bin

The .bin file is the raw assembled output and does not contain the two-byte C64 PRG load address. For normal VICE testing, use the .prg.

## Build explicitly

    make prg

Equivalent to the default make target.

## Launch in VICE

If x64sc is installed:

    make run

You can also choose a different VICE executable:

    make VICE=/path/to/x64sc run

## Choose another source file

This is useful for the river-only prototype:

    make SRC=c64/river_prototype.asm

The resulting files remain:

    build/otter_raid.bin
    build/otter_raid.prg

## Choose another assembler

If VASM is not in PATH:

    make VASM=/path/to/vasm6502_mot

## Clean

    make clean

This removes the generated build/ directory.

## Prototype workflow

For the gameplay-engine rewrite, the intended loop is:

1. Edit the prototype source.
2. Run make.
3. Start/test build/otter_raid.prg in VICE.
4. Fix the prototype.
5. Repeat.

Keeping generated files under build/ means compiled output does not clutter the repository.
