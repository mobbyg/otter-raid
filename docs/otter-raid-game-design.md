# Otter Raid — Game Design

## 1. Game Concept
Otter Raid is a Commodore 64 action game inspired by River Raid, but with Ollie Otter swimming upstream instead of a jet flying over a river.

Ollie is trying to make it home in time for Auntie's birthday party. Friends and family are waiting, and Ollie has a present to deliver.

The river is dangerous. Alligators enter from the banks, an eagle periodically swoops across the river, and Ollie must manage his swimming speed and positioning while collecting crawfish for temporary protection.

The game is a finite journey, not an endless survival game. Reaching the end of the river triggers a short celebration sequence with Ollie, Auntie, and the present.

## 2. Core Game Flow
1. Title screen
2. Main menu
3. Start a new run
4. Ollie begins near the bottom-center of the river
5. Swim upstream toward home
6. Avoid alligators and the eagle
7. Collect crawfish for temporary invulnerability
8. Build Life Points by swimming safely
9. Lose Life Points when hit by hazards
10. Losing all Life Points costs one heart and resets the run to the beginning
11. Losing a heart to the eagle also resets the run
12. Three hearts lost = Game Over
13. Reaching the destination = Home celebration
14. Return to score/high-score flow and allow another run

A new run may use a different procedural river sequence, so resetting to the beginning does not necessarily mean replaying the exact same river.

## 3. Player
The player controls Ollie Otter.

Starting state:
- Position: approximately bottom-center of the river
- Life Points: 1,000
- Hearts: 3
- Maximum Life Points: 10,000

Movement:
- Left/right to position Ollie across the river
- Up to swim faster upstream
- Down to slow down
- Dive underwater

Intended keyboard mapping: W = faster/upstream, A = left, S = slower/downstream, D = right, SPACE = dive.

Joystick control is required for the initial single-player version. Keyboard controls are an additional control method. A future two-player mode may allow players to take turns.

## 4. Swimming Speed and Distance
The game represents progress as distance traveled upstream rather than relying only on elapsed time. The initial journey is 40 generated river sections.

This gives Up/Down movement a meaningful tradeoff: swimming faster gets Ollie home sooner, while swimming slower gives the player more time to maneuver around hazards. Higher speed can also make collisions more consequential.

The initial journey is **40 river sections**. The section count is deliberately tunable: it can be reduced or extended after playtesting without changing the underlying game architecture.

## 5. Life Points
Life Points are Ollie's temporary survival resource and are separate from score.
- Start at 1,000
- Maximum 10,000
- Life Points recover through a tracked **safe_distance** value while Ollie is making upstream progress without taking hazard damage
- Alligator collisions remove Life Points
- Diving longer than the free dive period removes Life Points
- Life Points reaching zero costs one heart

The initial alligator damage target is 100 Life Points per hit. A simple speed-based damage modifier may be introduced during tuning, but the base implementation should remain simple and predictable.

When Life Points reach zero: lose one heart, end the current run, return Ollie to the beginning, and reset Life Points to 1,000. If no hearts remain, go to Game Over.

When a heart is lost, establish a recovery target at **Life Points at loss + 5,000**. Reaching that target restores one heart, up to three. A later heart loss establishes a new target from the Life Points held at that moment.

## 6. Hearts
Ollie starts with 3 hearts.

A heart is lost when Life Points reach zero or when the eagle successfully catches Ollie. After a heart is lost, the river run resets to the beginning.

## 7. Diving
SPACE makes Ollie dive underwater.
- Ollie is immune to alligator collisions while diving
- Ollie is immune to eagle attacks while diving
- The first 3 seconds are free
- Beyond 3 seconds costs 50 Life Points per second

Diving is a deliberate defensive tool, not a permanently safe movement mode. The player should receive a clear visual indication that Ollie is underwater.

## 8. Alligators
Alligators are the primary river hazard.
- Begin near either river bank
- Enter/cross the river
- Move at varying speeds
- Can approach from either side
- Four active alligators are supported initially
- Alligators are independent world objects and do not collide with one another

Alligators should be world objects with position, side, direction, speed, and movement state rather than fixed patrol sprites.

## 9. Eagle
The eagle is a periodic major threat.
- Appears approximately every 90–120 seconds
- Randomly chooses the attack side
- Swoops diagonally across the river
- Continues off the opposite side if it misses
- Produces a V-like visual flight path

Suggested state machine: waiting -> choose interval -> choose side -> enter -> swoop -> collision/catch check -> exit -> waiting.

If the eagle catches Ollie, one heart is lost and the current run resets to the beginning. Diving makes Ollie immune.

## 10. Crawfish
Crawfish are generated as part of the river environment and may be difficult or risky to reach.

Catching/eating a crawfish gives Ollie 5 seconds of invulnerability against both alligators and the eagle.

The player should receive a strong visual indication when the protection is active.

## 11. River and Scrolling
The river scrolls from top to bottom, creating the illusion that Ollie is swimming upstream.

The river should not be one perfectly straight channel. Left and right banks remain broadly symmetrical, leave enough playable width, and form smooth bends and varied sections.

