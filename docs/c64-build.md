# C64 Build and VICE Test Workflow

## Requirements

| Tool | Used for |
|---|---|
| `vasm6502_oldstyle` (vasm, 6502 oldstyle syntax) | assembling |
| `make` | build driver |
| `x64sc` (VICE) | running and testing |
| `python3` | asset compilers and the test driver |
| `Xvfb` | headless VICE runs (`tools/vicetest.py`) |

## Build

From the repository root:

    make            # same as: make prg

| Output | Content |
|---|---|
| `build/otter_raid.prg` | the C64 program: load address `$0801`, BASIC line `10 SYS2061`, entry `start` at `$080D` |
| `build/otter_raid.lst` | vasm listing with the symbol table at the end (read by `tools/vicetest.py`) |

The Makefile runs:

    vasm6502_oldstyle -Fbin -cbm-prg -dotdir -quiet \
        -L build/otter_raid.lst -o build/otter_raid.prg c64/main.asm

`-cbm-prg` writes the two-byte load address and `-dotdir` enables the
dotted directives (`.byte`, `.org`, `.rept`, ...). The single PRG holds
everything from `$0801` up to the end of the sound data at
`$8000-$9FFF` (see `docs/c64-memory-map.md`). Every `c64/*.asm` and
`c64/*/*.asm` file is a dependency.

| Target | Does |
|---|---|
| `make run` | build, then `x64sc -autostart build/otter_raid.prg` |
| `make assets` | `python3 tools/gfx.py`: regenerate `c64/gfx/*.asm` from `gfx/*.gfx` and write previews to `build/gfx_preview/` (`docs/c64-graphics.md`) |
| `make clean` | remove `build/` |

Sound data is regenerated with `python3 tools/music.py` from `music/`
(`docs/c64-sound.md`). The generated `.asm` files live in `c64/gfx/`
and `c64/sound/`, so a plain `make` needs neither Python script.

Overrides: `make VASM=/path/to/vasm6502_oldstyle`,
`make VICE=/path/to/x64sc`, `make PYTHON=python3.12`,
`make VASMFLAGS=...`.

## Source layout

`c64/main.asm` is the only file passed to the assembler. It includes:

| File | Role |
|---|---|
| `defs.asm`, `memory.asm`, `palette.asm` | hardware constants, **all RAM allocation**, shared colors |
| `gfx/gfx_ids.asm`, `sound/sound_ids.asm` | character, sprite, stamp and sound ids |
| `system.asm` | machine setup, raster IRQ chain, frame handshake, sprite latch |
| `display.asm` | double-buffered vertical scroll |
| `river_engine.asm` | river generator, row renderer, `river_limits` |
| `input.asm`, `player.asm`, `enemies.asm`, `eagle.asm` | input, Ollie, gators, eagle |
| `hud.asm`, `game.asm`, `screens.asm`, `home.asm`, `demo.asm` | HUD, game states, title screens, homecoming, attract demo |
| `gfx/gfx_tables.asm` | edge LUTs, stamp tables, animation data |
| `sound/sound.asm`, `sound/music_data.asm`, `sound/sfx_data.asm` (at `$8000`) | SID player, music and effects (`-DSOUND_STUB=1` builds silent with `sound_stub.asm`) |
| `gfx/charset_game.asm`, `gfx/charset_text.asm`, `gfx/sprites.asm` | VIC bank data at `$4800`, `$5000`, `$5800` |

Not built: `c64/otter_raid_c64.asm` (the legacy game), and the old
prototype files `c64/river.asm`, `river_prototype.asm`,
`river_render.asm` and `constants.asm`.

## Headless testing with `tools/vicetest.py`

`Vice` drives one x64sc session through its remote monitor:

1. It starts a private `Xvfb` display (no window appears).
2. It runs `x64sc -default -sounddev dummy -warp -remotemonitor` on
   `127.0.0.1:6510` and autostarts the PRG.

| Call | Does |
|---|---|
| `load_symbols("build/otter_raid.lst")` | `{name: address}` from the listing |
| `Vice(prg, port=6510, warp=True, headless=True, log=None)` | start the emulator; `Vice(None)` starts it without a program |
| `v.connect()` | wait for boot, attach to the monitor (the C64 pauses); **call it first** |
| `v.break_at(addr)` / `v.delete_breaks()` | set or clear breakpoints |
| `v.cont()` / `v.run_frames(n)` | run to the next breakpoint, or through `n` hits |
| `v.screenshot(path)` | save a PNG of the current screen |
| `v.mem(addr, n)` / `v.poke(addr, *bytes)` / `v.regs()` | read RAM, write RAM, read registers |
| `v.load_and_go(prg, 0x080D)` | load through the monitor and jump, so breakpoints can be set before the program starts |
| `v.cmd(text)` | any raw monitor command |

```python
import sys; sys.path.insert(0, "tools")
from vicetest import Vice, load_symbols
sym = load_symbols("build/otter_raid.lst")
with Vice("build/otter_raid.prg") as v:
    v.connect()
    v.break_at(sym["main_loop"])       # one hit per prepared frame
    v.run_frames(300)
    v.poke(sym["in_override"], 0x10)   # hold FIRE
    v.run_frames(30)
    v.screenshot("shot.png")
    print(v.mem(sym["lp_lo"], 2))
```

**Input hook.** `in_override` (`$62`): any non-zero value replaces the
joystick and keyboard bits every frame (`IN_UP` 1, `IN_DOWN` 2,
`IN_LEFT` 4, `IN_RIGHT` 8, `IN_FIRE` `$10`, `IN_PAUSE` `$20`,
`IN_START` `$40`). Write 0 to return to real input. `in_new` edges are
still derived from it, so an override gives one press edge when it
starts.

**Profiling.** Set the `debug_profile` byte to non-zero to show the
main thread's busy time as a red border band.

## Running by hand

    make run                 # or: x64sc -autostart build/otter_raid.prg

Use joystick port 2 or W/A/S/D, SPACE to dive, P to pause and RETURN
in the menus.

## Changed from the original workflow

- `vasm6502_mot` was replaced by `vasm6502_oldstyle` with `-cbm-prg`,
  so the PRG header is written by vasm.
- `make bin` and `SRC=c64/river_prototype.asm` are gone; the default
  source is `c64/main.asm`.
- DASM is no longer supported: the source uses vasm macros, `.rept`
  and `.ifdef`.
