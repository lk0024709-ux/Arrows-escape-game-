# ARROWS ESCAPE

A production-quality Flutter puzzle game: **long geometric arrow paths** that
have to be slid out of a dense labyrinth, with deterministic procedural level
generation, a single shared physics core, a real solver, and a measured
difficulty score.

The visual language follows the supplied reference screenshots (white board,
deep-navy paths, procedural arrow heads, soft rounded cards, blue interaction
accents) while using an original implementation and original assets.

```
        ← Level 6 →
   ┌───────────────────────────┐
   │  ↗ 86    ♥ ♥ ♥     Hard   │
   └───────────────────────────┘

      ───────────────→
             │
             ↓
      ←─────────┐
                │
                ↑
      💡        ↺        ⟳
   ─────────────────────────
             AD
```

---

## 1. Quick start

```bash
flutter pub get
flutter run                 # phone / tablet / desktop
flutter test                # engine, generator, solver, controller tests
```

Minimum SDK: **Dart 3.6 / Flutter 3.27+** (uses `Color.withValues`, records and
`CardThemeData`).

Only one third-party dependency: `shared_preferences` (offline save). No state
management package — the controller is a plain `ChangeNotifier`.

## 2. Live web preview

`web_preview/` contains a **vanilla-JS mirror of the same engine** — the same
algorithms, the same geometry and the same generator, ported line by line — plus
a canvas renderer and the reference-style UI chrome. It exists so the game can
be played in a browser and so the engine can be exercised by a Node test
harness. (Each implementation is deterministic on its own; the 64-bit seed
derivation is platform specific, so a given seed produces *a* stable level in
each, not byte-identical twins.)

```bash
cd web_preview
python3 -m http.server 8000        # then open http://localhost:8000
node tools/test_engine.mjs         # generation / solver / determinism
node tools/test_game.mjs           # gameplay rules
node tools/measure.mjs             # difficulty calibration table
npm install jsdom && node tools/smoke_dom.mjs   # boots index.html and plays a level
```

The Flutter app is the deliverable; the web preview is a mirror used for
verification (see `docs/GENERATOR.md` for the measured numbers).

## 3. The rule

Tap an arrow → it travels along its escape direction until it either

* **leaves the board** (it escapes and is removed), or
* **hits another arrow** and comes to rest flush against it.

Because a partial slide permanently changes the geometry, a careless tap *can*
dead-lock the board — that is what makes decoy moves matter. Undo is free;
restarting after a dead end costs a life.

`TravelMode.escapeOnly` (all-or-nothing) is also implemented and fully tested,
and every rule lives behind `GameRules`, so nothing is hard-coded in the
physics.

## 4. Architecture at a glance

```
lib/
  core/            pure Dart: vectors, AABB/triangle/segment geometry,
                   spatial hash, deterministic SplitMix64 RNG
  game/
    model/         GridPoint · Direction · PathArrow · ArrowMetrics ·
                   Level · BoardState · GameRules
    geometry/      ArrowGeometry (collision shapes + arrow heads) ·
                   EscapeCorridor · BoardTransform (world ↔ screen)
    physics/       PhysicsEngine  ← the ONE "can this arrow move?" rule
    generator/     DifficultyParams · PathTemplates · OccupancyField ·
                   DependencyGraph · LevelGenerator
    solver/        Solver (BFS/DFS/greedy) · QualityScorer
    engine/        GameController (moves, undo, hints, lives)
  ui/              screens · widgets · CustomPainter board · debug panel
  data/            LevelPack (50 campaign levels + endless + daily)
  services/        SaveService (offline) · AdProvider (isolated ads)
```

The important invariant: **gameplay, solver, validator and generator all call
`PhysicsEngine.evaluate`**, so there is exactly one definition of "can this
arrow escape?" (prompt §49).

Full details: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
[`docs/GENERATOR.md`](docs/GENERATOR.md).

## 5. What is implemented

| Area | Status |
| --- | --- |
| Path-arrow model, orthogonal path construction, procedural arrow heads | ✅ |
| Rounded joins, configurable metrics (thickness, head length/width, min gap) | ✅ |
| Invisible construction grid + grey guide dots + debug grid | ✅ |
| Deterministic reverse-order generator with dependency DAG | ✅ |
| Occupancy/distance-field placement, targeted corridor blocking, shrink-to-fit | ✅ |
| BFS / DFS / greedy solver sharing the physics core | ✅ |
| Measured quality score (0–100) → Easy/Normal/Medium/Hard/Expert | ✅ |
| 50-level campaign, endless mode, daily seed | ✅ |
| Moves counter, lives, hints, undo, restart, star scoring | ✅ |
| Escape/slide/blocked animations, particles, haptics, shake | ✅ |
| Debug menu (grid, dots, points, hitboxes, corridors, raycast, DAG, solution, seed, score) | ✅ |
| Level editor (generate → inspect → validate → solve → export JSON) | ✅ |
| Offline save, settings, isolated ad container | ✅ |
| Responsive: SafeArea + LayoutBuilder, portrait phones → tablets | ✅ |

## 6. Tests

`flutter test` covers geometry, RNG determinism, arrow validation, the physics
core (escape / flush stop / blocked / crossing / escape-only rules), generator
validity + solvability + determinism + spacing, solver agreement, and the
controller (move counting, blocked taps, undo, hints, lives, stars).

The Node harness in `web_preview/tools/` runs the same scenarios against the JS
mirror and prints the difficulty calibration table.
