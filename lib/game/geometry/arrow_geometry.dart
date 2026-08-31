import 'dart:math' as math;

import '../../core/geometry/geometry.dart';
import '../../core/math/vector2.dart';
import '../model/arrow_theme_metrics.dart';
import '../model/direction.dart';
import '../model/path_arrow.dart';

/// Builds every geometric representation of a [PathArrow].
///
/// The renderer and the collision system consume **the same** functions, so the
/// shape the player sees is literally the shape the physics test uses
/// (prompt §34 — never two unrelated geometries).
class ArrowGeometry {
  const ArrowGeometry._();

  /// Collision shapes of an arrow: one AABB per straight segment plus the
  /// arrow-head box.
  ///
  /// Every path is orthogonal and every movement is orthogonal, therefore the
  /// AABB swept along the movement axis is *exactly* the swept region — no
  /// conservative approximation is involved (prompt §36).
  static List<Aabb> partsOf(PathArrow arrow) {
    final pts = arrow.worldPoints;
    final m = arrow.metrics;
    final half = m.halfThickness;
    final parts = <Aabb>[];
    for (var i = 0; i < pts.length - 1; i++) {
      parts.add(Aabb.fromPoints(pts[i], pts[i + 1]).expand(half));
    }
    parts.add(headBox(arrow, pts.last));
    return parts;
  }

  /// The arrow-head collision box (axis aligned, tight around the head).
  static Aabb headBox(PathArrow arrow, Vec2 tip) {
    final m = arrow.metrics;
    final d = arrow.direction;
    final base = tip - Vec2(d.dx * m.headLength, d.dy * m.headLength);
    if (d.isHorizontal) {
      return Aabb(
        math.min(base.x, tip.x) - m.halfThickness,
        tip.y - m.headWidth / 2,
        math.max(base.x, tip.x) + m.halfThickness,
        tip.y + m.headWidth / 2,
      );
    }
    return Aabb(
      tip.x - m.headWidth / 2,
      math.min(base.y, tip.y) - m.halfThickness,
      tip.x + m.headWidth / 2,
      math.max(base.y, tip.y) + m.halfThickness,
    );
  }

  /// The rendered arrow head as a triangle (tip + two base corners).
  static Triangle headTriangle(PathArrow arrow) {
    final pts = arrow.worldPoints;
    final tip = pts.last;
    final m = arrow.metrics;
    final d = arrow.direction;
    final back = Vec2(d.dx.toDouble(), d.dy.toDouble()) * m.headLength;
    final side = Vec2(d.dy.toDouble(), d.dx.toDouble()) * (m.headWidth / 2);
    return Triangle(tip, tip - back + side, tip - back - side);
  }

  /// Centre-line of the path (used for debug rendering and validation).
  static List<Segment> centerSegments(PathArrow arrow) {
    final pts = arrow.worldPoints;
    return [
      for (var i = 0; i < pts.length - 1; i++) Segment(pts[i], pts[i + 1]),
    ];
  }

  static Aabb boundsOfParts(List<Aabb> parts) {
    var box = parts.first;
    for (var i = 1; i < parts.length; i++) {
      box = box.union(parts[i]);
    }
    return box;
  }

  static Aabb boundsOf(PathArrow arrow) => boundsOfParts(partsOf(arrow));
}

/// Helpers for the "escape corridor" — the volume an arrow sweeps while
/// travelling towards its exit (prompt §35).
class EscapeCorridor {
  const EscapeCorridor._();

  /// Grow [box] by [distance] in direction [d].
  static Aabb sweep(Aabb box, Direction d, double distance) => switch (d) {
        Direction.right => Aabb(box.left, box.top, box.right + distance, box.bottom),
        Direction.left => Aabb(box.left - distance, box.top, box.right, box.bottom),
        Direction.down => Aabb(box.left, box.top, box.right, box.bottom + distance),
        Direction.up => Aabb(box.left, box.top - distance, box.right, box.bottom),
      };

  /// The complete corridor from the arrow's current position to the board edge.
  static Aabb toBoardEdge(Aabb bounds, Direction d, Aabb playBounds) =>
      sweep(bounds, d, exitDistance(bounds, d, playBounds));

  /// Distance the arrow must travel before it is completely outside the board.
  static double exitDistance(Aabb bounds, Direction d, Aabb playBounds) =>
      switch (d) {
        Direction.right => playBounds.right - bounds.left,
        Direction.left => bounds.right - playBounds.left,
        Direction.down => playBounds.bottom - bounds.top,
        Direction.up => bounds.bottom - playBounds.top,
      } + kGeometryEpsilon;

  /// Is the corridor to the board edge completely free of [others]?
  static bool isClear(
    Aabb bounds,
    Direction d,
    Aabb playBounds,
    List<Aabb> others, {
    double margin = 0,
  }) {
    final corridor = toBoardEdge(bounds, d, playBounds);
    for (final o in others) {
      if (margin > 0 ? corridor.overlapsWithMargin(o, margin) : corridor.overlaps(o)) {
        return false;
      }
    }
    return true;
  }

  /// Which of the [others] sit inside the corridor (used by the dependency
  /// graph and by the hint system).
  static List<int> blockersInside(
    Aabb bounds,
    Direction d,
    Aabb playBounds,
    List<Aabb> others,
  ) {
    final corridor = toBoardEdge(bounds, d, playBounds);
    final result = <int>[];
    for (var i = 0; i < others.length; i++) {
      if (corridor.overlaps(others[i])) result.add(i);
    }
    return result;
  }
}

/// Uniform-grid broad phase (prompt §59).
class SpatialHash {
  SpatialHash({this.cellSize = 2.0});

  final double cellSize;
  final Map<int, List<int>> _buckets = <int, List<int>>{};
  final Map<int, Aabb> _boxes = <int, Aabb>{};

  void clear() {
    _buckets.clear();
    _boxes.clear();
  }

  void insert(int id, Aabb box) {
    _boxes[id] = box;
    final x0 = (box.left / cellSize).floor();
    final x1 = (box.right / cellSize).floor();
    final y0 = (box.top / cellSize).floor();
    final y1 = (box.bottom / cellSize).floor();
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        _buckets.putIfAbsent(_key(x, y), () => <int>[]).add(id);
      }
    }
  }

  /// Candidate ids whose boxes may intersect [query].
  Set<int> query(Aabb query) {
    final out = <int>{};
    final x0 = (query.left / cellSize).floor();
    final x1 = (query.right / cellSize).floor();
    final y0 = (query.top / cellSize).floor();
    final y1 = (query.bottom / cellSize).floor();
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        final bucket = _buckets[_key(x, y)];
        if (bucket != null) out.addAll(bucket);
      }
    }
    return out;
  }

  Aabb? boxOf(int id) => _boxes[id];

  int _key(int x, int y) => (x * 73856093) ^ (y * 19349663);
}
