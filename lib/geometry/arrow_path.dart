import 'grid_point.dart';

enum Direction { up, down, left, right }

enum ArrowState { active, escaping, blocked, selected }

import 'dart:math';

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
  }) : assert(points.length >= 2);

  /// Get the endpoint grid point (where arrowhead is)
  GridPoint get endpoint => points.last;

  /// Get the start grid point
  GridPoint get start => points.first;

  /// Get the second-to-last point (for direction calculation)
  GridPoint get secondToLast => points.length >= 2 ? points[points.length - 2] : points.first;

  /// Calculate the logical direction based on path points
  static Direction calculateDirection(List<GridPoint> points) {
    if (points.length < 2) return Direction.right;
    
    final p1 = points.first;
    final p2 = points.last;
    
    if (p2.x > p1.x) return Direction.right;
    if (p2.x < p1.x) return Direction.left;
    if (p2.y > p1.y) return Direction.down;
    if (p2.y < p1.y) return Direction.up;
    
    return Direction.right;
  }

  /// Get the arrowhead path as a list of offsets for rendering
  List<Offset> getArrowheadPath(Offset startOffset, double cellSize, Direction dir) {
    final headX = startOffset.dx;
    final headY = startOffset.dy;
    
    switch (dir) {
      case Direction.right:
        return [
          Offset(headX, headY),
          Offset(headX + arrowHeadSize, headY - arrowHeadSize ~/ 2),
          Offset(headX + arrowHeadSize, headY + arrowHeadSize ~/ 2),
        ];
      case Direction.left:
        return [
          Offset(headX, headY),
          Offset(headX - arrowHeadSize, headY - arrowHeadSize ~/ 2),
          Offset(headX - arrowHeadSize, headY + arrowHeadSize ~/ 2),
        ];
      case Direction.down:
        return [
          Offset(headX, headY),
          Offset(headX - arrowHeadSize ~/ 2, headY + arrowHeadSize),
          Offset(headX + arrowHeadSize ~/ 2, headY + arrowHeadSize),
        ];
      case Direction.up:
        return [
          Offset(headX, headY),
          Offset(headX - arrowHeadSize ~/ 2, headY - arrowHeadSize),
          Offset(headX + arrowHeadSize ~/ 2, headY - arrowHeadSize),
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

  /// Check if a position collides with this path
  bool containsPoint(Offset point, double tolerance) {
    if (points.length < 2) return false;
    
    // Check distance to each segment
    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1].toOffset(1.0);
      final p2 = points[i].toOffset(1.0);
      
      // Calculate distance from point to line segment
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
}