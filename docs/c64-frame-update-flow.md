# Otter Raid — C64 Frame Update Flow

How one frame is produced: the raster interrupt chain that builds the
screen, the handshake between the main loop and the IRQ, and the order
of work inside a PLAYING frame. Code: `c64/system.asm`,
`c64/display.asm`, `c64/main.asm`, `c64/game.asm`.

## Screen layout (PAL raster lines, `DM_GAME`)

| Lines | Content | VIC mode |
|---|---|---|
| 55-70 | HUD, screen A rows 0-1, text charset | hires text, `YSCROLL` 7 |
| 71-78 | black band | ECM+MCM (an invalid mode, which draws only black) |
| 79-246 | playfield rows 2-23, screen A or B, game charset | multicolor text, `YSCROLL` = (71+d) & 7 |
| 247+ | bottom border (`RSEL`=0, 24-row mode) | |

`d` is the fine scroll `cur_fine` (0-7). The display window is 24 rows
(`RSEL`=0) in every gameplay frame.

## Raster IRQ chain

| IRQ line | Handler | Work |
|---|---|---|
| 250 | `irq_vblank` | Set up the top of the next frame for `disp_mode` (GAME: HUD registers and `$D022` black; TEXT: 25-row hires text; BLANK: `$D011`=0). If `next_valid` is set, latch it: `cur_fine`, `cur_front`, `sprites_latch`, then clear `next_valid`. Then `inc frame_count` and `sound_update`. In GAME mode, chain to line 69. |
| 69 | `irq_split` | Wait for line 70. Write `$D011` = ECM + `split_d011_first[d]`, `$D016` = MCM, `$D018` = playfield screen A/B, `$D021-$D023` = playfield colors. When d=7, also wait for line 71 and write `YSCROLL` 6. Chain to 77. |
| 77 | `irq_play` | Wait for line 79, then write `$D011` with ECM off and `YSCROLL` = (71+d) & 7. Chain to 250. |

Text and blank modes use only the line-250 IRQ.

### Why the band exists

The VIC starts a character row on a *bad line*, the first line where
`(line & 7) == YSCROLL`. With the HUD's `YSCROLL` 7, row 2 would
naturally start at line 71. At line 70 the split writes
`YSCROLL = (71+d) & 7`, so the first playfield bad line moves to
`71+d`. This is an FLD-style delay: the whole playfield moves down by
`d` pixels without copying anything. The idle lines this delay creates
fall inside the band, so they show as black.

The 22 playfield rows are 176 lines tall, starting at `71+d`, but the
visible window from line 79 to line 246 is only 168 lines. Exactly one
row's worth of lines is always hidden: `8-d` lines of row 2 behind the
band and `d` lines of row 23 under the `RSEL`=0 bottom border. The new
top row slides in from behind the band and the old bottom row slides
out under the border, so no seam ever shows.

- **The d=7 two-step.** The target `YSCROLL` is 6, but line 70 itself
  has `70 & 7 = 6`, so writing 6 during line 70 would make line 70 a
  bad line. The split writes 5 first (no bad line before 77) and writes
  6 once line 71 has started (bad line at 78).
- **`$D022` black.** Between the `$D011` write (ECM on) and the
  `$D016` write (MCM on), line 70 is briefly in ECM text mode. In that
  mode HUD characters `$40-$7F` take their background from `$D022`, so
  the vblank IRQ sets `$D022` to black.

## Display modes (`disp_mode`)

| Mode | Used by | Screen |
|---|---|---|
| `DM_GAME` | PLAYING, PAUSED, LIFE_LOST, GAME_OVER, HOME | HUD + band + scrolling playfield |
| `DM_TEXT` | title, menu, high scores, controls, name entry | 25 rows of hires text from screen A |
| `DM_BLANK` | while a screen is rebuilt | display off (`$D011`=0) |

Only `irq_vblank` reads `disp_mode`, so a change takes effect at the
next vblank. Code that redraws a whole screen first sets `DM_BLANK` and
calls `frame_end`, so the screen is already off while it draws.

## Main loop and the frame handshake

```text
main_loop:
    input_read          ; joystick 2 + keys -> in_held / in_new
    game_frame          ; inc state_t, dispatch on game_state
    frame_end           ; publish, then wait for the latch
```

`frame_end` copies `fine_pos`/`front_buf` to `next_fine`/`next_front`,
sets `next_valid` and spins until the vblank IRQ clears it.

- **One prepared frame per pass.** The IRQ latches only when
  `next_valid` is set, which means only after main has finished a
  whole frame. Fine scroll, buffer swap and all sprite registers change
  together at line 250.
- **Overrun repeats a frame, it never tears.** If main is still busy
  at line 250, nothing is latched and the previous frame is shown
  again; main then waits for the following vblank. Game logic runs
  once per prepared frame, so an overrun slows the game down instead
  of skipping a step. `frame_count` (incremented by the IRQ) counts
  every vblank; `state_t` and the gameplay timers count main passes.
- **After `frame_end` returns**, a new frame has begun and the old
  front buffer is no longer on screen, so the back-buffer copy may
  start writing to it.
- **Writes that bypass the double buffer** are small and harmless:
  - HUD rows 0-1 of screen A;
  - a crawfish erase and its "pop" ring characters, written in the
    buffer being shown;
  - `river_animate` rewriting water and crawfish characters in the
    live charset every 8 frames;
  - color RAM on text screens.
- **Decimal mode.** `score_add` uses decimal mode inside `sei`/`plp`,
  because the IRQ (sound engine) does not clear the D flag.

