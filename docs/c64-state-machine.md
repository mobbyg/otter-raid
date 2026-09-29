# Otter Raid — State Machine Design

## 1. Purpose

The rewrite uses explicit state machines to keep the game organized.

A state is simply the mode something is currently in, and a transition is the event that moves it to another state.

For example, the main game can be in TITLE, MENU, or PLAYING. While it is PLAYING, the eagle can independently be in WAITING, ENTERING, SWOOPING, or EXITING.

This document defines the behavior before assembly code is written.

## 2. Main Game State Machine

The main game state controls the overall mode of Otter Raid.

### States

- TITLE — Display the title artwork and wait for player input.
- MENU — Display the main menu and allow the player to choose an option.
- PLAYING — Run the actual river journey.
- LIFE_LOST — Brief transition after Ollie loses a heart; reset the run.
- GAME_OVER — Display the game-over screen and wait for the next action.
- HOME — Play the homecoming celebration.
- HIGH_SCORES — Display scores and handle the transition back toward another game.

### Main transitions

| Current State | Event | Next State |
|---|---|---|
| TITLE | Player presses Start/Fire | MENU |
| TITLE | Player presses another accepted input | MENU |
| MENU | Start Game selected | PLAYING |
| MENU | Controls selected | MENU / CONTROLS* |
| MENU | High Scores selected | HIGH_SCORES |
| PLAYING | Life Points reach zero and hearts remain | LIFE_LOST |
| PLAYING | Eagle catches Ollie and hearts remain | LIFE_LOST |
| PLAYING | Life Points reach zero with no hearts | GAME_OVER |
| PLAYING | Eagle catches Ollie with no hearts | GAME_OVER |
| PLAYING | Destination reached | HOME |
| LIFE_LOST | Reset work complete | PLAYING |
| GAME_OVER | Player chooses restart | PLAYING |
| GAME_OVER | Player chooses menu | MENU |
| HOME | Celebration complete | HIGH_SCORES |
| HIGH_SCORES | Player chooses another game | PLAYING or MENU |
| HIGH_SCORES | Player chooses to exit | MENU |

* A separate CONTROLS state can be added if the menu needs to become more than a simple screen. The initial implementation does not need to overcomplicate this.

### Important rule

Only the main game state decides whether the game is actually running.

For example, if the state is HOME, the river does not scroll, alligators do not move, the eagle does not attack, and collisions are not processed.

This prevents one subsystem from accidentally continuing to run during another screen.

## 3. PLAYING State

PLAYING is the main active game state.

Each game frame should perform the gameplay systems in a deliberate order:

1. Read player input.
2. Update Ollie's movement and swimming speed.
3. Update dive state and dive timer.
4. Update river position/scrolling.
5. Update alligators.
6. Update crawfish.
7. Update eagle.
8. Check collisions.
9. Apply Life Point/heart effects.
10. Update distance toward home.
11. Update score.
12. Update timers.
13. Update sprites and HUD.
14. Check for a state transition.

The exact order can change during implementation, but it should be deliberate rather than accidental.

## 4. Life-Loss State

LIFE_LOST is a short transition state rather than a second gameplay mode.

When Ollie loses a heart:

1. Stop normal gameplay updates.
2. Decrement hearts.
3. Determine whether any hearts remain.
4. If none remain, transition to GAME_OVER.
5. Otherwise reset the current run:
   - Ollie's position returns near bottom-center.
   - Life Points return to 1,000.
   - Dive state is cleared.
   - Temporary invulnerability is cleared.
   - River position returns to its starting point.
   - Active hazards are reset.
   - A new river sequence may be selected.
6. After reset work is complete, return to PLAYING.

The score is not reset by losing a heart.

The player's overall game attempt continues until all three hearts have been lost or the destination is reached.

## 5. GAME_OVER State

GAME_OVER is entered when Ollie has no hearts remaining.

Gameplay is stopped.

The game may display:

- Game Over
- Final score
- Distance reached
- Any other useful summary

If the score qualifies for the high-score table, the high-score entry process occurs before returning to normal menu flow.

Possible transitions:

- Restart → PLAYING
- Menu → MENU
- High Scores → HIGH_SCORES

The exact input/menu behavior can be tuned later.

## 6. HOME State

HOME is entered when Ollie reaches the destination.

Gameplay stops immediately.

The celebration sequence should be treated as its own small state machine so it can be animated without accidentally running normal river gameplay.

Suggested sequence:

1. HOME_SETUP — Stop river scrolling and place Ollie, Auntie, and present.
2. HOME_ARRIVE — Ollie reaches Auntie/home position.
3. HOME_PRESENT — Present is shown between them.
4. HOME_CELEBRATE — Play a short animation.
5. HOME_MESSAGE — Display the completion message.
6. HOME_DONE — Wait briefly or for player input.

After the celebration, transition to HIGH_SCORES.

