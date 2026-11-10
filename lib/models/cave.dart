import 'dart:math' as math;

import 'coordinate_system.dart';
import 'geo_position.dart';
import 'magnetic_declination.dart';
import 'series_problem.dart';
import 'series_range.dart';
import 'sketch.dart';
import 'survey.dart';
import 'trip.dart';

/// A section contains survey measurement data and drawings.
/// This is the leaf node in the explorer hierarchy (like a file).
class Section {
  final String id;
  final String name;
  final Survey survey;
  final Sketch outlineSketch;
  final Sketch sideViewSketch;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const Section({
    required this.id,
    required this.name,
    required this.survey,
    this.outlineSketch = const Sketch(),
    this.sideViewSketch = const Sketch(),
    required this.createdAt,
    required this.modifiedAt,
  });

  Section copyWith({
    String? name,
    Survey? survey,
    Sketch? outlineSketch,
    Sketch? sideViewSketch,
    DateTime? modifiedAt,
  }) {
    return Section(
      id: id,
      name: name ?? this.name,
      survey: survey ?? this.survey,
      outlineSketch: outlineSketch ?? this.outlineSketch,
      sideViewSketch: sideViewSketch ?? this.sideViewSketch,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }
}

/// An area is an optional organizational container (like a directory).
/// Areas can contain other areas (nested) and sections.
class Area {
  final String id;
  final String name;
  final List<Area> subAreas;
  final List<Section> sections;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const Area({
    required this.id,
    required this.name,
    this.subAreas = const [],
    this.sections = const [],
    required this.createdAt,
    required this.modifiedAt,
  });

