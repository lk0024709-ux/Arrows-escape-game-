import '../geometry/arrow_geometry.dart';
import '../model/arrow_theme_metrics.dart' show ArrowMetrics;
import '../model/board_state.dart';
import '../model/direction.dart';
import '../model/game_rules.dart';
import '../model/level.dart';
import '../model/path_arrow.dart';

import '../../core/geometry/geometry.dart';

/// Result of the single authoritative question:
/// *"can this arrow move, how far, and does it escape?"* (prompt §49).
class MoveEvaluation {
  const MoveEvaluation({
    required this.arrowIndex,
    required this.canMove,
    required this.travel,
    required this.escapes,
    required this.exitDistance,
    this.blockers = const <int>[],
  });

  final int arrowIndex;

  /// `true` when the arrow is able to travel a meaningful distance.
  final bool canMove;

  /// Distance (in grid cells) the arrow travels before stopping.
  final double travel;

  /// `true` when the arrow leaves the board during this move.
  final bool escapes;

  /// Distance needed to fully leave the board.
  final double exitDistance;

  /// Indices of the arrows that stop this arrow (empty when it escapes).
  final List<int> blockers;

  /// A move that travels but does not remove the arrow is a *decoy*: it looks
  /// productive but it silently re-shapes the board (prompt §21).
  bool get isDecoy => canMove && !escapes;

  /// Minimum travel that counts as a real move (below this the arrow shakes).
  static const double minimumTravel = 1e-4;

  @override
  String toString() => 'MoveEvaluation(#$arrowIndex, move=$canMove, '
      'travel=${travel.toStringAsFixed(3)}, escapes=$escapes)';
}

/// Cached geometry for one board state.
///
/// Built once per state, reused by every query (gameplay, solver, validator).
class BoardCollisionIndex {
  BoardCollisionIndex(this.level, this.state) {
    final n = level.arrows.length;
    _parts = List<List<Aabb>>.filled(n, const <Aabb>[]);
    _bounds = List<Aabb?>.filled(n, null);
    _hash = SpatialHash(cellSize: 2.0);
    for (var i = 0; i < n; i++) {
      if (state.isRemovedAt(i)) continue;
      final arrow = level.arrows[i].withOffset(state.offsetAt(i));
      final parts = ArrowGeometry.partsOf(arrow);
      _parts[i] = parts;
      final bounds = ArrowGeometry.boundsOfParts(parts);
      _bounds[i] = bounds;
      _hash.insert(i, bounds);
    }
  }

  final Level level;
  final BoardState state;
  late final List<List<Aabb>> _parts;
  late final List<Aabb?> _bounds;
  late final SpatialHash _hash;

  List<Aabb> partsOf(int i) => _parts[i];
  Aabb boundsOf(int i) => _bounds[i]!;

  /// Broad phase: ids whose bounds may intersect [query].
  Set<int> candidates(Aabb query) => _hash.query(query);

  /// All active arrow indices.
  List<int> get activeIndices => [
        for (var i = 0; i < level.arrows.length; i++)
          if (!state.isRemovedAt(i)) i,
      ];
}

/// The one and only physics core.
///
/// Gameplay, the solver and the level validator all call [evaluate]; there is
/// no second, divergent copy of the movement rule anywhere in the codebase
/// (prompt §49).
class PhysicsEngine {
  const PhysicsEngine({this.rules = const GameRules()});

  final GameRules rules;

  /// Evaluate a single arrow.
  MoveEvaluation evaluate(BoardCollisionIndex index, int arrowIndex) {
    final level = index.level;
    if (index.state.isRemovedAt(arrowIndex)) {
      return MoveEvaluation(
        arrowIndex: arrowIndex,
        canMove: false,
        travel: 0,
        escapes: false,
        exitDistance: 0,
      );
    }
    final arrow = level.arrows[arrowIndex].withOffset(index.state.offsetAt(arrowIndex));
    final parts = index.partsOf(arrowIndex);
    final bounds = index.boundsOf(arrowIndex);
    final playBounds = level.playBounds;
    final exit = EscapeCorridor.exitDistance(bounds, arrow.direction, playBounds);
    final travel = _maxFreeTravel(
      direction: arrow.direction,
      parts: parts,
      index: index,
      selfIndex: arrowIndex,
      cap: exit,
    );

    final escapes = travel >= exit - MoveEvaluation.minimumTravel;
    if (rules.travelMode == TravelMode.escapeOnly && !escapes) {
      return MoveEvaluation(
        arrowIndex: arrowIndex,
        canMove: false,
        travel: 0,
        escapes: false,
        exitDistance: exit,
        blockers: _blockersFor(
          direction: arrow.direction,
          bounds: bounds,
          playBounds: playBounds,
          index: index,
          selfIndex: arrowIndex,
        ),
      );
    }

    return MoveEvaluation(
      arrowIndex: arrowIndex,
      canMove: travel > MoveEvaluation.minimumTravel,
      travel: travel,
      escapes: escapes,
      exitDistance: exit,
      blockers: escapes
          ? const <int>[]
          : _blockersFor(
              direction: arrow.direction,
              bounds: bounds,
              playBounds: playBounds,
              index: index,
              selfIndex: arrowIndex,
              withinDistance: travel + kGeometryEpsilon * 8,
            ),
    );
  }

