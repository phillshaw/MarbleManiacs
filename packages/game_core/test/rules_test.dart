import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

/// Builds a two-player (or [stations]) table with chosen marbles and hand.
/// Unlisted marbles are at Home. Station 0 is to play.
GameState table({
  Map<MarbleId, Spot> spots = const {},
  List<Rank> hand = const [],
  List<int> stations = const [0, 3],
  List<List<int>> teams = const [],
}) {
  final config = GameConfig(stations: stations, teams: teams);
  var id = 1000;
  return GameState(
    config: config,
    players: [
      for (final s in stations)
        PlayerState(
          s,
          s == stations.first
              ? [for (final r in hand) Card(id++, r, Suit.spades)]
              : [Card(id++, Rank.two, Suit.clubs)],
        ),
    ],
    spots: {
      for (final s in stations)
        for (var i = 0; i < Board.marblesPerPlayer; i++)
          MarbleId(s, i): const InHome(),
      ...spots,
    },
    shoe: buildShoe(stations.length),
    discards: [],
    dealIndex: 0,
    dealer: stations.length - 1,
    turn: 0,
  );
}

const a0 = MarbleId(0, 0),
    a1 = MarbleId(0, 1),
    a2 = MarbleId(0, 2),
    a3 = MarbleId(0, 3);
const b0 = MarbleId(3, 0), b1 = MarbleId(3, 1);

/// Track seat that is [progress] along station 0's lap.
int seat(int progress) => Board.wrap(Board.comeOut(0) + progress);

List<String> movesOf(GameState s, [Rank? rank]) => [
  for (final m in Rules.legalMoves(s))
    if (rank == null ||
        switch (m) {
          ComeOutMove(:final card) ||
          StepMove(:final card) ||
          SplitMove(:final card) ||
          SwapMove(:final card) => card.rank == rank,
          DiscardMove() || FoldMove() => false,
        })
      m.toString(),
];

GameState play(GameState s, bool Function(Move) pick) {
  final move = Rules.legalMoves(s).firstWhere(pick);
  return Rules.apply(s, move, Random(1)).$1;
}

