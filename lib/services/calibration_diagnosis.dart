import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../models/calibration.dart';
import 'calibration_algorithm.dart';

/// Why a single calibration shot is suspect.
enum ShotProblem {
  /// The laser pointed far from the direction the shot was taken for.
  wrongDirection,

  /// A shot of a precisely aimed direction does not hit the point the
  /// other shots of the direction hit.
  offTarget,

  /// The device was held with the display facing another side than asked.
  wrongOrientation,

  /// The gravity reading is inconsistent: the device moved during the shot.
  unsteady,

  /// The magnetic reading is inconsistent with the other shots.
  disturbed,
}

/// Which way a shot of a precisely aimed direction missed the others' point.
enum MissSide { above, below, left, right }

/// A suspect shot of a calibration direction.
class ShotIssue {
  /// Display orientation (0-3) the shot was taken for.
  final int rollIndex;

  final ShotProblem problem;

  /// How far off the shot is, in degrees: from the direction for
  /// [ShotProblem.wrongDirection], from the other shots of the direction for
  /// [ShotProblem.offTarget].
  final double? degrees;

  /// Which way a [ShotProblem.offTarget] shot missed.
  final MissSide? side;

  /// Display orientation (0-3) the device was actually held in, for
  /// [ShotProblem.wrongOrientation].
  final int? actualRollIndex;

  const ShotIssue({
    required this.rollIndex,
    required this.problem,
    this.degrees,
    this.side,
    this.actualRollIndex,
  });

  @override
  String toString() => 'roll $rollIndex: ${problem.name}'
      '${degrees == null ? '' : ' ${degrees!.toStringAsFixed(1)}°'}'
      '${side == null ? '' : ' ${side!.name}'}'
      '${actualRollIndex == null ? '' : ' as roll $actualRollIndex'}';
}

/// What most likely causes a calibration error above the limit.
enum CalibrationProblem {
  /// The shots do not cover enough directions for the error to mean anything.
  coverage,

  /// The device moved during shots.
  unsteady,

  /// The magnetic field differed between shots.
  magnetic,

  /// The shots of the precisely aimed directions miss each other's point.
  aiming,
}

/// What to tell the user about a finished set of calibration shots.
///
/// Empty while the calibration error is within the limit. Above it, there is
/// always a [problem], and shots that look responsible are listed by
/// direction.
class CalibrationDiagnosis {
  final CalibrationProblem? problem;

  /// Suspect shots by direction, ordered by display orientation.
  final Map<int, List<ShotIssue>> directions;

  const CalibrationDiagnosis({this.problem, this.directions = const {}});

  static const ok = CalibrationDiagnosis();

  bool get isOk => problem == null && directions.isEmpty;

  @override
  String toString() => 'problem: ${problem?.name ?? 'none'}, '
      'directions: $directions';
}

/// Judges calibration shots by what the calibration says about them.
///
/// The calibration is fitted from the shots it judges. With most shots good it
/// is still accurate to well within the direction and orientation
/// tolerances, which are wide compared with what one bad shot can distort.
/// Whether the shots of a precisely aimed direction hit one point is judged
/// more finely, so there the calibration is fitted again without the shots
/// that miss.
class CalibrationDiagnoser {
  /// Limit for the calibration error E, scaled like
  /// [CalibrationOutput.rmsError]. A scaled E is about the angular error in
  /// degrees (see [CalibrationResult.errorScale]).
  final double errorLimit;

  const CalibrationDiagnoser({required this.errorLimit});

  /// How far a shot may stray from the direction it was taken for, in
  /// degrees: below half the 54.7° between the closest of the 14 directions,
  /// so it is always closer to its own than to any other.
  static const double directionLimit = 25.0;

  /// How far the display orientation may stray, in degrees: half the 90°
  /// between the four orientations.
  static const double rollLimit = 45.0;

  /// How far a shot of a precisely aimed direction may stray from the point
  /// the other shots hit, in degrees: twice the angular error the limit
  /// allows for a shot on average.
  double get targetLimit => 2 * errorLimit;

  /// How large a shot's own inconsistency may be, scaled like the error:
  /// twice what the limit allows a shot on average.
  double get shotLimit => 2 * errorLimit;

