import 'package:flutter/material.dart';

import '../../game/engine/game_controller.dart';
import '../../theme/app_theme.dart';
import '../painters/board_painter.dart';

/// Internal debug menu (prompt §56).
///
/// Toggles: grid, grey dots, path points, hitboxes, collision shapes, escape
/// corridors, raycasts, dependency graph, solution, seed, difficulty score.
class DebugPanel extends StatelessWidget {
  const DebugPanel({
    super.key,
    required this.controller,
    required this.options,
    required this.onChanged,
  });

  final GameController controller;
  final DebugOptions options;
  final ValueChanged<DebugOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: height,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.guideDot,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Debug',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          _Switch(
            label: 'Show grid',
            value: options.showGrid,
            onChanged: (v) => onChanged(options.copyWith(showGrid: v)),
          ),
          _Switch(
            label: 'Show grey dots (debug)',
            value: options.showNodesDebug,
            onChanged: (v) => onChanged(options.copyWith(showNodesDebug: v)),
          ),
          _Switch(
            label: 'Show path points',
            value: options.showPathPoints,
            onChanged: (v) => onChanged(options.copyWith(showPathPoints: v)),
          ),
          _Switch(
            label: 'Show hitboxes / collision shapes',
            value: options.showHitboxes,
            onChanged: (v) => onChanged(options.copyWith(showHitboxes: v)),
          ),
          _Switch(
            label: 'Show escape corridor',
            value: options.showCorridors,
            onChanged: (v) => onChanged(options.copyWith(showCorridors: v)),
          ),
          _Switch(
            label: 'Show raycast',
            value: options.showRaycasts,
            onChanged: (v) => onChanged(options.copyWith(showRaycasts: v)),
          ),
          _Switch(
            label: 'Show dependency graph',
            value: options.showDependency,
            onChanged: (v) => onChanged(options.copyWith(showDependency: v)),
          ),
          _Switch(
            label: 'Show solution',
            value: options.showSolution,
            onChanged: (v) => onChanged(options.copyWith(showSolution: v)),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lightUi,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              controller.debugSummary(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.7,
                color: AppColors.navySoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryNavy,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
