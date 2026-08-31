import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/math/vector2.dart';

/// World ↔ screen mapping for the board (prompt §45).
///
/// World units are grid cells. UI code never performs physics in screen space:
/// taps are converted with [toWorld] and drawing converts with [toScreen].
class BoardTransform {
  BoardTransform({
    required this.cellSize,
    required this.originX,
    required this.originY,
  });

  /// Pixels per world unit (grid cell).
  final double cellSize;
  final double originX;
  final double originY;

  /// Fits the logical grid (plus its padding) inside [size].
  factory BoardTransform.fit({
    required Size size,
    required int gridCols,
    required int gridRows,
    double paddingCells = 1.0,
  }) {
    final worldWidth = gridCols - 1 + paddingCells * 2;
    final worldHeight = gridRows - 1 + paddingCells * 2;
    final cell = math.min(size.width / worldWidth, size.height / worldHeight);
    return BoardTransform(
      cellSize: cell,
      originX: (size.width - worldWidth * cell) / 2 + paddingCells * cell,
      originY: (size.height - worldHeight * cell) / 2 + paddingCells * cell,
    );
  }

  Offset toScreen(Vec2 world) =>
      Offset(originX + world.x * cellSize, originY + world.y * cellSize);

  Vec2 toWorld(Offset screen) =>
      Vec2((screen.dx - originX) / cellSize, (screen.dy - originY) / cellSize);

  Offset toScreenPoint(double worldX, double worldY) =>
      Offset(originX + worldX * cellSize, originY + worldY * cellSize);

  double get thicknessInPixelsHint => cellSize;
}