  /// Diagnose the shots.
  ///
  /// [positions] and [results] run parallel to [measurements]: the slot each
  /// shot was taken for, and its result in [output]. [rmsError] is null when
  /// the shots do not cover enough directions for it to mean anything.
  /// [refit] calibrates again from the measurements with the ones at the
  /// given indices left out, or returns null if that fails.
  CalibrationDiagnosis diagnose({
    required List<CalibrationMeasurement> measurements,
    required List<CalibrationPosition?> positions,
    required List<CalibrationResult?> results,
    required CalibrationOutput output,
    required double? rmsError,
    required double? referenceBearing,
    required CalibrationCoefficients? Function(Set<int> excluded) refit,
  }) {
    if (rmsError != null && rmsError < errorLimit) {
      return CalibrationDiagnosis.ok;
    }
    if (rmsError == null) {
      return const CalibrationDiagnosis(problem: CalibrationProblem.coverage);
    }

    final shots = <int, _Shot>{
      for (int i = 0; i < measurements.length && i < results.length; i++)
        if (measurements[i].enabled &&
            positions[i] != null &&
            results[i] != null)
          i: _Shot(positions[i]!, results[i]!),
    };

    final offTarget = _offTarget(
      measurements,
      shots,
      output.coefficients,
      refit,
    );

    final issues = <int, List<ShotIssue>>{};
    for (final MapEntry(key: i, value: shot) in shots.entries) {
      final issue = _wrongDirection(shot, referenceBearing) ??
          offTarget[i] ??
          _wrongOrientation(shot) ??
          _inconsistent(shot, output.alpha);
      if (issue != null) {
        (issues[shot.position.direction] ??= []).add(issue);
      }
    }
    for (final list in issues.values) {
      list.sort((a, b) => a.rollIndex.compareTo(b.rollIndex));
    }

    return CalibrationDiagnosis(
      problem: _dominantProblem(output.errorBreakdown),
      directions: issues,
    );
  }

  /// The cause behind the largest share of the error.
  CalibrationProblem _dominantProblem(ErrorBreakdown b) {
    final shares = {
      CalibrationProblem.unsteady: b.gravityLength * b.gravityLength,
      CalibrationProblem.magnetic:
          b.magneticLength * b.magneticLength + b.dip * b.dip,
      CalibrationProblem.aiming: b.aiming * b.aiming,
    };
    return shares.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  ShotIssue? _wrongDirection(_Shot shot, double? referenceBearing) {
    if (referenceBearing == null) return null;
    final (offset, inclination) =
        CalibrationPositions.relativeDirections[shot.position.direction];
    final expected = _unit(referenceBearing + offset, inclination);
    final degrees = _degrees(shot.laser.angleTo(expected));
    if (degrees <= directionLimit) return null;
    return ShotIssue(
      rollIndex: shot.position.rollIndex,
      problem: ShotProblem.wrongDirection,
      degrees: degrees,
    );
  }

  /// Shots of one precisely aimed direction that miss the point the others
  /// hit.
  ///
  /// Each shot is compared with the other shots of its direction only, so
  /// that it does not pull the point it is measured against towards itself.
  ///
  /// The groups are also all the calibration has to tell where the laser
  /// points relative to the sensors, so a shot that misses bends the whole
  /// fit: part of its miss is hidden, and the rest spills onto the other
  /// shots. So the worst shot is set aside and the calibration fitted again
  /// without it, until all remaining shots agree. The shots set aside are then
  /// measured against that clean fit, which shows their whole miss.
  ///
  /// Returns the issues by measurement index.
  Map<int, ShotIssue> _offTarget(
    List<CalibrationMeasurement> measurements,
    Map<int, _Shot> shots,
    CalibrationCoefficients coefficients,
    CalibrationCoefficients? Function(Set<int> excluded) refit,
  ) {
    final groups = <int, List<int>>{
      for (int d = 0; d < CalibrationPositions.preciseDirections; d++)
        d: [
          for (final MapEntry(key: i, value: shot) in shots.entries)
            if (shot.position.direction == d) i,
        ],
    };
    final excluded = <int>{};
    var fit = coefficients;

    while (true) {
      final aims = {
        for (final members in groups.values)
          for (final i in members) i: _Aim.of(fit, measurements[i]),
      };

      int? worst;
      var worstDegrees = targetLimit;
      for (final members in groups.values) {
        final remaining = [
          for (final i in members) if (!excluded.contains(i)) i,
        ];
        if (remaining.length < 3) continue;
        for (final i in remaining) {
          final degrees = aims[i]!.angleTo(_meanLaser(remaining, i, aims));
          if (degrees > worstDegrees) {
            worst = i;
            worstDegrees = degrees;
          }
        }
      }
      if (worst == null) break;

      excluded.add(worst);
      final refitted = refit(excluded);
      if (refitted == null) break;
      fit = refitted;
    }

    final issues = <int, ShotIssue>{};
    for (final i in excluded) {
      final members = groups[shots[i]!.position.direction]!;
      final remaining = [
        for (final j in members) if (!excluded.contains(j)) j,
      ];
      final aims = {for (final j in members) j: _Aim.of(fit, measurements[j])};
      final others = _meanLaser(remaining, i, aims);
      issues[i] = ShotIssue(
        rollIndex: shots[i]!.position.rollIndex,
        problem: ShotProblem.offTarget,
        degrees: aims[i]!.angleTo(others),
        side: aims[i]!.sideOf(others),
      );
    }
    return issues;
  }

  /// Mean laser direction of the shots [members] other than [except].
  static Vector3 _meanLaser(
    List<int> members,
    int except,
    Map<int, _Aim> aims,
  ) {
    final sum = Vector3.zero();
    for (final j in members) {
      if (j != except) sum.add(aims[j]!.laser);
    }
    return sum.normalized();
  }

  ShotIssue? _wrongOrientation(_Shot shot) {
    final (_, inclination) =
        CalibrationPositions.relativeDirections[shot.position.direction];
    // Pointing vertically, roll has no meaning.
    if (inclination.abs() == 90) return null;

    final expected = shot.position.rollIndex * 90.0;
    if (_angleDiff(shot.result.roll, expected).abs() <= rollLimit) return null;
    return ShotIssue(
      rollIndex: shot.position.rollIndex,
      problem: ShotProblem.wrongOrientation,
      actualRollIndex: ((shot.result.roll / 90).round()) % 4,
    );
  }

  /// A shot whose gravity or magnetic reading does not fit the others: its
  /// vectors' lengths or the angle between them are off.
  ShotIssue? _inconsistent(_Shot shot, double alpha) {
    final r = shot.result;
    final gravity = _square(r.gMagnitude - 1);
    final magnetic = _square(r.mMagnitude - 1) +
        _square((r.alpha - alpha) * math.pi / 180) / 2;
    final error =
        math.sqrt(gravity + magnetic) * CalibrationResult.errorScale;
    if (error < shotLimit) return null;
    return ShotIssue(
      rollIndex: shot.position.rollIndex,
      problem:
          gravity >= magnetic ? ShotProblem.unsteady : ShotProblem.disturbed,
    );
  }

  /// Unit vector for a bearing and inclination in degrees: x east, y north,
  /// z up.
  static Vector3 _unit(double bearing, double inclination) {
    final b = bearing * math.pi / 180;
    final i = inclination * math.pi / 180;
    return Vector3(
      math.cos(i) * math.sin(b),
      math.cos(i) * math.cos(b),
      math.sin(i),
    );
  }

  static double _degrees(double radians) => radians * 180 / math.pi;

  static double _square(double x) => x * x;

  /// Difference between two angles in degrees, normalized to [-180, 180).
  static double _angleDiff(double a, double b) =>
      ((a - b + 180) % 360) - 180;
}

/// A shot with the slot it was taken for and its evaluated result.
class _Shot {
  final CalibrationPosition position;
  final CalibrationResult result;

