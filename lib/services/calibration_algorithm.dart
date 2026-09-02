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

  /// One entry per *enabled* input measurement, in input order.
  final List<CalibrationResult> results;

  /// RMS of the per-measurement errors, in degrees.
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
/// This follows the pseudo code in appendix B of
/// B. Heeb, "A general calibration algorithm for 3-axis compass/clino
/// devices", CREG Journal 73 (a text copy lives in
/// `docs/distox/Calibration.txt`). Equation numbers in the comments below
/// refer to that paper.
///
/// The device coordinate system is x = forward (laser beam), y = right,
/// z = down. The calibration function is
///
///   gr = G o gs + gd     mr = M o ms + md      (eq. 1)
///
/// where `gs`/`ms` are the raw sensor readings scaled by
/// [CalibrationCoefficients.rawUnit] and `gr`/`mr` come out as (roughly)
/// unit vectors.
class CalibrationAlgorithm {
  /// Maximum number of optimization iterations.
  static const int maxIterations = 200;

  /// Convergence threshold on the max norm of the change in G and M.
  static const double epsilon = 1e-6;

  /// Minimum number of measurements required.
  static const int minMeasurements = 16;

  static const double _radToDeg = 180.0 / math.pi;

  /// Compute calibration coefficients from measurements.
  ///
  /// Disabled measurements are skipped. Measurements that share a group id
  /// form a unidirectional group; measurements without a group are treated as
  /// free measurements, i.e. single-measurement groups (see the paper,
  /// "The Main Iteration", remarks).
  ///
  /// Throws [CalibrationException] if there are insufficient measurements.
  Future<CalibrationOutput> compute(
    List<CalibrationMeasurement> measurements,
  ) async {
    // Input order is preserved: callers map the results back onto the enabled
    // measurements positionally.
    final data = measurements.where((m) => m.enabled).toList();
    final nn = data.length;

    if (nn < minMeasurements) {
      throw CalibrationException(
        'Need at least $minMeasurements measurements, got $nn',
      );
    }

    // Raw 16-bit sensor counts are scaled into the unit system used by the
    // device firmware and by the coefficient byte layout, so that the
    // resulting G/M matrices come out around 1 rather than around 1/16000
    // (which would quantize to 0 or 1 when serialized with FM = 16384).
    const unit = CalibrationCoefficients.rawUnit;
    final gs = [for (final d in data) d.gVector * unit];
    final ms = [for (final d in data) d.mVector * unit];

    final result = _optimize(gs, ms, _buildGroups(data));
    final results = _buildResults(result);

    final rmsError = results.isEmpty
        ? 0.0
        : math.sqrt(
            results.map((r) => r.error * r.error).reduce((a, b) => a + b) /
                results.length,
          );

    return CalibrationOutput(
      coefficients: CalibrationCoefficients(
        aG: result.g,
        bG: result.gd,
        aM: result.m,
        bM: result.md,
      ),
      results: results,
      rmsError: rmsError,
      iterations: result.iterations,
    );
  }

  /// Partition measurement indices into unidirectional groups.
  ///
  /// Measurements sharing a group id end up in one group even when they are
  /// not adjacent in the list. Ungrouped measurements become their own
  /// single-measurement group, which is exactly how the paper handles free
  /// measurements.
  List<List<int>> _buildGroups(List<CalibrationMeasurement> data) {
    final byId = <int, List<int>>{};
    final groups = <List<int>>[];
    for (int i = 0; i < data.length; i++) {
      final id = data[i].group;
      if (id == null) {
        groups.add([i]);
        continue;
      }
      final existing = byId[id];
      if (existing != null) {
        existing.add(i);
      } else {
        final created = <int>[i];
        byId[id] = created;
        groups.add(created);
      }
    }
    return groups;
  }

