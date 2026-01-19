import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../models/calibration.dart';
import '../utils/matrix_helpers.dart';

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

/// Implements Beat Heeb's iterative calibration algorithm.
///
/// This is a Dart port of TopoDroid's CalibAlgoBH.java, which is itself
/// adapted from TopoLinux and PocketTopo implementations.
///
/// References:
/// - B. Heeb, "A general calibration algorithm for 3-axis compass/clino devices"
///   CREG Journal 73
/// - TopoDroid source: github.com/marcocorvi/topodroid
class CalibrationAlgorithm {
  /// Maximum number of optimization iterations.
  static const int maxIterations = 200;

  /// Convergence threshold (stop when matrix change < epsilon).
  static const double epsilon = 1e-6;

  /// Minimum number of measurements required.
  static const int minMeasurements = 16;

  // Intermediate computation results
  Vector3 _gxp = Vector3.zero(); // Optimized G direction
  Vector3 _mxp = Vector3.zero(); // Optimized M direction
  Vector3 _gxt = Vector3.zero(); // Turned G vector
  Vector3 _mxt = Vector3.zero(); // Turned M vector

  /// Compute calibration coefficients from measurements.
  ///
  /// Throws [CalibrationException] if there are insufficient measurements
  /// or the algorithm fails to converge.
  Future<CalibrationOutput> compute(
    List<CalibrationMeasurement> measurements,
  ) async {
    // Filter to enabled measurements only
    final data = measurements.where((m) => m.enabled).toList();
    final nn = data.length;

    if (nn < minMeasurements) {
      throw CalibrationException(
        'Need at least $minMeasurements measurements, got $nn',
      );
    }

    // Extract raw vectors and group IDs
    final g = data.map((m) => m.gVector).toList();
    final m = data.map((m) => m.mVector).toList();
    final group = data.map((m) => m.group != null ? int.parse(m.group!) + 1 : 0).toList();

    // Run optimization
    final result = _optimize(nn, g, m, group);

    // Compute per-measurement errors
    final results = _computeResults(data, result.aG, result.bG, result.aM, result.bM);

    // Compute RMS error in degrees
    final rmsError = results.isEmpty
        ? 0.0
        : math.sqrt(
            results.map((r) => r.error * r.error).reduce((a, b) => a + b) /
                results.length,
          );

    return CalibrationOutput(
      coefficients: CalibrationCoefficients(
        aG: result.aG,
        bG: result.bG,
        aM: result.aM,
        bM: result.bM,
      ),
      results: results,
      rmsError: rmsError,
      iterations: result.iterations,
    );
  }

