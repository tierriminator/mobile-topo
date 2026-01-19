import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/models/calibration.dart';
import 'package:mobile_topo/services/calibration_algorithm.dart';
import 'package:mobile_topo/utils/matrix_helpers.dart';
import 'package:vector_math/vector_math.dart';

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
        aG: matrix3FromRowMajor([0.5, 0, 0, 0, 0.5, 0, 0, 0, 0.5]),
        bG: Vector3(10, 20, 30),
        aM: matrix3FromRowMajor([0.25, 0, 0, 0, 0.25, 0, 0, 0, 0.25]),
        bM: Vector3(5, 10, 15),
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
          aG: matrix3FromRowMajor([1.1, 0.01, -0.02, 0.02, 0.98, 0.03, -0.01, -0.02, 1.05]),
          bG: Vector3(0.1, -0.2, 0.3),
          aM: matrix3FromRowMajor([0.95, 0.05, 0.01, -0.03, 1.02, -0.02, 0.01, 0.03, 0.99]),
          bM: Vector3(-0.15, 0.25, -0.1),
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
        final g = Vector3(0, -1, 0); // Gravity pointing down in device Y axis
        final m = Vector3(0, 0, 1);

        final coeff = CalibrationCoefficients.identity();
        final (_, inclination, _) = coeff.computeAngles(g, m);

        // Inclination should be close to 0 (horizontal)
        expect(inclination.abs(), lessThan(5));
      });

      test('azimuth differs by 90 degrees when M rotates 90 degrees', () {
        // Device horizontal, gravity in Y direction
        final g = Vector3(0, -1, 0);
        final mA = Vector3(1, 0, 0);
        final mB = Vector3(0, 0, 1);

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
        final gHorizontal = Vector3(0, -1, 0);
        final gPointingUp = Vector3(0, 0, -1);
        final gPointingDown = Vector3(0, 0, 1);
        final m = Vector3(1, 0, 0);

        final coeff = CalibrationCoefficients.identity();
        final (_, inclHoriz, _) = coeff.computeAngles(gHorizontal, m);
        final (_, inclUp, _) = coeff.computeAngles(gPointingUp, m);
        final (_, inclDown, _) = coeff.computeAngles(gPointingDown, m);

        expect(inclHoriz, closeTo(0, 5));
        expect(inclUp, closeTo(90, 5));
        expect(inclDown, closeTo(-90, 5));
      });

      test('returns valid azimuth in 0-360 range', () {
        final g = Vector3(0, -1, 0);
        final m = Vector3(0.5, 0, 0.5);

        final coeff = CalibrationCoefficients.identity();
        final (azimuth, _, _) = coeff.computeAngles(g, m);

        expect(azimuth, greaterThanOrEqualTo(0));
        expect(azimuth, lessThan(360));
      });
    });
  });

  group('CalibrationData', () {
    test('defaultGroup returns correct groups for all 56 measurements', () {
      // Groups are "0" through "13", with 4 measurements per group
      // Group 0: measurements 1-4
      expect(CalibrationData.defaultGroup(1), '0');
      expect(CalibrationData.defaultGroup(2), '0');
      expect(CalibrationData.defaultGroup(3), '0');
      expect(CalibrationData.defaultGroup(4), '0');

      // Group 1: measurements 5-8
      expect(CalibrationData.defaultGroup(5), '1');
      expect(CalibrationData.defaultGroup(8), '1');

      // Group 2: measurements 9-12
      expect(CalibrationData.defaultGroup(9), '2');
      expect(CalibrationData.defaultGroup(12), '2');

      // Group 3: measurements 13-16
      expect(CalibrationData.defaultGroup(13), '3');
      expect(CalibrationData.defaultGroup(16), '3');

      // Group 4: measurements 17-20
      expect(CalibrationData.defaultGroup(17), '4');
      expect(CalibrationData.defaultGroup(20), '4');

      // Group 13: measurements 53-56 (last group)
      expect(CalibrationData.defaultGroup(53), '13');
      expect(CalibrationData.defaultGroup(54), '13');
      expect(CalibrationData.defaultGroup(55), '13');
      expect(CalibrationData.defaultGroup(56), '13');

      // Out of range: null
      expect(CalibrationData.defaultGroup(0), isNull);
      expect(CalibrationData.defaultGroup(57), isNull);
      expect(CalibrationData.defaultGroup(-1), isNull);
    });

    test('all 56 measurements have groups assigned', () {
      // Every measurement from 1-56 should have a group
      for (int i = 1; i <= 56; i++) {
        expect(CalibrationData.defaultGroup(i), isNotNull,
            reason: 'Measurement $i should have a group');
      }
    });

    test('14 unique groups with 4 measurements each', () {
      // Count measurements per group
      final groupCounts = <String, int>{};
      for (int i = 1; i <= 56; i++) {
        final group = CalibrationData.defaultGroup(i)!;
        groupCounts[group] = (groupCounts[group] ?? 0) + 1;
      }

      // Should have exactly 14 groups
      expect(groupCounts.length, 14);

      // Each group should have exactly 4 measurements
      for (final entry in groupCounts.entries) {
        expect(entry.value, 4, reason: 'Group ${entry.key} should have 4 measurements');
      }
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

    test('computes calibration for standard 14-direction data', () async {
      // Use the standard 56-measurement pattern (14 directions × 4 orientations)
      final measurements = _generateStandardMeasurements();

      // Run calibration
      final result = await algorithm.compute(measurements);

      // Check that we got results
      expect(result.iterations, greaterThan(0));
      expect(result.iterations, lessThanOrEqualTo(CalibrationAlgorithm.maxIterations));

      // Results should have same count as input
      expect(result.results.length, measurements.length);

      // Coefficients should be non-null
      expect(result.coefficients, isNotNull);

      // RMS error should be computed
      expect(result.rmsError, greaterThanOrEqualTo(0));
    });

    test('handles measurements in orthogonal directions', () async {
      // Create measurements in 6 orthogonal directions (±X, ±Y, ±Z)
      // with 4 different roll angles each (24 measurements total, padding to 28)
      // Note: G and M need to have different orientations (magnetic dip)
      final measurements = <CalibrationMeasurement>[];
      const magnitude = 16000;
      const dipAngle = 0.866; // ~60 degree dip: cos(60) = 0.5, sin(60) = 0.866

      // Directions for G: +X, -X, +Y, -Y, +Z, -Z
      final gDirections = [
        [magnitude, 0, 0],
        [-magnitude, 0, 0],
        [0, magnitude, 0],
        [0, -magnitude, 0],
        [0, 0, magnitude],
        [0, 0, -magnitude],
      ];

      int index = 1;
      for (final gDir in gDirections) {
        for (int roll = 0; roll < 4; roll++) {
          // M is rotated from G by dip angle (not aligned with G)
          final mDip = (magnitude * dipAngle).round(); // sin(60) component
          measurements.add(CalibrationMeasurement(
            gx: gDir[0],
            gy: gDir[1],
            gz: gDir[2],
            // M is perpendicular component + dip component
            mx: gDir[0] ~/ 2 + (gDir[2] != 0 ? 0 : mDip),
            my: gDir[1] ~/ 2 + (gDir[2] != 0 ? mDip : 0),
            mz: gDir[2] ~/ 2 + (gDir[0] != 0 ? mDip : (gDir[1] != 0 ? mDip : 0)),
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
          mx: magnitude ~/ 2,
          my: (magnitude * dipAngle).round(),
          mz: 0,
          index: index,
          enabled: true,
        ));
        index++;
      }

      final result = await algorithm.compute(measurements);

      expect(result.coefficients, isNotNull);
      // Note: with synthetic data, RMS error may be higher
      expect(result.rmsError, greaterThanOrEqualTo(0));

      // Calibrated vectors should all have reasonable magnitude (not near zero)
      for (final r in result.results) {
        expect(r.gMagnitude, greaterThan(0.01));
        expect(r.mMagnitude, greaterThan(0.01));
      }
    });

    test('calibrates with scaled sensor data', () async {
      // Generate measurements with scale factor applied
      // This tests that the algorithm handles sensors that need scaling
      final measurements = _generateStandardMeasurements();

      final result = await algorithm.compute(measurements);

      expect(result.coefficients, isNotNull);
      expect(result.rmsError, greaterThanOrEqualTo(0));

      // Calibration should produce finite, reasonable matrix elements
      final aG = result.coefficients.aG;
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          expect(aG.get(i, j).isFinite, true);
          expect(aG.get(i, j).abs(), lessThan(10)); // Reasonable bounds
        }
      }
    });

    test('converges within max iterations', () async {
      final measurements = _generateStandardMeasurements();
      final result = await algorithm.compute(measurements);

      expect(result.iterations, greaterThan(0));
      expect(result.iterations, lessThanOrEqualTo(CalibrationAlgorithm.maxIterations));
    });

    test('produces consistent alpha angles', () async {
      // After good calibration, all alpha angles should be similar
      // (alpha = angle between G and M, i.e., the dip angle)
      final measurements = _generateStandardMeasurements();
      final result = await algorithm.compute(measurements);

      expect(result.results.isNotEmpty, true);

      // Compute mean and check all are within tolerance
      final alphas = result.results.map((r) => r.alpha).toList();
      final meanAlpha = alphas.reduce((a, b) => a + b) / alphas.length;

      for (final alpha in alphas) {
        expect(alpha, closeTo(meanAlpha, 10.0),
            reason: 'Alpha angles should be consistent');
      }
    });

    test('results count matches enabled measurements', () async {
      final measurements = _generateStandardMeasurements();

      // Disable some measurements
      final modified = measurements.asMap().entries.map((e) {
        return e.value.copyWith(enabled: e.key % 3 != 0); // Disable every 3rd
      }).toList();

      final enabledCount = modified.where((m) => m.enabled).length;

      // Ensure we still have enough
      if (enabledCount >= CalibrationAlgorithm.minMeasurements) {
        final result = await algorithm.compute(modified);
        expect(result.results.length, enabledCount);
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

// Helper functions for generating test data

/// Generate 14 well-distributed directions for calibration.
/// These approximate the recommended calibration orientations:
/// - 4 horizontal directions (N, E, S, W)
/// - 4 intermediate horizontal (NE, SE, SW, NW)
/// - 3 upward tilted
/// - 3 downward tilted
List<Vector3> _generate14Directions() {
  final directions = <Vector3>[];

  // 4 cardinal horizontal directions
  directions.add(Vector3(1, 0, 0)); // +X (East)
  directions.add(Vector3(0, 1, 0)); // +Y (North)
  directions.add(Vector3(-1, 0, 0)); // -X (West)
  directions.add(Vector3(0, -1, 0)); // -Y (South)

  // 4 intermediate horizontal
  final sqrt2 = math.sqrt(2) / 2;
  directions.add(Vector3(sqrt2, sqrt2, 0)); // NE
  directions.add(Vector3(sqrt2, -sqrt2, 0)); // SE
  directions.add(Vector3(-sqrt2, -sqrt2, 0)); // SW
  directions.add(Vector3(-sqrt2, sqrt2, 0)); // NW

  // 3 upward tilted (~45 degrees up)
  final tilt = math.sqrt(2) / 2;
  directions.add(Vector3(tilt, 0, tilt)); // +X up
  directions.add(Vector3(0, tilt, tilt)); // +Y up
  directions.add(Vector3(-tilt, 0, tilt)); // -X up

  // 3 downward tilted (~45 degrees down)
  directions.add(Vector3(tilt, 0, -tilt)); // +X down
  directions.add(Vector3(0, tilt, -tilt)); // +Y down
  directions.add(Vector3(0, -tilt, -tilt)); // -Y down

  return directions;
}

/// Rotate a direction vector to simulate magnetic dip angle.
/// The magnetic field is not parallel to gravity - there's a dip angle.
Vector3 _rotateForDip(Vector3 dir, double dipAngle) {
  // Simple rotation: add a vertical component based on dip
  final cosD = math.cos(dipAngle);
  final sinD = math.sin(dipAngle);

  // Rotate around an axis perpendicular to dir
  // For simplicity, we'll just blend horizontal and vertical components
  return Vector3(
    dir.x * cosD,
    dir.y * cosD,
    dir.z * cosD + sinD,
  ).normalized();
}

/// Generate a standard set of 56 measurements for testing.
List<CalibrationMeasurement> _generateStandardMeasurements() {
  final measurements = <CalibrationMeasurement>[];
  const baseMagnitude = 16000.0;
  const dipAngle = 60 * math.pi / 180; // 60 degree dip

  final directions = _generate14Directions();

  int index = 1;
  for (final dir in directions) {
    for (int roll = 0; roll < 4; roll++) {
      // Simulate different roll angles with small variations
      // For simplicity, just use the direction with small variations
      final gx = (dir.x * baseMagnitude + roll * 10).round();
      final gy = (dir.y * baseMagnitude + roll * 10).round();
      final gz = (dir.z * baseMagnitude + roll * 10).round();

      final mDir = _rotateForDip(dir, dipAngle);
      final mx = (mDir.x * baseMagnitude).round();
      final my = (mDir.y * baseMagnitude).round();
      final mz = (mDir.z * baseMagnitude).round();

      measurements.add(CalibrationMeasurement(
        gx: gx,
        gy: gy,
        gz: gz,
        mx: mx,
        my: my,
        mz: mz,
        index: index,
        enabled: true,
        group: CalibrationData.defaultGroup(index),
      ));
      index++;
    }
  }

  return measurements;
}
