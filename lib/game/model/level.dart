import '../../core/geometry/geometry.dart';
import 'arrow_theme_metrics.dart';
import 'board_state.dart';
import 'game_rules.dart';
import 'path_arrow.dart';

/// A complete, self-describing playable level (prompt §54).
class Level {
  Level({
    required this.levelId,
    required this.seed,
    required this.difficulty,
    required this.gridCols,
    required this.gridRows,
    required this.arrows,
    this.metrics = const ArrowMetrics(),
    this.rules = const GameRules(),
    this.analysis,
    this.generatorVersion = LevelGeneratorVersion.current,
    this.boundsPadding = 1.0,
    this.title,
  });

  final String levelId;
  final int seed;

  /// Requested difficulty band (1..5). The *measured* difficulty lives in
  /// [analysis] and may differ — prompt §29.
  final int difficulty;

  final int gridCols;
  final int gridRows;
  final List<PathArrow> arrows;
  final ArrowMetrics metrics;
  final GameRules rules;

  /// Measured metrics (filled in by the generator / solver).
  final LevelAnalysis? analysis;

  /// Bumped whenever the generator algorithm changes, so that cached levels can
  /// be invalidated (prompt §54).
  final int generatorVersion;

  /// World-space margin around the outermost grid nodes.
  final double boundsPadding;

  final String? title;

  int get arrowCount => arrows.length;

  Iterable<PathArrow> activeArrows(BoardState state) sync* {
    for (var i = 0; i < arrows.length; i++) {
      if (!state.isRemovedAt(i)) yield arrows[i];
    }
  }

  /// World-space rectangle that the player perceives as "the board".
  /// An arrow has escaped once its bounding box no longer intersects it.
  Aabb get playBounds => Aabb(
        -boundsPadding,
        -boundsPadding,
        gridCols - 1 + boundsPadding,
        gridRows - 1 + boundsPadding,
      );

  /// Rectangle of the logical construction grid itself (nodes 0..cols-1).
  Aabb get gridBounds =>
      Aabb(0, 0, (gridCols - 1).toDouble(), (gridRows - 1).toDouble());

  BoardState get initialState => BoardState.initial(arrows.length);

  Level copyWith({
    List<PathArrow>? arrows,
    LevelAnalysis? analysis,
    GameRules? rules,
    ArrowMetrics? metrics,
    String? title,
    int? difficulty,
  }) =>
      Level(
        levelId: levelId,
        seed: seed,
        difficulty: difficulty ?? this.difficulty,
        gridCols: gridCols,
        gridRows: gridRows,
        arrows: arrows ?? this.arrows,
        metrics: metrics ?? this.metrics,
        rules: rules ?? this.rules,
        analysis: analysis ?? this.analysis,
        generatorVersion: generatorVersion,
        boundsPadding: boundsPadding,
        title: title ?? this.title,
      );

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'seed': seed,
        'difficulty': difficulty,
        'generatorVersion': generatorVersion,
        'gridCols': gridCols,
        'gridRows': gridRows,
        'boundsPadding': boundsPadding,
        'metrics': metrics.toJson(),
        'rules': rules.toJson(),
        if (title != null) 'title': title,
        if (analysis != null) 'analysis': analysis!.toJson(),
        'arrows': [for (final a in arrows) a.toJson()],
      };

  factory Level.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] == null
        ? const ArrowMetrics()
        : ArrowMetrics.fromJson(json['metrics'] as Map<String, dynamic>);
    return Level(
      levelId: json['levelId'] as String? ?? 'custom',
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      gridCols: (json['gridCols'] as num?)?.toInt() ?? 8,
      gridRows: (json['gridRows'] as num?)?.toInt() ?? 10,
      arrows: [
        for (final raw in (json['arrows'] as List<dynamic>? ?? const []))
          PathArrow.fromJson(raw as Map<String, dynamic>, metrics: metrics),
      ],
      metrics: metrics,
      rules: json['rules'] == null
          ? const GameRules()
          : GameRules.fromJson(json['rules'] as Map<String, dynamic>),
      analysis: json['analysis'] == null
          ? null
          : LevelAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
      generatorVersion:
          (json['generatorVersion'] as num?)?.toInt() ?? LevelGeneratorVersion.current,
      boundsPadding: (json['boundsPadding'] as num?)?.toDouble() ?? 1.0,
      title: json['title'] as String?,
    );
  }

  @override
  String toString() =>
      'Level($levelId, seed=$seed, ${gridCols}x$gridRows, arrows=$arrowCount)';
}

