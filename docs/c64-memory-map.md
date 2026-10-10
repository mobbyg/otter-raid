# Otter Raid C64 Memory Map

This is the memory layout of the implemented engine. The source of
truth is **`c64/memory.asm`** (every zero-page byte and RAM buffer is
allocated there and nowhere else) plus the `.org` placement in
**`c64/main.asm`**. If this document and those files disagree, the
files win; fix the document.

## Machine configuration

| Item | Setting | Where |
|---|---|---|
| CPU port `$01` | `$35`: RAM everywhere, I/O at `$D000-$DFFF`, KERNAL and BASIC banked out | `system_init` |
| Hardware vectors | `$FFFA-$FFFF` in RAM: NMI -> `rti`, IRQ -> raster chain | `system_init` |
| CIA interrupts | all sources disabled; only the VIC raster IRQ is used | `system_init` |
| VIC bank | bank 1 (`$4000-$7FFF`), `$DD00` bits 0-1 = `%10` | `CIA2_BANK1` |
| ROM calls | none; the game never returns to BASIC | |

## Address map

| Range | Use | Notes |
|---|---|---|
| `$0000-$0001` | 6510 CPU port | |
| `$0002-$00FF` | zero page, game-owned | see table below |
| `$0100-$01FF` | stack | `start` resets SP to `$FF` |
| `$0200-$03FF` | small buffers, gator pool | see buffers table |
| `$0400-$07FF` | river buffers | **not** screen RAM any more (VIC bank 1) |
| `$0801-$080C` | BASIC stub `10 SYS2061` | entry `start` = `$080D` |
| `$080D-$3FFF` | code and tables (incl. `gfx/gfx_tables.asm`) | ends at `code_end`; must stay below `$4000` |
| `$4000-$7FFF` | VIC bank 1: screens, charsets, sprites | see below |
| `$8000-$9FFF` | sound engine, music and SFX data | `c64/sound/`, see `docs/c64-sound.md` |
| `$A000-$BFFF` | RAM under BASIC ROM | reserved, currently unused |
| `$C000-$CFFF` | RAM | reserved, currently unused |
| `$D000-$DFFF` | I/O; color RAM `$D800-$DBE7` | |
| `$E000-$FFF9` | RAM under KERNAL ROM | reserved, currently unused |
| `$FFFA-$FFFF` | NMI / RESET / IRQ vectors (RAM) | written by `system_init` |

The PRG is one file from `$0801` up to the end of the sound data; the
assembler fills the gaps.

## VIC bank 1 (`$4000-$7FFF`)

| Address | Size | Content |
|---|---:|---|
| `$4000` | 1 KB | Screen A: HUD rows 0-1, playfield buffer A (rows 2-23), all text screens |
| `$43F8` | 8 B | Sprite pointers for screen A |
| `$4400` | 1 KB | Screen B: playfield buffer B (rows 2-23; rows 0-1 unused) |
| `$47F8` | 8 B | Sprite pointers for screen B |
| `$4800` | 2 KB | `CHARSET_GAME`: multicolor river charset |
| `$5000` | 2 KB | `CHARSET_TEXT`: hires HUD/text charset |
| `$5800` | up to 10 KB | `SPRITE_DATA`: 160 slots, pointer = 96 + slot (`SPR_PTR_BASE`) |
| `$7FFF` | 1 B | `VIC_IDLE_BYTE`, shown in idle lines; must be 0 |

Bank 1 has no character ROM image, so both charsets live in RAM. The
charset, sprite and table contents (and how many sprite slots are used)
are described in `docs/c64-graphics.md`; the engine only uses the
constants in `c64/gfx/gfx_ids.asm` and the tables in
`c64/gfx/gfx_tables.asm`.

`$D018` values: `D018_HUD` (screen A + text charset), `D018_PLAY_A`
and `D018_PLAY_B` (screen A or B + game charset).

## Zero page

| Range | Owner | Contents |
|---|---|---|
| `$02-$05` | IRQ scratch | `zi_t0`, `zi_t1`, `zi_ptr`; reserved for IRQ code, currently unused |
| `$06-$0F` | | free (reserved for IRQ scratch) |
| `$10-$1F` | main-thread scratch | `zp_t0-zp_t7`, `zp_ptr0-zp_ptr3`; callee-clobbered unless a routine's header says otherwise |
| `$20-$30` | `system.asm`, `display.asm` | `frame_count`, `next_valid`, `cur_/next_` fine and front, `scroll_sub`, `scroll_speed`, `fine_pos`, `front_buf`, `back_ready`, `copy_stage`, `top_world` (2), `is_ntsc`, `hud_bg_color`, `disp_mode` |
| `$31-$3F` | | free |
| `$40-$57` | river generator | `emit_world`, `base_world` (2 each), section state `sec_*`, edges `edge_*`, LFSR `rng_lo/hi`, `scen_rate`, `fish_rate`, `island_next`, `row_seed`, `river_end`, `run_seed` |
| `$58-$5F` | row renderer | `rb_la`, `rb_lb`, `rb_ra`, `rb_rb`, `rb_ila`, `rb_irb`, `rb_island`, `water_frame` |
| `$60-$7F` | input, player, game | `in_held`, `in_new`, `in_override`, `game_state`, `scroll_delta`, `ply_*`, `lp_lo/hi`, `hearts`, `heart_prog_lo/hi`, `score` (3, BCD), `safe_rows`, `lim_*`, `ply_bump`, `ply_flags` (unused) |
| `$80-$8E` | eagle | `e_state`, `e_t`, timer, 24-bit X, 8.8 Y, steps, `e_anim`, `e_side` |
| `$8F-$9F` | | free |
| `$A0-$BD` | game, screens, home, demo | `hi_score` (3), `loss_cause`, `state_t`, `last_top`, `home_row` (2), `menu_sel`, `ts_mode`, `ts_idle` (2), `hs_slot`, `hs_letter`, `home_*`, `fx_splash_t`, `fx_bump_t`, `ready_t`, `last_sec`, `demo_mode`, `demo_t_hi`, `idle_seq`, `pop_t`, `pop_col`, `pop_world` (2) |
| `$C0-$C6` | pickups | `snack_rate`, `gift_rate`, `gifts`, `pk_kind`, `pk_left`, `gifts_shown`, `home_gift_t` |
| `$BE-$DF` | | free |
| `$E0-$EF` | sound engine | owned by `c64/sound` |
| `$F0-$FF` | | free |

