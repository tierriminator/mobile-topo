import 'dart:math' as math;
import 'dart:ui';

import 'survey.dart';

/// The side view of a survey: a projection on the development of the survey
/// shots (an "extended elevation"). Each survey shot runs from left to right
/// in the direction the survey progressed, from the previous station to the
/// new one, unless it is flipped to run from right to left. Shots keep
/// their horizontal length and stations their altitude.
///
/// World coordinates are in metres with the y axis pointing down, like the
/// plan view: x is the position along the development, y the negated
/// altitude.
class SideView {
  final Map<Point, _SideViewStation> _stations;

  const SideView._(this._stations);

  /// Lays out the stations that have a position in [positions], following
  /// the survey shots of [survey] from each reference point in turn
  factory SideView.of(Survey survey, Map<Point, StationPosition> positions) {
    final shotsAt = <Point, List<MeasuredDistance>>{};
    for (final stretch in survey.stretches) {
      final to = stretch.to;
      if (to == null) continue;
      (shotsAt[stretch.from] ??= []).add(stretch);
      (shotsAt[to] ??= []).add(stretch);
    }

    final stations = <Point, _SideViewStation>{};
    for (final ref in survey.referencePoints) {
      final start = positions[ref.id];
      if (start == null || stations.containsKey(ref.id)) continue;

      // The start station faces the way the survey leaves it; until a shot
      // is followed from it, it faces right
      stations[ref.id] =
          _SideViewStation(0, start.altitude, 0, 1, isUnfollowed: true);
      final pending = [ref.id];
      while (pending.isNotEmpty) {
        final station = pending.removeLast();
        final here = stations[station]!;
        for (final shot in shotsAt[station] ?? const <MeasuredDistance>[]) {
          final next = shot.from == station ? shot.to! : shot.from;
          final nextPos = positions[next];
          if (nextPos == null || stations.containsKey(next)) continue;

          // Following the shot in survey direction moves to the right, or
          // to the left if the shot is flipped
          final previous = shot.station == shot.to ? shot.from : shot.to!;
          final facing =
              (station == previous ? 1.0 : -1.0) * (shot.flipped ? -1 : 1);
          // Azimuth in the direction the shot is followed
          final azimuth = shot.from == station
              ? shot.azimut.toDouble()
              : shot.azimut.toDouble() + 180;
          final horizontal = shot.distance.toDouble() *
              math.cos(shot.inclination.toDouble() * math.pi / 180);

          stations[next] = _SideViewStation(
            here.x + facing * horizontal,
            nextPos.altitude,
            azimuth,
            facing,
          );
          if (here.isUnfollowed) {
            stations[station] =
                _SideViewStation(here.x, here.altitude, azimuth, facing);
          }
          pending.add(next);
        }
      }
    }
    return SideView._(stations);
  }

  /// Where each laid out station appears in the side view
  Map<Point, Offset> get stationPositions =>
      _stations.map((id, s) => MapEntry(id, s.offset));

  /// The end of a splay or cross section shot in the side view: its
  /// horizontal part is projected onto the direction the survey runs at its
  /// station. Null if the station is not laid out.
  Offset? splayEnd(MeasuredDistance splay) {
    final station = _stations[splay.from];
    if (station == null) return null;
    final inclination = splay.inclination.toDouble() * math.pi / 180;
    final horizontal = splay.distance.toDouble() * math.cos(inclination);
    final vertical = splay.distance.toDouble() * math.sin(inclination);
    final angle = (splay.azimut.toDouble() - station.azimuth) * math.pi / 180;
    return station.offset +
        Offset(station.facing * horizontal * math.cos(angle), -vertical);
  }
}

class _SideViewStation {
  final double x, altitude;

  /// Azimuth in degrees of the direction the survey runs at this station,
  /// which points right when [facing] is 1 and left when it is -1
  final double azimuth;
  final double facing;

  /// Whether no shot has been followed from or to this station yet, so
  /// [azimuth] and [facing] are placeholders
  final bool isUnfollowed;

  const _SideViewStation(this.x, this.altitude, this.azimuth, this.facing,
      {this.isUnfollowed = false});

  Offset get offset => Offset(x, -altitude);
}
