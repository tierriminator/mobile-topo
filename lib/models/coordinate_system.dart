import 'dart:math' as math;

import 'geo_position.dart';

/// The coordinate system the East and North of a cave's reference points
/// are given in. Coordinates are stored as entered and converted only for
/// calculations that need positions on the earth or in metres.
sealed class CoordinateSystem {
  const CoordinateSystem();

  /// Swiss grid, LV95 or LV03
  static const swiss = SwissGrid();

  /// WGS84 longitude as East and latitude as North, in degrees
  static const wgs84 = Wgs84();

  /// The position of [east] and [north], or null if they do not fit this
  /// system, as local coordinates usually do not
  GeoPosition? toGeo(num east, num north);

  /// East and North of [position] in this system
  ({double east, double north}) fromGeo(GeoPosition position);

  /// Whether East and North are in metres, which positions are computed
  /// in; otherwise they are degrees
  bool get isMetric => true;

  /// The azimuth of true north at [position], measured from grid north in
  /// degrees: the meridian convergence. Adding it turns a bearing against
  /// true north into one against grid north. Found by projecting a short
  /// step north, as the projections are conformal.
  double trueNorthAzimuth(GeoPosition position) {
    const step = 1e-4;
    final from = fromGeo(position);
    final to =
        fromGeo(GeoPosition(position.latitude + step, position.longitude));
    return math.atan2(to.east - from.east, to.north - from.north) *
        180 /
        math.pi;
  }

  /// The name the system is stored by
  String toJson();

  /// The system stored as [json]; the Swiss grid if it is unknown
  static CoordinateSystem fromJson(String? json) {
    if (json == 'wgs84') return wgs84;
    final utm = RegExp(r'^utm(\d{1,2})([ns])$').firstMatch(json ?? '');
    if (utm != null) {
      final zone = int.parse(utm.group(1)!);
      if (zone >= 1 && zone <= 60) {
        return Utm(zone, south: utm.group(2) == 's');
      }
    }
    return swiss;
  }
}

/// The Swiss grid: LV95 (East around 2'600'000 m) or LV03 (East around
/// 600'000 m), told apart by their size
class SwissGrid extends CoordinateSystem {
  const SwissGrid();

  @override
  GeoPosition? toGeo(num east, num north) =>
      GeoPosition.fromSwissGrid(east, north);

  /// LV95 coordinates, by swisstopo's approximate formulas
  @override
  ({double east, double north}) fromGeo(GeoPosition position) {
    // Latitude and longitude in units of 10000"
    final phi = (position.latitude * 3600 - 169028.66) / 10000;
    final lambda = (position.longitude * 3600 - 26782.5) / 10000;
    final east = 2600072.37 +
        211455.93 * lambda -
        10938.51 * lambda * phi -
        0.36 * lambda * phi * phi -
        44.54 * lambda * lambda * lambda;
    final north = 1200147.07 +
        308807.95 * phi +
        3745.25 * lambda * lambda +
        76.63 * phi * phi -
        194.56 * lambda * lambda * phi +
        119.79 * phi * phi * phi;
    return (east: east, north: north);
  }

  @override
  String toJson() => 'swiss';

  @override
  bool operator ==(Object other) => other is SwissGrid;

  @override
  int get hashCode => (SwissGrid).hashCode;
}

/// Universal Transverse Mercator on WGS84 in [zone], north of the equator
/// unless [south]
class Utm extends CoordinateSystem {
  /// From 1 to 60
  final int zone;
  final bool south;

  const Utm(this.zone, {this.south = false});

  /// The zone [position] lies in
  factory Utm.containing(GeoPosition position) => Utm(
        ((position.longitude + 180) / 6).floor().clamp(0, 59) + 1,
        south: position.latitude < 0,
      );

  static const double _a = 6378137;
  static const double _f = 1 / 298.257223563;
  static const double _k0 = 0.9996;
  static const double _falseEasting = 500000;
  static const double _southFalseNorthing = 10000000;

  static const double _e2 = _f * (2 - _f);
  static const double _ep2 = _e2 / (1 - _e2);

  /// Longitude of the zone's central meridian in radians
  double get _centralMeridian => ((zone - 1) * 6 - 180 + 3) * math.pi / 180;

