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
  final DateTime createdAt;
  final DateTime modifiedAt;

  const Cave({
    required this.id,
    required this.name,
    this.description,
    this.areas = const [],
    this.sections = const [],
    this.trips = const [],
    required this.createdAt,
    required this.modifiedAt,
  });

  Cave copyWith({
    String? name,
    String? description,
    List<Area>? areas,
    List<Section>? sections,
    List<Trip>? trips,
    DateTime? modifiedAt,
  }) {
    return Cave(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      areas: areas ?? this.areas,
      sections: sections ?? this.sections,
      trips: trips ?? this.trips,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  /// The trip with the given ID, or null if there is none
  Trip? findTrip(String? tripId) =>
      trips.where((t) => t.id == tripId).firstOrNull;

  /// The trip new measurements are assigned to: the most recently created
  /// one, if any
  Trip? get activeTrip => trips.lastOrNull;

  /// Add a trip, which becomes the active one
  Cave addTrip(Trip trip) {
    return copyWith(trips: [...trips, trip]);
  }

  /// Replace the trip with the same ID
  Cave replaceTrip(Trip trip) {
    return copyWith(trips: [for (final t in trips) t.id == trip.id ? trip : t]);
  }

  /// Remove a trip; if it was the active one, the previous trip becomes active
  Cave removeTrip(String tripId) {
    return copyWith(trips: [for (final t in trips) if (t.id != tripId) t]);
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
    final declinations = {for (final t in trips) t.id: t.declination};
    MeasuredDistance corrected(MeasuredDistance stretch) {
      final declination = declinations[stretch.tripId] ?? 0;
      if (declination == 0) return stretch;
      return stretch.copyWith(azimut: stretch.azimut + declination);
    }

    return Survey(
      stretches: [
        for (final s in all) ...s.survey.stretches.map(corrected),
      ],
      referencePoints: [for (final s in all) ...s.survey.referencePoints],
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
