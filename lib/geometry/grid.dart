/// Invisible logical construction grid.
/// Used for alignment, spacing, collision detection, and path generation.
/// Should normally be invisible to the player, but can be shown in debug mode.
class Grid {
  final int width;
  final int height;
  final double cellSize;

  Grid({
    required this.width,
    required this.height,
    this.cellSize = 50.0,
  });

  /// Get all cells in the grid
  List<GridPoint> get cells {
    final list = <GridPoint>[];
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        list.add(GridPoint(x, y));
      }
    }
    return list;
  }

  /// Check if grid coordinates are within bounds
  bool inBounds(int x, int y) {
    return x >= 0 && x < width && y >= 0 && y < height;
  }

  /// Get neighboring grid points in orthogonal directions
  List<GridPoint> getNeighbors(GridPoint point) {
    final neighbors = <GridPoint>[];
    final directions = [
      GridPoint(point.x + 1, point.y),
      GridPoint(point.x - 1, point.y),
      GridPoint(point.x, point.y + 1),
      GridPoint(point.x, point.y - 1),
    ];

    for (final neighbor in directions) {
      if (inBounds(neighbor.x, neighbor.y)) {
        neighbors.add(neighbor);
      }
    }
    return neighbors;
  }

  /// Get offset for a grid point (for rendering)
  Offset offsetFor(GridPoint point) {
    return Offset(point.x * cellSize + cellSize / 2, point.y * cellSize + cellSize / 2);
  }

  /// Get grid point from screen coordinates
  GridPoint? pointFromOffset(Offset offset) {
    final x = (offset.dx / cellSize).round();
    final y = (offset.dy / cellSize).round();
    if (inBounds(x, y)) {
      return GridPoint(x, y);
    }
    return null;
  }

  @override
  String toString() => 'Grid($width x $height, cellSize: $cellSize)';
}