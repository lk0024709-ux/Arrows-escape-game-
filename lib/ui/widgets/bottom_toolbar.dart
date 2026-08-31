import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Bottom tool row: hint (with badge), undo, restart (prompt §30–§32).
class BottomToolbar extends StatelessWidget {
  const BottomToolbar({
    super.key,
    required this.hints,
    required this.canUndo,
    required this.onHint,
    required this.onUndo,
    required this.onRestart,
  });

  final int hints;
  final bool canUndo;
  final VoidCallback onHint;
  final VoidCallback onUndo;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToolButton(
            icon: Icons.lightbulb_outline_rounded,
            badge: '$hints',
            enabled: hints > 0,
            tooltip: 'Hint',
            onTap: onHint,
          ),
          const SizedBox(width: 22),
          _ToolButton(
            icon: Icons.undo_rounded,
            enabled: canUndo,
            tooltip: 'Undo',
            onTap: onUndo,
          ),
          const SizedBox(width: 22),
          _ToolButton(
            icon: Icons.restart_alt_rounded,
            enabled: true,
            tooltip: 'Restart',
            onTap: onRestart,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.tooltip,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String tooltip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.lightUi,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.softShadow,
              ),
              child: IconButton(
                tooltip: tooltip,
                iconSize: 24,
                onPressed: enabled ? onTap : null,
                icon: Icon(
                  icon,
                  color: enabled ? AppColors.primaryNavy : AppColors.textMuted,
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.blueAccent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
