/// Topology of the six-station board. Geometry (where seats are drawn) lives
/// in the app; the engine only needs to know how seats connect.
///
/// The track is 108 seats numbered clockwise. Station 0 sits at the bottom,
/// facing the first player, and the stations run clockwise from there:
/// blue, purple, red, yellow, green, black.
///
/// Station `s` brings marbles out at seat `18 * s`. The seat just before it,
/// counter-clockwise, is where that station's Destination row branches off,
/// so a marble travels 107 seats from Come Out to the branch and then turns
/// inward.
abstract final class Board {
  static const stations = 6;
  static const trackLength = 108;
  static const runLength = trackLength ~/ stations;
  static const marblesPerPlayer = 4;
  static const destinationLength = 4;

  /// Track seat a station's marbles come out onto.
  static int comeOut(int station) => station * runLength;

  /// Track seat the station's Destination row branches from.
  static int destinationBranch(int station) => wrap(comeOut(station) - 1);

  static int wrap(int seat) => seat % trackLength;

  /// How far along its lap a marble on [seat] is, 0 at Come Out and 107 at
  /// the Destination branch.
  static int progress(int station, int seat) => wrap(seat - comeOut(station));

  /// The station directly across the board.
  static int opposite(int station) => (station + stations ~/ 2) % stations;
}

/// Where a marble sits.
sealed class Spot {
  const Spot();
}

class InHome extends Spot {
  const InHome();

  @override
  bool operator ==(Object other) => other is InHome;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'home';
}

class OnTrack extends Spot {
  const OnTrack(this.seat);
  final int seat;

  @override
  bool operator ==(Object other) => other is OnTrack && other.seat == seat;

  @override
  int get hashCode => seat.hashCode + 1;

  @override
  String toString() => 'track $seat';
}

/// [slot] 0 is the first Destination seat off the branch, 3 the innermost.
class InDestination extends Spot {
  const InDestination(this.slot);
  final int slot;

  @override
  bool operator ==(Object other) =>
      other is InDestination && other.slot == slot;

  @override
  int get hashCode => slot.hashCode + 1000;

  @override
  String toString() => 'destination $slot';
}

/// A marble is identified by its owner's station and its index 0–3.
class MarbleId {
  const MarbleId(this.station, this.index);
  final int station;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is MarbleId && other.station == station && other.index == index;

  @override
  int get hashCode => station * 8 + index;

  @override
  String toString() => 'M$station.$index';
}
