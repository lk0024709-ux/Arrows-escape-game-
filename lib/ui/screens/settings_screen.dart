import 'package:flutter/material.dart';

import '../../services/save_service.dart';
import '../../theme/app_theme.dart';
import 'level_editor_screen.dart';

/// Settings screen (prompt §55).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onResetProgress,
  });

  final GameSettings settings;
  final ValueChanged<GameSettings> onChanged;
  final Future<void> Function() onResetProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SettingSwitch(
                    label: 'Guide dots',
                    value: settings.showGuideDots,
                    onChanged: (v) => onChanged(settings.copyWith(showGuideDots: v)),
                  ),
                  _SettingSwitch(
                    label: 'Haptics',
                    value: settings.haptics,
                    onChanged: (v) => onChanged(settings.copyWith(haptics: v)),
                  ),
                  _SettingSwitch(
                    label: 'Show measured difficulty score',
                    value: settings.showQualityScore,
                    onChanged: (v) =>
                        onChanged(settings.copyWith(showQualityScore: v)),
                  ),
                  _SettingSwitch(
                    label: 'Ads (turn off for premium)',
                    value: settings.adsEnabled,
                    onChanged: (v) => onChanged(settings.copyWith(adsEnabled: v)),
                  ),
                  _SettingSwitch(
                    label: 'Developer debug menu',
                    value: settings.developerMode,
                    onChanged: (v) =>
                        onChanged(settings.copyWith(developerMode: v)),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LevelEditorScreen(),
                      ),
                    ),
                    child: const Text('Level editor'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Reset progress?'),
                              content: const Text(
                                'This clears completed levels, stars and cached levels.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (confirmed) await onResetProgress();
                    },
                    child: const Text(
                      'Reset progress',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lightUi,
          borderRadius: BorderRadius.circular(14),
        ),
        child: SwitchListTile.adaptive(
          title: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryNavy,
            ),
          ),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
