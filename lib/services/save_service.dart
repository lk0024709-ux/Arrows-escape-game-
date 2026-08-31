import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/model/level.dart';

/// Offline persistence (prompt §55).
///
/// Stores completed levels, best moves, stars, hints used, current level,
/// settings, cached generated levels and daily puzzles.
class SaveService {
  SaveService._(this._prefs);

  final SharedPreferences? _prefs;

  static const String _progressKey = 'arrows_escape.progress.v3';
  static const String _settingsKey = 'arrows_escape.settings.v3';
  static const String _levelCachePrefix = 'arrows_escape.level.';
  static const String _dailyPrefix = 'arrows_escape.daily.';

  static SaveService? _instance;

  static Future<SaveService> init() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = SaveService._(prefs);
    return _instance!;
  }

  /// In-memory fallback used by tests and by the web preview.
  factory SaveService.memory() => SaveService._(null);

  // ---------------------------------------------------------------------------
  // Level records
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _readMap(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    await _prefs?.setString(key, jsonEncode(value));
  }

  LevelRecord? recordFor(String levelId) {
    final map = _readMap(_progressKey);
    final raw = map[levelId];
    if (raw is Map<String, dynamic>) return LevelRecord.fromJson(raw);
    if (raw is Map) return LevelRecord.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }

  Map<String, LevelRecord> get allRecords {
    final map = _readMap(_progressKey);
    return map.map(
      (key, value) => MapEntry(
        key,
        LevelRecord.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  }

  Future<void> saveRecord(String levelId, LevelRecord record) async {
    final map = _readMap(_progressKey);
    final existing = recordFor(levelId);
    map[levelId] = record.mergeWith(existing).toJson();
    await _writeMap(_progressKey, map);
  }

  int get completedCount =>
      allRecords.values.where((r) => r.completed).length;

  int get totalStars =>
      allRecords.values.fold(0, (sum, r) => sum + r.stars);

  // ---------------------------------------------------------------------------
  // Progression
  // ---------------------------------------------------------------------------

  int get currentLevel => _prefs?.getInt('${_progressKey}.current') ?? 1;

  Future<void> setCurrentLevel(int value) async {
    await _prefs?.setInt('${_progressKey}.current', value);
  }

  int get endlessBest => _prefs?.getInt('${_progressKey}.endless') ?? 0;

  Future<void> setEndlessBest(int value) async {
    if (value > endlessBest) {
      await _prefs?.setInt('${_progressKey}.endless', value);
    }
  }

  // ---------------------------------------------------------------------------
  // Generated level cache (so revisiting a level is instant and stable)
  // ---------------------------------------------------------------------------

  Level? cachedLevel(String levelId) {
    final raw = _prefs?.getString('$_levelCachePrefix$levelId');
    if (raw == null) return null;
    try {
      return Level.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheLevel(Level level) async {
    await _prefs?.setString(
      '$_levelCachePrefix${level.levelId}',
      jsonEncode(level.toJson()),
    );
  }

  Level? cachedDaily(String isoDate) {
    final raw = _prefs?.getString('$_dailyPrefix$isoDate');
    if (raw == null) return null;
    try {
      return Level.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheDaily(String isoDate, Level level) async {
    await _prefs?.setString('$_dailyPrefix$isoDate', jsonEncode(level.toJson()));
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  GameSettings get settings {
    final map = _readMap(_settingsKey);
    return GameSettings.fromJson(map);
  }

  Future<void> saveSettings(GameSettings value) async {
    await _writeMap(_settingsKey, value.toJson());
  }

  Future<void> resetAll() async {
    final keys = _prefs
            ?.getKeys()
            .where((k) => k.startsWith('arrows_escape.'))
            .toList() ??
        <String>[];
    for (final key in keys) {
      await _prefs?.remove(key);
    }
  }
}

/// Per-level progression record.
class LevelRecord {
  const LevelRecord({
    this.completed = false,
    this.stars = 0,
    this.bestMoves,
    this.hintsUsed = 0,
    this.attempts = 0,
  });

  final bool completed;
  final int stars;
  final int? bestMoves;
  final int hintsUsed;
  final int attempts;

  LevelRecord mergeWith(LevelRecord? other) {
    if (other == null) return this;
    final mergedBest = bestMoves == null
        ? other.bestMoves
        : (other.bestMoves == null
            ? bestMoves
            : (bestMoves! < other.bestMoves! ? bestMoves : other.bestMoves));
    return LevelRecord(
      completed: completed || other.completed,
      stars: stars > other.stars ? stars : other.stars,
      bestMoves: mergedBest,
      hintsUsed: hintsUsed + other.hintsUsed,
      attempts: attempts + other.attempts,
    );
  }

  Map<String, dynamic> toJson() => {
        'completed': completed,
        'stars': stars,
        if (bestMoves != null) 'bestMoves': bestMoves,
        'hintsUsed': hintsUsed,
        'attempts': attempts,
      };

  factory LevelRecord.fromJson(Map<String, dynamic> json) => LevelRecord(
        completed: json['completed'] as bool? ?? false,
        stars: (json['stars'] as num?)?.toInt() ?? 0,
        bestMoves: (json['bestMoves'] as num?)?.toInt(),
        hintsUsed: (json['hintsUsed'] as num?)?.toInt() ?? 0,
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );
}

/// User settings (all optional, all persisted offline).
class GameSettings {
  const GameSettings({
    this.showGuideDots = true,
    this.haptics = true,
    this.showQualityScore = false,
    this.adsEnabled = true,
    this.developerMode = false,
    this.soundEnabled = true,
  });

  final bool showGuideDots;
  final bool haptics;
  final bool showQualityScore;
  final bool adsEnabled;
  final bool developerMode;
  final bool soundEnabled;

  GameSettings copyWith({
    bool? showGuideDots,
    bool? haptics,
    bool? showQualityScore,
    bool? adsEnabled,
    bool? developerMode,
    bool? soundEnabled,
  }) =>
      GameSettings(
        showGuideDots: showGuideDots ?? this.showGuideDots,
        haptics: haptics ?? this.haptics,
        showQualityScore: showQualityScore ?? this.showQualityScore,
        adsEnabled: adsEnabled ?? this.adsEnabled,
        developerMode: developerMode ?? this.developerMode,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );

  Map<String, dynamic> toJson() => {
        'showGuideDots': showGuideDots,
        'haptics': haptics,
        'showQualityScore': showQualityScore,
        'adsEnabled': adsEnabled,
        'developerMode': developerMode,
        'soundEnabled': soundEnabled,
      };

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
        showGuideDots: json['showGuideDots'] as bool? ?? true,
        haptics: json['haptics'] as bool? ?? true,
        showQualityScore: json['showQualityScore'] as bool? ?? false,
        adsEnabled: json['adsEnabled'] as bool? ?? true,
        developerMode: json['developerMode'] as bool? ?? false,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
      );
}
