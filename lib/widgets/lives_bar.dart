import 'package:arrows_escape_game/core/constants.dart';
import 'package:flutter/material.dart';

/// Compact row of heart icons representing the player's remaining lives.
class LivesBar extends StatelessWidget {
  const LivesBar({
    super.key,
    required this.lives,
    this.maxLives = 3,
    this.iconSize = 20,
  });

  /// Lives still available.
  final int lives;

  /// Total slots to render (filled hearts for remaining lives).
  final int maxLives;

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (index) {
        final alive = index < lives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.favorite,
            color: alive ? kDanger : Colors.grey.shade300,
            size: iconSize,
          ),
        );
      }),
    );
  }
}
