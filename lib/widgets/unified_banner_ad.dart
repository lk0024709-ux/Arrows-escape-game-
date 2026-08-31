import 'package:arrows_escape_game/core/ad_secrets.dart';
import 'package:flutter/material.dart';

/// Advertising slot rendered at the bottom of the game screen.
///
/// AdMob is not linked into this dependency-free build. When
/// [AdSecrets.adsEnabled] is `false` (or the SDK is unavailable) this renders a
/// zero-height, non-intrusive widget so the game layout is never broken. When
/// a build that links `google_mobile_ads` is configured, the banner widget is
/// swapped in here behind the same constant, keeping the rest of the screen
/// unchanged.
class UnifiedBannerAd extends StatelessWidget {
  const UnifiedBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdSecrets.adsEnabled) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFE082)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Advertisement',
        style: TextStyle(fontSize: 11, color: Colors.brown),
      ),
    );
  }
}
