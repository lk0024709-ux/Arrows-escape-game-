import 'dart:ui';

/// Logical grid point for the construction system.
/// These are the invisible nodes that paths are built upon.
class GridPoint {
  final int x;
  final int y;

  const GridPoint(this.x, this.y);

  /// Centre of this cell in pixel space for a given cell size.
  Offset toOffset(double cellSize) {
    return Offset(x * cellSize + cellSize / 2, y * cellSize + cellSize / 2);
  }

  /// A point shifted by [dx]/[dy] cells.
  GridPoint translate(int dx, int dy) => GridPoint(x + dx, y + dy);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GridPoint && x == other.x && y == other.y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}
