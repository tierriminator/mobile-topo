import 'dart:math' as math;
import 'dart:ui';

import 'survey.dart';

enum CrossSectionKind {
  /// Seen along the passage: how wide and high it is
  vertical,

  /// Seen from above like the outline, north up: the outline of the passage
  /// around the station
  horizontal,
}

/// A cross section drawing placed in a sketch: a copy of [station] at
/// [position] with the station's cross section measurements around it, as
/// PocketTopo's "XSection" commands make them. The measurements are taken
/// from the survey data whenever it is drawn.
class CrossSection {
  final Point station;

  /// Where the copy of the station is drawn, in the sketch's world
  /// coordinates
  final Offset position;
  final CrossSectionKind kind;

  const CrossSection({
    required this.station,
    required this.position,
    required this.kind,
  });

  /// Where the ends of [splays] appear in this cross section. A vertical
  /// cross section looks along the passage, which runs towards [azimuth] in
  /// degrees at the station; a horizontal one ignores it.
  List<Offset> splayEnds(
    Iterable<MeasuredDistance> splays, {
    required double azimuth,
  }) {
    return [
      for (final splay in splays) position + _project(splay, azimuth),
    ];
  }

  Offset _project(MeasuredDistance splay, double azimuth) {
    final inclination = splay.inclination.toDouble() * math.pi / 180;
    final horizontal = splay.distance.toDouble() * math.cos(inclination);
    switch (kind) {
      case CrossSectionKind.vertical:
        // Looking along the passage: its right side is right, up is up
        final angle = (splay.azimut.toDouble() - azimuth) * math.pi / 180;
        final vertical = splay.distance.toDouble() * math.sin(inclination);
        return Offset(horizontal * math.sin(angle), -vertical);
      case CrossSectionKind.horizontal:
        // From above with east to the right and north up, like the outline
        final splayAzimuth = splay.azimut.toDouble() * math.pi / 180;
        return Offset(horizontal * math.sin(splayAzimuth),
            -horizontal * math.cos(splayAzimuth));
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CrossSection &&
      other.station == station &&
      other.position == position &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(station, position, kind);
}
