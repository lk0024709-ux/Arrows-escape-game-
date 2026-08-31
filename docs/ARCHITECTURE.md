# Architecture

## Coordinate systems (prompt §45)

```
Grid coordinates (integers)  →  World coordinates (cells)  →  Screen coordinates (px)
        GridPoint                    Vec2 / Aabb                   Offset
```

* The **logical construction grid** is `gridCols × gridRows` integer nodes.
  Every generated path is built from these nodes only — no free-floating pixel
  coordinates are ever invented (§13).
* **World space** uses *grid cells* as units, so `thickness = 0.26` means 26% of
  a cell. Sliding an arrow adds a fractional `offset` along its own direction.
* `BoardTransform` converts world ↔ screen. Taps are converted to world space
  before the controller sees them; UI pixels never leak into physics (§46).

## One geometry, one rule (prompt §34, §49)

```
PathArrow
   ↓  ArrowGeometry.partsOf()        (segments + arrow-head box)
Collision shapes (List<Aabb>)
   ↓  BoardCollisionIndex            (built once per board state)
PhysicsEngine.evaluate()
   ↓  → MoveEvaluation { canMove, travel, escapes, blockers }
```

`PhysicsEngine` is the **only** place that answers "can this arrow move, how
far, does it escape?". The UI, the solver, the generator's validator and the
hint system all call it, so a solution found by the solver is guaranteed to be
executable by the player.

### Why AABBs are exact here

Every path is orthogonal and every movement is orthogonal, therefore:

* the swept region of an AABB along an axis **is** an AABB (no approximation),
* the perpendicular overlap test plus the along-axis gap gives the exact
  stopping distance,
* broad phase = spatial hash over arrow bounding boxes, narrow phase =
  part-vs-part AABB tests.

Triangle-vs-AABB SAT (`Triangle.intersectsAabb`) and segment intersection are
implemented and used by the validator for the exact "do these paths cross?"
question (§36).

### The gap bug worth remembering

`_gapAlong` must return `infinity` when the candidate blocker lies *behind* the
moving part — otherwise an arrow is "blocked" by something it is driving away
from. This single function is what made the first generator produce dead-locked
boards.

## Collision pipeline (prompt §36, §59)

1. **Broad phase** — `SpatialHash` (uniform grid, cell = 2 world units) over
   arrow bounding boxes; the swept corridor queries it for candidates.
2. **Narrow phase** — part-vs-part AABB tests, with `minGap` margins during
   generation.
3. **Swept solve** — for each part pair: perpendicular overlap check, then the
   along-axis gap; the minimum gap is the travel distance.
4. **Escape test** — `travel >= exitDistance`, where `exitDistance` comes from
   `EscapeCorridor.exitDistance(bounds, direction, playBounds)`.

## Rendering (prompt §40, §41)

`BoardPainter` (a `CustomPainter`) draws, in this order:

1. background
2. guide nodes (grey dots — the construction grid, §12)
3. debug grid
4. path shadows
5. path bodies (`StrokeCap.round` + `StrokeJoin.round`, §8)
6. procedural arrow heads (§9)
7. selection / hint glow (§42)
8. escaping arrows: eased translation + blue gradient trail + fade + particle
   burst (§44)
9. debug geometry (hitboxes, corridors, raycasts, dependency graph, solution,
   path points)

Animation never gates logic: the controller commits the move first and records
a `MoveAnimation`; the painter only reads it (§39).

## Animation timing (prompt §38)

| Phase | Duration |
| --- | --- |
| anticipation | 0–80 ms |
| acceleration | 80–350 ms |
| escape | 350–650 ms |
| removal | after the animation completes |

Actual durations are tuned to the travel distance:
`slides: clamp(travel*18 + 140, 180, 340) ms`,
`escapes: clamp(travel*26 + 220, 260, 700) ms`.

## State ownership

`GameController` (a `ChangeNotifier`) owns `BoardState`, `moves`, `lives`,
`hints`, the undo stack and the animation list. Widgets never mutate geometry.
The `GameScreen` runs a `AnimationController` ticker **only while an animation
is in flight**, and rebuilds just the board via `AnimatedBuilder`.

## Ads (prompt §33)

```dart
abstract class AdProvider { Widget buildBanner(); }
```

`PlaceholderAdProvider` / `NoopAdProvider` are the two implementations. The ad
container sits below the game surface inside `SafeArea`, and the game engine has
no reference to it at all. Premium = swap in `NoopAdProvider`.

## Persistence (prompt §55)

`SaveService` (SharedPreferences) stores: per-level records (completed, stars,
best moves, hints used), the generated-level cache (so revisits are instant and
stable), daily puzzles, current level, endless best, and settings. Everything is
offline; a `SaveService.memory()` factory exists for tests.
