import 'dart:math' as math;

class Point implements Comparable<Point> {
  final num corridorId, pointId;
  const Point(this.corridorId, this.pointId);

  /// Orders stations by series, then by point within the series
  @override
  int compareTo(Point other) {
    final bySeries = corridorId.compareTo(other.corridorId);
    return bySeries != 0 ? bySeries : pointId.compareTo(other.pointId);
  }

  @override
  bool operator ==(Object other) =>
      other is Point &&
      other.corridorId == corridorId &&
      other.pointId == pointId;

  @override
  int get hashCode => Object.hash(corridorId, pointId);

  /// The following point in the same series
  Point get next => Point(corridorId, pointId.toInt() + 1);

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

  /// ID of the trip this stretch was measured on, if any
  final String? tripId;

  /// Free text note on this stretch, like the name of a new passage
  final String? comment;

  /// Whether this survey shot runs from right to left in the side view
  final bool flipped;

  const MeasuredDistance(
      this.from, this.to, this.distance, this.azimut, this.inclination,
      {this.tripId, this.comment, this.flipped = false});

  /// A copy with the given values replaced. [to] and [comment] cannot be
  /// cleared this way; use [withComment] for the comment.
  MeasuredDistance copyWith({
    Point? from,
    Point? to,
    num? distance,
    num? azimut,
    num? inclination,
    String? tripId,
    String? comment,
    bool? flipped,
  }) {
    return MeasuredDistance(
      from ?? this.from,
      to ?? this.to,
      distance ?? this.distance,
      azimut ?? this.azimut,
      inclination ?? this.inclination,
      tripId: tripId ?? this.tripId,
      comment: comment ?? this.comment,
      flipped: flipped ?? this.flipped,
    );
  }

  /// A copy with the comment replaced; null or empty removes it
  MeasuredDistance withComment(String? comment) => MeasuredDistance(
        from,
        to,
        distance,
        azimut,
        inclination,
        tripId: tripId,
        comment: _normalizeComment(comment),
        flipped: flipped,
      );

  /// The station this row stands for: the station a survey shot leads to,
  /// or the station of a cross section. A shot whose From station is numbered
  /// higher than its To station counts as a backward shot, measured from the
  /// new station back to the previous one.
  Point get station {
    final to = this.to;
    if (to == null) return from;
    return from.compareTo(to) > 0 ? from : to;
  }

  /// Whether this is a survey shot measured from the new station back to
  /// the previous one
  bool get isBackward {
    final to = this.to;
    return to != null && from.compareTo(to) > 0;
  }

  /// A survey shot switched between forward and backward by exchanging From
  /// and To. A cross section is returned unchanged.
  MeasuredDistance reversed() {
    final to = this.to;
    return to == null ? this : copyWith(from: to, to: from);
  }

  /// A cross section turned into a survey shot to the next station, a
  /// backward one if [backward] is set. A survey shot is returned unchanged.
  MeasuredDistance toSurveyShot({bool backward = false}) {
    if (to != null) return this;
    final next = from.next;
    return copyWith(
      from: backward ? next : from,
      to: backward ? from : next,
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from.toJson(),
        if (to != null) 'to': to!.toJson(),
        'distance': distance,
        'azimut': azimut,
        'inclination': inclination,
        if (tripId != null) 'tripId': tripId,
        if (comment != null) 'comment': comment,
        if (flipped) 'flipped': true,
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
        tripId: json['tripId'] as String?,
        comment: json['comment'] as String?,
        flipped: json['flipped'] as bool? ?? false,
      );
}

class ReferencePoint {
  final Point id;
  final num east, north, altitude;

  /// Free text note on this reference point, like where the coordinates
  /// come from
  final String? comment;

  const ReferencePoint(this.id, this.east, this.north, this.altitude,
      {this.comment});

  /// A copy with the given values replaced. [comment] cannot be cleared this
  /// way; use [withComment] for it.
  ReferencePoint copyWith({
    Point? id,
    num? east,
    num? north,
    num? altitude,
    String? comment,
  }) {
    return ReferencePoint(
      id ?? this.id,
      east ?? this.east,
      north ?? this.north,
      altitude ?? this.altitude,
      comment: comment ?? this.comment,
    );
  }

