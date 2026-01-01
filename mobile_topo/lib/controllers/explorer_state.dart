import '../models/cave.dart';
import '../models/explorer_path.dart';

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
