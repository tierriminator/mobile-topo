import 'dart:math' as math;

import 'coordinate_system.dart';
import 'geo_position.dart';
import 'magnetic_declination.dart';
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

  /// The position of the [firstReferencePoint], or null if there is none or
  /// it does not fit the [coordinateSystem]
  GeoPosition? get referencePosition {
    final ref = firstReferencePoint;
    return ref == null ? null : coordinateSystem.toGeo(ref.east, ref.north);
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
  /// metres. Coordinates in degrees are converted to the UTM zone of the
  /// [declinationPosition] for this, so the whole cave shares one zone.
  Survey corrected(Survey survey) {
    final declinations = {for (final t in trips) t.id: declinationOf(t)};
    MeasuredDistance correct(MeasuredDistance stretch) {
      final declination = declinations[stretch.tripId] ?? 0;
      if (declination == 0) return stretch;
      return stretch.copyWith(azimut: stretch.azimut + declination);
    }

    final metric = Utm.containing(declinationPosition);
    ReferencePoint inMetres(ReferencePoint ref) {
      final position = coordinateSystem.toGeo(ref.east, ref.north);
      if (position == null) return ref;
      final (:east, :north) = metric.fromGeo(position);
      return ref.copyWith(east: east, north: north);
    }

    return survey.copyWith(
      stretches: survey.stretches.map(correct).toList(),
      referencePoints: coordinateSystem.isMetric
          ? survey.referencePoints
          : survey.referencePoints.map(inMetres).toList(),
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