  /// A copy with the comment replaced; null or empty removes it
  ReferencePoint withComment(String? comment) => ReferencePoint(
        id,
        east,
        north,
        altitude,
        comment: _normalizeComment(comment),
      );

  Map<String, dynamic> toJson() => {
        'id': id.toJson(),
        'east': east,
        'north': north,
        'altitude': altitude,
        if (comment != null) 'comment': comment,
      };

  factory ReferencePoint.fromJson(Map<String, dynamic> json) => ReferencePoint(
        Point.fromJson(json['id'] as Map<String, dynamic>),
        json['east'] as num,
        json['north'] as num,
        json['altitude'] as num,
        comment: json['comment'] as String?,
      );
}

/// A comment as stored: surrounding whitespace removed, null when empty
String? _normalizeComment(String? comment) {
  final trimmed = comment?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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

  /// Stations measured from, measured to, or referenced in this survey
  Set<Point> get stations => {
        for (final ref in referencePoints) ref.id,
        for (final stretch in stretches) ...[
          stretch.from,
          if (stretch.to != null) stretch.to!,
        ],
      };

  /// For each station, the first station in data order it is equivalent to:
  /// stations linked by zero length shots, as at the start of a new series,
  /// are equivalent. A station without equivalents maps to itself.
  Map<Point, Point> get equivalentStations {
    final linked = <Point, List<Point>>{};
    for (final stretch in stretches) {
      final to = stretch.to;
      if (to == null || stretch.distance != 0) continue;
      (linked[stretch.from] ??= []).add(to);
      (linked[to] ??= []).add(stretch.from);
    }

    final first = <Point, Point>{};
    for (final station in stations) {
      if (first.containsKey(station)) continue;
      first[station] = station;
      final pending = [station];
      while (pending.isNotEmpty) {
        for (final other in linked[pending.removeLast()] ?? const <Point>[]) {
          if (first.containsKey(other)) continue;
          first[other] = station;
          pending.add(other);
        }
      }
    }
    return first;
  }

  /// The stations in data order, leaving out any equivalent to an earlier one
  Set<Point> get distinctStations {
    final equivalents = equivalentStations;
    return {
      for (final station in stations)
        if (equivalents[station] == station) station,
    };
  }

  /// The last station (highest point number) of each series
  Set<Point> get seriesEnds {
    final last = <num, Point>{};
    for (final station in stations) {
      final current = last[station.corridorId];
      if (current == null || station.pointId > current.pointId) {
        last[station.corridorId] = station;
      }
    }
    return last.values.toSet();
  }

  /// The station new measurements continue from, as in PocketTopo where the
  /// last row of the data table determines the numbering: the station of the
  /// last stretch, or without stretches the last reference point's station.
  ///
  /// Returns null for an empty survey.
  Point? get lastStation =>
      stretches.lastOrNull?.station ?? referencePoints.lastOrNull?.id;

  /// First station of a new series: the series after the highest one in use
  Point get nextSeriesStart {
    var maxSeries = 0;
    for (final station in stations) {
      maxSeries = math.max(maxSeries, station.corridorId.toInt());
    }
    return Point(maxSeries + 1, 0);
  }

  /// Total surveyed length: the sum of all survey shots between two stations.
  /// Cross sections and splays measure passage dimensions, not the cave's
  /// length, so they are left out.
  double get totalLength {
    double total = 0;
    for (final stretch in stretches) {
      if (stretch.to != null) total += stretch.distance.toDouble();
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

  Survey removeStretchesAt(Set<int> indices) {
    return copyWith(stretches: [
      for (var i = 0; i < stretches.length; i++)
        if (!indices.contains(i)) stretches[i],
    ]);
  }

  /// PocketTopo's "Renumber": reassigns the stations of all stretches
  /// following the one at [index], continuing from the station that one
  /// stands for. Rows continuing where the previous row ended are numbered
  /// in sequence: cross sections move to the current station, survey shots
  /// lead on to the next station and keep their direction. Rows continuing
  /// elsewhere, like the dummy rows of Start Here and Continue Here, only
  /// take over the new numbers of stations renumbered before them, and the
  /// numbering goes on from where they lead.
  Survey renumberFrom(int index) {
    final renumbered = List<MeasuredDistance>.from(stretches);
    // New numbers of the stations survey shots lead to, by old number
    final moved = <Point, Point>{};
    Point newNumber(Point old) => moved[old] ?? old;

    var current = renumbered[index].station;
    // The station the previous row stood for before renumbering; unknown
    // for the row the renumbering starts at, which may have been edited
    Point? previous;
    for (var i = index + 1; i < renumbered.length; i++) {
      final stretch = renumbered[i];
      final to = stretch.to;
      final start = stretch.isBackward ? to! : stretch.from;
      final startsSeries =
          to != null && to.corridorId != stretch.from.corridorId;
      final continues = previous == null || start == previous;
      previous = stretch.station;

      if (startsSeries || !continues) {
        renumbered[i] = stretch.copyWith(
          from: newNumber(stretch.from),
          to: to == null ? null : newNumber(to),
        );
        current = renumbered[i].station;
      } else if (to == null) {
        renumbered[i] = stretch.copyWith(from: current);
      } else {
        final next = current.next;
        moved[stretch.station] = next;
        renumbered[i] = stretch.isBackward
            ? stretch.copyWith(from: next, to: current)
            : stretch.copyWith(from: current, to: next);
        current = next;
      }
    }
    return copyWith(stretches: renumbered);
  }

  /// The cross section measurements and splays taken at [station]
  Iterable<MeasuredDistance> splaysAt(Point station) =>
      stretches.where((s) => s.to == null && s.from == station);

  /// The azimuth in degrees the passage runs in at [station]: the bisector
  /// of the first survey shot leading to it and the first one leading on
  /// from it, both taken in the direction the survey progressed. Further
  /// shots, like branches or a second shot closing a loop, are ignored. A
  /// steep shot counts less, a vertical one not at all. Null if neither shot
  /// has a horizontal direction, or they point in opposite directions.
  double? passageAzimuth(Point station) {
    final shots = stretches.where((s) => s.to != null);
    final leadingTo = shots.where((s) => s.station == station).firstOrNull;
    final leadingOn = shots
        .where((s) =>
            s.station != station && (s.from == station || s.to == station))
        .firstOrNull;

    var east = 0.0, north = 0.0;
    for (final s in [?leadingTo, ?leadingOn]) {
      // A backward shot was measured against the survey direction
      final backward = s.station == s.from;
      final azimuth =
          (s.azimut.toDouble() + (backward ? 180 : 0)) * math.pi / 180;
      final horizontal =
          math.cos(s.inclination.toDouble() * math.pi / 180).abs();
      east += horizontal * math.sin(azimuth);
      north += horizontal * math.cos(azimuth);
    }
    if (east.abs() < 1e-9 && north.abs() < 1e-9) return null;
    return math.atan2(east, north) * 180 / math.pi;
  }

  /// Whether a survey shot leads to [station], which [flip] would turn around
  bool canFlip(Point station) =>
      stretches.any((s) => s.to != null && s.station == station);

  /// Turns around the side view direction of the survey shot leading to
  /// [station]. Applying it again restores the direction.
  Survey flip(Point station) => copyWith(stretches: [
        for (final s in stretches)
          s.to != null && s.station == station
              ? s.copyWith(flipped: !s.flipped)
              : s,
      ]);

  /// Turns around the side view direction of the survey shot leading to
  /// [station] and of all shots following it in the same series, so they
  /// all run opposite to where that shot ran. Applying it again turns them
  /// all back. Starting from a station no shot leads to, the first
  /// following shot decides the direction.
  Survey flipAll(Point station) {
    bool follows(MeasuredDistance s) =>
        s.to != null &&
        s.station.corridorId == station.corridorId &&
        s.station.pointId >= station.pointId;

    final following = stretches.where(follows).toList()
      ..sort((a, b) => a.station.compareTo(b.station));
    if (following.isEmpty) return this;
    final flipped = !following.first.flipped;
    return copyWith(stretches: [
      for (final s in stretches)
        follows(s) ? s.copyWith(flipped: flipped) : s,
    ]);
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

  Survey removeReferencePointsAt(Set<int> indices) {
    return copyWith(referencePoints: [
      for (var i = 0; i < referencePoints.length; i++)
        if (!indices.contains(i)) referencePoints[i],
    ]);
  }
}
