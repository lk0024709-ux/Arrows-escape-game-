import 'package:arrows_escape_game/geometry/arrow_path.dart';
import 'package:arrows_escape_game/geometry/grid.dart';
import 'package:flutter/material.dart';

/// Paints the guide dots, arrow bodies and arrowheads onto the board canvas.
class ArrowPainter extends CustomPainter {
  static const Color background = Colors.white;
  static const Color guideDot = Color(0xFFD9DEE8);
  static const Color ink = Color(0xFF07164F);
  static const Color highlight = Color(0xFF2585FF);

  final List<ArrowPath> arrows;
  final Grid? grid;
  final String? selectedArrowId;
  final String? hintArrowId;
  final bool showGrid;
  final bool showDots;
  final double cellSize;

  ArrowPainter({
    required this.arrows,
    this.grid,
    this.selectedArrowId,
    this.hintArrowId,
    this.showGrid = false,
    this.showDots = false,
    this.cellSize = 50.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw background
    _paintBackground(canvas, size);

    // 2. Draw guide nodes (grey dots) if enabled
    if (showDots) _paintGuideDots(canvas);

    // 3. Draw debug geometry if enabled
    if (showGrid) _paintGrid(canvas);

    // 4. Draw path shadows
    _paintPathShadows(canvas);

    // 5. Draw path bodies and arrowheads
    _paintArrowPaths(canvas);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, backgroundPaint);
  }

  void _paintGuideDots(Canvas canvas) {
    final board = grid;
    if (board == null) return;

    final dotPaint = Paint()
      ..color = guideDot
      ..style = PaintingStyle.fill;

    for (int x = 0; x < board.width; x++) {
      for (int y = 0; y < board.height; y++) {
        final offset = Offset(
          x * cellSize + cellSize / 2,
          y * cellSize + cellSize / 2,
        );
        canvas.drawCircle(offset, 3, dotPaint);
      }
    }
  }

  void _paintPathShadows(Canvas canvas) {
    final shadowPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final arrow in arrows) {
      if (arrow.points.length < 2) continue;
      shadowPaint.strokeWidth = arrow.thickness + 4;
      canvas.drawPath(_buildPath(arrow), shadowPaint);
    }
  }

  void _paintArrowPaths(Canvas canvas) {
    for (final arrow in arrows) {
      _paintSingleArrowPath(canvas, arrow);
    }
  }

  void _paintSingleArrowPath(Canvas canvas, ArrowPath arrow) {
    if (arrow.points.length < 2) return;

    final isSelected = arrow.id == selectedArrowId;
    final isHinted = arrow.id == hintArrowId;
    final color = isSelected || isHinted ? highlight : ink;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = arrow.thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(_buildPath(arrow), paint);
    _drawArrowhead(canvas, arrow, color);
  }

  Path _buildPath(ArrowPath arrow) {
    final path = Path();
    if (arrow.points.isEmpty) return path;

    final startOffset = arrow.points.first.toOffset(cellSize);
    path.moveTo(startOffset.dx, startOffset.dy);

    for (int i = 1; i < arrow.points.length; i++) {
      final offset = arrow.points[i].toOffset(cellSize);
      path.lineTo(offset.dx, offset.dy);
    }
    return path;
  }

  void _drawArrowhead(Canvas canvas, ArrowPath arrow, Color color) {
    final tip = arrow.points.last.toOffset(cellSize);
    final headPoints = _calculateArrowheadPoints(
      tip,
      arrow.direction,
      arrow.thickness * 2.4,
      arrow.thickness * 1.8,
    );
    if (headPoints.length < 3) return;

    final head = Path()..moveTo(headPoints.first.dx, headPoints.first.dy);
    for (final point in headPoints.skip(1)) {
      head.lineTo(point.dx, point.dy);
    }
    head.close();

    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  List<Offset> _calculateArrowheadPoints(
    Offset start,
    Direction dir,
    double headLength,
    double headWidth,
  ) {
    final halfLength = headLength / 2;
    final halfWidth = headWidth / 2;

    switch (dir) {
      case Direction.right:
        return [
          start,
          Offset(start.dx - headLength, start.dy - halfWidth),
          Offset(start.dx - headLength, start.dy + halfWidth),
        ];
      case Direction.left:
        return [
          start,
          Offset(start.dx + headLength, start.dy - halfWidth),
          Offset(start.dx + headLength, start.dy + halfWidth),
        ];
      case Direction.down:
        return [
          start,
          Offset(start.dx - halfWidth, start.dy - headLength),
          Offset(start.dx + halfWidth, start.dy - headLength),
        ];
      case Direction.up:
        return [
          start,
          Offset(start.dx - halfWidth, start.dy + headLength),
          Offset(start.dx + halfWidth, start.dy + headLength),
        ];
    }
  }

  void _paintGrid(Canvas canvas) {
    final board = grid;
    if (board == null) return;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int x = 0; x <= board.width; x++) {
      canvas.drawLine(
        Offset(x * cellSize, 0),
        Offset(x * cellSize, cellSize * board.height),
        gridPaint,
      );
    }

    for (int y = 0; y <= board.height; y++) {
      canvas.drawLine(
        Offset(0, y * cellSize),
        Offset(cellSize * board.width, y * cellSize),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArrowPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.grid != grid ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.selectedArrowId != selectedArrowId ||
        oldDelegate.hintArrowId != hintArrowId ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDots != showDots;
  }
}
