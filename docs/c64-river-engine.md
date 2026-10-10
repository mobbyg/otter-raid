# Otter Raid — C64 River Engine

The river is generated procedurally one character row at a time, kept
smooth by easing and rate limiting, and shown through a double-buffered
vertical scroll. Code: `c64/river_engine.asm` (generator, renderer,
`river_limits`) and `c64/display.asm` (screens and scrolling).
Character and stamp art: `docs/c64-graphics.md`.

## Pipeline

```text
section_next / river_advance_boundary   one boundary sample per row
        |
river_render_base                       water, banks, island, grass
river_place_extras                      scenery stamps, crawfish, home
        |   (ring buffer, LOOKAHEAD rows ahead of the display)
gen_row                                 row -> row_buf -> display
        |
display.asm                             back buffer, fine scroll, swap
```

## World coordinates

- World rows are numbered upstream from 0 at the start of the journey.
- Boundary `n` is the bottom edge of world row `n`, so building row `w`
  needs boundaries `w` and `w+1`.
- Horizontal positions are multicolor pixels 0-159, four per character
  column. Banks are limited to 8..152, which always leaves two columns
  of land on each side.
- `top_world` is the world row in screen row 2. Screen row `k` shows
  world row `top_world - (k-2)`.
- The top raster line of world row `w` is
  `71 + fine_pos + 8 * (top_world - w)`. A sprite Y register value is
  a raster line, so hitbox lines map to rows with
  `(line - 71 - fine_pos) >> 3`.

## Sections

The journey has `SECTION_COUNT` = 40 sections of `SECTION_LEN` = 64
rows. Each section eases the river center and width from where the
previous section ended (`sec_c0`, `sec_w0`) to a target (`sec_c1`,
`sec_w1`), so sections always stitch.

