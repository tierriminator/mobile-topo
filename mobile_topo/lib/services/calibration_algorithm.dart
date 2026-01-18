import 'dart:math' as math;

import '../models/calibration.dart';
import '../utils/linear_algebra.dart';

/// Exception thrown when calibration computation fails.
class CalibrationException implements Exception {
  final String message;
  CalibrationException(this.message);

  @override
  String toString() => 'CalibrationException: $message';
}

/// Output from calibration computation.
class CalibrationOutput {
  final CalibrationCoefficients coefficients;
  final List<CalibrationResult> results;
  final double rmsError;
  final int iterations;

  const CalibrationOutput({
    required this.coefficients,
    required this.results,
    required this.rmsError,
    required this.iterations,
  });
}

/// Implements Beat Heeb's iterative least-squares calibration algorithm.
///
/// The algorithm works by:
/// 1. Starting with identity transforms
/// 2. Iteratively updating transforms to minimize error
/// 3. Using group constraints to align same-direction measurements
///
/// References:
/// - PocketTopo source code
/// - TopoDroid CalibAlgo.java
/// - InsideDistoX2.txt documentation
class CalibrationAlgorithm {
  /// Maximum number of optimization iterations.
  static const int maxIterations = 200;

  /// Convergence threshold (stop when change < epsilon).
  static const double epsilon = 1e-7;

  /// Minimum number of measurements required.
  static const int minMeasurements = 16;

  /// Compute calibration coefficients from measurements.
  ///
  /// Throws [CalibrationException] if there are insufficient measurements
  /// or the algorithm fails to converge.
  Future<CalibrationOutput> compute(
    List<CalibrationMeasurement> measurements,
  ) async {
    // Filter to enabled measurements only
    final data = measurements.where((m) => m.enabled).toList();
    if (data.length < minMeasurements) {
      throw CalibrationException(
        'Need at least $minMeasurements measurements, got ${data.length}',
      );
    }

    // Initialize transforms
    var aG = Matrix3.identity();
    var bG = Vector3.zero;
    var aM = Matrix3.identity();
    var bM = Vector3.zero;

    // Compute initial scale factors to normalize vectors
    final gScale = _computeScaleFactor(data.map((m) => m.gVector).toList());
    final mScale = _computeScaleFactor(data.map((m) => m.mVector).toList());

    // Apply initial scaling
    aG = aG * (1.0 / gScale);
    aM = aM * (1.0 / mScale);

    int iterations = 0;
    double prevError = double.infinity;

    while (iterations < maxIterations) {
      iterations++;

      // Step 1: Transform all raw measurements
      final transformed = data.map((m) {
        final g = aG.transform(m.gVector) + bG;
        final rawM = aM.transform(m.mVector) + bM;
        return _TransformedMeasurement(
          g: g,
          m: rawM,
          raw: m,
        );
      }).toList();

      // Step 2: Compute group constraints
      // Measurements in the same group should have the same direction
      final groupMeanG = <String, Vector3>{};
      final groupMeanM = <String, Vector3>{};
      final groupCounts = <String, int>{};

      for (final t in transformed) {
        final group = t.raw.group;
        if (group == null) continue;

        final gNorm = t.g.normalized;
        final mNorm = t.m.normalized;

        groupMeanG[group] = (groupMeanG[group] ?? Vector3.zero) + gNorm;
        groupMeanM[group] = (groupMeanM[group] ?? Vector3.zero) + mNorm;
        groupCounts[group] = (groupCounts[group] ?? 0) + 1;
      }

      // Normalize group means
      for (final group in groupMeanG.keys) {
        final count = groupCounts[group]!;
        if (count > 0) {
          groupMeanG[group] = groupMeanG[group]!.normalized;
          groupMeanM[group] = groupMeanM[group]!.normalized;
        }
      }

      // Step 3: Compute optimal transforms using least-squares
      // For each sensor (G and M), solve:
      //   min sum ||A * raw_i + B - target_i||^2
      //
      // Target is:
      //   - For grouped measurements: the group mean direction, scaled to |target| = 1
      //   - For ungrouped: the normalized current transformed value

      final gRaw = <Vector3>[];
      final gTarget = <Vector3>[];
      final mRaw = <Vector3>[];
      final mTarget = <Vector3>[];

      for (final t in transformed) {
        final group = t.raw.group;

        // G targets
        if (group != null && groupMeanG.containsKey(group)) {
          gTarget.add(groupMeanG[group]!);
        } else {
          gTarget.add(t.g.normalized);
        }
        gRaw.add(t.raw.gVector);

        // M targets
        if (group != null && groupMeanM.containsKey(group)) {
          mTarget.add(groupMeanM[group]!);
        } else {
          mTarget.add(t.m.normalized);
        }
        mRaw.add(t.raw.mVector);
      }

      // Solve for new transforms
      final (newAG, newBG) = _solveTransform(gRaw, gTarget);
      final (newAM, newBM) = _solveTransform(mRaw, mTarget);

      // Update transforms
      aG = newAG;
      bG = newBG;
      aM = newAM;
      bM = newBM;

      // Step 4: Compute error
      final error = _computeRmsError(
        data,
        aG,
        bG,
        aM,
        bM,
        groupMeanG,
        groupMeanM,
      );

      // Check convergence
      if ((prevError - error).abs() < epsilon) {
        break;
      }
      prevError = error;
    }

    // Compute per-measurement results
    final results = _computeResults(data, aG, bG, aM, bM);

    // Final RMS error in degrees
    final rmsError = results.isEmpty
        ? 0.0
        : math.sqrt(
            results.map((r) => r.error * r.error).reduce((a, b) => a + b) /
                results.length,
          );

    return CalibrationOutput(
      coefficients: CalibrationCoefficients(
        aG: aG,
        bG: bG,
        aM: aM,
        bM: bM,
      ),
      results: results,
      rmsError: rmsError,
      iterations: iterations,
    );
  }

