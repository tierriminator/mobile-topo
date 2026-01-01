import 'dart:math' as math;

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
/// According to DistoX specs, shots are "nearly identical" if:
/// - Distance difference < 5cm (0.05m)
/// - Directional difference < 3% (1.7°)
class SmartModeDetector {
  /// Maximum distance difference for shots to be considered identical (in meters)
  static const double maxDistanceDifference = 0.05;

  /// Maximum angular difference for shots to be considered identical (in degrees)
  static const double maxAngularDifference = 1.7;

  final List<RawMeasurement> _pendingMeasurements = [];

  /// Callback when a shot is detected
  void Function(DetectedShot shot)? onShotDetected;

  SmartModeDetector({this.onShotDetected});

  /// Add a new measurement and check for triple detection
  ///
  /// Returns the detected shot if a complete shot is detected, null otherwise.
  /// When smart mode detects a survey shot (3 identical), it consumes all 3
  /// measurements. For splay shots, measurements are emitted individually
  /// once we know they're not part of a triple.
  DetectedShot? addMeasurement(RawMeasurement measurement) {
    _pendingMeasurements.add(measurement);

    // Check if we have 3 measurements that form a triple
    if (_pendingMeasurements.length >= 3) {
      final last3 = _pendingMeasurements.sublist(_pendingMeasurements.length - 3);

      if (_isTriple(last3[0], last3[1], last3[2])) {
        // Survey shot detected - consume all 3 measurements
        _pendingMeasurements.removeRange(
          _pendingMeasurements.length - 3,
          _pendingMeasurements.length,
        );

        final shot = _createSurveyShot(last3);
        onShotDetected?.call(shot);
        return shot;
      } else {
        // Not a triple - emit the oldest measurement as a splay
        final oldest = _pendingMeasurements.removeAt(0);
        final shot = DetectedShot(
          type: ShotType.splay,
          distance: oldest.distance,
          azimuth: oldest.azimuth,
          inclination: oldest.inclination,
          rawMeasurements: [oldest],
        );
        onShotDetected?.call(shot);
        return shot;
      }
    }

    return null;
  }

  /// Force flush any pending measurements as splay shots
  List<DetectedShot> flush() {
    final shots = <DetectedShot>[];
    while (_pendingMeasurements.isNotEmpty) {
      final m = _pendingMeasurements.removeAt(0);
      shots.add(DetectedShot(
        type: ShotType.splay,
        distance: m.distance,
        azimuth: m.azimuth,
        inclination: m.inclination,
        rawMeasurements: [m],
      ));
    }
    for (final shot in shots) {
      onShotDetected?.call(shot);
    }
    return shots;
  }

  /// Clear all pending measurements
  void clear() {
    _pendingMeasurements.clear();
  }

  /// Number of measurements waiting to be processed
  int get pendingCount => _pendingMeasurements.length;

  /// Check if three measurements form a "triple" (nearly identical)
  bool _isTriple(RawMeasurement a, RawMeasurement b, RawMeasurement c) {
    // Check all pairwise distance differences
    if (!_distancesMatch(a.distance, b.distance)) return false;
    if (!_distancesMatch(b.distance, c.distance)) return false;
    if (!_distancesMatch(a.distance, c.distance)) return false;

    // Check all pairwise directional differences
    if (!_directionsMatch(a, b)) return false;
    if (!_directionsMatch(b, c)) return false;
    if (!_directionsMatch(a, c)) return false;

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
