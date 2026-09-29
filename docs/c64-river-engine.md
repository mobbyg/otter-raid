# Otter Raid — C64 River Engine

## Purpose

The river is the foundation of Otter Raid. It needs to look smooth, scroll smoothly, remain playable, and provide a predictable world in which hazards and pickups can exist.

The old row-by-row random approach produced a jerky river. The rewrite will instead use **smooth river sections** and a scrolling playfield.

## Journey Structure

The initial journey contains **40 river sections**.

A section is a chunk of the upstream world with:
- a defined length
- a starting river shape
- an ending river shape
- controlled width variation
- bend information
- scenery opportunities
- hazard/pickup opportunities

The section count is deliberately a gameplay tuning value. If testing shows the journey is too short or too long, we can reduce or extend it without changing the underlying engine.

## Section Stitching

A section must not independently choose a completely unrelated starting position.

Instead, each section receives the previous section's ending geometry as its starting condition.

Conceptually:

```text
Section N ending geometry
          |
          v
Section N+1 starting geometry
          |
          v
smooth interpolation
          |
          v
Section N+1 ending geometry
```

This guarantees that sections meet cleanly.

## River Representation

The engine should not store an arbitrary left/right bank position for every screen row as its primary representation.

Instead, a section is described by a small number of **control points**.

Each control point contains enough information to describe:
- left bank
- right bank
- world position along the section

The renderer interpolates between control points to obtain the bank position for the current screen/world rows.

This produces broad, smooth bends rather than jagged one-row changes.

## Width

The river has a minimum playable width.

The generator may:
- widen the river
- narrow the river
- bend left
- bend right
- combine a bend with a width change

But it must always maintain enough space for Ollie to maneuver.

The generator should reject or clamp a proposed section if its geometry would create an unfairly narrow passage.

## Symmetry

The river should generally feel visually balanced, but it does not need perfect mathematical symmetry.

A section can bend left or right while maintaining a sensible playable corridor.

The important rule is that the river should feel like a natural channel rather than a rectangular track.

## Generation

The generator uses a deterministic pseudo-random state.

A new run may select a new seed.

This gives us:
- repeatability for debugging when a seed is recorded
- variation between runs
- the ability to reproduce a difficult or interesting river during testing

The active section and upcoming section data are kept in the river-generation buffer.

The engine should generate the next section before the current section is exhausted.

## Smooth Scrolling

The preferred C64 presentation is a **fine-scrolled playfield**:

1. Keep the HUD on a non-scrolling top row.
2. Use a raster split to establish the playfield display region.
3. Use VIC-II vertical fine scrolling for smooth movement.
4. As the fine-scroll value wraps, advance the logical character rows.
5. Generate the newly exposed row from the current river geometry.
6. Update its screen characters and Color RAM.

This avoids redrawing all 24 playfield rows every frame.

The exact raster implementation will be validated with a small prototype before the complete river engine is written.

## River Row Rendering

A rendered river row needs to answer only a few questions:

- Where is the left bank?
- Where is the right bank?
- What characters/colors fill the river?
- What bank/scenery graphics are present?
- Which world objects are near this row?

The bank positions come from interpolated section geometry.

The renderer should not generate randomness while drawing a row. Generation decisions belong to the river generator.

## Scenery

Scenery is part of the river world.

Potential scenery includes:
- trees
- rocks
- islands
- houses
- other river-side details

Scenery should be represented as lightweight world objects/markers rather than requiring a full object system for every visual detail.

Scenery placement must not make the playable corridor unfair.

## Hazard and Pickup Placement

River sections can provide placement opportunities for:
- alligators
- crawfish
- scenery

Hazard generation should understand the river geometry.

An alligator should not spawn in a location outside the river merely because a random number selected it.

Crawfish may intentionally be difficult to reach. They are allowed to create a risk/reward decision.

## Reset

When a run resets:
- return to section 0
- reset the section position
- reset the generator state
- choose a new seed if desired
- clear/rebuild active world objects

The game therefore returns to the beginning of the journey without necessarily producing the exact same river.

## Implementation Strategy

The first river prototype should **not** include all hazards, scenery, and polish.

It should prove only:

1. a smooth section can be generated
2. two sections stitch cleanly
3. the playfield scrolls smoothly
4. Ollie remains inside the river
5. the HUD remains fixed
6. the system can generate all 40 sections without discontinuities

Once that works, hazards and scenery can consume the river's world coordinates.

## Tuning Values

These are intentionally adjustable:
- number of sections: 40 initially
- section length
- minimum/maximum width
- maximum bend rate
- control-point spacing
- scenery frequency
- hazard opportunities
- crawfish opportunities
- generation seed behavior

The generator should use named constants/tables so these can be changed without rewriting the engine.