  /// Compute scale factor as average magnitude of vectors.
  double _computeScaleFactor(List<Vector3> vectors) {
    if (vectors.isEmpty) return 1.0;
    final sum = vectors.map((v) => v.magnitude).reduce((a, b) => a + b);
    return sum / vectors.length;
  }

  /// Solve for transform (A, B) that minimizes ||A * raw + B - target||^2.
  ///
  /// Uses least-squares solution with SVD-free approach.
  (Matrix3, Vector3) _solveTransform(
    List<Vector3> raw,
    List<Vector3> target,
  ) {
    final n = raw.length;
    if (n == 0) {
      return (Matrix3.identity(), Vector3.zero);
    }

    // Compute means
    var rawMean = Vector3.zero;
    var targetMean = Vector3.zero;
    for (int i = 0; i < n; i++) {
      rawMean = rawMean + raw[i];
      targetMean = targetMean + target[i];
    }
    rawMean = rawMean / n.toDouble();
    targetMean = targetMean / n.toDouble();

    // Center the data
    final rawCentered = raw.map((v) => v - rawMean).toList();
    final targetCentered = target.map((v) => v - targetMean).toList();

    // Compute covariance matrices
    // C = sum(target_i * raw_i^T) / n
    // R = sum(raw_i * raw_i^T) / n
    var c = Matrix3.zero();
    var r = Matrix3.zero();

    for (int i = 0; i < n; i++) {
      final t = targetCentered[i];
      final s = rawCentered[i];

      // Outer product: target * raw^T
      c = c + _outerProduct(t, s);

      // Outer product: raw * raw^T
      r = r + _outerProduct(s, s);
    }

    // Add regularization to avoid singular matrix
    const reg = 1e-6;
    r = r + Matrix3.identity() * reg;

    // A = C * R^(-1)
    Matrix3 a;
    try {
      final rInv = r.inverse;
      a = c.multiply(rInv);
    } catch (_) {
      // If matrix is singular, return identity
      a = Matrix3.identity();
    }

    // B = targetMean - A * rawMean
    final b = targetMean - a.transform(rawMean);

    return (a, b);
  }

  /// Compute outer product of two vectors.
  Matrix3 _outerProduct(Vector3 a, Vector3 b) {
    return Matrix3([
      a.x * b.x, a.x * b.y, a.x * b.z,
      a.y * b.x, a.y * b.y, a.y * b.z,
      a.z * b.x, a.z * b.y, a.z * b.z,
    ]);
  }

