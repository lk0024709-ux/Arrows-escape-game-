import '../../core/geometry/geometry.dart';
import '../geometry/arrow_geometry.dart';
import '../model/board_state.dart';
import '../model/level.dart';
import '../physics/physics_engine.dart';

/// The blocking DAG of a board (prompt §19).
///
/// `blockers[i]` = every arrow that currently sits inside the escape corridor
/// of arrow `i` and therefore has to leave the board first.
///
/// For generated levels this graph is acyclic by construction: an arrow can only
/// ever be blocked by arrows that were inserted *after* it, and insertion order
/// is the reverse of escape order.
class DependencyGraph {
  DependencyGraph(this.blockers, this.blocked);

  /// arrow index → indices of the arrows blocking it.
  final List<List<int>> blockers;

  /// arrow index → indices of the arrows it blocks.
  final List<List<int>> blocked;

  static const PhysicsEngine _physics = PhysicsEngine();

  factory DependencyGraph.compute(Level level, {BoardState? state}) {
    final s = state ?? level.initialState;
    final index = BoardCollisionIndex(level, s);
    final n = level.arrows.length;
    final blockers = List<List<int>>.filled(n, const <int>[]);
    final blocked = List<List<int>>.filled(n, const <int>[]);

    for (final i in index.activeIndices) {
      final arrow = level.arrows[i].withOffset(s.offsetAt(i));
      final bounds = index.boundsOf(i);
      final corridor = EscapeCorridor.toBoardEdge(
        bounds,
        arrow.direction,
        level.playBounds,
      );
      final list = <int>[];
      for (final part in index.partsOf(i)) {
        // corridor tests run against every other arrow's parts
        for (final j in index.activeIndices) {
          if (j == i || list.contains(j)) continue;
          var hit = false;
          for (final q in index.partsOf(j)) {
            if (corridor.overlaps(q)) {
              hit = true;
              break;
            }
          }
          if (hit) list.add(j);
        }
        break;
      }
      blockers[i] = list;
    }
    for (var i = 0; i < n; i++) {
      for (final j in blockers[i]) {
        blocked[j] = [...blocked[j], i];
      }
    }
    return DependencyGraph(blockers, blocked);
  }

  int get arrowCount => blockers.length;

  /// Arrows with nothing in their corridor — the moves available immediately.
  List<int> get roots => [
        for (var i = 0; i < blockers.length; i++)
          if (blockers[i].isEmpty) i,
      ];

  int get rootCount => roots.length;

  int get edgeCount {
    var n = 0;
    for (final b in blockers) {
      n += b.length;
    }
    return n;
  }

  /// Longest dependency chain (0 when every arrow is free).
  int get depth {
    final memo = List<int>.filled(blockers.length, -1);
    int visit(int i) {
      if (memo[i] >= 0) return memo[i];
      memo[i] = 0; // cycle guard
      var best = 0;
      for (final b in blockers[i]) {
        final d = visit(b) + 1;
        if (d > best) best = d;
      }
      memo[i] = best;
      return best;
    }

    var max = 0;
    for (var i = 0; i < blockers.length; i++) {
      final d = visit(i);
      if (d > max) max = d;
    }
    return max;
  }

  /// A valid escape order (topological sort, deterministic).
  List<int> topologicalEscapeOrder() {
    final indegree = [
      for (var i = 0; i < blockers.length; i++) blockers[i].length,
    ];
    final order = <int>[];
    final ready = <int>[
      for (var i = 0; i < blockers.length; i++)
        if (indegree[i] == 0) i,
    ];
    while (ready.isNotEmpty) {
      ready.sort();
      final next = ready.removeAt(0);
      order.add(next);
      for (final j in blocked[next]) {
        indegree[j]--;
        if (indegree[j] == 0) ready.add(j);
      }
    }
    return order;
  }

  /// Human readable form for the debug overlay.
  @override
  String toString() =>
      'DependencyGraph(arrows=$arrowCount, roots=$rootCount, edges=$edgeCount, depth=$depth)';
}
