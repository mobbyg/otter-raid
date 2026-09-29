# Otter Raid C64 Memory Map

## Purpose

This document defines the planned Commodore 64 memory layout for the **Otter Raid gameplay-engine rewrite**.

The goal is to give the rewrite a deliberate memory architecture before assembly code is written. The layout reserves the C64 hardware areas, keeps screen/color memory separate from game data, provides structured runtime buffers, and leaves enough room for the rewritten engine to grow.

This is a **planned map**, not yet a final binary/linker map. Exact routine and asset sizes will be measured as the rewrite is implemented.

## Design Principles

1. Never place game data over C64 screen RAM.
2. Keep VIC-II-visible sprite data in the active VIC memory bank.
3. Give the game a named, documented zero-page allocation.
4. Keep gameplay state separate from temporary working buffers.
5. Allow the gameplay engine to be larger than the original project's small code window.
6. Avoid committing to a bitmap title screen until the engine and memory requirements are known.
7. Leave expansion room for music, sound effects, additional graphics, and future gameplay.
8. Treat the old monolithic source layout as legacy; this map is for the rewrite.

## Proposed Address Map

| Address range | Size | Planned use | Notes |
|---|---:|---|---|
| $0000-$0001 | 2 B | 6510 CPU port | Hardware; do not use as game RAM |
| $0002-$001F | 30 B | Reserved/system | Avoid depending on these locations |
| $0020-$007F | 96 B | Otter Raid zero page | Application-owned after startup |
| $0080-$00FF | 128 B | Reserved ZP | Expansion/scratch; avoid until needed |
| $0100-$01FF | 256 B | CPU stack | Do not use for persistent game data |
| $0200-$03FF | 512 B | Scratch/work buffers | Temporary calculations, collision work, pointers |
| $0400-$07E7 | 1000 B | Screen RAM | 40×25 character screen |
| $07E8-$07F7 | 16 B | Screen tail / available | Do not assume all is free without checking |
| $07F8-$07FF | 8 B | Sprite pointers | One pointer byte per hardware sprite |
| $0801-$1FFF | ~6.0 KB | Primary code area | Startup, main loop, small/common routines |
| $2000-$20FF | 256 B | Global runtime state | Game state, timers, counters, flags |
| $2100-$21FF | 256 B | Alligator objects | Structured enemy slots |
| $2200-$22FF | 256 B | Crawfish objects | Structured pickup slots |
| $2300-$23FF | 256 B | Eagle state/data | Eagle FSM and trajectory data |
| $2400-$24FF | 256 B | River state | Current banks, scrolling/segment state |
| $2500-$27FF | 768 B | Gameplay scratch | Collision, spawning, temporary buffers |
| $2800-$2FFF | 2 KB | River generation/segment buffers | Procedural river data and history |
| $3000-$33FF | 1 KB | Sprite data | 16 × 64-byte sprite slots |
| $3400-$3FFF | 3 KB | Static game data/assets | Tables, character data, title/menu assets |
| $4000-$7FFF | 16 KB | Extended code/data pool | Additional engine modules and larger routines |
| $8000-$9FFF | 8 KB | Expansion reserve | Future use; no dependency initially |
| $A000-$BFFF | 8 KB | BASIC ROM area / future banked RAM | Leave unmapped initially |
| $C000-$CFFF | 4 KB | Expansion reserve | Possible future code/data |
| $D000-$DFFF | 4 KB | VIC-II/SID/CIA/I/O and Color RAM | Hardware-mapped; do not use as normal RAM |
| $D800-$DBE7 | 1000 B | Color RAM | C64 color memory; access explicitly |
| $DBE8-$DFFF | — | I/O/color-memory region | Hardware-dependent; do not use as game RAM |
| $E000-$FFFF | 8 KB | KERNAL ROM / reserved | Leave mapped normally during initial development |

### Important

The ranges above are **logical reservations**, not a promise that every address is simultaneously available as ordinary RAM under every C64 memory configuration.

In particular:

