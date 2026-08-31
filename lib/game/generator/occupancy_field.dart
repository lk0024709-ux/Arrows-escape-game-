import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/geometry/geometry.dart';
import '../model/arrow_theme_metrics.dart';
import '../model/direction.dart';

/// Coarse occupancy + distance field over the invisible construction grid.
///
/// This is a *search accelerator only*: candidate paths are grown through free
/// cells before the exact geometry checks (minimum spacing §14, escape
/// corridor §35) run. It never decides gameplay — the physics core does.
class OccupancyField {
  OccupancyField(this.cols, this.rows)
      : _blocked = Uint8List(cols * rows),
        _distance = Int32List(cols * rows);

  final int cols;
  final int rows;
  final Uint8List _blocked;
  final Int32List _distance;

  static const int _infinity = 1 << 20;

  /// Mark every cell that can no longer host a path centre-line.
  void rebuild(
    List<List<Aabb>> partsList,
    ArrowMetrics metrics,
    double minGap,
  ) {
    _blocked.fillRange(0, _blocked.length, 0);
    final bodyMargin = minGap + metrics.halfThickness;
    final headMargin = minGap + metrics.headWidth / 2;

    for (final parts in partsList) {
      for (var i = 0; i < parts.length; i++) {
        final p = parts[i];
        // The final part of every arrow list is the arrow head, which is wider.
        final margin = i == parts.length - 1 ? headMargin : bodyMargin;
        final c0 = math.max(0, (p.left - margin).floor());
        final c1 = math.min(cols - 1, (p.right + margin).ceil());
        final r0 = math.max(0, (p.top - margin).floor());
        final r1 = math.min(rows - 1, (p.bottom + margin).ceil());
        for (var r = r0; r <= r1; r++) {
          for (var c = c0; c <= c1; c++) {
            final index = r * cols + c;
            if (_blocked[index] == 1) continue;
            if (c >= p.left - margin &&
                c <= p.right + margin &&
                r >= p.top - margin &&
                r <= p.bottom + margin) {
              _blocked[index] = 1;
            }
          }
        }
      }
    }
    _computeDistance();
  }

  /// Multi-source BFS distance transform (4-neighbour).
  void _computeDistance() {
    _distance.fillRange(0, _distance.length, _infinity);
    final queue = <int>[];
    for (var i = 0; i < _blocked.length; i++) {
      if (_blocked[i] == 1) {
        _distance[i] = 0;
        queue.add(i);
      }
    }
    var head = 0;
    while (head < queue.length) {
      final index = queue[head++];
      final c = index % cols;
      final r = index ~/ cols;
      final next = _distance[index] + 1;
      if (c > 0) _relax(r * cols + (c - 1), next, queue);
      if (c < cols - 1) _relax(r * cols + (c + 1), next, queue);
      if (r > 0) _relax((r - 1) * cols + c, next, queue);
      if (r < rows - 1) _relax((r + 1) * cols + c, next, queue);
    }
  }

  void _relax(int index, int value, List<int> queue) {
    if (_distance[index] > value) {
      _distance[index] = value;
      queue.add(index);
    }
  }

  bool isFree(int c, int r) {
    if (c < 0 || c >= cols || r < 0 || r >= rows) return false;
    return _blocked[r * cols + c] == 0;
  }

  int distanceAt(int c, int r) {
    if (c < 0 || c >= cols || r < 0 || r >= rows) return 0;
    return _distance[r * cols + c];
  }

  /// Longest run of free cells starting at (c, r) and walking [dir].
  int freeRun(int c, int r, Direction dir, int maxSteps) {
    var steps = 0;
    for (var k = 1; k <= maxSteps; k++) {
      if (!isFree(c + dir.dx * k, r + dir.dy * k)) break;
      steps = k;
    }
    return steps;
  }
}