The celebration should take approximately 5–10 seconds, subject to playtesting.

## 7. Title/Menu Flow

The title and menu are intentionally separate.

### TITLE

Displays the title artwork.

No gameplay systems run.

Accepted input moves to MENU.

### MENU

The menu may initially contain:

- Start Game
- Controls
- High Scores

A simple menu cursor/selection variable is sufficient.

The menu should not create a new game until Start Game is selected.

### Starting a new game

Starting a completely new game initializes:

- Hearts = 3
- Life Points = 1,000
- Score = 0
- Distance = 0
- Dive timer = 0
- Temporary invulnerability = 0
- Player position
- River seed/state
- Alligator objects
- Crawfish objects
- Eagle state

This is different from LIFE_LOST, which preserves the player's accumulated score.

## 8. Player State Machine

Ollie does not need a large state machine.

Suggested states:

- NORMAL
- DIVING
- INVULNERABLE

### NORMAL

Normal swimming.

- Alligator collision can hurt Ollie.
- Eagle can catch Ollie.
- Crawfish can be collected.

### DIVING

Triggered by SPACE or the joystick dive control.

- Alligator collision is ignored.
- Eagle collision is ignored.
- First 3 seconds are free.
- After 3 seconds, Life Points drain at 50 points per second.

If the player stops diving, return to NORMAL.

### INVULNERABLE

Triggered by collecting a crawfish.

- Alligator collision is ignored.
- Eagle collision is ignored.
- Protection lasts 5 seconds.

When the timer expires, return to NORMAL unless Ollie is still diving.

### Priority rule

If Ollie is both diving and has crawfish protection, both protections are active.

A collision should never damage Ollie while either protection is active.

## 9. Alligator State Machine

Each alligator is an independent world object.

Suggested states:

- INACTIVE
- ENTERING
- CROSSING
- EXITING
- COOLDOWN

### INACTIVE

No active alligator exists in this object slot.

The river/enemy manager may activate it when an appropriate spawn condition occurs.

### ENTERING

The alligator moves from its selected river bank toward the playable river area.

Its initial side, speed, direction, and starting position are selected when it spawns.

### CROSSING

The alligator moves across the river.

Its speed is allowed to vary between objects.

It can collide with Ollie during this state.

### EXITING

The alligator has crossed far enough to leave the playable area.

It continues moving until it is safely outside the active area.

### COOLDOWN

The object slot is temporarily unavailable for immediate reuse.

After the cooldown it returns to INACTIVE.

### Alligator design rule

Alligators should not be implemented as a single fixed patrol pattern.

Each active object should have its own:

- X position
- Y/world position
- Direction
- Speed
- Side
- State
- Active flag/timer as needed

This allows multiple alligators to behave differently.

## 10. Eagle State Machine

The eagle is a special timed hazard.

Suggested states:

- WAIT
- SELECT_ATTACK
- ENTER
- SWOOP
- EXIT
- COOLDOWN

### WAIT

No eagle is currently attacking.

The eagle timer counts toward the next attack.

The target interval is randomized to approximately 90–120 seconds.

### SELECT_ATTACK

When the timer expires:

1. Choose attack side.
2. Select the corresponding entry position.
3. Initialize the eagle's flight parameters.
4. Transition to ENTER.

### ENTER

The eagle enters from the selected side.

It should be visible before the main crossing begins.

### SWOOP

The eagle moves diagonally across the river.

The intended path crosses from one side toward the opposite side, creating the visual impression of a V-shaped swoop.

During this state:

- If Ollie is protected by diving, no catch occurs.
- If Ollie has crawfish invulnerability, no catch occurs.
- Otherwise, an eagle collision can catch Ollie.

### EXIT

If the eagle misses Ollie, it continues off the opposite side of the river.

It does not turn around to make a second attack during the same pass.

### COOLDOWN

The eagle disappears and the system returns to WAIT.

A new 90–120 second interval is selected before the next attack.

### Eagle catch

If the eagle catches Ollie:

1. Stop normal gameplay updates.
2. Lose one heart.
3. Reset the run through LIFE_LOST.
4. If no hearts remain, transition to GAME_OVER instead.

## 11. Crawfish State Machine

Crawfish are simpler collectible objects.

Suggested states:

- INACTIVE
- ACTIVE
- COLLECTED

### INACTIVE

No crawfish is currently present.

### ACTIVE

A crawfish is visible and can be collected.

### COLLECTED

The player has touched the crawfish.

On collection:

- Remove/hide the crawfish.
- Start the 5-second invulnerability timer.
- Increase score according to the eventual scoring rules.

Then the object returns to INACTIVE when its slot is reused.

## 12. River State

The river does not need to use a complicated state machine.

Its primary runtime state is:

- Current generated section
- Scroll position
- Left bank position
- Right bank position
- Section/segment index
- Generation seed/state

The river generator should produce smooth sections rather than changing the banks randomly every row.

