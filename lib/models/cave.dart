import 'sketch.dart';
import 'survey.dart';

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
  final DateTime createdAt;
  final DateTime modifiedAt;

  const Cave({
    required this.id,
    required this.name,
    this.description,
    this.areas = const [],
    this.sections = const [],
    required this.createdAt,
    required this.modifiedAt,
  });

  Cave copyWith({
    String? name,
    String? description,
    List<Area>? areas,
    List<Section>? sections,
    DateTime? modifiedAt,
  }) {
    return Cave(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      areas: areas ?? this.areas,
      sections: sections ?? this.sections,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

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
