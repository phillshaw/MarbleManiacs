import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:game_core/game_core.dart';

/// Runs one game on this phone: the person plays station 0 and computer
/// players take every other seat.
class GameController extends ChangeNotifier {
  GameController({
    required int opponents,
    Random? rng,
    this.botDelay = const Duration(milliseconds: 700),
  }) : _rng = rng ?? Random() {
    final config = GameConfig(
      stations: GameConfig.defaultStations(opponents + 1),
    );
    final (state, events) = Rules.newGame(config, _rng);
    _state = state;
    _log(events);
    _scheduleBots();
  }

  static const humanStation = 0;

  final Random _rng;
  final Duration botDelay;
  late final Bot _bot = Bot(rng: _rng);

  late GameState _state;
  GameState get state => _state;

  /// Plain-language lines about what just happened, newest last.
  final List<String> history = [];

  Timer? _botTimer;
  Card? _selected;

  /// The card the person has picked, waiting for them to choose a move.
  Card? get selectedCard => _selected;

  bool get isHumanTurn =>
      !_state.isOver && _state.current.station == humanStation;

  List<Card> get humanHand =>
      _state.players.firstWhere((p) => p.station == humanStation).hand;

  List<Move> get legalMoves =>
      isHumanTurn ? Rules.legalMoves(_state) : const [];

  /// Moves open with the selected card, or the throw-in / fold choices when
  /// nothing can move.
  List<Move> get movesForSelection {
    final moves = legalMoves;
    if (moves.isNotEmpty &&
        moves.every((m) => m is DiscardMove || m is FoldMove)) {
      return moves
          .where((m) => m is FoldMove || _cardOf(m) == _selected)
          .toList();
    }
    if (_selected == null) return const [];
    return moves.where((m) => _cardOf(m) == _selected).toList();
  }

  /// Whether the person can't move anything and must throw a card in or fold.
  bool get mustDiscard {
    final moves = legalMoves;
    return moves.isNotEmpty &&
        moves.every((m) => m is DiscardMove || m is FoldMove);
  }

  /// Cards in the person's hand that have at least one move.
  Set<Card> get playableCards => {
    for (final m in legalMoves)
      if (m is! FoldMove) _cardOf(m)!,
  };

  void selectCard(Card card) {
    if (!isHumanTurn) return;
    _selected = _selected == card ? null : card;
    notifyListeners();
  }

  void play(Move move) {
    if (!isHumanTurn) return;
    _apply(move);
  }

  void _apply(Move move) {
    final station = _state.current.station;
    final (next, events) = Rules.apply(_state, move, _rng);
    _state = next;
    _selected = null;
    history.add('${stationName(station)}: ${describeMove(move)}');
    _log(events);
    notifyListeners();
    _scheduleBots();
  }

  void _scheduleBots() {
    _botTimer?.cancel();
    if (_state.isOver || _state.current.station == humanStation) return;
    _botTimer = Timer(botDelay, () => _apply(_bot.choose(_state)));
  }

  /// Plays every bot turn now. Used by tests.
  @visibleForTesting
  void playBotsNow() {
    while (!_state.isOver && _state.current.station != humanStation) {
      _botTimer?.cancel();
      _apply(_bot.choose(_state));
    }
  }

  void _log(List<GameEvent> events) {
    for (final e in events) {
      switch (e) {
        case MarbleSentHome(:final marble, :final by):
          history.add(
            '${stationName(by.station)} sent '
            '${stationName(marble.station)}\'s marble home',
          );
        case CardsDealt(:final count, :final reshuffled):
          history.add(
            '${reshuffled ? 'Shuffled and dealt' : 'Dealt'} $count cards each',
          );
        case PlayerFinished(:final station):
          history.add('${stationName(station)} got all marbles home');
        case GameWon(:final stations):
          history.add('${stations.map(stationName).join(' and ')} won!');
        default:
          break;
      }
    }
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}

const stationNames = ['Blue', 'Purple', 'Red', 'Yellow', 'Green', 'Black'];

String stationName(int station) =>
    station == GameController.humanStation ? 'You' : stationNames[station];

Card? _cardOf(Move m) => switch (m) {
  ComeOutMove(:final card) ||
  StepMove(:final card) ||
  SplitMove(:final card) ||
  SwapMove(:final card) ||
  DiscardMove(:final card) => card,
  FoldMove() => null,
};

String _marble(MarbleId m) => m.station == GameController.humanStation
    ? 'marble ${m.index + 1}'
    : '${stationNames[m.station]}\'s marble';

/// A short description of [move] a player can read on a button.
String describeMove(Move move) => switch (move) {
  ComeOutMove(:final marble) => 'bring ${_marble(marble)} out',
  StepMove(:final marble, :final steps) =>
    steps < 0
        ? 'move ${_marble(marble)} back ${-steps}'
        : 'move ${_marble(marble)} $steps',
  SplitMove(:final first, :final firstSteps, :final second) =>
    'move ${_marble(first)} $firstSteps, '
        '${_marble(second)} ${move.secondSteps}',
  SwapMove(:final a, :final b) => 'swap ${_marble(a)} with ${_marble(b)}',
  DiscardMove(:final card) => 'throw in $card',
  FoldMove() => 'fold',
};

/// Marbles a move touches, for highlighting on the board.
Set<MarbleId> marblesIn(Move move) => switch (move) {
  ComeOutMove(:final marble) || StepMove(:final marble) => {marble},
  SplitMove(:final first, :final second) => {first, second},
  SwapMove(:final a, :final b) => {a, b},
  DiscardMove() || FoldMove() => {},
};
