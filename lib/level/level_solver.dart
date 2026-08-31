import 'dart:math';
import 'grid_point.dart';
import 'arrow_path.dart';
import 'level/level.dart';

class LevelSolver {
  final Level level;

  LevelSolver({required this.level});

  /// Solve the puzzle using BFS to find if there's a valid sequence of arrow escapes
  List<ArrowPath> solve() {
    final initialState = _State(
      arrows: List<ArrowPath>.from(level.arrows),
      moveCount: 0,
    );

    // BFS
    final visited = <String>{};
    final queue = Queue<_State>();
    queue.add(initialState);
    visited.add(initialState.hashKey);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      // Check if puzzle is solved (all arrows escaped)
      if (current.arrows.isEmpty) {
        return _extractSolutionPath(current);
      }

      // Find all available arrows that can escape
      final available = current.getAvailable();

      // For each available arrow, try escaping it
      for (final arrow in available) {
        final newArrows = List<ArrowPath>.from(current.arrows);
        newArrows.removeWhere((a) => a.id == arrow.id);

        final newState = _State(
          arrows: newArrows,
          moveCount: current.moveCount + 1,
        );

        final key = newState.hashKey;
        if (!visited.contains(key)) {
          visited.add(key);
          queue.add(newState);
        }
      }
    }

    // No solution found
    return [];
  }

  /// Extract solution path from BFS results
  List<ArrowPath> _extractSolutionPath(_State finalState) {
    return [];
  }
}

/// Internal state representation for the solver
class _State {
  final List<ArrowPath> arrows;
  final int moveCount;

  _State({
    required this.arrows,
    required this.moveCount,
  });

  String get hashKey {
    final hash = arrows.map((a) => a.hashCode).reduce((a, b) => a ^ b, defaultValue: 0);
    return '$hash-$moveCount';
  }

  /// Get arrows that can currently escape (have clear corridors)
  List<ArrowPath> get available {
    return arrows.where((arrow) => canEscape(arrow)).toList();
  }

  /// Check if a specific arrow can escape
  bool canEscape(ArrowPath arrow) {
    // Check if the arrow's escape corridor is clear of other arrows
    final dir = arrow.direction;
    final endpoint = arrow.endpoint;

    for (final other in arrows) {
      if (other.id == arrow.id) continue;

      // Check if other arrow blocks the escape corridor
      if (_isInEscapeCorridor(other, dir, endpoint)) return false;
    }

    return true;
  }

  /// Check if another arrow's position is in this arrow's escape corridor
  bool _isInEscapeCorridor(ArrowPath other, Direction dir, GridPoint endpoint) {
    // Calculate the escape corridor area in the forward direction
    // This includes the path width, arrowhead clearance, and safety margin

    for (final point in other.points) {
      // Simple bounding box check for the corridor
      final dx = point.x - endpoint.x;
      final dy = point.y - endpoint.y;

      // Check if point is in front of the arrow's endpoint
      bool inFront = false;
      switch (dir) {
        case Direction.right:
          inFront = dx > 0;
          break;
        case Direction.left:
          inFront = dx < 0;
          break;
        case Direction.up:
          inFront = dy < 0;
          break;
        case Direction.down:
          inFront = dy > 0;
          break;
      }

      if (inFront) {
        // Check proximity - if too close, it blocks
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < 3.0) return true; // Blocks the corridor
      }
    }

    return false;
  }
}