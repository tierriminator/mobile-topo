import 'dart:math' as math;

class Point {
  final num corridorId, pointId;
  const Point(this.corridorId, this.pointId);

  @override
  bool operator ==(Object other) =>
      other is Point &&
      other.corridorId == corridorId &&
      other.pointId == pointId;

  @override
  int get hashCode => Object.hash(corridorId, pointId);

  @override
  String toString() => '$corridorId.$pointId';
}

class MeasuredDistance {
  final Point from, to;
  final num distance, azimut, inclination;
  const MeasuredDistance(
      this.from, this.to, this.distance, this.azimut, this.inclination);
}

class ReferencePoint {
  final Point id;
  final num east, north, altitude;
  const ReferencePoint(this.id, this.east, this.north, this.altitude);
}

/// Calculated 3D position of a survey station
class StationPosition {
  final Point id;
  final double east, north, altitude;
  const StationPosition(this.id, this.east, this.north, this.altitude);
}

/// Holds survey data and computes station positions
class Survey {
  final List<MeasuredDistance> stretches;
  final List<ReferencePoint> referencePoints;

  const Survey({
    required this.stretches,
    required this.referencePoints,
  });

  /// Computes positions of all stations from reference points and stretches.
  /// Returns a map from Point to StationPosition.
  Map<Point, StationPosition> computeStationPositions() {
    final positions = <Point, StationPosition>{};

    // Start with reference points
    for (final ref in referencePoints) {
      positions[ref.id] = StationPosition(
        ref.id,
        ref.east.toDouble(),
        ref.north.toDouble(),
        ref.altitude.toDouble(),
      );
    }

    // Iterate until no new positions are computed
    bool changed = true;
    while (changed) {
      changed = false;
      for (final stretch in stretches) {
        // Skip if 'to' is empty (cross-section measurement)
        if (stretch.to.corridorId == 0 && stretch.to.pointId == 0) continue;

        // Try to compute position from 'from' station
        if (positions.containsKey(stretch.from) &&
            !positions.containsKey(stretch.to)) {
          final fromPos = positions[stretch.from]!;
          final toPos = _computeToPosition(fromPos, stretch);
          positions[stretch.to] = toPos;
          changed = true;
        }

        // Try to compute position from 'to' station (backward shot)
        if (positions.containsKey(stretch.to) &&
            !positions.containsKey(stretch.from)) {
          final toPos = positions[stretch.to]!;
          final fromPos = _computeFromPosition(toPos, stretch);
          positions[stretch.from] = fromPos;
          changed = true;
        }
      }
    }

    return positions;
  }

  StationPosition _computeToPosition(
      StationPosition from, MeasuredDistance stretch) {
    // Convert angles to radians
    final azimuthRad = stretch.azimut * math.pi / 180.0;
    final inclinationRad = stretch.inclination * math.pi / 180.0;

    // Horizontal distance
    final horizDist = stretch.distance * math.cos(inclinationRad);

    // Vertical distance
    final vertDist = stretch.distance * math.sin(inclinationRad);

    // East and North offsets (azimuth is from North, clockwise)
    final eastOffset = horizDist * math.sin(azimuthRad);
    final northOffset = horizDist * math.cos(azimuthRad);

    return StationPosition(
      stretch.to,
      from.east + eastOffset,
      from.north + northOffset,
      from.altitude + vertDist,
    );
  }

  StationPosition _computeFromPosition(
      StationPosition to, MeasuredDistance stretch) {
    // Reverse calculation: from = to - offset
    final azimuthRad = stretch.azimut * math.pi / 180.0;
    final inclinationRad = stretch.inclination * math.pi / 180.0;

    final horizDist = stretch.distance * math.cos(inclinationRad);
    final vertDist = stretch.distance * math.sin(inclinationRad);

    final eastOffset = horizDist * math.sin(azimuthRad);
    final northOffset = horizDist * math.cos(azimuthRad);

    return StationPosition(
      stretch.from,
      to.east - eastOffset,
      to.north - northOffset,
      to.altitude - vertDist,
    );
  }

  /// Calculates total surveyed length (sum of all stretch distances)
  double get totalLength {
    double total = 0;
    for (final stretch in stretches) {
      total += stretch.distance.toDouble();
    }
    return total;
  }

  /// Calculates depth (difference between highest and lowest station)
  double computeDepth(Map<Point, StationPosition> positions) {
    if (positions.isEmpty) return 0;
    double minAlt = double.infinity;
    double maxAlt = double.negativeInfinity;
    for (final pos in positions.values) {
      if (pos.altitude < minAlt) minAlt = pos.altitude;
      if (pos.altitude > maxAlt) maxAlt = pos.altitude;
    }
    return maxAlt - minAlt;
  }
}
