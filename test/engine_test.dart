import 'package:flutter_test/flutter_test.dart';

import 'package:arrows_escape/core/geometry/geometry.dart';
import 'package:arrows_escape/core/math/vector2.dart';
import 'package:arrows_escape/core/rng/deterministic_random.dart';
import 'package:arrows_escape/game/engine/game_controller.dart';
import 'package:arrows_escape/game/generator/dependency_graph.dart';
import 'package:arrows_escape/game/generator/difficulty_params.dart';
import 'package:arrows_escape/game/generator/level_generator.dart';
import 'package:arrows_escape/game/geometry/arrow_geometry.dart';
import 'package:arrows_escape/game/model/arrow_theme_metrics.dart';
import 'package:arrows_escape/game/model/direction.dart';
import 'package:arrows_escape/game/model/grid_point.dart';
import 'package:arrows_escape/game/model/level.dart';
import 'package:arrows_escape/game/model/path_arrow.dart';
import 'package:arrows_escape/game/physics/physics_engine.dart';
import 'package:arrows_escape/game/solver/solver.dart';

const ArrowMetrics metrics = ArrowMetrics();

PathArrow arrow(
  String id,
  List<List<int>> nodes,
  Direction direction, {
  double offset = 0,
}) =>
    PathArrow(
      id: id,
      points: [for (final n in nodes) GridPoint(n[0], n[1])],
      direction: direction,
      metrics: metrics,
      offset: offset,
    );

