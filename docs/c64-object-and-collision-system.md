# Otter Raid — C64 Objects and Collision

There is no generic object system. Each hazard module owns its state,
moves itself and tests itself against Ollie. Every outcome goes through
a few shared channels:

- `lp_sub` (Life Points);
- `ply_hurt` (grace after a bite);
- `ply_invuln` (crawfish protection);
- `loss_cause` (heart lost).

`state_playing` turns these into state transitions once per frame
(`docs/c64-state-machine.md`). Code: `player.asm`, `enemies.asm`,
`eagle.asm`, `game.asm` (`player_pickup`) and `river_engine.asm`
(`river_limits`).

## Hardware sprites

Lower numbers are drawn on top. `$D01B` = 0, so every sprite is in
front of the playfield. The shared multicolors are `$D025` black and
`$D026` white.

| # | PLAYING | Mode, color | HOME scene | Title |
|---|---|---|---|---|
| 0 | eagle (X+Y expanded) | MC, brown | firework (hires) | Ollie portrait, top left |
| 1 | effect: splash / bubbles / sparkle | MC white / hires light blue / hires yellow | firework (hires) | portrait, top right |
| 2 | Ollie | MC, brown (dark grey underwater, color cycle while invulnerable) | Ollie dancing | portrait, bottom left |
| 3-6 | gators 0-3 | MC, green | 3 present, 4 Auntie, 5-6 balloons | 3: portrait, bottom right; 4: present |
| 7 | eagle shadow (X+Y expanded) | hires, dark grey | firework (hires) | — |

All sprite writes go to the shadow at `$0240`; the vblank IRQ latches
it (`docs/c64-frame-update-flow.md`). Sprite graphics and pointer ids:
`docs/c64-graphics.md`.

## Coordinates

| Object | X | Y |
|---|---|---|
| Ollie | `ply_x`: sprite left edge in MC pixels; sprite X = 24 + 2·`ply_x` | `ply_y` = sprite Y register |
| Gator | `g_x` = MC pixels + 16 (`GX_OFS`), so a gator can poke past the left edge; sprite X = 2·`g_x` - 8 | `g_y` = sprite Y register |
| Eagle | 24-bit hires sprite X (8-bit fraction) | 8.8 sprite Y |

## Hitboxes

| Object | X (from sprite left) | Y (lines from sprite top) |
|---|---|---|
| Ollie | MC px 3..8 (6 MC = 12 hires px) | 3..17 (15 lines) |
| Gator | MC px 1..10 (10 MC px) | 6..15 (10 lines) |
| Eagle | no box: a talon point at sprite +24 hires px, +34 lines | |

The eagle catch test compares the talon point with Ollie's center
(sprite +12 hires px, +10 lines) and needs `|dx| < 14` hires px **and**
`|dy| < 14` lines.

## Ollie

| Aspect | Rule |
|---|---|
| Speed | UP = fast, DOWN = slow, else normal. Sets `scroll_speed` and eases the sprite Y toward 186/198/208 at 1 line/frame. |
| Steering | accel 10/64 MC px per frame², friction 6/64, max 96/64 (1.5 MC px per frame) |
| Banks | `river_limits` over the hitbox lines. The hitbox is clamped into `[lim_l, lim_r)` and pushed off an island toward the nearer side. Contact sets `vx` = 0 and plays a bump sound (12-frame cooldown). No damage. |
| Dive | FIRE: DOWN 12 frames, UNDER while held, UP 12 frames. Protected from frame 6 of DOWN to frame 6 of UP. |

## Effect sprite (#1)

| Shown when | Frames | Mode, color |
|---|---|---|
| Diving or surfacing | splash, 3 frames over 12 | MC, white |
| Underwater (UNDER) | bubbles, 2 frames | hires, light blue |
| Invulnerable | sparkle, 4 frames | hires, yellow |

The sprite sits at Ollie's position. In the last 50 frames of crawfish
protection a warning sound plays every 16 frames.

## Gators

The pool holds `GATOR_MAX` = 4 gators as parallel arrays at `$0300`.

| State | Time | Behaviour |
|---|---|---|
| OFF | | slot free |
| LURK | 40 frames | eyes only at the bank, drifting, harmless |
| SWIM | until a shore | moves across at `g_speed`; the only state that bites |
| BITE | 24 frames | jaws open, holds position, then back to SWIM |
| SINK | 30 frames | eyes only, harmless, then OFF |

**Spawning** (`gator_spawn`):

- `gator_spawn_t` counts down. The first try comes 100 frames into a
  run. Each try then sets the next interval to
  `max(12, 40 - section) + rand(0..63)` frames.
- There are no spawns while `top_world < 40` or once `river_end` is
  set, and none without a free slot.
- Height: sprite Y 92..147, at least 24 lines away from every other
  active gator. Otherwise the try is skipped.
- Side: random. The gator starts at that bank, using `river_limits`
  at its height, with its head 4 pixels out of the bank, facing across
  the river. A splash sound plays.
- Speed: `6 + section/4 + rand(0..7)` sixteenths of an MC pixel per
  frame. That is 0.4-0.8 px/frame early and up to about 1.4 late.

**Riding the current.** Every active gator adds `scroll_delta` to its
Y each frame, so it drifts with the river at any swim speed. It
despawns once its Y reaches 248.

