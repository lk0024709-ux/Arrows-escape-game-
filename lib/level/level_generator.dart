import 'dart:math';

import '../geometry/arrow_path.dart';
import '../geometry/grid.dart';
import '../geometry/grid_point.dart';
import 'difficulty.dart';
import 'level.dart';
import 'level_solver.dart';

/// Deterministic board generator.
///
/// Boards are built by reverse generation: arrows are dropped on one at a time
/// and a candidate is only kept while the board stays solvable. Later arrows
/// may therefore block earlier ones (real dependencies), while solvability is
/// never lost. The same (difficulty, seed) pair always yields the same board.
class LevelGenerator {
  /// Whole-board retries before falling back to a hand-made layout.
  final int maxAttempts;

  /// Candidate positions tried per arrow slot.
  final int placementAttempts;

  LevelGenerator({this.maxAttempts = 25, this.placementAttempts = 30});

  /// Set a global seed for reproducible level generation
  static int globalSeed = 12345;

  static void setSeed(int seed) {
    globalSeed = seed;
  }

  /// Generate a level with deterministic results based on seed and difficulty.
  /// Always returns a playable board.
  Level generate({required DifficultyLevel difficulty, required int seed}) {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final level = tryGenerate(difficulty: difficulty, seed: seed + attempt);
      if (level != null) return level;
    }
    return fallbackLevel(difficulty: difficulty, seed: seed);
  }

  /// One attempt at a board, or null when it did not meet the quality bar.
  Level? tryGenerate({required DifficultyLevel difficulty, required int seed}) {
    final rng = Random(seed);
    final params = DifficultyParams.forLevel(difficulty, rng);
    final grid = Grid(width: params.boardWidth, height: params.boardHeight);
    if (grid.width < 4 || grid.height < 4) return null;

    final occupied = <String>{};
    final arrows = <ArrowPath>[];
    var emptySlots = 0;

    for (var slot = 0; slot < params.arrowCount; slot++) {
      final placed = _placeArrow(
        id: 'arrow_${seed}_$slot',
        grid: grid,
        params: params,
        rng: rng,
        occupied: occupied,
        current: arrows,
      );

      if (placed == null) {
        // Board is getting crowded; stop early rather than spinning.
        if (++emptySlots >= 3) break;
        continue;
      }
      emptySlots = 0;
      arrows.add(placed);
      for (final cell in placed.occupiedCells) {
        occupied.add('${cell.x},${cell.y}');
      }
    }

    final minArrows = max(3, (params.arrowCount * 0.6).round());
    if (arrows.length < minArrows) return null;

    final solution = LevelSolver.solveArrows(arrows, grid);
    if (solution.isEmpty) return null;

    final level = Level(generatorSeed: seed, difficulty: params)
      ..grid = grid
      ..arrows = arrows
      ..solutionOrder = solution
      ..solutionLength = solution.length;

    _measure(level);
    return level.isValid ? level : null;
  }

  /// A sparse, guaranteed-solvable layout used when random generation keeps
  /// failing. Better a simple board than no board.
  Level fallbackLevel({required DifficultyLevel difficulty, required int seed}) {
    final params = DifficultyParams.forLevel(difficulty, Random(seed));
    final grid = Grid(width: max(6, params.boardWidth), height: max(6, params.boardHeight));
    final arrows = <ArrowPath>[];

    for (int row = 1; row + 1 < grid.height && arrows.length < 4; row += 3) {
      final points = <GridPoint>[
        GridPoint(1, row),
        GridPoint(2, row),
        GridPoint(3, row),
      ];
      arrows.add(ArrowPath(
        id: 'fallback_${seed}_$row',
        points: points,
        direction: ArrowPath.calculateDirection(points),
      ));
    }

    final level = Level(generatorSeed: seed, difficulty: params)
      ..grid = grid
      ..arrows = arrows
      ..solutionOrder = List<ArrowPath>.of(arrows)
      ..solutionLength = arrows.length;

    _measure(level);
    return level;
  }

  /// Try random candidates for one slot, keeping the first that does not
  /// overlap an existing arrow and leaves the board solvable.
  ArrowPath? _placeArrow({
    required String id,
    required Grid grid,
    required DifficultyParams params,
    required Random rng,
    required Set<String> occupied,
    required List<ArrowPath> current,
  }) {
    for (var attempt = 0; attempt < placementAttempts; attempt++) {
      final candidate = _randomArrow(
        id: id,
        grid: grid,
        params: params,
        rng: rng,
      );
      if (candidate == null) continue;

      final cells = candidate.occupiedCells;
      var overlaps = false;
      for (final cell in cells) {
        if (occupied.contains('${cell.x},${cell.y}')) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) continue;

      final trial = List<ArrowPath>.of(current)..add(candidate);
      if (LevelSolver.solveArrows(trial, grid).isEmpty) continue;

      return candidate;
    }
    return null;
  }

  /// A random straight or single-bend arrow that fits inside [grid].
  ArrowPath? _randomArrow({
    required String id,
    required Grid grid,
    required DifficultyParams params,
    required Random rng,
  }) {
    final points = <GridPoint>[
      GridPoint(rng.nextInt(grid.width), rng.nextInt(grid.height)),
    ];

    final segments = 1 + rng.nextInt(2); // straight or one bend
    final maxStep = max(2, params.maxPathLength);
    var dir = Direction.values[rng.nextInt(Direction.values.length)];

    for (int s = 0; s < segments; s++) {
      if (s > 0) {
        final horizontal = dir == Direction.left || dir == Direction.right;
        dir = horizontal
            ? (rng.nextBool() ? Direction.up : Direction.down)
            : (rng.nextBool() ? Direction.left : Direction.right);
      }

      final step = ArrowPath.delta(dir);
      final length = 1 + rng.nextInt(maxStep);
      for (int i = 0; i < length; i++) {
        final next = points.last.translate(step.x, step.y);
        if (!grid.inBoundsPoint(next)) break;
        points.add(next);
      }
    }

    if (points.length < 2) return null;

    final arrow = ArrowPath(
      id: id,
      points: points,
      direction: ArrowPath.calculateDirection(points),
    );
    return arrow.isValidDirection ? arrow : null;
  }

  /// Fill in the difficulty measurements used by the quality score.
  void _measure(Level level) {
    final grid = level.grid;
    if (grid == null) return;

    final freeAtStart = LevelSolver.branchingFactor(level.arrows, grid);
    final totalCells = grid.width * grid.height;
    final bodyCells =
        level.arrows.fold<int>(0, (sum, a) => sum + a.occupiedCells.length);

    level.branchingFactor = freeAtStart;
    level.dependencyComplexity = level.arrows.length - freeAtStart;
    level.trivialMoves = freeAtStart;
    level.pathComplexity =
        level.arrows.fold<int>(0, (sum, a) => sum + a.points.length);
    level.spatialDensity = totalCells == 0 ? 0.0 : bodyCells / totalCells;
    level.qualityScore = _qualityScore(level);
  }

  /// quality = solutionDepth + dependencyComplexity + branching +
  /// pathComplexity + spatialDensity - trivialMoves, normalised to 0-100.
  int _qualityScore(Level level) {
    final score = level.solutionLength * 1.5 +
        level.dependencyComplexity * 4 +
        level.branchingFactor * 1 +
        level.pathComplexity * 0.5 +
        level.spatialDensity * 40 -
        level.trivialMoves * 0.5;

    return score.round().clamp(0, 100);
  }
}
