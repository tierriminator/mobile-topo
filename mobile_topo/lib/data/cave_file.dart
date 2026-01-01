/// Area structure for cave.json - contains section references, not full sections.
class AreaRef {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<AreaRef> subAreas;
  final List<String> sectionIds;

  const AreaRef({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    this.subAreas = const [],
    this.sectionIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'subAreas': subAreas.map((a) => a.toJson()).toList(),
        'sectionIds': sectionIds,
      };

  factory AreaRef.fromJson(Map<String, dynamic> json) => AreaRef(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
        subAreas: (json['subAreas'] as List?)
                ?.map((a) => AreaRef.fromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
        sectionIds: (json['sectionIds'] as List?)
                ?.map((s) => s as String)
                .toList() ??
            const [],
      );
}

/// Cave metadata and hierarchy for JSON serialization.
/// Contains area structure with section references (IDs only).
class CaveFile {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<AreaRef> areas;
  final List<String> rootSectionIds;

  const CaveFile({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.modifiedAt,
    this.areas = const [],
    this.rootSectionIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'areas': areas.map((a) => a.toJson()).toList(),
        'rootSectionIds': rootSectionIds,
      };

  factory CaveFile.fromJson(Map<String, dynamic> json) => CaveFile(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
        areas: (json['areas'] as List?)
                ?.map((a) => AreaRef.fromJson(a as Map<String, dynamic>))
                .toList() ??
            const [],
        rootSectionIds: (json['rootSectionIds'] as List?)
                ?.map((s) => s as String)
                .toList() ??
            const [],
      );
}
