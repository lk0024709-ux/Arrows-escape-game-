import 'package:flutter/foundation.dart';

import '../generator/dependency_graph.dart';
import '../geometry/arrow_geometry.dart';
import '../model/board_state.dart';
import '../model/game_rules.dart';
import '../model/level.dart';
import '../model/path_arrow.dart';
import '../physics/physics_engine.dart';
import '../solver/solver.dart';
import '../../core/math/vector2.dart';

/// High level game status.
enum GameStatus { playing, won, lost, stuck }

/// What a tap produced.
enum MoveKind { escape, slide, blocked }

/// Outcome of a player action.
class MoveResult {
  const MoveResult({
    required this.kind,
    required this.arrowIndex,
    required this.evaluation,
  });

  final MoveKind kind;
  final int arrowIndex;
  final MoveEvaluation evaluation;

  bool get wasBlocked => kind == MoveKind.blocked;
}

/// A running escape animation (presentation only — the logic has already
/// committed the move, see prompt §39).
class MoveAnimation {
  MoveAnimation({
    required this.arrowIndex,
    required this.arrow,
    required this.from,
    required this.to,
    required this.durationMs,
    required this.escapes,
    required this.startedAt,
  });

  final int arrowIndex;
  final PathArrow arrow;
  final double from;
  final double to;
  final int durationMs;
  final bool escapes;
  final DateTime startedAt;

  double progress(DateTime now) {
    final elapsed = now.difference(startedAt).inMicroseconds / 1000.0;
    if (elapsed <= 0) return 0;
    if (elapsed >= durationMs) return 1;
    return elapsed / durationMs;
  }

  bool isDone(DateTime now) =>
      now.difference(startedAt).inMilliseconds >= durationMs;
}

/// The gameplay state machine (prompt §26–§32, §39).
///
/// Extends [ChangeNotifier] so the UI can rebuild without any external state
/// management dependency.
class GameController extends ChangeNotifier {
  GameController({
    required Level level,
    GameRules? rules,
    PhysicsEngine? physics,
    Solver? solver,
  })  : _level = level,
        _rules = rules ?? level.rules,
        _physics = physics ?? PhysicsEngine(rules: rules ?? level.rules),
        _solver = solver ?? Solver(mode: SolverMode.greedy, maxNodes: 4000) {
    reset();
  }

  Level _level;
  final GameRules _rules;
  final PhysicsEngine _physics;
  final Solver _solver;

  late BoardState _state;
  late int _moves;
  late int _lives;
  late int _hints;
  late int _escapes;
  late int _slides;
  late int _invalidTaps;
  late GameStatus _status;
  late DateTime _startedAt;
  late List<_HistoryEntry> _history;
  late List<MoveAnimation> _animations;
  int? _selectedIndex;
  int? _blockedIndex;
  DateTime? _blockedAt;
  int? _hintIndex;

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  Level get level => _level;
  GameRules get rules => _rules;
  PhysicsEngine get physics => _physics;
  BoardState get state => _state;
  int get moves => _moves;
  int get lives => _lives;
  int get hints => _hints;
  int get escapes => _escapes;
  int get slides => _slides;
  int get invalidTaps => _invalidTaps;
  int get remaining => _state.remaining;
  int? get selectedIndex => _selectedIndex;
  int? get blockedIndex => _blockedIndex;
  DateTime? get blockedAt => _blockedAt;
  int? get hintIndex => _hintIndex;

  /// Selection is presentation only: it never changes the puzzle state.
  set selectedIndex(int? value) {
    if (_selectedIndex == value) return;
    _selectedIndex = value;
    notifyListeners();
  }
  GameStatus get status => _status;
  List<MoveAnimation> get animations => List.unmodifiable(_animations);

  bool get isOver => _status == GameStatus.won || _status == GameStatus.lost;
  bool get isWon => _status == GameStatus.won;
  bool get isStuck => _status == GameStatus.stuck;
  bool get canUndo => _history.isNotEmpty;
  bool get hasActiveAnimations =>
      _animations.any((a) => !a.isDone(DateTime.now()));

