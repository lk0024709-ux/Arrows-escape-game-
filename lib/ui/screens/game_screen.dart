import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/math/vector2.dart';
import '../../data/level_pack.dart';
import '../../game/engine/game_controller.dart';
import '../../services/ad_provider.dart';
import '../debug/debug_panel.dart';
import '../painters/board_painter.dart';
import '../widgets/ad_container.dart';
import '../widgets/board_view.dart';
import '../widgets/bottom_toolbar.dart';
import '../widgets/status_card.dart';
import '../widgets/top_header.dart';
import '../widgets/result_dialog.dart';
import '../../services/save_service.dart';
import '../../theme/app_theme.dart';

/// The main play screen (prompt §24).
///
/// Layout:
/// top UI → small breathing space → game board → large breathing space →
/// tools → isolated ad container.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.controller,
    required this.levelIndex,
    required this.settings,
    required this.save,
    required this.pack,
    required this.adProvider,
    this.onSettingsChanged,
  });

  final GameController controller;
  final int? levelIndex;
  final GameSettings settings;
  final SaveService save;
  final LevelPack pack;
  final AdProvider adProvider;
  final ValueChanged<GameSettings>? onSettingsChanged;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _ticker;
  late GameController _controller;
  late DebugOptions _debug;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onControllerChanged);
    _debug = const DebugOptions();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    );
    _syncTicker();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _syncTicker();
    _maybeShowDialog();
  }

  /// The ticker only runs while an escape/slide animation is in flight.
  void _syncTicker() {
    if (_controller.hasActiveAnimations) {
      if (!_ticker.isAnimating) _ticker.repeat();
    } else {
      _ticker.stop();
      _controller.pruneAnimations();
    }
  }

  void _maybeShowDialog() {
    if (_dialogVisible || !_controller.isOver && !_controller.isStuck) return;
    _dialogVisible = true;
    final delay = _controller.isWon ? 640 : 320;
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _showResultDialog();
    });
  }

  Future<void> _showResultDialog() async {
    if (_controller.isWon) {
      final record = LevelRecord(
        completed: true,
        stars: _controller.starsFor(),
        bestMoves: _controller.moves,
      );
      final levelId = _controller.level.levelId;
      await widget.save.saveRecord(levelId, record);
      if (widget.levelIndex != null) {
        await widget.save.setCurrentLevel(widget.levelIndex! + 1);
        if (widget.levelIndex! > LevelPack.campaignLength) {
          await widget.save
              .setEndlessBest(widget.levelIndex! - LevelPack.campaignLength);
        }
      }
      if (!mounted) return;
      await showResultDialog(
        context: context,
        title: 'Escaped!',
        stars: record.stars,
        message: _winMessage(),
        actions: [
          ResultAction(
            label: 'Next level',
            isPrimary: true,
            onTap: () => _goToNextLevel(),
          ),
          ResultAction(
            label: 'Replay',
            onTap: () {
              _controller.restart();
              _dialogVisible = false;
            },
          ),
          ResultAction(
            label: 'Levels',
            onTap: () {
              _dialogVisible = false;
              Navigator.of(context).maybePop();
            },
          ),
        ],
      );
    } else if (_controller.isStuck) {
      await showResultDialog(
        context: context,
        title: 'No moves left',
        message:
            'Nothing can slide any more. Undo your last move, or restart the level.',
        actions: [
          ResultAction(
            label: 'Undo',
            isPrimary: true,
            onTap: () {
              _controller.undo();
              _dialogVisible = false;
            },
          ),
          ResultAction(
            label: 'Restart (♥)',
            onTap: () {
              _controller.restartWithPenalty();
              _dialogVisible = false;
            },
          ),
        ],
      );
    } else {
      await showResultDialog(
        context: context,
        title: 'Out of lives',
        message: 'The labyrinth won this round.',
        actions: [
          ResultAction(
            label: 'Retry',
            isPrimary: true,
            onTap: () {
              _controller.restart();
              _dialogVisible = false;
            },
          ),
          ResultAction(
            label: 'Levels',
            onTap: () {
              _dialogVisible = false;
              Navigator.of(context).maybePop();
            },
          ),
        ],
      );
    }
    if (mounted) setState(() => _dialogVisible = false);
  }

  Future<void> _goToNextLevel() async {
    final nextIndex = (widget.levelIndex ?? 0) + 1;
    _dialogVisible = false;
    if (!mounted) return;
    final level = await widget.pack.campaignLevel(nextIndex);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          controller: GameController(level: level),
          levelIndex: nextIndex,
          settings: widget.settings,
          save: widget.save,
          pack: widget.pack,
          adProvider: widget.adProvider,
          onSettingsChanged: widget.onSettingsChanged,
        ),
      ),
    );
  }

  String _winMessage() {
    final analysis = _controller.level.analysis;
    final parts = <String>[
      '${_controller.moves} moves · ${_controller.par} par',
      if (analysis != null)
        'Measured difficulty ${analysis.difficultyLabel} '
            '(${analysis.qualityScore.round()}/100) · '
            'dependency depth ${analysis.dependencyDepth}',
    ];
    return parts.join('\n');
  }

  void _onTapWorld(Vec2 world) {
    if (_controller.isOver) return;
    final index = _controller.hitTest(world);
    if (index == null) {
      _controller.selectedIndex = null;
      return;
    }
    _controller.selectedIndex = index;
    final result = _controller.tapArrow(index);
    if (result == null) return;
    if (result.wasBlocked && widget.settings.haptics) {
      HapticFeedback.lightImpact();
    } else if (widget.settings.haptics) {
      HapticFeedback.selectionClick();
    }
  }

  void _openDebug() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DebugPanel(
        controller: _controller,
        options: _debug,
        onChanged: (value) => setState(() => _debug = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final title = widget.levelIndex != null
        ? levelTitle(widget.levelIndex!)
        : (controller.level.title ?? 'Custom');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TopHeader(
              title: title,
              onSettings: widget.settings.developerMode ? _openDebug : null,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            StatusCard(
              controller: controller,
              showQualityScore: widget.settings.showQualityScore,
            ),
            const SizedBox(height: 8),
            // Board — flexes to fill the available space while keeping margins.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedBuilder(
                  animation: _ticker,
                  builder: (context, _) => BoardView(
                    controller: controller,
                    showGuideDots: widget.settings.showGuideDots,
                    debug: _debug,
                    onTapWorld: _onTapWorld,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            BottomToolbar(
              hints: controller.hints,
              canUndo: controller.canUndo,
              onHint: () {
                final index = controller.requestHint();
                if (index != null && widget.settings.haptics) {
                  HapticFeedback.selectionClick();
                }
              },
              onUndo: () => controller.undo(),
              onRestart: () => controller.restartWithPenalty(),
            ),
            // Isolated ad region — the engine knows nothing about it (§33).
            AdContainer(provider: widget.adProvider),
          ],
        ),
      ),
    );
  }
}
