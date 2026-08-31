import 'package:flutter/material.dart';

import '../../core/math/vector2.dart';
import '../../game/engine/game_controller.dart';
import '../../game/geometry/board_transform.dart';
import '../painters/board_painter.dart';

/// The game board widget.
///
/// Converts taps into **world coordinates** before handing them to the
/// controller, so UI pixels never leak into the physics (prompt §46).
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.controller,
    required this.showGuideDots,
    required this.debug,
    required this.repaint,
    this.onTapWorld,
  });

  final GameController controller;
  final bool showGuideDots;
  final DebugOptions debug;
  final Listenable? repaint;
  final void Function(Vec2 world)? onTapWorld;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final local = details.localPosition;
            final transform = BoardTransform.fit(
              size: size,
              gridCols: controller.level.gridCols,
              gridRows: controller.level.gridRows,
              paddingCells: controller.level.boundsPadding,
            );
            onTapWorld?.call(transform.toWorld(local));
          },
          child: CustomPaint(
            painter: BoardPainter(
              controller: controller,
              showGuideDots: showGuideDots,
              debug: debug,
            ),
            size: size,
            isComplex: true,
            willChange: false,
          ),
        );
      },
    );
  }
}