  /// Par: one move per arrow plus the configured slack (prompt §52).
  int get par => _level.arrowCount + _rules.parSlack;

  /// 3 stars at par, 2 within 1.6× par, otherwise 1.
  int starsFor([int? moves]) {
    final used = moves ?? _moves;
    if (used <= par) return 3;
    if (used <= (par * 1.6).ceil()) return 2;
    return 1;
  }

  Duration get elapsed => DateTime.now().difference(_startedAt);

  set level(Level value) {
    _level = value;
    reset();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  void reset() {
    _state = _level.initialState;
    _moves = 0;
    _lives = _rules.lives;
    _hints = _rules.hints;
    _escapes = 0;
    _slides = 0;
    _invalidTaps = 0;
    _status = GameStatus.playing;
    _startedAt = DateTime.now();
    _history = <_HistoryEntry>[];
    _animations = <MoveAnimation>[];
    _selectedIndex = null;
    _blockedIndex = null;
    _blockedAt = null;
    _hintIndex = null;
    notifyListeners();
  }

  void restart() {
    reset();
  }

  /// Restart after running out of moves: costs a life.
  void restartWithPenalty() {
    final lives = _lives;
    reset();
    _lives = lives - 1;
    if (_lives <= 0) {
      _lives = 0;
      _status = GameStatus.lost;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Queries (all delegate to the shared physics core)
  // ---------------------------------------------------------------------------

  BoardCollisionIndex get collisionIndex => BoardCollisionIndex(_level, _state);

  MoveEvaluation evaluate(int arrowIndex) =>
      _physics.evaluate(collisionIndex, arrowIndex);

  List<MoveEvaluation> evaluateAll() =>
      _physics.evaluateAll(collisionIndex);

  int get availableEscapes =>
      evaluateAll().where((e) => e.canMove && e.escapes).length;

  int get decoyCount => evaluateAll().where((e) => e.isDecoy).length;

  int get blockedCount => evaluateAll().where((e) => !e.canMove).length;

  bool get hasAnyMove => evaluateAll().any((e) => e.canMove);

  /// Which arrow is under [worldPoint]? Uses the physics geometry (prompt §34).
  int? hitTest(Vec2 worldPoint, {double tolerance = 0.35}) {
    final index = collisionIndex;
    int? best;
    var bestArea = double.infinity;
    for (final i in index.activeIndices) {
      for (final part in index.partsOf(i)) {
        if (worldPoint.x >= part.left - tolerance &&
            worldPoint.x <= part.right + tolerance &&
            worldPoint.y >= part.top - tolerance &&
            worldPoint.y <= part.bottom + tolerance) {
          final area = part.area;
          if (area < bestArea) {
            bestArea = area;
            best = i;
          }
        }
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Commit a player action on [arrowIndex].
  MoveResult? tapArrow(int arrowIndex) {
    if (isOver) return null;
    if (_state.isRemovedAt(arrowIndex)) return null;

    final index = collisionIndex;
    final evaluation = _physics.evaluate(index, arrowIndex);

    if (!evaluation.canMove) {
      _blockedIndex = arrowIndex;
      _blockedAt = DateTime.now();
      _invalidTaps++;
      switch (_rules.blockedTapPolicy) {
        case BlockedTapPolicy.ignore:
          break;
        case BlockedTapPolicy.countAsMove:
          _moves++;
        case BlockedTapPolicy.loseLife:
          _loseLife();
      }
      notifyListeners();
      return MoveResult(
        kind: MoveKind.blocked,
        arrowIndex: arrowIndex,
        evaluation: evaluation,
      );
    }

    _history.add(
      _HistoryEntry(
        state: _state,
        moves: _moves,
        escapes: _escapes,
        slides: _slides,
      ),
    );
    if (_history.length > 256) _history.removeAt(0);

    final from = _state.offsetAt(arrowIndex);
    _state = _physics.applyMove(index, arrowIndex, evaluation);
    _moves++;
    _selectedIndex = arrowIndex;
    _hintIndex = null;

    if (evaluation.escapes) {
      _escapes++;
    } else {
      _slides++;
    }
    _animations.add(
      MoveAnimation(
        arrowIndex: arrowIndex,
        arrow: _level.arrows[arrowIndex],
        from: from,
        to: from + evaluation.travel,
        durationMs: _durationFor(evaluation.travel, escapes: evaluation.escapes),
        escapes: evaluation.escapes,
        startedAt: DateTime.now(),
      ),
    );

    if (_state.isSolved) {
      _status = GameStatus.won;
    } else if (!hasAnyMove) {
      _status = GameStatus.stuck;
    }
    notifyListeners();
    return MoveResult(
      kind: evaluation.escapes ? MoveKind.escape : MoveKind.slide,
      arrowIndex: arrowIndex,
      evaluation: evaluation,
    );
  }

  /// Prompt §38: 0–80 ms anticipation, 80–350 ms acceleration, 350–650 ms exit.
  int _durationFor(double travel, {required bool escapes}) {
    if (!escapes) return (travel * 18 + 140).round().clamp(180, 340);
    return (travel * 26 + 220).round().clamp(260, 700);
  }

  /// Hint: the next arrow of the canonical solution (prompt §31).
  int? requestHint() {
    if (_hints <= 0 || isOver) return null;
    final graph = DependencyGraph.compute(_level, _state);
    final solution = _solver.greedySolve(
      _level,
      from: _state,
      preferredOrder: graph.topologicalEscapeOrder(),
    );
    if (solution == null || solution.moves.isEmpty) return null;
    _hints--;
    _hintIndex = solution.moves.first.arrowIndex;
    notifyListeners();
    return _hintIndex;
  }

  bool undo() {
    if (_history.isEmpty) return false;
    final previous = _history.removeLast();
    _state = previous.state;
    _moves = previous.moves;
    _escapes = previous.escapes;
    _slides = previous.slides;
    _animations = <MoveAnimation>[];
    _status = GameStatus.playing;
    _hintIndex = null;
    notifyListeners();
    return true;
  }

  void _loseLife() {
    _lives = _lives > 0 ? _lives - 1 : 0;
    if (_lives == 0 && _status != GameStatus.won) {
      _status = GameStatus.lost;
    }
  }

  // ---------------------------------------------------------------------------
  // Presentation helpers
  // ---------------------------------------------------------------------------

  /// Current (animated) offset of an arrow, for the painter.
  double offsetFor(int arrowIndex, {DateTime? now}) {
    final base = _state.offsetAt(arrowIndex);
    for (final animation in _animations.reversed) {
      if (animation.arrowIndex != arrowIndex) continue;
      final progress = animation.progress(now ?? DateTime.now());
      final eased = 1 - pow3(1 - progress);
      return animation.from + (animation.to - animation.from) * eased;
    }
    return base;
  }

  static double pow3(double v) => v * v * v;

  /// Drops finished animations.
  void pruneAnimations({DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (_animations.isEmpty) return;
    _animations = _animations.where((a) => !a.isDone(reference)).toList();
  }

  /// Debug summary (prompt §56).
  String debugSummary() {
    final graph = DependencyGraph.compute(_level, _state);
    final analysis = _level.analysis;
    return [
      'levelId      ${_level.levelId}',
      'seed         ${_level.seed}',
      'generator    v${_level.generatorVersion}',
      'grid         ${_level.gridCols} x ${_level.gridRows}',
      'arrows       ${_level.arrowCount} ($remaining left)',
      'quality      ${analysis == null ? '—' : analysis.qualityScore.toStringAsFixed(1)}',
      'difficulty   ${analysis?.difficultyLabel ?? '—'}',
      'solution     ${analysis?.optimalSolutionLength ?? 0} moves',
      'dependency   depth ${graph.depth}, roots ${graph.rootCount}, edges ${graph.edgeCount}',
      'position     ${availableEscapes} escape, ${decoyCount} decoy, ${blockedCount} stuck',
      'moves        $_moves (par $par, invalid $_invalidTaps)',
    ].join('\n');
  }
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.state,
    required this.moves,
    required this.escapes,
    required this.slides,
  });

  final BoardState state;
  final int moves;
  final int escapes;
  final int slides;
}
