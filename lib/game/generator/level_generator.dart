import 'dart:math' as math;

import '../../core/geometry/geometry.dart';
import '../../core/rng/deterministic_random.dart';
import '../geometry/arrow_geometry.dart';
import '../model/arrow_theme_metrics.dart';
import '../model/board_state.dart';
import '../model/direction.dart';
import '../model/game_rules.dart';
import '../model/grid_point.dart';
import '../model/level.dart';
import '../model/path_arrow.dart';
import '../physics/physics_engine.dart';
import '../solver/quality.dart';
import '../solver/solver.dart';
import 'dependency_graph.dart';
import 'difficulty_params.dart';
import 'occupancy_field.dart';
import 'path_templates.dart';

/// Deterministic, reverse-order procedural level generator
/// (prompt §16, §17, §18, §47).
///
/// Pipeline
/// ```
/// SEED → DIFFICULTY PARAMS → LOGICAL GRID → SOLUTION ORDER
///      → PATH ARROWS → PLACEMENT → GEOMETRY CHECK → COLLISION CHECK
///      → SOLVER → DIFFICULTY MEASUREMENT → ACCEPT / REJECT
/// ```
///
/// Reverse generation: arrows are inserted in *reverse escape order*. Every
/// arrow is only allowed to enter the corridor of arrows that were inserted
/// before it (i.e. arrows that escape *after* it), which makes the blocking
/// graph acyclic and guarantees a solution in exactly `arrowCount` moves.
class LevelGenerator {
  LevelGenerator({
    this.attempts = 14,
    this.candidatesPerArrow = 140,
    this.solver = const Solver(mode: SolverMode.bfs, maxNodes: 8000),
    this.physics = const PhysicsEngine(),
  });

  /// How many full board layouts to try before relaxing the constraints.
  final int attempts;

  /// Candidate paths evaluated per arrow.
  final int candidatesPerArrow;

  final Solver solver;
  final PhysicsEngine physics;

  static const int _version = LevelGeneratorVersion.current;

  /// Generate one level. Deterministic for a given `(seed, difficulty)`.
  Level generate({
    required int difficulty,
    required int seed,
    DifficultyParams? params,
    int? levelNumber,
    String? levelId,
  }) {
    final p = params ?? DifficultyParams.forBand(difficulty);
    final target = QualityScorer.bandCenter(p.band);
    final range = QualityScorer.bandRange(p.band);

    Level? best;
    var bestDistance = double.infinity;

    for (var attempt = 0; attempt < attempts; attempt++) {
      final rng = DeterministicRandom(seed).fork(attempt * 7919 + p.band * 104729);
      final level = _buildAttempt(
        rng: rng,
        params: p,
        seed: seed,
        difficulty: difficulty,
        levelNumber: levelNumber,
        levelId: levelId,
        attempt: attempt,
      );
      if (level == null) continue;
      final analysis = level.analysis;
      if (analysis == null || !analysis.isSolvable) continue;
      if (analysis.rootCount > p.maxRoots || analysis.rootCount < 1) continue;

      final distance = (analysis.qualityScore - target).abs();
      if (analysis.qualityScore >= range.$1 &&
          analysis.qualityScore <= range.$2 &&
          analysis.qualityScore >= p.minQualityScore) {
        return level;
      }
      if (distance < bestDistance) {
        bestDistance = distance;
        best = level;
      }
    }

    if (best != null) return best;

    // Last resort: relax the quality window and take anything solvable.
    for (var attempt = 0; attempt < attempts; attempt++) {
      final rng = DeterministicRandom(seed).fork(0x5A5A + attempt * 6151);
      final level = _buildAttempt(
        rng: rng,
        params: p.copyWith(targetRoots: 1, blockBias: 0.4),
        seed: seed,
        difficulty: difficulty,
        levelNumber: levelNumber,
        levelId: levelId,
        attempt: attempts + attempt,
      );
      if (level?.analysis?.isSolvable ?? false) return level!;
    }

    // Absolute fallback: a tiny, guaranteed-solvable board.
    return _fallbackLevel(seed, difficulty, p);
  }

