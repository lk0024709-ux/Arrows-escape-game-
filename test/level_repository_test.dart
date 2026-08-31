import 'package:arrows_escape_game/data/repositories/level_repository.dart';
import 'package:arrows_escape_game/level/difficulty.dart';
import 'package:arrows_escape_game/level/level_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = LevelRepository();

  test('getLevelAsync returns a valid, solvable board', () async {
    for (final difficulty in DifficultyLevel.values) {
      final level =
          await repository.getLevelAsync(difficulty: difficulty);
      expect(level.arrows, isNotEmpty,
          reason: '${difficulty.name} has arrows');
      expect(level.grid, isNotNull,
          reason: '${difficulty.name} has a grid');
      expect(LevelSolver(level: level).solve(), isNotEmpty,
          reason: '${difficulty.name} is solvable');
      expect(level.isValid, isTrue,
          reason: '${difficulty.name} passes isValid');
    }
  });

  test('getLevelAsync completes even with a tiny timeout', () async {
    // The repository must never hang; a very short timeout should still yield
    // a board (via the fallback) rather than throwing or awaiting forever.
    final level = await repository.getLevelAsync(
      difficulty: DifficultyLevel.normal,
      timeout: const Duration(milliseconds: 1),
    );
    expect(level.arrows, isNotEmpty);
  });
}
