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
6. Recover Life Points while swimming safely.
7. Reach the end of the river.
8. Celebrate with Auntie, Ollie, and the birthday present.
9. See the score/high-score flow and play again.

If Ollie runs out of Life Points, a heart is lost and the run resets. An eagle catch also costs a heart and resets the run. Lose all three hearts and it's Game Over.

## Controls
| Key | Action |
| --- | --- |
| W | Swim faster / upstream |
| A | Move left |
| S | Slow down |
| D | Move right |
| SPACE | Dive |

Joystick control is part of the initial single-player design. Keyboard support is an additional control method.

## Gameplay Systems
### Life Points
- Start: **1,000**
- Maximum: **10,000**
- Recover while swimming safely
- Alligator damage starts at **100 points**
- Diving longer than 3 seconds costs **50 points/second**

### Hearts
Ollie starts with **3 hearts**. Reaching zero Life Points costs a heart and restarts the run. The eagle can also take a heart directly.

### Diving
Ollie can dive underwater for free for **3 seconds**. While underwater, he is immune to alligators and the eagle. Staying underwater longer costs 50 Life Points per second.

### Alligators
Alligators enter from the river banks and cross the river at varying speeds. Their movement is intended to be less predictable than simple fixed patrols.

### Eagle
Every roughly **90–120 seconds**, an eagle swoops diagonally across the river from one side to the other. Diving protects Ollie from the attack.

### Crawfish
Catching a crawfish gives Ollie **5 seconds of invulnerability**.

### River
The river scrolls downward to create the illusion of swimming upstream. Its banks form smooth bends and varied sections while retaining enough width for maneuvering.

Future scenery can include islands, houses, and other river details.

## The Homecoming
Reaching the destination triggers a short celebration rather than simply ending the game.

Ollie and Auntie will meet with the birthday present between them, followed by a small celebratory animation before returning to the score/high-score flow.

## Development
The current development direction is a **gameplay-engine rewrite** rather than continuing to patch the original monolithic assembly source.

The rewrite will establish:
- Explicit game states
- A documented C64 memory map
- Separate player/input/river/enemy/eagle/collision/HUD/menu systems
- Smooth procedural river generation
- A finite distance-based journey
- A complete start-to-home game loop

The detailed design is in **docs/otter-raid-game-design.md**.

The implementation work is tracked in the GitHub issue for the gameplay-engine rewrite.

## Current Platform
- Commodore 64/128 (in 64 mode)

### Planned
- Commander X16

## Building
Using DASM:

    dasm otter_raid.asm -ootter_raid.prg

Using the Makefile with VASM:

Comment out processor=6502 on line 1 as required by the current build setup.

<hr>