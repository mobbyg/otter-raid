<p align="center"><img width="559" height="261" alt="Otter_Raid_Transparent" src="https://github.com/user-attachments/assets/07ee60e0-9172-4e74-9f6b-00f9a58f466b" /></p>
<h1 align="center">Otter Raid — A River Raid-Inspired C64 Game with Otters</h1>

Otter Raid is a Commodore 64 action game inspired by <i>River Raid</i>, with a decidedly more aquatic hero.

You are **Ollie Otter**, swimming upstream to get home for Auntie's birthday party. Friends and family are waiting, and Ollie has a present to deliver. Unfortunately, the river is full of alligators, and an eagle periodically swoops down looking for a meal.

The goal is not to survive forever. **Get Ollie home.**

## Game Flow

1. Start at the bottom of the river with **1,000 Life Points and 3 hearts**.
2. Swim upstream while managing speed and position.
3. Avoid alligators coming from either river bank.
4. Dive underwater to avoid alligators and the eagle.
5. Collect crawfish for **5 seconds of invulnerability**.
6. Recover Life Points through safe upstream progress.
7. Reach the end of the river.
8. Celebrate with Auntie, Ollie, and the birthday present.
9. See the score/high-score flow and play again.

If Ollie runs out of Life Points, a heart is lost and the run resets. An eagle catch also costs a heart and resets the run. Lose all three hearts and it's Game Over.

After losing a heart, Ollie can earn it back by reaching a recovery target of **Life Points at loss + 5,000**. The target is tracked from the Life Point total at the moment of each heart loss, up to three hearts.

## Controls

| Key | Action |
| --- | --- |
| W | Swim faster / upstream |
| A | Move left |
| S | Slow down |
| D | Move right |
| SPACE | Dive |
| P | Pause / resume |

Joystick control is part of the initial single-player design. Keyboard support is an additional control method.

## Gameplay Systems

### Life Points

- Start: **1,000**
- Maximum: **10,000**
- Recover through tracked safe upstream distance
- Alligator damage starts at **100 points**
- Diving longer than 3 seconds costs **50 points/second**
- Life Points are separate from score

### Hearts

Ollie starts with **3 hearts**.

A heart is lost when:
- Life Points reach zero
- The eagle catches Ollie

Losing a heart resets the current river run while preserving the overall score. If all three hearts are lost, the game goes to Game Over.

A recovered heart is earned after **5,000 newly accumulated Life Points** following a heart loss, up to the maximum of three hearts.

### Diving

Ollie can dive underwater for free for **3 seconds**.

While diving:
- Alligators cannot hurt Ollie.
- The eagle cannot catch Ollie.

Staying underwater longer costs **50 Life Points per second**.

Diving protection and crawfish protection are independent. If both are active, Ollie remains protected until both protections have ended.

### Alligators

Alligators enter from the river banks and cross the river at varying speeds.

Each alligator is an independent world object with its own position, side, direction, speed, and movement state. Alligators can occupy different river rows, including facing one another from opposite banks, without interacting or colliding with each other.

The rewrite uses a fixed pool of independent alligator objects rather than fixed patrol patterns, with **4 active alligators supported initially**. Alligators do not collide with one another.

### Eagle

Every roughly **90–120 seconds**, an eagle attacks from a randomly selected side and swoops diagonally across the river toward the opposite side.

If it misses Ollie, it continues off the opposite side rather than turning around for another attack.

Diving or crawfish protection prevents the eagle from catching Ollie.

The eagle's attack timer resets when a run resets.

### Crawfish

Crawfish appear as part of the generated river environment.

Catching a crawfish gives Ollie **5 seconds of invulnerability** against both alligators and the eagle.

Crawfish are not guaranteed to be safely reachable. A player may have to decide whether pursuing one is worth the positioning and hazard risk.

### River

The river scrolls downward to create the illusion of swimming upstream.

The rewrite uses **40 smooth river sections** rather than jagged row-by-row randomness. Sections stitch together through shared endpoint geometry and controlled bends/width changes. Only the nearby/current river data needs to be resident in RAM; the 40-section journey is a logical progression rather than 40 full sections stored at once.

River sections can also provide opportunities for scenery, alligator placement, and crawfish placement. Future scenery can include islands, houses, and other river details.

### Distance and Speed

Progress toward home is measured by **distance traveled upstream**, not simply elapsed time.

Swimming faster advances the journey faster but gives the player less time to maneuver and recover Life Points. Swimming slower advances the journey more slowly but gives the player more control and time.

The initial implementation uses three discrete swimming speeds: **1 = slow, 2 = normal, 3 = fast**. Up/W and Down/S are held controls; the actual distance contribution of each speed will be tuned through playtesting.

## State Machines

The rewrite uses explicit state machines so that the game's behavior remains predictable and manageable in 6502 assembly.

The main game states are:

- **TITLE**
- **MENU**
- **PLAYING**
- **LIFE_LOST**
- **GAME_OVER**
- **HOME**
- **HIGH_SCORES**
- **PAUSED**

While the main game is PLAYING, individual systems have their own state:

- Ollie has independent dive and crawfish-protection timers.
- Each alligator has its own movement state.
- The eagle has an independent attack state machine.
- Crawfish have active/inactive/collected states.
- The river manages its current generated section and scroll position.

The full state-machine design is documented in **docs/c64-state-machine.md**.

## The Homecoming

Reaching the destination triggers a short celebration rather than simply ending the game.

Ollie and Auntie will meet with the birthday present between them, followed by a small celebratory animation before returning to the score/high-score flow.

## Development

The current development direction is a **gameplay-engine rewrite** rather than continuing to patch the original monolithic assembly source.

The rewrite will establish:

- Explicit game states and transitions
- A documented C64 memory map
- Separate player/input/river/enemy/eagle/collision/HUD/menu systems
- Smooth procedural river generation
- A finite distance-based journey
- A complete start-to-home game loop
- Deliberate memory-safe storage for screen, sprites, runtime objects, and code

Before gameplay assembly is written, the design and architecture are being documented and reviewed.

The detailed game design is in **docs/otter-raid-game-design.md**.

The C64 memory layout is in **docs/c64-memory-map.md**.

The state-machine design is in **docs/c64-state-machine.md**.

The frame/update contract is in **docs/c64-frame-update-flow.md**.

The river architecture is in **docs/c64-river-engine.md**.

The object/collision architecture is in **docs/c64-object-and-collision-system.md**.

The implementation work is tracked in the GitHub issue for the gameplay-engine rewrite.

## Current Platform

- Commodore 64/128 (in 64 mode)

### Planned

- Commander X16

## Building

The rewrite's build path is being standardized around VASM.

    make

The Makefile invokes `vasm6502_mot` and produces `otter_raid.prg`.

<hr>
