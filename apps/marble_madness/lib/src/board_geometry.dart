import 'dart:math';
import 'dart:ui';

import 'package:game_core/game_core.dart';

/// Where every seat sits on the hexagon, in a square of side [size].
///
/// Each station owns one flat side. Station 0 is the bottom side and the
/// stations run clockwise from there, matching the engine's seat numbers.
/// A side holds 18 track seats, with the Come Out seat at the middle and the
/// Destination row turning inward from the seat before it. Home sits inside
/// the board beside the Destination row.
class BoardGeometry {
  BoardGeometry(this.size)
    : center = Offset(size / 2, size / 2),
      radius = size * 0.49;

  final double size;
  final Offset center;

  /// Centre to corner.
  final double radius;

  /// Distance between neighbouring track seats.
  double get step => radius / Board.runLength;

  double get marbleRadius => step * 0.43;

  Offset _corner(int k) {
    // Screen y points down, so increasing angles run clockwise. The bottom
    // side's corners are at 60 and 120 degrees.
    final a = (60 + 60 * k) * pi / 180;
    return center + Offset(cos(a), sin(a)) * radius;
  }

  /// The side's 18 seats run from 9 before Come Out to 8 after it.
  Offset seat(int seat) {
    final shifted = Board.wrap(seat + Board.runLength ~/ 2);
    final side = shifted ~/ Board.runLength;
    final i = shifted % Board.runLength;
    final t = (i + 0.5) / Board.runLength;
    return Offset.lerp(_corner(side), _corner(side + 1), t)!;
  }

  Offset _inward(int station) {
    final mid = (_corner(station) + _corner(station + 1)) / 2;
    final d = center - mid;
    return d / d.distance;
  }

  Offset destination(int station, int slot) =>
      seat(Board.destinationBranch(station)) +
      _inward(station) * step * (slot + 1.2);

  /// Home spots form a 2x2 block inside the board, past the Come Out seat.
  Offset home(int station, int index) {
    final base = seat(Board.comeOut(station) + 3);
    final along =
        (seat(Board.comeOut(station) + 1) - seat(Board.comeOut(station))) /
        step;
    return base +
        _inward(station) * step * (1.6 + (index ~/ 2) * 1.1) +
        along * step * (index % 2) * 1.1;
  }

  Offset spot(MarbleId m, Spot s) => switch (s) {
    InHome() => home(m.station, m.index),
    OnTrack(:final seat) => this.seat(seat),
    InDestination(:final slot) => destination(m.station, slot),
  };

  List<Offset> get corners => [for (var k = 0; k < 6; k++) _corner(k)];
}
