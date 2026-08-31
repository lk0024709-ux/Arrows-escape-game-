import 'package:arrows_escape_game/game/game_manager.dart';
import 'package:arrows_escape_game/geometry/arrow_path.dart';
import 'package:arrows_escape_game/level/difficulty.dart';
import 'package:arrows_escape_game/widgets/game_board.dart';
import 'package:flutter/material.dart';

const Color kInk = Color(0xFF07164F);
const Color kAccent = Color(0xFF2585FF);
const Color kDanger = Color(0xFFEF4444);
const Color kMuted = Color(0xFFD9DEE8);

void main() {
  runApp(const ArrowEscapeApp());
}

class ArrowEscapeApp extends StatelessWidget {
  const ArrowEscapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrows Escape',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: kInk,
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent).copyWith(
          secondary: kMuted,
          surface: Colors.white,
          error: kDanger,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: kInk),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameManager _manager = GameManager();

  @override
  void initState() {
    super.initState();
    _manager.startLevel(DifficultyLevel.normal);
  }

  void _onArrowSelected(ArrowPath arrow) {
    setState(() => _manager.onArrowSelected(arrow));
  }

  void _onArrowReleased(ArrowPath arrow) {
    final before = _manager.currentDifficulty;
    final livesBefore = _manager.lives;

    setState(() => _manager.onArrowReleased(arrow));

    if (_manager.isGameOver) {
      _showGameOver();
    } else if (_manager.currentDifficulty != before) {
      _toast('Level cleared - moving up to ${_manager.currentDifficulty.name}');
    } else if (_manager.lives < livesBefore) {
      _toast('That arrow is blocked');
    }
  }

  void _onArrowBlocked(ArrowPath arrow) {
    _toast('Blocked: clear its corridor first');
  }

  void _onHint() {
    setState(_manager.showHint);
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

  void _onNewBoard(DifficultyLevel level) {
    setState(() => _manager.startLevel(level));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _showGameOver() async {
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
              _onNewBoard(_manager.currentDifficulty);
            },
            child: const Text('Play again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = _manager.currentLevel;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusCard(),
            Expanded(
              child: GameBoard(
                arrows: level?.arrows ?? const [],
                grid: level?.grid,
                selectedArrow: _manager.selectedArrow,
                hintArrowId: _manager.hintArrowId,
                onArrowSelected: _onArrowSelected,
                onArrowReleased: _onArrowReleased,
                onArrowBlocked: _onArrowBlocked,
                onUndo: _onUndo,
                onHint: _onHint,
              ),
            ),
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'Arrows Escape',
        style: TextStyle(
          color: kInk,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        PopupMenuButton<DifficultyLevel>(
          icon: const Icon(Icons.settings, color: kInk),
          tooltip: 'Difficulty',
          onSelected: _onNewBoard,
          itemBuilder: (context) => DifficultyLevel.values
              .map((level) => PopupMenuItem<DifficultyLevel>(
                    value: level,
                    child: Text(_capitalise(level.name)),
                  ))
              .toList(),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildDifficultyBadge(),
      ),
    );
  }

  Widget _buildDifficultyBadge() {
    final classification = _manager.getDifficultyClassification();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        label: Text(
          classification,
          style: const TextStyle(
            color: kInk,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: _manager.getDifficultyColor(classification),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
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
          _buildMoveCounter(),
          _buildLivesIndicator(),
          _buildClearCount(),
        ],
      ),
    );
  }

  Widget _buildMoveCounter() {
    return Row(
      children: [
        const Icon(Icons.arrow_forward, size: 20, color: kAccent),
        const SizedBox(width: 4),
        Text(
          '${_manager.moveCount}',
          style: const TextStyle(
            fontSize: 16,
            color: kInk,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLivesIndicator() {
    return Row(
      children: List.generate(GameManager.startingLives, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.favorite,
            color: _manager.lives > index ? kDanger : Colors.grey,
            size: 20,
          ),
        );
      }),
    );
  }

  Widget _buildClearCount() {
    final remaining = _manager.currentLevel?.arrows.length ?? 0;
    return Row(
      children: [
        const Icon(Icons.flag_outlined, size: 20, color: kInk),
        const SizedBox(width: 4),
        Text(
          '$remaining left',
          style: const TextStyle(fontSize: 14, color: kInk),
        ),
      ],
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      height: 64,
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
      child: Row(
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
      ),
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

  String _capitalise(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
