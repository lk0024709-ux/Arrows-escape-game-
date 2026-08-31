import 'package:flutter/material.dart';
import 'package:Arrows-escape-game-/lib/game/game_manager.dart';
import 'package:Arrows-escape-game-/lib/level/level_generator.dart';

void main() {
  runApp(const ArrowEscapeApp());
}

class ArrowEscapeApp extends StatelessWidget {
  const ArrowEscapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrows Escape',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Color(0xFF07164F),
        colorScheme: ColorScheme.light(
          primary: Color(0xFF2585FF),
          secondary: Color(0xFFD9DEE8),
          surface: Colors.white,
          error: Color(0xEF4444),
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Color(0xFF07164F)),
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
  late GameManager _manager;
  late LevelGenerator _generator;

  @override
  void initState() {
    super.initState();
    _manager = GameManager();
    _generator = LevelGenerator();
    _startNewLevel();
  }

  void _startNewLevel() {
    // Generate a new level using the deterministic generator
    final level = _manager.currentLevel ?? _generator.generate(
      difficulty: _manager.currentDifficulty.index + 1,
      seed: _manager.currentSeed,
    );
    _manager.setLevel(level);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top header
      appBar: _buildAppBar(context),

      body: SafeArea(
        child: Column(
          children: [
            // Status card
            _buildStatusCard(),
            // Game board
            Expanded(
              child: GameBoard(
                arrows: _manager.currentLevel?.arrows ?? [],
                grid: _manager.currentLevel?.grid,
                onArrowSelected: _onArrowSelected,
                onArrowReleased: _onArrowReleased,
                onUndo: _manager.undo,
                onHint: _manager.showHint,
                selectedArrow: _manager.selectedArrow,
                onArrowBlocked: (_) {}, // Callback for when arrow is blocked
              ),
            ),
            // Bottom toolbar
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Arrows Escape',
        style: TextStyle(
          color: Color(0xFF07164F),
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          on: () {
            // Open settings
          },
          tooltip: 'Settings',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildDifficultyBadge(),
      ),
    );
  }

  Widget _buildDifficultyBadge() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        label: Text(
          _manager.getDifficultyClassification(),
          style: const TextStyle(
            color: Color(0xFF07164F),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: _manager.getDifficultyColor(_manager.getDifficultyClassification()),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return Colors.green.shade100;
      case 'Normal':
        return Colors.blue.shade100;
      case 'Medium':
        return Colors.orange.shade100;
      case 'Hard':
        return Colors.red.shade100;
      case 'Expert':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Move counter
          _buildMoveCounter(),
          // Lives indicator
          _buildLivesIndicator(),
          // Difficulty badge (right side)
          _manager.currentLevel != null
              ? _buildDifficultyBadge()
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildMoveCounter() {
    return Row(
      children: [
        const Icon(
          Icons.arrow_forward,
          size: 20,
          color: Color(0xFF2585FF),
        ),
        const SizedBox(width: 4),
        Text(
          '↗ ${_manager.moveCount}',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF07164F),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLivesIndicator() {
    return Row(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.favorite,
            color: _manager.lives > index ? Colors.red : Colors.grey,
            size: 20,
          ),
        );
      }),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Hint button
          _buildToolButton(
            icon: Icons.help_outline,
            label: 'Hint',
            onPressed: () => _manager.showHint(),
            badgeCount: _manager.currentLevel?.availableArrowCount ?? 0,
          ),
          // Undo button
          _buildToolButton(
            icon: Icons.undo,
            label: 'Undo',
            onPressed: () => _manager.undo(),
          ),
          // Ad space (kept empty for extensibility)
          const SizedBox(width: 40),
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
                    decoration: BoxDecoration(
                      color: Colors.red,
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
    );
  }
}