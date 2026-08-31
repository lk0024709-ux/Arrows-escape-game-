import '../model/board_state.dart';
import '../model/level.dart';
import '../physics/physics_engine.dart';

/// One committed move inside a solution.
class SolverMove {
  const SolverMove({
    required this.arrowIndex,
    required this.travel,
    required this.escapes,
    required this.fromOffset,
  });

  final int arrowIndex;
  final double travel;
  final bool escapes;
  final double fromOffset;

  double get toOffset => fromOffset + travel;

  @override
  String toString() => 'SolverMove(#$arrowIndex, ${escapes ? 'escape' : 'slide'} '
      '${travel.toStringAsFixed(2)})';
}

/// A sequence of moves that clears the board.
class Solution {
  const Solution({
    required this.moves,
    required this.isComplete,
    required this.nodesExplored,
    this.isOptimal = false,
  });

  final List<SolverMove> moves;
  final bool isComplete;
  final int nodesExplored;

  /// `true` when a shortest solution was proven (BFS finished without hitting
  /// the node cap).
  final bool isOptimal;

  int get length => moves.length;

  int get escapeCount => moves.where((m) => m.escapes).length;
  int get slideCount => moves.where((m) => !m.escapes).length;

  static const Solution empty = Solution(
    moves: <SolverMove>[],
    isComplete: true,
    nodesExplored: 0,
    isOptimal: true,
  );
}

enum SolverMode { bfs, dfs, greedy }

/// The puzzle solver (prompt §48).
///
/// Uses the *shared* [PhysicsEngine], so a solution found here is guaranteed to
/// be executable by the player — there is no second movement rule.
class Solver {
  const Solver({
    this.mode = SolverMode.bfs,
    this.maxNodes = 40000,
    this.expandSlides = true,
    this.physics = const PhysicsEngine(),
  });

  final SolverMode mode;
  final int maxNodes;
  final bool expandSlides;
  final PhysicsEngine physics;

  /// Breadth-first search for a shortest solution.
  Solution solve(Level level, {BoardState? from}) {
    final start = from ?? level.initialState;
    if (start.isSolved) return Solution.empty;

    switch (mode) {
      case SolverMode.greedy:
        return greedySolve(level, from: start) ??
            Solution(moves: const <SolverMove>[], isComplete: false, nodesExplored: 0);
      case SolverMode.dfs:
        return _dfs(level, start);
      case SolverMode.bfs:
        return _bfs(level, start);
    }
  }

  Solution _bfs(Level level, BoardState start) {
    final visited = <String>{start.key};
    final nodes = <_Node>[_Node(start, -1, null)];
    var explored = 0;

    for (var head = 0; head < nodes.length; head++) {
      final node = nodes[head];
      explored++;
      if (explored > maxNodes) {
        return Solution(
          moves: const <SolverMove>[],
          isComplete: false,
          nodesExplored: explored,
        );
      }
      final index = BoardCollisionIndex(level, node.state);
      for (final evaluation in physics.evaluateAll(index)) {
        if (!evaluation.canMove) continue;
        if (!expandSlides && !evaluation.escapes) continue;
        final nextState = physics.applyMove(index, evaluation.arrowIndex, evaluation);
        if (nextState == node.state) continue;
        final key = nextState.key;
        if (visited.contains(key)) continue;
        visited.add(key);
        final move = SolverMove(
          arrowIndex: evaluation.arrowIndex,
          travel: evaluation.travel,
          escapes: evaluation.escapes,
          fromOffset: node.state.offsetAt(evaluation.arrowIndex),
        );
        final next = _Node(nextState, head, move);
        nodes.add(next);
        if (nextState.isSolved) {
          return Solution(
            moves: _reconstruct(nodes, next),
            isComplete: true,
            nodesExplored: explored,
            isOptimal: true,
          );
        }
      }
    }
    return Solution(
      moves: const <SolverMove>[],
      isComplete: false,
      nodesExplored: explored,
    );
  }

