import '../models/cave.dart';

/// Metadata for a cave (without loading full section data).
class CaveSummary {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int sectionCount;

  const CaveSummary({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.modifiedAt,
    required this.sectionCount,
  });
}

/// Abstract repository for cave data persistence.
abstract class CaveRepository {
  /// List all caves (metadata only, sections not loaded).
  Future<List<CaveSummary>> listCaves();

  /// Load a complete cave with all its sections.
  Future<Cave?> getCave(String caveId);

  /// Save a cave (creates or updates).
  /// Also saves all sections that are part of the cave.
  Future<void> saveCave(Cave cave);

  /// Delete a cave and all its sections.
  Future<void> deleteCave(String caveId);

  /// Load a single section.
  Future<Section?> getSection(String caveId, String sectionId);

  /// Save a single section.
  /// The section must already be referenced in the cave hierarchy.
  Future<void> saveSection(String caveId, Section section);

  /// Delete a section.
  /// Note: This only deletes the section files, not the reference in cave.json.
  /// Call saveCave after removing the section from the hierarchy.
  Future<void> deleteSection(String caveId, String sectionId);

  /// Import a section from external source (e.g., shared file).
  /// Returns the imported section with its original ID preserved.
  Future<Section> importSection(String caveId, Section section);

  /// Export a section to a shareable format.
  /// Returns the path to the exported files or archive.
  Future<String> exportSection(String caveId, String sectionId);
}
