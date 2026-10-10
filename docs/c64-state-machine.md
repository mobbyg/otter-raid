# Otter Raid — State Machine

One variable, `game_state`, selects the handler that `game_frame` runs
each frame (`c64/game.asm`). `set_state` changes it and resets the
per-state frame counter `state_t`. Hazards and the player never change
`game_state`; they change Life Points or set `loss_cause`, and the end
of `state_playing` decides.

## Main states

| `ST_` | Handler | File | What it does |
|---|---|---|---|
| `TITLE` (0) | `state_title` | screens.asm | title menu and its sub-screens (`ts_mode`): 0 menu, 1 high scores, 2 controls, 3 name entry |
| `PLAYING` (1) | `state_playing` | game.asm | GET READY pause, then the river journey; also runs the attract demo |
| `PAUSED` (2) | `state_paused` | game.asm | frozen; P resumes |
| `LIFE_LOST` (3) | `state_life_lost` | game.asm | 150 frames: Ollie faints, or is already gone with the eagle |
| `GAME_OVER` (4) | `state_game_over` | game.asm | "GAME OVER" for 200 frames |
| `HOME` (5) | `state_home` | home.asm | the homecoming party and score tally |
| `HIGH_SCORES` (6) | `state_high_scores` | screens.asm | vestigial: never entered; jumps to `title_menu` |

## Transitions

| From | Event | To |
|---|---|---|
| boot | `title_enter` | TITLE, menu |
| TITLE menu | UP/DOWN move the cursor | TITLE menu |
| TITLE menu | FIRE/RETURN on START GAME | `game_start` -> PLAYING |
| TITLE menu | FIRE/RETURN on HIGH SCORES or CONTROLS | that sub-screen |
| TITLE menu | idle for 768 frames | high scores, marked as the idle tour (`idle_seq`) |
| scores / controls | FIRE/RETURN, or 250 frames | menu, or the attract demo if this is the idle tour |
| name entry | third letter confirmed | `title_enter` |
| PLAYING | P | PAUSED (`sound_pause` 1) |
| PAUSED | P | PLAYING (`sound_pause` 0, HUD redrawn) |
| PLAYING | LP = 0 (`LOSS_LP`) or eagle carry finished (`LOSS_EAGLE`) | `lose_heart`: hearts - 1 -> LIFE_LOST |
| PLAYING | `river_end` and `top_world - home_row >= 18` | HOME |
| PLAYING, demo | FIRE/RETURN, ~60 s, or any heart loss | `title_enter` |
| LIFE_LOST | 150 frames, hearts > 0 | `run_seed`+1, `game_new_run` -> PLAYING |
| LIFE_LOST | 150 frames, hearts = 0 | GAME_OVER |
| GAME_OVER | 200 frames | `hiscore_check` -> TITLE (name entry if the score places, else menu) |
| HOME | after the show (see below) | `hiscore_check` -> TITLE |

Losing the last heart still goes through LIFE_LOST (3 s) before
GAME_OVER. Within one PLAYING frame the checks run in this order:
pause, then loss, then home. A loss therefore always beats arriving
home.

## Starting a game and a run

| Routine | Does |
|---|---|
| `game_start` | score = 0, hearts = 3, `run_seed` = 0, then `game_new_run` |
| `game_new_run` | blank the display, `river_init`, `display_init`, `player_reset`, `gators_reset`, `eagle_reset`; LP = 1,000; heart progress, `safe_rows` and `loss_cause` = 0; sprite shadow reset; HUD drawn; GET READY for 90 frames; river music; PLAYING |

Every lost heart restarts the journey from world row 0, with a
different river (`run_seed`+1). Score and hearts carry over.

**GET READY** (`ready_t`): for 90 frames the message blinks, the
river, hazards and input are frozen, and only the water animation and
Ollie's sprite run.

## Rules

### Life Points

| Rule | Value |
|---|---|
| Start, and after every heart loss | 1,000 (`LP_START`) |
| Maximum | 10,000 (`LP_MAX`) |
| Gator bite | -100 (`GATOR_DAMAGE`), then 75 frames of hurt grace |
| Diving | free for 150 frames (3 s) from the start of the dive, including going down and coming up; then -1 LP per frame (50 LP/s on PAL) until fully surfaced |
| Recovery | +5 LP per scrolled row (`LP_PER_ROW`), once 16 rows have passed since the last gator bite (`SAFE_ROWS_NEEDED`) |
| LP reaches 0 | heart lost (`LOSS_LP`) |

### Hearts

| Rule | Value |
|---|---|
| Start | 3 |
| Lost when | LP reaches 0, or the eagle carries Ollie away |
| Earned back | **5,000 LP earned since the last heart loss** (`HEART_COST`), at most 3 hearts |

Heart progress (`heart_prog`) adds every recovery amount passed to
`lp_add`. It counts LP *earned*, not net LP, so it keeps counting even
while LP sits at the 10,000 cap. Any excess over 5,000 carries over to
the next heart. Progress is zeroed at every heart loss (and new run)
and while all three hearts are full.