  // ---------------------------------------------------------------------------
  // Layout construction
  // ---------------------------------------------------------------------------

  Level? _buildAttempt({
    required DeterministicRandom rng,
    required DifficultyParams params,
    required int seed,
    required int difficulty,
    required int attempt,
    int? levelNumber,
    String? levelId,
  }) {
    final cols = params.gridCols;
    final rows = params.gridRows;
    final metrics = const ArrowMetrics();
    final boundsPadding = 1.0;
    final playBounds = Aabb(
      -boundsPadding,
      -boundsPadding,
      cols - 1 + boundsPadding,
      rows - 1 + boundsPadding,
    );

    final arrowCount = rng.nextIntRange(params.arrowMin, params.arrowMax);
    final inserted = <PathArrow>[];
    final insertedParts = <List<Aabb>>[];
    final insertedBounds = <Aabb>[];
    final insertedEscapeIndex = <int>[];
    final blockerCounts = <int>[];
    final byEscapeIndex = List<PathArrow?>.filled(arrowCount, null);
    final field = OccupancyField(cols, rows);

    for (var escapeIndex = arrowCount - 1; escapeIndex >= 0; escapeIndex--) {
      final pick = _pickCandidate(
        rng: rng,
        params: params,
        cols: cols,
        rows: rows,
        metrics: metrics,
        playBounds: playBounds,
        escapeIndex: escapeIndex,
        inserted: inserted,
        insertedParts: insertedParts,
        insertedBounds: insertedBounds,
        insertedEscapeIndex: insertedEscapeIndex,
        blockerCounts: blockerCounts,
        field: field,
      );
      if (pick == null) return null;

      byEscapeIndex[escapeIndex] = pick.arrow;
      inserted.add(pick.arrow);
      insertedParts.add(pick.parts);
      insertedBounds.add(pick.bounds);
      insertedEscapeIndex.add(escapeIndex);
      blockerCounts.add(0);

      // Register the new arrow as a blocker of everything it now blocks.
      for (var j = 0; j < inserted.length - 1; j++) {
        if (pick.blockedIndices.contains(j)) blockerCounts[j]++;
      }
    }

    final arrows = <PathArrow>[];
    for (var k = 0; k < arrowCount; k++) {
      final a = byEscapeIndex[k];
      if (a == null) return null;
      arrows.add(a);
    }

    final level = Level(
      levelId: levelId ?? (levelNumber != null ? 'L$levelNumber' : 'seed-$seed'),
      seed: seed,
      difficulty: difficulty,
      gridCols: cols,
      gridRows: rows,
      arrows: arrows,
      metrics: metrics,
      rules: GameRules(
        lives: params.lives,
        hints: params.hints,
        requireUniqueSolution: false,
        minimumQualityScore: params.minQualityScore,
      ),
      generatorVersion: _version,
      boundsPadding: boundsPadding,
      title: levelNumber != null ? 'Level $levelNumber' : null,
    );

    return level.copyWith(analysis: analyze(level, solver: solver, physics: physics));
  }

