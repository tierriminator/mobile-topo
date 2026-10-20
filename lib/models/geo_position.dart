/// A position on the earth in WGS84 degrees, north and east positive
class GeoPosition {
  final double latitude;
  final double longitude;

  const GeoPosition(this.latitude, this.longitude);

  /// The main entrance of the Hölloch, Muotathal, Switzerland: where the
  /// automatic declination is computed for caves with no position of their
  /// own
  static const hoelloch = GeoPosition(46.97664, 8.78839);

  /// Whether this is a valid position, with latitude and longitude in range
  bool get isValid =>
      latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;

  /// The position of Swiss grid coordinates, either LV95 (east around
  /// 2'600'000 m) or LV03 (east around 600'000 m), told apart by their size.
  /// Returns null if [east] and [north] lie outside Switzerland in both, as
  /// local coordinates do. Uses swisstopo's approximate formulas, accurate
  /// to about a metre.
  static GeoPosition? fromSwissGrid(num east, num north) {
    final (e, n) = switch ((east, north)) {
      (>= 2480000 && <= 2840000, >= 1070000 && <= 1300000) => (
          east - 2600000,
          north - 1200000
        ),
      (>= 480000 && <= 840000, >= 70000 && <= 300000) => (
          east - 600000,
          north - 200000
        ),
      _ => (null, null),
    };
    if (e == null || n == null) return null;

    final y = e / 1e6;
    final x = n / 1e6;
    final longitude = 2.6779094 +
        4.728982 * y +
        0.791484 * y * x +
        0.1306 * y * x * x -
        0.0436 * y * y * y;
    final latitude = 16.9023892 +
        3.238272 * x -
        0.270978 * y * y -
        0.002528 * x * x -
        0.0447 * y * y * x -
        0.0140 * x * x * x;
    // The formulas give units of 10000"
    return GeoPosition(latitude * 100 / 36, longitude * 100 / 36);
  }

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
