import 'dart:math';

import 'board.dart';
import 'cards.dart';
import 'moves.dart';
import 'state.dart';

/// The rules of Aggies and Jokers. Everything here is a pure function of the
/// state, apart from the shuffles, which take the caller's [Random] so a
/// server or a test can replay a game exactly.
abstract final class Rules {
  /// Seats everyone, finds the first dealer (first Ace dealt face up) and
  /// deals the opening hands.
  static (GameState, List<GameEvent>) newGame(GameConfig config, Random rng) {
    final shoe = shuffled(buildShoe(config.players), rng);

    // Deal face up, clockwise, until someone turns an Ace.
    var dealer = 0;
    for (var i = shoe.length - 1, p = 0; i >= 0; i--, p++) {
      if (shoe[i].rank == Rank.ace) {
        dealer = p % config.players;
        break;
      }
    }

    final state = GameState(
      config: config,
      players: [for (final s in config.stations) PlayerState(s, [])],
      spots: {
        for (final s in config.stations)
          for (var i = 0; i < Board.marblesPerPlayer; i++)
            MarbleId(s, i): const InHome(),
      },
      shoe: shuffled(shoe, rng),
      discards: [],
      dealIndex: 0,
      // [_deal] passes the deal to the left, so start one seat to the right.
      dealer: (dealer - 1) % config.players,
      turn: 0,
    );
    final events = <GameEvent>[];
    _deal(state, rng, events);
    return (state, events);
  }

  /// Every move open to the player whose turn it is.
  static List<Move> legalMoves(GameState state) {
    if (state.isOver) return const [];
    final player = state.current;
    if (player.isOut) return const [];

    final station = player.station;
    final mine = state.marblesOf(station).toList();
    final inPlay = [
      for (final m in mine)
        if (state.spots[m] is! InHome) m,
    ];
    final onTrack = [
      for (final m in mine)
        if (state.spots[m] is OnTrack) m,
    ];
    final atHome = [
      for (final m in mine)
        if (state.spots[m] is InHome) m,
    ];

    final moves = <Move>[];
    for (final card in player.hand) {
      final rank = card.rank;

      if (rank.isComeOut && atHome.isNotEmpty) {
        final move = ComeOutMove(card, atHome.first);
        if (_comeOutTarget(state, move.marble) != null) moves.add(move);
      }

      if (rank.isBackward) {
        for (final m in onTrack) {
          if (_walk(state, m, -rank.steps) != null) {
            moves.add(StepMove(card, m, -rank.steps));
          }
        }
      } else {
        for (final m in inPlay) {
          if (_walk(state, m, rank.steps) != null) {
            moves.add(StepMove(card, m, rank.steps));
          }
        }
      }

      if (rank.isSplittable) {
        for (final a in inPlay) {
          for (final b in inPlay) {
            if (a == b) continue;
            for (var n = 1; n < rank.steps; n++) {
              final first = _walk(state, a, n);
              if (first == null) continue;
              final after = state.copy();
              _commitWalk(after, a, first, []);
              if (_walk(after, b, rank.steps - n) != null) {
                moves.add(SplitMove(card, a, n, b));
              }
            }
          }
        }
      }

      if (rank == Rank.jack && inPlay.isNotEmpty) {
        final swappable = [
          for (final e in state.spots.entries)
            if (e.value is OnTrack && !state.isProtected(e.key)) e.key,
        ];
        for (var i = 0; i < swappable.length; i++) {
          for (var j = i + 1; j < swappable.length; j++) {
            // Swapping two of the same player's marbles changes nothing.
            if (swappable[i].station == swappable[j].station) continue;
            moves.add(SwapMove(card, swappable[i], swappable[j]));
          }
        }
      }
    }

    if (moves.isEmpty) {
      moves.addAll([for (final c in player.hand) DiscardMove(c)]);
    }
    final hasComeOutCard = player.hand.any((c) => c.rank.isComeOut);
    if (!hasComeOutCard && onTrack.isEmpty) moves.add(const FoldMove());
    return moves;
  }