**Resolved contradiction.** The original docs gave both "recovery
target = LP at loss + 5,000" and "5,000 newly accumulated LP". LP is
reset to 1,000 after a loss (and is 0 after an LP loss), so a target
based on LP at the moment of loss is meaningless. The implemented rule
is the second one: 5,000 LP earned since the last loss.
`docs/otter-raid-game-design.md` still states the old rule.

### Protection

`player_protected` is true while any of these hold:

| Source | Window |
|---|---|
| Dive | DOWN from frame 6 of 12, all of UNDER, UP until frame 6 of 12 |
| Crawfish | 250 frames (5 s on PAL); refreshed by each pickup |

Protection blocks both gator bites and the eagle's catch. Separately,
the 75-frame **hurt grace** after a bite blocks further gator bites
(but not the eagle) and makes Ollie blink.

### Scoring

| Event | Points |
|---|---:|
| Each scrolled row | 10 |
| Crawfish | 500 |
| Fish (also +250 Life Points) | 100 |
| Gift for Auntie | 1,000 |
| Home tally: each gift collected | 500 |
| Eagle swoop that ends without a catch | 1,000 |
| Home tally: Life Points | 100 per 100 LP (any remainder below 100 is dropped) |
| Home tally: each heart left | 5,000 |

Score is 6-digit BCD. `hi_score` (shown in the HUD) starts as the best
entry of the high-score table and is updated by `hiscore_check`.

## Sub-state machines

| Owner | States | Notes |
|---|---|---|
| Ollie's dive (`ply_dive`) | NONE -> DOWN (12 frames) -> UNDER (while FIRE is held) -> UP (12 frames) -> NONE | the free-dive counter resets when he is fully up |
| Gator (`g_state`) | OFF -> LURK (40) -> SWIM <-> BITE (24) -> SINK (30) -> OFF | any state -> OFF when it drifts below line 248 |
| Eagle (`e_state`) | WAIT -> WARN (60) -> SWOOP (128) -> WAIT, or SWOOP -> CARRY (70) -> `LOSS_EAGLE` | timer counts only in PLAYING, and not once `river_end` is set |
| Title (`ts_mode`) | menu / scores / controls / name entry | all inside `ST_TITLE` |

Details: `docs/c64-object-and-collision-system.md`.

## HOME sequence

`state_t` wraps every 256 frames, so `home_t_hi` extends it.

| Frame | Phase |
|---|---|
| 1 | `home_begin`: scroll stops, gators and eagle cleared, the party spot is found from the dock, "HAPPY BIRTHDAY, AUNTIE!" appears in HUD row 1 |
| 1-109 | Ollie swims to the spot (input ignored) |
| 110+ | party: Ollie and Auntie dance, the present hops, balloons rise, fireworks burst |
| 170+ | tally: 100 LP -> 100 points per frame, then 5,000 per heart (hearts count down to 0) |
| 320+ | FIRE/RETURN leaves (intended: `HOME_LEAVE_MIN`) |
| 512 | leaves automatically (`home_t_hi >= 2`) |

Known issue: the early-leave test compares only the low byte of
`HOME_LEAVE_MIN`, so FIRE is accepted from frame 110 and can skip the
tally.

## High scores

There are five entries of 3 BCD bytes and 3 letters in `hs_table`
(RAM, kept until power-off, not saved to disk).

1. `hiscore_check` inserts the score above the first entry it beats
   or equals, shifting the lower entries down.
2. It then shows the table with "ENTER YOUR NAME!" in `ts_mode` 3.
3. UP/DOWN cycle a letter A-Z, FIRE/RETURN moves on, and after three
   letters the game returns to the menu. There is no timeout.

## Attract demo

From the idle tour (menu, then high scores, then the demo),
`demo_start` sets `demo_mode` and calls `game_start`.

- `demo_ai` replaces the input each frame:
  - steer to the middle of the wider channel;
  - dive when a swimming gator is close above Ollie, or during the
    eagle's dive;
  - swim fast in alternating 128-frame stretches.
- The eagle comes after about 900 frames.
- The demo ends on FIRE/RETURN, after 12 wraps of `state_t` (~61 s),
  or at the first heart loss. Each of these returns to the title.

## Changed from the original design

- **Menus.** TITLE and MENU are one state, and there is no Exit item.
  HIGH_SCORES became a title sub-screen; the `ST_HIGH_SCORES` id is
  kept only in the dispatch table.
- **GAME_OVER is timed** (4 s) instead of offering restart or menu
  choices. High-score entry follows if the score places.
- **The eagle** uses WAIT/WARN/SWOOP/CARRY instead of
  ENTER/SWOOP/EXIT/COOLDOWN. Its catch costs the heart after a 70-frame
  carry.
- **Gators** use LURK/SWIM/BITE/SINK instead of
  ENTERING/CROSSING/EXITING/COOLDOWN.
- **Crawfish have no state machine**; they are playfield characters.
- **Distance** is the number of scrolled rows (`top_world`). Home is
  reached when the home row reaches Ollie's line.
- **The heart recovery rule** is "5,000 LP earned since the last
  loss" (see above).
- **PAUSED stops the music too.**
- **New: the attract demo and the GET READY pause.**
