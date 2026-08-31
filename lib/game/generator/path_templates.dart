import '../../core/geometry/geometry.dart';
import '../../core/math/vector2.dart';
import '../../core/rng/deterministic_random.dart';
import '../model/direction.dart';
import '../model/grid_point.dart';
import '../model/path_arrow.dart';

/// Procedural construction of orthogonal paths from logical grid nodes
/// (prompt §6, §7, §12, §13).
///
/// Every path is produced by walking the invisible construction grid:
/// `node → horizontal/vertical segment → node → turn → node`.
/// No pixel coordinates are ever invented.
class PathTemplates {
  const PathTemplates._();

  /// Random orthogonal walk.
  ///
  /// When [isFree] is supplied the walk only grows through free cells, which is
  /// what makes dense packing possible at all.
  ///
  /// Returns `null` when the walk leaves the board, folds onto itself, or hits
  /// an occupied cell before reaching [minLength].
  static List<GridPoint>? randomWalk({
    required DeterministicRandom rng,
    required int cols,
    required int rows,
    required int segments,
    required int minLength,
    required int maxLength,
    double turnBias = 0.5,
    GridPoint? origin,
    Direction? heading,
    bool Function(int col, int row)? isFree,
  }) {
    final start = origin ?? GridPoint(rng.nextInt(cols), rng.nextInt(rows));
    if (isFree != null && !isFree(start.col, start.row)) return null;

    final points = <GridPoint>[start];
    var dir = heading ?? Direction.values[rng.nextInt(4)];
    var current = start;

    for (var s = 0; s < segments; s++) {
      final target = rng.nextIntRange(minLength, maxLength);
      var next = current;
      var length = 0;
      for (var k = 1; k <= target; k++) {
        final candidate = current.step(dir, k);
        if (candidate.col < 0 ||
            candidate.col >= cols ||
            candidate.row < 0 ||
            candidate.row >= rows) {
          break;
        }
        if (isFree != null && !isFree(candidate.col, candidate.row)) break;
        next = candidate;
        length = k;
      }
      if (length < minLength) return null;
      if (touchesExisting(points, current, next)) return null;
      points.add(next);
      current = next;
      if (s < segments - 1) {
        dir = rng.nextBool(turnBias) ? dir.turnClockwise : dir.turnCounterClockwise;
      }
    }
    return points.length >= 2 ? points : null;
  }

  /// `true` when the new segment illegally meets the path it belongs to
  /// (crossing, overlapping or folding back).
  static bool touchesExisting(List<GridPoint> points, GridPoint from, GridPoint to) {
    final newBox = Aabb.fromPoints(
      Vec2(from.col.toDouble(), from.row.toDouble()),
      Vec2(to.col.toDouble(), to.row.toDouble()),
    );
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final box = Aabb.fromPoints(
        Vec2(a.col.toDouble(), a.row.toDouble()),
        Vec2(b.col.toDouble(), b.row.toDouble()),
      );
      if (newBox.overlaps(box)) return true;
    }
    return false;
  }

  /// Deterministic named shape (used by the level editor's shape presets).
  static List<GridPoint> named(
    PathShapeKind kind,
    GridPoint origin,
    Direction heading, {
    int length = 3,
    int depth = 2,
  }) {
    final points = <GridPoint>[origin];
    var current = origin;
    var dir = heading;
    switch (kind) {
      case PathShapeKind.straight:
        points.add(current.step(dir, length));
      case PathShapeKind.lShape:
        current = current.step(dir, length);
        points.add(current);
        dir = dir.turnClockwise;
        current = current.step(dir, depth);
        points.add(current);
      case PathShapeKind.uShape:
        current = current.step(dir, length);
        points.add(current);
        dir = dir.turnClockwise;
        current = current.step(dir, depth);
        points.add(current);
        dir = dir.turnClockwise;
        current = current.step(dir, length);
        points.add(current);
      case PathShapeKind.zigZag:
        current = current.step(dir, length);
        points.add(current);
        dir = dir.turnCounterClockwise;
        current = current.step(dir, depth);
        points.add(current);
        dir = dir.turnClockwise;
        current = current.step(dir, length);
        points.add(current);
      case PathShapeKind.sShape:
        current = current.step(dir, length);
        points.add(current);
        dir = dir.turnClockwise;
        current = current.step(dir, depth);
        points.add(current);
        dir = dir.turnCounterClockwise;
        current = current.step(dir, length);
        points.add(current);
        dir = dir.turnClockwise;
        current = current.step(dir, depth);
        points.add(current);
      case PathShapeKind.complex:
        current = current.step(dir, length);
        points.add(current);
        dir = dir.turnClockwise;
        current = current.step(dir, depth);
        points.add(current);
        dir = dir.turnCounterClockwise;
        current = current.step(dir, length);
        points.add(current);
        dir = dir.turnCounterClockwise;
        current = current.step(dir, depth);
        points.add(current);
        dir = dir.turnClockwise;
        current = current.step(dir, length);
        points.add(current);
    }
    return points;
  }

  /// Direction implied by the final segment of a node list.
  static Direction directionOf(List<GridPoint> points) {
    final a = points[points.length - 2];
    final b = points[points.length - 1];
    return DirectionX.fromDelta(b.col - a.col, b.row - a.row);
  }
}
