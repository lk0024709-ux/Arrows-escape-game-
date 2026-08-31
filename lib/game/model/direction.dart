import 'dart:math' as math;

/// The four orthogonal directions a path may travel in.
/// Diagonals are never allowed (see `PathArrow.validateGeometry`).
enum Direction { up, down, left, right }

extension DirectionX on Direction {
  int get dx => switch (this) {
        Direction.right => 1,
        Direction.left => -1,
        _ => 0,
      };

  int get dy => switch (this) {
        Direction.down => 1,
        Direction.up => -1,
        _ => 0,
      };

  bool get isHorizontal => this == Direction.left || this == Direction.right;
  bool get isVertical => !isHorizontal;

  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
        Direction.right => Direction.left,
      };

  /// Clockwise turn.
  Direction get turnClockwise => switch (this) {
        Direction.up => Direction.right,
        Direction.right => Direction.down,
        Direction.down => Direction.left,
        Direction.left => Direction.up,
      };

  /// Counter-clockwise turn.
  Direction get turnCounterClockwise => turnClockwise.opposite;

  /// Rotation in radians (0 = pointing right).
  double get radians => switch (this) {
        Direction.right => 0,
        Direction.down => math.pi / 2,
        Direction.left => math.pi,
        Direction.up => -math.pi / 2,
      };

  String get key => switch (this) {
        Direction.up => 'up',
        Direction.down => 'down',
        Direction.left => 'left',
        Direction.right => 'right',
      };

  static const List<Direction> values = Direction.values;

  static Direction fromKey(String? key) => switch (key) {
        'up' => Direction.up,
        'down' => Direction.down,
        'left' => Direction.left,
        'right' => Direction.right,
        _ => Direction.right,
      };

  static Direction fromDelta(int dx, int dy) {
    if (dx == 0 && dy == 0) return Direction.right;
    if (dx.abs() >= dy.abs()) {
      return dx >= 0 ? Direction.right : Direction.left;
    }
    return dy >= 0 ? Direction.down : Direction.up;
  }
}
