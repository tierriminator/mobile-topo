import 'coordinate_system.dart';

/// A position on the earth in WGS84 degrees, north and east positive
class GeoPosition {
  final double latitude;
  final double longitude;

  const GeoPosition(this.latitude, this.longitude);

  /// Swiss grid (LV95) coordinates of the main entrance of the Hölloch,
  /// Muotathal, Switzerland: where the automatic declination is computed
  /// for caves with no position of their own
  static const hoellochEast = 2702698;
  static const hoellochNorth = 1203724;

  /// The position of [hoellochEast] and [hoellochNorth]
  static final GeoPosition hoelloch =
      CoordinateSystem.swiss.toGeo(hoellochEast, hoellochNorth)!;

  /// Whether this is a valid position, with latitude and longitude in range
  bool get isValid =>
      latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPosition &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPosition($latitude, $longitude)';
}
