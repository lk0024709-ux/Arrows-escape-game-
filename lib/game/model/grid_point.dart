import 'dart:math' as math;

import 'direction.dart';

/// An integer node on the invisible logical construction grid.
///
/// Every generated path is built exclusively from these nodes — the engine never
/// invents free-floating pixel coordinates (prompt §13).
class GridPoint {
  const GridPoint(this.col, this.row);

  final int col;
  final int row;

  static const GridPoint zero = GridPoint(0, 0);

  GridPoint operator +(GridPoint o) => GridPoint(col + o.col, row + o.row);
  GridPoint operator -(GridPoint o) => GridPoint(col - o.col, row - o.row);
  GridPoint operator *(int s) => GridPoint(col * s, row * s);

  GridPoint translate(int dc, int dr) => GridPoint(col + dc, row + dr);

  GridPoint step(Direction d, [int distance = 1]) =>
      GridPoint(col + d.dx * distance, row + d.dy * distance);

  /// Manhattan distance to another node.
  int manhattanTo(GridPoint o) => (col - o.col).abs() + (row - o.row).abs();

  double distanceTo(GridPoint o) =>
      math.sqrt((col - o.col) * (col - o.col) + (row - o.row) * (row - o.row));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GridPoint && other.col == col && other.row == row);

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => '($col, $row)';
}
