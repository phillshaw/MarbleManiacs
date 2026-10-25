import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import 'board_geometry.dart';

/// Marble colours by station, in the engine's station order.
const stationColors = [
  Color(0xFF1E6FD9), // blue
  Color(0xFF8E44AD), // purple
  Color(0xFFD63031), // red
  Color(0xFFF1C40F), // yellow
  Color(0xFF27AE60), // green
  Color(0xFF2D3436), // black
];

/// The hexagon board with every marble on it. Marbles in [highlighted] get a
/// ring so the player can see what a move will touch.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.state,
    this.highlighted = const {},
  });

  final GameState state;
  final Set<MarbleId> highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _BoardPainter(
          state: state,
          highlighted: highlighted,
          surface: scheme.surfaceContainerHighest,
          line: scheme.outline,
          ring: scheme.primary,
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.state,
    required this.highlighted,
    required this.surface,
    required this.line,
    required this.ring,
  });

  final GameState state;
  final Set<MarbleId> highlighted;
  final Color surface;
  final Color line;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final g = BoardGeometry(size.shortestSide);
    final hole = g.marbleRadius * 0.55;

    final corners = g.corners;
    final hex = Path()..addPolygon(corners, true);
    canvas.drawPath(hex, Paint()..color = surface);
    canvas.drawPath(
      hex,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final holePaint = Paint()..color = line.withValues(alpha: 0.45);
    for (var s = 0; s < Board.trackLength; s++) {
      canvas.drawCircle(g.seat(s), hole, holePaint);
    }

    for (final station in state.config.stations) {
      final tint = Paint()
        ..color = stationColors[station].withValues(alpha: 0.35);
      for (var slot = 0; slot < Board.destinationLength; slot++) {
        canvas.drawCircle(g.destination(station, slot), hole * 1.2, tint);
      }
      for (var i = 0; i < Board.marblesPerPlayer; i++) {
        canvas.drawCircle(g.home(station, i), hole * 1.2, tint);
      }
      // Mark the Come Out seat.
      canvas.drawCircle(
        g.seat(Board.comeOut(station)),
        g.marbleRadius * 1.15,
        Paint()
          ..color = stationColors[station]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    for (final MapEntry(key: m, value: s) in state.spots.entries) {
      final c = g.spot(m, s);
      canvas.drawCircle(
        c,
        g.marbleRadius,
        Paint()..color = stationColors[m.station],
      );
      canvas.drawCircle(
        c,
        g.marbleRadius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (m.station == 0) _label(canvas, c, '${m.index + 1}', g.marbleRadius);
      if (highlighted.contains(m)) {
        canvas.drawCircle(
          c,
          g.marbleRadius * 1.45,
          Paint()
            ..color = ring
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  void _label(Canvas canvas, Offset c, String text, double r) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: r * 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.state != state ||
      old.highlighted != highlighted ||
      old.surface != surface;
}
