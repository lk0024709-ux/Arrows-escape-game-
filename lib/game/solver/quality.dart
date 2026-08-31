import '../generator/difficulty_params.dart';

/// Puzzle quality score (prompt §51).
///
/// ```
/// quality = solutionDepth + dependencyComplexity + branching
///         + pathComplexity + spatialDensity + size + decoys − trivialMoves
/// ```
/// normalised to `0..100`, then mapped to a **measured** difficulty label
/// (prompt §29 — never derived from the arrow count alone).
///
/// Thresholds were calibrated against the measured distribution of the
/// generator (see `docs/GENERATOR.md`).
class QualityReport {
  const QualityReport({
    required this.score,
    required this.label,
    required this.components,
  });

  /// 0..100
  final double score;

  /// Easy / Normal / Medium / Hard / Expert.
  final String label;

  final Map<String, double> components;

  @override
  String toString() =>
      'QualityReport(${score.toStringAsFixed(1)}, $label, $components)';
}

class QualityScorer {
  const QualityScorer._();

  static QualityReport score({
    required int arrowCount,
    required int dependencyDepth,
    required int edgeCount,
    required double averageBranching,
    required int decoyCount,
    required double averageTurns,
    required double density,
    required int rootCount,
    required int forcedSteps,
    required int totalSteps,
  }) {
    final size = _norm(arrowCount / 30.0);
    final depth = _norm(dependencyDepth / 6.0);
    final dependencies =
        _norm(arrowCount == 0 ? 0 : edgeCount / (arrowCount * 1.5));
    final branching = _norm((averageBranching - 1.0) / 3.0);
    final paths = _norm(averageTurns / 3.0);
    final space = _norm(density / 0.55);
    final decoys = _norm(arrowCount == 0 ? 0 : decoyCount / (arrowCount * 0.45));
    final trivial =
        totalSteps == 0 ? 1.0 : _norm(forcedSteps / totalSteps);

    final components = <String, double>{
      'size': size,
      'solutionDepth': depth,
      'dependencyComplexity': dependencies,
      'branching': branching,
      'pathComplexity': paths,
      'spatialDensity': space,
      'decoys': decoys,
      'triviality': trivial,
    };

    final raw = 16 * size +
        18 * depth +
        16 * dependencies +
        13 * branching +
        11 * paths +
        10 * space +
        8 * decoys -
        16 * trivial;

    // A board where nothing blocks anything is never a puzzle.
    final floor = rootCount >= arrowCount ? 0.0 : 6.0;

    final value = _clamp(raw + floor, 0, 100);
    return QualityReport(
      score: value,
      label: labelFor(value),
      components: components,
    );
  }

  static String labelFor(double score) {
    if (score < 32) return 'Easy';
    if (score < 50) return 'Normal';
    if (score < 64) return 'Medium';
    if (score < 76) return 'Hard';
    return 'Expert';
  }

  /// Acceptable score window for a difficulty band (calibrated empirically).
  static (double, double) bandRange(int band) => switch (band) {
        DifficultyBand.easy => (0.0, 34.0),
        DifficultyBand.normal => (26.0, 52.0),
        DifficultyBand.medium => (45.0, 66.0),
        DifficultyBand.hard => (54.0, 76.0),
        _ => (62.0, 100.0),
      };

  static double bandCenter(int band) {
    final r = bandRange(band);
    return (r.$1 + r.$2) / 2;
  }

  static double _norm(double v) => _clamp(v, 0, 1);

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);
}
