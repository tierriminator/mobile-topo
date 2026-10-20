import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/models/coordinate_system.dart';
import 'package:mobile_topo/models/geo_position.dart';

void main() {
  group('Utm', () {
    const zone31 = Utm(31);

    test('puts the central meridian at the equator at 500 km east', () {
      final (:east, :north) = zone31.fromGeo(const GeoPosition(0, 3));
      expect(east, closeTo(500000, 1e-6));
      expect(north, closeTo(0, 1e-6));
      expect(const Utm(31, south: true).fromGeo(const GeoPosition(0, 3)).north,
          closeTo(10000000, 1e-6));
    });

    test('scales the meridian arc on the central meridian', () {
      // The WGS84 meridian arc from the equator to 45° is 4'984'944.4 m
      expect(zone31.fromGeo(const GeoPosition(45, 3)).north,
          closeTo(0.9996 * 4984944.4, 1));
    });

    test('converts back and forth within a zone', () {
      const zone32 = Utm(32);
      for (final position in [
        GeoPosition.hoelloch,
        const GeoPosition(47.5, 6.2),
        const GeoPosition(60, 11.9),
      ]) {
        final (:east, :north) = zone32.fromGeo(position);
        final back = zone32.toGeo(east, north)!;
        expect(back.latitude, closeTo(position.latitude, 1e-7));
        expect(back.longitude, closeTo(position.longitude, 1e-7));
      }
    });

    test('converts back and forth south of the equator', () {
      const zone33s = Utm(33, south: true);
      const position = GeoPosition(-25.4, 15.8);
      final (:east, :north) = zone33s.fromGeo(position);
      final back = zone33s.toGeo(east, north)!;
      expect(back.latitude, closeTo(position.latitude, 1e-7));
      expect(back.longitude, closeTo(position.longitude, 1e-7));
    });

    test('rejects local coordinates', () {
      expect(zone31.toGeo(0, 0), isNull);
      expect(zone31.toGeo(120, 340), isNull);
    });

    test('finds the zone of a position', () {
      expect(Utm.containing(GeoPosition.hoelloch), const Utm(32));
      expect(Utm.containing(const GeoPosition(-33.9, 18.4)),
          const Utm(34, south: true));
      expect(Utm.containing(const GeoPosition(10, 180)).zone, 60);
    });
  });

  test('SwissGrid converts to LV95', () {
    // Swisstopo's example: the old observatory in Bern
    final (:east, :north) =
        CoordinateSystem.swiss.fromGeo(const GeoPosition(46.95108, 7.43864));
    expect(east, closeTo(2600000, 2));
    expect(north, closeTo(1200000, 2));
  });

  test('Wgs84 takes longitude as East and latitude as North', () {
    expect(CoordinateSystem.wgs84.toGeo(8.79, 46.98),
        const GeoPosition(46.98, 8.79));
    expect(CoordinateSystem.wgs84.toGeo(8.79, 95), isNull);
    expect(CoordinateSystem.wgs84.fromGeo(const GeoPosition(46.98, 8.79)),
        (east: 8.79, north: 46.98));
  });

  test('survives storing by name', () {
    for (final system in [
      CoordinateSystem.swiss,
      CoordinateSystem.wgs84,
      const Utm(32),
      const Utm(7, south: true),
    ]) {
      expect(CoordinateSystem.fromJson(system.toJson()), system);
    }
    expect(CoordinateSystem.fromJson(null), CoordinateSystem.swiss);
    expect(CoordinateSystem.fromJson('utm61n'), CoordinateSystem.swiss);
  });
}
