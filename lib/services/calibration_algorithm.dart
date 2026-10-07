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

  /// RMS of the per-measurement errors: the paper's error measure E, scaled by
  /// [CalibrationResult.errorScale]. Under 0.5 is a good calibration.
  final double rmsError;

  /// How evenly the device orientations are spread over the rotation group,
  /// from 0 (all measurements in one direction) to 1 (evenly spread).
  ///
  /// The paper's least squares step only determines a column of G along an
  /// axis the measurements actually vary on, so a low value means part of the
  /// solution is unconstrained and [rmsError] says nothing about the quality
  /// of the calibration. See [CalibrationAlgorithm.minUsefulCoverage].
  final double directionCoverage;

  final int iterations;

  const CalibrationOutput({
    required this.coefficients,
    required this.results,
    required this.rmsError,
    required this.directionCoverage,
    required this.iterations,
  });

  /// Whether the measurements are spread widely enough for [rmsError] and the
  /// per-measurement errors to be meaningful.
  bool get hasUsefulCoverage =>
      directionCoverage >= CalibrationAlgorithm.minUsefulCoverage;
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

  /// Minimum [CalibrationOutput.directionCoverage] for the reported errors to
  /// mean anything. Calibrated against the procedure in the DistoX2
  /// calibration manual: see the coverage tests in `test/calibration_test.dart`.
  static const double minUsefulCoverage = 0.25;

  /// Minimum RMS spread of the calibrated vectors around their centroid.
  /// A valid solution puts them on the unit sphere, so this is ~1; the
  /// degenerate solution collapses it to 0.
  static const double _minSpread = 0.5;

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

    // A correct calibration turns the readings into unit vectors spread over
    // the sphere, so their RMS distance from their centroid is ~1. The
    // iteration also has a degenerate fixed point where every calibrated
    // vector is the same constant (A -> 0, b -> +/-x): it reports a perfect
    // RMS error but leaves the azimuth stuck at 0/180 on the device, so it
    // must never reach the coefficient write.
    final spreadG = _sphereRadius(covariance(result.gr));
    final spreadM = _sphereRadius(covariance(result.mr));
    if (spreadG < _minSpread || spreadM < _minSpread) {
      throw CalibrationException(
        'Calibration collapsed to a degenerate solution '
        '(G spread ${spreadG.toStringAsFixed(3)}, '
        'M spread ${spreadM.toStringAsFixed(3)}, expected ~1). '
        'The measurements are most likely not grouped by direction correctly, '
        'or the directions are not spread out enough.',
      );
    }

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
      directionCoverage: result.coverage,
      iterations: result.iterations,
    );
  }

  /// How well a set of readings constrains the least squares step, from 0 to 1.
  ///
  /// [covariance] is the paper's Gs, the matrix eq. 6 inverts to get G. Since
  /// `G = Cov(gt, gs) o Gs^-1`, the uncertainty in G scales with `Gs^-1`, so
  /// along an eigenvector of Gs it goes as the inverse of that eigenvalue: a
  /// direction the device was never turned along collapses an eigenvalue and
  /// leaves that part of G determined by noise alone.
  ///
  /// The paper's condition for a solvable system is that the readings are
  /// "evenly spread over all possible directions", which it expresses as
  /// `Gs = |gs|^2 / 3 * I` — isotropic. Gravity has constant magnitude, so the
  /// readings lie on an ellipsoid (a sphere up to the sensor's gain and skew
  /// errors) and an even spread over it gives exactly that.
  ///
  /// The determinant over the cube of the mean eigenvalue is the ratio of the
  /// eigenvalues' geometric to arithmetic mean, cubed. By AM-GM that is at
  /// most 1, with equality only when all three are equal, so it reads 1 when
  /// isotropic and 0 when flat along any direction, whatever the sensor's
  /// gain — the clamp only guards float error. Per-axis gain differences
  /// distort it by the same few percent by which they differ.
  double _coverageOf(Matrix3 covariance) {
    final meanEigenvalue = covariance.trace() / 3.0;
    if (meanEigenvalue <= 0) return 0.0;
    final isotropic = meanEigenvalue * meanEigenvalue * meanEigenvalue;
    return (covariance.determinant() / isotropic).clamp(0.0, 1.0);
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

    // Eq. 6 is a least squares regression of the true vectors on the sensor
    // readings:
    //
    //   G  = Cov(gt, gs) o Gs^-1      gd = <gt> - G o <gs>
    //
    // where Gs = Cov(gs). The sensor means and the paper's Gs and Ms depend on
    // the readings only, so they are computed and inverted once and reused
    // every iteration.
    final avGs = mean(gs);
    final avMs = mean(ms);
    final gCovariance = covariance(gs);
    final mCovariance = covariance(ms);
    final gi = gCovariance.inverse;
    final mi = mCovariance.inverse;

    // Steps 1 and 2 of the paper's main iteration: a first estimate of alpha,
    // the angle between the gravity and the magnetic field vector, from the
    // readings themselves, and G = M = I, gd = md = 0 — the sensors taken at
    // face value. Alpha is kept as sin/cos so no arctan/sincos round trip is
    // needed.
    double sa = 0.0;
    double ca = 0.0;
    for (int i = 0; i < nn; i++) {
      sa += gs[i].cross(ms[i]).length; // sum up sine of angle
      ca += gs[i].dot(ms[i]); // sum up cosine of angle
    }
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

      // 6) new coefficients by least squares (eq. 6). `multiplied` rather
      // than `*`: `Matrix3.operator*` is declared to return `dynamic`, and
      // extension members do not resolve on `dynamic`.
      final oldG = g;
      final oldM = m;
      g = crossCovariance(gt, gs).multiplied(gi);
      m = crossCovariance(mt, ms).multiplied(mi);

      // 7) resolve the roll angle ambiguity by enforcing G_yz == G_zy
      final sym = 0.5 * (g.entry(1, 2) + g.entry(2, 1));
      g.setEntry(1, 2, sym);
      g.setEntry(2, 1, sym);

      gd = mean(gt) - g.transformVector(avGs);
      md = mean(mt) - m.transformVector(avMs);

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
      coverage: _coverageOf(gCovariance),
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

  /// RMS distance of a set of readings from its own centroid, given their
  /// centred [covariance]. For readings spread over the sphere of orientations
  /// this is its radius, which is the scale that takes them to unit vectors.
  double _sphereRadius(Matrix3 covariance) =>
      math.sqrt(math.max(covariance.trace(), 1e-12));

  /// Turn a (sum of sines, sum of cosines) pair into a unit sin/cos pair.
  (double, double) _normalizeSinCos(double s, double c) {
    final d = math.sqrt(s * s + c * c);
    if (d == 0) return (0.0, 1.0);
    return (s / d, c / d);
  }

  /// Per-measurement results, in the same order as the enabled input
  /// measurements.
  ///
  /// The error is `sqrt(|gr - gt|^2 + |mr - mt|^2)`, the per-measurement
  /// deviation the paper's error measure E (eq. 4) is the RMS average of,
  /// scaled by [CalibrationResult.errorScale].
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
        error: error * CalibrationResult.errorScale,
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

  /// Conditioning of the accelerometer covariance the fit inverts, 0 to 1.
  final double coverage;

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
    required this.coverage,
    required this.gr,
    required this.mr,
    required this.gt,
    required this.mt,
  });
}
