import '../../core/math/vector2.dart';
import 'arrow_theme_metrics.dart';
import 'direction.dart';
import 'grid_point.dart';

/// Lifecycle of a single arrow.
enum ArrowState {
  /// Resting on the board.
  idle,

  /// Currently touched / highlighted by the player.
  selected,

  /// Travelling towards its exit (animation only — logic already committed it).
  escaping,

  /// The last tap was rejected: the arrow cannot move at all.
  blocked,

  /// Left the board (or was consumed by the solver).
  removed,
}

extension ArrowStateX on ArrowState {
  bool get isOnBoard => this != ArrowState.removed;
  bool get isAnimating => this == ArrowState.escaping;
}

/// The primary game object (prompt §5).
///
/// A `PathArrow` is *not* an icon: it is a long orthogonal polyline built from
/// logical grid nodes and terminated by a procedurally generated arrow head
/// that always points along the final segment (prompt §10).
class PathArrow {
  PathArrow({
    required this.id,
    required this.points,
    required this.direction,
    this.metrics = const ArrowMetrics(),
    this.offset = 0.0,
    this.state = ArrowState.idle,
    this.escapeIndex,
    this.label,
  }) : assert(points.length >= 2, 'A path needs at least two nodes');

  final String id;

  /// Grid nodes of the path, from tail to tip. Consecutive nodes always share a
  /// row or a column (orthogonality invariant).
  final List<GridPoint> points;

  /// Escape direction — always identical to the direction of the last segment.
  final Direction direction;

  final ArrowMetrics metrics;

  /// Distance travelled along [direction] (in grid cells). 0 = generated home
  /// position. After a slide that stops against a blocker this is fractional.
  final double offset;

  final ArrowState state;

  /// Position inside the guaranteed escape order (generator bookkeeping, also
  /// surfaced in debug mode). `0` = escapes first.
  final int? escapeIndex;

  /// Optional short label used by the level editor / debug overlay.
  final String? label;

  PathArrow copyWith({
    List<GridPoint>? points,
    Direction? direction,
    ArrowMetrics? metrics,
    double? offset,
    ArrowState? state,
    int? escapeIndex,
    String? label,
  }) =>
      PathArrow(
        id: id,
        points: points ?? this.points,
        direction: direction ?? this.direction,
        metrics: metrics ?? this.metrics,
        offset: offset ?? this.offset,
        state: state ?? this.state,
        escapeIndex: escapeIndex ?? this.escapeIndex,
        label: label ?? this.label,
      );

  PathArrow withOffset(double value) => copyWith(offset: value);

  PathArrow withState(ArrowState value) => copyWith(state: value);

  // ---------------------------------------------------------------------------
  // Geometry (world units == grid cells)
  // ---------------------------------------------------------------------------

  /// Translation currently applied to the generated path.
  Vec2 get translation => Vec2(direction.dx * offset, direction.dy * offset);

  /// Path nodes in world space, offset applied.
  List<Vec2> get worldPoints {
    final t = translation;
    return [for (final p in points) Vec2(p.col + t.x, p.row + t.y)];
  }

  GridPoint get tail => points.first;
  GridPoint get tip => points.last;

  /// Number of straight segments (nodes - 1).
  int get segmentCount => points.length - 1;

  /// Number of 90° turns.
  int get turnCount => segmentCount - 1 < 0 ? 0 : segmentCount - 1;

