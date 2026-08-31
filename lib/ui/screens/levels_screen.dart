import 'package:flutter/material.dart';

import '../../data/level_pack.dart';
import '../../game/engine/game_controller.dart';
import '../../services/ad_provider.dart';
import '../../services/save_service.dart';
import '../../theme/app_theme.dart';
import 'game_screen.dart';

/// Campaign level grid + endless entry point (prompt §52, §53).
class LevelsScreen extends StatelessWidget {
  const LevelsScreen({
    super.key,
    required this.save,
    required this.pack,
    required this.adProvider,
    required this.onSettingsChanged,
  });

  final SaveService save;
  final LevelPack pack;
  final AdProvider adProvider;
  final ValueChanged<GameSettings> onSettingsChanged;

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
                      'Levels',
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
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: LevelPack.campaignLength,
                itemBuilder: (context, index) {
                  final levelNumber = index + 1;
                  final record = save.recordFor('L$levelNumber');
                  final unlocked = levelNumber == 1 ||
                      (save.recordFor('L${levelNumber - 1}')?.completed ?? false) ||
                      levelNumber <= save.currentLevel;
                  return _LevelChip(
                    number: levelNumber,
                    stars: record?.stars ?? 0,
                    unlocked: unlocked,
                    isCurrent: levelNumber == save.currentLevel,
                    onTap: unlocked
                        ? () => _open(context, levelNumber)
                        : null,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _open(
                        context,
                        LevelPack.campaignLength + save.endlessBest + 1,
                        endless: true,
                      ),
                      child: const Text('Endless run'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Procedurally generated — difficulty ramps without limit.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, int index, {bool endless = false}) async {
    final level = await pack.campaignLevel(index);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          controller: GameController(level: level),
          levelIndex: index,
          settings: save.settings,
          save: save,
          pack: pack,
          adProvider: adProvider,
          onSettingsChanged: onSettingsChanged,
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.number,
    required this.stars,
    required this.unlocked,
    required this.isCurrent,
    required this.onTap,
  });

  final int number;
  final int stars;
  final bool unlocked;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: Material(
        color: AppColors.lightUi,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.softShadow,
              border: isCurrent
                  ? Border.all(color: AppColors.blueAccent, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 10,
                  child: Text(
                    stars > 0 ? '★' * stars : '',
                    style: const TextStyle(fontSize: 9, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
