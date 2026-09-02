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
