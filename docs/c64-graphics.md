# Otter Raid C64 Graphics

All graphics are drawn as text in `gfx/*.gfx` and compiled by
`tools/gfx.py` into assembler data under `c64/gfx/`. The generated files
carry a "do not edit" header; change the `.gfx` sources and rebuild.

## Rebuilding

    python3 tools/gfx.py              # or: make assets
    python3 tools/gfx.py --no-preview # data only, skip PNG/GIF previews

Output (deterministic, so two runs give identical files):

| File | Contents | Where the engine puts it |
|---|---|---|
| `c64/gfx/charset_game.asm` | `charset_game_data`, 2048 bytes (multicolour) | `.org $4800` |
| `c64/gfx/charset_text.asm` | `charset_text_data`, 2048 bytes (hires) | `.org $5000` |
| `c64/gfx/sprites.asm` | `sprite_data`, 54 x 64 bytes | `.org $5800` (pointer = 96 + slot) |
| `c64/gfx/gfx_ids.asm` | constants only (`CH_*`, `TX_*`, `SPR_*`, `STAMP_*`, counts) | anywhere |
| `c64/gfx/gfx_tables.asm` | `water_anim_data`, `crawfish_anim_data`, `fish_anim_data`, `gift_anim_data`, `edge_lut_left/right`, `stamp_*`, `title_logo_map` | code area |

Previews go to `build/gfx_preview/` (gitignored): charset sheets, sprite
sheet (each sprite on water, grass and black), `stamps.png`,
`title_logo.png` (two sample row gradients), `anim_*.gif` for every cycle,
and mock screens: `mock_playfield.png` (320x168), the scrolling
`mock_playfield_scroll.gif`, `mock_hud.png`, `mock_title.png`,
`mock_home.png` and `mock_home_dance.gif`. Previews use the Colodore
palette.

## Palette and colour assignments

Playfield (multicolour chars, one colour RAM value for every cell):

| Bits | Letter | Colour | Source |
|---|---|---|---|
| %00 | `.` | blue (6) | `$D021`: water |
| %01 | `w` | light blue (14) | `$D022`: foam, glints, stone, plaster |
| %10 | `b` | brown (9) | `$D023`: earth, mud, bark, shade, outlines on land |
| %11 | `g` | green (5) | colour RAM (5+8): grass and foliage |

Light comes from the top-left everywhere: highlights (`w`) on upper-left
edges, brown shade and cast shadows to the lower right.

Sprites: `$D025` = black (`k`, outlines), `$D026` = white (`w`). Sprite
colours the art is drawn for: Ollie brown (9), gators green (5), eagle
brown (9, white head/tail), Auntie orange (8), present red (2), balloon
light red or yellow, splash white, bubbles light blue (hires), sparkles
yellow (hires), fireworks any (hires), eagle shadow dark grey (hires). The
submerged Ollie silhouette (`OLLIE_UNDER*`) should be recoloured dark grey
or black; plain blue would vanish into the water.

## Game charset ($4800, multicolour)

| Codes | Use |
|---|---|
| `$00` | `CH_WATER`, plain water (blank in every animation frame) |
| `$01-$07` | ripple/glint chars (`CH_RIPPLE_FIRST`, 7 of them) |
| `$08` | `CH_LAND`, flat base grass |
| `$09-$0F` | grass variants: `CH_LAND_TUFT`, `_TUFT2`, `_FLOWER`, `_FLOWERS`, `_PEBBLES`, `_DIRT`, `_CLOVER` |
| `$10-$2E` | left-bank edge tiles (31, generated) |
| `$2F-$4D` | right-bank edge tiles (31, generated) |
| `$4E-$4F` | unused (blank) |
| `$50-$51` | crawfish pickup `CH_CRAWFISH_L/R` (frame 0) |
| `$52-$57` | collect "pop" ring, three 2x1 frames: `CH_POP0_L/R`, `CH_POP1_L/R`, `CH_POP2_L/R` |
| `$58-$59` | fish pickup `CH_FISH_L/R` (frame 0): silver fish, restores Life Points |
| `$5A-$5F` | gifts for Auntie, 2x1 each from `CH_GIFT_FIRST`: `CH_GIFT0_L/R` water-lily blossom, `CH_GIFT1_L/R` birthday cake, `CH_GIFT2_L/R` wrapped gift box (`GIFT_KINDS` = 3) |
| `$60-$FE` | scenery stamp chars (113 of 159 used) |
| `$FF` | never a glyph: stamp code meaning "transparent, keep the cell" |

Animation tables:

- `water_anim_data`: `WATER_FRAMES` = 8 frames x 64 bytes. Copy frame k over
  chars `$00-$07`. Glints grow, shrink and twinkle in place (no vertical
  drift), so they never fight the downward scroll.
