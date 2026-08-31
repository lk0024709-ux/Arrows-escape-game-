import 'package:arrows_escape_game/game/game_manager.dart';
import 'package:arrows_escape_game/geometry/arrow_path.dart';
import 'package:arrows_escape_game/geometry/grid.dart';
import 'package:arrows_escape_game/geometry/grid_point.dart';
import 'package:arrows_escape_game/level/difficulty.dart';
import 'package:arrows_escape_game/level/level.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tiny hand-built board with one free arrow, one blocked arrow and the
/// arrow that blocks it. Lets us assert the real corridor logic without any
/// randomness.
///
///   row 1:  blocker  -> -> ->
///   row 4:  free ^    blocked ^
///   row 5:  free ^    blocked ^
Level manualLevel() {
  final grid = Grid(width: 10, height: 10);
  final free = ArrowPath(
    id: 'free',
    points: const [GridPoint(1, 5), GridPoint(1, 4)],
    direction: Direction.up,
  );
  final blocked = ArrowPath(
    id: 'blocked',
    points: const [GridPoint(4, 5), GridPoint(4, 4)],
    direction: Direction.up,
  );
  final blocker = ArrowPath(
    id: 'blocker',
    points: const [GridPoint(4, 1), GridPoint(6, 1)],
    direction: Direction.right,
  );

  return Level(
    generatorSeed: 1,
    difficulty: const DifficultyParams(
      level: DifficultyLevel.easy,
      boardWidth: 10,
      boardHeight: 10,
      arrowCount: 3,
      maxPathLength: 3,
      minPathGap: 2,
    ),
  )
    ..grid = grid
    ..arrows = [free, blocked, blocker];
}

void main() {
  group('GameManager', () {
    test('startLevel builds a board and resets run state', () {
      final manager = GameManager();
      manager.startLevel(DifficultyLevel.easy);

      expect(manager.currentLevel, isNotNull);
      expect(manager.currentLevel!.arrows, isNotEmpty);
      expect(manager.moveCount, 0);
      expect(manager.lives, GameManager.startingLives);
      expect(manager.currentDifficulty, DifficultyLevel.easy);
    });

    test('selecting a board arrow spends a move; undo restores it', () {
      final manager = GameManager();
      manager.setLevel(manualLevel());

      final arrow = manager.currentLevel!.getArrowById('free')!;
      manager.onArrowSelected(arrow);
      expect(manager.moveCount, 1);
      expect(manager.selectedArrow?.id, 'free');

      manager.undo();
      expect(manager.moveCount, 0);
      expect(manager.selectedArrow, isNull);
    });

    test('releasing a free arrow removes it from the board', () {
      final manager = GameManager();
      manager.setLevel(manualLevel());

      final arrow = manager.currentLevel!.getArrowById('free')!;
      manager.onArrowSelected(arrow);
      manager.onArrowReleased(arrow);

      expect(manager.currentLevel!.getArrowById('free'), isNull);
    });

    test('releasing a blocked arrow costs a life and keeps it', () {
      final manager = GameManager();
      manager.setLevel(manualLevel());

      final blocked = manager.currentLevel!.getArrowById('blocked')!;
      manager.onArrowSelected(blocked);
      manager.onArrowReleased(blocked);

      expect(manager.lives, GameManager.startingLives - 1);
      expect(manager.currentLevel!.getArrowById('blocked'), isNotNull);
    });

    test('getAvailableArrows returns exactly the free arrows', () {
      final manager = GameManager();
      manager.setLevel(manualLevel());

      final ids = manager
          .getAvailableArrows()
          .map((a) => a.id)
          .toSet();
      expect(ids, {'free', 'blocker'});
    });

    test('showHint highlights an arrow that can escape now', () {
      final manager = GameManager();
      manager.setLevel(manualLevel());

      manager.showHint();
      expect(manager.hintArrowId, isNotNull);
      expect({'free', 'blocker'}, contains(manager.hintArrowId));
    });
  });
}
