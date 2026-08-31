import 'dart:math' as m;

import '../math/vector2.dart';

/// Shared tolerance for all geometry comparisons (world units = grid cells).
const double kGeometryEpsilon = 1e-9;

/// Axis aligned bounding box.
///
/// All collision shapes in the game are AABBs (see `docs/ARCHITECTURE.md` for
/// why: every path is orthogonal and every motion is orthogonal, so an AABB
/// swept along an axis is *exactly* an AABB — no approximation).
class Aabb {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const Aabb(this.left, this.top, this.right, this.bottom);

  factory Aabb.fromPoints(Vec2 a, Vec2 b) => Aabb(
        m.min(a.x, b.x),
        m.min(a.y, b.y),
        m.max(a.x, b.x),
        m.max(a.y, b.y),
      );

  factory Aabb.fromCenter(Vec2 c, double w, double h) =>
      Aabb(c.x - w / 2, c.y - h / 2, c.x + w / 2, c.y + h / 2);

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  Vec2 get center => Vec2(centerX, centerY);
  double get area => width * height;
  bool get isEmpty => width <= 0 || height <= 0;

  Aabb expand(double d) => Aabb(left - d, top - d, right + d, bottom + d);

  Aabb translate(double dx, double dy) =>
      Aabb(left + dx, top + dy, right + dx, bottom + dy);

  Aabb union(Aabb o) => Aabb(
        m.min(left, o.left),
        m.min(top, o.top),
        m.max(right, o.right),
        m.max(bottom, o.bottom),
      );

  Aabb intersection(Aabb o) {
    final r = Aabb(
      m.max(left, o.left),
      m.max(top, o.top),
      m.min(right, o.right),
      m.min(bottom, o.bottom),
    );
    return r.isEmpty ? Aabb(left, top, left, top) : r;
  }

  /// Strict overlap test. Touching boxes are *not* considered overlapping so
  /// that an arrow may come to rest flush against a blocker.
  bool overlaps(Aabb o) =>
      left < o.right - kGeometryEpsilon &&
      right > o.left + kGeometryEpsilon &&
      top < o.bottom - kGeometryEpsilon &&
      bottom > o.top + kGeometryEpsilon;

  /// Overlap test with an extra safety margin (used by the generator to enforce
  /// the "minimum path spacing" rule).
  bool overlapsWithMargin(Aabb o, double margin) => overlaps(o.expand(margin));

  bool containsPoint(Vec2 p) =>
      p.x >= left - kGeometryEpsilon &&
      p.x <= right + kGeometryEpsilon &&
      p.y >= top - kGeometryEpsilon &&
      p.y <= bottom + kGeometryEpsilon;

  bool contains(Aabb o) =>
      left <= o.left + kGeometryEpsilon &&
      top <= o.top + kGeometryEpsilon &&
      right >= o.right - kGeometryEpsilon &&
      bottom >= o.bottom - kGeometryEpsilon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Aabb &&
          other.left == left &&
          other.top == top &&
          other.right == right &&
          other.bottom == bottom);

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() =>
      'Aabb(${_f(left)}, ${_f(top)}, ${_f(right)}, ${_f(bottom)})';

  static String _f(double v) => v.toStringAsFixed(3);
}

/// A triangle (used for the rendered arrow head and for the *exact*
/// narrow-phase polygon tests used by the level validator).
class Triangle {
  const Triangle(this.a, this.b, this.c);

  final Vec2 a;
  final Vec2 b;
  final Vec2 c;

  Aabb get bounds => Aabb.fromPoints(a, b)
      .union(Aabb.fromPoints(b, c))
      .union(Aabb.fromPoints(c, a));

  List<Vec2> get vertices => [a, b, c];

  /// Separating-axis test: triangle vs AABB.
  bool intersectsAabb(Aabb box) {
    if (!bounds.overlaps(box)) return false;
    final boxPts = <Vec2>[
      Vec2(box.left, box.top),
      Vec2(box.right, box.top),
      Vec2(box.right, box.bottom),
      Vec2(box.left, box.bottom),
    ];
    final triPts = vertices;
    for (var shape = 0; shape < 2; shape++) {
      final pts = shape == 0 ? triPts : boxPts;
      for (var i = 0; i < pts.length; i++) {
        final p1 = pts[i];
        final p2 = pts[(i + 1) % pts.length];
        final axis = Vec2(-(p2.y - p1.y), p2.x - p1.x);
        if (axis.lengthSquared < kGeometryEpsilon) continue;
        if (_separated(axis, triPts, boxPts)) return false;
      }
    }
    return true;
  }

  static bool _separated(Vec2 axis, List<Vec2> tri, List<Vec2> box) {
    var triMin = double.infinity;
    var triMax = -double.infinity;
    for (final p in tri) {
      final v = axis.dot(p);
      if (v < triMin) triMin = v;
      if (v > triMax) triMax = v;
    }
    var boxMin = double.infinity;
    var boxMax = -double.infinity;
    for (final p in box) {
      final v = axis.dot(p);
      if (v < boxMin) boxMin = v;
      if (v > boxMax) boxMax = v;
    }
    return triMax < boxMin + kGeometryEpsilon ||
        boxMax < triMin + kGeometryEpsilon;
  }
}

/// Line segment used for the exact "do these two path centre-lines cross?"
/// check performed by the validator.
class Segment {
  const Segment(this.a, this.b);

  final Vec2 a;
  final Vec2 b;

  double get length => a.distanceTo(b);

  /// Proper segment/segment intersection test.
  bool intersects(Segment o) {
    final d1 = _cross(o.a, o.b, a);
    final d2 = _cross(o.a, o.b, b);
    final d3 = _cross(a, b, o.a);
    final d4 = _cross(a, b, o.b);
    if (((d1 > kGeometryEpsilon && d2 < -kGeometryEpsilon) ||
            (d1 < -kGeometryEpsilon && d2 > kGeometryEpsilon)) &&
        ((d3 > kGeometryEpsilon && d4 < -kGeometryEpsilon) ||
            (d3 < -kGeometryEpsilon && d4 > kGeometryEpsilon))) {
      return true;
    }
    return _onSegment(o.a, o.b, a) ||
        _onSegment(o.a, b, a) ||
        _onSegment(a, o.b, o.a) ||
        _onSegment(a, b, o.a);
  }

  static double _cross(Vec2 o, Vec2 a, Vec2 b) => (a - o).cross(b - o);

  static bool _onSegment(Vec2 p, Vec2 q, Vec2 r) =>
      _cross(p, q, r).abs() < kGeometryEpsilon &&
      r.x <= m.max(p.x, q.x) &&
      r.x >= m.min(p.x, q.x) &&
      r.y <= m.max(p.y, q.y) &&
      r.y >= m.min(p.y, q.y);
}

/// Clamp helper shared by the engine.
double clampValue(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);