  /// Main optimization loop - port of TopoDroid's Optimize method.
  _OptimizeResult _optimize(
    int nn,
    List<Vector3> g,
    List<Vector3> m,
    List<int> group,
  ) {
    // Working arrays
    final gr = List<Vector3>.filled(nn, Vector3.zero());
    final mr = List<Vector3>.filled(nn, Vector3.zero());
    final gx = List<Vector3>.filled(nn, Vector3.zero());
    final mx = List<Vector3>.filled(nn, Vector3.zero());

    // Compute sums for initialization
    var sumG = Vector3.zero();
    var sumM = Vector3.zero();
    var sumG2 = Matrix3.zero();
    var sumM2 = Matrix3.zero();
    double sa = 0.0;
    double ca = 0.0;
    double invNum = 0.0;

    for (int i = 0; i < nn; i++) {
      if (group[i] > 0) {
        invNum += 1.0;
        // Cross product length (sin of angle) and dot product (cos of angle)
        sa += g[i].cross(m[i]).magnitude;
        ca += g[i].dot(m[i]);
        sumG = sumG + g[i];
        sumM = sumM + m[i];
        sumG2 = sumG2 + _outerProduct(g[i], g[i]);
        sumM2 = sumM2 + _outerProduct(m[i], m[i]);
      }
    }

    if (invNum < 0.5) {
      throw CalibrationException('No valid measurements with groups');
    }

    invNum = 1.0 / invNum;

    // Compute averages and inverse covariance matrices
    final avG = sumG * invNum;
    final avM = sumM * invNum;
    final invG = (sumG2 - _outerProduct(sumG, avG)).inverse;
    final invM = (sumM2 - _outerProduct(sumM, avM)).inverse;

    // Initialize transforms (identity A, zero B for linear algorithm)
    var aG = Matrix3.identity();
    var aM = Matrix3.identity();
    var bG = Vector3.zero();
    var bM = Vector3.zero();

    // Compute initial sin/cos of dip angle
    double da = math.sqrt(ca * ca + sa * sa);
    double s = sa / da;
    double c = ca / da;

    int it = 0;
    Matrix3 aG0, aM0;

    do {
      // Transform all raw measurements
      for (int i = 0; i < nn; i++) {
        if (group[i] > 0) {
          gr[i] = bG + aG.transform(g[i]);
          mr[i] = bM + aM.transform(m[i]);
        }
      }

      // Process groups
      sa = 0.0;
      ca = 0.0;
      int group0 = -1;

      for (int i = 0; i < nn;) {
        if (group[i] <= 0) {
          i++;
        } else if (group[i] != group0) {
          group0 = group[i];
          var grp = Vector3.zero();
          var mrp = Vector3.zero();
          int first = i;

          // Sum up all measurements in this group
          while (i < nn && (group[i] <= 0 || group[i] == group0)) {
            if (group[i] > 0) {
              _turnVectors(gr[i], mr[i], gr[first], mr[first]);
              grp = grp + _gxt;
              mrp = mrp + _mxt;
            }
            i++;
          }

          // Compute optimal vectors for this group
          _optVectors(grp, mrp, s, c);

          // Accumulate sin/cos for dip angle update
          sa += mrp.cross(_gxp).magnitude;
          ca += mrp.dot(_gxp);

          // Turn optimal vectors back to each measurement
          for (int j = first; j < i; j++) {
            if (group[j] > 0) {
              _turnVectors(_gxp, _mxp, gr[j], mr[j]);
              gx[j] = _gxt;
              mx[j] = _mxt;
            }
          }
        }
      }

      // Update sin/cos
      da = math.sqrt(ca * ca + sa * sa);
      s = sa / da;
      c = ca / da;

      // Compute new transforms using least squares
      var avGx = Vector3.zero();
      var avMx = Vector3.zero();
      var sumGxG = Matrix3.zero();
      var sumMxM = Matrix3.zero();

      for (int i = 0; i < nn; i++) {
        if (group[i] > 0) {
          avGx = avGx + gx[i];
          avMx = avMx + mx[i];
          sumGxG = sumGxG + _outerProduct(gx[i], g[i]);
          sumMxM = sumMxM + _outerProduct(mx[i], m[i]);
        }
      }

      // Save old matrices for convergence check
      aG0 = aG;
      aM0 = aM;

      avGx = avGx * invNum;
      avMx = avMx * invNum;

      // Update A matrices: A = (sumXxR - outer(avX, sumR)) * invR^T
      aG = (sumGxG - _outerProduct(avGx, sumG)).multiplyTransposed(invG);
      aM = (sumMxM - _outerProduct(avMx, sumM)).multiplyTransposed(invM);

      // Enforce symmetric aG[1,2] = aG[2,1] (y.z = z.y)
      final sym = (aG.get(1, 2) + aG.get(2, 1)) * 0.5;
      aG = aG.withElement(1, 2, sym).withElement(2, 1, sym);

      // Update B vectors
      bG = avGx - aG.transform(avG);
      bM = avMx - aM.transform(avM);

      it++;
    } while (it < maxIterations && (_maxDiff(aG, aG0) > epsilon || _maxDiff(aM, aM0) > epsilon));

    return _OptimizeResult(
      aG: aG,
      bG: bG,
      aM: aM,
      bM: bM,
      iterations: it,
      s: s,
      c: c,
    );
  }

