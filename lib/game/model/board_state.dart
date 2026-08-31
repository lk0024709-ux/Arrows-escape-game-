/// Compact, immutable snapshot of a board in play.
///
/// The solver, the validator and the gameplay controller all share this
/// representation, which guarantees they reason about *exactly* the same state
/// (prompt §49 — one definition of "can this arrow escape?").
class BoardState {
  BoardState._(this.offsets, this.removed, this.moveCount);

  /// Travel distance per arrow index (0 = generated home position).
  final List<double> offsets;

  /// `true` once the arrow has left the board.
  final List<bool> removed;

  /// Number of committed moves that produced this state (player moves, not
  /// animation frames — prompt §27).
  final int moveCount;

  factory BoardState.initial(int arrowCount) => BoardState._(
        List<double>.filled(arrowCount, 0.0),
        List<bool>.filled(arrowCount, false),
        0,
      );

  int get arrowCount => offsets.length;

  int get remaining {
    var n = 0;
    for (final r in removed) {
      if (!r) n++;
    }
    return n;
  }

  bool get isSolved => remaining == 0;

  bool isRemovedAt(int i) => removed[i];

  double offsetAt(int i) => offsets[i];

  /// State after moving arrow [i] to a new offset (a slide that ended flush).
  BoardState slidTo(int i, double newOffset) {
    final nextOffsets = List<double>.from(offsets);
    final nextRemoved = List<bool>.from(removed);
    nextOffsets[i] = newOffset;
    return BoardState._(nextOffsets, nextRemoved, moveCount + 1);
  }

  /// State after arrow [i] escaped the board.
  BoardState escapedAt(int i) {
    final nextRemoved = List<bool>.from(removed);
    nextRemoved[i] = true;
    return BoardState._(List<double>.from(offsets), nextRemoved, moveCount + 1);
  }

  /// Quantised, hashable key used by the solver's visited set.
  String get key {
    final sb = StringBuffer();
    for (var i = 0; i < offsets.length; i++) {
      if (removed[i]) {
        sb.write('x;');
      } else {
        sb.write((offsets[i] * 1000).round());
        sb.write(';');
      }
    }
    return sb.toString();
  }

  @override
  bool operator ==(Object other) => other is BoardState && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'BoardState(moves=$moveCount, remaining=$remaining)';
}
