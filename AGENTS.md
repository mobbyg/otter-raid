# Repository Guidelines

## Project Structure & Module Organization
- `c64/main.asm` — Entry point (BASIC stub `SYS 2061`), main loop, and the
  include list; the only file passed to the assembler.
- `c64/memory.asm` — The **only** place RAM is allocated (zero page, buffers,
  VIC bank 1 layout). Add new variables here, never ad hoc in a module.
- `c64/defs.asm`, `c64/palette.asm` — Hardware constants, shared colors.
- Engine modules: `system.asm` (setup, raster IRQ chain, frame handshake),
  `display.asm` (double-buffered scroll), `river_engine.asm`, `input.asm`,
  `player.asm`, `enemies.asm` (gators), `eagle.asm`, `hud.asm`, `game.asm`
  (state machine, scoring), `screens.asm` (title/menus/high scores),
  `home.asm`, `demo.asm`.
- `c64/gfx/` — Generated graphics data (from `gfx/*.gfx` via `tools/gfx.py`).
  `c64/sound/` — SID player and generated music/SFX (from `music/` via
  `tools/music.py`). Don't hand-edit generated files.
- `tools/` — `gfx.py`, `music.py`, `vicetest.py` (headless VICE driver).
- `docs/` — Design docs; `c64-*.md` describe the implemented engine.
- Legacy, not built: `c64/otter_raid_c64.asm`, `c64/river*.asm` other than
  `river_engine.asm`, `c64/constants.asm`; root `otter_raid.*` artifacts.
- Output: `build/otter_raid.prg` and listing `build/otter_raid.lst`.

## Build, Test, and Development Commands
- `make` — Assemble `c64/main.asm` with `vasm6502_oldstyle -Fbin -cbm-prg
  -dotdir -quiet` to `build/otter_raid.prg` (+ `build/otter_raid.lst`).
  - Override: `make VASM=/path/to/vasm6502_oldstyle VASMFLAGS='...'`
- `make run` — Build and launch `x64sc -autostart build/otter_raid.prg`
  (entry is `SYS 2061`, `start` at `$080D`).
- `make assets` — Regenerate `c64/gfx/*.asm` from `gfx/` (python3).
- `python3 tools/music.py` — Regenerate `c64/sound/*_data.asm` from `music/`.
- `make clean` — Remove `build/`.
- DASM is no longer supported (vasm macros/`.rept`/`.ifdef`).

## Coding Style & Naming Conventions
- Labels: flush-left, trailing colon. Instructions: one tab indent. Comments with `;` after two spaces.
- Constants/hardware registers: `UPPER_SNAKE_CASE` (e.g., `SCREEN`, `VIC_BORDER`).
- Routines/variables: `lower_snake_case` (e.g., `update_score`, `hit_cooldown`).
- Keep lines ≤80 chars; group related code with clear `; =====` banners.
- Example:
  ```asm
  start:
	lda #0
	sta score      ; reset score
	jsr update_score
  ```

## Testing Guidelines
- Build must succeed via `make` (vasm). Read the listing for symbol addresses.
- Headless checks: `tools/vicetest.py` starts Xvfb + `x64sc` with the remote
  monitor; use `load_symbols("build/otter_raid.lst")`, `Vice(prg)`,
  `connect()`, `break_at()`, `run_frames()`, `screenshot()`, `mem()`,
  `poke()`. Drive input by poking `in_override` (`$62`, nonzero = IN_* bits).
  Set `debug_profile` nonzero to see main-thread time as a red border band.
- Sanity run: PRG auto-starts to the title; START GAME runs; joystick 2 /
  WASD steer within the banks; dive, gators, eagle, crawfish, HUD score/LP/
  hearts update; no raster artifacts at the HUD/band/playfield splits.
- Main thread must finish a frame before the line-250 vblank IRQ (PAL budget
  ~19.6k cycles); an overrun repeats a frame. See
  `docs/c64-frame-update-flow.md`.
- If you change memory layout, re-check: `memory.asm` ranges don't overlap;
  code ends below `$4000`; screens `$4000`/`$4400`, sprite pointers
  `$43F8`/`$47F8` (both written by `sprites_latch`), charsets `$4800`/`$5000`,
  sprites `$5800+`, idle byte `$7FFF` = 0, color RAM `$D800`, sound
  `$8000-$9FFF`, sound zero page `$E0-$EF`.

## Commit & Pull Request Guidelines
- Use imperative, concise subjects (≤50 chars). Include a scope when helpful: `river`, `sprite`, `UI`.
  - Examples: `Add river scroll step`, `Fix fish wrap logic`, `Tune collision cooldown`.
- PRs should include:
  - What changed and why; any registers/memory affected.
  - Repro steps: `make clean && make` and optional emulator command.
  - Screenshots/GIFs welcome for gameplay changes.

## Toolchain & Environment
- Requires `vasm6502_oldstyle`; VICE (`x64sc`) recommended for testing;
  `python3` for asset tools; `Xvfb` for headless tests.
- You can override assembler via `VASM=...` and flags via `VASMFLAGS=...`.

## Agent-Specific Notes
- Keep patches minimal and localized; avoid whole-file reformatting. Update `README.md` if commands or entry points change.
- Keep `docs/c64-*.md` in sync when changing engine behaviour or memory use.
