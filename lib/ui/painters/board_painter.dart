import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/geometry/geometry.dart';
import '../../game/engine/game_controller.dart';
import '../../game/generator/dependency_graph.dart';
import '../../game/geometry/arrow_geometry.dart';
import '../../game/geometry/board_transform.dart';
import '../../game/model/direction.dart';
import '../../game/model/level.dart';
import '../../game/model/path_arrow.dart';
import '../../theme/app_theme.dart';

/// Toggles for the developer debug overlay (prompt §56).
class DebugOptions {
  const DebugOptions({
    this.showGrid = false,
    this.showNodesDebug = false,
    this.showPathPoints = false,
    this.showHitboxes = false,
    this.showCorridors = false,
    this.showRaycasts = false,
    this.showDependency = false,
    this.showSolution = false,
  });

  final bool showGrid;
  final bool showNodesDebug;
  final bool showPathPoints;
  final bool showHitboxes;
  final bool showCorridors;
  final bool showRaycasts;
  final bool showDependency;
  final bool showSolution;

  DebugOptions copyWith({
    bool? showGrid,
    bool? showNodesDebug,
    bool? showPathPoints,
    bool? showHitboxes,
    bool? showCorridors,
    bool? showRaycasts,
    bool? showDependency,
    bool? showSolution,
  }) =>
      DebugOptions(
        showGrid: showGrid ?? this.showGrid,
        showNodesDebug: showNodesDebug ?? this.showNodesDebug,
        showPathPoints: showPathPoints ?? this.showPathPoints,
        showHitboxes: showHitboxes ?? this.showHitboxes,
        showCorridors: showCorridors ?? this.showCorridors,
        showRaycasts: showRaycasts ?? this.showRaycasts,
        showDependency: showDependency ?? this.showDependency,
        showSolution: showSolution ?? this.showSolution,
      );

  bool get anyEnabled =>
      showGrid ||
      showNodesDebug ||
      showPathPoints ||
      showHitboxes ||
      showCorridors ||
      showRaycasts ||
      showDependency ||
      showSolution;
}

