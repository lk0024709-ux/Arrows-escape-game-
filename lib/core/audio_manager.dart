import 'package:flutter/services.dart';

/// Identifiers for every sound the game can play.
enum GameSound { move, success, block, hint, timeLow, god, boss }

/// One audio slot: an asset name plus (after a successful load) its bytes.
class _SoundSlot {
  _SoundSlot(this.assetName);

  final String assetName;
  ByteData? data;
}

/// Fail-safe, dependency-free audio manager.
///
/// Startup must never crash because an audio file is missing or zero bytes
/// (e.g. `underwater.mp3` or `swoosh_18.mp3`). Every asset is loaded
/// defensively and any failure simply marks that slot as unavailable; [play]
/// then safely no-ops.
///
/// Playback is intentionally a no-op in this build because no audio plugin is
/// linked. The pool + load API mirrors a real player, so an engine
/// (`audioplayers`, `just_audio`, ...) can be wired in later by handing each
/// slot's [ByteData] to the plugin without touching any caller.
class AudioManager {
  AudioManager._();

  /// Shared singleton; games are single-instance.
  static final AudioManager instance = AudioManager._();

  static const String _assetPrefix = 'assets/audio/';

  static const Map<GameSound, String> _assetNames = {
    GameSound.move: 'swoosh_18.mp3',
    GameSound.success: 'success.mp3',
    GameSound.block: 'block.mp3',
    GameSound.hint: 'hint.mp3',
    GameSound.timeLow: 'underwater.mp3',
    GameSound.god: 'god.mp3',
    GameSound.boss: 'boss.mp3',
  };

  final Map<GameSound, _SoundSlot> _slots = {
    for (final entry in _assetNames.entries)
      entry.key: _SoundSlot(_assetPrefix + entry.value),
  };

  bool _initialized = false;

  /// Whether the cache has been warmed at least once.
  bool get isInitialized => _initialized;

  /// Warm the sound cache. Missing or empty files are skipped, never thrown.
  Future<void> init() async {
    if (_initialized) return;
    await _loadAll();
    _initialized = true;
  }

  Future<void> _loadAll() async {
    for (final slot in _slots.values) {
      try {
        final data = await rootBundle.load(slot.assetName);
        if (data.lengthInBytes > 0) slot.data = data;
      } on Exception {
        // Missing or unreadable asset: keep the slot empty, never crash.
      } catch (_) {
        // Unknown failure: same graceful behaviour.
      }
    }
  }

  /// Returns true if [sound] loaded usable bytes.
  bool isLoaded(GameSound sound) {
    final slot = _slots[sound];
    return slot != null && slot.data != null;
  }

  /// Play [sound] if it is loaded. Never throws.
  void play(GameSound sound) {
    final slot = _slots[sound];
    if (slot == null || slot.data == null) return;
    // In a build that links an audio plugin this hands slot.data to it.
  }

  /// Drop all loaded buffers, e.g. between levels.
  void unloadAll() {
    for (final slot in _slots.values) {
      slot.data = null;
    }
  }
}