  _Candidate? _pickCandidate({
    required DeterministicRandom rng,
    required DifficultyParams params,
    required int cols,
    required int rows,
    required ArrowMetrics metrics,
    required Aabb playBounds,
    required int escapeIndex,
    required List<PathArrow> inserted,
    required List<List<Aabb>> insertedParts,
    required List<Aabb> insertedBounds,
    required List<int> insertedEscapeIndex,
    required List<int> blockerCounts,
    required OccupancyField field,
  }) {
    final isProtectedRoot = escapeIndex < params.targetRoots;

    // (a) ideal spacing (prompt §14: gap ≥ 2.5T)
    // (b) tighter packing
    // (c)+(d) shrink-to-fit with the smallest legal shapes — this is what makes
    //         dense levels achievable at all.
    final relaxations = <_Relaxation>[
      _Relaxation(metrics.minGap, null, null, null, candidatesPerArrow),
      _Relaxation(
          metrics.minGap * 0.6, null, null, null, (candidatesPerArrow * 0.6).round()),
      _Relaxation(metrics.thickness * 0.3, 1, 2, params.segmentLengthMax,
          (candidatesPerArrow * 0.6).round()),
      _Relaxation(metrics.thickness * 0.3, 1, 1, 3,
          (candidatesPerArrow * 0.6).round()),
    ];

    for (final relaxation in relaxations) {
      final pick = _tryPass(
        rng: rng,
        params: params,
        cols: cols,
        rows: rows,
        metrics: metrics,
        playBounds: playBounds,
        escapeIndex: escapeIndex,
        inserted: inserted,
        insertedParts: insertedParts,
        insertedBounds: insertedBounds,
        insertedEscapeIndex: insertedEscapeIndex,
        blockerCounts: blockerCounts,
        field: field,
        minGap: relaxation.gap,
        tries: relaxation.tries,
        isProtectedRoot: isProtectedRoot,
        segments: relaxation.segments,
        minLength: relaxation.minLength,
        maxLength: relaxation.maxLength,
      );
      if (pick != null) return pick;
    }
    return null;
  }

  _Candidate? _tryPass({
    required DeterministicRandom rng,
    required DifficultyParams params,
    required int cols,
    required int rows,
    required ArrowMetrics metrics,
    required Aabb playBounds,
    required int escapeIndex,
    required List<PathArrow> inserted,
    required List<List<Aabb>> insertedParts,
    required List<Aabb> insertedBounds,
    required List<int> insertedEscapeIndex,
    required List<int> blockerCounts,
    required OccupancyField field,
    required double minGap,
    required int tries,
    required bool isProtectedRoot,
    int? segments,
    int? minLength,
    int? maxLength,
  }) {
    field.rebuild(insertedParts, metrics, minGap);
    bool isFree(int c, int r) => field.isFree(c, r);

    _Candidate? best;
    var bestScore = -1e9;

    // Arrows that may still be blocked: candidates for *targeted* blocking —
    // the generator aims at their escape corridor instead of hoping for a
    // random hit (prompt §19/§20).
    final targets = <int>[];
    for (var j = 0; j < inserted.length; j++) {
      if (blockerCounts[j] >= params.maxBlockersPerArrow) continue;
      if (isProtectedRoot && insertedEscapeIndex[j] < params.targetRoots) continue;
      targets.add(j);
    }

    for (var t = 0; t < tries; t++) {
      GridPoint? origin;
      Direction? heading;
      if (targets.isNotEmpty && rng.nextDouble() < params.blockBias) {
        final aim = _aimAtCorridor(
          rng: rng,
          targets: targets,
          inserted: inserted,
          insertedBounds: insertedBounds,
          insertedEscapeIndex: insertedEscapeIndex,
          field: field,
          playBounds: playBounds,
          blockerCounts: blockerCounts,
          minLength: minLength ?? params.segmentLengthMin,
        );
        if (aim != null) {
          origin = aim.$1;
          heading = aim.$2;
        }
      }
      origin ??= _pickOrigin(rng, field);
      if (origin == null || !isFree(origin.col, origin.row)) continue;
      heading ??= _pickHeading(
        rng,
        origin,
        field,
        (maxLength ?? params.segmentLengthMax) + 1,
      );

      final points = PathTemplates.randomWalk(
        rng: rng,
        cols: cols,
        rows: rows,
        segments: segments ?? rng.nextIntRange(params.segmentMin, params.segmentMax),
        minLength: minLength ?? params.segmentLengthMin,
        maxLength: maxLength ?? params.segmentLengthMax,
        turnBias: params.turnBias,
        origin: origin,
        heading: heading,
        isFree: isFree,
      );
      if (points == null) continue;

      final arrow = PathArrow(
        id: 'a$escapeIndex',
        points: points,
        direction: PathTemplates.directionOf(points),
        metrics: metrics,
        escapeIndex: escapeIndex,
      );
      if (arrow.validateGeometry(gridCols: cols, gridRows: rows).isNotEmpty) {
        continue;
      }
      if (arrow.pathLength < params.segmentLengthMin) continue;

      final parts = ArrowGeometry.partsOf(arrow);
      final bounds = ArrowGeometry.boundsOfParts(parts);

      if (_violatesSpacing(parts, insertedParts, insertedBounds, minGap)) continue;

      // This arrow must be able to leave the board on its turn.
      final corridor = EscapeCorridor.toBoardEdge(
        bounds,
        arrow.direction,
        playBounds,
      );
      if (_corridorBlocked(corridor, insertedParts, insertedBounds)) continue;

      var blockedProtected = false;
      final blockedIndices = <int>[];
      for (var j = 0; j < inserted.length; j++) {
        final otherCorridor = EscapeCorridor.toBoardEdge(
          insertedBounds[j],
          inserted[j].direction,
          playBounds,
        );
        var hit = false;
        for (final part in parts) {
          if (otherCorridor.overlaps(part)) {
            hit = true;
            break;
          }
        }
        if (!hit) continue;
        // Root protection: the arrows that escape first must stay free.
        if (isProtectedRoot && insertedEscapeIndex[j] < params.targetRoots) {
          blockedProtected = true;
          break;
        }
        if (blockerCounts[j] >= params.maxBlockersPerArrow) continue;
        blockedIndices.add(j);
      }
      if (blockedProtected) continue;

      var newlyFirstBlocked = 0;
      for (final j in blockedIndices) {
        if (blockerCounts[j] == 0) newlyFirstBlocked++;
      }

      final spread = _spreadScore(bounds, insertedBounds);
      final turnBonus = (points.length - 2).toDouble();
      final jitter = rng.nextDouble();
      final score = params.blockBias * (2.2 * blockedIndices.length) +
          2.4 * newlyFirstBlocked +
          0.55 * spread +
          0.35 * turnBonus +
          0.30 * jitter;

      if (score > bestScore) {
        bestScore = score;
        best = _Candidate(arrow, parts, bounds, blockedIndices, score);
      }
    }
    return best;
  }