  Area copyWith({
    String? name,
    List<Area>? subAreas,
    List<Section>? sections,
    DateTime? modifiedAt,
  }) {
    return Area(
      id: id,
      name: name ?? this.name,
      subAreas: subAreas ?? this.subAreas,
      sections: sections ?? this.sections,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  /// Add a sub-area
  Area addSubArea(Area area) {
    return copyWith(
      subAreas: [...subAreas, area],
      modifiedAt: DateTime.now(),
    );
  }

  /// Add a section
  Area addSection(Section section) {
    return copyWith(
      sections: [...sections, section],
      modifiedAt: DateTime.now(),
    );
  }

  /// Replace the section with the same ID (recursive)
  Area replaceSection(Section section) {
    return copyWith(
      subAreas: [for (final a in subAreas) a.replaceSection(section)],
      sections: [for (final s in sections) s.id == section.id ? section : s],
    );
  }

  /// Remove the section with the given ID (recursive)
  Area removeSection(String sectionId) {
    return copyWith(
      subAreas: [for (final a in subAreas) a.removeSection(sectionId)],
      sections: [for (final s in sections) if (s.id != sectionId) s],
    );
  }

  /// All sections in this area and its sub-areas (recursive)
  List<Section> get allSections => [
        ...sections,
        for (final subArea in subAreas) ...subArea.allSections,
      ];

  /// Check if this area is empty
  bool get isEmpty => subAreas.isEmpty && sections.isEmpty;

  /// Get total count of all items (recursive)
  int get totalItemCount {
    int count = sections.length;
    for (final subArea in subAreas) {
      count += 1 + subArea.totalItemCount;
    }
    return count;
  }
}

/// A cave is the top-level container (like a partition/root).
/// A cave contains areas and/or sections directly.
class Cave {
  final String id;
  final String name;
  final String? description;
  final List<Area> areas;
  final List<Section> sections;

  /// Trips in the order they were created
  final List<Trip> trips;

  /// The system the East and North of the reference points are given in
  final CoordinateSystem coordinateSystem;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const Cave({
    required this.id,
    required this.name,
    this.description,
    this.areas = const [],
    this.sections = const [],
    this.trips = const [],
    this.coordinateSystem = CoordinateSystem.swiss,
    required this.createdAt,
    required this.modifiedAt,
  });

  Cave copyWith({
    String? name,
    String? description,
    List<Area>? areas,
    List<Section>? sections,
    List<Trip>? trips,
    CoordinateSystem? coordinateSystem,
    DateTime? modifiedAt,
  }) {
    return Cave(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      areas: areas ?? this.areas,
      sections: sections ?? this.sections,
      trips: trips ?? this.trips,
      coordinateSystem: coordinateSystem ?? this.coordinateSystem,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  /// The trip with the given ID, or null if there is none
  Trip? findTrip(String? tripId) =>
      trips.where((t) => t.id == tripId).firstOrNull;

  /// The trip new measurements are assigned to: the one most recently
  /// created or made active, if any
  Trip? get activeTrip => trips.isEmpty
      ? null
      : trips.reduce(
          (a, b) => b.lastActivated.isBefore(a.lastActivated) ? a : b);

  /// Add a trip, which becomes the active one
  Cave addTrip(Trip trip) {
    return copyWith(trips: [...trips, trip]);
  }

  /// Replace the trip with the same ID
  Cave replaceTrip(Trip trip) {
    return copyWith(trips: [for (final t in trips) t.id == trip.id ? trip : t]);
  }

  /// Remove a trip; if it was the active one, the trip active before becomes
  /// active again
  Cave removeTrip(String tripId) {
    return copyWith(trips: [for (final t in trips) if (t.id != tripId) t]);
  }

  /// Surveyed length measured on the given trip across all sections,
  /// counted like [Survey.totalLength]
  double tripLength(String tripId) => Survey(
        stretches: [
          for (final s in allSections)
            for (final stretch in s.survey.stretches)
              if (stretch.tripId == tripId) stretch,
        ],
        referencePoints: const [],
      ).totalLength;

  /// The closed series ranges reserved by the trips other than the one
  /// with [tripId]; open ranges only bound their own trip's series
  List<SeriesRange> seriesReservedByOthers(String? tripId) => [
        for (final trip in trips)
          if (trip.id != tripId)
            for (final range in trip.reservedSeries)
              if (!range.isOpen) range,
      ];

  /// The trip each series belongs to: the trip of the "Start Here" dummy
  /// shot that started it ([MeasuredDistance.startsSeries]), the earliest
  /// by date if several did. A dummy shot only starts a series if it leads
  /// to the series' first station and no earlier trip measured in the
  /// series; otherwise it ties in with a series measured before, which is
  /// no more than measuring in it. Series no dummy shot of a known trip
  /// started, like the first one, belong to no trip.
  Map<num, String> get seriesTrips {
    final order = [...trips]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    final rank = {for (final (i, trip) in order.indexed) trip.id: i};

    // Per series, its first station and the earliest trip measuring in it;
    // reference points and stretches without a known trip count as earliest
    final firstPoints = <num, num>{};
    for (final section in allSections) {
      for (final station in section.survey.stations) {
        final first = firstPoints[station.corridorId];
        if (first == null || station.pointId < first) {
          firstPoints[station.corridorId] = station.pointId;
        }
      }
    }
    final firstMeasured = <num, int>{};
    void measured(Point station, int tripRank) {
      final earliest = firstMeasured[station.corridorId];
      if (earliest == null || tripRank < earliest) {
        firstMeasured[station.corridorId] = tripRank;
      }
    }

    for (final section in allSections) {
      for (final ref in section.survey.referencePoints) {
        measured(ref.id, -1);
      }
      for (final stretch in section.survey.stretches) {
        if (stretch.startsSeries) continue;
        final tripRank = rank[stretch.tripId] ?? -1;
        measured(stretch.from, tripRank);
        if (stretch.to != null) measured(stretch.to!, tripRank);
      }
    }

    final owners = <num, int>{};
    for (final section in allSections) {
      for (final stretch in section.survey.stretches) {
        final tripRank = rank[stretch.tripId];
        if (!stretch.startsSeries || tripRank == null) continue;
        final to = stretch.to!;
        final series = to.corridorId;
        if (to.pointId != firstPoints[series] ||
            tripRank > (firstMeasured[series] ?? tripRank)) {
          continue;
        }
        final owner = owners[series];
        if (owner == null || tripRank < owner) owners[series] = tripRank;
      }
    }
    return {
      for (final MapEntry(key: series, value: tripRank) in owners.entries)
        series: order[tripRank].id,
    };
  }

  /// What is wrong with the range at [index] of the reserved series of
  /// [trip], if anything, with [seriesTrips] as [Cave.seriesTrips] gives
  /// them. Only the last range may be open; an open range only bounds the
  /// trip's series from below, so nothing else is wrong with it. A closed
  /// range reserves its series, so it must not overlap another closed range
  /// of any trip nor hold a series another trip started. [trip] may differ
  /// from this cave's trip with its ID, as while it is being edited.
  SeriesProblem? rangeProblemOf(
      Trip trip, int index, Map<num, String> seriesTrips) {
    final ranges = trip.reservedSeries;
    final range = ranges[index];
    final last = range.last;
    if (last == null) {
      return index == ranges.length - 1 ? null : OpenRangeNotLast(range);
    }
    if (last < range.first) return RangeEndsBeforeStart(range);

    for (final (i, other) in ranges.indexed) {
      if (i != index && !other.isOpen && other.overlaps(range)) {
        return RangesOverlap(range, other);
      }
    }
    for (final other in trips) {
      if (other.id == trip.id) continue;
      for (final reserved in other.reservedSeries) {
        if (!reserved.isOpen && reserved.overlaps(range)) {
          return RangeOverlapsOtherTrip(range, reserved, other);
        }
      }
    }
    for (final MapEntry(key: series, value: tripId) in seriesTrips.entries) {
      final starter = findTrip(tripId);
      if (starter != null && starter.id != trip.id && range.contains(series)) {
        return RangeHoldsOtherSeries(range, series, starter);
      }
    }
    return null;
  }

  /// What is wrong with the reserved series of [trip], if anything: the
  /// first problem of its ranges ([rangeProblemOf]), else one of the series
  /// it started ([startedSeriesProblemOf]), with [seriesTrips] as
  /// [Cave.seriesTrips] gives them
  SeriesProblem? seriesProblemOf(Trip trip, [Map<num, String>? seriesTrips]) {
    // Without reserved series nothing can be wrong, so the series need not
    // be looked at
    if (trip.reservedSeries.isEmpty &&
        !trips.any((t) => t.reservedSeries.isNotEmpty)) {
      return null;
    }
    final owners = seriesTrips ?? this.seriesTrips;
    for (var i = 0; i < trip.reservedSeries.length; i++) {
      final problem = rangeProblemOf(trip, i, owners);
      if (problem != null) return problem;
    }
    return startedSeriesProblemOf(trip, owners);
  }

  /// What is wrong with a series [trip] started, as [seriesTrips] gives
  /// them, if anything: one its reserved series do not allow
  /// ([Trip.allowsSeries]) or one another trip's closed range holds
  SeriesProblem? startedSeriesProblemOf(
      Trip trip, Map<num, String> seriesTrips) {
    for (final MapEntry(key: series, value: tripId) in seriesTrips.entries) {
      if (tripId != trip.id) continue;
      final reservedBy = trips
          .where((t) =>
              t.id != trip.id &&
              t.reservedSeries.any((r) => !r.isOpen && r.contains(series)))
          .firstOrNull;
      if (reservedBy != null) return SeriesReservedByOther(series, reservedBy);
      if (!trip.allowsSeries(series)) return SeriesOutsideRanges(series);
    }
    return null;
  }

  /// Surveyed length of the whole cave, counted like [Survey.totalLength]
  double get totalLength => combinedSurvey.totalLength;

  /// Altitude difference between the highest and the lowest station
  double get heightDifference {
    final altitudes = combinedSurvey
        .computeStationPositions()
        .values
        .map((p) => p.altitude);
    if (altitudes.isEmpty) return 0;
    return altitudes.reduce(math.max) - altitudes.reduce(math.min);
  }

  /// Whether any stretch in this cave was measured on the given trip
  bool isTripUsed(String tripId) => allSections
      .any((s) => s.survey.stretches.any((stretch) => stretch.tripId == tripId));

  /// Add an area at the root level
  Cave addArea(Area area) {
    return copyWith(
      areas: [...areas, area],
      modifiedAt: DateTime.now(),
    );
  }

  /// Add a section at the root level
  Cave addSection(Section section) {
    return copyWith(
      sections: [...sections, section],
      modifiedAt: DateTime.now(),
    );
  }

  /// Replace the section with the same ID anywhere in the hierarchy
  Cave replaceSection(Section section) {
    return copyWith(
      areas: [for (final a in areas) a.replaceSection(section)],
      sections: [for (final s in sections) s.id == section.id ? section : s],
    );
  }

  /// Remove the section with the given ID anywhere in the hierarchy
  Cave removeSection(String sectionId) {
    return copyWith(
      areas: [for (final a in areas) a.removeSection(sectionId)],
      sections: [for (final s in sections) if (s.id != sectionId) s],
      modifiedAt: DateTime.now(),
    );
  }

  /// Trips the given section measured on, in the order they were created
  List<Trip> tripsUsedBy(Section section) {
    final ids = {for (final s in section.survey.stretches) s.tripId};
    return [for (final trip in trips) if (ids.contains(trip.id)) trip];
  }

  /// Trips the given section measured on but no other section did, which
  /// are no longer used once the section is removed
  List<Trip> tripsOnlyUsedBy(String sectionId) {
    final section =
        allSections.where((s) => s.id == sectionId).firstOrNull;
    if (section == null) return const [];
    final rest = removeSection(sectionId);
    return [
      for (final trip in trips)
        if (section.survey.stretches.any((s) => s.tripId == trip.id) &&
            !rest.isTripUsed(trip.id))
          trip,
    ];
  }

  /// All sections in this cave, including those nested in areas
  List<Section> get allSections => [
        ...sections,
        for (final area in areas) ...area.allSections,
      ];

  /// The surveys of all sections merged into one, so stations shared between
  /// sections connect them into a single network. Each stretch's azimuth is
  /// corrected by the declination of its trip, so the result is ready for
  /// computing positions.
  Survey get combinedSurvey {
    final all = allSections;
    return corrected(Survey(
      stretches: [for (final s in all) ...s.survey.stretches],
      referencePoints: [for (final s in all) ...s.survey.referencePoints],
    ));
  }

  /// The first reference point of the cave's sections, which gives the
  /// cave's coordinates
  ReferencePoint? get firstReferencePoint => allSections
      .expand((s) => s.survey.referencePoints)
      .firstOrNull;

  /// The system the coordinates of [ref] were entered in
  CoordinateSystem systemOf(ReferencePoint ref) =>
      ref.coordinateSystem ?? coordinateSystem;

  /// The position of [ref], or null if its coordinates do not fit the
  /// system they were entered in, as local ones do not
  GeoPosition? positionOf(ReferencePoint ref) =>
      systemOf(ref).toGeo(ref.east, ref.north);

  /// [ref] with East and North in [system], by default the cave's: the
  /// coordinates as entered if they are in it already or fit no system,
  /// converted otherwise
  ReferencePoint inCoordinateSystem(ReferencePoint ref,
      [CoordinateSystem? system]) {
    final target = system ?? coordinateSystem;
    if (systemOf(ref) == target) return ref;
    final position = positionOf(ref);
    if (position == null) return ref;
    final (:east, :north) = target.fromGeo(position);
    return ref.copyWith(east: east, north: north, coordinateSystem: target);
  }

  /// The reference point to store after [original], as shown by
  /// [inCoordinateSystem], was edited to [edited]: in the cave's system if
  /// East or North changed, otherwise with the coordinates as entered, so
  /// they are not converted needlessly
  ReferencePoint editedReferencePoint(
      ReferencePoint original, ReferencePoint edited) {
    final shown = inCoordinateSystem(original);
    if (edited.east != shown.east || edited.north != shown.north) {
      return edited;
    }
    return original.copyWith(id: edited.id, altitude: edited.altitude);
  }

  /// The position of the [firstReferencePoint], or null if there is none or
  /// it fits no coordinate system
  GeoPosition? get referencePosition {
    final ref = firstReferencePoint;
    return ref == null ? null : positionOf(ref);
  }

  /// Where the automatic declination is computed: at the
  /// [referencePosition], else at the Hölloch
  GeoPosition get declinationPosition =>
      referencePosition ?? GeoPosition.hoelloch;

  /// The system positions are computed in: the [coordinateSystem], or for
  /// degrees the UTM zone of the [declinationPosition]
  CoordinateSystem get _metricSystem => coordinateSystem.isMetric
      ? coordinateSystem
      : Utm.containing(declinationPosition);

  /// The azimuth of true north against grid north at the
  /// [declinationPosition], which turns a declination against true north
  /// into one against grid north. Without a usable reference point, the
  /// cave is taken to lie at the Hölloch in its coordinate system, as for
  /// the declination itself.
  double get gridConvergence =>
      _metricSystem.trueNorthAzimuth(declinationPosition);

  /// The magnetic declination against true north on [date] at the
  /// [declinationPosition]
  double automaticDeclination(DateTime date) =>
      MagneticDeclination.at(declinationPosition, date);

  /// The declination against grid north applied to the stretches of
  /// [trip]: computed from its date if it is automatic, its own otherwise,
  /// which is given against map north as in PocketTopo
  num declinationOf(Trip trip) => trip.autoDeclination
      ? automaticDeclination(trip.date) + gridConvergence
      : trip.declination;

  /// [survey] ready for computing positions: each stretch's azimuth
  /// corrected by the declination of its trip, and reference points in
  /// metres of the cave's coordinate system, or for one in degrees of the
  /// UTM zone of the [declinationPosition], so the whole cave shares one
  /// grid
  Survey corrected(Survey survey) {
    final declinations = {for (final t in trips) t.id: declinationOf(t)};
    MeasuredDistance correct(MeasuredDistance stretch) {
      final declination = declinations[stretch.tripId] ?? 0;
      if (declination == 0) return stretch;
      return stretch.copyWith(azimut: stretch.azimut + declination);
    }

    final metric = _metricSystem;
    return survey.copyWith(
      stretches: survey.stretches.map(correct).toList(),
      referencePoints: [
        for (final ref in survey.referencePoints)
          inCoordinateSystem(ref, metric),
      ],
    );
  }

  /// Check if this cave is empty
  bool get isEmpty => areas.isEmpty && sections.isEmpty;

  /// Get total count of all items (recursive)
  int get totalItemCount {
    int count = sections.length;
    for (final area in areas) {
      count += 1 + area.totalItemCount;
    }
    return count;
  }
}
