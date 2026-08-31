import '../geometry/arrow_path.dart';
import '../geometry/grid.dart';
import 'level.dart';

/// Finds an order in which every arrow can fly off the board.
///
/// Escape clearance is monotone: removing arrows only ever frees corridors, it
/// never blocks one. So a greedy walk that always takes any currently free
/// arrow is complete - if it gets stuck, the board genuinely has no solution.
class LevelSolver {
  final Level level;

  LevelSolver({required this.level});

  /// True when [arrow] can leave the board right now.
  bool canEscape(ArrowPath arrow) => _canEscape(arrow, level.arrows, level.grid);

  /// A full escape order, or an empty list when the board is unsolvable.
  List<ArrowPath> solve() => solveArrows(level.arrows, level.grid);

  /// Greedy solve over an arbitrary arrow list. Exposed so the generator can
  /// validate a board before it is wrapped in a [Level].
  static List<ArrowPath> solveArrows(List<ArrowPath> arrows, Grid? grid) {
    final remaining = List<ArrowPath>.of(arrows);
    final order = <ArrowPath>[];

    while (remaining.isNotEmpty) {
      int pick = -1;
      for (int i = 0; i < remaining.length; i++) {
        if (_canEscape(remaining[i], remaining, grid)) {
          pick = i;
          break;
        }
      }
      if (pick < 0) return const [];
      order.add(remaining.removeAt(pick));
    }
    return order;
  }

  /// How many arrows are free at once on the opening board. More choices means
  /// the player has more branching to reason about.
  static int branchingFactor(List<ArrowPath> arrows, Grid? grid) {
    return arrows.where((a) => _canEscape(a, arrows, grid)).length;
  }

  static bool _canEscape(ArrowPath arrow, List<ArrowPath> arrows, Grid? grid) {
    if (grid == null) return false;
    if (!arrow.isValidDirection) return false;

    final corridor = <String>{
      for (final cell in arrow.escapeCorridor(grid)) '${cell.x},${cell.y}',
    };

    for (final other in arrows) {
      if (other.id == arrow.id) continue;
      for (final cell in other.occupiedCells) {
        if (corridor.contains('${cell.x},${cell.y}')) return false;
      }
    }
    return true;
  }
}