/// The board renderer (prompt §40, §41).
///
/// Render order:
/// background → guide nodes → path shadows → path bodies → arrow heads →
/// selection glow → escape effects → debug geometry
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.controller,
    required this.showGuideDots,
    required this.debug,
    DateTime? now,
  }) : _now = now;

  final GameController controller;
  final bool showGuideDots;
  final DebugOptions debug;
  final DateTime? _now;

  DateTime get now => _now ?? DateTime.now();

  /// Latest transform, cached so the shake helper can use the cell size.
  BoardTransform _transform = BoardTransform(cellSize: 24, originX: 0, originY: 0);

  @override
  void paint(Canvas canvas, Size size) {
    final level = controller.level;
    final transform = BoardTransform.fit(
      size: size,
      gridCols: level.gridCols,
      gridRows: level.gridRows,
      paddingCells: level.boundsPadding,
    );
    _transform = transform;

    // 1 — background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.background,
    );

    // 2 — guide nodes (the invisible construction grid)
    if (showGuideDots) {
      _drawGuideNodes(canvas, level, transform, debugOnly: false);
    } else if (debug.showNodesDebug) {
      _drawGuideNodes(canvas, level, transform, debugOnly: true);
    }
    if (debug.showGrid) _drawGrid(canvas, level, transform);

    final active = <int>[
      for (var i = 0; i < level.arrows.length; i++)
        if (!controller.state.isRemovedAt(i)) i,
    ];

    // 3 — shadows
    for (final i in active) {
      _drawPath(canvas, level, i, transform, shadow: true);
    }
    // 4/5 — bodies + heads
    for (final i in active) {
      _drawPath(canvas, level, i, transform, shadow: false);
      _drawHead(canvas, level, i, transform);
    }

    // 7 — escaping arrows (already removed from the logical state)
    for (final animation in controller.animations) {
      if (animation.isDone(now)) continue;
      _drawEscaping(canvas, level, animation, transform);
    }

    // 8 — debug geometry
    if (debug.showCorridors) _drawCorridors(canvas, level, transform);
    if (debug.showRaycasts) _drawRaycasts(canvas, level, transform);
    if (debug.showDependency) _drawDependency(canvas, level, transform);
    if (debug.showHitboxes) _drawHitboxes(canvas, level, transform);
    if (debug.showPathPoints) _drawPathPoints(canvas, level, transform);
    if (debug.showSolution) _drawSolution(canvas, level, transform);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.showGuideDots != showGuideDots ||
      oldDelegate.debug != debug ||
      true; // animations require a repaint each frame while active

  // ---------------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------------

  void _drawGuideNodes(
    Canvas canvas,
    Level level,
    BoardTransform transform, {
    required bool debugOnly,
  }) {
    final radius = math.max(0.8, transform.cellSize * (debugOnly ? 0.09 : 0.055));
    final paint = Paint()
      ..color = (debugOnly ? AppColors.textMuted : AppColors.guideDot)
          .withValues(alpha: AppBoardTheme.guideDotOpacity)
      ..style = PaintingStyle.fill;
    for (var row = 0; row < level.gridRows; row++) {
      for (var col = 0; col < level.gridCols; col++) {
        final p = transform.toScreenPoint(col.toDouble(), row.toDouble());
        canvas.drawCircle(p, radius, paint);
      }
    }
  }

  void _drawGrid(Canvas canvas, Level level, BoardTransform transform) {
    final paint = Paint()
      ..color = AppColors.blueAccent.withValues(alpha: AppBoardTheme.debugGridOpacity)
      ..strokeWidth = 1;
    for (var c = 0; c < level.gridCols; c++) {
      final a = transform.toScreenPoint(c.toDouble(), 0);
      final b = transform.toScreenPoint(c.toDouble(), (level.gridRows - 1).toDouble());
      canvas.drawLine(a, b, paint);
    }
    for (var r = 0; r < level.gridRows; r++) {
      final a = transform.toScreenPoint(0, r.toDouble());
      final b = transform.toScreenPoint((level.gridCols - 1).toDouble(), r.toDouble());
      canvas.drawLine(a, b, paint);
    }
  }

  PathArrow _animatedArrow(int index) {
    final base = controller.level.arrows[index];
    return base.withOffset(controller.offsetFor(index, now: now));
  }

  List<Offset> _screenPoints(PathArrow arrow, BoardTransform transform) => [
        for (final p in arrow.worldPoints) transform.toScreen(p),
      ];

  /// Shake offset for a blocked arrow (prompt §43).
  Offset _shakeFor(PathArrow arrow) {
    final blockedIndex = controller.blockedIndex;
    final blockedAt = controller.blockedAt;
    if (blockedIndex == null || blockedAt == null) return Offset.zero;
    final indexOfArrow = controller.level.arrows.indexWhere((a) => a.id == arrow.id);
    if (blockedIndex != indexOfArrow) return Offset.zero;
    final elapsed = now.difference(blockedAt).inMilliseconds;
    const duration = 420.0;
    if (elapsed > duration) return Offset.zero;
    final t = elapsed / duration;
    final decay = 1 - t;
    final amplitude = _transform.cellSize * 0.16 * decay;
    final shake = math.sin(t * 46) * amplitude;
    return arrow.direction.isHorizontal
        ? Offset(shake, 0)
        : Offset(0, shake);
  }

  void _drawPath(
    Canvas canvas,
    Level level,
    int index,
    BoardTransform transform, {
    required bool shadow,
  }) {
    final arrow = _animatedArrow(index);
    final points = _screenPoints(arrow, transform);
    if (points.length < 2) return;

    final isBlocked = controller.blockedIndex == index &&
        controller.blockedAt != null &&
        now.difference(controller.blockedAt!).inMilliseconds < 420;
    final isSelected = controller.selectedIndex == index;
    final isHinted = controller.hintIndex == index;
    final isError = controller.status == GameStatus.stuck && isBlocked;

    final offset = isBlocked ? _shakeFor(arrow) : Offset.zero;
    canvas.save();
    if (offset != Offset.zero) canvas.translate(offset.dx, offset.dy);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (shadow) {
      canvas.save();
      canvas.translate(0, math.max(1.0, transform.cellSize * 0.045));
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primaryNavy.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = arrow.metrics.thickness * transform.cellSize
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
      canvas.restore();
      return;
    }

    // Selection / hint glow (§42)
    if (isSelected || isHinted) {
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.blueAccent.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = arrow.metrics.thickness * transform.cellSize * 1.7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final paint = Paint()
      ..color = isError
          ? AppColors.error
          : isHinted
              ? AppColors.blueAccent
              : isSelected
                  ? const Color(0xFF12307A)
                  : AppColors.primaryNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = arrow.metrics.thickness * transform.cellSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isSelected || isHinted) {
      paint.maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        transform.cellSize * (isHinted ? 0.7 : 0.35),
      );
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawHead(
    Canvas canvas,
    Level level,
    int index,
    BoardTransform transform,
  ) {
    final arrow = _animatedArrow(index);
    final triangle = ArrowGeometry.headTriangle(arrow);
    final a = transform.toScreen(triangle.a);
    final b = transform.toScreen(triangle.b);
    final c = transform.toScreen(triangle.c);

    final isBlocked = controller.blockedIndex == index &&
        controller.blockedAt != null &&
        now.difference(controller.blockedAt!).inMilliseconds < 420;
    final isSelected = controller.selectedIndex == index;
    final isHinted = controller.hintIndex == index;

    final offset = isBlocked ? _shakeFor(arrow) : Offset.zero;
    canvas.save();
    if (offset != Offset.zero) canvas.translate(offset.dx, offset.dy);

    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = (controller.status == GameStatus.stuck && isBlocked)
            ? AppColors.error
            : isHinted
                ? AppColors.blueAccent
                : isSelected
                    ? const Color(0xFF12307A)
                    : AppColors.primaryNavy
        ..style = PaintingStyle.fill,
    );
    // Soften the head corners with a thin round-join stroke.
    canvas.drawPath(
      path,
      Paint()
        ..color = (controller.status == GameStatus.stuck && isBlocked)
            ? AppColors.error
            : isHinted
                ? AppColors.blueAccent
                : isSelected
                    ? const Color(0xFF12307A)
                    : AppColors.primaryNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _drawEscaping(
    Canvas canvas,
    Level level,
    MoveAnimation animation,
    BoardTransform transform,
  ) {
    final progress = animation.progress(now);
    final eased = 1 - GameController.pow3(1 - progress);
    final arrow = animation.arrow
        .withOffset(animation.from + (animation.to - animation.from) * eased);
    final points = _screenPoints(arrow, transform);
    if (points.length < 2) return;

    final alpha = progress < 0.6 ? 1.0 : 1 - (progress - 0.6) / 0.4;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Blue trail (§44)
    final trail = Paint()
      ..shader = ui.Gradient.linear(
        points.first,
        points.last,
        [
          AppColors.blueAccent.withValues(alpha: 0),
          AppColors.blueAccent.withValues(alpha: 0.55),
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = arrow.metrics.thickness * transform.cellSize * 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, trail);

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.blueAccent.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = arrow.metrics.thickness * transform.cellSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final triangle = ArrowGeometry.headTriangle(arrow);
    final a = transform.toScreen(triangle.a);
    final b = transform.toScreen(triangle.b);
    final c = transform.toScreen(triangle.c);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..close(),
      Paint()..color = AppColors.blueAccent.withValues(alpha: alpha),
    );

    // Particle burst at the moment of exit (§44)
    if (progress > 0.82) {
      final burst = (progress - 0.82) / 0.18;
      final centre = points.last;
      final particlePaint = Paint()
        ..color = AppColors.blueAccent.withValues(alpha: (1 - burst) * 0.8);
      for (var i = 0; i < 8; i++) {
        final angle = (i / 8) * math.pi * 2;
        final distance = burst * transform.cellSize * 0.55;
        canvas.drawCircle(
          centre + Offset(math.cos(angle) * distance, math.sin(angle) * distance),
          transform.cellSize * 0.05 * (1 - burst),
          particlePaint,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Debug overlays
  // ---------------------------------------------------------------------------

  void _drawHitboxes(Canvas canvas, Level level, BoardTransform transform) {
    final index = controller.collisionIndex;
    final paint = Paint()
      ..color = AppColors.error.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final i in index.activeIndices) {
      for (final part in index.partsOf(i)) {
        canvas.drawRect(_rectOf(part, transform), paint);
      }
    }
  }

  void _drawCorridors(Canvas canvas, Level level, BoardTransform transform) {
    final index = controller.collisionIndex;
    final paint = Paint()..color = AppColors.blueAccent.withValues(alpha: 0.10);
    for (final i in index.activeIndices) {
      final arrow = level.arrows[i].withOffset(controller.state.offsetAt(i));
      final corridor = EscapeCorridor.toBoardEdge(
        index.boundsOf(i),
        arrow.direction,
        level.playBounds,
      );
      canvas.drawRect(_rectOf(corridor, transform), paint);
    }
  }

  void _drawRaycasts(Canvas canvas, Level level, BoardTransform transform) {
    final index = controller.collisionIndex;
    final paint = Paint()
      ..color = AppColors.warning.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    for (final i in index.activeIndices) {
      final arrow = level.arrows[i].withOffset(controller.state.offsetAt(i));
      final bounds = index.boundsOf(i);
      final reach = EscapeCorridor.exitDistance(
        bounds,
        arrow.direction,
        level.playBounds,
      );
      final from = transform.toScreenPoint(bounds.centerX, bounds.centerY);
      final to = transform.toScreenPoint(
        bounds.centerX + arrow.direction.dx * reach,
        bounds.centerY + arrow.direction.dy * reach,
      );
      canvas.drawLine(from, to, paint);
    }
  }

  void _drawDependency(Canvas canvas, Level level, BoardTransform transform) {
    final graph = DependencyGraphHolder.computeFor(controller);
    final index = controller.collisionIndex;
    final line = Paint()
      ..color = AppColors.success.withValues(alpha: 0.85)
      ..strokeWidth = 1.4;
    final dot = Paint()..color = AppColors.success.withValues(alpha: 0.85);
    for (final i in index.activeIndices) {
      final to = transform.toScreenPoint(
        index.boundsOf(i).centerX,
        index.boundsOf(i).centerY,
      );
      for (final j in graph.blockers[i]) {
        if (controller.state.isRemovedAt(j)) continue;
        final from = transform.toScreenPoint(
          index.boundsOf(j).centerX,
          index.boundsOf(j).centerY,
        );
        canvas.drawLine(from, to, line);
      }
      canvas.drawCircle(to, 3, dot);
    }
  }

  void _drawPathPoints(Canvas canvas, Level level, BoardTransform transform) {
    final index = controller.collisionIndex;
    for (final i in index.activeIndices) {
      final arrow = level.arrows[i].withOffset(controller.state.offsetAt(i));
      final points = arrow.worldPoints;
      for (var k = 0; k < points.length; k++) {
        canvas.drawCircle(
          transform.toScreen(points[k]),
          3.2,
          Paint()
            ..color = k == 0 ? AppColors.warning : AppColors.success,
        );
      }
    }
  }

  void _drawSolution(Canvas canvas, Level level, BoardTransform transform) {
    final graph = DependencyGraphHolder.computeFor(controller);
    final order = graph
        .topologicalEscapeOrder()
        .where((i) => !controller.state.isRemovedAt(i))
        .toList();
    if (order.isEmpty) return;
    final index = controller.collisionIndex;
    for (var rank = 0; rank < order.length; rank++) {
      final centre = transform.toScreenPoint(
        index.boundsOf(order[rank]).centerX,
        index.boundsOf(order[rank]).centerY,
      );
      final radius = math.max(8.0, transform.cellSize * 0.36);
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = AppColors.blueAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rank + 1}',
          style: TextStyle(
            color: AppColors.primaryNavy,
            fontSize: math.max(9, transform.cellSize * 0.42),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        centre - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  Rect _rectOf(Aabb box, BoardTransform transform) {
    final topLeft = transform.toScreenPoint(box.left, box.top);
    final bottomRight = transform.toScreenPoint(box.right, box.bottom);
    return Rect.fromPoints(topLeft, bottomRight);
  }
}

/// Small cache so the debug overlays do not recompute the graph every frame.
///
/// An [Expando] is used instead of a [Map] so that entry keys are held weakly:
/// a fresh [GameController] is created for every level, and a plain map keyed on
/// the controller would retain every board the player has ever visited.
class DependencyGraphHolder {
  static final Expando<(BoardState, DependencyGraph)> _cache =
      Expando<(BoardState, DependencyGraph)>('DependencyGraphHolder');

  static DependencyGraph computeFor(GameController controller) {
    final cached = _cache[controller];
    if (cached != null && cached.$1.key == controller.state.key) {
      return cached.$2;
    }
    final graph = DependencyGraph.compute(controller.level, controller.state);
    _cache[controller] = (controller.state, graph);
    return graph;
  }
}
