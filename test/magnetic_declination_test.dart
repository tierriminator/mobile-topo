import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/models/geo_position.dart';
import 'package:mobile_topo/models/magnetic_declination.dart';

void main() {
  group('MagneticDeclination', () {
    // Expected values from the BGS IGRF-14 calculator,
    // https://geomag.bgs.ac.uk/web_service/GMModels/igrf/14/
    test('matches the IGRF-14 at the Hölloch in 2026', () {
      expect(MagneticDeclination.at(GeoPosition.hoelloch, DateTime(2026, 10, 20)),
          closeTo(3.681, 0.01));
    });

    test('interpolates between epochs', () {
      expect(MagneticDeclination.at(GeoPosition.hoelloch, DateTime(2008, 3, 10)),
          closeTo(1.174, 0.01));
    });

    test('gives westerly declination as negative', () {
      expect(
          MagneticDeclination.at(
              const GeoPosition(-33.9, 18.4), DateTime(1985, 6, 15)),
          closeTo(-22.965, 0.01));
    });

    test('works far from Europe', () {
      expect(
          MagneticDeclination.at(
              const GeoPosition(60, -100), DateTime(2010, 1, 1)),
          closeTo(5.208, 0.01));
    });
  });

  group('GeoPosition.fromSwissGrid', () {
    // Swisstopo's example: the old observatory in Bern
    test('reads LV95 coordinates', () {
      final position = GeoPosition.fromSwissGrid(2600000, 1200000)!;
      expect(position.latitude, closeTo(46.95108, 1e-4));
      expect(position.longitude, closeTo(7.43864, 1e-4));
    });

    test('reads LV03 coordinates', () {
      final position = GeoPosition.fromSwissGrid(600000, 200000)!;
      expect(position.latitude, closeTo(46.95108, 1e-4));
      expect(position.longitude, closeTo(7.43864, 1e-4));
    });

    test('places the Hölloch at its entrance', () {
      expect(GeoPosition.hoelloch.latitude, closeTo(46.97664, 1e-4));
      expect(GeoPosition.hoelloch.longitude, closeTo(8.78839, 1e-4));
    });

    test('rejects coordinates outside Switzerland', () {
      expect(GeoPosition.fromSwissGrid(0, 0), isNull);
      expect(GeoPosition.fromSwissGrid(500000, 5200000), isNull);
    });
  });
}