## Buffers `$0200-$07FF`

| Range | Name | Content |
|---|---|---|
| `$0200-$0227` | `row_buf` | newest world row handed to the display (40 chars) |
| `$0228-$023F` | | free |
| `$0240-$0265` | `spr_shadow` | sprite shadow: X[8], Y[8], PTR[8], COLOR[8], XMSB, ENABLE, MCOLOR, EXPX, EXPY, PRIO |
| `$0266-$02FF` | | free |
| `$0300-$0320` | gator pool | `g_state`, `g_x`, `g_xf`, `g_y`, `g_dir`, `g_speed`, `g_timer`, `g_anim` (4 bytes each), `gator_spawn_t` |
| `$0321-$03FF` | | free |
| `$0400-$053F` | `RIVER_RING` | 8 rows x 40 chars, ring row = world row & 7 |
| `$0540-$063F` | `BND_L/R/IL/IR` | 4 rings of 64 boundary samples, index = boundary & 63 |
| `$0640-$06BF` | `stamps_*` | stamp id lists per class (land, water, shore L, shore R), repeated cyclically to 32 entries |
| `$0280-$02AF` | `row_la/lb/ra/rb/il/ir` | per ring row land/water limits for scenery placement (8 each) |
| `$02B0-$02D7` | `occ_top` | scenery skyline: top row per column |
| `$06C0-$06C3` | `stamp_counts` | entries per class list |
| `$06D0-$06DF` | `land_var_tab` | 16 grass variant chars |
| `$06E0-$06FF` | | free |
| `$0700-$07FF` | `NOISE` | 256 random bytes for texture hashing |

### Code-resident variables

A few bytes live inside the code segment instead of `memory.asm`:
`debug_profile` (main), `gu_index`, `gs_slot_x` (enemies), `ec_time`
(eagle), `rpe_tries` (river), `hud_last_lp/hearts/track` (hud), `ta_phase` and the high-score
table `hs_table` (screens), `fw_x/fw_y/fw_color` (home), `dive_free` and
`invuln_frames` (player). New state belongs in `memory.asm`.

## Sprite pointers

Main code never writes `$43F8`/`$47F8` directly. It writes the sprite
shadow at `$0240`; `sprites_latch` (inside the vblank IRQ) copies the
shadow to the VIC registers and to **both** screens' pointer bytes,
because the VIC reads the pointers from whichever screen `$D018`
selects at that raster line (A for the HUD, A or B for the playfield).

## Color RAM

| Area | Policy |
|---|---|
| Playfield rows 2-23 (offsets 80-999) | Every cell holds `PLAY_COLRAM` = multicolor flag + green (the `%11` foliage color). Color RAM never scrolls; all river art is in the charset. Written by `display_init` at the start of every run. |
| HUD rows 0-1 (offsets 0-79) | Hires text; each print routine writes its own cell colors. |
| Text screens (`DM_TEXT`) | `text_clear` repaints all 1000 cells and each screen recolors its items. `display_init` restores the playfield values when the next run starts. |

Playfield multicolor registers (`c64/palette.asm`): `$D021` blue water,
`$D022` light blue foam, `$D023` brown earth. Sprite multicolors:
`$D025` black, `$D026` white.

## Changed from the original design

- KERNAL and BASIC are banked out from the start. The plan kept the
  ROMs and the KERNAL jiffy clock; all timing is now frame counts.
- The VIC uses bank 1 with two screens, two charsets and the sprites.
  Screen RAM is no longer at `$0400`, so `$0400-$07FF` holds river
  buffers.
- Sprite data moved from `$3000-$33FF` (16 slots) to `$5800+`
  (160 slots).
- The whole zero page is game-owned and split into ranges per
  subsystem, replacing the `$20-$3F` variable list.
- Object storage: the gators are parallel arrays at `$0300`, the eagle
  lives in zero page, and there is no crawfish pool (crawfish are
  playfield characters).
- Code is one block from `$0801`. Sound sits at `$8000-$9FFF` and
  `$4000-$7FFF` is VIC data, not an "extended code pool".
- The high-score table lives in RAM (`hs_table`). It survives games
  until power-off and is not saved to disk.

## Open

- The build stops with an error (`.fail` in `main.asm`) if `code_end`
  passes `$4000` or the sound data passes `$A000`.
- `$A000-$BFFF`, `$C000-$CFFF` and `$E000-$FFF9` are free for growth.
- Saving high scores to disk is still undecided.
