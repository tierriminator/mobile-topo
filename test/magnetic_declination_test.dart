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
}