  /// Main iteration (appendix B, `Calibrate`).
  _OptimizeResult _optimize(
    List<Vector3> gs,
    List<Vector3> ms,
    List<List<int>> groups,
  ) {
    final nn = gs.length;
    final invN = 1.0 / nn;

    // Sums that depend on the sensor values only, so they are computed once.
    var sumGs = Vector3.zero();
    var sumMs = Vector3.zero();
    var sumGs2 = Matrix3.zero();
    var sumMs2 = Matrix3.zero();
    double sa = 0.0;
    double ca = 0.0;

    for (int i = 0; i < nn; i++) {
      sa += gs[i].cross(ms[i]).length; // sum up sine of angle
      ca += gs[i].dot(ms[i]); // sum up cosine of angle
      sumGs += gs[i];
      sumMs += ms[i];
      sumGs2 += _outer(gs[i], gs[i]);
      sumMs2 += _outer(ms[i], ms[i]);
    }

    final avGs = sumGs * invN;
    final avMs = sumMs * invN;
    // Note: `Matrix3.operator*` is declared to return `dynamic`, and extension
    // members do not resolve on `dynamic`. Use the explicitly typed
    // `scaled`/`multiplied` instead.
    final gi = (sumGs2.scaled(invN) - _outer(avGs, avGs)).inverse;
    final mi = (sumMs2.scaled(invN) - _outer(avMs, avMs)).inverse;

    // First estimate of alpha, the angle between the gravity and the magnetic
    // field vector. Kept as sin/cos so no arctan/sincos round trip is needed.
    var (sinA, cosA) = _normalizeSinCos(sa, ca);

    var g = Matrix3.identity();
    var m = Matrix3.identity();
    var gd = Vector3.zero();
    var md = Vector3.zero();

    final gr = List<Vector3>.generate(nn, (_) => Vector3.zero());
    final mr = List<Vector3>.generate(nn, (_) => Vector3.zero());
    final gt = List<Vector3>.generate(nn, (_) => Vector3.zero());
    final mt = List<Vector3>.generate(nn, (_) => Vector3.zero());

    int it = 0;
    double change = double.infinity;

    while (it < maxIterations && change > epsilon) {
      // 3) result vectors from the current coefficients (eq. 1)
      for (int i = 0; i < nn; i++) {
        gr[i] = g.transformVector(gs[i]) + gd;
        mr[i] = m.transformVector(ms[i]) + md;
      }

      // 4) + 5) true vectors per group, and a fresh estimate of alpha
      (sinA, cosA) = _fitTrueVectors(groups, gr, mr, gt, mt, sinA, cosA);

      // 6) new coefficients by least squares (eq. 6)
      var avGt = Vector3.zero();
      var avMt = Vector3.zero();
      var avGtGs = Matrix3.zero();
      var avMtMs = Matrix3.zero();
      for (int i = 0; i < nn; i++) {
        avGt += gt[i];
        avMt += mt[i];
        avGtGs += _outer(gt[i], gs[i]);
        avMtMs += _outer(mt[i], ms[i]);
      }
      avGt *= invN;
      avMt *= invN;
      avGtGs = avGtGs.scaled(invN);
      avMtMs = avMtMs.scaled(invN);

      final oldG = g;
      final oldM = m;
      g = (avGtGs - _outer(avGt, avGs)).multiplied(gi);
      m = (avMtMs - _outer(avMt, avMs)).multiplied(mi);

      // 7) resolve the roll angle ambiguity by enforcing G_yz == G_zy
      final sym = 0.5 * (g.entry(1, 2) + g.entry(2, 1));
      g.setEntry(1, 2, sym);
      g.setEntry(2, 1, sym);

      gd = avGt - g.transformVector(avGs);
      md = avMt - m.transformVector(avMs);

      change = math.max(_maxDiff(g, oldG), _maxDiff(m, oldM));
      it++;
    }

    // The loop updated the coefficients after computing gr/mr/gt/mt, so refresh
    // them once with the converged values before the errors are derived.
    for (int i = 0; i < nn; i++) {
      gr[i] = g.transformVector(gs[i]) + gd;
      mr[i] = m.transformVector(ms[i]) + md;
    }
    _fitTrueVectors(groups, gr, mr, gt, mt, sinA, cosA);

    return _OptimizeResult(
      g: g,
      gd: gd,
      m: m,
      md: md,
      iterations: it,
      gr: gr,
      mr: mr,
      gt: gt,
      mt: mt,
    );
  }

  /// Steps 4 and 5 of the main iteration: derive the fitted ("true") vectors
  /// `gt`/`mt` for every measurement from the current result vectors `gr`/`mr`,
  /// and return the refreshed sin/cos of alpha.
  ///
  /// `gt` and `mt` are written in place.
  (double, double) _fitTrueVectors(
    List<List<int>> groups,
    List<Vector3> gr,
    List<Vector3> mr,
    List<Vector3> gt,
    List<Vector3> mt,
    double sinA,
    double cosA,
  ) {
    double sa = 0.0;
    double ca = 0.0;

    for (final group in groups) {
      final first = group.first;
      var gc = Vector3.zero();
      var mc = Vector3.zero();

      // Adapt every measurement of the group to the roll angle of the group's
      // first measurement (eq. 15).
      for (final i in group) {
        final (ga, ma) = _adaptPhi(gr[i], mr[i], gr[first], mr[first]);
        gc += ga;
        mc += ma;
      }

      // Direction of the group (eq. 16).
      final (gp, mp) = _trueVectors(gc, mc, sinA, cosA);

      sa += mc.cross(gp).length;
      ca += mc.dot(gp);

      // Turn the group direction back onto each individual roll angle
      // (eq. 14 combined with eq. 9).
      for (final i in group) {
        final (ti, si) = _adaptPhi(gp, mp, gr[i], mr[i]);
        gt[i] = ti;
        mt[i] = si;
      }
    }

    return _normalizeSinCos(sa, ca);
  }