Random row-by-row bank changes should be avoided because they create jitter rather than meaningful river shape. The river should be generated as smooth segments or sections with controlled variation.

Initial bank collisions do not damage Ollie; the banks primarily constrain movement.

Future environmental objects can include islands, houses, and other river scenery. Existing Issue #8 should be incorporated into the new river-generation system rather than implemented as a separate patch.

## 12. HUD
The C64 has a 40-column display. The intended top HUD contains score toward the left, title/high-score information near the center, hearts toward the right, and Life Points in a compact readable form.

The exact final text layout will be determined during implementation. The HUD remains stable while the playfield scrolls.

## 13. Score
Score and Life Points are separate systems.

Life Points are a temporary survival resource. Score is a persistent measure of game achievement and is used for high-score purposes.

The exact scoring formula is intentionally open for the first implementation pass. Candidate score sources include upstream distance, crawfish collected, survival milestones, reaching home, and other clearly communicated achievements.

## 14. Home / Ending
When Ollie reaches home:
1. Gameplay stops.
2. A short celebratory scene begins.
3. Ollie and Auntie appear together.
4. The present is visible between them.
5. A small animation plays, such as Ollie and Auntie celebrating/dancing.
6. A completion message is displayed.
7. The game transitions to the score/high-score flow.

The celebration should be roughly 5–10 seconds and feel like a reward. Ollie is not merely surviving indefinitely; he is trying to get home.

## 15. Title and Menu
The title screen should use a picture/image-oriented presentation rather than a plain text screen, with a small menu inspired by Attack of the PETSCII Robots.

The main menu will include at least:
- Start Game
- High Scores
- Controls
- Exit

An About entry may be added if the final screen has room.

## 16. Game States
Use explicit game states instead of allowing unrelated systems to control one another implicitly:
- TITLE
- MENU
- PLAYING
- LIFE LOST / RESET
- GAME OVER
- HOME / CELEBRATION
- HIGH SCORES
- PAUSED

The eagle and other hazards have their own internal state machines while the main game state remains PLAYING.

## 17. Technical Direction
The existing assembly source has accumulated independent gameplay patches. The next phase is therefore a gameplay-engine rewrite, not another sequence of isolated fixes.

Existing art, sprites, and useful routines may be retained where practical.

Proposed source responsibilities:
- c64/main.asm — startup and main loop
- c64/game.asm — game states and overall flow
- c64/input.asm — keyboard and joystick input
- c64/player.asm — Ollie movement, speed, diving
- c64/enemies.asm — alligator management
- c64/eagle.asm — eagle attack state machine
- c64/river.asm — river generation and scrolling
- c64/collision.asm — collision and damage
- c64/hud.asm — score, Life Points, hearts
- c64/menu.asm — title/menu/high-score screens
- c64/random.asm — random number generation
- c64/sprites.asm — sprite setup/data
- c64/data.asm — constants and game data

The exact file organization can change if the assembler/build system benefits from another arrangement, but responsibilities should remain separated.

## 18. C64 Memory Safety
Before gameplay code is rewritten, the C64 memory map must be explicitly documented.

Screen RAM, Color RAM, sprite pointers, sprite data, program/code, runtime variables, river data, generated object data, stack, and zero page must have deliberate non-overlapping allocations.

The current implementation has had sprite-data and screen-memory overlap, so memory layout is a first-class design concern.

## 19. Development Milestones
### Milestone 1 — Foundation
- Establish memory map and build layout
- Establish game-state machine
- Establish joystick and keyboard input
- Establish stable HUD
- Establish player movement and speed

### Milestone 2 — River
- Implement smooth procedural river sections
- Implement vertical scrolling
- Implement player/bank boundaries
- Verify screen/color memory handling

### Milestone 3 — Survival
- Implement Life Points
- Implement hearts and reset flow
- Implement Life Point recovery
- Implement dive and 3-second free-dive timer

### Milestone 4 — Hazards
- Implement alligator world objects
- Implement variable movement
- Implement collision/damage
- Implement crawfish and 5-second invulnerability
- Implement eagle attack state machine

### Milestone 5 — Journey
- Implement distance/progress
- Implement destination trigger
- Implement home celebration
- Implement game-over flow

### Milestone 6 — Presentation
- Implement title/menu screen
- Implement controls screen
- Implement high scores
- Tune HUD
- Add sound and animation polish

### Milestone 7 — Playtesting
Tune river width/bends, player speed, alligator frequency/speed, collision damage, Life Point recovery, eagle frequency, dive timing/cost, crawfish frequency, total journey distance, and scoring.

No tuning value is final until tested on C64-compatible hardware or emulation.

## 20. Open Design Questions
- Exact section length/distance contribution
- Exact swimming speed values and per-frame distance contribution
- Exact Life Point recovery rate
- Exact speed-based alligator damage experiment, if any
- Exact scoring point values
- Exact eagle flight timing/trajectory
- Final HUD layout
- Exact title-screen artwork
- Exact home celebration animation
- High-score persistence format
- Final raster-split/fine-scroll implementation details

The first implementation should establish the complete playable loop before optimizing or polishing these values.