- $A000-$BFFF is normally BASIC ROM.
- $D000-$DFFF is the I/O area, with Color RAM at $D800-$DBE7.
- $E000-$FFFF is normally KERNAL ROM.
- $8000-$9FFF is normally the cartridge address area and should not be made a dependency until the memory configuration is deliberately chosen.
- $C000-$CFFF is ordinary RAM in the normal configuration and is a useful future expansion area.

The initial rewrite should therefore stay within the straightforward RAM areas identified above.

## Zero-Page Allocation

The first 96 bytes of application-owned zero page are reserved at $20-$7F.

Initial allocation:

| Address | Name | Purpose |
|---|---|---|
| $20 | zp_player_x | Player X position |
| $21 | zp_player_y | Player Y position |
| $22 | zp_player_speed | Current upstream/downstream speed |
| $23 | zp_player_state | Player state flags |
| $24-$25 | zp_life | Life Points, 16-bit |
| $26-$29 | zp_score | Score, 32-bit |
| $2A | zp_hearts | Remaining hearts/lives |
| $2B | zp_dive_timer | Dive duration |
| $2C | zp_invuln_timer | Crawfish invulnerability |
| $2D-$2F | zp_distance | Journey distance/progress |
| $30 | zp_game_state | TITLE/MENU/PLAYING/etc. |
| $31 | zp_frame_counter | Frame timing / gameplay tick |
| $32 | zp_random | PRNG state |
| $33 | zp_temp | General temporary value |
| $34-$37 | zp_ptr0 | General pointer |
| $38-$3B | zp_ptr1 | General pointer |
| $3C-$3F | zp_ptr2 | General pointer |
| $40-$7F | Reserved | Future engine expansion |

### Zero-page policy

The rewrite should be treated as a mostly self-contained game after initialization. KERNAL/BASIC routines must not be assumed to preserve application zero-page locations.

If a future feature needs regular KERNAL calls during gameplay, the affected zero-page locations must be documented and protected rather than silently sharing them.

## Runtime Object Storage

Gameplay entities should use fixed-size object slots rather than independent variables scattered throughout the program.

### Alligators

The alligator region is $2100-$21FF.

A practical starting object layout is:

- X position
- Y/world position
- speed
- direction
- state
- animation frame
- active flag

For example, with 8-byte slots, the region supports 32 object slots. The game does **not** need to activate all 32 at once; the extra slots provide room for future tuning.

The exact slot size will be finalized when the enemy update and collision routines are written.

### Crawfish

Crawfish use $2200-$22FF.

Each slot can contain:

- X position
- Y/world position
- movement/state
- active flag
- animation frame

The initial game can use only a small number of active crawfish while retaining room for expansion.

### Eagle

The eagle uses $2300-$23FF.

This region is primarily state rather than a large object pool:

- current eagle state
- wait timer
- selected side
- entry/exit position
- trajectory progress
- animation frame
- collision state

The eagle state machine is planned as:

WAIT → SELECT SIDE → ENTER → SWOOP → COLLISION/CATCH CHECK → EXIT → WAIT

The normal appearance interval is 90–120 seconds, with variation rather than a fixed timer.

## River Data

The river uses $2400-$2FFF.

The river is intended to scroll continuously while being generated from smooth segments rather than independent random rows.

The design should support:

- left bank position
- right bank position
- segment length
- bank movement direction
- playable-width constraints
- scenery markers
- optional islands/houses/other scenery
- enough recent history to maintain smooth scrolling
- procedural variation between runs

The river engine is now specified as smooth sections with stitched endpoints and control points. The exact byte-level control-point representation will be finalized during the river prototype.

### River width

The river should remain wide enough for meaningful left/right maneuvering.

The two banks should generally remain visually balanced, while still allowing bends and changing width.

Initial bank collision does not damage Ollie; bank behavior can be revisited later if the game needs a stronger boundary mechanic.

## Sprite Memory

Sprite data is reserved at $3000-$33FF.

A C64 hardware sprite occupies 64 bytes, so this gives exactly 16 sprite slots:

