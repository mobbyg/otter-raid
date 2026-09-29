# Otter Raid — C64 Object and Collision System

## Purpose

Gameplay objects in Otter Raid use fixed-size pools and centralized collision handling. The C64 should never need dynamic memory allocation during play.

## Object Pools

Initial active-object targets:

| Object | Maximum active |
|---|---:|
| Ollie | 1 |
| Alligators | 4 |
| Crawfish | 2 |
| Eagle | 1 |

The four-alligator target is intentional. If performance testing shows that fewer are needed, the active count can be reduced without changing the object model.

## Fixed Slots

Each object pool uses a fixed number of slots.

A slot contains only the state needed to update and collide the object, such as:
- active flag
- X position
- world Y position
- movement speed
- direction
- state
- animation frame
- timers as required

Exact byte layouts will be finalized when the assembly routines are written.

Unused slots remain inactive.

## Alligators

Four alligator slots are available to the gameplay engine.

Each alligator independently stores:
- active/inactive
- river side
- X position
- world Y position
- direction
- speed
- movement state
- animation frame
- hit/cooldown information as required

Alligators do **not** collide with one another.

Two alligators can therefore be:
- at different world depths
- on opposite sides
- moving toward one another
- visually facing each other

without interacting.

### Sprite orientation

The C64 VIC-II supports horizontal and vertical sprite expansion/flip controls through its sprite registers.

For the initial implementation, we should use **one gator sprite graphic and horizontal-flip it** when the same artwork can serve both directions.

This avoids wasting sprite memory on duplicate left/right artwork.

If a particular animation looks better with dedicated frames, separate frames can still be added later.

## Crawfish

Crawfish use a small fixed pool.

Each active crawfish stores:
- position
- world Y
- active state
- animation frame
- collection state as needed

Crawfish are generated as part of river sections.

A placement can be difficult or risky to reach. The generator does not need to guarantee that every crawfish is safely collectible.

## Eagle

The eagle is a single special object.

It stores:
- active state
- attack state
- side
- X/Y position
- trajectory progress
- animation frame
- attack timer
- collision status

Its attack interval is approximately 90–120 seconds.

The eagle enters from one side, crosses diagonally, and exits the opposite side. It does not reverse direction during an attack.

## Player Hitbox

The visible Ollie sprite is not the collision box.

The collision box should be a smaller rectangle inside the sprite.

This is based on the first playtest, where smaller hitboxes produced more forgiving and natural-feeling collisions.

The exact width/height will be tuned visually.

## Enemy Hitboxes

Alligators and the eagle should likewise have logical collision regions smaller than or more precise than their full sprite rectangles where useful.

This prevents transparent or decorative portions of a sprite from creating unfair hits.

## Collision Checks

Collision handling is centralized.

The collision routine tests relevant object pairs rather than allowing each object to modify Life Points independently.

Initial pairs:
- Ollie/alligator
- Ollie/eagle
- Ollie/crawfish
- Ollie/bank

No alligator/alligator collision is performed.

## Protection

Ollie has two independent forms of protection:

### Diving

While diving:
- alligator damage is ignored
- eagle catch is ignored

The first three seconds are free. Longer continuous dives drain 50 Life Points per second.

### Crawfish protection

Collecting a crawfish:
- starts a five-second timer
- prevents alligator damage
- prevents eagle catch

The protection condition is:

```text
protected = diving OR crawfish_invulnerable
```

If both are active, either one is sufficient to prevent a collision effect.

## Alligator Damage

Base damage is exactly **100 Life Points**.

A later test branch may experiment with a speed-based modifier, but the engine's base collision contract remains 100 points.

A single physical contact should not repeatedly subtract Life Points every frame.

The collision system therefore needs a short contact cooldown or equivalent separation rule.

The exact duration is a tuning value.

## Eagle Collision

An unprotected Ollie hit by the eagle:
- loses one heart
- exits PLAYING
- enters LIFE_LOST or GAME_OVER depending on remaining hearts

A protected Ollie passes safely through the eagle's attack.

## Crawfish Collection

An Ollie/crawfish collision:
- marks the crawfish collected
- removes/hides it
- starts five-second protection
- awards the eventual crawfish score

## Bank Collision

Bank collision initially:
- constrains Ollie's X position
- does not cause Life Point damage
- does not cost a heart

## Collision Resolution Order

The frame should resolve collisions before deciding whether PLAYING continues.

Initial priority:

1. Detect all relevant collisions.
2. Apply crawfish collection/protection.
3. Apply alligator damage.
4. Apply eagle catch.
5. Apply Life Point/heart transitions.
6. Decide GAME_OVER, LIFE_LOST, HOME, or remain PLAYING.

If an unprotected eagle catch and a gator hit happen in the same frame, the final-heart rule still applies normally; collision effects are resolved through one centralized transition path rather than letting two routines independently change game state.

## Object/Renderer Separation

Object updates own world state.

The renderer converts world state into:
- sprite positions
- sprite animation selection
- playfield markers

The renderer must not decide whether an object hit Ollie or whether Life Points change.

## Performance Goal

The initial target is four active alligators, two crawfish, one eagle, and Ollie.

That is a deliberately small fixed workload for the 6502.

If the finished engine has enough CPU time, the pools can be expanded later without redesigning the architecture.