  /// Laser direction from the evaluated angles.
  final Vector3 laser;

  _Shot(this.position, this.result)
      : laser = CalibrationDiagnoser._unit(result.azimuth, result.inclination);
}

/// Where a shot points under a set of calibration coefficients.
class _Aim {
  final double azimuth;
  final double inclination;
  final Vector3 laser;

  _Aim(this.azimuth, this.inclination)
      : laser = CalibrationDiagnoser._unit(azimuth, inclination);

  factory _Aim.of(CalibrationCoefficients fit, CalibrationMeasurement raw) {
    final (g, m) = fit.apply(raw);
    final (azimuth, inclination, _) =
        CalibrationCoefficients.anglesFromVectors(g, m);
    return _Aim(azimuth, inclination);
  }

  /// Angle to [direction], in degrees.
  double angleTo(Vector3 direction) =>
      CalibrationDiagnoser._degrees(laser.angleTo(direction));

  /// Which way this shot points away from [direction].
  MissSide sideOf(Vector3 direction) {
    final inclinationOff = inclination -
        CalibrationDiagnoser._degrees(math.asin(direction.z.clamp(-1, 1)));
    final bearingOff = CalibrationDiagnoser._angleDiff(
          azimuth,
          CalibrationDiagnoser._degrees(math.atan2(direction.x, direction.y)),
        ) *
        math.cos(inclination * math.pi / 180);
    return inclinationOff.abs() >= bearingOff.abs()
        ? (inclinationOff > 0 ? MissSide.above : MissSide.below)
        : (bearingOff > 0 ? MissSide.right : MissSide.left);
  }
}
