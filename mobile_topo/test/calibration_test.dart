import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/models/calibration.dart';
import 'package:mobile_topo/services/calibration_algorithm.dart';
import 'package:mobile_topo/utils/linear_algebra.dart';

void main() {
  group('CalibrationMeasurement', () {
    test('creates measurement with all fields', () {
      const m = CalibrationMeasurement(
        gx: 100,
        gy: 200,
        gz: 300,
        mx: 400,
        my: 500,
        mz: 600,
        index: 1,
        enabled: true,
        group: 'A',
      );

      expect(m.gx, 100);
      expect(m.gy, 200);
      expect(m.gz, 300);
      expect(m.mx, 400);
      expect(m.my, 500);
      expect(m.mz, 600);
      expect(m.index, 1);
      expect(m.enabled, true);
      expect(m.group, 'A');
    });

    test('gVector returns correct vector', () {
      const m = CalibrationMeasurement(
        gx: 100,
        gy: 200,
        gz: 300,
        mx: 0,
        my: 0,
        mz: 0,
        index: 1,
      );

      expect(m.gVector.x, 100);
      expect(m.gVector.y, 200);
      expect(m.gVector.z, 300);
    });

    test('mVector returns correct vector', () {
      const m = CalibrationMeasurement(
        gx: 0,
        gy: 0,
        gz: 0,
        mx: 400,
        my: 500,
        mz: 600,
        index: 1,
      );

      expect(m.mVector.x, 400);
      expect(m.mVector.y, 500);
      expect(m.mVector.z, 600);
    });

    test('copyWith creates modified copy', () {
      const m = CalibrationMeasurement(
        gx: 100,
        gy: 200,
        gz: 300,
        mx: 400,
        my: 500,
        mz: 600,
        index: 1,
        enabled: true,
        group: 'A',
      );

      final disabled = m.copyWith(enabled: false);
      expect(disabled.enabled, false);
      expect(disabled.gx, 100); // Unchanged

      final groupB = m.copyWith(group: 'B');
      expect(groupB.group, 'B');

      final noGroup = m.copyWith(clearGroup: true);
      expect(noGroup.group, isNull);
    });

    test('toJson and fromJson roundtrip', () {
      const original = CalibrationMeasurement(
        gx: 100,
        gy: -200,
        gz: 300,
        mx: -400,
        my: 500,
        mz: -600,
        index: 5,
        enabled: false,
        group: 'B',
      );

      final json = original.toJson();
      final restored = CalibrationMeasurement.fromJson(json);

      expect(restored.gx, original.gx);
      expect(restored.gy, original.gy);
      expect(restored.gz, original.gz);
      expect(restored.mx, original.mx);
      expect(restored.my, original.my);
      expect(restored.mz, original.mz);
      expect(restored.index, original.index);
      expect(restored.enabled, original.enabled);
      expect(restored.group, original.group);
    });
  });

  group('CalibrationCoefficients', () {
    test('identity coefficients', () {
      final coeff = CalibrationCoefficients.identity();

      // Check identity matrices
      expect(coeff.aG.get(0, 0), 1);
      expect(coeff.aG.get(1, 1), 1);
      expect(coeff.aG.get(2, 2), 1);
      expect(coeff.aG.get(0, 1), 0);

      expect(coeff.aM.get(0, 0), 1);
      expect(coeff.aM.get(1, 1), 1);
      expect(coeff.aM.get(2, 2), 1);

      // Check zero bias
      expect(coeff.bG.x, 0);
      expect(coeff.bG.y, 0);
      expect(coeff.bG.z, 0);
      expect(coeff.bM.x, 0);
      expect(coeff.bM.y, 0);
      expect(coeff.bM.z, 0);
    });

    test('apply transforms raw measurement', () {
      // Create coefficients with 2x scaling
      final coeff = CalibrationCoefficients(
        aG: Matrix3([0.5, 0, 0, 0, 0.5, 0, 0, 0, 0.5]),
        bG: const Vector3(10, 20, 30),
        aM: Matrix3([0.25, 0, 0, 0, 0.25, 0, 0, 0, 0.25]),
        bM: const Vector3(5, 10, 15),
      );

      const m = CalibrationMeasurement(
        gx: 100,
        gy: 200,
        gz: 300,
        mx: 400,
        my: 800,
        mz: 1200,
        index: 1,
      );

      final (g, mag) = coeff.apply(m);

      // G: 0.5 * [100, 200, 300] + [10, 20, 30] = [60, 120, 180]
      expect(g.x, closeTo(60, 1e-10));
      expect(g.y, closeTo(120, 1e-10));
      expect(g.z, closeTo(180, 1e-10));

      // M: 0.25 * [400, 800, 1200] + [5, 10, 15] = [105, 210, 315]
      expect(mag.x, closeTo(105, 1e-10));
      expect(mag.y, closeTo(210, 1e-10));
      expect(mag.z, closeTo(315, 1e-10));
    });

    group('byte serialization', () {
      test('toBytes produces 48 bytes', () {
        final coeff = CalibrationCoefficients.identity();
        final bytes = coeff.toBytes();
        expect(bytes.length, 48);
      });

      test('roundtrip preserves identity coefficients', () {
        final original = CalibrationCoefficients.identity();
        final bytes = original.toBytes();
        final restored = CalibrationCoefficients.fromBytes(bytes);

        // Check matrices are close to identity
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            final expected = i == j ? 1.0 : 0.0;
            expect(restored.aG.get(i, j), closeTo(expected, 0.001));
            expect(restored.aM.get(i, j), closeTo(expected, 0.001));
          }
        }

        // Check bias vectors are close to zero
        expect(restored.bG.x, closeTo(0, 0.001));
        expect(restored.bG.y, closeTo(0, 0.001));
        expect(restored.bG.z, closeTo(0, 0.001));
        expect(restored.bM.x, closeTo(0, 0.001));
        expect(restored.bM.y, closeTo(0, 0.001));
        expect(restored.bM.z, closeTo(0, 0.001));
      });

      test('roundtrip preserves non-trivial coefficients', () {
        final original = CalibrationCoefficients(
          aG: Matrix3([1.1, 0.01, -0.02, 0.02, 0.98, 0.03, -0.01, -0.02, 1.05]),
          bG: const Vector3(0.1, -0.2, 0.3),
          aM: Matrix3([0.95, 0.05, 0.01, -0.03, 1.02, -0.02, 0.01, 0.03, 0.99]),
          bM: const Vector3(-0.15, 0.25, -0.1),
        );

        final bytes = original.toBytes();
        final restored = CalibrationCoefficients.fromBytes(bytes);

        // Check G matrix elements
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            expect(
              restored.aG.get(i, j),
              closeTo(original.aG.get(i, j), 0.001),
              reason: 'aG[$i,$j] mismatch',
            );
          }
        }

        // Check M matrix elements
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            expect(
              restored.aM.get(i, j),
              closeTo(original.aM.get(i, j), 0.001),
              reason: 'aM[$i,$j] mismatch',
            );
          }
        }

        // Check bias vectors
        expect(restored.bG.x, closeTo(original.bG.x, 0.001));
        expect(restored.bG.y, closeTo(original.bG.y, 0.001));
        expect(restored.bG.z, closeTo(original.bG.z, 0.001));
        expect(restored.bM.x, closeTo(original.bM.x, 0.001));
        expect(restored.bM.y, closeTo(original.bM.y, 0.001));
        expect(restored.bM.z, closeTo(original.bM.z, 0.001));
      });

      test('fromBytes throws for short buffer', () {
        expect(
          () => CalibrationCoefficients.fromBytes(Uint8List(40)),
          throwsArgumentError,
        );
      });
    });

    group('computeAngles', () {
      test('horizontal device returns near-zero inclination', () {
        // For inclination = asin(-gNorm.z) to be 0, gNorm.z must be 0
        // When device is horizontal (pointing forward along some horizontal direction),
        // gravity points down, which is perpendicular to the pointing direction
        // So G should have z = 0 (gravity has no component in pointing direction)
        const g = Vector3(0, -1, 0); // Gravity pointing down in device Y axis
        const m = Vector3(0, 0, 1);

        final coeff = CalibrationCoefficients.identity();
        final (_, inclination, _) = coeff.computeAngles(g, m);

        // Inclination should be close to 0 (horizontal)
        expect(inclination.abs(), lessThan(5));
      });

      test('azimuth differs by 90 degrees when M rotates 90 degrees', () {
        // Device horizontal, gravity in Y direction
        const g = Vector3(0, -1, 0);
        const mA = Vector3(1, 0, 0);
        const mB = Vector3(0, 0, 1);

        final coeff = CalibrationCoefficients.identity();
        final (aziA, _, _) = coeff.computeAngles(g, mA);
        final (aziB, _, _) = coeff.computeAngles(g, mB);

        // The difference should be ~90 degrees
        var diff = (aziB - aziA).abs();
        if (diff > 180) diff = 360 - diff;
        expect(diff, closeTo(90, 10));
      });

      test('inclination changes with device tilt', () {
        // Inclination = asin(-gNorm.z)
        // When gNorm.z = 0, inclination = 0 (horizontal)
        // When gNorm.z = -1, inclination = +90 (pointing up)
        // When gNorm.z = +1, inclination = -90 (pointing down)
        const gHorizontal = Vector3(0, -1, 0);
        const gPointingUp = Vector3(0, 0, -1);
        const gPointingDown = Vector3(0, 0, 1);
        const m = Vector3(1, 0, 0);

        final coeff = CalibrationCoefficients.identity();
        final (_, inclHoriz, _) = coeff.computeAngles(gHorizontal, m);
        final (_, inclUp, _) = coeff.computeAngles(gPointingUp, m);
        final (_, inclDown, _) = coeff.computeAngles(gPointingDown, m);

        expect(inclHoriz, closeTo(0, 5));
        expect(inclUp, closeTo(90, 5));
        expect(inclDown, closeTo(-90, 5));
      });

      test('returns valid azimuth in 0-360 range', () {
        const g = Vector3(0, -1, 0);
        const m = Vector3(0.5, 0, 0.5);

        final coeff = CalibrationCoefficients.identity();
        final (azimuth, _, _) = coeff.computeAngles(g, m);

        expect(azimuth, greaterThanOrEqualTo(0));
        expect(azimuth, lessThan(360));
      });
    });
  });

  group('CalibrationData', () {
    test('defaultGroup returns correct groups', () {
      // First 4: A
      expect(CalibrationData.defaultGroup(1), 'A');
      expect(CalibrationData.defaultGroup(4), 'A');

      // Next 4: B
      expect(CalibrationData.defaultGroup(5), 'B');
      expect(CalibrationData.defaultGroup(8), 'B');

      // Next 4: A
      expect(CalibrationData.defaultGroup(9), 'A');
      expect(CalibrationData.defaultGroup(12), 'A');

      // Next 4: B
      expect(CalibrationData.defaultGroup(13), 'B');
      expect(CalibrationData.defaultGroup(16), 'B');

      // Beyond 16: null
      expect(CalibrationData.defaultGroup(17), isNull);
      expect(CalibrationData.defaultGroup(56), isNull);
    });

    test('empty constant', () {
      expect(CalibrationData.empty.measurements, isEmpty);
      expect(CalibrationData.empty.results, isNull);
      expect(CalibrationData.empty.coefficients, isNull);
    });
  });

  group('CalibrationAlgorithm', () {
    late CalibrationAlgorithm algorithm;

    setUp(() {
      algorithm = CalibrationAlgorithm();
    });

    test('throws for too few measurements', () async {
      final measurements = List.generate(
        10,
        (i) => CalibrationMeasurement(
          gx: 1000,
          gy: 0,
          gz: 0,
          mx: 500,
          my: 0,
          mz: 0,
          index: i + 1,
        ),
      );

      expect(
        () => algorithm.compute(measurements),
        throwsA(isA<CalibrationException>()),
      );
    });

    test('ignores disabled measurements', () async {
      // Create 20 measurements, but disable some so only 10 are enabled
      final measurements = List.generate(
        20,
        (i) => CalibrationMeasurement(
          gx: 1000,
          gy: 0,
          gz: 0,
          mx: 500,
          my: 0,
          mz: 0,
          index: i + 1,
          enabled: i < 10, // Only first 10 enabled
        ),
      );

      expect(
        () => algorithm.compute(measurements),
        throwsA(isA<CalibrationException>()),
      );
    });

    test('computes calibration for varied directions', () async {
      // Generate measurements in various directions with different orientations
      // This tests that the algorithm can handle real-world-like data
      final measurements = <CalibrationMeasurement>[];
      final random = math.Random(42); // Fixed seed for reproducibility

      // Generate 56 measurements with varied sensor readings
      // Simulate a sensor with some bias and scale errors
      for (int i = 0; i < 56; i++) {
        // Generate random direction
        final theta = random.nextDouble() * 2 * math.pi;
        final phi = (random.nextDouble() - 0.5) * math.pi;

        // Simulated sensor readings with some variation
        const scale = 16000.0;
        final gx = (math.cos(phi) * math.cos(theta) * scale +
                (random.nextDouble() - 0.5) * 500)
            .round();
        final gy = (math.cos(phi) * math.sin(theta) * scale +
                (random.nextDouble() - 0.5) * 500)
            .round();
        final gz = (math.sin(phi) * scale + (random.nextDouble() - 0.5) * 500)
            .round();

        // M readings (similar pattern, slightly different)
        final mx = (math.cos(phi + 0.5) * math.cos(theta) * scale * 0.9 +
                (random.nextDouble() - 0.5) * 500)
            .round();
        final my = (math.cos(phi + 0.5) * math.sin(theta) * scale * 0.9 +
                (random.nextDouble() - 0.5) * 500)
            .round();
        final mz = (math.sin(phi + 0.5) * scale * 0.9 +
                (random.nextDouble() - 0.5) * 500)
            .round();

        measurements.add(CalibrationMeasurement(
          gx: gx,
          gy: gy,
          gz: gz,
          mx: mx,
          my: my,
          mz: mz,
          index: i + 1,
          enabled: true,
          group: CalibrationData.defaultGroup(i + 1),
        ));
      }

      // Run calibration
      final result = await algorithm.compute(measurements);

      // Check that we got results
      expect(result.iterations, greaterThan(0));
      expect(result.iterations, lessThanOrEqualTo(CalibrationAlgorithm.maxIterations));

      // Results should have same count as input
      expect(result.results.length, measurements.length);

      // Coefficients should be non-null
      expect(result.coefficients, isNotNull);

      // After calibration, magnitudes should be reasonably close to 1
      // (within 50% for noisy data)
      for (final r in result.results) {
        expect(r.gMagnitude, greaterThan(0.5));
        expect(r.gMagnitude, lessThan(1.5));
        expect(r.mMagnitude, greaterThan(0.5));
        expect(r.mMagnitude, lessThan(1.5));
      }
    });

    test('computes calibration for simple aligned data', () async {
      // Create simple measurements aligned with coordinate axes
      final measurements = <CalibrationMeasurement>[];

      // 16 measurements minimum, all pointing in +X direction with 16000 magnitude
      // This tests that the algorithm handles simple, consistent data
      for (int i = 0; i < 16; i++) {
        measurements.add(CalibrationMeasurement(
          gx: 16000,
          gy: 0,
          gz: 0,
          mx: 16000,
          my: 0,
          mz: 0,
          index: i + 1,
          enabled: true,
          group: CalibrationData.defaultGroup(i + 1),
        ));
      }

      final result = await algorithm.compute(measurements);

      expect(result.coefficients, isNotNull);
      expect(result.results.length, 16);

      // For identical measurements, after calibration all should have same angles
      final firstAzi = result.results[0].azimuth;
      final firstIncl = result.results[0].inclination;

      for (final r in result.results) {
        expect(r.azimuth, closeTo(firstAzi, 1.0));
        expect(r.inclination, closeTo(firstIncl, 1.0));
      }
    });

    test('handles measurements in orthogonal directions', () async {
      // Create measurements in 6 orthogonal directions (±X, ±Y, ±Z)
      // with 4 different roll angles each (24 measurements total, padding to 28)
      final measurements = <CalibrationMeasurement>[];
      const magnitude = 16000;

      // Directions: +X, -X, +Y, -Y, +Z, -Z
      final directions = [
        [magnitude, 0, 0],
        [-magnitude, 0, 0],
        [0, magnitude, 0],
        [0, -magnitude, 0],
        [0, 0, magnitude],
        [0, 0, -magnitude],
      ];

      int index = 1;
      for (final dir in directions) {
        for (int roll = 0; roll < 4; roll++) {
          measurements.add(CalibrationMeasurement(
            gx: dir[0],
            gy: dir[1],
            gz: dir[2],
            mx: dir[0], // Simplified: M aligned with G
            my: dir[1],
            mz: dir[2],
            index: index,
            enabled: true,
            group: CalibrationData.defaultGroup(index),
          ));
          index++;
        }
      }

      // Add 4 more to reach minimum of 28 for good distribution
      for (int i = 0; i < 4; i++) {
        measurements.add(CalibrationMeasurement(
          gx: magnitude,
          gy: 0,
          gz: 0,
          mx: magnitude,
          my: 0,
          mz: 0,
          index: index,
          enabled: true,
        ));
        index++;
      }

      final result = await algorithm.compute(measurements);

      expect(result.coefficients, isNotNull);
      expect(result.rmsError, lessThan(1.0)); // Low error for clean data

      // Calibrated vectors should all have magnitude close to 1
      for (final r in result.results) {
        expect(r.gMagnitude, closeTo(1.0, 0.1));
        expect(r.mMagnitude, closeTo(1.0, 0.1));
      }
    });
  });

  group('CalibrationResult', () {
    test('stores all computed values', () {
      const result = CalibrationResult(
        error: 0.25,
        gMagnitude: 1.002,
        mMagnitude: 0.998,
        alpha: 62.5,
        azimuth: 45.0,
        inclination: -10.0,
        roll: 15.0,
      );

      expect(result.error, 0.25);
      expect(result.gMagnitude, 1.002);
      expect(result.mMagnitude, 0.998);
      expect(result.alpha, 62.5);
      expect(result.azimuth, 45.0);
      expect(result.inclination, -10.0);
      expect(result.roll, 15.0);
    });
  });
}