  /// Total centre-line length in grid cells.
  double get pathLength {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += points[i].distanceTo(points[i + 1]);
    }
    return total;
  }

  /// Extent of the path along its own escape axis (used for exit distances).
  double get extentAlongDirection {
    final pts = points;
    if (direction.isHorizontal) {
      var min = pts.first.col.toDouble();
      var max = min;
      for (final p in pts) {
        if (p.col < min) min = p.col.toDouble();
        if (p.col > max) max = p.col.toDouble();
      }
      return max - min;
    }
    var min = pts.first.row.toDouble();
    var max = min;
    for (final p in pts) {
      if (p.row < min) min = p.row.toDouble();
      if (p.row > max) max = p.row.toDouble();
    }
    return max - min;
  }

  /// Coarse shape name, used by the generator for stats and by the editor.
  PathShapeKind get shapeKind {
    switch (segmentCount) {
      case 1:
        return PathShapeKind.straight;
      case 2:
        return PathShapeKind.lShape;
      case 3:
        return _isU ? PathShapeKind.uShape : PathShapeKind.zigZag;
      default:
        return _isS ? PathShapeKind.sShape : PathShapeKind.complex;
    }
  }

  bool get _isU {
    if (segmentCount != 3) return false;
    final d0 = _segmentDirection(0);
    final d2 = _segmentDirection(2);
    return d0 == d2.opposite;
  }

  bool get _isS {
    if (segmentCount < 4) return false;
    var flips = 0;
    for (var i = 1; i < points.length - 1; i++) {
      if (_segmentDirection(i - 1) != _segmentDirection(i)) flips++;
    }
    return flips >= 3;
  }

  Direction _segmentDirection(int i) {
    final a = points[i];
    final b = points[i + 1];
    return DirectionX.fromDelta(b.col - a.col, b.row - a.row);
  }

  /// Direction of the last segment — must always equal [direction] (prompt §10).
  Direction get lastSegmentDirection => _segmentDirection(points.length - 2);

  // ---------------------------------------------------------------------------
  // Validation (prompt §47)
  // ---------------------------------------------------------------------------

  /// Structural validation: orthogonality, no zero-length segments, no
  /// immediate back-tracking and a consistent arrow head direction.
  List<String> validateGeometry({int? gridCols, int? gridRows}) {
    final issues = <String>[];
    if (points.length < 2) {
      issues.add('${id}: needs at least 2 nodes');
      return issues;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final dx = b.col - a.col;
      final dy = b.row - a.row;
      if (dx != 0 && dy != 0) {
        issues.add('$id: segment $i is diagonal');
      }
      if (dx == 0 && dy == 0) {
        issues.add('$id: segment $i has zero length');
      }
    }
    for (var i = 0; i < points.length - 2; i++) {
      final a = points[i];
      final b = points[i + 1];
      final c = points[i + 2];
      if ((b.col - a.col) * (c.col - b.col) + (b.row - a.row) * (c.row - b.row) < 0) {
        issues.add('$id: back-tracks at node ${i + 1}');
      }
    }
    if (lastSegmentDirection != direction) {
      issues.add('$id: arrow head direction disagrees with last segment');
    }
    if (gridCols != null || gridRows != null) {
      for (final p in points) {
        if (gridCols != null && (p.col < 0 || p.col >= gridCols)) {
          issues.add('$id: node $p outside board width');
        }
        if (gridRows != null && (p.row < 0 || p.row >= gridRows)) {
          issues.add('$id: node $p outside board height');
        }
      }
    }
    return issues;
  }

  // ---------------------------------------------------------------------------
  // Serialisation (prompt §58)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': [
          for (final p in points) [p.col, p.row],
        ],
        'direction': direction.key,
        if (escapeIndex != null) 'escapeIndex': escapeIndex,
        if (label != null) 'label': label,
        if (offset != 0) 'offset': offset,
      };

  factory PathArrow.fromJson(
    Map<String, dynamic> json, {
    ArrowMetrics metrics = const ArrowMetrics(),
  }) =>
      PathArrow(
        id: json['id'] as String,
        points: [
          for (final raw in json['points'] as List<dynamic>)
            GridPoint((raw as List<dynamic>)[0] as int, raw[1] as int),
        ],
        direction: DirectionX.fromKey(json['direction'] as String?),
        metrics: metrics,
        escapeIndex: json['escapeIndex'] as int?,
        label: json['label'] as String?,
        offset: (json['offset'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  String toString() =>
      'PathArrow($id, ${shapeKind.name}, dir=${direction.key}, points=${points.length})';
}

/// Coarse classification of the generated path silhouettes (prompt §6).
enum PathShapeKind {
  straight,
  lShape,
  uShape,
  zigZag,
  sShape,
  complex,
}
