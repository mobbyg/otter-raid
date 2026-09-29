# Otter Raid — C64 Frame Update Flow

## Purpose

This document defines what happens during one gameplay tick of Otter Raid. It bridges the game-state machine and the runtime memory layout so that the assembly implementation has a predictable order of operations.

The goal is not to force every operation into one monolithic routine. It defines the **logical order** in which systems are evaluated.

## Timing Model

The game is intended to run as a stable C64 frame-driven game.

The rewrite will use the C64/KERNAL jiffy clock as a convenient timing source for second-based timers rather than inventing a separate wall-clock system.

The KERNAL jiffy clock is a 24-bit counter maintained by the system IRQ. The game should copy or sample it through a small timing routine rather than allowing individual gameplay systems to read the KERNAL locations independently.

Gameplay timers that must freeze during PAUSED should be represented by game-owned counters or by measuring jiffy deltas only while PLAYING. The jiffy clock itself is allowed to continue advancing while paused.

This gives us both:
- a standard C64 timing source for seconds and longer intervals
- deterministic game-owned timing that can be frozen when necessary

The exact PAL/NTSC frame-rate differences will be handled by the timing layer rather than scattered through gameplay code.

## One PLAYING Tick

Conceptually, one gameplay tick proceeds as follows:

```text
FRAME START
    |
    v
1. Read input
    |
    v
2. Update player speed
    |
    v
3. Update Ollie movement
    |
    v
4. Update dive/protection timers
    |
    v
5. Update river scroll/generation
    |
    v
6. Update alligator objects
    |
    v
7. Update crawfish objects
    |
    v
8. Update eagle timer/state
    |
    v
9. Resolve collisions
    |
    v
10. Apply damage/protection/collection effects
    |
    v
11. Update safe-distance and Life Points
    |
    v
12. Update journey distance
    |
    v
13. Update score
    |
    v
14. Update heart-recovery target
    |
    v
15. Test major transitions
    |
    v
16. Update sprite positions/animation
    |
    v
17. Update HUD
    |
    v
FRAME END
```

This order is the initial architecture. Individual routines may combine work for performance once the engine is working.

## 1. Read Input

Keyboard and joystick input are normalized into the same logical controls.

### Controls

- Left: move left
- Right: move right
- Up/W: swim faster
- Down/S: swim slower
- Fire/SPACE: dive
- P: pause

Movement controls are **held controls**. There is no tap-to-change-speed requirement.

The input layer should produce flags/values such as:

- move_left
- move_right
- speed_up
- speed_down
- dive
- pause_requested

The gameplay engine does not care whether the command came from keyboard or joystick.

## 2. Update Player Speed

The first implementation uses three discrete speed levels:

- Speed 1 — slow
- Speed 2 — normal
- Speed 3 — fast

Holding Up/W requests a higher speed. Holding Down/S requests a lower speed.

The exact distance contribution of each level is intentionally a tuning value. The speed system should therefore store a small level value while the movement/river system converts that level into actual per-frame progress.

This makes it easy to test alternate speed constants without redesigning the game.

## 3. Update Ollie's Movement

Left/right movement changes Ollie's horizontal position within the current playable river boundaries.

The player should have a smaller logical hitbox than the visible sprite.

The player cannot move outside the river.

Bank contact initially constrains movement but causes no damage.

Up/down speed changes affect upstream progress and river scrolling, not Ollie's screen Y position in the normal play mode. Ollie remains visually near the lower portion of the playfield while the world moves downward.

## 4. Update Dive and Protection

Diving is an independent flag/timer, not a mutually exclusive player state.

The player may simultaneously be:
- swimming at Speed 1/2/3
- diving
- crawfish-protected

Protection is:

```
protected = diving OR crawfish_invulnerable
```

The first three seconds of a continuous dive are free.

After three seconds, the game drains approximately 50 Life Points per second.

Collecting a crawfish starts a five-second invulnerability timer.

If both timers are active, protection remains active until both protections have ended.

## 5. Update River Scroll and Generation

The river is a continuous world, not a collection of unrelated screen rows.

The preferred rendering strategy is:

1. Keep the top HUD outside the scrolling playfield.
2. Use the VIC-II's vertical fine-scroll capability for the river playfield.
3. When fine scrolling crosses a character-row boundary, advance the logical river rows and generate the newly exposed row/section data.
4. Generate bank positions from smooth section geometry rather than randomizing each row independently.
5. Update both screen characters and Color RAM for newly exposed river content.

A raster split can keep the HUD visually fixed while the playfield fine-scrolls.

This gives smooth visual motion without requiring the entire 24-row playfield to be redrawn every frame.

The exact raster/screen implementation will be validated in the first river prototype before being considered final.

## 6. Update Alligators

Each active alligator is updated independently.

For each object slot:
- update world Y
- update X
- apply movement direction/speed
- update state
- determine whether it remains active
- update animation

The initial maximum is **4 simultaneously active alligators**.

They do not collide with one another.

Their world positions are independent, so two alligators may occupy different river depths and face each other from opposite banks.

## 7. Update Crawfish

Crawfish are generated as part of the river environment.

Active crawfish are moved with the world and remain associated with their river-world position.

The initial implementation should support a small fixed object pool rather than dynamic allocation.