  /// Evaluate every arrow on the board (used by the solver, the hint system and
  /// the difficulty analysis).
  List<MoveEvaluation> evaluateAll(BoardCollisionIndex index) => [
        for (final i in index.activeIndices) evaluate(index, i),
      ];

  /// Convenience wrapper — the canonical predicate (prompt §34/§49).
  bool canEscape(Level level, BoardState state, int arrowIndex) =>
      evaluate(BoardCollisionIndex(level, state), arrowIndex).escapes;

  /// Commit a move. Returns the new state; the input state is untouched.
  BoardState applyMove(
    BoardCollisionIndex index,
    int arrowIndex,
    MoveEvaluation evaluation,
  ) {
    if (!evaluation.canMove) return index.state;
    if (evaluation.escapes) return index.state.escapedAt(arrowIndex);
    final nextOffset = index.state.offsetAt(arrowIndex) + evaluation.travel;
    return index.state.slidTo(arrowIndex, nextOffset);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Exact swept-AABB solve: how far can this arrow travel along its own axis?
  double _maxFreeTravel({
    required Direction direction,
    required List<Aabb> parts,
    required BoardCollisionIndex index,
    required int selfIndex,
    required double cap,
  }) {
    var best = cap;
    // Broad phase: sweep the whole arrow to the board edge and collect the
    // candidate arrows that could possibly be in the way.
    final sweptBounds = ArrowGeometry.boundsOfParts(parts);
    final corridor = EscapeCorridor.sweep(sweptBounds, direction, cap);
    for (final otherIndex in index.candidates(corridor)) {
      if (otherIndex == selfIndex) continue;
      final otherParts = index.partsOf(otherIndex);
      final otherBounds = index.boundsOf(otherIndex);
      if (!corridor.overlaps(otherBounds)) continue;
      for (final p in parts) {
        for (final q in otherParts) {
          if (!_perpendicularOverlap(p, q, direction)) continue;
          final gap = _gapAlong(p, q, direction);
          if (gap < best) {
            best = gap;
            if (best <= 0) return 0;
          }
        }
      }
    }
    return best < 0 ? 0 : best;
  }

  /// Do the two boxes overlap on the axis perpendicular to the movement?
  static bool _perpendicularOverlap(Aabb p, Aabb q, Direction d) => d.isHorizontal
      ? p.top < q.bottom - kGeometryEpsilon && p.bottom > q.top + kGeometryEpsilon
      : p.left < q.right - kGeometryEpsilon && p.right > q.left + kGeometryEpsilon;

  /// Free distance between [p] and [q] along the movement axis.
  ///
  /// Returns `double.infinity` when [q] lies *behind* [p] (it can never be hit
  /// by a forward translation) and `0` when the boxes already overlap.
  static double _gapAlong(Aabb p, Aabb q, Direction d) {
    final e = kGeometryEpsilon;
    switch (d) {
      case Direction.right:
        if (q.right <= p.left + e) return double.infinity;
        return q.left >= p.right - e ? q.left - p.right : 0.0;
      case Direction.left:
        if (q.left >= p.right - e) return double.infinity;
        return p.left <= q.left + e ? p.left - q.right : 0.0;
      case Direction.down:
        if (q.bottom <= p.top + e) return double.infinity;
        return q.top >= p.bottom - e ? q.top - p.bottom : 0.0;
      case Direction.up:
        if (q.top >= p.bottom - e) return double.infinity;
        return p.top <= q.top + e ? p.top - q.bottom : 0.0;
    }
  }

  List<int> _blockersFor({
    required Direction direction,
    required Aabb bounds,
    required Aabb playBounds,
    required BoardCollisionIndex index,
    required int selfIndex,
    double? withinDistance,
  }) {
    final corridor = withinDistance == null
        ? EscapeCorridor.toBoardEdge(bounds, direction, playBounds)
        : EscapeCorridor.sweep(bounds, direction, withinDistance);
    final out = <int>[];
    for (final otherIndex in index.candidates(corridor)) {
      if (otherIndex == selfIndex) continue;
      final otherBounds = index.boundsOf(otherIndex);
      if (!corridor.overlaps(otherBounds)) continue;
      final parts = index.partsOf(otherIndex);
      for (final q in parts) {
        if (corridor.overlaps(q)) {
          out.add(otherIndex);
          break;
        }
      }
    }
    return out;
  }

  /// Distance an arrow would need to travel to escape — exported for the
  /// renderer (escape animation length) and the editor.
  static double exitDistanceFor(PathArrow arrow, Aabb playBounds) =>
      EscapeCorridor.exitDistance(
        ArrowGeometry.boundsOf(arrow),
        arrow.direction,
        playBounds,
      );

  /// Static helper used by the generator before a [BoardCollisionIndex] exists.
  static bool partsOverlap(List<Aabb> a, List<Aabb> b, {double margin = 0}) {
    for (final p in a) {
      for (final q in b) {
        if (margin > 0 ? p.overlapsWithMargin(q, margin) : p.overlaps(q)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Convenience for the editor: metrics accessor.
  ArrowMetrics metricsOf(Level level) => level.metrics;
}