**Shore check** (each SWIM frame, `river_limits` over its hitbox
lines). The gator sinks when its nose reaches the far bank. It also
sinks when its nose reaches the near shore of an island, unless it was
already past that shore (for example, when it spawned in the far
channel).

**Bite.** In SWIM, if the hitboxes overlap and Ollie is neither
protected nor in hurt grace, the gator switches to BITE and
`player_hit_gator` runs:

- -100 LP;
- `ply_hurt` = 75 frames (Ollie blinks);
- `safe_rows` = 0;
- chomp sound.

A protected Ollie overlaps a gator without any effect. Gators never
collide with each other.

**Frames.** Separate right- and left-facing frames: a 3-frame swim
cycle (0,1,2,1, 8 frames each) plus bite and lurk frames.

## Eagle

| State | Behaviour |
|---|---|
| WAIT | Timer `4500 + rand(0..255)·6` frames (90-120 s on PAL). Counts only during PLAYING frames, and not once `river_end` is set. Reset every run. |
| WARN | 60 frames. Picks a side (`e_side`), plays the screech and the eagle tune. The shadow slides in over the water from that side, 70 lines above Ollie, at 2 px/frame. |
| SWOOP | 128 frames, see below. |
| CARRY | 70 frames climbing (at least 2 lines/frame) with Ollie's "caught" frame hanging under the talons, then `loss_cause = LOSS_EAGLE`. |

**SWOOP.**

- **Launch.** The eagle starts at the top corner of the warned side
  (hires X 0 or 344, Y 22, above the playfield). It aims so that the
  talons reach Ollie's center **where he was at launch**, 64 frames
  later. The step is (target - start)/64 in 8.8 fixed point.
- **Path.** Y adds the step for 64 frames and subtracts it for the
  next 64, while X keeps going. The result is a V that leaves on the
  far side; the eagle never turns back.
- **Catch window.** Frames 54-73. A talon hit on an unprotected Ollie
  starts CARRY.
- **Miss.** If no catch happens, +1,000 points, a new timer and the
  river tune again.
- **Look.** The dive frame shows near the bottom of the V (frames
  48-71); otherwise there is a 4-frame flap.
- **Shadow.** It is offset by `h = |64 - t|`: Y + h + 8 and X + h/2,
  so it meets the eagle at the bottom of the V.

## Pickups (characters): crawfish, fish, gifts

All pickups are two-character pairs in the playfield (see
`river-engine.md`). `player_pickup` tests characters, not sprites:

- **Column:** `(ply_x + 6) >> 2`, Ollie's center column.
- **Row:** from Ollie's head line `ply_y + 4`:
  `row = ((line - 71 - fine_pos) >> 3) + 2`. Rows `r` and `r+1` of the
  buffer about to be shown (`front_buf`) are checked.
- **Classify** (`pickup_class`): `CH_CRAWFISH_L/R` ($50/$51) is a
  crawfish; `$58-$5F` are fish (`CH_FISH_L/R`) and gifts
  (`CH_GIFT_FIRST` + 2 x kind). In `$58-$5F` pairs start on even codes,
  so bit 0 tells the right half.
- **Hit** on either half: the pair becomes water in that buffer, and
  also at row `r+1` of the back buffer, which may already hold the
  shifted copy. `pickup_erase` checks the cell holds the same left
  character first, so a stale back buffer is left alone.
- **Rewards:**

  | Pickup | Effect | Points | Sound |
  |---|---|---:|---|
  | Crawfish | `ply_invuln` = 250 frames (255 on NTSC) | 500 | `SFX_CRAWFISH_PICKUP` |
  | Fish | +250 Life Points (counts toward a lost heart) | 100 | `SFX_FISH_EAT` |
  | Gift (lily blossom, cake, wrapped box) | `gifts` + 1, shown in the HUD; +500 each again at the homecoming | 1,000 | `SFX_GIFT` |

- **Pop ring.** `pop_update` then draws a 3-stage ring (`CH_POP0..2`,
  6 frames each) where the pickup was, in both buffers. It tracks the
  pair's world row (`pop_world`), so it scrolls with the river, and
  leaves water behind.
- Pickups also work underwater.

## Banks and islands

Walls are never characters. Ollie, gator spawns and gator shore checks
all call `river_limits`, which reads the boundary samples of the rows
under a range of raster lines. It returns the narrowest banks and the
widest island span (only islands at least 8 pixels wide count). Bank
contact never costs Life Points.

## Changed from the original design

- **No central collision pass and no pickup pool.** Crawfish, fish and
  gifts are characters collected by a screen test.
- **Fish and gifts are new.** The original design only had crawfish.
- **Separate left/right gator frames.** The VIC-II cannot flip
  sprites horizontally, so the planned flip is impossible.
- **Hit cooldown.** The BITE state plus the 75-frame hurt grace
  replace the planned "contact cooldown".
- **Eagle path.** The eagle aims at Ollie's position at launch from a
  top corner and swoops in a V. Its side is announced by the shadow
  during WARN. There are no separate ENTER/EXIT states; it still never
  turns back.
- **Water scenery is decoration.** Rocks, logs and lily pads do not
  collide.

## Fixed after code review

- During the eagle's CARRY, `player_update`, `player_pickup` and gator
  bites are skipped, so the carried-off Ollie cannot be bitten or
  collect anything.
- The surfacing frame is `2 - t/4` (was `1 - t/4`, which read past
  `ollie_dive_frames`).