| Address | Slot |
|---|---|
| $3000 | Sprite slot 0 |
| $3040 | Sprite slot 1 |
| $3080 | Sprite slot 2 |
| $30C0 | Sprite slot 3 |
| $3100 | Sprite slot 4 |
| $3140 | Sprite slot 5 |
| $3180 | Sprite slot 6 |
| $31C0 | Sprite slot 7 |
| $3200 | Sprite slot 8 |
| $3240 | Sprite slot 9 |
| $3280 | Sprite slot 10 |
| $32C0 | Sprite slot 11 |
| $3300 | Sprite slot 12 |
| $3340 | Sprite slot 13 |
| $3380 | Sprite slot 14 |
| $33C0 | Sprite slot 15 |

Potential initial use:

- Ollie animation frames
- alligator closed/open frames
- eagle frames
- crawfish frames
- future animation frames

The exact assignment will be made when the sprite system is rewritten.

This fixes a major problem in the old source: sprite data must not be copied into $0400-$07E7, because that range is the C64 screen.

## Screen and Color Memory

### Screen

$0400-$07E7 is the standard 40×25 C64 screen matrix.

The planned HUD occupies the top row:

- left: SCORE
- center: title/high-score area
- right: HEARTS

The remaining rows are available for the river and scenery.

### Sprite pointers

$07F8-$07FF contains the eight hardware sprite pointers associated with the standard screen page.

These bytes must remain available when using screen RAM at $0400.

### Color RAM

$D800-$DBE7 is C64 Color RAM.

All color writes should use a named COLOR_RAM constant or dedicated routines rather than hard-coded unrelated addresses.

## Code Layout

The original project is a single approximately 27 KB assembly source file. That source size is not a direct measure of final machine-code size, but it makes one thing clear: the rewritten engine should **not** assume that 6 KB is enough for the complete program.

The rewrite therefore uses two primary code regions.

### Primary code

$0801-$1FFF

This is the initial program/code area.

It is intended for:

- startup
- main loop
- state dispatch
- common utility routines
- small input/player routines
- frequently used shared code

### Extended code pool

$4000-$7FFF

This is reserved for additional engine code and larger routines.

It provides room for:

- river generation
- enemy update logic
- collision routines
- HUD/menu code
- animation systems
- audio code
- larger tables or data

The assembler/linking arrangement will be finalized when the rewrite begins. There is no requirement that the entire program occupy one contiguous address range.

This deliberately avoids the old assumption that the complete game must fit between $0800 and $1FFF.

## Static Data and Assets

$3400-$3FFF is reserved for relatively small static assets and lookup tables.

Possible contents include:

- movement tables
- river-generation tables
- animation metadata
- character sets
- menu data
- title graphics
- score formatting tables
- sound-effect parameter tables

### Title screen

A full C64 bitmap title screen is **not** locked into this map yet.

A true bitmap consumes a substantial contiguous graphics region and would change the allocation strategy. The initial plan is to support an image-like title using character graphics, multicolor characters, sprites, and/or a dedicated title screen layout.

If a bitmap title is later chosen, this memory map will be revisited before implementation.

## Game State

The gameplay engine will use explicit states rather than relying on scattered flags.

Planned states:

- TITLE
- MENU
- PLAYING
- LIFE LOST / RESET
- GAME OVER
- HOME / CELEBRATION
- HIGH SCORES

The state variable is allocated at zp_game_state.

A state owns its own update/draw behavior and transitions explicitly to another state.

## Player Resources

### Life Points

Life Points are separate from score.

- Starting Life Points: 1,000
- Maximum: 10,000
- Alligator hit: base 100-point loss
- Diving beyond the first 3 seconds: 50 Life Points per additional second
- Safe swimming: Life Points recover
- Reaching 0 Life Points: lose a heart and reset the run
- After a heart loss, Life Points return to 1,000

Safe-distance recovery rate remains a tuning value. Base alligator damage is 100 Life Points.

### Hearts

- Starting hearts: 3
- Eagle catch: lose one heart and reset
- Life Points reaching zero: lose one heart and reset
- No hearts remaining: Game Over

The heart counter is kept separately from Life Points.

