import 'dart:async';

import '../../level/difficulty.dart';
import '../../level/level.dart';
import '../../level/level_generator.dart';

/// Loads levels for gameplay with a safety timeout and a guaranteed fallback,
/// so an async level fetch can never hang the UI.
class LevelRepository {
  LevelRepository({LevelGenerator? generator})
      : _generator = generator ?? LevelGenerator();

  final LevelGenerator _generator;

  /// How long `getLevelAsync` will wait before falling back.
  static const Duration defaultTimeout = Duration(seconds: 3);

  int _seedCounter = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

  /// Builds a level for [difficulty].
  ///
  /// The generator itself is synchronous and deterministic, but this method
  /// presents it through an async boundary so a future remote/hand-made level
  /// source can be swapped in without changing callers. A [timeout] guards
  /// against any source that never completes, and on timeout or error we
  /// return a freshly generated board rather than throwing.
  Future<Level> getLevelAsync({
    required DifficultyLevel difficulty,
    Duration timeout = defaultTimeout,
  }) async {
    try {
      return await _generateWithTimeout(difficulty: difficulty, timeout: timeout);
    } on TimeoutException {
      return _generateFallback(difficulty);
    } catch (_) {
      return _generateFallback(difficulty);
    }
  }

  Future<Level> _generateWithTimeout({
    required DifficultyLevel difficulty,
    required Duration timeout,
  }) {
    // Completing synchronously inside a Future constructor still goes through
    // the microtask queue, which is what `.timeout` needs to observe.
    return Future<Level>(
      () => _generator.generate(
        difficulty: difficulty,
        seed: _nextSeed(),
      ),
    ).timeout(timeout);
  }

  /// A fresh deterministic board used when the primary path misbehaves.
  Level _generateFallback(DifficultyLevel difficulty) {
    return _generator.generate(
      difficulty: difficulty,
      seed: _nextSeed(),
    );
  }

  int _nextSeed() {
    _seedCounter = (_seedCounter + 1) & 0x7fffffff;
    return _seedCounter;
  }
}
