import 'dart:async';
import 'dart:math' as math;

import 'package:arrows_escape_game/core/audio_manager.dart';
import 'package:arrows_escape_game/core/constants.dart';
import 'package:arrows_escape_game/data/repositories/level_repository.dart';
import 'package:arrows_escape_game/game/game_manager.dart';
import 'package:arrows_escape_game/geometry/arrow_path.dart';
import 'package:arrows_escape_game/level/difficulty.dart';
import 'package:arrows_escape_game/level/level.dart';
import 'package:arrows_escape_game/widgets/game_board.dart';
import 'package:arrows_escape_game/widgets/lives_bar.dart';
import 'package:arrows_escape_game/widgets/unified_banner_ad.dart';
import 'package:arrows_escape_game/widgets/wavy_progress_bar.dart';
import 'package:flutter/material.dart';

/// Lifecycle outcomes the screen can report through its callback bridge.
enum GameState { playing, levelComplete, gameOver, deadlock }

/// The full gameplay screen.
///
/// Owns the run (via [GameManager]) plus the level number, the async level
/// loading (via [LevelRepository]), God/Boss count-down timers, and the
/// surrounding chrome: top bar (level indicator, [LivesBar], back button),
/// bottom UI ([WavyProgressBar], tool row and [UnifiedBannerAd]) and the
/// pinch-to-zoom/pan board inside an [InteractiveViewer].
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.levelNumber = 1,
    this.onLevelComplete,
    this.onGameOver,
    this.onLifeLost,
    this.onDeadlock,
  });

  /// Starting level number. God levels are > 100, Boss levels > 200.
  final int levelNumber;

  /// Invoked when a level is cleared (passes the cleared level number).
  final void Function(int level)? onLevelComplete;

  /// Invoked when the run ends (lives exhausted or a timer expires fatally).
  final VoidCallback? onGameOver;

  /// Invoked every time a life is lost.
  final VoidCallback? onLifeLost;

  /// Invoked when the board has no legal move (unsolvable).
  final VoidCallback? onDeadlock;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const Duration _godLimit = Duration(minutes: 2);
  static const Duration _bossLimit = Duration(minutes: 3);

  final GameManager _manager = GameManager();
  final AudioManager _audio = AudioManager.instance;
  late final LevelRepository _repository;

  late int _levelNumber;
  bool _loading = true;

  Timer? _levelTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _levelNumber = widget.levelNumber;
    _repository = LevelRepository();
    _startLevel(_levelNumber);
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Level tier helpers
  // ---------------------------------------------------------------------

  bool get _isGodLevel => _levelNumber > 100;
  bool get _isBossLevel => _levelNumber > 200;

  /// A simple difficulty curve driven by the level number.
  DifficultyLevel _difficultyFor(int levelNumber) {
    if (levelNumber > 200) return DifficultyLevel.expert;
    if (levelNumber > 100) return DifficultyLevel.hard;
    if (levelNumber > 50) return DifficultyLevel.medium;
    if (levelNumber > 15) return DifficultyLevel.normal;
    return DifficultyLevel.easy;
  }

  Duration get _timerLimit {
    if (_isBossLevel) return _bossLimit;
    if (_isGodLevel) return _godLimit;
    return Duration.zero;
  }

  // ---------------------------------------------------------------------
  // Level lifecycle
  // ---------------------------------------------------------------------

  Future<void> _startLevel(int levelNumber) async {
    _stopTimer();
    _loading = true;
    final difficulty = _difficultyFor(levelNumber);
    await _loadLevel(difficulty);
  }

  void _onArrowSelected(ArrowPath arrow) {
    setState(() => _manager.onArrowSelected(arrow));
    _audio.play(GameSound.move);
  }

  void _onArrowReleased(ArrowPath arrow) {
    final livesBefore = _manager.lives;
    final arrowsBefore = _manager.currentLevel?.arrows.length ?? 0;

    setState(() => _manager.onArrowReleased(arrow));

    if (_manager.isGameOver) {
      _onGameOver();
      return;
    }

    final arrowsAfter = _manager.currentLevel?.arrows.length ?? 0;

    if (arrowsAfter < arrowsBefore) {
      // An arrow escaped.
      _audio.play(GameSound.success);
      if (arrowsAfter == 0) {
        _onLevelComplete();
      } else if ((_manager.currentLevel?.availableArrowCount ?? 0) == 0) {
        _onDeadlock();
      }
    } else if (_manager.lives < livesBefore) {
      // A blocked arrow cost a life.
      _audio.play(GameSound.block);
      _onLifeLost();
    }
  }

  void _onHint() {
    setState(_manager.showHint);
    _audio.play(GameSound.hint);
    if (_manager.hintArrowId == null) {
      _toast('No hint available for this board');
    }
  }

  void _onUndo() {
    if (!_manager.canUndo) {
      _toast('Nothing to undo');
      return;
    }
    setState(_manager.undo);
  }

  void _onNewBoard(DifficultyLevel difficulty) {
    setState(() => _loading = true);
    _startLevelFromDifficulty(difficulty);
  }

  Future<void> _startLevelFromDifficulty(DifficultyLevel difficulty) async {
    _stopTimer();
    await _loadLevel(difficulty);
  }

  /// Loads a level through the repository and installs it in the manager.
  /// Falls back to a guaranteed generated board if the repository path throws.
  Future<void> _loadLevel(DifficultyLevel difficulty) async {
    Level? level;
    try {
      level = await _repository.getLevelAsync(difficulty: difficulty);
    } catch (_) {
      level = null;
    }

    if (!mounted) return;
    setState(() {
      if (level != null) {
        _manager.setLevel(level);
      } else {
        _manager.startLevel(difficulty); // guaranteed fallback
      }
      _loading = false;
    });

    _audio.unloadAll();
    if (_timerLimit != Duration.zero) _startTimer();
  }

  void _onLevelComplete() {
    _stopTimer();
    _audio.play(GameSound.success);
    final completed = _levelNumber;
    final stars = _computeStars();
    widget.onLevelComplete?.call(completed);
    _showLevelCompleteDialog(completed, stars);
  }

  void _onLifeLost() {
    widget.onLifeLost?.call();
    _toast('That arrow is blocked');
  }

  void _onDeadlock() {
    _stopTimer();
    widget.onDeadlock?.call();
    _toast('Deadlock: no arrow can escape. Start a new board.');
  }

  void _onGameOver() {
    _stopTimer();
    widget.onGameOver?.call();
    _showGameOverDialog();
  }

  int _computeStars() {
    if (_manager.lives >= GameManager.startingLives) return 3;
    if (_manager.lives >= GameManager.startingLives - 1) return 2;
    return 1;
  }

  // ---------------------------------------------------------------------
  // God / Boss timers
  // ---------------------------------------------------------------------

  void _startTimer() {
    _stopTimer();
    if (_timerLimit == Duration.zero) return;
    setState(() => _remaining = _timerLimit);
    _levelTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final expired = _remaining <= const Duration(seconds: 1);
      setState(() {
        _remaining =
            expired ? Duration.zero : _remaining - const Duration(seconds: 1);
      });
      if (expired) {
        _levelTimer?.cancel();
        _onTimerExpired();
      }
    });
  }

  void _stopTimer() {
    _levelTimer?.cancel();
    _levelTimer = null;
  }

  void _onTimerExpired() {
    _audio.play(GameSound.timeLow);
    _manager.loseLife();
    setState(() {});
    _toast('Time is up');

    if (_manager.isGameOver) {
      _onGameOver();
    } else {
      _startTimer(); // fresh time for the remaining lives
    }
  }

  // ---------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _showLevelCompleteDialog(int level, int stars) async {
    final next = level + 1;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Level complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You cleared level $level.'),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  color: i < stars ? const Color(0xFFFBBF24) : Colors.grey,
                  size: 28,
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() => _levelNumber = next);
              _startLevel(next);
            },
            child: const Text('Next level'),
          ),
        ],
      ),
    );
  }

  Future<void> _showGameOverDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Game over'),
        content: Text(
          'You ran out of lives on a '
          '${_manager.getDifficultyClassification()} board.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() => _levelNumber = widget.levelNumber);
              _startLevel(_levelNumber);
            },
            child: const Text('Play again'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            if (_timerLimit != Duration.zero) _buildTimerChip(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBoardArea(),
            ),
            _buildBottomArea(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final labelColor = _isBossLevel
        ? kBoss
        : _isGodLevel
            ? kGod
            : kInk;

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: kInk),
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _levelLabel,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          if (_isGodLevel || _isBossLevel)
            Icon(
              _isBossLevel ? Icons.local_fire_department : Icons.star,
              color: labelColor,
              size: 20,
            ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(child: LivesBar(lives: _manager.lives)),
        ),
      ],
    );
  }

  String get _levelLabel {
    if (_isBossLevel) return 'BOSS Level $_levelNumber';
    if (_isGodLevel) return 'GOD Level $_levelNumber';
    return 'Level $_levelNumber';
  }

  Widget _buildTimerChip() {
    final minutes = _remaining.inMinutes;
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isBossLevel ? const Color(0xFFE0F2F1) : const Color(0xFFF3EBFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isBossLevel ? kBoss : kGod),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 6),
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStat(Icons.arrow_forward, '${_manager.moveCount}'),
          _buildStat(Icons.flag_outlined, '${_manager.currentLevel?.arrows.length ?? 0} left'),
          _buildStat(
            Icons.speed,
            _manager.currentLevel?.availableArrowCount.toString() ?? '0',
          ),
          _buildStat(Icons.star_outline, _manager.getQualityScore().toString()),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kAccent),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: kInk),
        ),
      ],
    );
  }

  Widget _buildBoardArea() {
    final grid = _manager.currentLevel?.grid;
    return LayoutBuilder(
      builder: (context, constraints) {
        double cell = 50.0;
        if (grid != null && grid.width > 0 && grid.height > 0) {
          cell = math.min(
            constraints.maxWidth / grid.width,
            constraints.maxHeight / grid.height,
          ).clamp(8.0, 120.0).toDouble();
        }

        final boardSize = Size(
          grid == null ? constraints.maxWidth : grid.width * cell,
          grid == null ? constraints.maxHeight : grid.height * cell,
        );

        return InteractiveViewer(
          minScale: 0.6,
          maxScale: 4.0,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox(
            width: boardSize.width,
            height: boardSize.height,
            child: GameBoard(
              arrows: _manager.currentLevel?.arrows ?? const [],
              grid: grid,
              selectedArrow: _manager.selectedArrow,
              hintArrowId: _manager.hintArrowId,
              onArrowSelected: _onArrowSelected,
              onArrowReleased: _onArrowReleased,
              onArrowBlocked: _onArrowBlocked,
              onUndo: _onUndo,
              onHint: _onHint,
            ),
          ),
        );
      },
    );
  }

  void _onArrowBlocked(ArrowPath arrow) {
    _toast('Blocked: clear its corridor first');
  }

  Widget _buildBottomArea() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: WavyProgressBar(progress: _clearProgress),
          ),
          const SizedBox(height: 8),
          _buildToolbar(),
          const UnifiedBannerAd(),
        ],
      ),
    );
  }

  /// Fraction of the board cleared so far, used by the wavy progress bar.
  double get _clearProgress {
    final lvl = _manager.currentLevel;
    if (lvl == null) return 0;
    final total = lvl.solutionLength;
    if (total <= 0) return 0;
    final cleared = math.max(0, total - lvl.arrows.length);
    return (cleared / total).clamp(0.0, 1.0).toDouble();
  }

  Widget _buildToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToolButton(
          icon: Icons.help_outline,
          label: 'Hint',
          onPressed: _onHint,
          badgeCount: _manager.currentLevel?.availableArrowCount ?? 0,
        ),
        _buildToolButton(
          icon: Icons.undo,
          label: 'Undo',
          onPressed: _onUndo,
        ),
        _buildToolButton(
          icon: Icons.refresh,
          label: 'New board',
          onPressed: () => _onNewBoard(_manager.currentDifficulty),
        ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    int? badgeCount,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 28, color: Colors.blueGrey),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: kDanger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