/// Bump this whenever the generation algorithm changes in a way that makes
/// previously cached levels stale (prompt §54).
class LevelGeneratorVersion {
  static const int current = 3;
}

/// Result of measuring a generated level (prompt §51).
class LevelAnalysis {
  const LevelAnalysis({
    required this.isSolvable,
    required this.solutionLength,
    required this.optimalSolutionLength,
    required this.qualityScore,
    required this.difficultyLabel,
    required this.dependencyDepth,
    required this.rootCount,
    required this.maxBranching,
    required this.averageBranching,
    required this.decoyMoves,
    required this.blockedAtStart,
    required this.pathComplexity,
    required this.spatialDensity,
    required this.solutionIsOptimal,
  });

  final bool isSolvable;

  /// Length of the canonical (guaranteed) solution found by construction.
  final int solutionLength;

  /// Shortest solution found by the search (may be `null`-ish if capped).
  final int optimalSolutionLength;

  /// 0..100 (prompt §51).
  final double qualityScore;

  /// Measured label: Easy / Normal / Medium / Hard / Expert (prompt §29).
  final String difficultyLabel;

  /// Longest chain in the blocking dependency DAG.
  final int dependencyDepth;

  /// Arrows that are free at the very first move.
  final int rootCount;

  final int maxBranching;
  final double averageBranching;

  /// Moves that slide an arrow but do not remove it — the "traps".
  final int decoyMoves;

  /// How many arrows are blocked at the start of the level.
  final int blockedAtStart;

  final double pathComplexity;
  final double spatialDensity;

  /// `false` when the search hit its node cap and only found a partial result.
  final bool solutionIsOptimal;

  Map<String, dynamic> toJson() => {
        'isSolvable': isSolvable,
        'solutionLength': solutionLength,
        'optimalSolutionLength': optimalSolutionLength,
        'qualityScore': qualityScore,
        'difficultyLabel': difficultyLabel,
        'dependencyDepth': dependencyDepth,
        'rootCount': rootCount,
        'maxBranching': maxBranching,
        'averageBranching': averageBranching,
        'decoyMoves': decoyMoves,
        'blockedAtStart': blockedAtStart,
        'pathComplexity': pathComplexity,
        'spatialDensity': spatialDensity,
        'solutionIsOptimal': solutionIsOptimal,
      };

  factory LevelAnalysis.fromJson(Map<String, dynamic> json) => LevelAnalysis(
        isSolvable: json['isSolvable'] as bool? ?? false,
        solutionLength: (json['solutionLength'] as num?)?.toInt() ?? 0,
        optimalSolutionLength:
            (json['optimalSolutionLength'] as num?)?.toInt() ?? 0,
        qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0,
        difficultyLabel: json['difficultyLabel'] as String? ?? 'Easy',
        dependencyDepth: (json['dependencyDepth'] as num?)?.toInt() ?? 0,
        rootCount: (json['rootCount'] as num?)?.toInt() ?? 0,
        maxBranching: (json['maxBranching'] as num?)?.toInt() ?? 0,
        averageBranching: (json['averageBranching'] as num?)?.toDouble() ?? 0,
        decoyMoves: (json['decoyMoves'] as num?)?.toInt() ?? 0,
        blockedAtStart: (json['blockedAtStart'] as num?)?.toInt() ?? 0,
        pathComplexity: (json['pathComplexity'] as num?)?.toDouble() ?? 0,
        spatialDensity: (json['spatialDensity'] as num?)?.toDouble() ?? 0,
        solutionIsOptimal: json['solutionIsOptimal'] as bool? ?? false,
      );
}
