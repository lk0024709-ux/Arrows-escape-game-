import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'geometry/arrow_path.dart';
import 'geometry/grid.dart';
import 'geometry/grid_point.dart';

class ArrowPainter extends CustomPainter {
  final List<ArrowPath> arrows;
  final Grid? grid;
  bool showGrid = false;
  bool showDots = false;
  double cellSize = 50.0;

  ArrowPainter({
    required this.arrows,
    this.grid,
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

    // 3. Draw path shadows
    _paintPathShadows(canvas);

    // 4. Draw path bodies and arrowheads
    _paintArrowPaths(canvas);

    // 5. Draw selection glow if an arrow is selected
    // (handled externally)

    // 6. Draw debug geometry if enabled
    if (showGrid) _paintGrid(canvas);
  }

  void _paintBackground(Canvas canvas, Size size) {
    // White background
    final backgroundPaint = Paint();
    backgroundPaint.color = Colors.white;
    canvas.drawRect(Offset.zero & size, backgroundPaint);
  }

  void _paintGuideDots(Canvas canvas) {
    if (grid == null) return;

    final dotPaint = Paint();
    dotPaint.color = Color(0xFFD9DEE8); // Grey guide dot
    dotPaint.style = PaintingStyle.fill;

    // Draw dots at grid intersections
    for (int x = 0; x <= grid!.width; x++) {
      for (int y = 0; y <= grid!.height; y++) {
        final offset = Offset(x * cellSize + cellSize / 2, y * cellSize + cellSize / 2);
        canvas.drawCircle(offset, 3, dotPaint);
      }
    }
  }

  void _paintPathShadows(Canvas canvas) {
    for (final arrow in arrows) {
      _paintArrowShadow(canvas, arrow);
    }
  }

  void _paintArrowShadow(Canvas canvas, ArrowPath arrow) {
    // Draw a subtle shadow for the path
    final shadowPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = arrow.thickness + 4;

    // Draw path with rounded joins
    if (arrow.points.length >= 2) {
      final path = _buildPath(arrow);
      canvas.drawPath(path, shadowPaint);
    }
  }

  void _paintArrowPaths(Canvas canvas) {
    for (final arrow in arrows) {
      _paintSingleArrowPath(canvas, arrow);
    }
  }

  void _paintSingleArrowPath(Canvas canvas, ArrowPath arrow) {
    if (arrow.points.length < 2) return;

    final paint = Paint()
      ..color = Color(0xFF07164F) // Dark navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = arrow.thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Build the path
    final path = _buildPath(arrow);
    canvas.drawPath(path, paint);

    // Draw the arrowhead
    _drawArrowhead(canvas, arrow, paint);
  }

  Path _buildPath(ArrowPath arrow) {
    if (arrow.points.length < 2) return Path();

    final path = Path();
    final start = arrow.points.first;
    final startOffset = start.toOffset(cellSize);
    path.moveTo(startOffset.dx, startOffset.dy);

    for (int i = 1; i < arrow.points.length; i++) {
      final point = arrow.points[i];
      final offset = point.toOffset(cellSize);
      path.lineTo(offset.dx, offset.dy);
    }

    return path;
  }

  void _drawArrowhead(Canvas canvas, ArrowPath arrow, Paint paint) {
    if (arrow.points.length < 2) return;

    final start = arrow.points.last;
    final startOffset = start.toOffset(cellSize);
    final dir = arrow.direction;

    // Calculate arrowhead size based on thickness
    final headLength = arrow.thickness * 2.4;
    final headWidth = arrow.thickness * 1.8;

    // Get the direction we're heading
    final secondLast = arrow.points.length >= 2 ? arrow.points[arrow.points.length - 2] : start;
    final secondLastOffset = secondLast.toOffset(cellSize);

    // Determine arrowhead points based on direction
    final headPoints = _calculateArrowheadPoints(
      startOffset,
      secondLastOffset,
      dir,
      headLength,
      headWidth,
    );

    // Draw the arrowhead filled triangle
    final headPaint = Paint()
      ..color = Color(0xFF07164F)
      ..style = PaintingStyle.fill;

    if (headPoints.length >= 3) {
      canvas.drawPolygon(headPoints, headPaint);
    }

    // Also draw the main path line on top
    canvas.drawPath(_buildPath(arrow), paint);
  }

  List<Offset> _calculateArrowheadPoints(
    Offset start,
    Offset secondLast,
    Direction dir,
    double headLength,
    double headWidth,
  ) {
    // Calculate based on the direction of the path segment
    final dx = start.dx - secondLast.dx;
    final dy = start.dy - secondLast.dy;

    // Normalize direction
    final isHorizontal = dx.abs() > dy.abs;

    final points = <Offset>[];

    switch (dir) {
      case Direction.right:
        points.addAll([
          start, // tip
          Offset(start.dx - headWidth, start.dy - headLength ~/ 2),
          Offset(start.dx - headWidth, start.dy + headLength ~/ 2),
        ]);
        break;
      case Direction.left:
        points.addAll([
          start,
          Offset(start.dx + headWidth, start.dy - headLength ~/ 2),
          Offset(start.dx + headWidth, start.dy + headLength ~/ 2),
        ]);
        break;
      case Direction.down:
        points.addAll([
          start,
          Offset(start.dx - headLength ~/ 2, start.dy + headWidth),
          Offset(start.dx + headLength ~/ 2, start.dy + headWidth),
        ]);
        break;
      case Direction.up:
        points.addAll([
          start,
          Offset(start.dx - headLength ~/ 2, start.dy - headWidth),
          Offset(start.dx + headLength ~/ 2, start.dy - headWidth),
        ]);
        break;
    }

    return points;
  }

  void _paintGrid(Canvas canvas) {
    if (grid == null) return;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int x = 0; x <= grid!.width; x++) {
      final start = Offset(x * cellSize, 0);
      final end = Offset(x * cellSize, cellSize * grid!.height);
      canvas.drawLine(start, end, gridPaint);
    }

    for (int y = 0; y <= grid!.height; y++) {
      final start = Offset(0, y * cellSize);
      final end = Offset(cellSize * grid!.width, y * cellSize);
      canvas.drawLine(start, end, gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}