| Section | Kind | Target |
|---|---|---|
| 0 | STRAIGHT start | edges 28..132 -> center 80, width 104; no crawfish |
| 1-38, roll 0-2 of 8 | BEND | center ±24..71, width base-12..base+11 |
| roll 3 | STRAIGHT | center drift -8..+7, width = base |
| roll 4-5 | WIDTH | width base-24..base+23 |
| roll 6-7 | PRE_ISLAND (sections 3-35 only, otherwise BEND) | center 80, width 128 |
| after PRE_ISLAND | ISLAND | keeps the shape; island peak width = `w0 - 2*MIN_CHANNEL` |
| 39 and later | HOME | center 100, width 104 (room on the left bank for Auntie's house) |

**Difficulty ramp.** The base width is `88 - section`, falling from 88
to 50. Targets are clamped to 48..128 (even widths), and the center is
clamped so that both banks stay inside 8..152. Gator spawn rate and
speed also rise with the section number (see
`docs/c64-object-and-collision-system.md`).

**Per-row placement.** These are tuning values and still change
often; the current numbers are in `section_setup_start`, `sn_rates`,
`sn_home_again` and `river_place_extras`. Each new row gets:

- `SCEN_CANDIDATES` (4) land-stamp candidates, each accepted with chance
  `scen_rate`/256. The start section is dense, normal sections get a
  random density per section, bends get the most.
- One shore-stamp candidate (`SHORE_RATE`/256).
- One water-stamp candidate (`WATER_RATE`/256).
- One pickup roll per row: crawfish with chance `fish_rate`/256, else a
  fish snack (`snack_rate`), else a gift for Auntie (`gift_rate`).
  Normal sections: 6 / 14 / 3 (of 256); the start section has only
  fish (10); the home section has none. The crawfish rate is 6 in normal sections, 0 in
  the start and home sections.

## Easing and rate limit

- **Easing.** For boundary `i` = 1..64 of a section, both center and
  width are interpolated with `river_smooth[i]` =
  smoothstep(i/64)·255. The target edges are `center ∓ width/2`.
- **Rate limit.** Every edge (left, right, island left, island right)
  moves toward its target by at most `EDGE_STEP` = 2 multicolor pixels
  per row (`clamp_step`). A far target may therefore not be reached
  within the section; the edge simply keeps chasing it.
- **Why 2 pixels.** The bank edges are drawn from *generated* edge
  characters, one for every sub-character offset and every slope from
  -2 to +2 pixels per row. Limiting the slope guarantees that every row
  of every edge has a matching tile.

## Edge tiles

`edge_span` draws one edge, given its x at the row top (`x_top`) and
at the row bottom. It covers the columns from `(min-1) >> 2` to
`max >> 2`, which includes the foam and mud pixel on either side of the
edge (1-3 columns). For each column `c` it looks up:

```text
lt    = x_top - 4c           (-2..7)
d     = x_bottom - x_top     (-2..2)
index = (lt+2)*5 + (d+2)     50-byte LUT; next column: index - 20
```

`edge_lut_left` draws the left bank and the island's right shore.
`edge_lut_right` draws the right bank and the island's left shore. Both
tables come from `gfx/gfx_tables.asm`. Grass fills the land outside the
banks and between the island's shores.

## Islands

1. **PRE_ISLAND** widens the river toward 128 pixels, centered at 80.
2. **ISLAND** grows and shrinks an island on the actual river center.
   Its width is `sec_iw · river_bump[i] / 256`, where `river_bump` is
   16·t²(1-t)²·255: zero at both ends of the section and 255 in the
   middle. `MIN_CHANNEL` = 30 leaves two channels of at least 30
   pixels at the peak. The island edges are rate-limited like the banks.
3. **Visibility.** A row draws island land only where the island is at
   least `ISLAND_MIN_SHOW` = 8 pixels wide at both of its boundaries;
   narrower islands are plain water. `river_limits` uses the same rule.
   When there is no island, `edge_il = edge_ir`.

## Lookahead ring

| Item | Value |
|---|---|
| Ring | `RIVER_RING`: 8 rows x 40 chars, ring row = world row & 7 |
| Lookahead | `LOOKAHEAD` = 5: `river_init` pre-builds rows 0-4, then each `gen_row` builds row `emit+5` and hands row `emit` to the display |
| Boundary rings | 64 entries each (`BND_L/R/IL/IR`), index = boundary & 63 |

When row `b` is built, rows `b-5..b` are all still in the ring and not
yet shown, so a stamp may be up to 6 rows tall (`stamp_prepare` checks
this).

## Row rendering and texture

- **Water.** Plain water character, with a ripple character from
  `ripple_tab` where the hash is below `RIPPLE_CHANCE` (20/256).
- **Grass.** Grass character, with a variant from `land_var_tab` where
  the hash is below `LAND_VAR_CHANCE` (48/256).
- **Texture hash.** `row_seed = NOISE[base_world & 255]`, and a cell
  uses `NOISE[(x + seed) & 255]` (grass uses `^ $80`). Texture is
  therefore deterministic per row and does not consume the random
  generator. `NOISE` is 256 LFSR bytes filled by `river_init`.
- **Character classes** (`gfx_ids.asm`):

  | Codes | Class |
  |---|---|
  | `$00-$07` | water |
  | `$08-$0F` | grass |
  | `$10-$2E` | left edges |
  | `$2F-$4D` | right edges |
  | `$50-$51` | crawfish |
  | `$52-$57` | pop ring |
  | `$58-$59` | fish |
  | `$5A-$5F` | gifts |
  | `$60+` | stamps |

## Scenery stamps

Placement is seeded and bounded: no multiplies, no retry loops, a fixed
number of candidates per row.

- **Choices.** Every decision (place or not, which stamp, which bank,
  which column) is a byte from the seeded `NOISE` table at
  `row_seed ^ $A5` + offset, so a given river seed always produces the
  same scenery. At `river_init`, `river_build_classes` sorts the stamp
  ids into LAND, WATER, SHORE_L and SHORE_R lists and repeats each list
  cyclically to 32 entries, so a 5-bit noise index picks a stamp
  uniformly. SPECIAL stamps are placed only by hand (`place_home`).
- **Column.** `span_column` maps 5 noise bits into the free span of the
  chosen bank (or the island, or open water) by repeated subtraction.
- **Fit test, O(w + h).**
  - *Skyline:* `occ_top[c]` is the top world row (low byte) of the
    scenery already in column `c`. Stamps always have their top in the
    newest row and reach down into rows built but not shown, so a stamp
    of height `h` fits iff `base_world - occ_top[c] >= h` for its `w`
    columns. `occ_refresh` re-ages one column per row (64-row cycle) so
    the 8-bit difference never wraps.
  - *Limits:* `river_render_base` stores each ring row's edge-column
    limits in `row_la/lb/ra/rb/il/ir`; the test compares the stamp's
    columns against those for its `h` rows (left bank: end <= `row_la`;
    right bank: start > `row_rb`; island: inside `row_il..row_ir`;
    water: clear of both banks, no island in those rows).
- **Writing.** A stamp's top data row goes into the newest row
  (`base_world`); data row `j` goes to world row `base_world - j`. Data
  byte `$FF` keeps the character underneath. `occ_mark` then records the
  stamp in the skyline.
- **Cost.** Measured in VICE: median 1,657 cycles per new row (max
  3,312), most of it the stamp writes themselves. The earlier version
  (random try + full footprint scan + multiply-based picks) cost a
  median of 4,189 (max 7,170) for less coverage.
- **No collision.** Collision uses boundary samples, not characters,
  so water stamps (lily pads, rocks, logs) are decoration that Ollie
  and the gators pass through.

**Pickups** (crawfish `CH_CRAWFISH_L/R`, fish `CH_FISH_L/R`, gifts
`CH_GIFT_FIRST` + 2 x kind, `GIFT_KINDS` = 3) are two-character pairs
placed in the newest row by `place_pickup`. Both cells must be open
water between the banks; the column comes from `span_column` and the
pair is marked in the skyline. They are collected by a character test
(see the object document).

**Charset animation.** `river_animate` spreads its work over an 8-frame cycle (frame 0 water, 2 crawfish, 4 fish, 6 gifts) so no single frame pays for all of it. It copies one of
`WATER_FRAMES` 64-byte frames into water characters 0-7, one of
`CRAWFISH_FRAMES` 16-byte frames into the crawfish characters, one of
`FISH_FRAMES` into the fish and (when `GIFT_FRAMES` > 1) one of the
48-byte gift frames into `$5A-$5F`. The
screens themselves are never rewritten for animation.

## Double buffer and scrolling

`display_init` clears both screens, sets color RAM, fills screen A
rows 23 up to 2 with 22 generated rows (`top_world = emit_world - 1`),
and builds screen B synchronously. From then on the back buffer is
"front shifted down one row, plus the new top row", built in three
stages over three frames (rows 2-8, 9-15, 16-22), with the next world
row generated alongside (boundary + rendering in stage 1, scenery in
stage 2) and handed over by `gen_emit` in stage 3. Stage 1 starts in the frame after a swap is latched. See
`docs/c64-frame-update-flow.md` for costs.

| Speed | `scroll_speed` (1/16 px per frame, PAL) | px per frame | Ollie's sprite Y |
|---|---:|---:|---:|
| slow (DOWN) | 16 | 1 | 208 |
| normal | 28 | 1.75 | 198 |
| fast (UP) | 40 | 2.5 | 186 |

On NTSC the values are 13/23/33, which keeps the same pixels per
second.

Each frame `scroll_sub + scroll_speed` advances `fine_pos` (0-7).
Reaching 8 swaps the buffers (`front_buf ^= 1`, `top_world++`) if
`back_ready` is set; otherwise the fine scroll holds at 7.
`scroll_delta` is the number of pixels the world moved this frame;
the gators ride it.

## `river_limits`

`river_limits` takes the raster lines `zp_t0..zp_t1` of the frame
being prepared (a sprite's hitbox). It converts them to rows, scans the
boundary samples of every row those lines touch (at most 5 boundaries)
and returns conservative limits:

| Output | Meaning |
|---|---|
| `lim_l` | first water pixel: the largest left edge |
| `lim_r` | first land pixel of the right bank: the smallest right edge |
| `lim_il..lim_ir` | widest island span among the visible islands; both 0 when there is none |

It is used by Ollie's bank clamp, gator spawning, the gators' shore
check and the demo AI.

## Journey end and home

- **Final section.** When section 39 begins, `home_row = base_world + 32`
  (world row 2528) and `river_end` is set. From then on no gators
  spawn and the eagle timer stops.
- **Home scenery.** `place_home` writes the SPECIAL stamps:
  - Auntie's house against the left bank, with its bottom row at
    `home_row + HOME_HOUSE_ROW` (6);
  - the dock on the water beside the house's bottom rows;
  - bunting on the row above the house;
  - balloons on the right bank.
- **Arrival.** HOME starts when `top_world - home_row >= 18`, i.e. when
  the home row has scrolled down to Ollie's line.
- **Length.** About 2,525 rows scroll from the start to arrival, which
  is about 20,200 pixels: roughly 2.7 min at fast, 3.8 min at normal
  and 6.7 min at slow speed.

## Seeds and variation

`river_init` seeds the 16-bit LFSR from `run_seed`. A new game sets
`run_seed` to 0 and every lost heart increments it. The LFSR is shared
with gator spawning, the eagle and the home fireworks. As a result,
the first rows of every new game are identical, and from then on the
river depends on how play interleaves with generation. A run cannot be
reproduced from its seed alone.

## Changed from the original design

- **Easing instead of control points.** Each section eases center and
  width with smoothstep from its start to one target, sampled per row
  boundary and rate-limited to 2 px per row.
- **Fixed section length.** Sections are 64 rows long and the journey
  ends halfway into section 39 (40 sections in name).
- **Charset-only art.** New rows are characters only; color RAM is
  constant.
- **Islands, shore reeds and the home scenery exist.**
- **Crawfish are playfield characters**, not pooled objects.
- **No seed-based reproducibility.** Variation between runs comes from
  `run_seed` and the shared random generator.
