import 'dart:math' as math;

import 'package:arrows_escape_game/core/constants.dart';
import 'package:flutter/material.dart';

/// An animated, wavy progress bar used to visualise level clear progress.
///
/// The fill surface is a slowly-scrolling sine wave clipped to a rounded
/// capsule, giving the "water level" effect requested for the game screen.
class WavyProgressBar extends StatefulWidget {
  const WavyProgressBar({
    super.key,
    required this.progress,
    this.height = 18,
    this.color = kAccent,
    this.backgroundColor = const Color(0xFFE9EDF5),
  });

  /// Progress in the range 0..1 (clamped internally).
  final double progress;

  final double height;

  final Color color;

  final Color backgroundColor;

  @override
  State<WavyProgressBar> createState() => _WavyProgressBarState();
}

class _WavyProgressBarState extends State<WavyProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WavyProgressPainter(
              progress: widget.progress.clamp(0.0, 1.0).toDouble(),
              color: widget.color,
              backgroundColor: widget.backgroundColor,
              phase: _controller.value * 2 * math.pi,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _WavyProgressPainter extends CustomPainter {
  _WavyProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.phase,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );

    canvas.drawRRect(rrect, Paint()..color = backgroundColor);

    if (progress <= 0) return;

    final fillWidth = size.width * progress;
    const amplitude = 3.0;
    const wavelength = 22.0;

    final wave = Path()..moveTo(0, 0);

    // Top edge: a sine wave that rises up out of the water.
    for (double x = 0; x <= fillWidth; x += 2) {
      final y = math.max(0.0, math.sin((x / wavelength) * 2 * math.pi + phase) * amplitude);
      wave.lineTo(x, y);
    }

    wave
      ..lineTo(fillWidth, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawPath(wave, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavyProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.phase != phase;
  }
}