  Solution _dfs(Level level, BoardState start) {
    final visited = <String>{start.key};
    final path = <SolverMove>[];
    var explored = 0;

    bool visit(BoardState state) {
      if (state.isSolved) return true;
      if (explored++ > maxNodes) return false;
      final index = BoardCollisionIndex(level, state);
      for (final evaluation in physics.evaluateAll(index)) {
        if (!evaluation.canMove) continue;
        if (!expandSlides && !evaluation.escapes) continue;
        final nextState = physics.applyMove(index, evaluation.arrowIndex, evaluation);
        if (nextState == state) continue;
        if (!visited.add(nextState.key)) continue;
        path.add(SolverMove(
          arrowIndex: evaluation.arrowIndex,
          travel: evaluation.travel,
          escapes: evaluation.escapes,
          fromOffset: state.offsetAt(evaluation.arrowIndex),
        ));
        if (visit(nextState)) return true;
        path.removeLast();
      }
      return false;
    }

    final ok = visit(start);
    return Solution(
      moves: List<SolverMove>.from(path),
      isComplete: ok,
      nodesExplored: explored,
    );
  }

  /// Fast heuristic solution: repeatedly remove any arrow that can escape.
  ///
  /// This is the *canonical* solution that the generator guarantees by
  /// construction, and it is what the hint system follows.
  Solution? greedySolve(
    Level level, {
    BoardState? from,
    List<int>? preferredOrder,
    bool allowSlides = false,
  }) {
    var state = from ?? level.initialState;
    final moves = <SolverMove>[];
    var guard = level.arrowCount * level.arrowCount + 64;

    while (!state.isSolved && guard-- > 0) {
      final index = BoardCollisionIndex(level, state);
      final evaluations = physics.evaluateAll(index);
      SolverMove? chosen;
      for (final order in _orderings(index.activeIndices, preferredOrder)) {
        final evaluation = evaluations.firstWhere(
          (e) => e.arrowIndex == order,
          orElse: () => MoveEvaluation(
            arrowIndex: order,
            canMove: false,
            travel: 0,
            escapes: false,
            exitDistance: 0,
          ),
        );
        if (evaluation.canMove && evaluation.escapes) {
          chosen = SolverMove(
            arrowIndex: evaluation.arrowIndex,
            travel: evaluation.travel,
            escapes: true,
            fromOffset: state.offsetAt(evaluation.arrowIndex),
          );
          break;
        }
      }
      if (chosen == null && allowSlides) {
        for (final evaluation in evaluations) {
          if (evaluation.canMove) {
            chosen = SolverMove(
              arrowIndex: evaluation.arrowIndex,
              travel: evaluation.travel,
              escapes: false,
              fromOffset: state.offsetAt(evaluation.arrowIndex),
            );
            break;
          }
        }
      }
      if (chosen == null) {
        return Solution(
          moves: moves,
          isComplete: false,
          nodesExplored: moves.length,
        );
      }
      final evaluation = physics.evaluate(
        BoardCollisionIndex(level, state),
        chosen.arrowIndex,
      );
      state = physics.applyMove(
        BoardCollisionIndex(level, state),
        chosen.arrowIndex,
        evaluation,
      );
      moves.add(chosen);
    }
    return Solution(
      moves: moves,
      isComplete: state.isSolved,
      nodesExplored: moves.length,
    );
  }

  Iterable<int> _orderings(List<int> active, List<int>? preferred) sync* {
    if (preferred != null) {
      for (final i in preferred) {
        if (active.contains(i)) yield i;
      }
    }
    for (final i in active) {
      yield i;
    }
  }

  List<SolverMove> _reconstruct(List<_Node> nodes, _Node end) {
    final out = <SolverMove>[];
    var current = end;
    while (current.parent >= 0) {
      out.add(current.move!);
      current = nodes[current.parent];
    }
    return out.reversed.toList();
  }
}

class _Node {
  _Node(this.state, this.parent, this.move);

  final BoardState state;
  final int parent;
  final SolverMove? move;
}
