import 'package:flutter/material.dart';

import '../geometry/arrow_path.dart';
import '../level/difficulty.dart';
import '../level/level.dart';
import '../level/level_generator.dart';
import '../level/level_solver.dart';

/// A board plus the move count that belonged to it, so undo restores both.
class _Snapshot {
  final Level level;
  final int moveCount;

  const _Snapshot(this.level, this.moveCount);
}

/// Owns the run: current board, selection, moves, lives and undo history.
class GameManager {
  static const int startingLives = 3;

  DifficultyLevel _currentDifficulty = DifficultyLevel.normal;
  int _currentSeed = DateTime.now().millisecondsSinceEpoch;
  int _moveCount = 0;
  int _lives = startingLives;
  Level? _currentLevel;
  ArrowPath? _selectedArrow;
  String? _hintArrowId;

  final List<_Snapshot> _history = [];
  final LevelGenerator _generator;

  GameManager({LevelGenerator? generator})
      : _generator = generator ?? LevelGenerator() {
    _resetMoveCount();
  }

  int get moveCount => _moveCount;
  int get lives => _lives;
  bool get isGameOver => _lives <= 0;
  DifficultyLevel get currentDifficulty => _currentDifficulty;
  int get currentSeed => _currentSeed;
  Level? get currentLevel => _currentLevel;
  ArrowPath? get selectedArrow => _selectedArrow;
  String? get hintArrowId => _hintArrowId;
  bool get canUndo => _history.isNotEmpty;

  void _resetMoveCount() {
    _moveCount = 0;
    _history.clear();
    _hintArrowId = null;
  }

  void setLevel(Level level) {
    _currentLevel = level;
    _selectedArrow = null;
    _hintArrowId = null;
    _moveCount = 0;
    _history.clear();
    _lives = startingLives;
  }

  /// Start a fresh board on [difficulty].
  void startLevel(DifficultyLevel difficulty) {
    _currentDifficulty = difficulty;
    _currentSeed = DateTime.now().millisecondsSinceEpoch;
    setLevel(_generator.generate(difficulty: difficulty, seed: _currentSeed));
  }

  void nextDifficulty() {
    final values = DifficultyLevel.values;
    final next = values[(_currentDifficulty.index + 1) % values.length];
    startLevel(next);
  }

  void prevDifficulty() {
    final values = DifficultyLevel.values;
    final prev = values[(_currentDifficulty.index - 1 + values.length) % values.length];
    startLevel(prev);
  }

  /// Rebuild the board for the same difficulty with a new seed.
  void regenerateLevel() {
    startLevel(_currentDifficulty);
  }

  void onArrowSelected(ArrowPath arrow) {
    if (_currentLevel == null || isGameOver) return;
    if (_currentLevel!.getArrowById(arrow.id) == null) {
      // Tapped empty space: clear the selection without spending a move.
      _selectedArrow = null;
      return;
    }

    // Record state before selection for undo
    _history.add(_Snapshot(_currentLevel!.copyWithSelectedArrow(null), _moveCount));
    _selectedArrow = arrow;
    _currentLevel!.setSelectedArrowIndex(_currentLevel!.arrows.indexOf(arrow));
    // Increment move count when player actively selects an arrow
    _moveCount++;
    _hintArrowId = null;
  }

  void onArrowReleased(ArrowPath arrow) {
    if (_selectedArrow?.id == arrow.id) {
      _executeArrow(arrow);
      _selectedArrow = null;
    }
  }

  void _executeArrow(ArrowPath arrow) {
    final level = _currentLevel;
    if (level == null) return;

    if (_checkEscapeCorridor(arrow)) {
      arrow.isEscaping = true;
      level.removeArrow(arrow);
      _currentLevel = level;
      _selectedArrow = null;
      _hintArrowId = null;

      // The screen observes the emptied board and decides when to advance to
      // the next level, so progression (level number, God/Boss tiers) stays in
      // one place instead of being hard-wired to a difficulty bump here.
    } else {
      // Arrow blocked - apply penalty (lose life)
      _lives--;
      _selectedArrow = null;
      level.clearSelectedArrow();
    }
  }

  /// An arrow escapes when nothing sits in its forward corridor.
  bool _checkEscapeCorridor(ArrowPath arrow) {
    final level = _currentLevel;
    if (level == null) return false;
    if (_isBlockedByBoardBoundary(arrow)) return false;
    return LevelSolver(level: level).canEscape(arrow);
  }

  /// Arrows may not escape through the status bar, top controls, bottom tools
  /// or the ad container. The board grid already stops one cell short of those
  /// chrome areas, so an arrow whose head is still inside the grid always has
  /// somewhere to run; only an arrow parked outside the grid is rejected.
  bool _isBlockedByBoardBoundary(ArrowPath arrow) {
    final grid = _currentLevel?.grid;
    if (grid == null) return true;
    return !grid.inBoundsPoint(arrow.endpoint);
  }

  /// Lose a single life without an arrow, e.g. when a God/Boss level timer
  /// expires. Clamped at zero so it can never go negative.
  void loseLife() {
    if (_lives > 0) _lives--;
  }

  void undo() {
    if (_history.isEmpty) return;

    final previous = _history.removeLast();
    _currentLevel = previous.level;
    _moveCount = previous.moveCount;
    _selectedArrow = null;
    _hintArrowId = null;
  }

  /// Picks an arrow that can escape right now and marks it as the hint.
  void showHint() {
    final level = _currentLevel;
    if (level == null) return;

    final solution = LevelSolver(level: level).solve();
    if (solution.isEmpty) return;

    _hintArrowId = solution.first.id;
  }

  /// Get available arrows that can be selected and potentially escaped
  List<ArrowPath> getAvailableArrows() {
    final level = _currentLevel;
    if (level == null) return [];
    return level.getAvailableArrows();
  }

  /// Get the quality score for the current level
  int getQualityScore() => _currentLevel?.qualityScore ?? 0;

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

  /// Badge colour matching [getDifficultyClassification].
  Color getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Colors.green.shade100;
      case 'Normal':
        return Colors.blue.shade100;
      case 'Medium':
        return Colors.orange.shade100;
      case 'Hard':
        return Colors.red.shade100;
      case 'Expert':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}
