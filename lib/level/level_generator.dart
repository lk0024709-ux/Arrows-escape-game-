import 'dart:math';

import 'package:Arrows-escape-game-/lib/geometry/grid_point.dart';
import 'package:Arrows-escape-game-/lib/geometry/arrow_path.dart';
import 'package:Arrows-escape-game-/lib/level/level.dart';
import 'package:Arrows-escape-game-/lib/level/level_solver.dart';

class LevelGenerator {
  static int _globalSeed = 12345;

  /// Set a global seed for reproducible level generation
  static void setSeed(int seed) {
    _globalSeed = seed;
  }

  /// Generate a level with deterministic results based on seed and difficulty
  Level generate({required int difficulty, required int seed}) {
    final rng = Random(seed);
    final level = Level(
      difficulty: _getDifficultyParams(difficulty),
      seed: seed,
    );

    // Step 1: Create logical grid based on difficulty
    final grid = _createGridForDifficulty(difficulty, rng);
    level.grid = grid;

    // Step 2: Generate solution order (reverse generation)
    final solutionSequence = _generateSolutionSequence(difficulty, rng);
    level.solutionOrder = solutionSequence;

    // Step 3: Place arrows following the reverse generation
    _placeArrowsReverse(level, solutionSequence, grid, rng);

    // Step 4: Check geometry and collisions
    if (!_validateLevel(level, rng)) {
      // Reject and regenerate with sub-seed
      return LevelGenerator.generate(difficulty: difficulty, seed: seed + 1);
    }

    // Step 5: Run solver and measure difficulty
    final solver = LevelSolver(level: level);
    final solution = solver.solve();
    level.solutionLength = solution.length;
    level.qualityScore = _calculateQualityScore(solution, level);

    // Step 6: Accept or reject
    if (!level.isValid) {
      return LevelGenerator.generate(difficulty: difficulty, seed: seed + 1);
    }

    return level;
  }

  DifficultyParams _getDifficultyParams(int difficulty) {
    switch (difficulty) {
      case 1: // Easy
        return DifficultyParams(
          boardWidth: 8,
          boardHeight: 10,
          arrowCount: rng.nextInt(4) + 5, // 5-8
          maxPathLength: 3,
          minPathGap: 3.0,
        );
      case 2: // Normal
        return DifficultyParams(
          boardWidth: 10,
          boardHeight: 14,
          arrowCount: rng.nextInt(9) + 10, // 10-18
          maxPathLength: 4,
          minPathGap: 2.5,
        );
      case 3: // Medium
        return DifficultyParams(
          boardWidth: 12,
          boardHeight: 18,
          arrowCount: rng.nextInt(16) + 11, // 11-26
          maxPathLength: 5,
          minPathGap: 2.0,
        );
      case 4: // Hard
        return DifficultyParams(
          boardWidth: 14,
          boardHeight: 20,
          arrowCount: rng.nextInt(16) + 20, // 20-35
          maxPathLength: 6,
          minPathGap: 1.8,
        );
      case 5: // Expert
        return DifficultyParams(
          boardWidth: 18,
          boardHeight: 25,
          arrowCount: rng.nextInt(31) + 30, // 30-60+
          maxPathLength: 8,
          minPathGap: 1.5,
        );
      default:
        return DifficultyParams(
          boardWidth: 10,
          boardHeight: 14,
          arrowCount: 10,
          maxPathLength: 4,
          minPathGap: 2.5,
        );
    }
  }

  Grid _createGridForDifficulty(int rng, Random random) {
    // Create invisible construction grid
    final width = 10 + (rng % 12);
    final height = 10 + (rng % 15);
    return Grid(width: width, height: height);
  }

  List<ArrowPath> _generateSolutionSequence(int difficulty, Random rng) {
    // Generate a guaranteed solution path using reverse generation
    // Example: A → C → F → B → D → E
    final count = rng.nextInt(5) + 2; // 2-6 arrows in solution
    final directions = [Direction.values..shuffle(rng)];

    final List<ArrowPath> sequence = [];
    for (int i = 0; i < count; i++) {
      final path = _createRandomPath(rng, directions[i % directions.length]);
      sequence.add(path);
    }
    return sequence;
  }

  ArrowPath _createRandomPath(Random rng, Direction preferredDirection) {
    final pointCount = rng.nextInt(4) + 2; // 2-5 points
    final points = <GridPoint>[];

    // Start at a random position
    final startX = rng.nextInt(8) + 1;
    final startY = rng.nextInt(8) + 1;
    points.add(GridPoint(startX, startY));

    // Build path with orthogonal segments
    Direction currentDir = preferredDirection;
    for (int i = 1; i < pointCount; i++) {
      // Sometimes change direction
      if (rng.nextDouble() > 0.5 && i > 1) {
        // Choose a new perpendicular direction
        final perp = currentDir == Direction.right || currentDir == Direction.left
            ? Direction.up
            : Direction.right;
        currentDir = perp;
      }

      // Move 1-2 steps in current direction
      final steps = rng.nextInt(3) + 1;
      final last = points.last;
      int newX = last.x;
      int newY = last.y;

      if (currentDir == Direction.right) {
        newX = last.x + steps;
      } else if (currentDir == Direction.left) {
        newX = last.x - steps;
      } else if (currentDir == Direction.up) {
        newY = last.y - steps;
      } else if (currentDir == Direction.down) {
        newY = last.y + steps;
      }

      points.add(GridPoint(newX, newY));
    }

    final dir = ArrowPath.calculateDirection(points);
    return ArrowPath(
      id: '${DateTime.now().millisecondsSinceEpoch}_$rng',
      points: points,
      direction: dir,
      thickness: 8.0,
    );
  }