  /// Distance along the meridian from the equator to [phi]
  static double _meridianArc(double phi) {
    const e4 = _e2 * _e2;
    const e6 = e4 * _e2;
    return _a *
        ((1 - _e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi -
            (3 * _e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * phi) +
            (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * phi) -
            (35 * e6 / 3072) * math.sin(6 * phi));
  }

  /// Snyder's series for the transverse Mercator projection, accurate to
  /// well below a metre within a zone
  @override
  ({double east, double north}) fromGeo(GeoPosition position) {
    final phi = position.latitude * math.pi / 180;
    final lambda = position.longitude * math.pi / 180;
    final sinPhi = math.sin(phi);
    final cosPhi = math.cos(phi);
    final n = _a / math.sqrt(1 - _e2 * sinPhi * sinPhi);
    final t = math.tan(phi) * math.tan(phi);
    final c = _ep2 * cosPhi * cosPhi;
    final a = cosPhi * (lambda - _centralMeridian);
    final a2 = a * a;

    final east = _falseEasting +
        _k0 *
            n *
            (a +
                (1 - t + c) * a2 * a / 6 +
                (5 - 18 * t + t * t + 72 * c - 58 * _ep2) * a2 * a2 * a / 120);
    var north = _k0 *
        (_meridianArc(phi) +
            n *
                math.tan(phi) *
                (a2 / 2 +
                    (5 - t + 9 * c + 4 * c * c) * a2 * a2 / 24 +
                    (61 - 58 * t + t * t + 600 * c - 330 * _ep2) *
                        a2 *
                        a2 *
                        a2 /
                        720));
    if (south) north += _southFalseNorthing;
    return (east: east, north: north);
  }

  /// The inverse of [fromGeo]. Coordinates far outside a zone, like local
  /// ones near zero, do not fit.
  @override
  GeoPosition? toGeo(num east, num north) {
    if (east < 100000 || east > 900000 || north < 0 || north > 10000000) {
      return null;
    }
    final x = east - _falseEasting;
    final y = south ? north - _southFalseNorthing : north.toDouble();

    const e4 = _e2 * _e2;
    const e6 = e4 * _e2;
    final mu = y / _k0 / (_a * (1 - _e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256));
    final e1 = (1 - math.sqrt(1 - _e2)) / (1 + math.sqrt(1 - _e2));
    final phi1 = mu +
        (3 * e1 / 2 - 27 * math.pow(e1, 3) / 32) * math.sin(2 * mu) +
        (21 * e1 * e1 / 16 - 55 * math.pow(e1, 4) / 32) * math.sin(4 * mu) +
        (151 * math.pow(e1, 3) / 96) * math.sin(6 * mu) +
        (1097 * math.pow(e1, 4) / 512) * math.sin(8 * mu);

    final sinPhi1 = math.sin(phi1);
    final cosPhi1 = math.cos(phi1);
    final tanPhi1 = math.tan(phi1);
    final c1 = _ep2 * cosPhi1 * cosPhi1;
    final t1 = tanPhi1 * tanPhi1;
    final n1 = _a / math.sqrt(1 - _e2 * sinPhi1 * sinPhi1);
    final r1 = _a * (1 - _e2) / math.pow(1 - _e2 * sinPhi1 * sinPhi1, 1.5);
    final d = x / (n1 * _k0);
    final d2 = d * d;

    final phi = phi1 -
        (n1 * tanPhi1 / r1) *
            (d2 / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * _ep2) * d2 * d2 / 24 +
                (61 +
                        90 * t1 +
                        298 * c1 +
                        45 * t1 * t1 -
                        252 * _ep2 -
                        3 * c1 * c1) *
                    d2 *
                    d2 *
                    d2 /
                    720);
    final lambda = _centralMeridian +
        (d -
                (1 + 2 * t1 + c1) * d2 * d / 6 +
                (5 -
                        2 * c1 +
                        28 * t1 -
                        3 * c1 * c1 +
                        8 * _ep2 +
                        24 * t1 * t1) *
                    d2 *
                    d2 *
                    d /
                    120) /
            cosPhi1;
    final position = GeoPosition(phi * 180 / math.pi, lambda * 180 / math.pi);
    return position.isValid ? position : null;
  }

  @override
  String toJson() => 'utm$zone${south ? 's' : 'n'}';

  @override
  bool operator ==(Object other) =>
      other is Utm && other.zone == zone && other.south == south;

  @override
  int get hashCode => Object.hash(zone, south);
}

/// WGS84 longitude as East and latitude as North, in degrees
class Wgs84 extends CoordinateSystem {
  const Wgs84();

  @override
  GeoPosition? toGeo(num east, num north) {
    final position = GeoPosition(north.toDouble(), east.toDouble());
    return position.isValid ? position : null;
  }

  @override
  ({double east, double north}) fromGeo(GeoPosition position) =>
      (east: position.longitude, north: position.latitude);

  @override
  bool get isMetric => false;

  @override
  String toJson() => 'wgs84';

  @override
  bool operator ==(Object other) => other is Wgs84;

  @override
  int get hashCode => (Wgs84).hashCode;
}