  /// Estimated true vectors for a pair of result vectors (eq. 12 / 16,
  /// appendix B `GetTrueVectors`).
  (Vector3, Vector3) _trueVectors(
    Vector3 gr,
    Vector3 mr,
    double sinA,
    double cosA,
  ) {
    var no = gr.cross(mr);
    no = no.length > 0 ? no.normalized() : Vector3(0, 0, 1);

    var gt = gr + mr * cosA + mr.cross(no) * sinA;
    gt = gt.length > 0 ? gt.normalized() : Vector3(1, 0, 0);

    final mt = gt * cosA + no.cross(gt) * sinA;
    return (gt, mt);
  }

  /// Turn `ga`/`ma` to the roll angle of `gb`/`mb` (eq. 9, appendix B
  /// `AdaptPhi`). The rotation is around the x axis, so the laser direction
  /// is untouched.
  (Vector3, Vector3) _adaptPhi(
    Vector3 ga,
    Vector3 ma,
    Vector3 gb,
    Vector3 mb,
  ) {
    final s = ga.y * gb.z - ga.z * gb.y + ma.y * mb.z - ma.z * mb.y;
    final c = ga.y * gb.y + ga.z * gb.z + ma.y * mb.y + ma.z * mb.z;
    final d = math.sqrt(s * s + c * c);
    if (d < 1e-12) return (ga, ma);
    return (_turnX(ga, s / d, c / d), _turnX(ma, s / d, c / d));
  }

  /// Rotate a vector around the x axis by the angle given as sin/cos.
  Vector3 _turnX(Vector3 v, double s, double c) =>
      Vector3(v.x, c * v.y - s * v.z, c * v.z + s * v.y);

  /// Outer (Kronecker) product of two vectors.
  Matrix3 _outer(Vector3 a, Vector3 b) => matrix3FromRowMajor([
        a.x * b.x, a.x * b.y, a.x * b.z, //
        a.y * b.x, a.y * b.y, a.y * b.z, //
        a.z * b.x, a.z * b.y, a.z * b.z, //
      ]);

  /// Max norm of the element-wise difference of two matrices.
  double _maxDiff(Matrix3 a, Matrix3 b) {
    double maxD = 0;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final d = (a.entry(i, j) - b.entry(i, j)).abs();
        if (d > maxD) maxD = d;
      }
    }
    return maxD;
  }

  /// Turn a (sum of sines, sum of cosines) pair into a unit sin/cos pair.
  (double, double) _normalizeSinCos(double s, double c) {
    final d = math.sqrt(s * s + c * c);
    if (d == 0) return (0.0, 1.0);
    return (s / d, c / d);
  }

  /// Per-measurement results, in the same order as the enabled input
  /// measurements.
  ///
  /// The error is the distance between the measured and the fitted direction,
  /// `sqrt(|gr - gt|^2 + |mr - mt|^2)`. That is exactly the quantity the
  /// paper's error measure E (eq. 4) is the RMS average of. For (near) unit
  /// vectors the distance equals the angle in radians, so reporting it in
  /// degrees gives a directly interpretable number.
  List<CalibrationResult> _buildResults(_OptimizeResult r) {
    final results = <CalibrationResult>[];
    for (int i = 0; i < r.gr.length; i++) {
      final gr = r.gr[i];
      final mr = r.mr[i];
      final error =
          math.sqrt((gr - r.gt[i]).length2 + (mr - r.mt[i]).length2);
      final (azimuth, inclination, roll) =
          CalibrationCoefficients.anglesFromVectors(gr, mr);

      results.add(CalibrationResult(
        error: error * _radToDeg,
        gMagnitude: gr.length,
        mMagnitude: mr.length,
        alpha: gr.angleTo(mr) * _radToDeg,
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
  final Matrix3 g;
  final Vector3 gd;
  final Matrix3 m;
  final Vector3 md;
  final int iterations;

  /// Calibrated sensor vectors for the converged coefficients.
  final List<Vector3> gr;
  final List<Vector3> mr;

  /// Fitted ("true") vectors the calibration is aiming at.
  final List<Vector3> gt;
  final List<Vector3> mt;

  const _OptimizeResult({
    required this.g,
    required this.gd,
    required this.m,
    required this.md,
    required this.iterations,
    required this.gr,
    required this.mr,
    required this.gt,
    required this.mt,
  });
}