  /// Choose an origin inside the escape corridor of one of the [targets], plus
  /// a heading that keeps the new path inside (queue) or across (cross) that
  /// corridor. This is what turns "random packing" into "dependency graph
  /// construction" (prompt §18/§19).
  static (GridPoint, Direction)? _aimAtCorridor({
    required DeterministicRandom rng,
    required List<int> targets,
    required List<PathArrow> inserted,
    required List<Aabb> insertedBounds,
    required List<int> insertedEscapeIndex,
    required OccupancyField field,
    required Aabb playBounds,
    required List<int> blockerCounts,
    required int minLength,
  }) {
    // Prefer arrows that are not blocked by anything yet, and among those the
    // one with the *fewest remaining chances* to ever be blocked: the arrow
    // with the lowest escape index (it was inserted most recently, so only the
    // few arrows still to come can block it).
    final fresh = targets.where((j) => blockerCounts[j] == 0).toList();
    final pool = fresh.isNotEmpty ? fresh : targets;
    var mostUrgent = pool.first;
    for (final j in pool) {
      if (insertedEscapeIndex[j] < insertedEscapeIndex[mostUrgent]) {
        mostUrgent = j;
      }
    }
    final near = pool
        .where((j) => insertedEscapeIndex[j] <= insertedEscapeIndex[mostUrgent] + 1)
        .toList();
    final j = near[rng.nextInt(near.length)];
    final target = inserted[j];
    final corridor = EscapeCorridor.toBoardEdge(
      insertedBounds[j],
      target.direction,
      playBounds,
    );
    final c0 = math.max(0, corridor.left.ceil());
    final c1 = math.min(field.cols - 1, corridor.right.floor());
    final r0 = math.max(0, corridor.top.ceil());
    final r1 = math.min(field.rows - 1, corridor.bottom.floor());
    if (c1 < c0 || r1 < r0) return null;

    final perpendicular = target.direction.isHorizontal
        ? <Direction>[Direction.down, Direction.up]
        : <Direction>[Direction.right, Direction.left];
    final heads = rng.nextBool(0.75)
        ? <Direction>[target.direction, perpendicular[0], perpendicular[1]]
        : <Direction>[perpendicular[0], target.direction, perpendicular[1]];

    // Phase 1: only cells where the first segment actually fits.
    for (var attempt = 0; attempt < 14; attempt++) {
      final c = rng.nextIntRange(c0, c1);
      final r = rng.nextIntRange(r0, r1);
      if (!field.isFree(c, r)) continue;
      for (final heading in heads) {
        if (field.freeRun(c, r, heading, minLength) >= minLength) {
          return (GridPoint(c, r), heading);
        }
      }
    }
    // Phase 2: any free cell — the walk may still turn to fit.
    for (var attempt = 0; attempt < 10; attempt++) {
      final c = rng.nextIntRange(c0, c1);
      final r = rng.nextIntRange(r0, r1);
      if (!field.isFree(c, r)) continue;
      return (GridPoint(c, r), heads[attempt % heads.length]);
    }
    return null;
  }

