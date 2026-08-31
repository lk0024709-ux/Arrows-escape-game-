import 'dart:math';

/// Player facing difficulty tiers, easiest first.
enum DifficultyLevel { easy, normal, medium, hard, expert }

/// Board size and generation budget for one difficulty tier.
class DifficultyParams {
  final DifficultyLevel level;
  final int boardWidth;
  final int boardHeight;
  final int arrowCount;
  final int maxPathLength;
  final double minPathGap;

  const DifficultyParams({
    required this.level,
    required this.boardWidth,
    required this.boardHeight,
    required this.arrowCount,
    required this.maxPathLength,
    required this.minPathGap,
  });

  /// 1..5, handy for labels and for callers that still think in ints.
  int get levelNumber => level.index + 1;

  factory DifficultyParams.forLevel(DifficultyLevel level, Random rng) {
    switch (level) {
      case DifficultyLevel.easy:
        return DifficultyParams(
          level: level,
          boardWidth: 8,
          boardHeight: 10,
          arrowCount: 5 + rng.nextInt(4), // 5-8
          maxPathLength: 3,
          minPathGap: 3.0,
        );
      case DifficultyLevel.normal:
        return DifficultyParams(
          level: level,
          boardWidth: 10,
          boardHeight: 14,
          arrowCount: 10 + rng.nextInt(9), // 10-18
          maxPathLength: 4,
          minPathGap: 2.5,
        );
      case DifficultyLevel.medium:
        return DifficultyParams(
          level: level,
          boardWidth: 12,
          boardHeight: 16,
          arrowCount: 11 + rng.nextInt(8), // 11-18
          maxPathLength: 5,
          minPathGap: 2.0,
        );
      case DifficultyLevel.hard:
        return DifficultyParams(
          level: level,
          boardWidth: 14,
          boardHeight: 18,
          arrowCount: 16 + rng.nextInt(8), // 16-23
          maxPathLength: 6,
          minPathGap: 1.8,
        );
      case DifficultyLevel.expert:
        return DifficultyParams(
          level: level,
          boardWidth: 16,
          boardHeight: 20,
          arrowCount: 22 + rng.nextInt(9), // 22-30
          maxPathLength: 8,
          minPathGap: 1.5,
        );
    }
  }
}
