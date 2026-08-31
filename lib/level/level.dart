import '../geometry/arrow_path.dart';
import '../geometry/grid.dart';
import 'difficulty.dart';
import 'level_solver.dart';

/// A single generated board: the grid, the arrows on it and the quality
/// measurements the generator recorded for it.
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

  int _selectedArrowIndex = -1; // Index of selected arrow, -1 = none

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
        if (pathsIntersect(arrows[i], arrows[j])) return false;
      }
    }

    // Must be solvable
    return LevelSolver(level: this).solve().isNotEmpty;
  }

  bool get isLevelComplete => arrows.isEmpty;

  /// Get the index of the currently selected arrow
  int get selectedArrowIndex => _selectedArrowIndex;

  /// Set the selected arrow index
  void setSelectedArrowIndex(int index) {
    _selectedArrowIndex = index;
  }

  /// Clear the selected arrow
  void clearSelectedArrow() {
    _selectedArrowIndex = -1;
  }

  /// Remove an escaped arrow from the board.
  void removeArrow(ArrowPath arrow) {
    arrows.removeWhere((a) => a.id == arrow.id);
  }

  /// Check if two paths intersect
  bool pathsIntersect(ArrowPath a, ArrowPath b) {
    final bCells = <String>{
      for (final p in b.occupiedCells) '${p.x},${p.y}',
    };
    for (final p in a.occupiedCells) {
      if (bCells.contains('${p.x},${p.y}')) return true;
    }
    return false;
  }

  /// Get available arrows (those that can potentially escape)
  List<ArrowPath> getAvailableArrows() {
    final solver = LevelSolver(level: this);
    return arrows.where(solver.canEscape).toList();
  }

  /// Get count of available (non-blocked) arrows
  int get availableArrowCount => getAvailableArrows().length;

  /// Get arrow by ID, or null when it is not on the board.
  ArrowPath? getArrowById(String id) {
    for (final arrow in arrows) {
      if (arrow.id == id) return arrow;
    }
    return null;
  }

  /// A board snapshot with a different selection. Used for undo, so the arrow
  /// list is copied rather than shared.
  Level copyWithSelectedArrow(ArrowPath? arrow) {
    final copy = Level(generatorSeed: generatorSeed, difficulty: difficulty)
      ..grid = grid
      ..arrows = List<ArrowPath>.of(arrows)
      ..solutionOrder = List<ArrowPath>.of(solutionOrder)
      ..qualityScore = qualityScore
      ..solutionLength = solutionLength
      ..dependencyComplexity = dependencyComplexity
      ..branchingFactor = branchingFactor
      ..pathComplexity = pathComplexity
      ..spatialDensity = spatialDensity
      ..trivialMoves = trivialMoves;

    if (arrow == null) {
      copy.clearSelectedArrow();
    } else {
      final index = copy.arrows.indexOf(arrow);
      if (index < 0) {
        copy.clearSelectedArrow();
      } else {
        copy.setSelectedArrowIndex(index);
      }
    }
    return copy;
  }

  @override
  String toString() =>
      'Level(seed: $generatorSeed, ${difficulty.level.name}, ${arrows.length} arrows)';
}