The player may collect a crawfish even when reaching it is difficult or risky. That is intentional gameplay rather than an invalid placement.

## 8. Update Eagle

The eagle has its own timer and state machine.

The next attack interval is randomized to approximately 90–120 seconds.

When the timer expires:
1. Choose a random attack side.
2. Enter from that side.
3. Swoop diagonally across the river.
4. Continue off the opposite side if Ollie is missed.
5. Do not turn around during that attack.
6. Reset the attack timer after the eagle leaves.

The eagle timer is reset whenever a run resets.

## 9. Resolve Collisions

Collision testing is centralized.

Use smaller logical hitboxes inside the visible sprites.

Initial collision pairs:

| Pair | Result |
|---|---|
| Ollie / alligator | 100 LP damage unless protected |
| Ollie / eagle | Lose one heart unless protected |
| Ollie / crawfish | Collect and start 5-second protection |
| Ollie / bank | Constrain movement |
| Alligator / alligator | No collision |

Collision detection should use the logical hitboxes, not the full visible sprite dimensions.

## 10. Apply Effects

Collision results are accumulated before changing the main game state.

Examples:
- gator hit → subtract 100 LP
- eagle catch → request heart loss
- crawfish collection → start invulnerability
- bank contact → adjust player X

A frame should not allow several gator overlaps to cause an uncontrolled cascade. The implementation should define a short hit cooldown or equivalent one-hit-per-contact behavior so that one physical encounter does not drain hundreds of points in a few frames.

The exact cooldown duration is a tuning value.

## 11. Safe Distance and Life Points

The game tracks a **safe_distance** value separately from total journey distance.

Safe distance increases while Ollie is actively making upstream progress without taking hazard damage.

When a damaging alligator collision occurs, safe_distance resets.

Life Points recover according to safe_distance/progress.

The exact recovery rate is a tuning value and will be tested in a dedicated playtest branch.

Life Points are capped at 10,000.

### Heart recovery

When a heart is lost, establish a recovery target based on the Life Points held at the moment of loss:

```heart_recovery_target = LP_at_loss + 5000
```

As Ollie earns Life Points during the new run, reaching that target restores one heart, up to three hearts.

Each subsequent heart loss establishes a new target from the current Life Points at that loss.

## 12. Update Journey Distance

Journey distance is separate from score and Life Points.

Each frame, the current speed level contributes to upstream distance.

The initial journey contains **40 river sections**.

The exact distance represented by each section is a tuning/implementation detail. The important rule is that reaching the end of section 40 triggers the homecoming sequence.

The section count can later be reduced or extended without changing the overall game architecture.

## 13. Update Score

Score is a persistent achievement metric.

The initial score sources are:

- distance/progress
- alligators successfully avoided
- crawfish collected
- bonus for hearts remaining
- homecoming completion bonus

The implementation should keep these score events separate so that the exact point values can be tuned without changing the gameplay systems.

Avoidance should be counted as a meaningful event, not simply as time spent alive.

## 14. Heart Recovery

Heart recovery is checked after Life Point changes and before the frame transition decision.

If the recovery target has been reached:
- increase hearts by one, up to three
- mark that recovery target as satisfied
- establish the next target only when another heart is subsequently lost

A recovered heart does not reset the current run.

## 15. Major Transition Checks

After gameplay effects have been resolved, check transitions in this order:

1. Final-heart loss → GAME_OVER
2. Non-final heart loss → LIFE_LOST
3. Destination reached while still alive → HOME
4. Otherwise remain PLAYING

A heart-loss transition ends normal gameplay processing for that frame.

HOME is only entered if Ollie is still alive after all collision effects.

This prevents contradictory results such as "reached home" and "lost final heart" occurring simultaneously.

## 16. Render/Presentation

Once the gameplay state for the frame is known:

- update sprite positions
- update sprite animation frames
- update river playfield data
- update HUD values that changed
- show dive/protection visual feedback
- show temporary effects such as OUCH!

The rendering layer should not make gameplay decisions.

## 17. PAUSED

When P is pressed during PLAYING:

```text
PLAYING <-> PAUSED
```

While PAUSED:
- river scrolling stops
- Ollie stops
- alligators stop
- crawfish stop
- eagle stops
- collisions stop
- Life Points stop changing
- distance stops changing
- score stops changing
- gameplay timers stop advancing

Music may continue playing.

The KERNAL jiffy clock may continue running underneath the pause, but gameplay timer calculations must not consume that elapsed time.

Pressing P again resumes PLAYING.

The PAUSED presentation can be a custom-character overlay rather than requiring a dedicated hardware sprite.

## 18. Performance Rule

The logical order above does not require every subsystem to scan every object every frame if a more efficient implementation is available.

The first implementation should favor correctness and clear ownership.

After the game is playable, profiling on C64-compatible hardware/emulation can determine whether routines need to be combined, table-driven, or otherwise optimized.

## 19. Frame Contract

At the end of every PLAYING frame, these facts should be unambiguous:

- Ollie's current position and speed
- whether Ollie is protected
- current Life Points
- current hearts
- current score
- current distance
- current river section
- active alligator objects
- active crawfish objects
- eagle state/timer
- next main game state

That is the contract between the gameplay engine and the renderer.
