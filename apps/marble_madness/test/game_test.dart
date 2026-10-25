import 'dart:math';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:marble_madness/main.dart';
import 'package:marble_madness/src/board_geometry.dart';
import 'package:marble_madness/src/game_controller.dart';

void main() {
  group('GameController', () {
    for (var opponents = 1; opponents <= 4; opponents++) {
      test('a full game with $opponents bots ends with a winner', () {
        final c = GameController(opponents: opponents, rng: Random(opponents));
        final standIn = Bot(rng: Random(99));
        var turns = 0;
        while (!c.state.isOver) {
          c.playBotsNow();
          if (c.state.isOver) break;
          expect(c.isHumanTurn, isTrue);
          c.play(standIn.choose(c.state));
          expect(++turns, lessThan(5000));
        }
        expect(c.state.winners, isNotEmpty);
        expect(c.history.last, endsWith('won!'));
        c.dispose();
      });
    }

    test('selecting a card offers only that card\'s moves', () {
      final c = GameController(opponents: 1, rng: Random(3));
      c.playBotsNow();
      final card = c.playableCards.first;
      c.selectCard(card);
      expect(c.selectedCard, card);
      expect(c.movesForSelection, isNotEmpty);
      c.dispose();
    });
  });

  group('BoardGeometry', () {
    test('every seat and hole on the board is distinct and inside it', () {
      final g = BoardGeometry(600);
      final points = <Offset>[
        for (var s = 0; s < Board.trackLength; s++) g.seat(s),
        for (var st = 0; st < Board.stations; st++) ...[
          for (var i = 0; i < 4; i++) g.home(st, i),
          for (var i = 0; i < 4; i++) g.destination(st, i),
        ],
      ];
      for (var i = 0; i < points.length; i++) {
        expect((points[i] - g.center).distance, lessThan(g.radius));
        for (var j = i + 1; j < points.length; j++) {
          expect(
            (points[i] - points[j]).distance,
            greaterThan(g.marbleRadius * 2),
            reason: 'points $i and $j overlap',
          );
        }
      }
    });

    test('station 0 comes out on the bottom side', () {
      final g = BoardGeometry(600);
      expect(g.seat(Board.comeOut(0)).dy, greaterThan(g.center.dy));
    });
  });

  testWidgets('starting a game shows the board and a hand', (tester) async {
    await tester.pumpWidget(const MarbleMadnessApp());
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(CustomPaint), findsWidgets);
    // Let the bots finish their turns, then leave so timers stop.
    await tester.pump(const Duration(seconds: 5));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Start game'), findsOneWidget);
  });
}
