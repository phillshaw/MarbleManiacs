import 'board.dart';
import 'cards.dart';

/// Table setup chosen before the game starts.
class GameConfig {
  GameConfig({
    required this.stations,
    this.teams = const [],
    this.canKnockOutTeammate = true,
  }) {
    if (stations.length < 2 || stations.length > Board.stations) {
      throw ArgumentError('Aggies and Jokers seats 2 to 6 players');
    }
    final seen = <int>{};
    for (final team in teams) {
      for (final s in team) {
        if (!stations.contains(s) || !seen.add(s)) {
          throw ArgumentError(
            'Team station $s is not seated or is on two teams',
          );
        }
      }
    }
  }

  /// Occupied stations in clockwise order, which is also turn order.
  final List<int> stations;

  /// Groups of stations playing together. Empty means everyone for themselves.
  final List<List<int>> teams;

  /// Whether landing on a teammate sends them Home like anyone else.
  final bool canKnockOutTeammate;

  int get players => stations.length;

  /// Stations on the same side as [station], including itself.
  List<int> teamOf(int station) =>
      teams.firstWhere((t) => t.contains(station), orElse: () => [station]);

  bool sameTeam(int a, int b) => teamOf(a).contains(b);

  /// Where players sit for a table of [players]: spread as evenly as six
  /// stations allow, with seat 0 always taken by the host.
  static List<int> defaultStations(int players) => switch (players) {
    2 => [0, 3],
    3 => [0, 2, 4],
    4 => [0, 1, 3, 4],
    5 => [0, 1, 2, 3, 4],
    6 => [0, 1, 2, 3, 4, 5],
    _ => throw ArgumentError('Aggies and Jokers seats 2 to 6 players'),
  };

  /// Partners sit across from each other.
  static List<List<int>> acrossTeams(List<int> stations) => [
    for (final s in stations)
      if (s < Board.stations ~/ 2 && stations.contains(Board.opposite(s)))
        [s, Board.opposite(s)],
  ];

  /// One half of the board against the other.
  static List<List<int>> halvesTeams(List<int> stations) => [
    stations.where((s) => s < Board.stations ~/ 2).toList(),
    stations.where((s) => s >= Board.stations ~/ 2).toList(),
  ];
}

class PlayerState {
  PlayerState(this.station, this.hand, {this.folded = false});

  final int station;
  final List<Card> hand;
  bool folded;

  /// All four marbles home. A finished player sits out and roots for their
  /// partner.
  bool finished = false;

  bool get isOut => finished || folded || hand.isEmpty;

  PlayerState copy() =>
      PlayerState(station, [...hand], folded: folded)..finished = finished;
}

/// Everything about a game at one moment. Hands are included, so the server
/// keeps the full state and sends each phone a view with the other hands
/// hidden.
class GameState {
  GameState({
    required this.config,
    required this.players,
    required this.spots,
    required this.shoe,
    required this.discards,
    required this.dealIndex,
    required this.dealer,
    required this.turn,
    this.winners = const [],
  });

  final GameConfig config;

  /// In turn order; `players[i].station == config.stations[i]`.
  final List<PlayerState> players;
  final Map<MarbleId, Spot> spots;

  /// Cards not yet dealt, top of the shoe last.
  final List<Card> shoe;

  /// The pile in the center of the board.
  final List<Card> discards;

  /// Which deal of the current pass through the shoe comes next.
  int dealIndex;

  /// Index into [players].
  int dealer;
  int turn;

  /// Stations that have won; empty while the game is on.
  List<int> winners;

  bool get isOver => winners.isNotEmpty;

  PlayerState get current => players[turn];

  Iterable<MarbleId> marblesOf(int station) => [
    for (var i = 0; i < Board.marblesPerPlayer; i++) MarbleId(station, i),
  ];

  MarbleId? marbleOnTrack(int seat) {
    for (final e in spots.entries) {
      final s = e.value;
      if (s is OnTrack && s.seat == seat) return e.key;
    }
    return null;
  }

  MarbleId? marbleInDestination(int station, int slot) {
    for (final m in marblesOf(station)) {
      final s = spots[m];
      if (s is InDestination && s.slot == slot) return m;
    }
    return null;
  }

  /// A marble sitting on its own Come Out seat can't be knocked out or passed.
  bool isProtected(MarbleId m) {
    final s = spots[m];
    return s is OnTrack && s.seat == Board.comeOut(m.station);
  }

  bool isFinished(int station) =>
      marblesOf(station).every((m) => spots[m] is InDestination);

  bool allOutOfHome(int station) =>
      marblesOf(station).every((m) => spots[m] is! InHome);

  GameState copy() => GameState(
    config: config,
    players: [for (final p in players) p.copy()],
    spots: Map.of(spots),
    shoe: [...shoe],
    discards: [...discards],
    dealIndex: dealIndex,
    dealer: dealer,
    turn: turn,
    winners: [...winners],
  );
}
