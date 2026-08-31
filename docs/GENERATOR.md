# Level generator

## Pipeline (prompt §17)

```
SEED
 ↓  DifficultyParams (band)
 CREATE LOGICAL GRID (cols × rows construction nodes)
 ↓  arrowCount = rng(arrowMin, arrowMax)
 GENERATE SOLUTION ORDER   ← arrows are inserted in REVERSE escape order
 ↓  for escapeIndex = n-1 … 0
      GENERATE PATH ARROWS (orthogonal walk through the occupancy field)
      PLACE  (min-spacing check, escape-corridor check, root protection)
      SCORE  (blocking value, spread, complexity, jitter)
 ↓  CHECK GEOMETRY / COLLISIONS (LevelGenerator.validate)
 ↓  RUN SOLVER (canonical greedy + BFS cross-check)
 ↓  MEASURE DIFFICULTY (quality score → label)
 ↓  ACCEPT / REJECT (band window, or regenerate with a sub-seed)
```

## Reverse generation (prompt §18)

Arrows are inserted in **reverse escape order**: `o(n-1)` first, `o(0)` last.
Two invariants follow automatically:

1. When arrow `o(k)` is inserted, every arrow already on the board escapes
   *after* it, so we simply require `o(k)`'s corridor to the board edge to be
   clear of them → `o(k)` can always leave in a single move once its turn comes.
2. An arrow can only ever be blocked by arrows inserted *after* it, i.e. arrows
   that escape *before* it → **the blocking graph is acyclic by construction**.

Consequence: every generated level is guaranteed solvable in exactly
`arrowCount` moves, and — because a move can remove at most one arrow — that
solution is automatically **optimal**. The BFS is still run as a cross-check for
custom/edited levels.

## Placement internals

### OccupancyField

A per-cell bitmask + BFS distance transform over the construction grid. A cell
is blocked when a placed part (inflated by `minGap + halfThickness`, or
`minGap + headWidth/2` for the arrow head) covers its centre.

Uses:

* `pickOrigin` — sample 8 nodes, take the one furthest from occupied space.
* `pickHeading` — take the direction with the longest free run.
* `PathTemplates.randomWalk(isFree:)` — the walk only grows through free cells,
  which is what makes dense packing possible at all.

### Relaxation ladder

Each arrow is searched in up to four passes:

| Pass | Spacing | Shape |
| --- | --- | --- |
| a | `minGap = 2.5T` (prompt §14) | band shape |
| b | `0.6 × minGap` | band shape |
| c | `0.3T` | 1 segment, length 2…max |
| d | `0.3T` | 1 segment, length 1…3 (shrink-to-fit) |

### Targeted blocking

Purely random placement almost never lands inside another arrow's corridor, so
with probability `blockBias` the generator **aims**:

* pick the unblocked arrow with the *fewest remaining chances* to be blocked
  (lowest escape index — it was inserted most recently),
* sample a free cell inside that arrow's escape corridor,
* choose a heading: **queue** (same direction, sitting ahead of the target —
  its own corridor is then a sub-band of the target's corridor, so the
  corridor-clear invariant almost always holds) 75% of the time, otherwise
  **cross** (perpendicular).

Roots (arrows with nothing in their corridor) are protected for the first
`targetRoots` escape indices, which guarantees several legal first moves without
ever producing a forced single-file sequence (§20, §21).

## Quality score (prompt §51)

```
quality = 16·size + 18·depth + 16·dependencies + 13·branching
        + 11·paths + 10·density + 8·decoys − 16·triviality  (+6 unless rootless)
```

with `size = arrows/30`, `depth = dependencyDepth/6`,
`dependencies = edges/(1.5·arrows)`, `branching = (avgBranching−1)/3`,
`paths = avgTurns/3`, `density = occupiedArea/boardArea / 0.55`,
`decoys = decoys/(0.45·arrows)`, `triviality = forcedSteps/steps`.

Labels are **measured**, not assumed: `Easy < 32`, `Normal < 50`,
`Medium < 64`, `Hard < 76`, `Expert ≥ 76`.

## Calibration (measured with `web_preview/tools/measure.mjs`)

| Band | Grid | Arrows | Quality (min/median/max) | Roots | Depth | Decoys | Gen time |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 Easy | 8×10 | ~6 | 21 / 29 / 34 | 3.3 | 1.5 | 2 | ~25 ms |
| 2 Normal | 9×12 | ~10 | 38 / 47 / 52 | 6.6 | 2.0 | 9 | ~25 ms |
| 3 Medium | 11×15 | ~14 | 52 / 58 / 64 | 7.1 | 2.6 | 19 | ~35 ms |
| 4 Hard | 13×19 | ~21 | 58 / 66 / 72 | 12.8 | 3.5 | 43 | ~75 ms |
| 5 Expert | 14×22 | ~28 | 67 / 73 / 79 | 17.4 | 4.0 | 80 | ~210 ms |

Generation is deterministic for a given `(seed, difficulty)` and runs on the UI
thread in tens of milliseconds (expert ≈ 0.2 s), with the result cached.

## Band parameters

| Band | Grid | Arrows | Segments | Segment length | Lives | Hints |
| --- | --- | --- | --- | --- | --- | --- |
| Easy | 8×10 | 5–8 | 1–2 | 2–5 | 5 | 3 |
| Normal | 9×12 | 8–13 | 1–3 | 2–5 | 4 | 3 |
| Medium | 11×15 | 12–17 | 2–3 | 2–4 | 3 | 2 |
| Hard | 13×19 | 18–25 | 2–4 | 2–5 | 3 | 2 |
| Expert | 14×22 | 26–34 | 2–4 | 2–5 | 3 | 1 |

(Arrow counts sit at the low end of the brief's 20–35 / 30–60 ranges: those
counts are geometrically impossible to pack on a 12×18 / 14×22 grid with
`2.5T` spacing and paths long enough to read as arrows. The campaign ramps
without limit in endless mode instead.)

## Level identity (prompt §54)

Every level carries `levelId`, `seed`, `difficulty`, `generatorVersion`,
`solutionLength` and `qualityScore`. Bump `LevelGeneratorVersion.current` when
the algorithm changes: cached levels whose version differs are regenerated.
