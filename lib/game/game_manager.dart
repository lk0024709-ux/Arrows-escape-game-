import 'dart:math';

import 'package:Arrows-escape-game-/lib/geometry/arrow_path.dart';
import 'package:Arrows-escape-game-/lib/level/level.dart';
import 'package:Arrows-escape-game-/lib/level/level_generator.dart';
import 'package:Arrows-escape-game-/lib/level/level_solver.dart';

enum DifficultyLevel { easy, normal, medium, hard, expert }

class GameManager {
  DifficultyLevel _currentDifficulty = DifficultyLevel.normal;
  int _currentSeed = DateTime.now().millisecondsSinceEpoch;
  int _moveCount = 0;
  int _lives = 3;
  Level? _currentLevel;
  ArrowPath? _selectedArrow;
  final List<ArrowPath> _history = [];
  final LevelGenerator _generator = LevelGenerator();
  final LevelSolver _solver = LevelSolver();

  int get moveCount => _moveCount;
  int get lives => _lives;
  DifficultyLevel get currentDifficulty => _currentDifficulty;
  int get currentSeed => _currentSeed;
  Level? get currentLevel => _currentLevel;
  ArrowPath? get selectedArrow => _selectedArrow;

  GameManager() {
    _resetMoveCount();
  }

  void _resetMoveCount() {
    _moveCount = 0;
    _history.clear();
  }

  void setLevel(Level level) {
    _currentLevel = level;
    _selectedArrow = null;
    _moveCount = 0;
    _history.clear();
    _lives = 3;
  }

  void nextDifficulty() {
    switch (_currentDifficulty) {
      case DifficultyLevel.easy:
        _currentDifficulty = DifficultyLevel.normal;
        break;
      case DifficultyLevel.normal:
        _currentDifficulty = DifficultyLevel.medium;
        break;
      case DifficultyLevel.medium:
        _currentDifficulty = DifficultyLevel.hard;
        break;
      case DifficultyLevel.hard:
        _currentDifficulty = DifficultyLevel.expert;
        break;
      case DifficultyLevel.expert:
        _currentDifficulty = DifficultyLevel.easy;
        break;
    }
    _currentSeed = DateTime.now().millisecondsSinceEpoch;
    setLevel(Level(generatorSeed: _currentSeed, difficulty: _currentDifficulty));
  }

  void prevDifficulty() {
    switch (_currentDifficulty) {
      case DifficultyLevel.easy:
        _currentDifficulty = DifficultyLevel.expert;
        break;
      case DifficultyLevel.normal:
        _currentDifficulty = DifficultyLevel.easy;
        break;
      case DifficultyLevel.medium:
        _currentDifficulty = DifficultyLevel.normal;
        break;
      case DifficultyLevel.hard:
        _currentDifficulty = DifficultyLevel.medium;
        break;
      case DifficultyLevel.expert:
        _currentDifficulty = DifficultyLevel.hard;
        break;
    }
    _currentSeed = DateTime.now().millisecondsSinceEpoch;
    setLevel(Level(generatorSeed: _currentSeed, difficulty: _currentDifficulty));
  }

  void regenerateLevel() {
    // Regenerate level with same seed but possibly different parameters
    if (_currentLevel != null) {
      final level = _generator.generate(
        difficulty: _currentDifficulty,
        seed: _currentSeed,
      );
      setLevel(level);
    }
  }

  void onArrowSelected(ArrowPath arrow) {
    // Record state before selection for undo
    if (_currentLevel != null) {
      _history.add(_currentLevel!.copyWithSelectedArrow(null));
    }
    _selectedArrow = arrow;
    // Increment move count when player actively selects an arrow
    _moveCount++;
  }

  void onArrowReleased(ArrowPath arrow) {
    if (_selectedArrow == arrow) {
      _executeArrow(arrow);
      _selectedArrow = null;
    }
  }

  void _executeArrow(ArrowPath arrow) {
    // Check if arrow can escape using the physics/validator
    final canEscape = _checkEscapeCorridor(arrow);

    if (canEscape) {
      // Animate arrow escaping (in full implementation)
      arrow.isEscaping = true;
      // Remove arrow from board
      if (_currentLevel != null) {
        _currentLevel!.removeArrow(arrow);
      }
      // Check if level is complete
      if (_currentLevel?.isLevelComplete ?? false) {
        // Level completed - move to next difficulty
        nextDifficulty();
        setLevel(_generator.generate(
          difficulty: _currentDifficulty,
          seed: _currentSeed,
        ));
      } else {
        setLevel(_currentLevel!);
      }
    } else {
      // Arrow blocked - apply penalty (lose life)
      _lives--;
      _selectedArrow = null;
      if (_lives <= 0) {
        // Game over - could show dialog
      }
    }
  }

  bool _checkEscapeCorridor(ArrowPath arrow) {
    // Check if the arrow's forward escape corridor is clear
    final dir = arrow.direction;
    final endpoint = arrow.endpoint;

    // Safety margin: > 2.5 * thickness
    final safetyMargin = 2.5 * arrow.thickness;

    for (final otherArrow in _currentLevel?.arrows ?? []) {
      if (otherArrow.id == arrow.id) continue;

      // Check if other arrow blocks the escape corridor
      if (_isBlockedBy(otherArrow, dir, endpoint, safetyMargin)) {
        return false;
      }
    }

    // Check boundaries (status bar, top controls, bottom tools, ad container)
    if (_isBlockedByBoardBoundary(arrow)) {
      return false;
    }

    return true;
  }

  bool _isBlockedBy(ArrowPath other, Direction dir, GridPoint endpoint, double margin) {
    // Check if another arrow blocks the escape corridor
    for (final point in other.points) {
      final dx = point.x - endpoint.x;
      final dy = point.y - endpoint.y;

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
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < margin) return true;
      }
    }
    return false;
  }

  bool _isBlockedByBoardBoundary(ArrowPath arrow) {
    // Check if arrow's escape corridor touches status bar, controls, etc.
    // In the reference composition, arrows should not touch:
    // * status bar
    // * top controls
    // * bottom tools
    // * ad container

    final dir = arrow.direction;
    final endpoint = arrow.endpoint;

    // Check if arrow would escape through a forbidden area
    // This is a simplified check - full implementation would consider board layout
    return false;
  }

  void undo() {
    if (_history.isEmpty) return;

    final previousState = _history.removeLast();
    _currentLevel = previousState;
    _moveCount = _history.length;
    _selectedArrow = null;
  }

  void showHint() {
    if (_currentLevel != null) {
      final solver = LevelSolver(level: _currentLevel!);
      final solution = solver.solve();
      if (solution.isNotEmpty) {
        // Highlight the first recommended arrow
        final recommendedArrow = solution.first;
        // In a full implementation, this would trigger a visual highlight
        // and optionally show a path preview
      }
    }
  }

  /// Get available arrows that can be selected and potentially escaped
  List<ArrowPath> getAvailableArrows() {
    if (_currentLevel == null) return [];
    return _currentLevel!.getAvailableArrows();
  }

  /// Get the quality score for the current level
  int getQualityScore() {
    if (_currentLevel == null) return 0;
    return _currentLevel!.qualityScore;
  }

  /// Get the current difficulty classification
  String getDifficultyClassification() {
    final score = getQualityScore();
    final arrowCount = _currentLevel?.arrows.length ?? 0;

    if (arrowCount <= 8 && score < 30) return 'Easy';
    if (arrowCount <= 18 && score < 50) return 'Normal';
    if (arrowCount <= 26 && score < 70) return 'Medium';
    if (arrowCount <= 35 && score < 85) return 'Hard';
    return 'Expert';
  }
}