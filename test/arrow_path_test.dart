import 'package:arrows_escape_game/geometry/arrow_path.dart';
import 'package:arrows_escape_game/geometry/grid.dart';
import 'package:arrows_escape_game/geometry/grid_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArrowPath', () {
    test('calculateDirection follows the final segment', () {
      final bent = <GridPoint>[
        const GridPoint(1, 1),
        const GridPoint(5, 1),
        const GridPoint(5, 4),
      ];
      expect(ArrowPath.calculateDirection(bent), Direction.down);

      final straight = <GridPoint>[const GridPoint(3, 3), const GridPoint(0, 3)];
      expect(ArrowPath.calculateDirection(straight), Direction.left);
    });

    test('isValidDirection agrees with the tip', () {
      final arrow = ArrowPath(
        id: 'a',
        points: const [GridPoint(1, 1), GridPoint(4, 1)],
        direction: Direction.right,
      );
      expect(arrow.isValidDirection, isTrue);

      final mismatched = ArrowPath(
        id: 'b',
        points: const [GridPoint(4, 1), GridPoint(1, 1)],
        direction: Direction.right, // head is to the left of the tail
      );
      expect(mismatched.isValidDirection, isFalse);
    });

    test('occupiedCells walks every covered cell', () {
      final arrow = ArrowPath(
        id: 'a',
        points: const [GridPoint(0, 0), GridPoint(3, 0)],
        direction: Direction.right,
      );
      final cells = arrow.occupiedCells;
      expect(cells.map((p) => p.x).toSet(), {0, 1, 2, 3});
      expect(cells.every((p) => p.y == 0), isTrue);
      expect(cells.length, 4);
    });

    test('escapeCorridor runs off the board', () {
      final grid = Grid(width: 6, height: 6);
      final arrow = ArrowPath(
        id: 'a',
        points: const [GridPoint(2, 4), GridPoint(4, 4)],
        direction: Direction.right,
      );
      final corridor = arrow.escapeCorridor(grid);
      // The corridor should reach the right edge and never leave the grid.
      expect(corridor.any((p) => p.x == 5), isTrue);
      expect(corridor.every(grid.inBoundsPoint), isTrue);
      // With halfWidth 1 it is 3 cells tall.
      expect(corridor.map((p) => p.y).toSet(), {3, 4, 5});
    });

    test('containsPoint hits the body and misses elsewhere', () {
      const cellSize = 50.0;
      final arrow = ArrowPath(
        id: 'a',
        points: const [GridPoint(2, 2), GridPoint(5, 2)],
        direction: Direction.right,
      );
      // A tap on the horizontal segment between (2,2) and (5,2).
      final onBody = const GridPoint(3, 2).toOffset(cellSize);
      expect(arrow.containsPoint(onBody, cellSize), isTrue);

      // A tap far below the segment.
      final offBody = onBody + const Offset(0, 200);
      expect(arrow.containsPoint(offBody, cellSize), isFalse);
    });
  });
}
