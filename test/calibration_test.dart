import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/models/calibration.dart';
import 'package:mobile_topo/services/calibration_algorithm.dart';
import 'package:mobile_topo/services/calibration_service.dart';
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
        group: 1,
      );

      expect(m.gx, 100);
      expect(m.gy, 200);
      expect(m.gz, 300);
      expect(m.mx, 400);
      expect(m.my, 500);
      expect(m.mz, 600);
      expect(m.index, 1);
      expect(m.enabled, true);
      expect(m.group, 1);
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
        group: 1,
      );

      final disabled = m.copyWith(enabled: false);
      expect(disabled.enabled, false);
      expect(disabled.gx, 100); // Unchanged

      final groupB = m.copyWith(group: 2);
      expect(groupB.group, 2);

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
        group: 2,
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

    test('apply scales raw counts by rawUnit before transforming', () {
      final coeff = CalibrationCoefficients(
        aG: matrix3FromRowMajor([0.5, 0, 0, 0, 0.5, 0, 0, 0, 0.5]),
        bG: Vector3(10, 20, 30),
        aM: matrix3FromRowMajor([0.25, 0, 0, 0, 0.25, 0, 0, 0, 0.25]),
        bM: Vector3(5, 10, 15),
      );

      const raw = CalibrationMeasurement(
        gx: 100,
        gy: 200,
        gz: 300,
        mx: 400,
        my: 800,
        mz: 1200,
        index: 1,
      );

      final (g, mag) = coeff.apply(raw);
      const u = CalibrationCoefficients.rawUnit;
      // vector_math stores components as float32, hence the modest tolerance.
      const tol = 1e-5;

      // G: 0.5 * ([100, 200, 300] * u) + [10, 20, 30]
      expect(g.x, closeTo(0.5 * 100 * u + 10, tol));
      expect(g.y, closeTo(0.5 * 200 * u + 20, tol));
      expect(g.z, closeTo(0.5 * 300 * u + 30, tol));

      // M: 0.25 * ([400, 800, 1200] * u) + [5, 10, 15]
      expect(mag.x, closeTo(0.25 * 400 * u + 5, tol));
      expect(mag.y, closeTo(0.25 * 800 * u + 10, tol));
      expect(mag.z, closeTo(0.25 * 1200 * u + 15, tol));
    });

    test('error scale matches the paper angular error relation', () {
      // Heeb bounds the angular error of a calibration at sqrt(3) * E radians
      // (E being the dimensionless error measure of eq. 4), so E expressed as
      // a percentage is within 1% of the angular error in degrees. That is why
      // the DistoX2 calibration manual can ask for "smaller than 0.5" and
      // still expect a device that reads to a few tenths of a degree.
      final degreesPerUnitE = math.sqrt(3) * 180 / math.pi; // 99.2
      expect(CalibrationResult.errorScale, closeTo(degreesPerUnitE, 1.0));
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

      test('saturatedElements is empty for representable coefficients', () {
        expect(CalibrationCoefficients.identity().saturatedElements, isEmpty);
      });

      test('saturatedElements names elements toBytes would clamp', () {
        // A magnetometer whose counts per unit field are far below FV needs a
        // gain the int16 format cannot express; clamping it would leave the
        // device with a near-singular transform.
        final tooBig = CalibrationCoefficients(
          aG: Matrix3.identity(),
          bG: Vector3.zero(),
          aM: matrix3FromRowMajor([12, 0, 0, 0, 1, 0, 0, 0, 1]),
          bM: Vector3(0, 3.0, 0),
        );

        expect(tooBig.saturatedElements, containsAll(<String>['aM[0,0]=12.000']));
        expect(tooBig.saturatedElements.join(), contains('bM.y'));

        // And the clamping it warns about really does happen.
        final restored =
            CalibrationCoefficients.fromBytes(tooBig.toBytes());
        expect(restored.aM.get(0, 0), lessThan(12));
      });

      test('fromBytes throws for short buffer', () {
        expect(
          () => CalibrationCoefficients.fromBytes(Uint8List(40)),
          throwsArgumentError,
        );
      });
    });

    group('computeAngles', () {
      // Device frame: x = forward (laser), y = right, z = down.
      // Ground truth vectors come from equation 2 of the calibration paper.

      test('recovers the orientation angles of the true vectors', () {
        const alpha = 27.0; // angle between gravity and magnetic field
        final cases = <(double yaw, double pitch, double roll)>[
          (0, 0, 0),
          (90, 0, 0),
          (180, 0, 0),
          (270, 0, 0),
          (45, 35.3, 90),
          (135, -35.3, 180),
          (315, 60, 270),
          (200, -70, 45),
        ];

        for (final (yaw, pitch, roll) in cases) {
          final (g, m) = _trueVectors(yaw, pitch, roll, alpha);
          final (azimuth, inclination, gotRoll) =
              CalibrationCoefficients.anglesFromVectors(g, m);

          // vector_math stores components as float32, hence the tolerance.
          expect(azimuth, closeTo(yaw, 1e-4), reason: 'azimuth for $yaw/$pitch');
          expect(inclination, closeTo(pitch, 1e-4),
              reason: 'inclination for $yaw/$pitch');
          expect(_angleDiff(gotRoll, roll).abs(), lessThan(1e-4),
              reason: 'roll for $yaw/$pitch/$roll');
        }
      });

      test('inclination is +90 pointing up and -90 pointing down', () {
        // Laser is the x axis, so a device pointing straight up has gravity
        // along -x.
        final m = Vector3(0, 1, 0);
        final (_, up, _) =
            CalibrationCoefficients.anglesFromVectors(Vector3(-1, 0, 0), m);
        final (_, down, _) =
            CalibrationCoefficients.anglesFromVectors(Vector3(1, 0, 0), m);
        final (_, level, _) =
            CalibrationCoefficients.anglesFromVectors(Vector3(0, 0, 1), m);

        expect(up, closeTo(90, 1e-6));
        expect(down, closeTo(-90, 1e-6));
        expect(level, closeTo(0, 1e-6));
      });

      test('angles are invariant under the roll ambiguity', () {
        // G' = Rx(w) o G, M' = Rx(w) o M is an equally valid solution, so
        // azimuth and inclination must not depend on w.
        const alpha = 27.0;
        final (g, m) = _trueVectors(123, -40, 15, alpha);
        final (azimuth, inclination, _) =
            CalibrationCoefficients.anglesFromVectors(g, m);

        for (final w in [17.0, 90.0, 200.0]) {
          final rx = _rotX(w * math.pi / 180);
          final (a2, i2, _) = CalibrationCoefficients.anglesFromVectors(
              rx.transformVector(g), rx.transformVector(m));
          expect(a2, closeTo(azimuth, 1e-4));
          expect(i2, closeTo(inclination, 1e-4));
        }
      });

      test('returns valid azimuth in 0-360 range', () {
        final (azimuth, _, _) = CalibrationCoefficients.anglesFromVectors(
            Vector3(0, 0, 1), Vector3(0.5, 0, 0.5));

        expect(azimuth, greaterThanOrEqualTo(0));
        expect(azimuth, lessThan(360));
      });
    });
  });

  group('CalibrationData', () {
    test('defaultDirection assigns 4 consecutive shots to each direction', () {
      expect(CalibrationData.defaultDirection(1), 0);
      expect(CalibrationData.defaultDirection(4), 0);
      expect(CalibrationData.defaultDirection(5), 1);
      expect(CalibrationData.defaultDirection(16), 3);
      expect(CalibrationData.defaultDirection(17), 4);
      expect(CalibrationData.defaultDirection(53), 13);
      expect(CalibrationData.defaultDirection(56), 13);

      expect(CalibrationData.defaultDirection(0), isNull);
      expect(CalibrationData.defaultDirection(57), isNull);
      expect(CalibrationData.defaultDirection(-1), isNull);
    });

    test('14 directions with 4 measurements each', () {
      final counts = <int, int>{};
      for (int i = 1; i <= 56; i++) {
        final direction = CalibrationData.defaultDirection(i)!;
        counts[direction] = (counts[direction] ?? 0) + 1;
      }

      expect(counts.length, 14);
      for (final entry in counts.entries) {
        expect(entry.value, 4, reason: 'direction ${entry.key}');
      }
    });

    test('empty constant', () {
      expect(CalibrationData.empty.measurements, isEmpty);
      expect(CalibrationData.empty.results, isNull);
      expect(CalibrationData.empty.coefficients, isNull);
    });
  });

  group('CalibrationPositions grouping', () {
    test('only the four horizontal directions form unidirectional groups', () {
      for (int d = 0; d < 4; d++) {
        expect(CalibrationPositions.relativeDirections[d].$2, 0.0,
            reason: 'direction $d is horizontal');
        expect(CalibrationPositions.isPrecise(d), isTrue);
        expect(CalibrationPositions.groupFor(d), d);
      }
      for (int d = 4; d < 14; d++) {
        expect(CalibrationPositions.isPrecise(d), isFalse);
        expect(CalibrationPositions.groupFor(d), isNull,
            reason: 'direction $d is a free measurement');
      }
    });

    test('forDirection sets the direction and the group it implies', () {
      const raw = CalibrationMeasurement(
          gx: 1, gy: 2, gz: 3, mx: 4, my: 5, mz: 6, index: 1);

      final precise = raw.forDirection(2);
      expect(precise.direction, 2);
      expect(precise.group, 2);

      final free = precise.forDirection(9);
      expect(free.direction, 9);
      expect(free.group, isNull);
    });

    test('direction survives a JSON round trip', () {
      const original = CalibrationMeasurement(
          gx: 1, gy: 2, gz: 3, mx: 4, my: 5, mz: 6, index: 30, direction: 7);

      final restored = CalibrationMeasurement.fromJson(original.toJson());

      expect(restored.direction, 7);
      expect(restored.group, isNull);
    });
  });

  group('CalibrationAlgorithm', () {
    late CalibrationAlgorithm algorithm;

    setUp(() {
      algorithm = CalibrationAlgorithm();
    });

    test('splits the error into parts that add up to it', () async {
      final data = _syntheticCalibration(noiseCounts: 40, procedureGroups: true);

      final output = await algorithm.compute(data.measurements);
      final b = output.errorBreakdown;

      final sumOfSquares = b.gravityLength * b.gravityLength +
          b.magneticLength * b.magneticLength +
          b.dip * b.dip +
          b.aiming * b.aiming;
      expect(output.rmsError, greaterThan(0.05));
      expect(math.sqrt(sumOfSquares), closeTo(output.rmsError, 1e-3));
      expect(output.alpha, closeTo(_alphaDeg, 0.2));
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

    test('recovers a known sensor distortion from noise-free data', () async {
      final data = _syntheticCalibration();
      final result = await algorithm.compute(data.measurements);

      expect(result.iterations, greaterThan(0));
      expect(result.iterations,
          lessThanOrEqualTo(CalibrationAlgorithm.maxIterations));
      expect(result.results.length, data.measurements.length);

      // Noise-free input, so the fit should be essentially exact.
      expect(result.rmsError, lessThan(0.01),
          reason: 'RMS error ${result.rmsError} deg on exact data');

      for (int i = 0; i < data.measurements.length; i++) {
        final r = result.results[i];
        final orientation = data.orientations[i];

        expect(r.gMagnitude, closeTo(1.0, 1e-3), reason: 'shot $i |G|');
        expect(r.mMagnitude, closeTo(1.0, 1e-3), reason: 'shot $i |M|');
        expect(r.alpha, closeTo(_alphaDeg, 0.05), reason: 'shot $i alpha');
        expect(r.inclination, closeTo(orientation.pitch, 0.05),
            reason: 'shot $i inclination');

        // Azimuth is undefined when the laser points straight up or down.
        if (orientation.pitch.abs() < 85) {
          expect(_angleDiff(r.azimuth, orientation.yaw).abs(), lessThan(0.05),
              reason: 'shot $i azimuth');
        }
      }
    });

    test('coefficients survive the 48-byte device round trip', () async {
      final result = await algorithm.compute(_syntheticCalibration().measurements);
      final c = result.coefficients;

      // The A matrices act on raw counts scaled by rawUnit, so their diagonal
      // must be around 1, not around 1/16000 (which would quantize to 0 or 1).
      for (final v in [c.aG.get(0, 0), c.aG.get(1, 1), c.aG.get(2, 2)]) {
        expect(v, greaterThan(0.1), reason: 'aG diagonal $v too small');
        expect(v, lessThan(2.0), reason: 'aG diagonal $v too large');
      }

      final restored = CalibrationCoefficients.fromBytes(c.toBytes());
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          expect(restored.aG.get(i, j), closeTo(c.aG.get(i, j), 1e-4));
          expect(restored.aM.get(i, j), closeTo(c.aM.get(i, j), 1e-4));
        }
      }
      expect(restored.bG.x, closeTo(c.bG.x, 1e-4));
      expect(restored.bG.y, closeTo(c.bG.y, 1e-4));
      expect(restored.bG.z, closeTo(c.bG.z, 1e-4));
    });

    test('enforces the y-z symmetry of the G matrix', () async {
      final result = await algorithm.compute(_syntheticCalibration().measurements);
      final aG = result.coefficients.aG;
      expect(aG.get(1, 2), closeTo(aG.get(2, 1), 1e-12));
    });

    test('raw sensor vectors are not mutated by the computation', () async {
      final measurements = _syntheticCalibration().measurements;
      final before = [for (final m in measurements) m.gVector.clone()];

      await algorithm.compute(measurements);

      for (int i = 0; i < measurements.length; i++) {
        expect(measurements[i].gVector.x, before[i].x, reason: 'shot $i gx');
        expect(measurements[i].gVector.y, before[i].y, reason: 'shot $i gy');
        expect(measurements[i].gVector.z, before[i].z, reason: 'shot $i gz');
      }
    });

    test('result order follows input order, not group order', () async {
      final data = _syntheticCalibration();

      // Interleave the groups so that same-group measurements are no longer
      // adjacent in the list.
      final shuffled = <CalibrationMeasurement>[];
      final orientations = <_Orientation>[];
      for (int roll = 0; roll < 4; roll++) {
        for (int dir = 0; dir < 14; dir++) {
          final i = dir * 4 + roll;
          shuffled.add(data.measurements[i]);
          orientations.add(data.orientations[i]);
        }
      }

      final result = await algorithm.compute(shuffled);

      expect(result.rmsError, lessThan(0.01));
      for (int i = 0; i < shuffled.length; i++) {
        expect(result.results[i].inclination,
            closeTo(orientations[i].pitch, 0.05),
            reason: 'shot $i inclination');
      }
    });

    test('treats ungrouped measurements as free measurements', () async {
      final data = _syntheticCalibration();

      // Drop the group from the last roll of every direction. Those become
      // free measurements and must still get a result.
      final measurements = [
        for (int i = 0; i < data.measurements.length; i++)
          i % 4 == 3
              ? data.measurements[i].copyWith(clearGroup: true)
              : data.measurements[i],
      ];

      final result = await algorithm.compute(measurements);

      expect(result.results.length, measurements.length);
      expect(result.rmsError, lessThan(0.01));
      for (int i = 0; i < measurements.length; i++) {
        expect(result.results[i].inclination,
            closeTo(data.orientations[i].pitch, 0.05),
            reason: 'shot $i inclination');
      }
    });

    test('results align with the enabled measurements', () async {
      final data = _syntheticCalibration();
      final modified = [
        for (int i = 0; i < data.measurements.length; i++)
          data.measurements[i].copyWith(enabled: i % 5 != 0),
      ];
      final expectedPitches = [
        for (int i = 0; i < data.measurements.length; i++)
          if (i % 5 != 0) data.orientations[i].pitch,
      ];

      final result = await algorithm.compute(modified);

      expect(result.results.length, expectedPitches.length);
      for (int i = 0; i < expectedPitches.length; i++) {
        expect(result.results[i].inclination, closeTo(expectedPitches[i], 0.5),
            reason: 'result $i inclination');
      }
    });

    test('recovers alpha despite a large magnetometer offset and gain', () async {
      // The magnetometer sphere sits far from the accelerometer's: a quarter
      // of the gain and a hard-iron offset bigger than the field itself. The
      // paper's starting point of G = M = I still converges here.
      final data = _syntheticCalibration(
        magGain: 4000,
        magOffset: Vector3(-3000, 2200, 4100),
      );
      final result = await algorithm.compute(data.measurements);

      expect(result.rmsError, lessThan(0.05));

      final azimuths = <double>{};
      for (int i = 0; i < data.measurements.length; i++) {
        final r = result.results[i];
        expect(r.alpha, closeTo(_alphaDeg, 0.1), reason: 'shot $i alpha');
        if (data.orientations[i].pitch.abs() < 85) {
          expect(_angleDiff(r.azimuth, data.orientations[i].yaw).abs(),
              lessThan(0.2),
              reason: 'shot $i azimuth');
          azimuths.add(r.azimuth);
        }
      }
      // Guard the actual symptom: azimuth must span the circle, not sit on
      // two opposite values.
      expect(azimuths.length, greaterThan(4));
    });

    test('reports low coverage while directions are still missing', () async {
      // The standard procedure starts with the four horizontal directions,
      // which barely vary along the laser (x) axis. Until a vertical shot
      // arrives, the x column of G is unconstrained by any measurement and
      // the RMS error reflects that free parameter rather than the shots.
      final data = _syntheticCalibration();
      final horizontalOnly = data.measurements.take(16).toList();

      final partial = await algorithm.compute(horizontalOnly);
      final full = await algorithm.compute(data.measurements);

      // The four horizontal directions alone leave the laser axis flat.
      expect(partial.directionCoverage, lessThan(0.01));
      expect(partial.hasUsefulCoverage, isFalse);

      // The full evenly spread set covers the rotation group completely.
      expect(full.directionCoverage, closeTo(1.0, 0.01));
      expect(full.hasUsefulCoverage, isTrue);

      // Coverage climbs as soon as the vertical directions arrive, which is
      // also where the x column of G stops being determined by noise. It is
      // graded, not a step: two vertical shots reach ~0.56 and the full six
      // cube faces ~1.0.
      final twoVertical =
          await algorithm.compute(data.measurements.take(18).toList());
      expect(twoVertical.directionCoverage, closeTo(0.56, 0.05));
      expect(twoVertical.hasUsefulCoverage, isTrue);

      final sixFaces =
          await algorithm.compute(data.measurements.take(24).toList());
      expect(sixFaces.directionCoverage, closeTo(1.0, 0.01));
    });

    test('the procedure grouping is immune to aiming error on free shots',
        () async {
      // Only the four horizontal directions are grouped (row Ug4 of Heeb's
      // table); the other ten are aimed only to within ±3°. Free shots never
      // use the laser direction, so that scatter does not reach the fit.
      Future<(double, double)> run({required bool procedure}) async {
        final data = _syntheticCalibration(
          procedureGroups: procedure,
          aimingErrorDeg: 3,
          noiseCounts: 20,
        );
        final r = await algorithm.compute(data.measurements);
        var sumSq = 0.0;
        for (int i = 0; i < data.measurements.length; i++) {
          final e = _directionErrorDeg(r.results[i], data.orientations[i]);
          sumSq += e * e;
        }
        return (r.rmsError, math.sqrt(sumSq / data.measurements.length));
      }

      final (procedureQuality, procedureDirection) = await run(procedure: true);
      expect(procedureQuality, lessThan(CalibrationService.errorThreshold));
      expect(procedureDirection, lessThan(0.2));

      // Grouping the roughly aimed directions as well constrains each of
      // them to one laser direction it was never shot in, and the aiming
      // scatter goes straight into the result.
      final (allGroupedQuality, allGroupedDirection) =
          await run(procedure: false);
      expect(allGroupedQuality, greaterThan(CalibrationService.errorThreshold));
      expect(allGroupedDirection, greaterThan(2 * procedureDirection));
    });

    test('rejects a degenerate fit instead of returning it', () async {
      // Randomly assigned groups give the unidirectional constraint nothing
      // consistent to fit, and the iteration heads for the A -> 0 fixed point.
      // That solution reports a flattering RMS error, so it has to be caught
      // here rather than silently written to the device.
      final data = _syntheticCalibration(scrambleGroups: true);

      await expectLater(
        algorithm.compute(data.measurements),
        throwsA(isA<CalibrationException>()),
      );
    });

    test('tolerates sensor noise', () async {
      final data = _syntheticCalibration(noiseCounts: 40);
      final result = await algorithm.compute(data.measurements);

      // 40 counts of noise on a ~16000 count full scale is ~0.25%, which the
      // paper puts at well under a degree of direction error.
      expect(result.rmsError, lessThan(1.0),
          reason: 'RMS error ${result.rmsError} deg');
      for (int i = 0; i < data.measurements.length; i++) {
        if (data.orientations[i].pitch.abs() >= 85) continue;
        expect(_angleDiff(result.results[i].azimuth, data.orientations[i].yaw)
            .abs(),
            lessThan(2.0),
            reason: 'shot $i azimuth');
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

// ===========================================================================
// Ground-truth test data
//
// The device frame is x = forward (laser), y = right, z = down. Equation 2 of
// docs/distox/Calibration.txt gives the exact sensor directions for a device
// at yaw (azimuth) psi, pitch (inclination) theta and roll phi:
//
//   gt = Rx(-phi) o Ry(-theta) o z
//   mt = Rx(-phi) o Ry(-theta) o Rz(-psi) o Ry(alpha) o z
//
// where alpha is the angle between gravity and the magnetic field.
// A synthetic sensor then turns those unit vectors into raw counts via a
// known affine distortion, which the calibration has to undo.
// ===========================================================================

/// Angle between gravity and the magnetic field used by the test data
/// (alpha = 90 - dip; 27 deg is a typical central-European value).
const double _alphaDeg = 27.0;

double _rad(double deg) => deg * math.pi / 180;

Matrix3 _rotX(double w) => matrix3FromRowMajor([
      1, 0, 0, //
      0, math.cos(w), -math.sin(w), //
      0, math.sin(w), math.cos(w), //
    ]);

Matrix3 _rotY(double w) => matrix3FromRowMajor([
      math.cos(w), 0, math.sin(w), //
      0, 1, 0, //
      -math.sin(w), 0, math.cos(w), //
    ]);

Matrix3 _rotZ(double w) => matrix3FromRowMajor([
      math.cos(w), -math.sin(w), 0, //
      math.sin(w), math.cos(w), 0, //
      0, 0, 1, //
    ]);

/// Exact gravity and magnetic field vectors for a device orientation
/// (all angles in degrees), per equation 2.
(Vector3, Vector3) _trueVectors(
  double yaw,
  double pitch,
  double roll,
  double alpha,
) {
  final down = Vector3(0, 0, 1);
  final body = _rotX(-_rad(roll)).multiplied(_rotY(-_rad(pitch)));
  final field = body.multiplied(_rotZ(-_rad(yaw))).multiplied(_rotY(_rad(alpha)));
  return (body.transformVector(down), field.transformVector(down));
}

/// Angle in degrees between the laser direction a calibration reports for a
/// shot and the direction it was actually taken in.
double _directionErrorDeg(CalibrationResult r, _Orientation o) {
  Vector3 unit(double azimuth, double inclination) {
    final a = _rad(azimuth);
    final i = _rad(inclination);
    return Vector3(math.cos(i) * math.cos(a), math.cos(i) * math.sin(a),
        math.sin(i));
  }

  final cos = unit(r.azimuth, r.inclination)
      .dot(unit(o.yaw, o.pitch))
      .clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

/// Difference between two angles in degrees, normalized to [-180, 180].
double _angleDiff(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

class _Orientation {
  final double yaw;
  final double pitch;
  final double roll;
  const _Orientation(this.yaw, this.pitch, this.roll);
}

class _SyntheticCalibration {
  final List<CalibrationMeasurement> measurements;
  final List<_Orientation> orientations;
  const _SyntheticCalibration(this.measurements, this.orientations);
}

/// The 14 directions of the calibration procedure recommended in the paper:
/// the 6 face centres and the 8 vertices of a cube seen from its centre.
const List<(double yaw, double pitch)> _standardDirections = [
  (0, 0), (90, 0), (180, 0), (270, 0), // 4 horizontal
  (0, 90), (0, -90), // straight up / down
  (45, 35.3), (135, 35.3), (225, 35.3), (315, 35.3), // upper vertices
  (45, -35.3), (135, -35.3), (225, -35.3), (315, -35.3), // lower vertices
];

/// 56 measurements (14 directions x 4 roll angles) generated from a known
/// sensor distortion, so the calibration has an exact answer to find.
///
/// [noiseCounts] adds a deterministic pseudo-random perturbation of up to
/// that many raw counts to every sensor axis. [magGain] sets the
/// magnetometer's counts per unit field and [magOffset] its hard-iron offset
/// (the battery), which together decide how far the raw magnetometer sphere
/// sits from the accelerometer's. [scrambleGroups] assigns groups at random,
/// simulating a user who did not shoot the suggested directions.
///
/// [procedureGroups] groups only the four horizontal directions, as the
/// calibration procedure does; otherwise all 14 directions are grouped.
/// [aimingErrorDeg] perturbs the azimuth and inclination of every shot of
/// the ten non-horizontal directions by up to that many degrees, simulating
/// shots that are only roughly aimed; the four horizontal directions stay
/// exact, as if aimed at a target point.
_SyntheticCalibration _syntheticCalibration({
  int noiseCounts = 0,
  double magGain = 15000,
  Vector3? magOffset,
  bool scrambleGroups = false,
  bool procedureGroups = false,
  double aimingErrorDeg = 0,
}) {
  // Sensor model: counts = P o trueVector + q, with gain/skew errors, a
  // slight misalignment between sensors and laser, and a magnetic offset.
  final pG = matrix3FromRowMajor([
    16200, 130, -90, //
    -70, 15850, 210, //
    140, 60, 16050, //
  ]);
  final qG = Vector3(180, -240, 95);
  final pM = matrix3FromRowMajor([
    magGain, -260, 175, //
    310, magGain * 1.03, -120, //
    -85, 195, magGain * 0.97, //
  ]);
  final qM = magOffset ?? Vector3(-620, 410, 730);

  // Deterministic "noise" so failures are reproducible.
  final rng = math.Random(20250831);
  int noise() => noiseCounts == 0
      ? 0
      : (rng.nextDouble() * 2 * noiseCounts - noiseCounts).round();
  final aimRng = math.Random(7);
  double aim() => (aimRng.nextDouble() * 2 - 1) * aimingErrorDeg;

  final measurements = <CalibrationMeasurement>[];
  final orientations = <_Orientation>[];

  int index = 1;
  for (int d = 0; d < _standardDirections.length; d++) {
    final (targetYaw, targetPitch) = _standardDirections[d];
    final precise = d < 4;
    for (int r = 0; r < 4; r++) {
      final yaw = precise || aimingErrorDeg == 0 ? targetYaw : targetYaw + aim();
      final pitch =
          precise || aimingErrorDeg == 0 ? targetPitch : targetPitch + aim();
      final roll = r * 90.0;
      final (gt, mt) = _trueVectors(yaw, pitch, roll, _alphaDeg);
      final gs = pG.transformVector(gt) + qG;
      final ms = pM.transformVector(mt) + qM;

      measurements.add(CalibrationMeasurement(
        gx: gs.x.round() + noise(),
        gy: gs.y.round() + noise(),
        gz: gs.z.round() + noise(),
        mx: ms.x.round() + noise(),
        my: ms.y.round() + noise(),
        mz: ms.z.round() + noise(),
        index: index,
        enabled: true,
        group: scrambleGroups
            ? rng.nextInt(14)
            : procedureGroups
                ? (precise ? d : null)
                : d,
      ));
      orientations.add(_Orientation(yaw, pitch, roll));
      index++;
    }
  }

  return _SyntheticCalibration(measurements, orientations);
}
