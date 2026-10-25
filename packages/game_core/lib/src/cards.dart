import 'dart:math';

enum Suit { spades, hearts, diamonds, clubs }

enum Rank {
  ace(1, 'A'),
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  joker(1, 'Jk');

  const Rank(this.steps, this.label);

  /// Spaces this card moves a marble already in play.
  final int steps;
  final String label;

  /// Ace, King and Joker bring a marble out of Home.
  bool get isComeOut => this == ace || this == king || this == joker;

  /// The Four moves backwards.
  bool get isBackward => this == four;

  /// Sevens and Jacks may be split between two marbles.
  bool get isSplittable => this == seven || this == jack;
}

/// One physical card. [id] is unique within a shoe, so two Queens of hearts
/// from different decks stay distinguishable.
class Card {
  const Card(this.id, this.rank, [this.suit]);

  final int id;
  final Rank rank;

  /// Null for Jokers.
  final Suit? suit;

  @override
  bool operator ==(Object other) => other is Card && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      suit == null ? rank.label : '${rank.label}${suit!.name[0]}';
}

/// What gets shuffled for a given table size, straight from the rules:
/// 2 or 4 players one deck, 3 players one deck and two Jokers,
/// 5 players a deck and a half and two Jokers, 6 players a deck and a half.
List<Card> buildShoe(int players) {
  final cards = <Card>[];
  var id = 0;
  void addSuit(Suit s) {
    for (final r in Rank.values) {
      if (r != Rank.joker) cards.add(Card(id++, r, s));
    }
  }

  Suit.values.forEach(addSuit);
  if (players >= 5) {
    // The half deck: two more suits.
    addSuit(Suit.spades);
    addSuit(Suit.hearts);
  }
  if (players == 3 || players == 5) {
    cards.add(Card(id++, Rank.joker));
    cards.add(Card(id++, Rank.joker));
  }
  return cards;
}

/// Cards per player for each deal in one pass through the shoe. Each table
/// exhausts the shoe exactly, after which it is reshuffled and the schedule
/// starts again.
List<int> dealSchedule(int players) => switch (players) {
  2 => [5, 5, 4, 4, 4, 4],
  3 => [5, 5, 4, 4],
  4 => [5, 4, 4],
  5 => [4, 4, 4, 4],
  6 => [5, 4, 4],
  _ => throw ArgumentError('Aggies and Jokers seats 2 to 6 players'),
};

List<Card> shuffled(List<Card> cards, Random rng) => [...cards]..shuffle(rng);
