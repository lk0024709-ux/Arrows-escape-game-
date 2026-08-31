import 'dart:math';
import 'dart:ui';

import 'grid.dart';
import 'grid_point.dart';

enum Direction { up, down, left, right }

enum ArrowState { active, escaping, blocked, selected }

/// One arrow: an orthogonal polyline on the grid plus a direction it escapes in.
class ArrowPath {
  final String id;
  final List<GridPoint> points;
  final Direction direction;
  final double thickness;
  final double arrowHeadSize;
  ArrowState state;
  bool isMoving;
  bool isRemoved;
  bool isEscaping;

  ArrowPath({
    required this.id,
    required this.points,
    required this.direction,
    this.thickness = 8.0,
    this.arrowHeadSize = 20.0,
    this.state = ArrowState.active,
    this.isMoving = false,
    this.isRemoved = false,
    this.isEscaping = false,
  }) : assert(points.length >= 2, 'An arrow needs at least a tail and a head');

  /// Get the endpoint grid point (where arrowhead is)
  GridPoint get endpoint => points.last;

  /// Get the start grid point
  GridPoint get start => points.first;

  /// Get the second-to-last point (for direction calculation)
  GridPoint get secondToLast =>
      points.length >= 2 ? points[points.length - 2] : points.first;

  /// Calculate the logical direction from the final path segment, so the
  /// arrowhead points where the tip is actually heading (matters for bends).
  static Direction calculateDirection(List<GridPoint> points) {
    if (points.length < 2) return Direction.right;

    final p1 = points[points.length - 2];
    final p2 = points.last;

    if (p2.x > p1.x) return Direction.right;
    if (p2.x < p1.x) return Direction.left;
    if (p2.y > p1.y) return Direction.down;
    if (p2.y < p1.y) return Direction.up;

    return Direction.right;
  }

  /// Unit step taken when travelling along [direction].
  static GridPoint delta(Direction direction) {
    switch (direction) {
      case Direction.right:
        return const GridPoint(1, 0);
      case Direction.left:
        return const GridPoint(-1, 0);
      case Direction.down:
        return const GridPoint(0, 1);
      case Direction.up:
        return const GridPoint(0, -1);
    }
  }

  /// True when the stored direction agrees with the actual geometry, i.e. the
  /// head really is further along [direction] than the segment it sits on.
  bool get isValidDirection {
    if (points.length < 2) return false;
    if (start == endpoint) return false;

    final tail = secondToLast;
    switch (direction) {
      case Direction.right:
        return endpoint.x > tail.x;
      case Direction.left:
        return endpoint.x < tail.x;
      case Direction.down:
        return endpoint.y > tail.y;
      case Direction.up:
        return endpoint.y < tail.y;
    }
  }

  /// Every grid cell covered by the body of this arrow.
  List<GridPoint> get occupiedCells {
    final cells = <GridPoint>[];
    final seen = <String>{};

    void add(GridPoint p) {
      if (seen.add('${p.x},${p.y}')) cells.add(p);
    }

    for (int i = 0; i < points.length; i++) {
      add(points[i]);
      if (i == 0) continue;
      var cursor = points[i - 1];
      final target = points[i];
      var guard = 0;
      while (cursor != target && guard++ < 512) {
        if (cursor.x != target.x) {
          cursor = cursor.translate(cursor.x < target.x ? 1 : -1, 0);
        } else if (cursor.y != target.y) {
          cursor = cursor.translate(0, cursor.y < target.y ? 1 : -1);
        }
        add(cursor);
      }
    }
    return cells;
  }

  /// Cells swept by the arrow head as it flies off the board, widened by
  /// [halfWidth] on both sides. Another arrow body inside this corridor blocks
  /// the escape.
  List<GridPoint> escapeCorridor(Grid grid, {int halfWidth = 1}) {
    final step = delta(direction);
    final side = (direction == Direction.left || direction == Direction.right)
        ? const GridPoint(0, 1)
        : const GridPoint(1, 0);

    final corridor = <GridPoint>[];
    final seen = <String>{};
    var cursor = endpoint;
    var guard = 0;

    while (grid.inBoundsPoint(cursor) && guard++ < 512) {
      for (int w = -halfWidth; w <= halfWidth; w++) {
        final cell = cursor.translate(side.x * w, side.y * w);
        if (!grid.inBoundsPoint(cell)) continue;
        if (seen.add('${cell.x},${cell.y}')) corridor.add(cell);
      }
      cursor = cursor.translate(step.x, step.y);
    }
    return corridor;
  }

  /// Same arrow following a different polyline. Paths are immutable so the
  /// generator re-places an arrow by deriving a new one.
  ArrowPath withPoints(List<GridPoint> newPoints) {
    return ArrowPath(
      id: id,
      points: List<GridPoint>.of(newPoints),
      direction: calculateDirection(newPoints),
      thickness: thickness,
      arrowHeadSize: arrowHeadSize,
    );
  }

  /// Get the arrowhead path as a list of offsets for rendering
  List<Offset> getArrowheadPath(Offset startOffset, double cellSize, Direction dir) {
    final headX = startOffset.dx;
    final headY = startOffset.dy;
    final half = arrowHeadSize / 2;

    switch (dir) {
      case Direction.right:
        return [
          Offset(headX + arrowHeadSize, headY),
          Offset(headX, headY - half),
          Offset(headX, headY + half),
        ];
      case Direction.left:
        return [
          Offset(headX - arrowHeadSize, headY),
          Offset(headX, headY - half),
          Offset(headX, headY + half),
        ];
      case Direction.down:
        return [
          Offset(headX, headY + arrowHeadSize),
          Offset(headX - half, headY),
          Offset(headX + half, headY),
        ];
      case Direction.up:
        return [
          Offset(headX, headY - arrowHeadSize),
          Offset(headX - half, headY),
          Offset(headX + half, headY),
        ];
    }
  }

  /// Get the main path body points for rendering
  List<Offset> getPathBodyOffsets(double cellSize) {
    if (points.isEmpty) return [];

    return points.map((point) => point.toOffset(cellSize)).toList();
  }

  double getLength() {
    if (points.length < 2) return 0;

    double total = 0;
    for (int i = 1; i < points.length; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dy = points[i].y - points[i - 1].y;
      total += sqrt(dx * dx + dy * dy);
    }
    return total;
  }

  /// Check if a pixel position hits this path. [cellSize] is needed because the
  /// path is stored in grid units but taps arrive in pixels.
  bool containsPoint(Offset point, double cellSize, {double tolerance = 15.0}) {
    if (points.length < 2) return false;

    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1].toOffset(cellSize);
      final p2 = points[i].toOffset(cellSize);

      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final lengthSq = dx * dx + dy * dy;

      if (lengthSq == 0) {
        final distSq = (point.dx - p1.dx) * (point.dx - p1.dx) +
            (point.dy - p1.dy) * (point.dy - p1.dy);
        if (distSq <= tolerance * tolerance) return true;
      } else {
        final t = ((point.dx - p1.dx) * dx + (point.dy - p1.dy) * dy) / lengthSq;
        final clampedT = t.clamp(0.0, 1.0);
        final closestX = p1.dx + clampedT * dx;
        final closestY = p1.dy + clampedT * dy;
        final distSq = (point.dx - closestX) * (point.dx - closestX) +
            (point.dy - closestY) * (point.dy - closestY);
        if (distSq <= tolerance * tolerance) return true;
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArrowPath && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ArrowPath($id, ${points.length} pts, $direction)';
}
