import 'package:flutter/material.dart';

import '../../game/engine/game_controller.dart';
import '../../theme/app_theme.dart';

/// Floating status card: move counter · lives · difficulty badge (prompt §26).
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.controller,
    this.showQualityScore = false,
  });

  final GameController controller;
  final bool showQualityScore;

  @override
  Widget build(BuildContext context) {
    final analysis = controller.level.analysis;
    final label = analysis?.difficultyLabel ?? 'Easy';
    final score = analysis?.qualityScore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightUi,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Move counter (player moves, never animation frames — §27)
          const Icon(
            Icons.north_east_rounded,
            size: 18,
            color: AppColors.primaryNavy,
          ),
          const SizedBox(width: 6),
          Text(
            '${controller.moves}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryNavy,
            ),
          ),
          const Spacer(),
          // Lives (§28)
          LivesIndicator(lives: controller.lives, max: controller.rules.lives),
          const Spacer(),
          DifficultyBadge(
            label: showQualityScore && score != null
                ? '$label ${score.round()}'
                : label,
          ),
        ],
      ),
    );
  }
}

/// Heart row — the number of hearts comes from the rules, never from physics.
class LivesIndicator extends StatelessWidget {
  const LivesIndicator({super.key, required this.lives, required this.max});

  final int lives;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Icon(
              Icons.favorite_rounded,
              size: 18,
              color: i < lives ? AppColors.error : AppColors.error.withValues(alpha: 0.22),
            ),
          ),
      ],
    );
  }
}

/// Measured-difficulty pill (prompt §29).
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.blueAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.blueAccent,
        ),
      ),
    );
  }
}
