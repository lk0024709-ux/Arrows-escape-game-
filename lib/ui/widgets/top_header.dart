import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Compact top bar: back · centred level title · settings (prompt §25).
class TopHeader extends StatelessWidget implements PreferredSizeWidget {
  const TopHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onSettings,
    this.settingsIcon = Icons.settings_outlined,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final IconData settingsIcon;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: preferredSize.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _RoundIconButton(
                icon: settingsIcon,
                onTap: onSettings,
                tooltip: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        iconSize: 20,
        icon: Icon(icon, color: AppColors.primaryNavy),
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
}
