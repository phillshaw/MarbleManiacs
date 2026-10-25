import 'package:flutter/material.dart' hide Card;
import 'package:game_core/game_core.dart';

import 'board_view.dart';
import 'game_controller.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Move? _preview;

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final state = c.state;
        final moves = c.movesForSelection;
        final highlighted = _preview != null && moves.contains(_preview)
            ? marblesIn(_preview!)
            : {for (final m in moves) ...marblesIn(m)};
        return Scaffold(
          appBar: AppBar(title: Text(_status(c))),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      // Pinch to zoom: 108 seats make small marbles on a phone.
                      child: InteractiveViewer(
                        maxScale: 3,
                        child: BoardView(
                          state: state,
                          highlighted: highlighted,
                        ),
                      ),
                    ),
                  ),
                ),
                _LastEvents(lines: c.history),
                if (c.isHumanTurn) ...[
                  _MoveList(
                    moves: moves,
                    onPreview: (m) => setState(() => _preview = m),
                    onPlay: (m) {
                      setState(() => _preview = null);
                      c.play(m);
                    },
                    hint: c.mustDiscard
                        ? 'Nothing can move. Throw a card in.'
                        : c.selectedCard == null
                        ? 'Pick a card.'
                        : null,
                  ),
                ],
                _Hand(
                  cards: c.humanHand,
                  playable: c.playableCards,
                  selected: c.selectedCard,
                  enabled: c.isHumanTurn,
                  onTap: (card) {
                    setState(() => _preview = null);
                    c.selectCard(card);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _status(GameController c) {
    final s = c.state;
    if (s.isOver) {
      return s.winners.contains(GameController.humanStation)
          ? 'You win!'
          : '${s.winners.map(stationName).join(' and ')} won';
    }
    return c.isHumanTurn
        ? 'Your turn'
        : '${stationName(s.current.station)} is thinking…';
  }
}

class _LastEvents extends StatelessWidget {
  const _LastEvents({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final recent = lines.length > 3 ? lines.sublist(lines.length - 3) : lines;
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in recent)
            Text(l, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MoveList extends StatelessWidget {
  const _MoveList({
    required this.moves,
    required this.onPreview,
    required this.onPlay,
    this.hint,
  });

  final List<Move> moves;
  final ValueChanged<Move?> onPreview;
  final ValueChanged<Move> onPlay;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 140),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(hint!),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in moves)
                MouseRegion(
                  onEnter: (_) => onPreview(m),
                  onExit: (_) => onPreview(null),
                  child: FilledButton.tonal(
                    onPressed: () => onPlay(m),
                    onLongPress: () => onPreview(m),
                    child: Text(_capitalise(describeMove(m))),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Hand extends StatelessWidget {
  const _Hand({
    required this.cards,
    required this.playable,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final List<Card> cards;
  final Set<Card> playable;
  final Card? selected;
  final bool enabled;
  final ValueChanged<Card> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final card in cards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: !enabled || playable.contains(card) ? 1 : 0.45,
                child: InkWell(
                  key: ValueKey('card-${card.id}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: enabled && playable.contains(card)
                      ? () => onTap(card)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    height: 74,
                    transform: Matrix4.translationValues(
                      0,
                      card == selected ? -10 : 0,
                      0,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: card == selected
                            ? scheme.primary
                            : scheme.outline,
                        width: card == selected ? 3 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _face(card),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isRed(card) ? Colors.red.shade700 : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _face(Card c) => switch (c.suit) {
    null => '🃏',
    Suit.spades => '${c.rank.label}\n♠',
    Suit.hearts => '${c.rank.label}\n♥',
    Suit.diamonds => '${c.rank.label}\n♦',
    Suit.clubs => '${c.rank.label}\n♣',
  };

  static bool _isRed(Card c) =>
      c.suit == Suit.hearts || c.suit == Suit.diamonds;
}