A new section can be generated as Ollie approaches it.

### River reset

When a run resets:

- Return to the beginning of the river.
- Reset the river generator.
- Select a new seed if procedural variation is enabled.
- Clear old scenery/object placement as necessary.

This gives the player a new run without requiring the river to be identical every time.

## 13. Collision Rules

Collision processing should be centralized rather than scattered through every object routine.

The collision system checks:

### Ollie vs. alligator

If Ollie is:

- Diving → no damage
- Crawfish-protected → no damage
- Otherwise → remove 100 Life Points initially

The exact speed-based modifier remains a tuning decision.

### Ollie vs. eagle

If Ollie is:

- Diving → no catch
- Crawfish-protected → no catch
- Otherwise → lose one heart

### Ollie vs. crawfish

Collect crawfish and activate 5-second invulnerability.

### Ollie vs. river bank

Initially:

- Constrain Ollie's movement.
- Do not remove Life Points.
- Do not remove a heart.

## 14. Life Point and Heart Transitions

Life Points are separate from the state machine itself, but reaching certain values causes state transitions.

### Alligator hit

Life Points = Life Points - damage

If Life Points remain above zero:

- Continue PLAYING.

If Life Points reach zero:

- Lose one heart.
- Transition to LIFE_LOST.

### Dive drain

After the first 3 seconds of a continuous dive:

- Drain approximately 50 Life Points per second.

If this reaches zero:

- Lose one heart.
- Transition to LIFE_LOST.

### Heart recovery

After a heart has been lost, the player may regain a heart for every additional 5,000 Life Points earned, up to three hearts.

The exact implementation of the recovery threshold should be finalized during tuning.

## 15. Distance and Home Transition

Distance is the measure of actual progress toward home.

Each frame:

- Swimming speed contributes to upstream distance.
- Higher speed advances the journey faster.
- Lower speed advances the journey more slowly.

When:

Distance >= Destination Distance

the game transitions:

PLAYING -> HOME

The exact destination distance is intentionally a tuning value.

This makes Up/Down meaningful to the actual objective rather than merely changing a cosmetic speed number.

## 16. Frame-Level Transition Priority

When multiple events happen during the same frame, the game needs predictable priority.

Initial priority:

1. Fatal state transition / no hearts
2. Heart loss
3. Home reached
4. Other gameplay updates

More specifically:

- If an event causes the final heart to be lost, GAME_OVER wins.
- A heart-loss event should stop normal gameplay for that frame.
- HOME should only be entered while Ollie is still alive.
- Collision effects should be resolved before deciding whether the run continues.

This prevents contradictory results such as reaching home and losing the final heart on the same frame.

## 17. State Machine Implementation Model

The assembly implementation should have one main game-state variable.

Conceptually:

    game_state = TITLE

The main loop then dispatches to the routine belonging to that state.

Conceptually:

    TITLE       -> title_update
    MENU        -> menu_update
    PLAYING     -> play_update
    LIFE_LOST   -> life_lost_update
    GAME_OVER   -> game_over_update
    HOME        -> home_update
    HIGH_SCORES -> high_scores_update

These are conceptual names, not final labels.

The important part is that one place controls the main state.

Subsystem state variables are separate.

For example:

    game_state = PLAYING
    eagle_state = SWOOP
    player_state = DIVING

That means:

The game is playing, the eagle is currently swooping, and Ollie is underwater.

This is much easier to reason about than having unrelated routines decide independently whether the game should still be running.

## 18. Implementation Order

The rewrite should be implemented in this order:

### Phase 1 — Main state machine

Implement:

- TITLE
- MENU
- PLAYING
- LIFE_LOST
- GAME_OVER
- HOME
- HIGH_SCORES

Use placeholder screens where necessary.

### Phase 2 — Player state

Implement:

- Normal movement
- Speed
- Dive
- Dive timer
- Player reset

### Phase 3 — River

Implement:

- Scroll
- Smooth bank positions
- Player boundaries
- River reset

### Phase 4 — Resources

Implement:

- Life Points
- Hearts
- Life recovery
- Reset behavior

### Phase 5 — Hazards

Implement:

- Alligators
- Crawfish
- Eagle
- Their individual state machines

### Phase 6 — Collision

Centralize collision and damage rules.

### Phase 7 — Journey

Implement:

- Distance
- Destination
- Home celebration

### Phase 8 — Presentation

Add:

- Title artwork
- Menu artwork
- HUD polish
- Animations
- Sound
- High-score presentation

## 19. Design Principle

The state machine is not intended to make the game complicated.

It does the opposite.

At any moment we should be able to answer:

1. What is the game doing?
2. What is Ollie doing?
3. What is each hazard doing?
4. What event can change each state?

If those answers are explicit, the assembly code becomes much easier to build, debug, and change.

The state machine is therefore part of the game's architecture, not just an implementation detail.
