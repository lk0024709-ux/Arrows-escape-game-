import 'package:flutter/services.dart';

/// Resolves the font family the app should render with.
///
/// A custom font can live in `assets/fonts/`. Because a missing or zero-byte
/// asset would otherwise break rendering, [resolve] checks every candidate
/// defensively and gracefully falls back to the platform default (or a Google
/// font in a build that links `google_fonts`) when none is usable.
class AppFont {
  AppFont._();

  /// Candidates checked in order. The first that loads with a non-zero byte
  /// count is registered and returned.
  static const List<({String family, String asset})> candidates = [
    (family: 'ArrowsEscape', asset: 'assets/fonts/arrows_escape.ttf'),
    (family: 'ArrowsEscape', asset: 'assets/fonts/arrows_escape.otf'),
  ];

  static String? _resolved;

  /// Resolves and caches the chosen family. Returns `null` when no bundled
  /// font is usable, signalling callers to use the platform default.
  static Future<String?> resolve() async {
    if (_resolved != null) return _resolved;
    _resolved = await _loadFirstUsable();
    return _resolved;
  }

  /// Whether a bundled font was successfully registered.
  static bool get hasBundledFont => _resolved != null;

  static Future<String?> _loadFirstUsable() async {
    for (final candidate in candidates) {
      try {
        final data = await rootBundle.load(candidate.asset);
        if (data.lengthInBytes == 0) continue; // zero-byte -> skip
        final loader = FontLoader(candidate.family)
          ..addFont(Future<ByteData>.value(data));
        await loader.load();
        return candidate.family;
      } on Exception {
        // Missing / unreadable asset -> try the next candidate.
      } catch (_) {
        // Unknown failure -> fall through to the next candidate.
      }
    }
    return null;
  }
}