  /// Compute RMS error of current calibration.
  double _computeRmsError(
    List<CalibrationMeasurement> data,
    Matrix3 aG,
    Vector3 bG,
    Matrix3 aM,
    Vector3 bM,
    Map<String, Vector3> groupMeanG,
    Map<String, Vector3> groupMeanM,
  ) {
    if (data.isEmpty) return 0.0;

    double sumSq = 0.0;
    int count = 0;

    for (final m in data) {
      final g = (aG.transform(m.gVector) + bG).normalized;
      final mag = (aM.transform(m.mVector) + bM).normalized;

      // Error is angular difference from group mean (if grouped) or from unit sphere
      final group = m.group;
      double gError, mError;

      if (group != null && groupMeanG.containsKey(group)) {
        gError = g.angleTo(groupMeanG[group]!);
        mError = mag.angleTo(groupMeanM[group]!);
      } else {
        // For ungrouped, error is deviation from unit magnitude
        gError = (g.magnitude - 1.0).abs();
        mError = (mag.magnitude - 1.0).abs();
      }

      sumSq += gError * gError + mError * mError;
      count += 2;
    }

    return count > 0 ? math.sqrt(sumSq / count) : 0.0;
  }

  /// Compute per-measurement results.
  List<CalibrationResult> _computeResults(
    List<CalibrationMeasurement> data,
    Matrix3 aG,
    Vector3 bG,
    Matrix3 aM,
    Vector3 bM,
  ) {
    // First pass: compute mean alpha (dip angle) for consistency check
    double alphaSum = 0;
    for (final m in data) {
      final g = aG.transform(m.gVector) + bG;
      final mag = aM.transform(m.mVector) + bM;
      final alpha = g.angleTo(mag);
      alphaSum += alpha;
    }
    final meanAlpha = data.isNotEmpty ? alphaSum / data.length : 0.0;

    // Second pass: compute full results
    final results = <CalibrationResult>[];

    for (final m in data) {
      final g = aG.transform(m.gVector) + bG;
      final mag = aM.transform(m.mVector) + bM;

      final gMag = g.magnitude;
      final mMag = mag.magnitude;
      final alpha = g.angleTo(mag);

      // Error estimate: deviation of alpha from mean, plus magnitude deviations
      final alphaError = (alpha - meanAlpha).abs();
      final gMagError = (gMag - 1.0).abs();
      final mMagError = (mMag - 1.0).abs();

      // Combined error (in radians, will be converted to degrees)
      final error = math.sqrt(
        alphaError * alphaError +
            gMagError * gMagError +
            mMagError * mMagError,
      );

      // Compute angles
      final gNorm = g.normalized;
      final mNorm = mag.normalized;

      // Inclination from G
      final inclination = math.asin(-gNorm.z) * 180 / math.pi;

      // For azimuth, project M onto horizontal plane
      final mHoriz = mNorm - gNorm * mNorm.dot(gNorm);
      final mHorizNorm = mHoriz.magnitude > 0.01 ? mHoriz.normalized : mNorm;

      // Use cross product to get east direction
      const up = Vector3(0, 0, 1);
      var east = gNorm.cross(up);
      if (east.magnitude < 0.01) {
        east = const Vector3(1, 0, 0);
      }
      east = east.normalized;
      final north = up.cross(east).normalized;

      final mEast = mHorizNorm.dot(east);
      final mNorth = mHorizNorm.dot(north);
      var azimuth = math.atan2(mEast, mNorth) * 180 / math.pi;
      if (azimuth < 0) azimuth += 360;

      // Roll
      final roll = math.atan2(gNorm.y, -gNorm.x) * 180 / math.pi;

      results.add(CalibrationResult(
        error: error * 180 / math.pi, // Convert to degrees
        gMagnitude: gMag,
        mMagnitude: mMag,
        alpha: alpha * 180 / math.pi,
        azimuth: azimuth,
        inclination: inclination,
        roll: roll,
      ));
    }

    return results;
  }
}

/// Internal class for transformed measurement during iteration.
class _TransformedMeasurement {
  final Vector3 g;
  final Vector3 m;
  final CalibrationMeasurement raw;

  _TransformedMeasurement({
    required this.g,
    required this.m,
    required this.raw,
  });
}