void main() {
  group('cards', () {
    test('every table empties its shoe exactly over one schedule', () {
      for (var players = 2; players <= 6; players++) {
        final dealt = dealSchedule(players).fold(0, (a, b) => a + b) * players;
        expect(dealt, buildShoe(players).length, reason: '$players players');
      }
    });

    test('Jokers only for 3 and 5 players', () {
      for (var players = 2; players <= 6; players++) {
        final jokers = buildShoe(players).where((c) => c.rank == Rank.joker);
        expect(jokers.length, players == 3 || players == 5 ? 2 : 0);
      }
    });
  });

  group('board', () {
    test('a lap is 107 seats from Come Out to the Destination branch', () {
      for (var s = 0; s < Board.stations; s++) {
        expect(Board.progress(s, Board.destinationBranch(s)), 107);
      }
    });
  });

  group('coming out', () {
    test('Ace, King and Joker bring a marble out; others do not', () {
      for (final r in Rank.values) {
        final s = table(hand: [r]);
        expect(
          Rules.legalMoves(s).any((m) => m is ComeOutMove),
          r.isComeOut,
          reason: r.name,
        );
      }
    });

    test('blocked by your own marble on Come Out', () {
      final s = table(hand: [Rank.ace], spots: {a0: OnTrack(seat(0))});
      expect(Rules.legalMoves(s).whereType<ComeOutMove>(), isEmpty);
    });

    test('knocks an opponent off your Come Out', () {
      var s = table(hand: [Rank.king], spots: {b0: OnTrack(seat(0))});
      s = play(s, (m) => m is ComeOutMove);
      expect(s.spots[b0], const InHome());
      expect(s.spots.values.whereType<OnTrack>().single.seat, seat(0));
    });
  });

  group('moving', () {
    test('lands on an opponent and sends them Home', () {
      var s = table(
        hand: [Rank.five],
        spots: {a0: OnTrack(seat(10)), b0: OnTrack(seat(15))},
      );
      s = play(s, (m) => m is StepMove);
      expect(s.spots[a0], OnTrack(seat(15)));
      expect(s.spots[b0], const InHome());
    });

    test('cannot land on your own marble', () {
      final s = table(
        hand: [Rank.five],
        spots: {a0: OnTrack(seat(10)), a1: OnTrack(seat(15))},
      );
      expect(movesOf(s), isNot(contains('5s: $a0 +5')));
      expect(movesOf(s), contains('5s: $a1 +5'));
    });

    test('may pass your own marble on the track', () {
      final s = table(
        hand: [Rank.five],
        spots: {a0: OnTrack(seat(10)), a1: OnTrack(seat(12))},
      );
      expect(movesOf(s), contains('5s: $a0 +5'));
    });

    test('cannot pass or land on a marble guarding its Come Out', () {
      final guard = Board.comeOut(3);
      final s = table(
        hand: [Rank.five, Rank.three],
        spots: {a0: OnTrack(guard - 3), b0: OnTrack(guard)},
      );
      expect(movesOf(s, Rank.five), isEmpty);
      expect(movesOf(s, Rank.three), isEmpty);
    });

    test('a marble on another station\'s Come Out has no protection', () {
      final target = Board.comeOut(2);
      final s = table(
        hand: [Rank.five],
        spots: {a0: OnTrack(target - 5), b0: OnTrack(target)},
      );
      expect(movesOf(s), contains('5s: $a0 +5'));
    });

    test('back 4 from Come Out, then forward into the Destination', () {
      var s = table(hand: [Rank.four, Rank.six], spots: {a0: OnTrack(seat(0))});
      s = play(s, (m) => m is StepMove && m.steps == -4);
      // Hand the turn back to station 0 for the follow-up card.
      s.turn = 0;
      s = play(s, (m) => m is StepMove && m.steps == 6);
      // 104 -> 105, 106, 107 (branch), then Destination slots 0, 1, 2.
      expect(s.spots[a0], const InDestination(2));
    });

    test('Four moves backwards', () {
      var s = table(hand: [Rank.four], spots: {a0: OnTrack(seat(20))});
      s = play(s, (m) => m is StepMove);
      expect(s.spots[a0], OnTrack(seat(16)));
    });

    test('Four from Come Out backs past it toward the Destination', () {
      var s = table(hand: [Rank.four], spots: {a0: OnTrack(seat(0))});
      s = play(s, (m) => m is StepMove);
      expect(s.spots[a0], OnTrack(seat(104)));
      expect(Board.progress(0, seat(104)), 104);
    });
  });

  group('Destination', () {
    test('needs the exact count; a marble that would overshoot stays put', () {
      final s = table(
        hand: [Rank.six, Rank.five],
        spots: {a0: OnTrack(seat(106))},
      );
      // 106 -> 107 (branch) -> slots 0..3: five reaches slot 3, six overshoots.
      expect(movesOf(s, Rank.six), isEmpty);
      expect(movesOf(s, Rank.five), ['5s: $a0 +5']);
    });

    test('cannot jump your own marble in the Destination', () {
      final s = table(
        hand: [Rank.three],
        spots: {a0: OnTrack(seat(106)), a1: const InDestination(1)},
      );
      expect(movesOf(s, Rank.three), isEmpty);
    });

    test('marbles can move up inside the Destination', () {
      final s = table(hand: [Rank.two], spots: {a0: const InDestination(1)});
      expect(movesOf(s, Rank.two), ['2s: $a0 +2']);
    });
  });

  group('King', () {
    test('sweeps everyone passed once all your marbles are out', () {
      var s = table(
        hand: [Rank.king],
        spots: {
          a0: OnTrack(seat(10)),
          a1: const InDestination(3),
          a2: const InDestination(2),
          a3: OnTrack(seat(50)),
          b0: OnTrack(seat(14)),
          b1: OnTrack(seat(18)),
        },
      );
      s = play(s, (m) => m is StepMove && m.marble == a0);
      expect(s.spots[a0], OnTrack(seat(23)));
      expect(s.spots[b0], const InHome());
      expect(s.spots[b1], const InHome());
    });

    test('does not sweep while a marble is still Home', () {
      var s = table(
        hand: [Rank.king],
        spots: {
          a0: OnTrack(seat(10)),
          a1: OnTrack(seat(0)),
          b0: OnTrack(seat(14)),
        },
      );
      s = play(s, (m) => m is StepMove && m.marble == a0);
      expect(s.spots[b0], OnTrack(seat(14)));
    });
  });

  group('split', () {
    test('a Seven splits between two marbles', () {
      var s = table(
        hand: [Rank.seven],
        spots: {a0: OnTrack(seat(105)), a1: OnTrack(seat(20))},
      );
      s = play(s, (m) => m is SplitMove && m.first == a0 && m.firstSteps == 3);
      expect(s.spots[a0], const InDestination(0));
      expect(s.spots[a1], OnTrack(seat(24)));
    });

    test('a Jack splits too, but a Queen does not', () {
      final spots = {a0: OnTrack(seat(30)), a1: OnTrack(seat(60))};
      expect(
        Rules.legalMoves(table(hand: [Rank.jack], spots: spots))
            .whereType<SplitMove>(),
        isNotEmpty,
      );
      expect(
        Rules.legalMoves(table(hand: [Rank.queen], spots: spots))
            .whereType<SplitMove>(),
        isEmpty,
      );
    });

    test('no split with only one marble in play', () {
      final s = table(hand: [Rank.seven], spots: {a0: OnTrack(seat(30))});
      expect(Rules.legalMoves(s).whereType<SplitMove>(), isEmpty);
    });
  });

  group('Jack swap', () {
    test('can swap two opponents', () {
      const c0 = MarbleId(1, 0);
      var s = table(
        stations: [0, 1, 3],
        hand: [Rank.jack],
        spots: {a0: OnTrack(seat(5)), b0: OnTrack(70), c0: OnTrack(90)},
      );
      s = play(
        s,
        (m) =>
            m is SwapMove && m.a == c0 && m.b == b0 ||
            m is SwapMove && m.a == b0 && m.b == c0,
      );
      expect(s.spots[b0], const OnTrack(90));
      expect(s.spots[c0], const OnTrack(70));
    });

    test('needs a marble of yours outside Home', () {
      final s = table(
        hand: [Rank.jack],
        spots: {b0: OnTrack(70), b1: OnTrack(80)},
      );
      expect(Rules.legalMoves(s).whereType<SwapMove>(), isEmpty);
    });

    test('cannot touch a marble guarding its Come Out', () {
      final s = table(
        hand: [Rank.jack],
        spots: {a0: OnTrack(seat(5)), b0: OnTrack(Board.comeOut(3))},
      );
      expect(Rules.legalMoves(s).whereType<SwapMove>(), isEmpty);
    });
  });

  group('no move', () {
    test('throw a card in when nothing can move', () {
      final s = table(hand: [Rank.queen, Rank.five]);
      expect(
        Rules.legalMoves(s).every((m) => m is DiscardMove || m is FoldMove),
        isTrue,
      );
    });

    test('fold only with no Come Out card and nothing on the track', () {
      expect(
        Rules.legalMoves(table(hand: [Rank.five])),
        contains(isA<FoldMove>()),
      );
      expect(
        Rules.legalMoves(table(hand: [Rank.ace])),
        isNot(contains(isA<FoldMove>())),
      );
      expect(
        Rules.legalMoves(
          table(hand: [Rank.five], spots: {a0: OnTrack(seat(9))}),
        ),
        isNot(contains(isA<FoldMove>())),
      );
    });

    test('must play a legal move rather than throw a card', () {
      final s = table(hand: [Rank.five], spots: {a0: OnTrack(seat(9))});
      expect(Rules.legalMoves(s).whereType<DiscardMove>(), isEmpty);
    });
  });

  group('teams', () {
    final pairs = GameConfig.acrossTeams([0, 1, 3, 4]);
    const partner = MarbleId(3, 0), rival = MarbleId(1, 0);

    test('cannot land on your partner', () {
      final s = table(
        stations: [0, 1, 3, 4],
        teams: pairs,
        hand: [Rank.five],
        spots: {a0: OnTrack(seat(10)), partner: OnTrack(seat(15))},
      );
      expect(movesOf(s, Rank.five), isEmpty);
    });

    test('can pass your partner', () {
      final s = table(
        stations: [0, 1, 3, 4],
        teams: pairs,
        hand: [Rank.five],
        spots: {a0: OnTrack(seat(10)), partner: OnTrack(seat(12))},
      );
      expect(movesOf(s, Rank.five), ['5s: $a0 +5']);
    });

    test('cannot come out onto your partner', () {
      final s = table(
        stations: [0, 1, 3, 4],
        teams: pairs,
        hand: [Rank.ace],
        spots: {partner: OnTrack(seat(0))},
      );
      expect(Rules.legalMoves(s).whereType<ComeOutMove>(), isEmpty);
    });

    test('the King sweep skips your partner', () {
      var s = table(
        stations: [0, 1, 3, 4],
        teams: pairs,
        hand: [Rank.king],
        spots: {
          a0: OnTrack(seat(10)),
          a1: const InDestination(3),
          a2: const InDestination(2),
          a3: const InDestination(1),
          partner: OnTrack(seat(14)),
          rival: OnTrack(seat(17)),
        },
      );
      s = play(s, (m) => m is StepMove);
      expect(s.spots[partner], OnTrack(seat(14)));
      expect(s.spots[rival], const InHome());
    });

    test('a team wins only when both partners are home', () {
      final stations = [0, 1, 3, 4];
      final teams = GameConfig.acrossTeams(stations);
      expect(teams, [
        [0, 3],
        [1, 4],
      ]);
      var s = table(
        stations: stations,
        teams: teams,
        hand: [Rank.ace, Rank.two],
        spots: {
          a0: const InDestination(3),
          a1: const InDestination(2),
          a2: const InDestination(1),
          a3: OnTrack(seat(107)),
        },
      );
      s = play(s, (m) => m is StepMove);
      expect(s.players.first.finished, isTrue);
      expect(s.isOver, isFalse, reason: 'partner at station 3 still playing');
      expect(s.players.first.hand, isEmpty, reason: 'finished players sit out');
    });
  });

  group('whole games', () {
    for (final (name, stations, teamsOf) in [
      ('2 players', [0, 3], (List<int> s) => <List<int>>[]),
      ('3 players', [0, 2, 4], (List<int> s) => <List<int>>[]),
      ('4 players', [0, 1, 3, 4], (List<int> s) => <List<int>>[]),
      ('4 players in pairs', [0, 1, 3, 4], GameConfig.acrossTeams),
      ('5 players', [0, 1, 2, 3, 4], (List<int> s) => <List<int>>[]),
      ('6 players', [0, 1, 2, 3, 4, 5], (List<int> s) => <List<int>>[]),
      ('6 players in pairs', [0, 1, 2, 3, 4, 5], GameConfig.acrossTeams),
      ('6 players, halves', [0, 1, 2, 3, 4, 5], GameConfig.halvesTeams),
    ]) {
      test('$name: bots always finish a game', () {
        for (var seed = 0; seed < 40; seed++) {
          final rng = Random(seed);
          final config = GameConfig(
            stations: stations,
            teams: teamsOf(stations),
          );
          var (state, _) = Rules.newGame(config, rng);
          final bot = Bot(rng: rng);
          var turns = 0;
          while (!state.isOver) {
            state = Rules.apply(state, bot.choose(state), rng).$1;
            // Cards are never lost or duplicated.
            final cards =
                state.shoe.length +
                state.discards.length +
                state.players.fold(0, (n, p) => n + p.hand.length);
            expect(cards, buildShoe(stations.length).length);
            expect(++turns, lessThan(20000), reason: 'seed $seed stuck');
          }
          for (final s in state.winners) {
            expect(state.isFinished(s), isTrue);
          }
        }
      });
    }
  });
}
