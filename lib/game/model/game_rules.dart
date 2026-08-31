/// How an arrow behaves when the player taps it.
enum TravelMode {
  /// The arrow travels forward until it leaves the board, or until it comes to
  /// rest flush against the first arrow in its way.
  ///
  /// This is the default: it is what turns the board into a real puzzle. A
  /// partial slide changes the geometry, so a careless tap *can* dead-lock the
  /// board — which is exactly what makes decoy moves matter (prompt §21).
  continuous,

  /// Legacy "all or nothing" mode: the arrow only moves when its complete
  /// escape corridor is clear.
  escapeOnly,
}

/// What happens when the player taps an arrow that cannot move at all.
enum BlockedTapPolicy {
  /// Shake + haptic feedback only. No penalty.
  ignore,

  /// Shake + haptic + the move counter is incremented.
  countAsMove,

  /// Shake + haptic + one life is lost (hard difficulties).
  loseLife,
}

/// Fully configurable rule set. Nothing here is hard-coded inside the physics
/// engine (prompt §28 — lives must not leak into the physics core).
class GameRules {
  const GameRules({
    this.travelMode = TravelMode.continuous,
    this.blockedTapPolicy = BlockedTapPolicy.ignore,
    this.lives = 3,
    this.hints = 2,
    this.requireUniqueSolution = false,
    this.minimumQualityScore = 0,
    this.parSlack = 3,
  });

  final TravelMode travelMode;
  final BlockedTapPolicy blockedTapPolicy;

  /// Starting lives (configurable — prompt §28).
  final int lives;

  /// Starting hints (prompt §31).
  final int hints;

  /// Generator option (prompt §50).
  final bool requireUniqueSolution;

  /// Generator option: reject generated levels below this quality score.
  final double minimumQualityScore;

  /// How many extra moves over the optimal solution still earn 3 stars.
  final int parSlack;

  GameRules copyWith({
    TravelMode? travelMode,
    BlockedTapPolicy? blockedTapPolicy,
    int? lives,
    int? hints,
    bool? requireUniqueSolution,
    double? minimumQualityScore,
    int? parSlack,
  }) =>
      GameRules(
        travelMode: travelMode ?? this.travelMode,
        blockedTapPolicy: blockedTapPolicy ?? this.blockedTapPolicy,
        lives: lives ?? this.lives,
        hints: hints ?? this.hints,
        requireUniqueSolution: requireUniqueSolution ?? this.requireUniqueSolution,
        minimumQualityScore: minimumQualityScore ?? this.minimumQualityScore,
        parSlack: parSlack ?? this.parSlack,
      );

  Map<String, dynamic> toJson() => {
        'travelMode': travelMode.name,
        'blockedTapPolicy': blockedTapPolicy.name,
        'lives': lives,
        'hints': hints,
        'requireUniqueSolution': requireUniqueSolution,
        'minimumQualityScore': minimumQualityScore,
        'parSlack': parSlack,
      };

  factory GameRules.fromJson(Map<String, dynamic> json) => GameRules(
        travelMode: TravelMode.values.firstWhere(
          (e) => e.name == json['travelMode'],
          orElse: () => TravelMode.continuous,
        ),
        blockedTapPolicy: BlockedTapPolicy.values.firstWhere(
          (e) => e.name == json['blockedTapPolicy'],
          orElse: () => BlockedTapPolicy.ignore,
        ),
        lives: (json['lives'] as num?)?.toInt() ?? 3,
        hints: (json['hints'] as num?)?.toInt() ?? 2,
        requireUniqueSolution: json['requireUniqueSolution'] as bool? ?? false,
        minimumQualityScore:
            (json['minimumQualityScore'] as num?)?.toDouble() ?? 0,
        parSlack: (json['parSlack'] as num?)?.toInt() ?? 3,
      );
}
