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

  Map<String, dynamic> toJson() => {
        'corridorId': corridorId,
        'pointId': pointId,
      };

  factory Point.fromJson(Map<String, dynamic> json) => Point(
        json['corridorId'] as num,
        json['pointId'] as num,
      );
}

class MeasuredDistance {
  final Point from;
  final Point? to; // null for splay shots
  final num distance, azimut, inclination;
  const MeasuredDistance(
      this.from, this.to, this.distance, this.azimut, this.inclination);

  Map<String, dynamic> toJson() => {
        'from': from.toJson(),
        if (to != null) 'to': to!.toJson(),
        'distance': distance,
        'azimut': azimut,
        'inclination': inclination,
      };

  factory MeasuredDistance.fromJson(Map<String, dynamic> json) =>
      MeasuredDistance(
        Point.fromJson(json['from'] as Map<String, dynamic>),
        json['to'] != null
            ? Point.fromJson(json['to'] as Map<String, dynamic>)
            : null,
        json['distance'] as num,
        json['azimut'] as num,
        json['inclination'] as num,
      );
}

class ReferencePoint {
  final Point id;
  final num east, north, altitude;
  const ReferencePoint(this.id, this.east, this.north, this.altitude);

  Map<String, dynamic> toJson() => {
        'id': id.toJson(),
        'east': east,
        'north': north,
        'altitude': altitude,
      };

  factory ReferencePoint.fromJson(Map<String, dynamic> json) => ReferencePoint(
        Point.fromJson(json['id'] as Map<String, dynamic>),
        json['east'] as num,
        json['north'] as num,
        json['altitude'] as num,
      );
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

  Map<String, dynamic> toJson() => {
        'stretches': stretches.map((s) => s.toJson()).toList(),
        'referencePoints': referencePoints.map((r) => r.toJson()).toList(),
      };

  factory Survey.fromJson(Map<String, dynamic> json) => Survey(
        stretches: (json['stretches'] as List)
            .map((s) => MeasuredDistance.fromJson(s as Map<String, dynamic>))
            .toList(),
        referencePoints: (json['referencePoints'] as List)
            .map((r) => ReferencePoint.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

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
        // Skip splay shots (no destination)
        final to = stretch.to;
        if (to == null) continue;

        // Try to compute position from 'from' station
        if (positions.containsKey(stretch.from) &&
            !positions.containsKey(to)) {
          final fromPos = positions[stretch.from]!;
          final toPos = _computeToPosition(fromPos, stretch, to);
          positions[to] = toPos;
          changed = true;
        }

        // Try to compute position from 'to' station (backward shot)
        if (positions.containsKey(to) &&
            !positions.containsKey(stretch.from)) {
          final toPos = positions[to]!;
          final fromPos = _computeFromPosition(toPos, stretch);
          positions[stretch.from] = fromPos;
          changed = true;
        }
      }
    }

    return positions;
  }

  StationPosition _computeToPosition(
      StationPosition from, MeasuredDistance stretch, Point to) {
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
      to,
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

  Survey copyWith({
    List<MeasuredDistance>? stretches,
    List<ReferencePoint>? referencePoints,
  }) {
    return Survey(
      stretches: stretches ?? this.stretches,
      referencePoints: referencePoints ?? this.referencePoints,
    );
  }

  Survey addStretch(MeasuredDistance stretch) {
    return copyWith(stretches: [...stretches, stretch]);
  }

  Survey insertStretchAt(int index, MeasuredDistance stretch) {
    final newStretches = List<MeasuredDistance>.from(stretches);
    newStretches.insert(index, stretch);
    return copyWith(stretches: newStretches);
  }

  Survey updateStretchAt(int index, MeasuredDistance stretch) {
    final newStretches = List<MeasuredDistance>.from(stretches);
    newStretches[index] = stretch;
    return copyWith(stretches: newStretches);
  }

  Survey removeStretchAt(int index) {
    final newStretches = List<MeasuredDistance>.from(stretches);
    newStretches.removeAt(index);
    return copyWith(stretches: newStretches);
  }

  /// Remove last N stretches and add a new stretch.
  /// Used by smart mode to replace 3 splays with 1 survey shot.
  Survey replaceLastNWithStretch(int n, MeasuredDistance stretch) {
    final newStretches = List<MeasuredDistance>.from(stretches);
    // Remove last n items
    for (int i = 0; i < n && newStretches.isNotEmpty; i++) {
      newStretches.removeLast();
    }
    // Add the new stretch
    newStretches.add(stretch);
    return copyWith(stretches: newStretches);
  }

  Survey addReferencePoint(ReferencePoint point) {
    return copyWith(referencePoints: [...referencePoints, point]);
  }

  Survey insertReferencePointAt(int index, ReferencePoint point) {
    final newPoints = List<ReferencePoint>.from(referencePoints);
    newPoints.insert(index, point);
    return copyWith(referencePoints: newPoints);
  }

  Survey updateReferencePointAt(int index, ReferencePoint point) {
    final newPoints = List<ReferencePoint>.from(referencePoints);
    newPoints[index] = point;
    return copyWith(referencePoints: newPoints);
  }

  Survey removeReferencePointAt(int index) {
    final newPoints = List<ReferencePoint>.from(referencePoints);
    newPoints.removeAt(index);
    return copyWith(referencePoints: newPoints);
  }
}
