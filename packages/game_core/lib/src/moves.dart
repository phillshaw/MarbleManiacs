import 'board.dart';
import 'cards.dart';

/// One thing a player can do on their turn.
sealed class Move {
  const Move();
}

/// Ace, King or Joker: a marble leaves Home for its Come Out seat.
class ComeOutMove extends Move {
  const ComeOutMove(this.card, this.marble);
  final Card card;
  final MarbleId marble;

  @override
  String toString() => '$card: $marble comes out';
}

/// The card's full count on one marble. Negative [steps] for the Four.
class StepMove extends Move {
  const StepMove(this.card, this.marble, this.steps);
  final Card card;
  final MarbleId marble;
  final int steps;

  @override
  String toString() => '$card: $marble ${steps > 0 ? '+' : ''}$steps';
}

/// A Seven or Jack split between two different marbles, applied in order.
class SplitMove extends Move {
  const SplitMove(this.card, this.first, this.firstSteps, this.second)
    : assert(firstSteps > 0);
  final Card card;
  final MarbleId first;
  final int firstSteps;
  final MarbleId second;

  int get secondSteps => card.rank.steps - firstSteps;

  @override
  String toString() => '$card: $first +$firstSteps, $second +$secondSteps';
}

/// The Jack's alternative to moving 11: two marbles trade seats.
class SwapMove extends Move {
  const SwapMove(this.card, this.a, this.b);
  final Card card;
  final MarbleId a;
  final MarbleId b;

  @override
  String toString() => '$card: swap $a and $b';
}

/// No card in hand can move anything: throw one into the center.
class DiscardMove extends Move {
  const DiscardMove(this.card);
  final Card card;

  @override
  String toString() => '$card: thrown in';
}

/// No Come Out card and nothing on the track: fold the hand until the next deal.
class FoldMove extends Move {
  const FoldMove();

  @override
  String toString() => 'fold';
}

/// What happened, in order, so the app can animate it.
sealed class GameEvent {
  const GameEvent();
}

class MarbleMoved extends GameEvent {
  const MarbleMoved(this.marble, this.path);
  final MarbleId marble;

  /// Every spot the marble passes through, starting where it was.
  final List<Spot> path;
}

class MarbleSentHome extends GameEvent {
  const MarbleSentHome(this.marble, this.from, {required this.by});
  final MarbleId marble;
  final Spot from;

  /// The marble that landed on or swept past it.
  final MarbleId by;
}

class MarblesSwapped extends GameEvent {
  const MarblesSwapped(this.a, this.b);
  final MarbleId a;
  final MarbleId b;
}

class CardPlayed extends GameEvent {
  const CardPlayed(this.station, this.card);
  final int station;
  final Card card;
}

class HandFolded extends GameEvent {
  const HandFolded(this.station);
  final int station;
}

class CardsDealt extends GameEvent {
  const CardsDealt(this.dealerStation, this.count, {required this.reshuffled});
  final int dealerStation;
  final int count;
  final bool reshuffled;
}

class PlayerFinished extends GameEvent {
  const PlayerFinished(this.station);
  final int station;
}

class GameWon extends GameEvent {
  const GameWon(this.stations);
  final List<int> stations;
}
