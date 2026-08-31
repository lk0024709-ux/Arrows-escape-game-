import 'package:flutter/material.dart';

import '../../services/ad_provider.dart';
import '../../theme/app_theme.dart';

/// Bottom ad region (prompt §33).
///
/// Isolated: it sits below the game surface, it renders whatever the
/// [AdProvider] returns, and it never touches game state.
class AdContainer extends StatelessWidget {
  const AdContainer({super.key, required this.provider});

  final AdProvider provider;

  @override
  Widget build(BuildContext context) {
    if (!provider.isEnabled) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.guideDot.withValues(alpha: 0.4)),
          ),
        ),
        child: provider.buildBanner(),
      ),
    );
  }
}