void main() {
  group('geometry', () {
    test('AABB overlap is strict (flush contact is allowed)', () {
      const a = Aabb(0, 0, 1, 1);
      const touching = Aabb(1, 0, 2, 1);
      const overlapping = Aabb(0.9, 0, 2, 1);
      expect(a.overlaps(touching), isFalse);
      expect(a.overlaps(overlapping), isTrue);
    });

    test('sweeping an AABB along an axis is exact', () {
      const box = Aabb(0, 0, 1, 1);
      final swept = EscapeCorridor.sweep(box, Direction.right, 5);
      expect(swept.left, 0);
      expect(swept.right, 6);
    });

    test('triangle vs AABB separating axis test', () {
      final triangle = Triangle(
        const Vec2(0, 0),
        const Vec2(2, 1),
        const Vec2(2, -1),
      );
      expect(triangle.intersectsAabb(const Aabb(1, -0.2, 1.4, 0.2)), isTrue);
      expect(triangle.intersectsAabb(const Aabb(3, 3, 4, 4)), isFalse);
    });

    test('segment intersection', () {
      expect(
        Segment(const Vec2(0, 0), const Vec2(2, 0))
            .intersects(Segment(const Vec2(1, -1), const Vec2(1, 1))),
        isTrue,
      );
      expect(
        Segment(const Vec2(0, 0), const Vec2(2, 0))
            .intersects(Segment(const Vec2(3, -1), const Vec2(3, 1))),
        isFalse,
      );
    });
  });

  group('deterministic rng', () {
    test('same seed yields the same sequence', () {
      final a = DeterministicRandom(1234);
      final b = DeterministicRandom(1234);
      for (var i = 0; i < 50; i++) {
        expect(a.nextDouble(), b.nextDouble());
      }
    });

    test('different seeds diverge', () {
      final a = DeterministicRandom(1);
      final b = DeterministicRandom(2);
      expect(a.nextDouble(), isNot(b.nextDouble()));
    });

    test('hashString is stable', () {
      expect(DeterministicRandom.hashString('2026-08-31'),
          DeterministicRandom.hashString('2026-08-31'));
    });
  });

  group('arrow model', () {
    test('validates orthogonality', () {
      expect(
        arrow('a', [
          [0, 0],
          [3, 0],
        ], Direction.right)
            .validateGeometry(gridCols: 8, gridRows: 8),
        isEmpty,
      );
      expect(
        arrow('b', [
          [0, 0],
          [3, 3],
        ], Direction.right)
            .validateGeometry(gridCols: 8, gridRows: 8),
        isNotEmpty,
      );
    });

    test('rejects a head that disagrees with the last segment', () {
      final bad = arrow('c', [
        [0, 0],
        [3, 0],
      ], Direction.up);
      expect(bad.validateGeometry(), isNotEmpty);
    });

    test('path shapes are classified', () {
      expect(
        arrow('s', [
          [0, 0],
          [3, 0],
        ], Direction.right)
            .shapeKind,
        PathShapeKind.straight,
      );
      expect(
        arrow('l', [
          [0, 0],
          [3, 0],
          [3, 2],
        ], Direction.down)
            .shapeKind,
        PathShapeKind.lShape,
      );
      expect(
        arrow('u', [
          [0, 0],
          [0, 2],
          [3, 2],
          [3, 0],
        ], Direction.up)
            .shapeKind,
        PathShapeKind.uShape,
      );
    });
  });

  group('physics core', () {
    Level levelOf(List<PathArrow> arrows, {int cols = 8, int rows = 8}) => Level(
          levelId: 'test',
          seed: 1,
          difficulty: 1,
          gridCols: cols,
          gridRows: rows,
          arrows: arrows,
          metrics: metrics,
        );

    test('a free arrow escapes', () {
      final level = levelOf([
        arrow('a', [
          [1, 1],
          [4, 1],
        ], Direction.right),
      ]);
      final engine = PhysicsEngine();
      final evaluation = engine.evaluate(
        BoardCollisionIndex(level, level.initialState),
        0,
      );
      expect(evaluation.canMove, isTrue);
      expect(evaluation.escapes, isTrue);
    });

    test('an arrow queued behind another stops flush', () {
      final level = levelOf([
        arrow('front', [
          [6, 1],
          [7, 1],
        ], Direction.right),
        arrow('back', [
          [1, 1],
          [3, 1],
        ], Direction.right),
      ]);
      final engine = PhysicsEngine();
      final state = level.initialState;
      final back = engine.evaluate(BoardCollisionIndex(level, state), 1);
      expect(back.canMove, isTrue);
      expect(back.escapes, isFalse);
      expect(back.blockers, contains(0));

      // Committing the slide stops the arrow flush against the front arrow.
      final next = engine.applyMove(BoardCollisionIndex(level, state), 1, back);
      final after = engine.evaluate(BoardCollisionIndex(level, next), 1);
      expect(after.canMove, isTrue, reason: 'it can move once the front is gone');
    });

    test('an arrow is blocked when there is no room at all', () {
      final level = levelOf([
        arrow('front', [
          [2, 1],
          [7, 1],
        ], Direction.right),
        arrow('back', [
          [0, 1],
          [1, 1],
        ], Direction.right),
      ], cols: 8);
      final engine = PhysicsEngine();
      final back = engine.evaluate(BoardCollisionIndex(level, level.initialState), 1);
      expect(back.canMove, isTrue);
      expect(back.escapes, isFalse);
      // After sliding, the arrow rests flush and cannot continue.
      final next = engine.applyMove(
        BoardCollisionIndex(level, level.initialState),
        1,
        back,
      );
      final again = engine.evaluate(BoardCollisionIndex(level, next), 1);
      expect(again.travel, lessThan(MoveEvaluation.minimumTravel + 1e-9));
    });

    test('escapeOnly rules reject partial slides', () {
      final level = levelOf([
        arrow('front', [
          [6, 1],
          [7, 1],
        ], Direction.right),
        arrow('back', [
          [1, 1],
          [3, 1],
        ], Direction.right),
      ]);
      final engine = PhysicsEngine(
        rules: const GameRules().copyWith(travelMode: TravelMode.escapeOnly),
      );
      final back = engine.evaluate(BoardCollisionIndex(level, level.initialState), 1);
      expect(back.canMove, isFalse);
    });

    test('a perpendicular arrow crosses the corridor', () {
      final level = levelOf([
        arrow('h', [
          [1, 4],
          [4, 4],
        ], Direction.right),
        arrow('v', [
          [6, 2],
          [6, 6],
        ], Direction.down),
      ], cols: 10, rows: 10);
      final engine = PhysicsEngine();
      final blocked = engine.evaluate(BoardCollisionIndex(level, level.initialState), 0);
      expect(blocked.escapes, isFalse);
      expect(blocked.blockers, contains(1));
    });
  });

  group('generator', () {
    for (final band in [1, 2, 3, 4, 5]) {
      test('band $band produces valid, solvable levels', () {
        final generator = LevelGenerator();
        for (var seed = 0; seed < 3; seed++) {
          final level = generator.generate(
            difficulty: band,
            seed: 1000 + band * 97 + seed,
            levelNumber: band * 10 + seed,
          );
          expect(level.arrows, isNotEmpty);
          final issues = LevelGenerator.validate(level);
          expect(issues, isEmpty, reason: '${level.levelId}: $issues');
          expect(level.analysis!.isSolvable, isTrue);
          expect(level.analysis!.qualityScore, inInclusiveRange(0, 100));

          // Every arrow escapes in one move when played in the canonical order.
          final engine = PhysicsEngine();
          var state = level.initialState;
          final order = DependencyGraph.compute(level).topologicalEscapeOrder();
          for (final index in order) {
            final evaluation =
                engine.evaluate(BoardCollisionIndex(level, state), index);
            expect(evaluation.escapes, isTrue, reason: '${level.levelId} #$index');
            state = engine.applyMove(
              BoardCollisionIndex(level, state),
              index,
              evaluation,
            );
          }
          expect(state.isSolved, isTrue);
        }
      });
    }

    test('generation is deterministic', () {
      final a = LevelGenerator().generate(difficulty: 3, seed: 424242);
      final b = LevelGenerator().generate(difficulty: 3, seed: 424242);
      expect(a.toJson(), b.toJson());
    });

    test('different seeds give different levels', () {
      final a = LevelGenerator().generate(difficulty: 3, seed: 1);
      final b = LevelGenerator().generate(difficulty: 3, seed: 2);
      expect(a.toJson(), isNot(b.toJson()));
    });

    test('the generated layout respects minimum spacing', () {
      final level = LevelGenerator().generate(difficulty: 4, seed: 777);
      final gap = level.metrics.minGap;
      for (var i = 0; i < level.arrows.length; i++) {
        final a = ArrowGeometry.partsOf(level.arrows[i]);
        for (var j = i + 1; j < level.arrows.length; j++) {
          final b = ArrowGeometry.partsOf(level.arrows[j]);
          for (final p in a) {
            for (final q in b) {
              expect(p.overlaps(q), isFalse);
            }
          }
        }
      }
      expect(gap, greaterThan(0));
    });

    test('the dependency graph is acyclic', () {
      final level = LevelGenerator().generate(difficulty: 5, seed: 31337);
      final graph = DependencyGraph.compute(level);
      final order = graph.topologicalEscapeOrder();
      expect(order.length, level.arrowCount);
    });
  });

  group('solver', () {
    test('finds the canonical solution', () {
      final level = LevelGenerator().generate(difficulty: 3, seed: 5150);
      const solver = Solver(mode: SolverMode.greedy);
      final solution = solver.solve(level);
      expect(solution.isComplete, isTrue);
      expect(solution.length, level.arrowCount);
    });

    test('BFS agrees with the greedy canonical solution', () {
      final level = LevelGenerator().generate(difficulty: 2, seed: 909);
      const solver = Solver(mode: SolverMode.bfs, maxNodes: 20000);
      final solution = solver.solve(level);
      expect(solution.isComplete, isTrue);
      expect(solution.length, level.arrowCount,
          reason: 'each move removes at most one arrow');
    });

    test('reports unsolvable boards', () {
      // Two arrows facing each other dead-lock.
      final level = Level(
        levelId: 'deadlock',
        seed: 0,
        difficulty: 1,
        gridCols: 8,
        gridRows: 8,
        arrows: [
          arrow('left', [
            [1, 4],
            [4, 4],
          ], Direction.right),
          arrow('right', [
            [6, 4],
            [3, 4],
          ], Direction.left),
        ],
        metrics: metrics,
      );
      const solver = Solver(mode: SolverMode.bfs, maxNodes: 5000);
      expect(solver.solve(level).isComplete, isFalse);
    });
  });

  group('game controller', () {
    test('counts moves, not animation frames', () {
      final level = LevelGenerator().generate(difficulty: 2, seed: 2024);
      final controller = GameController(level: level);
      expect(controller.moves, 0);
      final movable = controller.evaluateAll().firstWhere((e) => e.canMove);
      controller.tapArrow(movable.arrowIndex);
      expect(controller.moves, 1);
    });

    test('blocked taps do not mutate the board', () {
      final level = LevelGenerator().generate(difficulty: 4, seed: 606);
      final controller = GameController(level: level);
      final blocked = controller.evaluateAll().firstWhere((e) => !e.canMove);
      final before = controller.state.key;
      final result = controller.tapArrow(blocked.arrowIndex);
      expect(result!.wasBlocked, isTrue);
      expect(controller.state.key, before);
      expect(controller.moves, 0);
    });

    test('undo restores the previous state exactly', () {
      final level = LevelGenerator().generate(difficulty: 3, seed: 8080);
      final controller = GameController(level: level);
      final before = controller.state.key;
      final movable = controller.evaluateAll().firstWhere((e) => e.canMove);
      controller.tapArrow(movable.arrowIndex);
      expect(controller.state.key, isNot(before));
      expect(controller.undo(), isTrue);
      expect(controller.state.key, before);
      expect(controller.moves, 0);
    });

    test('hint points at an arrow that can escape', () {
      final level = LevelGenerator().generate(difficulty: 3, seed: 1234);
      final controller = GameController(level: level);
      final hint = controller.requestHint();
      expect(hint, isNotNull);
      expect(controller.evaluate(hint!).escapes, isTrue);
      expect(controller.hints, level.rules.hints - 1);
    });

    test('restarting after a dead end costs a life', () {
      final level = LevelGenerator().generate(difficulty: 2, seed: 11);
      final controller = GameController(level: level);
      final lives = controller.lives;
      controller.restartWithPenalty();
      expect(controller.lives, lives - 1);
    });

    test('stars follow par', () {
      final level = LevelGenerator().generate(difficulty: 1, seed: 4);
      final controller = GameController(level: level);
      expect(controller.starsFor(controller.par), 3);
      expect(controller.starsFor(controller.par + 1000), 1);
    });
  });

  group('difficulty parameters', () {
    test('the campaign ramps across all five bands', () {
      final bands = <int>{
        for (var i = 1; i <= 50; i++) DifficultyParams.forLevelIndex(i).band,
      };
      expect(bands, {1, 2, 3, 4, 5});
    });

    test('endless keeps ramping past level 50', () {
      final p60 = DifficultyParams.forBand(5);
      expect(p60.arrowMax, greaterThan(DifficultyParams.forBand(1).arrowMax));
    });
  });
}