  static bool isLegal(GameState state, Move move) {
    final key = move.toString();
    final card = switch (move) {
      ComeOutMove(:final card) ||
      StepMove(:final card) ||
      SplitMove(:final card) ||
      SwapMove(:final card) ||
      DiscardMove(:final card) => card,
      FoldMove() => null,
    };
    if (card != null && !state.current.hand.contains(card)) return false;
    return legalMoves(state).any((m) => m.toString() == key);
  }

  /// Plays [move] for the current player and passes the turn. Throws if the
  /// move isn't legal, so a server can trust what it applies.
  static (GameState, List<GameEvent>) apply(
    GameState before,
    Move move,
    Random rng,
  ) {
    if (!isLegal(before, move)) {
      throw StateError('Illegal move: $move');
    }
    final state = before.copy();
    final player = state.current;
    final events = <GameEvent>[];

    void play(Card card) {
      player.hand.remove(card);
      state.discards.add(card);
      events.add(CardPlayed(player.station, card));
    }

    switch (move) {
      case ComeOutMove(:final card, :final marble):
        play(card);
        final seat = Board.comeOut(marble.station);
        final victim = state.marbleOnTrack(seat);
        if (victim != null) _sendHome(state, victim, marble, events);
        state.spots[marble] = OnTrack(seat);
        events.add(MarbleMoved(marble, [const InHome(), OnTrack(seat)]));
      case StepMove(:final card, :final marble, :final steps):
        play(card);
        _commitWalk(state, marble, _walk(state, marble, steps)!, events);
      case SplitMove(
        :final card,
        :final first,
        :final firstSteps,
        :final second,
      ):
        play(card);
        _commitWalk(state, first, _walk(state, first, firstSteps)!, events);
        final secondSteps = move.secondSteps;
        _commitWalk(state, second, _walk(state, second, secondSteps)!, events);
      case SwapMove(:final card, :final a, :final b):
        play(card);
        final spotA = state.spots[a]!;
        state.spots[a] = state.spots[b]!;
        state.spots[b] = spotA;
        events.add(MarblesSwapped(a, b));
      case DiscardMove(:final card):
        play(card);
      case FoldMove():
        state.discards.addAll(player.hand);
        player.hand.clear();
        player.folded = true;
        events.add(HandFolded(player.station));
    }

    _checkFinished(state, events);
    if (!state.isOver) _passTurn(state, rng, events);
    return (state, events);
  }

  // ---------------------------------------------------------------------------

  /// The Come Out seat if [marble] may come out onto it, else null.
  static int? _comeOutTarget(GameState state, MarbleId marble) {
    final seat = Board.comeOut(marble.station);
    final occupant = state.marbleOnTrack(seat);
    if (occupant == null) return seat;
    if (occupant.station == marble.station) return null;
    return _canSendHome(state, marble, occupant) ? seat : null;
  }

  /// Opponents can be sent Home; you and your partner can't, and nobody on
  /// their own Come Out can. Landing on a marble you can't send Home is
  /// illegal, and the King's sweep passes over it.
  static bool _canSendHome(GameState state, MarbleId mover, MarbleId victim) =>
      !state.isProtected(victim) &&
      !state.config.sameTeam(mover.station, victim.station);

