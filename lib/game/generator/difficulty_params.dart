/// Numeric difficulty bands (1 = Easy … 5 = Expert).
class DifficultyBand {
  static const int easy = 1;
  static const int normal = 2;
  static const int medium = 3;
  static const int hard = 4;
  static const int expert = 5;

  static String labelOf(int band) => switch (band) {
        easy => 'Easy',
        normal => 'Normal',
        medium => 'Medium',
        hard => 'Hard',
        _ => 'Expert',
      };

  static int fromLabel(String label) => switch (label.toLowerCase()) {
        'easy' => easy,
        'normal' => normal,
        'medium' => medium,
        'hard' => hard,
        'expert' => expert,
        _ => normal,
      };
}

/// Everything the generator tunes per difficulty (prompt §22, §23).
class DifficultyParams {
  const DifficultyParams({
    required this.band,
    required this.gridCols,
    required this.gridRows,
    required this.arrowMin,
    required this.arrowMax,
    required this.segmentMin,
    required this.segmentMax,
    required this.segmentLengthMin,
    required this.segmentLengthMax,
    required this.targetRoots,
    required this.maxRoots,
    required this.maxBlockersPerArrow,
    required this.blockBias,
    required this.lives,
    required this.hints,
    required this.minQualityScore,
    this.turnBias = 0.5,
  });

  final int band;
  final int gridCols;
  final int gridRows;
  final int arrowMin;
  final int arrowMax;

  /// Number of straight segments per path (1 = straight, 2 = L, 3 = U/Z …).
  final int segmentMin;
  final int segmentMax;

  /// Length of a single segment, in grid cells.
  final int segmentLengthMin;
  final int segmentLengthMax;

  /// How many arrows should be free at the very first move.
  final int targetRoots;
  final int maxRoots;

  /// Cap on how many arrows may block a single arrow.
  final int maxBlockersPerArrow;

  /// Weight that pushes the generator towards creating dependencies.
  final double blockBias;

  final int lives;
  final int hints;

  /// Reject generated levels below this measured quality score.
  final double minQualityScore;

  /// Probability of turning clockwise at each junction (0.5 = neutral).
  final double turnBias;

  int get maxArrows => arrowMax;

  double get aspect => gridCols / gridRows;

  /// Band defaults (prompt §22/§23).
  factory DifficultyParams.forBand(int band) => switch (band) {
        DifficultyBand.easy => const DifficultyParams(
            band: DifficultyBand.easy,
            gridCols: 8,
            gridRows: 10,
            arrowMin: 5,
            arrowMax: 8,
            segmentMin: 1,
            segmentMax: 2,
            segmentLengthMin: 2,
            segmentLengthMax: 5,
            targetRoots: 2,
            maxRoots: 6,
            maxBlockersPerArrow: 2,
            blockBias: 0.6,
            lives: 5,
            hints: 3,
            minQualityScore: 0,
          ),
        DifficultyBand.normal => const DifficultyParams(
            band: DifficultyBand.normal,
            gridCols: 9,
            gridRows: 12,
            arrowMin: 8,
            arrowMax: 13,
            segmentMin: 1,
            segmentMax: 3,
            segmentLengthMin: 2,
            segmentLengthMax: 5,
            targetRoots: 2,
            maxRoots: 9,
            maxBlockersPerArrow: 2,
            blockBias: 0.75,
            lives: 4,
            hints: 3,
            minQualityScore: 8,
          ),
        DifficultyBand.medium => const DifficultyParams(
            band: DifficultyBand.medium,
            gridCols: 11,
            gridRows: 15,
            arrowMin: 12,
            arrowMax: 17,
            segmentMin: 2,
            segmentMax: 3,
            segmentLengthMin: 2,
            segmentLengthMax: 4,
            targetRoots: 3,
            maxRoots: 12,
            maxBlockersPerArrow: 3,
            blockBias: 0.85,
            lives: 3,
            hints: 2,
            minQualityScore: 18,
          ),
        DifficultyBand.hard => const DifficultyParams(
            band: DifficultyBand.hard,
            gridCols: 13,
            gridRows: 19,
            arrowMin: 18,
            arrowMax: 25,
            segmentMin: 2,
            segmentMax: 4,
            segmentLengthMin: 2,
            segmentLengthMax: 5,
            targetRoots: 3,
            maxRoots: 17,
            maxBlockersPerArrow: 3,
            blockBias: 0.95,
            lives: 3,
            hints: 2,
            minQualityScore: 32,
          ),
        _ => const DifficultyParams(
            band: DifficultyBand.expert,
            gridCols: 14,
            gridRows: 22,
            arrowMin: 26,
            arrowMax: 34,
            segmentMin: 2,
            segmentMax: 5,
            segmentLengthMin: 2,
            segmentLengthMax: 5,
            targetRoots: 4,
            maxRoots: 24,
            maxBlockersPerArrow: 4,
            blockBias: 1.0,
            lives: 3,
            hints: 1,
            minQualityScore: 46,
          ),
      };

  /// Smooth ramp used for the 50 level campaign (prompt §52) and for endless
  /// mode (prompt §53), where difficulty grows without bound.
  factory DifficultyParams.forLevelIndex(int index) {
    if (index <= 10) return DifficultyParams.forBand(DifficultyBand.easy);
    if (index <= 20) return DifficultyParams.forBand(DifficultyBand.normal);
    if (index <= 30) return DifficultyParams.forBand(DifficultyBand.medium);
    if (index <= 40) return DifficultyParams.forBand(DifficultyBand.hard);
    return DifficultyParams.forBand(DifficultyBand.expert);
  }

  DifficultyParams copyWith({
    int? gridCols,
    int? gridRows,
    int? arrowMin,
    int? arrowMax,
    int? targetRoots,
    double? blockBias,
    double? minQualityScore,
  }) =>
      DifficultyParams(
        band: band,
        gridCols: gridCols ?? this.gridCols,
        gridRows: gridRows ?? this.gridRows,
        arrowMin: arrowMin ?? this.arrowMin,
        arrowMax: arrowMax ?? this.arrowMax,
        segmentMin: segmentMin,
        segmentMax: segmentMax,
        segmentLengthMin: segmentLengthMin,
        segmentLengthMax: segmentLengthMax,
        targetRoots: targetRoots ?? this.targetRoots,
        maxRoots: maxRoots,
        maxBlockersPerArrow: maxBlockersPerArrow,
        blockBias: blockBias ?? this.blockBias,
        lives: lives,
        hints: hints,
        minQualityScore: minQualityScore ?? this.minQualityScore,
        turnBias: turnBias,
      );

  Map<String, dynamic> toJson() => {
        'band': band,
        'gridCols': gridCols,
        'gridRows': gridRows,
        'arrowMin': arrowMin,
        'arrowMax': arrowMax,
        'segmentMin': segmentMin,
        'segmentMax': segmentMax,
        'segmentLengthMin': segmentLengthMin,
        'segmentLengthMax': segmentLengthMax,
        'targetRoots': targetRoots,
        'maxRoots': maxRoots,
        'maxBlockersPerArrow': maxBlockersPerArrow,
        'blockBias': blockBias,
        'lives': lives,
        'hints': hints,
        'minQualityScore': minQualityScore,
        'turnBias': turnBias,
      };
}