- `crawfish_anim_data`: `CRAWFISH_FRAMES` = 4 frames x 16 bytes, copied over
  `$50-$51`: pincers snap, the tail flicks and a sparkle moves round it.
- `fish_anim_data`: `FISH_FRAMES` = 4 frames x 16 bytes, copied over
  `$58-$59` (tail flick). Use the crawfish timer.
- `gift_anim_data`: `GIFT_FRAMES` = 2 frames x 48 bytes, copied over
  `$5A-$5F` (sparkles and flickering candles).

## Bank edge tiles

A bank edge inside one character row runs straight from `x_top` (multicolour
pixel where it crosses the row's top) to `x_bot` (8 lines down), with
`|x_bot - x_top| <= 2`. On pixel line `y = 0..7` the edge sits at

    e(y) = floor(x_top + (x_bot - x_top) * (2y + 1) / 16 + 0.5)

- Left bank: x < e(y) is land. Land pixel `e-1` is mud `b`, water pixel `e`
  is foam `w`.
- Right bank: x >= e(y) is land. Land pixel `e` is mud `b`, water pixel
  `e-1` is foam `w`.
- Other land pixels copy `CH_LAND` at `(x mod 4, y)`; other water pixels are
  `.`.

For char column c, `lt = x_top - 4c` and `lb = x_bot - 4c`. All
`lt` in -2..7 and `d = lb - lt` in -2..2 are rendered. Results equal to
plain water become `$00`, results equal to `CH_LAND` become `$08`, and the
rest are deduplicated (left bank first). That gives 31 unique tiles per side
(62 in total; the spec estimated 64). `edge_lut_left` and `edge_lut_right`
have 50 bytes each: index `(lt+2)*5 + (d+2)`, value = char code. For a left
bank, `lt > 7` means the cell is fully land and `lt < -2` fully water. For a
right bank it is the other way round.

## Scenery stamps

Stamp tables in `gfx_tables.asm`: `stamp_w`, `stamp_h`, `stamp_class`,
`stamp_lo`/`stamp_hi` -> `stamp_N_chars` (w*h codes, row-major, top row
first, `$FF` = keep the underlying cell). Constants are in `gfx_ids.asm`.
Uncovered pixels inside a stamp cell carry base grass (land classes) or
plain water (WATER class), so stamps sit cleanly on any grass variant.

| Class | Stamps |
|---|---|
| 0 LAND | `TREE_OAK` 3x3, `TREE_ROUND` 2x2, `TREE_FRUIT` 3x3 (blossom), `PINE` 2x3, `BUSH` 1x1, `BUSH_WIDE` 2x1, `FLOWERS` 2x1, `FLOWER` 1x1, `ROCKS` 2x1, `ROCK` 1x1, `STUMP` 1x1, `MUSHROOMS` 1x1, `LOG` 3x1, `COTTAGE` 3x3 |
| 1 WATER | `LILY` 1x1, `LILY_FLOWER` 1x1, `LILY_WIDE` 2x1, `WATER_ROCK` 2x1, `LOG_FLOAT` 3x1 |
| 2 SHORE_L | `REEDS_L` 1x2, `CATTAILS_L` 1x2. Put them on the fully-land cell just left of a left-bank edge tile; the reeds lean toward the water |
| 3 SHORE_R | `REEDS_R`, `CATTAILS_R` (mirrors). Put them just right of a right-bank edge |
| 4 SPECIAL | `AUNTIE_HOUSE` 6x5 (land, door at bottom centre), `DOCK` 4x3 (water, plank landing that fits either bank), `BUNTING` 5x1 (land), `BALLOONS` 2x2 (land) |

The trees' cast shadows fall into their lower-right cells, so leave a free
cell to the right of and below a tree when you can.

## Text charset ($5000, hires)

Row 7 of every glyph in `$00-$7F` is empty (raster split line). The tool
checks this.

| Codes | Use |
|---|---|
| `$00-$3F` | 7x7 arcade font in screen-code order (`@`, `A-Z`, `[ £ ] ↑ ←`, space, punctuation, `0-9`, `: ; < = > ?`) |
| `$40/$41` | `TX_HEART_FULL`, `TX_HEART_EMPTY` |
| `$42-$4A` | `TX_BAR_0` .. `TX_BAR_8`: life-bar cell filled n/8 from the left |
| `$4B/$4C` | `TX_BAR_LEFT` (rounded cap with a fill stub), `TX_BAR_RIGHT` |
| `$4D-$4F` | `TX_ICON_OTTER`, `TX_ICON_CRAWFISH`, `TX_ICON_EAGLE` |
| `$50-$53` | progress track: `TX_TRACK`, `TX_TRACK_START` (flag), `TX_TRACK_HOME` (house), `TX_TRACK_OLLIE` (Ollie's head on the line) |
| `$54` | `TX_ICON_BUBBLE` (air/dive) |
| `$55-$5F` | `TX_CURSOR_RIGHT/LEFT`, `TX_STAR`, `TX_STAR_SMALL`, `TX_NOTE`, `TX_TROPHY`, `TX_GIFT`, `TX_JOYSTICK`, `TX_SPEED`, `TX_CLOCK`, `TX_COPYRIGHT` |
| `$60-$67` | bamboo menu frame: `TX_FRAME_TL/TOP/TR/LEFT/RIGHT/BL/BOTTOM/BR`. The empty row 7 reads as the cane's joints |
| `$68-$77` | `TX_WAVE_A/B`, `TX_DIVIDER`, `TX_DIVIDER_GEM`, `TX_GRASS_A/B`, `TX_ARROW_UP/DOWN`, `TX_FISH`, `TX_PAW`, `TX_DROP`, `TX_BULLET`, `TX_CHECK`, `TX_CROSS`, `TX_HEART_SMALL`, `TX_SPARKLE` |
| `$80-$DA` | title logo chars (`TX_LOGO_FIRST`, `TX_LOGO_COUNT` = 91). These may use row 7 |
| rest | blank |

Title logo: "OTTER RAID", `TITLE_LOGO_W` x `TITLE_LOGO_H` = 36 x 7 cells.
`title_logo_map` is row-major with `$20` for blank cells. Rows 0-4 are
chunky bevelled letters with an inline highlight. Give each cell row its
own colour (warm gradient, cycling). Rows 5-6 are the logo's rippled
reflection on the river and look best in light blue and blue.

## Sprites ($5800, pointer = 96 + slot)

Multicolour sprites are 12x21 fat pixels and hires sprites are 24x21.
Slots follow source order; the authoritative list is `gfx_ids.asm`.

| Slots | Sprites |
|---|---|
| 0-12 | `SPR_OLLIE_SWIM0-3` (left stroke, pull, right stroke, glide), `_LEFT`, `_RIGHT`, `_DIVE0-2`, `_UNDER0-1`, `_HURT`, `_CAUGHT` |
| 13-22 | `SPR_GATOR_R0-2`, `_L0-2` (mirrors), `_BITE_R/L`, `_LURK_R/L` |
| 23-28 | `SPR_EAGLE0-3`, `_DIVE`, `_CARRY`. The head points down the screen. Drawn for X+Y expansion |
| 29-31 | `SPR_SPLASH0-2` (multicolour, white) |
| 32-39 | `SPR_BUBBLES0-1`, `SPR_SPARKLE0-3`, `SPR_EAGLE_SHADOW0-1` (all hires) |
| 40-45 | `SPR_AUNTIE0-1`, `SPR_OLLIE_FRONT0-1`, `SPR_PRESENT`, `SPR_BALLOON` |
| 46-49 | `SPR_FIREWORK0-3` (hires burst) |
| 50-53 | `SPR_TITLE_OLLIE_TL/TR/BL/BR`: 48x42 portrait |

Title portrait: place TL/TR/BL/BR at (x, y), (x+24, y), (x, y+21),
(x+24, y+21). Put `SPR_PRESENT` (red) at (x+12, y+23) on a higher-numbered
sprite, so it sits behind the portrait. Its red box then shows through the
see-through window between Ollie's paws. Without the overlay, the box shows
as an outline with a white ribbon.

## Source format (`gfx/*.gfx`)

    ; comment (everything after ';')
    @kind [NAME] key=value ...
    <pixel rows; whitespace inside a row is ignored>

| Block | Meaning |
|---|---|
| `@water frame=k [names=..]` | 32x8: chars `$00-$07` for one animation frame |
| `@chars at=$xx names=A,B,..` | multicolour chars, 4 px each, left to right (constants `CH_<name>`) |
| `@crawfish frame=k` | 8x8: chars `$50-$51` for one frame |
| `@fish frame=k` | 8x8: chars `$58-$59` for one frame |
| `@gifts frame=k` | 24x8: chars `$5A-$5F` (three 2x1 gifts) for one frame |
| `@stamp NAME class=.. [bg=land/water]` | stamp image, `-` = transparent |
| `@tchars at=$xx [names=..] [color=n]` | hires glyphs side by side, 8 rows per band (constants `TX_<name>`) |
| `@logo NAME` | title logo bitmap (`#`/`.`), cut into 8x8 cells |
| `@sprite NAME [hr] [color=n] [mirror=OTHER]` | 21 rows of 12 (multicolour) or 24 (hires) pixels |
| `@bigsprite NAME cols=2 rows=2 names=..` | one image split into several sprites |
| `@anim NAME frames=.. delay=ms bg=.. expand=0/1` | preview GIFs only |

Files are read in a fixed order (see `SOURCE_FILES` in `tools/gfx.py`),
which sets sprite slots and stamp indices. The engine only uses the
generated constants, so after adding or reordering assets, reassemble.