  /// Pick a grid node inside the emptiest region we can find.
  static GridPoint? _pickOrigin(DeterministicRandom rng, OccupancyField field) {
    GridPoint? best;
    var bestDistance = -1.0;
    const samples = 8;
    for (var t = 0; t < samples; t++) {
      final c = rng.nextInt(field.cols);
      final r = rng.nextInt(field.rows);
      final d = field.distanceAt(c, r) + rng.nextDouble() * 0.5;
      if (d > bestDistance) {
        bestDistance = d;
        best = GridPoint(c, r);
      }
    }
    return best;
  }

  /// Prefer a heading that has room to run, so paths follow open lanes.
  static Direction _pickHeading(
    DeterministicRandom rng,
    GridPoint origin,
    OccupancyField field,
    int maxSteps,
  ) {
    final ordered = <Direction>[Direction.values[rng.nextInt(4)]];
    for (final d in Direction.values) {
      if (!ordered.contains(d)) ordered.add(d);
    }
    Direction best = ordered.first;
    var bestRun = -1.0;
    for (final d in ordered) {
      final run = field.freeRun(origin.col, origin.row, d, maxSteps) +
          rng.nextDouble() * 1.2;
      if (run > bestRun) {
        bestRun = run;
        best = d;
      }
    }
    return best;
  }

  static bool _violatesSpacing(
    List<Aabb> parts,
    List<List<Aabb>> others,
    List<Aabb> otherBounds,
    double minGap,
  ) {
    for (var j = 0; j < others.length; j++) {
      if (!parts.first.overlapsWithMargin(otherBounds[j], minGap + 1)) {
        // Quick reject is not safe (multiple parts) — fall through to exact test
        // only when the bounds are anywhere near.
        var near = false;
        for (final p in parts) {
          if (p.overlapsWithMargin(otherBounds[j], minGap + 1)) {
            near = true;
            break;
          }
        }
        if (!near) continue;
      }
      for (final p in parts) {
        for (final q in others[j]) {
          if (p.overlapsWithMargin(q, minGap)) return true;
        }
      }
    }
    return false;
  }

  static bool _corridorBlocked(
    Aabb corridor,
    List<List<Aabb>> others,
    List<Aabb> otherBounds,
  ) {
    for (var j = 0; j < others.length; j++) {
      if (!corridor.overlaps(otherBounds[j])) continue;
      for (final q in others[j]) {
        if (corridor.overlaps(q)) return true;
      }
    }
    return false;
  }

