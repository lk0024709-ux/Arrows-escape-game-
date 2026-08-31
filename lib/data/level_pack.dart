import '../core/rng/deterministic_random.dart';
import '../game/generator/difficulty_params.dart';
import '../game/generator/level_generator.dart';
import '../game/model/level.dart';
import '../services/save_service.dart';

/// The 50 level campaign plus endless mode (prompt §52, §53).
///
/// Levels are generated **deterministically** from `(seed, difficulty, generator
/// version)`, then cached — so a level is byte-identical on every device and on
/// every launch, while costing nothing to ship as an asset.
class LevelPack {
  LevelPack({
    LevelGenerator? generator,
    SaveService? save,
  })  : _generator = generator ?? LevelGenerator(),
        _save = save;

  final LevelGenerator _generator;
  final SaveService? _save;

  static const int campaignLength = 50;

  /// Stable seed for a campaign level.
  static int seedForLevel(int index) =>
      DeterministicRandom.hashString('arrows-escape-v${LevelGeneratorVersion.current}-L$index');

  static int seedForDaily(String isoDate) =>
      DeterministicRandom.hashString('daily-$isoDate');

  /// Difficulty parameters for a campaign or endless level.
  static DifficultyParams paramsForIndex(int index) {
    if (index <= campaignLength) return DifficultyParams.forLevelIndex(index);
    final base = DifficultyParams.forBand(DifficultyBand.expert);
    final extra = ((index - campaignLength) / 5).floor().clamp(0, 8);
    return base.copyWith(arrowMin: base.arrowMin + extra, arrowMax: base.arrowMax + extra);
  }

  /// Load (or generate + cache) a campaign level.
  Future<Level> campaignLevel(int index) async {
    final levelId = 'L$index';
    final cached = _save?.cachedLevel(levelId);
    if (cached != null && cached.generatorVersion == LevelGeneratorVersion.current) {
      return cached;
    }
    final level = _generator.generate(
      difficulty: paramsForIndex(index).band,
      seed: seedForLevel(index),
      params: paramsForIndex(index),
      levelNumber: index,
      levelId: levelId,
    );
    await _save?.cacheLevel(level);
    return level;
  }

  /// Endless level: same pipeline, unbounded index.
  Future<Level> endlessLevel(int index) => campaignLevel(index);

  /// Daily puzzle — identical for every player on a given date.
  Future<Level> dailyLevel(String isoDate) async {
    final cached = _save?.cachedDaily(isoDate);
    if (cached != null && cached.generatorVersion == LevelGeneratorVersion.current) {
      return cached;
    }
    final params = DifficultyParams.forBand(DifficultyBand.medium);
    final level = _generator.generate(
      difficulty: params.band,
      seed: seedForDaily(isoDate),
      params: params,
      levelId: 'daily-$isoDate',
    );
    await _save?.cacheDaily(isoDate, level);
    return level;
  }

  /// Custom level from a raw seed + band (used by the editor and by settings).
  Level customLevel({required int seed, required int band}) =>
      _generator.generate(difficulty: band, seed: seed);

  /// Generates the whole campaign up-front (used by the editor's
  /// "pre-generate pack" action and by the unit tests).
  Future<List<Level>> generateCampaign({int count = campaignLength}) async {
    final levels = <Level>[];
    for (var i = 1; i <= count; i++) {
      levels.add(await campaignLevel(i));
    }
    return levels;
  }
}

/// Human label for a level index.
String levelTitle(int index) => index > LevelPack.campaignLength
    ? 'Endless ${index - LevelPack.campaignLength}'
    : 'Level $index';
