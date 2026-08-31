import 'dart:math';

import 'package:arrows_escape_game/geometry/arrow_path.dart';
import 'package:arrows_escape_game/geometry/grid.dart';
import 'package:arrows_escape_game/geometry/grid_point.dart';
import 'package:arrows_escape_game/rendering/arrow_painter.dart';
import 'package:flutter/material.dart';

/// Interactive board: hit-tests taps against arrow paths and reports them.
class GameBoard extends StatefulWidget {
  final List<ArrowPath> arrows;
  final Grid? grid;
  final ValueChanged<ArrowPath> onArrowSelected;
  final ValueChanged<ArrowPath> onArrowReleased;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final ArrowPath? selectedArrow;
  final ValueChanged<ArrowPath> onArrowBlocked;

  /// Id of the arrow the hint should highlight, if any.
  final String? hintArrowId;

  const GameBoard({
    required this.arrows,
    this.grid,
    required this.onArrowSelected,
    required this.onArrowReleased,
    required this.onUndo,
    required this.onHint,
    this.selectedArrow,
    required this.onArrowBlocked,
    this.hintArrowId,
    super.key,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  static const double _tapSlop = 10.0;
  static const double _hitTolerance = 18.0;

  double _cellSize = 50.0;
  Offset? _tapDownPosition;
  ArrowPath? _pressedArrow;

  void _onTapDown(TapDownDetails details) {
    _tapDownPosition = details.localPosition;
    _pressedArrow = _findArrowAtPosition(details.localPosition);
  }

  void _onTapUp(TapUpDetails details) {
    final downPosition = _tapDownPosition;
    final pressed = _pressedArrow;
    _tapDownPosition = null;
    _pressedArrow = null;

    if (downPosition == null) return;

    final dx = details.localPosition.dx - downPosition.dx;
    final dy = details.localPosition.dy - downPosition.dy;
    final distance = sqrt(dx * dx + dy * dy);

    // A drag away from the press point cancels the tap.
    if (distance >= _tapSlop) return;

    if (pressed == null) {
      // Tapped empty space: clear the selection.
      widget.onArrowSelected(_emptyArrow);
      return;
    }

    if (pressed.state == ArrowState.blocked) {
      widget.onArrowBlocked(pressed);
      return;
    }

    if (widget.selectedArrow?.id == pressed.id) {
      // Second tap on the selected arrow sends it off.
      widget.onArrowReleased(pressed);
    } else {
      widget.onArrowSelected(pressed);
    }
  }

  void _onTapCancel() {
    _tapDownPosition = null;
    _pressedArrow = null;
  }

  /// Sentinel used to tell the parent "nothing was hit". It never reaches the
  /// board because its id is not on any level.
  static final ArrowPath _emptyArrow = ArrowPath(
    id: 'none',
    points: const [GridPoint(0, 0), GridPoint(0, 0)],
    direction: Direction.right,
  );

  ArrowPath? _findArrowAtPosition(Offset position) {
    for (final arrow in widget.arrows) {
      if (arrow.containsPoint(position, _cellSize, tolerance: _hitTolerance)) {
        return arrow;
      }
    }
    return null;
  }

  /// Largest cell size that fits the logical grid inside [constraints].
  double _cellSizeFor(BoxConstraints constraints) {
    final grid = widget.grid;
    if (grid == null) return 50.0;

    final byWidth = constraints.maxWidth / grid.width;
    final byHeight = constraints.maxHeight / grid.height;
    return max(8.0, min(byWidth, byHeight));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _cellSize = _cellSizeFor(constraints);
        final grid = widget.grid;
        final boardWidth = grid == null
            ? constraints.maxWidth
            : min(constraints.maxWidth, grid.width * _cellSize);
        final boardHeight = grid == null
            ? constraints.maxHeight
            : min(constraints.maxHeight, grid.height * _cellSize);

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onLongPress: widget.onHint,
            child: SizedBox(
              width: boardWidth,
              height: boardHeight,
              child: CustomPaint(
                painter: ArrowPainter(
                  arrows: widget.arrows,
                  grid: grid,
                  cellSize: _cellSize,
                  selectedArrowId: widget.selectedArrow?.id,
                  hintArrowId: widget.hintArrowId,
                  showGrid: false,
                  showDots: false,
                ),
                size: Size(boardWidth, boardHeight),
              ),
            ),
          ),
        );
      },
    );
  }
}