## A PLAYING frame (`state_playing`)

During GET READY (`ready_t`, 90 frames after each run starts) only
`river_animate` and `player_sprite` run while the message blinks. The
river is frozen and input is ignored. After that, every frame runs:

| # | Call | Work |
|---:|---|---|
| 0 | `demo_check_end` | attract demo only: FIRE/RETURN or ~60 s ends it |
| 1 | `display_advance` | run one back-buffer copy stage if pending; add `scroll_speed` to the fine scroll; swap buffers on an 8-pixel step; set `scroll_delta` |
| 2 | `river_animate` | charset animation (every 8 frames) |
| 3 | `demo_ai` | attract demo only: replaces `in_held`/`in_new` |
| 4 | `player_update` | speed (sets `scroll_speed` for the next frame), steering, bank limits, dive, timers, effect sprite, Ollie's sprite |
| 5 | `gators_update` | spawn, drift, swim, shore check, collision, sprites |
| 6 | `eagle_update` | timer, warning, swoop, catch, carry, sprites |
| 7 | `play_progress` | per scrolled row: score, `safe_rows`, LP recovery, heart recovery; section milestone sound |
| 8 | `player_pickup` | crawfish under Ollie's head |
| 9 | `pop_update` | animate the ring where a crawfish was eaten |
| 10 | `hud_update` | redraw HUD parts that changed |
| 11 | transitions | P -> PAUSED; LP = 0 sets `LOSS_LP`; any `loss_cause` -> `lose_heart`; journey end -> HOME |

Hazards do not change the game state themselves. They lower Life
Points or set `loss_cause`, and step 11 is the only place that decides
the transition. A loss is checked before HOME, so Ollie cannot both
lose his last heart and arrive home in the same frame.

## Cost

| Budget | Cycles per frame |
|---|---:|
| PAL (312 lines x 63) | 19,656, minus bad-line and sprite DMA |
| NTSC (263 lines x 65) | 17,095, minus DMA |

Measured in VICE (headless, `tools/vicetest.py`) as the idle time the
main thread spends waiting in `frame_end`, under a forced peak load
(four gators, an eagle swoop, dive + fast swim, maximum scenery
density):

| Standard | Worst slack | Median slack | Dropped frames |
|---|---:|---:|---:|
| PAL | ~4,300 cycles | ~10,000 | 0 of 474 |
| NTSC | ~1,800 cycles | ~7,100 | 0 of 474 |

These include the sound engine (worst ~1,400 cycles in the vblank IRQ).
Setting the `debug_profile` byte (`main.asm`) to non-zero, e.g. from
the VICE monitor, paints the main thread's busy time as a red border
band.

The back buffer is "front shifted down one row, plus a new top row".
Copying 21 rows in one frame would cost about 8k cycles, so the copy is
split into three equal stages, one per frame, and the river generator's
work for the next world row is spread over the same stages (it only
touches the river ring, never a screen buffer):

| Stage | Copy (unrolled `lda/sta abs,x`) | Generator |
|---:|---|---|
| 1 | rows 2-8 -> 3-9 (~2.8k) | `river_build_row_a`: sample the next boundary, draw the row's water, banks and island into the ring |
| 2 | rows 9-15 -> 10-16 (~2.8k) | `river_build_row_b`: scenery stamps, shore reeds, water decoration, crawfish (median ~1.7k) |
| 3 | rows 16-22 -> 17-23 (~2.8k) | `gen_emit`: hand world row `top_world+1` to `row_buf`, blit it into row 2; `back_ready` = 1 |

An 8-pixel step takes 3.2 frames at the fastest speed (2.5 px/frame),
so three stages are always done in time. Three stages sustain up to
8/3 ≈ 2.67 px/frame. If the back buffer is ever late, the fine scroll
holds at 7 and the world pauses for a frame instead of tearing. Scroll
correctness is verified frame by frame (pixel-exact shift of the
playfield across every buffer swap, black band, first visible line 79),
including while the X/Y-expanded eagle's sprite DMA crosses the split
lines.

## PAL / NTSC

`detect_ntsc` (in `system_init`) records the highest raster low byte
seen on lines 256 and above: PAL reaches 311 (`$37`), NTSC 262
(`$06`), and the threshold is `$20`. The result goes to `is_ntsc` and
to the sound engine's `snd_ntsc`. On NTSC the game also uses different
scroll speed values (13/23/33 sixteenths of a pixel), dive free time
(180 frames) and crawfish time (255 frames, the most one byte holds).
All other timers are plain frame counts and run about 20% faster at
60 Hz.

## PAUSED

`state_paused` only watches for P. Nothing else runs, `sound_pause`
freezes music and effects, and `frame_end` keeps republishing the same
frame.

## Changed from the original design

- **No jiffy clock or separate timing layer.** The KERNAL is banked out,
  so every timer is a frame counter owned by its module, and pausing
  freezes the timers simply by not running them. PAL/NTSC compensation
  covers only the sound tempo, scroll speed, dive and crawfish times.
- **Collisions are not one central pass.** Each hazard tests itself
  against Ollie, but every outcome goes through Life Points,
  `loss_cause` and the single transition block at the end of the frame.
- **Screen sizes.** The HUD has two rows and the playfield 22 rows.
  Color RAM is never written for new rows.
- **Pause freezes the music too.** The original allowed music to
  continue.
- **One frame of input latency for speed.** A new speed reaches
  `scroll_speed` in `player_update`, after `display_advance` has
  already used the old value.
