import 'dart:math';

import 'grid_point.dart';
import 'geometry/grid.dart';
import 'arrow_path.dart';

class DifficultyParams {
  final int boardWidth;
  final int boardHeight;
  final int arrowCount;
  final int maxPathLength;
  final double minPathGap;

  DifficultyParams({
    required this.boardWidth,
    required this.boardHeight,
    required this.arrowCount,
    required this.maxPathLength,
    required this.minPathGap,
  });
}

class Level {
  final int generatorSeed;
  final DifficultyParams difficulty;
  int qualityScore = 0;
  List<ArrowPath> arrows = [];
  Grid? grid;
  List<ArrowPath> solutionOrder = [];
  int solutionLength = 0;
  int dependencyComplexity = 0;
  int branchingFactor = 0;
  int pathComplexity = 0;
  double spatialDensity = 0.0;
  int trivialMoves = 0;
  bool _selectedArrow = -1; // Index of selected arrow, -1 = none

  Level({
    required this.generatorSeed,
    required this.difficulty,
  });

  /// Check if level is valid (passes all validation rules)
  bool get isValid {
    if (arrows.isEmpty) return false;
    if (grid == null) return false;

    // All arrows must have valid geometry
    for (final arrow in arrows) {
      if (arrow.points.length < 2) return false;
      if (!arrow.isValidDirection) return false;
    }

    // No overlapping arrows
    for (int i = 0; i < arrows.length; i++) {
      for (int j = i + 1; j < arrows.length; j++) {
        if (_pathsIntersect(arrows[i], arrows[j])) return false;
      }
    }

    // Must be solvable
    final solver = LevelSolver(level: this);
    final solution = solver.solve();
    if (solution.isEmpty) return false;

    return true;
  }

  bool get isLevelComplete {
    // Level is complete when all arrows have escaped
    return arrows.isEmpty;
  }

  /// Get the index of the currently selected arrow
  int get selectedArrowIndex => _selectedArrow;

  /// Set the selected arrow index
  void setSelectedArrow(int index) {
    _selectedArrow = index;
  }

  /// Clear the selected arrow
  void clearSelectedArrow() {
    _selectedArrow = -1;
  }

  /// Check if two paths intersect
  bool _pathsIntersect(ArrowPath a, ArrowPath b) {
    for (final p1 in a.points) {
      for (final p2 in b.points) {
        if (p1.x == p2.x && p1.y == p2.y) return true;
      }
    }
    return false;
  }

  /// Get available arrows (those that can potentially escape)
  List<ArrowPath> getAvailableArrows() {
    return arrows.where((arrow) {
      // An arrow is available if its escape corridor is clear
      return _checkEscapeCorridor(arrow);
    }).toList();
  }

  /// Check if a specific arrow's escape corridor is clear
  bool _checkEscapeCorridor(ArrowPath arrow) {
    // The arrow is blocked if any other active object occupies its forward escape corridor
    final dir = arrow.direction;
    final endpoint = arrow.endpoint;

    // Calculate forward escape corridor from endpoint
    for (final otherArrow in arrows) {
      if (otherArrow.id == arrow.id) continue;

      for (final point in otherArrow.points) {
        // Check if other arrow occupies the escape corridor
        if (_pointInEscapeCorridor(point, dir, endpoint)) return false;
      }
    }

    return true;
  }

  /// Check if a point is in the arrow's escape corridor
  bool _pointInEscapeCorridor(Offset point, Direction dir, GridPoint endpoint) {
    // Simplified check - in full implementation, this would calculate the full escape corridor
    // based on path width, arrowhead clearance, and safety margin
    return false;
  }

  /// Get arrow by ID
  ArrowPath? getArrowById(String id) {
    return arrows.firstWhere((arrow) => arrow.id == id, orElse: () => arrows.first);
  }

  /// Get count of available (non-blocked) arrows
  int get availableArrowCount {
    return getAvailableArrows().length;
  }
}