  static double _spreadScore(Aabb bounds, List<Aabb> others) {
    if (others.isEmpty) return 1.0;
    var nearest = double.infinity;
    for (final o in others) {
      final dx = bounds.centerX - o.centerX;
      final dy = bounds.centerY - o.centerY;
      final d = dx * dx + dy * dy;
      if (d < nearest) nearest = d;
    }
    final distance = nearest == double.infinity ? 0.0 : _sqrt(nearest);
    // Ideal packing distance ≈ 3 cells: close enough to interlock, far enough
    // to stay readable.
    final delta = (distance - 3.0).abs();
    return delta >= 3 ? 0 : 1 - delta / 3;
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    var x = v;
    for (var i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  Level _fallbackLevel(int seed, int difficulty, DifficultyParams params) {
    final metrics = const ArrowMetrics();
    // A tiny, hand-verified puzzle: a0 must leave before a3 can escape.
    final arrows = <PathArrow>[
      PathArrow(
        id: 'a0',
        points: const [GridPoint(7, 8), GridPoint(7, 3)],
        direction: Direction.up,
        metrics: metrics,
        escapeIndex: 0,
      ),
      PathArrow(
        id: 'a1',
        points: const [GridPoint(1, 2), GridPoint(6, 2)],
        direction: Direction.right,
        metrics: metrics,
        escapeIndex: 1,
      ),
      PathArrow(
        id: 'a2',
        points: const [GridPoint(6, 4), GridPoint(1, 4)],
        direction: Direction.left,
        metrics: metrics,
        escapeIndex: 2,
      ),
      PathArrow(
        id: 'a3',
        points: const [GridPoint(1, 7), GridPoint(1, 9), GridPoint(5, 9)],
        direction: Direction.right,
        metrics: metrics,
        escapeIndex: 3,
      ),
    ];
    final level = Level(
      levelId: 'fallback-$seed',
      seed: seed,
      difficulty: difficulty,
      gridCols: params.gridCols,
      gridRows: params.gridRows,
      arrows: arrows,
      metrics: metrics,
      generatorVersion: _version,
    );
    return level.copyWith(analysis: analyze(level));
  }

  // ---------------------------------------------------------------------------
  // Measurement
  // ---------------------------------------------------------------------------

  /// Full validation + difficulty measurement of a level (prompt §47, §51).
  static LevelAnalysis analyze(
    Level level, {
    Solver? solver,
    PhysicsEngine? physics,
  }) {
    final engine = physics ?? const PhysicsEngine();
    final search = solver ?? const Solver(mode: SolverMode.bfs, maxNodes: 8000);
    final graph = DependencyGraph.compute(level);
    final preferred = graph.topologicalEscapeOrder();

    // Branching / decoy statistics measured along the canonical solution.
    var state = level.initialState;
    var totalSteps = 0;
    var forcedSteps = 0;
    var maxBranching = 0;
    var branchingSum = 0;
    var decoyMoves = 0;
    var slides = 0;

    while (!state.isSolved) {
      final index = BoardCollisionIndex(level, state);
      final evaluations = engine.evaluateAll(index);
      final escaping = evaluations.where((e) => e.canMove && e.escapes).toList();
      final movable = evaluations.where((e) => e.canMove).toList();
      decoyMoves += movable.length - escaping.length;
      if (escaping.isEmpty) break;
      final branching = escaping.length;
      branchingSum += branching;
      if (branching > maxBranching) maxBranching = branching;
      if (branching == 1) forcedSteps++;
      totalSteps++;

      // Follow the canonical order when possible (deterministic).
      final chosen = _firstIn(preferred, escaping) ?? escaping.first;
      state = engine.applyMove(index, chosen.arrowIndex, chosen);
      if (!chosen.escapes) slides++;
      if (totalSteps > level.arrowCount * 8 + 32) break;
    }

    final solvable = state.isSolved;
    final canonicalLength = totalSteps;

    // A board can never be cleared in fewer moves than there are arrows, so the
    // canonical "escape only" solution is automatically optimal when it uses no
    // slides. Custom / edited levels are verified with a real search.
    var optimalLength = canonicalLength;
    var isOptimal = slides == 0 && solvable;
    if (!isOptimal) {
      final searchResult = search.solve(level);
      if (searchResult.isComplete) {
        optimalLength = searchResult.length;
        isOptimal = searchResult.isOptimal;
      }
    }

    final density = _densityOf(level);
    final averageTurns = level.arrows.isEmpty
        ? 0.0
        : level.arrows.map((a) => a.turnCount).reduce((a, b) => a + b) /
            level.arrows.length;

    final report = QualityScorer.score(
      arrowCount: level.arrowCount,
      dependencyDepth: graph.depth,
      edgeCount: graph.edgeCount,
      averageBranching: totalSteps == 0 ? 0.0 : branchingSum / totalSteps,
      decoyCount: decoyMoves,
      averageTurns: averageTurns,
      density: density,
      rootCount: graph.rootCount,
      forcedSteps: forcedSteps,
      totalSteps: totalSteps,
    );

    return LevelAnalysis(
      isSolvable: solvable,
      solutionLength: canonicalLength,
      optimalSolutionLength: optimalLength,
      qualityScore: report.score,
      difficultyLabel: report.label,
      dependencyDepth: graph.depth,
      rootCount: graph.rootCount,
      maxBranching: maxBranching,
      averageBranching: totalSteps == 0 ? 0.0 : branchingSum / totalSteps,
      decoyMoves: decoyMoves,
      blockedAtStart: level.arrowCount - graph.rootCount,
      pathComplexity: averageTurns,
      spatialDensity: density,
      solutionIsOptimal: isOptimal,
    );
  }

  static MoveEvaluation? _firstIn(List<int> preferred, List<MoveEvaluation> options) {
    for (final i in preferred) {
      for (final e in options) {
        if (e.arrowIndex == i) return e;
      }
    }
    return null;
  }

  static double _densityOf(Level level) {
    final boardArea = (level.gridCols - 1.0) * (level.gridRows - 1.0);
    if (boardArea <= 0) return 0;
    var occupied = 0.0;
    for (final arrow in level.arrows) {
      final parts = ArrowGeometry.partsOf(arrow);
      for (final p in parts) {
        occupied += p.area;
      }
    }
    return occupied / boardArea;
  }

  /// Structural validation used by the editor and by the generator's own
  /// accept/reject loop (prompt §47).
  static List<String> validate(Level level) {
    final issues = <String>[];
    for (final arrow in level.arrows) {
      issues.addAll(
        arrow.validateGeometry(gridCols: level.gridCols, gridRows: level.gridRows),
      );
    }
    // Illegal overlaps between arrows.
    final metrics = level.metrics;
    for (var i = 0; i < level.arrows.length; i++) {
      final a = ArrowGeometry.partsOf(level.arrows[i]);
      for (var j = i + 1; j < level.arrows.length; j++) {
        final b = ArrowGeometry.partsOf(level.arrows[j]);
        var overlap = false;
        for (final p in a) {
          for (final q in b) {
            if (p.overlaps(q)) {
              overlap = true;
              break;
            }
          }
          if (overlap) break;
        }
        if (overlap) {
          issues.add('${level.arrows[i].id} overlaps ${level.arrows[j].id} '
              '(min gap ${metrics.minGap.toStringAsFixed(2)})');
        }
      }
    }
    // Duplicate geometry.
    final seen = <String>{};
    for (final arrow in level.arrows) {
      final key = arrow.points.map((p) => '${p.col},${p.row}').join('|');
      if (!seen.add(key)) issues.add('${arrow.id} duplicates another path');
    }
    final analysis = analyze(level);
    if (!analysis.isSolvable) issues.add('level is not solvable');
    return issues;
  }
}

/// One "try harder" stage of the placement search.
class _Relaxation {
  const _Relaxation(this.gap, this.segments, this.minLength, this.maxLength, this.tries);

  final double gap;
  final int? segments;
  final int? minLength;
  final int? maxLength;
  final int tries;
}

class _Candidate {
  _Candidate(this.arrow, this.parts, this.bounds, this.blockedIndices, this.score);

  final PathArrow arrow;
  final List<Aabb> parts;
  final Aabb bounds;
  final List<int> blockedIndices;
  final double score;
}

/// Convenience: build a fresh board state for a generated level.
BoardState initialStateOf(Level level) => level.initialState;
