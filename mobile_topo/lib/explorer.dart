import 'sketching.dart';
import 'topo.dart';

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

/// Represents the path to an item in the explorer hierarchy
class ExplorerPath {
  final String caveId;
  final List<String> areaIds;
  final String? sectionId;

  const ExplorerPath({
    required this.caveId,
    this.areaIds = const [],
    this.sectionId,
  });

  /// Create a path to a cave root
  factory ExplorerPath.cave(String caveId) {
    return ExplorerPath(caveId: caveId);
  }

  /// Create a child path by adding an area
  ExplorerPath enterArea(String areaId) {
    return ExplorerPath(
      caveId: caveId,
      areaIds: [...areaIds, areaId],
      sectionId: null,
    );
  }

  /// Create a path pointing to a section
  ExplorerPath toSection(String sectionId) {
    return ExplorerPath(
      caveId: caveId,
      areaIds: areaIds,
      sectionId: sectionId,
    );
  }

  /// Go up one level (remove last area or section)
  ExplorerPath? parent() {
    if (sectionId != null) {
      return ExplorerPath(caveId: caveId, areaIds: areaIds);
    }
    if (areaIds.isNotEmpty) {
      return ExplorerPath(
        caveId: caveId,
        areaIds: areaIds.sublist(0, areaIds.length - 1),
      );
    }
    return null; // Already at cave root
  }

  /// Check if this path points to a section
  bool get isSection => sectionId != null;

  /// Check if this path is at cave root
  bool get isAtCaveRoot => areaIds.isEmpty && sectionId == null;

  /// Get the depth of this path (0 = cave root)
  int get depth => areaIds.length + (sectionId != null ? 1 : 0);
}

/// The explorer state holding all caves
class ExplorerState {
  final List<Cave> caves;
  final ExplorerPath? currentPath;

  const ExplorerState({
    this.caves = const [],
    this.currentPath,
  });

  ExplorerState copyWith({
    List<Cave>? caves,
    ExplorerPath? currentPath,
  }) {
    return ExplorerState(
      caves: caves ?? this.caves,
      currentPath: currentPath ?? this.currentPath,
    );
  }

  /// Add a new cave
  ExplorerState addCave(Cave cave) {
    return copyWith(caves: [...caves, cave]);
  }

  /// Find a cave by ID
  Cave? findCave(String caveId) {
    for (final cave in caves) {
      if (cave.id == caveId) return cave;
    }
    return null;
  }

  /// Get the currently selected section (if any)
  Section? get currentSection {
    if (currentPath == null || !currentPath!.isSection) return null;

    final cave = findCave(currentPath!.caveId);
    if (cave == null) return null;

    // Navigate to the correct area
    dynamic current = cave;
    for (final areaId in currentPath!.areaIds) {
      if (current is Cave) {
        current = current.areas.where((a) => a.id == areaId).firstOrNull;
      } else if (current is Area) {
        current = current.subAreas.where((a) => a.id == areaId).firstOrNull;
      }
      if (current == null) return null;
    }

    // Find the section
    final sections = current is Cave ? current.sections : (current as Area).sections;
    return sections.where((s) => s.id == currentPath!.sectionId).firstOrNull;
  }
}