  /// Compute optimal direction vectors (port of OptVectors).
  ///
  /// Given summed G and M vectors from a group, compute the optimal
  /// unit direction vectors that satisfy the dip angle constraint.
  void _optVectors(Vector3 gr, Vector3 mr, double s, double c) {
    var no = gr.cross(mr);
    no = no.length > 0 ? no.normalized() : Vector3(0, 0, 1);

    // gxp = normalize(mr * c + (mr x no) * s + gr)
    _gxp = (mr * c) + (mr.cross(no) * s) + gr;
    _gxp = _gxp.length > 0 ? _gxp.normalized() : Vector3(1, 0, 0);

    // mxp = gxp * c + (no x gxp) * s
    _mxp = (_gxp * c) + (no.cross(_gxp) * s);
  }

  /// Turn vectors around X axis to align with reference (port of TurnVectors).
  ///
  /// Rotates (gf, mf) around X axis to best align with (gr, mr).
  void _turnVectors(Vector3 gf, Vector3 mf, Vector3 gr, Vector3 mr) {
    // Compute rotation angle
    final s1Raw = gr.z * gf.y - gr.y * gf.z + mr.z * mf.y - mr.y * mf.z;
    final c1Raw = gr.y * gf.y + gr.z * gf.z + mr.y * mf.y + mr.z * mf.z;
    final d1 = math.sqrt(c1Raw * c1Raw + s1Raw * s1Raw);

    if (d1 < 1e-10) {
      _gxt = gf;
      _mxt = mf;
      return;
    }

    final s1 = s1Raw / d1;
    final c1 = c1Raw / d1;

    // Apply rotation around X axis
    _gxt = _turnX(gf, s1, c1);
    _mxt = _turnX(mf, s1, c1);
  }

  /// Rotate vector around X axis.
  Vector3 _turnX(Vector3 v, double s, double c) {
    return Vector3(v.x, c * v.y - s * v.z, c * v.z + s * v.y);
  }

  /// Compute outer product of two vectors.
  Matrix3 _outerProduct(Vector3 a, Vector3 b) {
    return matrix3FromRowMajor([
      a.x * b.x, a.x * b.y, a.x * b.z,
      a.y * b.x, a.y * b.y, a.y * b.z,
      a.z * b.x, a.z * b.y, a.z * b.z,
    ]);
  }

