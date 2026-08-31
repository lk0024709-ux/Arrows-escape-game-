import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Advertisement abstraction (prompt §33).
///
/// The game engine knows nothing about ads: this is the only place where an ad
/// widget is produced, and it can be swapped for a no-op at any time (premium).
abstract class AdProvider {
  const AdProvider();

  /// Whether this provider currently renders a banner.
  bool get isEnabled;

  /// Builds the banner widget, or an empty box when ads are disabled.
  Widget buildBanner();

  /// Optional pre-load hook.
  Future<void> load() async {}
}

/// Premium / testing provider: renders nothing.
class NoopAdProvider extends AdProvider {
  const NoopAdProvider();

  @override
  bool get isEnabled => false;

  @override
  Widget buildBanner() => const SizedBox.shrink();
}

/// Placeholder banner used until a real network is wired in.
///
/// It is deliberately isolated: it lives below the safe area, it is the only
/// widget that knows about "an ad", and it never touches game state.
class PlaceholderAdProvider extends AdProvider {
  const PlaceholderAdProvider({this.height = 58});

  final double height;

  @override
  bool get isEnabled => true;

  @override
  Widget buildBanner() => _PlaceholderBanner(height: height);
}

class _PlaceholderBanner extends StatelessWidget {
  const _PlaceholderBanner({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.guideDot, style: BorderStyle.solid),
      ),
      child: const Center(
        child: Text(
          'AD',
          style: TextStyle(
            color: AppColors.textMuted,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
