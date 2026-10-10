import 'dart:math';

import 'board.dart';
import 'cards.dart';
import 'moves.dart';
import 'rules.dart';
import 'state.dart';

/// A computer player. It tries every legal move, scores the board that
/// results from where its own side stands against everyone else, and plays
/// the best, with a little noise so it isn't perfectly predictable.
class Bot {
  Bot({Random? rng, this.noise = 4}) : _rng = rng ?? Random();

  final Random _rng;

  /// How much randomness goes into each score. 0 plays the same every time.
  final double noise;

  Move choose(GameState state) {
    final moves = Rules.legalMoves(state);
    if (moves.isEmpty) throw StateError('No legal moves');
    if (moves.length == 1) return moves.single;

    final me = state.current.station;

    // Out of moves: throw the card we'd miss least.
    if (moves.every((m) => m is DiscardMove || m is FoldMove)) {
      return moves.firstWhere(
        (m) => m is FoldMove,
        orElse: () => moves.cast<DiscardMove>().reduce(
          (a, b) =>
              _keepValue(state, me, a.card) <= _keepValue(state, me, b.card)
              ? a
              : b,
        ),
      );
    }

    Move? best;
    var bestScore = double.negativeInfinity;
    for (final move in moves) {
      if (move is DiscardMove || move is FoldMove) continue;
      final after = Rules.apply(state, move, Random(0)).$1;
      var score = evaluate(after, me);
      // Spending a come-out card on a plain move wastes it while marbles
      // are still waiting at Home.
      if (move is! ComeOutMove &&
          _cardOf(move).rank.isComeOut &&
          state.marblesOf(me).any((m) => state.spots[m] is InHome)) {
        score -= 6;
      }
      score += _rng.nextDouble() * noise;
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best!;
  }

  /// How good the board is for [station]'s side.
  static double evaluate(GameState state, int station) {
    if (state.isOver) {
      return state.winners.contains(station) ? 1e6 : -1e6;
    }
    final team = state.config.teamOf(station);
    var score = 0.0;
    for (final s in state.config.stations) {
      var standing = 0.0;
      for (final m in state.marblesOf(s)) {
        standing += _marbleValue(state, m);
      }
      score += team.contains(s) ? standing : -standing / 2;
    }
    return score;
  }

  static double _marbleValue(GameState state, MarbleId m) =>
      switch (state.spots[m]!) {
        InHome() => -25,
        // Safe on its own Come Out, but it has to go round the whole board.
        OnTrack(:final seat) =>
          Board.progress(m.station, seat).toDouble() +
              (state.isProtected(m) ? 6 : 0),
        // Deeper in the row leaves room for the next marble.
        InDestination(:final slot) => 130.0 + slot * 4,
      };

  static double _keepValue(GameState state, int me, Card card) {
    final waiting = state.marblesOf(me).any((m) => state.spots[m] is InHome);
    if (card.rank.isComeOut && waiting) return 100;
    return switch (card.rank) {
      Rank.seven || Rank.jack => 50,
      Rank.four => 40,
      _ => card.rank.steps.toDouble(),
    };
  }

  static Card _cardOf(Move move) => switch (move) {
    ComeOutMove(:final card) ||
    StepMove(:final card) ||
    SplitMove(:final card) ||
    SwapMove(:final card) ||
    DiscardMove(:final card) => card,
    FoldMove() => throw ArgumentError('Fold has no card'),
  };
}