  /// Compute maximum element-wise difference between matrices.
  double _maxDiff(Matrix3 a, Matrix3 b) {
    double maxD = 0;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final d = (a.get(i, j) - b.get(i, j)).abs();
        if (d > maxD) maxD = d;
      }
    }
    return maxD;
  }

  /// Compute bearing and clino from calibrated G and M vectors.
  /// Returns (bearing, clino) in radians.
  (double, double) _computeBearingClino(Vector3 g, Vector3 m) {
    final gNorm = g.normalized();
    final mNorm = m.normalized();

    // Clino (inclination) from G - angle from horizontal
    final clino = math.asin(-gNorm.z.clamp(-1.0, 1.0));

    // Project M onto horizontal plane perpendicular to G for bearing
    final mHoriz = mNorm - gNorm * mNorm.dot(gNorm);
    if (mHoriz.length < 0.001) {
      // Device is vertical, bearing is undefined
      return (0.0, clino);
    }
    final mHorizNorm = mHoriz.normalized();

    // Compute bearing using local reference frame
    final up = Vector3(0, 0, 1);
    var east = gNorm.cross(up);
    if (east.length < 0.01) {
      east = Vector3(1, 0, 0);
    }
    east = east.normalized();
    final north = up.cross(east).normalized();

    final mEast = mHorizNorm.dot(east);
    final mNorth = mHorizNorm.dot(north);
    final bearing = math.atan2(mEast, mNorth);

    return (bearing, clino);
  }

  /// Compute per-measurement results.
  /// Error is computed as direction difference within groups (TopoDroid method).
  List<CalibrationResult> _computeResults(
    List<CalibrationMeasurement> data,
    Matrix3 aG,
    Vector3 bG,
    Matrix3 aM,
    Vector3 bM,
  ) {
    final nn = data.length;

    // First pass: compute calibrated vectors and directions for all measurements
    final calibratedG = <Vector3>[];
    final calibratedM = <Vector3>[];
    final bearings = <double>[];
    final clinos = <double>[];

    for (final m in data) {
      final g = aG.transform(m.gVector) + bG;
      final mag = aM.transform(m.mVector) + bM;
      calibratedG.add(g);
      calibratedM.add(mag);

      final (bearing, clino) = _computeBearingClino(g, mag);
      bearings.add(bearing);
      clinos.add(clino);
    }

    // Second pass: compute group reference directions and errors
    // Group measurements by their group ID
    final groupIndices = <int, List<int>>{};
    for (int i = 0; i < nn; i++) {
      final groupStr = data[i].group;
      if (groupStr != null) {
        final groupId = int.tryParse(groupStr) ?? -1;
        if (groupId >= 0) {
          groupIndices.putIfAbsent(groupId, () => []).add(i);
        }
      }
    }

    // Compute reference direction for each group (average of measurements)
    final groupRefBearing = <int, double>{};
    final groupRefClino = <int, double>{};

    for (final entry in groupIndices.entries) {
      final indices = entry.value;
      if (indices.isEmpty) continue;

      // Average bearing needs special handling for angle wraparound
      double sumSin = 0, sumCos = 0, sumClino = 0;
      for (final i in indices) {
        sumSin += math.sin(bearings[i]);
        sumCos += math.cos(bearings[i]);
        sumClino += clinos[i];
      }
      groupRefBearing[entry.key] = math.atan2(sumSin, sumCos);
      groupRefClino[entry.key] = sumClino / indices.length;
    }

    // Third pass: compute errors and build results
    final errors = List<double>.filled(nn, 0.0);

    for (final entry in groupIndices.entries) {
      final groupId = entry.key;
      final indices = entry.value;
      final refB = groupRefBearing[groupId] ?? 0.0;
      final refC = groupRefClino[groupId] ?? 0.0;

      for (final i in indices) {
        // Error = length of direction difference vector
        // This approximates the angle: error ≈ 2*tan(angle/2) for small angles
        var dBearing = bearings[i] - refB;
        // Normalize bearing difference to [-pi, pi]
        while (dBearing > math.pi) {
          dBearing -= 2 * math.pi;
        }
        while (dBearing < -math.pi) {
          dBearing += 2 * math.pi;
        }

        final dClino = clinos[i] - refC;

        // Error as Euclidean distance in (bearing, clino) space
        errors[i] = math.sqrt(dBearing * dBearing + dClino * dClino);
      }
    }

    // Build results
    final results = <CalibrationResult>[];

    for (int i = 0; i < nn; i++) {
      final g = calibratedG[i];
      final mag = calibratedM[i];

      final gMag = g.magnitude;
      final mMag = mag.magnitude;
      final alpha = g.angleTo(mag);

      // Convert bearing/clino to degrees for output
      var azimuth = bearings[i] * 180 / math.pi;
      if (azimuth < 0) azimuth += 360;
      final inclination = clinos[i] * 180 / math.pi;

      // Roll from G
      final gNorm = g.normalized();
      final roll = math.atan2(gNorm.y, -gNorm.x) * 180 / math.pi;

      results.add(CalibrationResult(
        error: errors[i] * 180 / math.pi, // Convert to degrees
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

/// Internal result from optimization.
class _OptimizeResult {
  final Matrix3 aG;
  final Vector3 bG;
  final Matrix3 aM;
  final Vector3 bM;
  final int iterations;
  final double s; // sin of dip angle
  final double c; // cos of dip angle

  _OptimizeResult({
    required this.aG,
    required this.bG,
    required this.aM,
    required this.bM,
    required this.iterations,
    required this.s,
    required this.c,
  });
}
