import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// A raw measurement from the DistoX device
class RawMeasurement {
  final double distance;
  final double azimuth; // in degrees
  final double inclination; // in degrees
  final DateTime timestamp;

  const RawMeasurement({
    required this.distance,
    required this.azimuth,
    required this.inclination,
    required this.timestamp,
  });

  /// Convert azimuth and inclination to a 3D unit direction vector
  /// Returns [east, north, up] components
  (double, double, double) get directionVector {
    final azRad = azimuth * math.pi / 180.0;
    final incRad = inclination * math.pi / 180.0;

    // Horizontal component
    final horizDist = math.cos(incRad);

    // East = horizontal * sin(azimuth)
    final east = horizDist * math.sin(azRad);
    // North = horizontal * cos(azimuth)
    final north = horizDist * math.cos(azRad);
    // Up = sin(inclination)
    final up = math.sin(incRad);

    return (east, north, up);
  }
}

/// Result of smart mode detection
enum ShotType {
  /// A single measurement (splay shot or cross-section)
  splay,

  /// Three identical measurements detected (survey shot)
  surveyShot,
}

/// Detected shot with averaged values (for survey shots) or single measurement
class DetectedShot {
  final ShotType type;
  final double distance;
  final double azimuth;
  final double inclination;
  final List<RawMeasurement> rawMeasurements;

  const DetectedShot({
    required this.type,
    required this.distance,
    required this.azimuth,
    required this.inclination,
    required this.rawMeasurements,
  });
}

/// Detects survey shots by identifying 3 nearly identical measurements.
///
/// Every measurement is emitted immediately as a splay. When 3 consecutive
/// measurements form a triple, onTripleDetected is called so the UI can
/// replace the 3 splays with a single survey shot.
///
/// According to DistoX specs, shots are "nearly identical" if:
/// - Distance difference < 5cm (0.05m)
/// - Directional difference < 3% (1.7°)
class SmartModeDetector {
  /// Maximum distance difference for shots to be considered identical (in meters)
  static const double maxDistanceDifference = 0.05;

  /// Maximum angular difference for shots to be considered identical (in degrees)
  static const double maxAngularDifference = 1.7;

  /// Ring buffer of last 3 measurements for triple detection
  final List<RawMeasurement> _recentMeasurements = [];

  /// Callback when any shot is detected (splay or survey shot)
  void Function(DetectedShot shot)? onShotDetected;

  /// Callback when a triple is detected - the last 3 splays should be
  /// replaced with this survey shot
  void Function(DetectedShot surveyShot)? onTripleDetected;

  SmartModeDetector({this.onShotDetected, this.onTripleDetected});

  /// Add a new measurement.
  ///
  /// The measurement is immediately emitted as a splay via onShotDetected.
  /// If this forms a triple with the previous 2 measurements, onTripleDetected
  /// is also called so the UI can replace the 3 splays with 1 survey shot.
  DetectedShot addMeasurement(RawMeasurement measurement) {
    debugPrint('SmartModeDetector.addMeasurement: dist=${measurement.distance.toStringAsFixed(3)}, azi=${measurement.azimuth.toStringAsFixed(1)}, inc=${measurement.inclination.toStringAsFixed(1)}');
    debugPrint('SmartModeDetector: buffer size before add: ${_recentMeasurements.length}');

    // Always emit the measurement immediately as a splay
    final splay = DetectedShot(
      type: ShotType.splay,
      distance: measurement.distance,
      azimuth: measurement.azimuth,
      inclination: measurement.inclination,
      rawMeasurements: [measurement],
    );
    debugPrint('SmartModeDetector: calling onShotDetected (${onShotDetected != null})');
    onShotDetected?.call(splay);

    // Add to recent measurements (keep only last 3)
    _recentMeasurements.add(measurement);
    if (_recentMeasurements.length > 3) {
      _recentMeasurements.removeAt(0);
    }
    debugPrint('SmartModeDetector: buffer size after add: ${_recentMeasurements.length}');

    // Check if last 3 form a triple
    if (_recentMeasurements.length == 3) {
      debugPrint('SmartModeDetector: checking for triple...');
      if (_isTriple(_recentMeasurements[0], _recentMeasurements[1], _recentMeasurements[2])) {
        // Triple detected - notify so UI can replace last 3 splays
        final surveyShot = _createSurveyShot(_recentMeasurements.toList());
        debugPrint('SmartModeDetector: calling onTripleDetected (${onTripleDetected != null})');
        onTripleDetected?.call(surveyShot);
        // Clear buffer so we don't detect overlapping triples
        _recentMeasurements.clear();
        return surveyShot;
      }
    }

    return splay;
  }

