import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A single dialog action.
class ResultAction {
  const ResultAction({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
}

/// Win / lose / dead-end dialog.
Future<void> showResultDialog({
  required BuildContext context,
  required String title,
  required String message,
  required List<ResultAction> actions,
  int stars = 0,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.primaryNavy.withValues(alpha: 0.35),
    pageBuilder: (context, _, __) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  if (stars > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Icon(
                            i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                            color: AppColors.warning,
                            size: 30,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: actions[i].isPrimary
                              ? FilledButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    actions[i].onTap();
                                  },
                                  child: Text(actions[i].label),
                                )
                              : OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    actions[i].onTap();
                                  },
                                  child: Text(actions[i].label),
                                ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