## Journey Progress

The game is a finite upstream journey rather than an endless survival mode.

Distance/progress is stored separately from score.

The final journey length is not yet fixed.

The important architectural rule is:

> Upstream speed affects actual progress toward home.

This means W/D/S-style movement decisions can affect both risk and how quickly Ollie reaches the destination.

A successful run eventually reaches the home/celebration state, where Ollie meets Aunt and the family/friends for the birthday celebration.

## Expansion Reservations

The following areas are intentionally left available.

### $8000-$9FFF

Potential future expansion for code/data if the memory configuration is deliberately extended.

### $C000-$CFFF

Convenient future RAM for:

- music
- sound data
- additional graphics
- high-score storage
- larger lookup tables
- future gameplay systems

### $A000-$BFFF and $E000-$FFFF

These are not part of the initial game RAM plan because they are normally occupied by BASIC/KERNAL ROM.

If the final game needs more memory, banking those ROMs out can be considered as a later optimization.

## Named Hardware Constants

The rewritten assembly should use named constants rather than scattering hardware addresses throughout the source.

At minimum:

~~~asm
SCREEN_RAM  = $0400
COLOR_RAM   = $D800
SPRITE_PTRS = $07F8
SPRITE_DATA = $3000
~~~

Additional VIC-II, SID, CIA, and timing registers should likewise receive named constants in the appropriate hardware module.

## Migration From the Old Source

The old source should not be mechanically rearranged into this map.

Instead:

1. Preserve useful sprite artwork and proven low-level techniques.
2. Rebuild startup and memory initialization around this map.
3. Replace scattered gameplay variables with the documented zero-page/runtime structures.
4. Replace the old energy system with Life Points.
5. Rebuild river generation around the new buffered model.
6. Rebuild alligator movement as object-based entities.
7. Rebuild eagle behavior as an explicit state machine.
8. Rebuild collision handling around the new player/enemy state.
9. Build the explicit game-state system.
10. Add HUD, menu, home celebration, and high-score flow after the core engine is stable.

## Open Decisions Before Assembly

These are intentionally **not** frozen by this document:

- Exact journey distance
- Exact player speeds
- Exact Life Point recovery rate
- Whether alligator damage receives a speed-based modifier
- Exact active alligator slot layout (initial target: 4 active)
- Maximum simultaneous active crawfish (initial target: 2)
- Exact river section/control-point representation
- Exact scenery representation
- Eagle trajectory math
- Exact HUD character layout
- Title-screen graphics technique
- Home celebration animation length
- High-score persistence format
- Music/SFX memory requirements
- Final raster-split/fine-scroll implementation details
- Whether a later release will bank out BASIC/KERNAL ROM

These should be decided or prototyped before the portions of the memory map they affect become permanent.

## Initial Implementation Rule

**Do not write the new gameplay assembly until the memory map and state-machine design have been reviewed.**

The first implementation should establish:

1. startup and memory initialization
2. screen/color configuration
3. zero-page definitions
4. game-state dispatch
5. controller input
6. player movement
7. basic river scrolling

Only then should enemies, collision, scoring, Life Points, eagle behavior, crawfish, and the end-game sequence be layered in.


## Timing

The rewrite will use the C64/KERNAL jiffy clock as the standard source for second-scale timing rather than inventing an unrelated wall-clock system.

Gameplay code should access the jiffy clock through a timing routine and convert elapsed time into game-owned timers. This is important because the KERNAL clock itself continues while the game is PAUSED; gameplay timers must not advance during pause.

The timing layer will hide PAL/NTSC timing differences so gameplay systems do not contain scattered frame-rate assumptions.

## Rendering Strategy

The river playfield is planned as a smooth fine-scrolling region beneath a fixed HUD row. A raster split can keep the HUD fixed while VIC-II vertical fine scrolling moves the river.

When fine scrolling crosses a character-row boundary, the engine advances the logical river rows and generates only the newly exposed row rather than redrawing the entire playfield every frame.

This is the preferred approach for the first smooth-scrolling prototype, subject to validation on a C64-compatible target/emulator.