  /// Follows [marble] for [steps] seats (negative is backwards) and reports
  /// where it ends up and who it sends Home, or null if the move is illegal.
  static _Walk? _walk(GameState state, MarbleId marble, int steps) {
    final start = state.spots[marble]!;
    final owner = marble.station;
    final path = <Spot>[start];
    final swept = <MarbleId>[];
    MarbleId? landedOn;

    // The King sweeps everyone it passes once all your marbles are out.
    final sweeping = steps == Rank.king.steps && state.allOutOfHome(owner);

    switch (start) {
      case InHome():
        return null;
      case InDestination(:final slot):
        if (steps < 0) return null;
        for (var k = 1; k <= steps; k++) {
          final s = slot + k;
          if (s >= Board.destinationLength) return null;
          // No jumping or landing on your own marble in the Destination.
          if (state.marbleInDestination(owner, s) != null) return null;
          path.add(InDestination(s));
        }
      case OnTrack(:final seat):
        final direction = steps.sign;
        final progress = Board.progress(owner, seat);
        for (var k = 1; k <= steps.abs(); k++) {
          final last = k == steps.abs();
          final p = progress + k * direction;
          if (direction > 0 && p >= Board.trackLength) {
            // Past the branch and into the Destination row.
            final s = p - Board.trackLength;
            if (s >= Board.destinationLength) return null;
            if (state.marbleInDestination(owner, s) != null) return null;
            path.add(InDestination(s));
            continue;
          }
          final here = Board.wrap(seat + k * direction);
          final occupant = state.marbleOnTrack(here);
          if (occupant != null) {
            // Nobody passes or lands on a marble guarding its Come Out.
            if (state.isProtected(occupant)) return null;
            if (last) {
              if (!_canSendHome(state, marble, occupant)) return null;
              landedOn = occupant;
            } else if (sweeping && _canSendHome(state, marble, occupant)) {
              swept.add(occupant);
            }
          }
          path.add(OnTrack(here));
        }
    }
    return _Walk(path, landedOn, swept);
  }

  static void _commitWalk(
    GameState state,
    MarbleId marble,
    _Walk walk,
    List<GameEvent> events,
  ) {
    for (final victim in [...walk.swept, ?walk.landedOn]) {
      _sendHome(state, victim, marble, events);
    }
    state.spots[marble] = walk.path.last;
    events.add(MarbleMoved(marble, walk.path));
  }

  static void _sendHome(
    GameState state,
    MarbleId victim,
    MarbleId by,
    List<GameEvent> events,
  ) {
    events.add(MarbleSentHome(victim, state.spots[victim]!, by: by));
    state.spots[victim] = const InHome();
  }

  static void _checkFinished(GameState state, List<GameEvent> events) {
    for (final p in state.players) {
      if (p.finished || !state.isFinished(p.station)) continue;
      p.finished = true;
      state.discards.addAll(p.hand);
      p.hand.clear();
      events.add(PlayerFinished(p.station));
      final team = state.config.teamOf(p.station);
      if (team.every(state.isFinished)) {
        state.winners = team;
        events.add(GameWon(team));
        return;
      }
    }
  }

  static void _passTurn(GameState state, Random rng, List<GameEvent> events) {
    final n = state.players.length;
    for (var i = 1; i <= n; i++) {
      final next = (state.turn + i) % n;
      if (!state.players[next].isOut) {
        state.turn = next;
        return;
      }
    }
    // Everyone has played out or folded.
    _deal(state, rng, events);
  }

  /// Passes the deal one seat clockwise and deals the next round.
  static void _deal(GameState state, Random rng, List<GameEvent> events) {
    final n = state.players.length;
    state.dealer = (state.dealer + 1) % n;
    final active = [
      for (var i = 1; i <= n; i++)
        if (!state.players[(state.dealer + i) % n].finished)
          state.players[(state.dealer + i) % n],
    ];

    final schedule = dealSchedule(state.config.players);
    var reshuffled = false;
    if (state.dealIndex >= schedule.length ||
        state.shoe.length < schedule[state.dealIndex] * active.length) {
      final all = [...state.shoe, ...state.discards];
      state.shoe
        ..clear()
        ..addAll(shuffled(all, rng));
      state.discards.clear();
      state.dealIndex = 0;
      reshuffled = true;
    }

    final count = schedule[state.dealIndex++];
    for (final p in state.players) {
      p.folded = false;
    }
    for (var c = 0; c < count; c++) {
      for (final p in active) {
        p.hand.add(state.shoe.removeLast());
      }
    }
    events.add(
      CardsDealt(
        state.players[state.dealer].station,
        count,
        reshuffled: reshuffled,
      ),
    );
    // Play starts left of the dealer.
    state.turn = state.players.indexOf(active.first);
  }
}

class _Walk {
  _Walk(this.path, this.landedOn, this.swept);
  final List<Spot> path;
  final MarbleId? landedOn;
  final List<MarbleId> swept;
}