  /// Force flush - no longer needed since measurements are emitted immediately
  List<DetectedShot> flush() {
    return [];
  }

  /// Clear recent measurements buffer
  void clear() {
    _recentMeasurements.clear();
  }

  /// Number of measurements in the recent buffer (0-3)
  int get pendingCount => _recentMeasurements.length;

  /// Check if three measurements form a "triple" (nearly identical)
  bool _isTriple(RawMeasurement a, RawMeasurement b, RawMeasurement c) {
    debugPrint('SmartModeDetector._isTriple: checking 3 measurements');
    debugPrint('  a: dist=${a.distance.toStringAsFixed(3)}, azi=${a.azimuth.toStringAsFixed(1)}, inc=${a.inclination.toStringAsFixed(1)}');
    debugPrint('  b: dist=${b.distance.toStringAsFixed(3)}, azi=${b.azimuth.toStringAsFixed(1)}, inc=${b.inclination.toStringAsFixed(1)}');
    debugPrint('  c: dist=${c.distance.toStringAsFixed(3)}, azi=${c.azimuth.toStringAsFixed(1)}, inc=${c.inclination.toStringAsFixed(1)}');

    // Check all pairwise distance differences
    final distAB = (a.distance - b.distance).abs();
    final distBC = (b.distance - c.distance).abs();
    final distAC = (a.distance - c.distance).abs();
    debugPrint('  distance diffs: AB=${distAB.toStringAsFixed(3)}, BC=${distBC.toStringAsFixed(3)}, AC=${distAC.toStringAsFixed(3)} (max=$maxDistanceDifference)');

    if (!_distancesMatch(a.distance, b.distance)) {
      debugPrint('  FAIL: distance A-B');
      return false;
    }
    if (!_distancesMatch(b.distance, c.distance)) {
      debugPrint('  FAIL: distance B-C');
      return false;
    }
    if (!_distancesMatch(a.distance, c.distance)) {
      debugPrint('  FAIL: distance A-C');
      return false;
    }

    // Check all pairwise directional differences
    if (!_directionsMatch(a, b)) {
      debugPrint('  FAIL: direction A-B');
      return false;
    }
    if (!_directionsMatch(b, c)) {
      debugPrint('  FAIL: direction B-C');
      return false;
    }
    if (!_directionsMatch(a, c)) {
      debugPrint('  FAIL: direction A-C');
      return false;
    }

    debugPrint('  SUCCESS: triple detected!');
    return true;
  }

  /// Check if two distances are within the threshold
  bool _distancesMatch(double d1, double d2) {
    return (d1 - d2).abs() < maxDistanceDifference;
  }

  /// Check if two directions are within the angular threshold
  bool _directionsMatch(RawMeasurement a, RawMeasurement b) {
    final (ax, ay, az) = a.directionVector;
    final (bx, by, bz) = b.directionVector;

    // Dot product of unit vectors gives cos(angle)
    final dot = ax * bx + ay * by + az * bz;

    // Clamp to avoid numerical issues with acos
    final clampedDot = dot.clamp(-1.0, 1.0);

    // Angle in degrees
    final angleDeg = math.acos(clampedDot) * 180.0 / math.pi;

    return angleDeg < maxAngularDifference;
  }

  /// Create a survey shot by averaging three measurements
  DetectedShot _createSurveyShot(List<RawMeasurement> measurements) {
    assert(measurements.length == 3);

    // Average distance
    final avgDistance =
        (measurements[0].distance + measurements[1].distance + measurements[2].distance) / 3;

    // For angles, we need to handle wraparound properly
    // Convert to vectors, average, then back to angles
    double sumEast = 0, sumNorth = 0, sumUp = 0;
    for (final m in measurements) {
      final (e, n, u) = m.directionVector;
      sumEast += e;
      sumNorth += n;
      sumUp += u;
    }

    // Normalize the averaged vector
    final mag = math.sqrt(sumEast * sumEast + sumNorth * sumNorth + sumUp * sumUp);
    final avgEast = sumEast / mag;
    final avgNorth = sumNorth / mag;
    final avgUp = sumUp / mag;

    // Convert back to azimuth and inclination
    final avgInclination = math.asin(avgUp.clamp(-1.0, 1.0)) * 180.0 / math.pi;

    // atan2 returns angle in radians from -pi to pi
    var avgAzimuth = math.atan2(avgEast, avgNorth) * 180.0 / math.pi;
    if (avgAzimuth < 0) avgAzimuth += 360.0;

    return DetectedShot(
      type: ShotType.surveyShot,
      distance: avgDistance,
      azimuth: avgAzimuth,
      inclination: avgInclination,
      rawMeasurements: measurements,
    );
  }
}
