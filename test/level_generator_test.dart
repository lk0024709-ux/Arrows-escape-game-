import 'package:arrows_escape_game/level/difficulty.dart';
import 'package:arrows_escape_game/level/level_generator.dart';
import 'package:arrows_escape_game/level/level_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generator = LevelGenerator();

  test('same seed + difficulty is deterministic', () {
    final a = generator.generate(difficulty: DifficultyLevel.normal, seed: 42);
    final b = generator.generate(difficulty: DifficultyLevel.normal, seed: 42);
    expect(a.arrows.length, b.arrows.length);
    for (int i = 0; i < a.arrows.length; i++) {
      expect(a.arrows[i].id, b.arrows[i].id);
      expect(a.arrows[i].points, b.arrows[i].points);
      expect(a.arrows[i].direction, b.arrows[i].direction);
    }
  });

  test('every difficulty yields a non-empty solvable board', () {
    for (final difficulty in DifficultyLevel.values) {
      final level = generator.generate(difficulty: difficulty, seed: 7);
      expect(level.arrows, isNotEmpty, reason: '${difficulty.name} has arrows');
      expect(level.grid, isNotNull, reason: '${difficulty.name} has a grid');
      expect(LevelSolver(level: level).solve(), isNotEmpty,
          reason: '${difficulty.name} is solvable');
      expect(level.isValid, isTrue, reason: '${difficulty.name} passes isValid');
    }
  });

  test('generated arrows never overlap', () {
    for (final seed in [1, 2, 3]) {
      final level = generator.generate(difficulty: DifficultyLevel.medium, seed: seed);
      final arrows = level.arrows;
      for (int i = 0; i < arrows.length; i++) {
        for (int j = i + 1; j < arrows.length; j++) {
          expect(level.pathsIntersect(arrows[i], arrows[j]), isFalse);
        }
      }
    }
  });

  test('quality score stays within 0-100', () {
    final level = generator.generate(difficulty: DifficultyLevel.expert, seed: 11);
    expect(level.qualityScore, inInclusiveRange(0, 100));
  });
}
