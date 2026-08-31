import 'package:flutter/material.dart';
import 'geometry/arrow_path.dart';
import 'level/level.dart';
import 'rendering/arrow_painter.dart';

class GameBoard extends StatefulWidget {
  final List<ArrowPath> arrows;
  final Grid? grid;
  final ValueChanged<ArrowPath> onArrowSelected;
  final ValueChanged<ArrowPath> onArrowReleased;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final ArrowPath? selectedArrow;
  final Function(ArrowPath) onArrowBlocked;

  const GameBoard({
    required this.arrows,
    this.grid,
    required this.onArrowSelected,
    required this.onArrowReleased,
    required this.onUndo,
    required this.onHint,
    this.selectedArrow,
    required this.onArrowBlocked,
    Key? key,
  }) : super(key: key);

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  late TapGestureRecognizer _tapRecognizer;
  double _cellSize = 50.0;
  Offset? _tapDownPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()
      ..onTapDown = _onTapDown
      ..onTapUp = _onTapUp
      ..onTapCancel = _onTapCancel
      ..onTap = _onTap;
  }

  @override
  void dispose() {
    _tapRecognizer.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _tapDownPosition = details.localPosition;
    _isDragging = false;
  }

  void _onTapUp(TapUpDetails details) {
    if (_tapDownPosition != null) {
      final dx = details.localPosition.dx - _tapDownPosition!.dx;
      final dy = details.localPosition.dy - _tapDownPosition!.dy;
      final distance = sqrt(dx * dx + dy * dy);
      
      // If tap was very small, treat as selection
      if (distance < 10) {
        _onTap();
      }
    }
    _tapDownPosition = null;
  }

  void _onTapCancel() {
    _tapDownPosition = null;
  }

  void _onTap() {
    // Find which arrow was tapped
    final hitTestResult = _findArrowAtPosition(_tapDownPosition!);
    if (hitTestResult != null && hitTestResult.id != 'none') {
      widget.onArrowSelected(hitTestResult);
    } else {
      // Deselect if tapping on empty space
      widget.onArrowSelected(ArrowPath(
        id: 'none',
        points: [],
        direction: Direction.right,
      ));
    }
  }

  ArrowPath? _findArrowAtPosition(Offset position) {
    // Find the arrow at the given position using hit-testing
    for (final arrow in widget.arrows) {
      if (arrow.containsPoint(position, 15.0)) {
        return arrow;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Get cell size based on available space
    final size = MediaQuery.of(context).size;
    final boardWidth = size.width - 40; // margin
    final boardHeight = size.height - 200; // account for UI
    _cellSize = min(boardWidth / 12, boardHeight / 16); // based on typical grid size

    return CustomPaint(
      painter: ArrowPainter(
        arrows: widget.arrows,
        grid: widget.grid,
        cellSize: _cellSize,
        showGrid: false,
        showDots: false,
      ),
      size: Size.infinite,
    );
  }
}