import '../topo.dart';

/// Section metadata and survey data for JSON serialization.
/// Sketches are stored separately as binary files.
class SectionFile {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final Survey survey;

  const SectionFile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.survey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'survey': survey.toJson(),
      };

  factory SectionFile.fromJson(Map<String, dynamic> json) => SectionFile(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
        survey: Survey.fromJson(json['survey'] as Map<String, dynamic>),
      );
}
