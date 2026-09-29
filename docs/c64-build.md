# C64 Build and VICE Test Workflow

The rewrite uses VASM to assemble the 6502 source. The normal test artifact is a **C64 PRG** that can be loaded directly into VICE.

## Requirements

- vasm6502_mot in PATH
- make
- VICE (x64sc) for emulator testing

## Build the PRG

From the repository root:

    make

The default target creates:

    build/otter_raid.prg

The PRG includes the C64 load address ($0801) and is the normal artifact for C64/VICE testing.

You can also use the explicit target:

    make prg

## Launch in VICE

If x64sc is installed:

    make run

This builds build/otter_raid.prg and launches it with VICE.

You can choose a different VICE executable:

    make VICE=/path/to/x64sc run

## Raw binary

A raw assembled binary is available when needed:

    make bin

This creates:

    build/otter_raid.bin

The .bin file contains only the assembled bytes and does not contain the two-byte C64 PRG load address. It is not the normal file to load into VICE.

## Choose another source file

This is useful for the river-only prototype:

    make SRC=c64/river_prototype.asm

The selected source is assembled into:

    build/otter_raid.bin
    build/otter_raid.prg

Once the river prototype exists, the normal development loop can be:

    make SRC=c64/river_prototype.asm

or build and launch it directly with:

    make SRC=c64/river_prototype.asm run

## Choose another assembler

If VASM is not in PATH:

    make VASM=/path/to/vasm6502_mot

## Clean

    make clean

This removes the generated build/ directory.

## Prototype workflow

For the gameplay-engine rewrite, the intended loop is:

1. Edit the prototype source.
2. Build the PRG.
3. Start/test the PRG in VICE.
4. Fix the prototype.
5. Repeat.

Keeping generated files under build/ means compiled output does not clutter the repository.
