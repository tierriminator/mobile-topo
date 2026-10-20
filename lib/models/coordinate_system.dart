import 'dart:math' as math;

import 'package:proj4dart/proj4dart.dart' as proj4;

import 'geo_position.dart';

/// The coordinate system the East and North of a cave's reference points
/// are given in. Coordinates are stored as entered and converted only for
/// calculations that need positions on the earth or in metres.
///
/// The projections are computed by proj4dart from their EPSG definitions,
/// the same PROJ uses, so positions agree with those Therion computes.
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

/// Projections parsed from their definitions, each once
final _projections = <String, proj4.Projection>{};

proj4.Projection _projection(String definition) =>
    _projections[definition] ??= proj4.Projection.parse(definition);

/// [east] and [north] of [definition]'s projection on WGS84, or null if the
/// result is no valid position
GeoPosition? _inverse(String definition, num east, num north) {
  final point = _projection(definition).transform(proj4.Projection.WGS84,
      proj4.Point(x: east.toDouble(), y: north.toDouble()));
  final position = GeoPosition(point.y, point.x);
  return position.latitude.isFinite &&
          position.longitude.isFinite &&
          position.isValid
      ? position
      : null;
}

/// [position] projected by [definition]
({double east, double north}) _forward(
    String definition, GeoPosition position) {
  final point = proj4.Projection.WGS84.transform(_projection(definition),
      proj4.Point(x: position.longitude, y: position.latitude));
  return (east: point.x, north: point.y);
}

/// The Swiss grid: LV95 (EPSG:2056, East around 2'600'000 m) or LV03
/// (EPSG:21781, East around 600'000 m), told apart by their size
class SwissGrid extends CoordinateSystem {
  const SwissGrid();

  /// The EPSG definitions, as PROJ has them
  static const _lv95 = '+proj=somerc +lat_0=46.9524055555556 '
      '+lon_0=7.43958333333333 +k_0=1 +x_0=2600000 +y_0=1200000 '
      '+ellps=bessel +towgs84=674.374,15.056,405.346,0,0,0,0 +units=m '
      '+no_defs';
  static const _lv03 = '+proj=somerc +lat_0=46.9524055555556 '
      '+lon_0=7.43958333333333 +k_0=1 +x_0=600000 +y_0=200000 '
      '+ellps=bessel +towgs84=674.374,15.056,405.346,0,0,0,0 +units=m '
      '+no_defs';

  /// Coordinates outside Switzerland in both LV95 and LV03, as local ones
  /// are, do not fit
  @override
  GeoPosition? toGeo(num east, num north) => switch ((east, north)) {
        (>= 2480000 && <= 2840000, >= 1070000 && <= 1300000) =>
          _inverse(_lv95, east, north),
        (>= 480000 && <= 840000, >= 70000 && <= 300000) =>
          _inverse(_lv03, east, north),
        _ => null,
      };

  /// LV95 coordinates
  @override
  ({double east, double north}) fromGeo(GeoPosition position) =>
      _forward(_lv95, position);

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

  /// The definition of EPSG:326xx or EPSG:327xx
  String get _definition =>
      '+proj=utm +zone=$zone${south ? ' +south' : ''} +datum=WGS84 '
      '+units=m +no_defs';

  @override
  ({double east, double north}) fromGeo(GeoPosition position) =>
      _forward(_definition, position);

  /// Coordinates far outside a zone, like local ones near zero, do not fit
  @override
  GeoPosition? toGeo(num east, num north) {
    if (east < 100000 || east > 900000 || north < 0 || north > 10000000) {
      return null;
    }
    return _inverse(_definition, east, north);
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
