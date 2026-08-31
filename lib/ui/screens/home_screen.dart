import 'package:flutter/material.dart';

import '../../data/level_pack.dart';
import '../../game/model/direction.dart';
import '../../game/model/grid_point.dart';
import '../../game/model/path_arrow.dart';
import '../../services/save_service.dart';
import '../../theme/app_theme.dart';
import 'levels_screen.dart';
import '../../game/engine/game_controller.dart';
import 'game_screen.dart';
import '../../services/ad_provider.dart';

/// Home screen: title art, continue, levels, daily, settings.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.save,
    required this.pack,
    required this.adProvider,
    required this.onOpenSettings,
    required this.onSettingsChanged,
  });

  final SaveService save;
  final LevelPack pack;
  final AdProvider adProvider;
  final VoidCallback onOpenSettings;
  final ValueChanged<GameSettings> onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final completed = save.completedCount;
    final stars = save.totalStars;
    final current = save.currentLevel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 10),
                    const Text(
                      'ARROWS',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const Text(
                      'ESCAPE',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: AppColors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Slide every path out of the labyrinth.',
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => _openLevel(context, current),
                    child: Text(current > 1 ? 'Continue — level $current' : 'Play'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LevelsScreen(
                          save: save,
                          pack: pack,
                          adProvider: adProvider,
                          onSettingsChanged: onSettingsChanged,
                        ),
                      ),
                    ),
                    child: const Text('Levels'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _openDaily(context),
                    child: const Text('Daily puzzle'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onOpenSettings,
                    child: const Text('Settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '$completed/${LevelPack.campaignLength} levels · $stars★ · '
              'endless best ${save.endlessBest}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _openLevel(BuildContext context, int index) async {
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

  Future<void> _openDaily(BuildContext context) async {
    final iso = DateTime.now().toIso8601String().substring(0, 10);
    final level = await pack.dailyLevel(iso);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          controller: GameController(level: level),
          levelIndex: null,
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

/// Decorative logo drawn with the same path geometry the game uses.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(160, 80),
      painter: _LogoPainter(),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final metrics = const ArrowMetrics();
    final arrows = <PathArrow>[
      PathArrow(
        id: 'logo1',
        points: const [
          GridPoint(0, 1),
          GridPoint(4, 1),
          GridPoint(4, 4),
        ],
        direction: Direction.down,
        metrics: metrics,
      ),
      PathArrow(
        id: 'logo2',
        points: const [GridPoint(1, 6), GridPoint(5, 6)],
        direction: Direction.right,
        metrics: metrics,
      ),
    ];

    for (final arrow in arrows) {
      final points = arrow.worldPoints;
      final scale = size.width / 6;
      final offset = Offset(size.width * 0.08, size.height * 0.12);
      final path = Path()
        ..moveTo(offset.dx + points.first.x * scale, offset.dy + points.first.y * scale);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(offset.dx + points[i].x * scale, offset.dy + points[i].y * scale);
      }
      final isAccent = arrow.id == 'logo2';
      canvas.drawPath(
        path,
        Paint()
          ..color = isAccent ? AppColors.blueAccent : AppColors.primaryNavy
          ..style = PaintingStyle.stroke
          ..strokeWidth = metrics.thickness * scale * 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final tip = points.last;
      final back = tip.x - arrow.direction.dx * metrics.headLength;
      final backY = tip.y - arrow.direction.dy * metrics.headLength;
      final halfWidth = metrics.headWidth / 2;
      final head = Path()
        ..moveTo(offset.dx + tip.x * scale, offset.dy + tip.y * scale);
      if (arrow.direction.isHorizontal) {
        head
          ..lineTo(offset.dx + back * scale, offset.dy + (tip.y - halfWidth) * scale)
          ..lineTo(offset.dx + back * scale, offset.dy + (tip.y + halfWidth) * scale);
      } else {
        head
          ..lineTo(offset.dx + (tip.x - halfWidth) * scale, offset.dy + backY * scale)
          ..lineTo(offset.dx + (tip.x + halfWidth) * scale, offset.dy + backY * scale);
      }
      head.close();
      canvas.drawPath(
        head,
        Paint()..color = isAccent ? AppColors.blueAccent : AppColors.primaryNavy,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