  /// Reverse level generation: start from empty board, add arrows in reverse order
  void _placeArrowsReverse(
      Level level, List<ArrowPath> sequence, Grid grid, Random rng) {
    // Start with empty board
    level.arrows = [];
    level.freeCells = grid.cells.length;

    // Add arrows in reverse order (last solution arrow first)
    for (int i = sequence.length - 1; i >= 0; i--) {
      final arrow = sequence[i];
      // Find a valid position that doesn't block future arrows
      final validPos = _findValidPosition(arrow, level, grid, rng);
      if (validPos != null) {
        arrow.points = validPos;
        level.arrows.add(arrow);
        level.freeCells -= _calculatePathOccupancy(arrow);
      }
    }
  }

  List<GridPoint>? _findValidPosition(
      ArrowPath arrow, Level level, Grid grid, Random rng) {
    // Try to find a valid position for the arrow
    final maxAttempts = 50;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // Generate candidate position
      final candidate = _generateCandidatePosition(arrow, grid, rng);

      if (candidate == null) continue;

      // Check for collisions with existing arrows
      bool collision = false;
      for (final existing in level.arrows) {
        if (_pathsIntersect(existing, ArrowPath(
          id: '${DateTime.now().millisecondsSinceEpoch}_collision',
          points: candidate,
          direction: arrow.direction,
          thickness: arrow.thickness,
        ))) {
          collision = true;
          break;
        }
      }

      if (!collision) {
        // Check escape corridor is clear
        if (_escapeCorridorClear(candidate, level)) {
          return candidate;
        }
      }
    }

    return null;
  }

  Offset _generateCandidatePosition(ArrowPath arrow, Grid grid, Random rng) {
    // Generate a position within the grid bounds
    final startX = rng.nextInt(grid.width - 3) + 2;
    final startY = rng.nextInt(grid.height - 3) + 2;

    // Build path from this start position
    final points = <GridPoint>[];
    points.add(GridPoint(startX, startY));

    // Extend path based on arrow direction
    Direction dir = arrow.direction;
    for (int i = 1; i < 5; i++) {
      final last = points.last;
      int newX = last.x;
      int newY = last.y;

      if (dir == Direction.right) newX++;
      else if (dir == Direction.left) newX--;
      else if (dir == Direction.up) newY--;
      else if (dir == Direction.down) newY++;

      if (newX >= 1 && newX <= grid.width - 2 &&
          newY >= 1 && newY <= grid.height - 2) {
        points.add(GridPoint(newX, newY));
      } else {
        break;
      }
    }

    return points;
  }

  bool _pathsIntersect(ArrowPath a, ArrowPath b) {
    // Check if two paths intersect/collide
    for (final p1 in a.points) {
      for (final p2 in b.points) {
        if (p1.x == p2.x && p1.y == p2.y) return true;
      }
    }
    return false;
  }

  bool _escapeCorridorClear(List<GridPoint> arrowPoints, Level level) {
    // Check if the escape corridor for an arrow is clear
    // The arrow is blocked if any active object occupies its forward escape corridor
    return true; // Simplified for now
  }

  double _calculatePathOccupancy(ArrowPath arrow) {
    // Calculate how many cells this path occupies
    return arrow.points.length.toDouble();
  }

  int _calculateQualityScore(List<ArrowPath> solution, Level level) {
    // Calculate puzzle quality score
    // quality = solutionDepth + dependencyComplexity + branching + pathComplexity + spatialDensity - trivialMoves
    int score = level.solutionLength;
    score += level.dependencyComplexity ?? 0;
    score += level.branchingFactor ?? 0;
    score += level.pathComplexity ?? 0;
    score += level.spatialDensity ?? 0;
    score -= level.trivialMoves ?? 0;

    // Normalize to 0-100
    return score.clamp(0, 100);
  }

  bool _validateLevel(Level level, Random rng) {
    // Validate the generated level passes all checks
    // Check: inside board, valid path geometry, no illegal overlaps,
    // valid arrowheads, valid directions, valid dependencies, solvable, reasonable difficulty

    if (level.arrows.isEmpty) return false;
    if (level.grid == null) return false;

    // Check all arrows have valid geometry
    for (final arrow in level.arrows) {
      if (arrow.points.length < 2) return false;
      if (!arrow.isValidDirection) return false;
    }

    // Check for overlaps
    for (int i = 0; i < level.arrows.length; i++) {
      for (int j = i + 1; j < level.arrows.length; j++) {
        if (_pathsIntersect(level.arrows[i], level.arrows[j])) return false;
      }
    }

    // Check solvability
    final solver = LevelSolver(level: level);
    final solution = solver.solve();
    if (solution.isEmpty) return false;

    return true;
  }
}