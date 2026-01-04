import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/services/smart_mode_detector.dart';

void main() {
  group('SmartModeDetector', () {
    late SmartModeDetector detector;

    setUp(() {
      detector = SmartModeDetector();
    });

    RawMeasurement createMeasurement({
      double distance = 10.0,
      double azimuth = 45.0,
      double inclination = 5.0,
    }) {
      return RawMeasurement(
        distance: distance,
        azimuth: azimuth,
        inclination: inclination,
        timestamp: DateTime.now(),
      );
    }

    group('triple detection', () {
      test('detects three identical shots as survey shot', () {
        // Three identical measurements
        final m1 = createMeasurement();
        final m2 = createMeasurement();
        final m3 = createMeasurement();

        // Each measurement is immediately emitted as a splay
        final result1 = detector.addMeasurement(m1);
        expect(result1.type, ShotType.splay);

        final result2 = detector.addMeasurement(m2);
        expect(result2.type, ShotType.splay);

        // Third measurement triggers triple detection, returns survey shot
        final result3 = detector.addMeasurement(m3);
        expect(result3.type, ShotType.surveyShot);
        expect(result3.rawMeasurements.length, 3);
      });

      test('detects shots within distance threshold (< 5cm)', () {
        final m1 = createMeasurement(distance: 10.00);
        final m2 = createMeasurement(distance: 10.02); // 2cm diff
        final m3 = createMeasurement(distance: 10.04); // 4cm diff from m1

        detector.addMeasurement(m1);
        detector.addMeasurement(m2);
        final result = detector.addMeasurement(m3);

        expect(result, isNotNull);
        expect(result!.type, ShotType.surveyShot);
      });

      test('rejects shots exceeding distance threshold (>= 5cm)', () {
        final m1 = createMeasurement(distance: 10.00);
        final m2 = createMeasurement(distance: 10.03);
        final m3 = createMeasurement(distance: 10.06); // 6cm diff from m1

        // All measurements are immediately emitted as splays
        final result1 = detector.addMeasurement(m1);
        expect(result1.type, ShotType.splay);

        final result2 = detector.addMeasurement(m2);
        expect(result2.type, ShotType.splay);

        // Third doesn't form a triple (distance > 5cm from m1), so still a splay
        final result3 = detector.addMeasurement(m3);
        expect(result3.type, ShotType.splay);
      });

      test('detects shots within angular threshold (< 1.7 degrees)', () {
        final m1 = createMeasurement(azimuth: 45.0, inclination: 5.0);
        final m2 = createMeasurement(azimuth: 45.5, inclination: 5.0); // 0.5° diff
        final m3 = createMeasurement(azimuth: 46.0, inclination: 5.0); // 1° diff from m1

        detector.addMeasurement(m1);
        detector.addMeasurement(m2);
        final result = detector.addMeasurement(m3);

        expect(result, isNotNull);
        expect(result!.type, ShotType.surveyShot);
      });

      test('rejects shots exceeding angular threshold (>= 1.7 degrees)', () {
        final m1 = createMeasurement(azimuth: 45.0);
        final m2 = createMeasurement(azimuth: 45.5);
        final m3 = createMeasurement(azimuth: 47.0); // 2° diff from m1

        // All measurements are immediately emitted as splays
        final result1 = detector.addMeasurement(m1);
        expect(result1.type, ShotType.splay);

        final result2 = detector.addMeasurement(m2);
        expect(result2.type, ShotType.splay);

        // Third doesn't form a triple (angular diff > 1.7°), so still a splay
        final result3 = detector.addMeasurement(m3);
        expect(result3.type, ShotType.splay);
      });

      test('inclination differences also count for angular threshold', () {
        final m1 = createMeasurement(inclination: 0.0);
        final m2 = createMeasurement(inclination: 0.5);
        final m3 = createMeasurement(inclination: 2.0); // 2° diff from m1

        detector.addMeasurement(m1);
        detector.addMeasurement(m2);
        final result = detector.addMeasurement(m3);

        // Third doesn't form a triple (inclination diff > 1.7°), so still a splay
        expect(result.type, ShotType.splay);
      });
    });

    group('averaging', () {
      test('averages distance for survey shots', () {
        final m1 = createMeasurement(distance: 10.0);
        final m2 = createMeasurement(distance: 10.02);
        final m3 = createMeasurement(distance: 10.04);

        detector.addMeasurement(m1);
        detector.addMeasurement(m2);
        final result = detector.addMeasurement(m3);

        expect(result!.distance, closeTo(10.02, 0.001));
      });

      test('averages direction for survey shots', () {
        // Use azimuths within the 1.7° threshold for all pairwise comparisons
        // Max pairwise diff must be < 1.7°, so use 0.8° differences
        final m1 = createMeasurement(azimuth: 44.2, inclination: 0.0);
        final m2 = createMeasurement(azimuth: 45.0, inclination: 0.0);
        final m3 = createMeasurement(azimuth: 45.8, inclination: 0.0);

        detector.addMeasurement(m1);
        detector.addMeasurement(m2);
        final result = detector.addMeasurement(m3);

        expect(result!.type, ShotType.surveyShot);
        expect(result.azimuth, closeTo(45.0, 0.1));
      });

      test('handles azimuth wraparound correctly', () {
        // Test angles around 0/360 - all within 1.7° of each other
        final m1 = createMeasurement(azimuth: 359.5, inclination: 0.0);
        final m2 = createMeasurement(azimuth: 0.0, inclination: 0.0);
        final m3 = createMeasurement(azimuth: 0.5, inclination: 0.0);

        detector.addMeasurement(m1);
        detector.addMeasurement(m2);
        final result = detector.addMeasurement(m3);

        expect(result!.type, ShotType.surveyShot);
        // Average should be around 0
        expect(result.azimuth, anyOf(closeTo(0.0, 1.0), closeTo(360.0, 1.0)));
      });
    });

    group('splay detection', () {
      test('emits splay immediately for each measurement', () {
        final m1 = createMeasurement(distance: 10.0);
        final m2 = createMeasurement(distance: 15.0); // Very different
        final m3 = createMeasurement(distance: 10.0);

        // All measurements are immediately emitted as splays
        final result1 = detector.addMeasurement(m1);
        expect(result1.type, ShotType.splay);
        expect(result1.distance, 10.0);

        final result2 = detector.addMeasurement(m2);
        expect(result2.type, ShotType.splay);
        expect(result2.distance, 15.0);

        // Third doesn't form a triple with diverse measurements
        final result3 = detector.addMeasurement(m3);
        expect(result3.type, ShotType.splay);
        expect(result3.distance, 10.0);
      });
    });

    group('flush', () {
      test('flush returns empty list (measurements already emitted)', () {
        final m1 = createMeasurement();
        final m2 = createMeasurement();

        // Measurements are emitted immediately
        detector.addMeasurement(m1);
        detector.addMeasurement(m2);

        // Flush now returns empty since measurements are already emitted
        final flushed = detector.flush();
        expect(flushed.length, 0);
        // But pending count tracks measurements for triple detection
        expect(detector.pendingCount, 2);
      });
    });

    group('clear', () {
      test('clears pending measurements', () {
        detector.addMeasurement(createMeasurement());
        detector.addMeasurement(createMeasurement());
        expect(detector.pendingCount, 2);

        detector.clear();
        expect(detector.pendingCount, 0);
      });
    });

    group('callback', () {
      test('calls onShotDetected for each measurement and onTripleDetected for survey shot', () {
        final detectedShots = <DetectedShot>[];
        final tripleShots = <DetectedShot>[];
        detector.onShotDetected = detectedShots.add;
        detector.onTripleDetected = tripleShots.add;

        final m1 = createMeasurement();
        final m2 = createMeasurement();
        final m3 = createMeasurement();

        detector.addMeasurement(m1);
        detector.addMeasurement(m2);
        detector.addMeasurement(m3);

        // Each measurement triggers onShotDetected (as splay)
        expect(detectedShots.length, 3);
        expect(detectedShots[0].type, ShotType.splay);
        expect(detectedShots[1].type, ShotType.splay);
        expect(detectedShots[2].type, ShotType.splay);

        // Triple detection triggers onTripleDetected (survey shot)
        expect(tripleShots.length, 1);
        expect(tripleShots[0].type, ShotType.surveyShot);
      });
    });
  });

  group('RawMeasurement', () {
    test('directionVector computes correct components for horizontal shot', () {
      // Horizontal shot pointing north (azimuth 0, inclination 0)
      final m = RawMeasurement(
        distance: 10.0,
        azimuth: 0.0,
        inclination: 0.0,
        timestamp: DateTime.now(),
      );

      final (east, north, up) = m.directionVector;
      expect(east, closeTo(0.0, 0.001));
      expect(north, closeTo(1.0, 0.001));
      expect(up, closeTo(0.0, 0.001));
    });

    test('directionVector computes correct components for east shot', () {
      // Horizontal shot pointing east (azimuth 90, inclination 0)
      final m = RawMeasurement(
        distance: 10.0,
        azimuth: 90.0,
        inclination: 0.0,
        timestamp: DateTime.now(),
      );

      final (east, north, up) = m.directionVector;
      expect(east, closeTo(1.0, 0.001));
      expect(north, closeTo(0.0, 0.001));
      expect(up, closeTo(0.0, 0.001));
    });

    test('directionVector computes correct components for vertical up shot', () {
      // Vertical shot pointing up (inclination 90)
      final m = RawMeasurement(
        distance: 10.0,
        azimuth: 0.0,
        inclination: 90.0,
        timestamp: DateTime.now(),
      );

      final (east, north, up) = m.directionVector;
      expect(east, closeTo(0.0, 0.001));
      expect(north, closeTo(0.0, 0.001));
      expect(up, closeTo(1.0, 0.001));
    });

    test('directionVector computes correct components for vertical down shot', () {
      // Vertical shot pointing down (inclination -90)
      final m = RawMeasurement(
        distance: 10.0,
        azimuth: 0.0,
        inclination: -90.0,
        timestamp: DateTime.now(),
      );

      final (east, north, up) = m.directionVector;
      expect(east, closeTo(0.0, 0.001));
      expect(north, closeTo(0.0, 0.001));
      expect(up, closeTo(-1.0, 0.001));
    });
  });
}
