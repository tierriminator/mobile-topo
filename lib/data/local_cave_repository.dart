import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/cave.dart';
import '../models/sketch.dart';
import '../models/trip.dart';
import 'cave_file.dart';
import 'cave_repository.dart';
import 'section_file.dart';
import 'sketch_serialization.dart';

/// File-based implementation of CaveRepository.
///
/// Directory structure:
/// ```
/// app_data/
/// └── caves/
///     └── {cave-id}/
///         ├── cave.json
///         ├── trips/
///         │   └── {trip-id}.json
///         └── sections/
///             └── {section-id}/
///                 ├── section.json
///                 ├── outline.sketch
///                 └── sideview.sketch
/// ```
class LocalCaveRepository implements CaveRepository {
  Directory? _baseDir;

  // The latest queued write of each section, by cave and section ID. Writes
  // to a section run one after the other in the order they were requested,
  // so they never overlap and the last requested state ends up on disk.
  final Map<String, Future<void>> _sectionWrites = {};

  Future<void> _queueSectionWrite(
      String caveId, String sectionId, Future<void> Function() write) {
    final key = '$caveId/$sectionId';
    final previous = _sectionWrites[key] ?? Future<void>.value();
    // A failed write must not block the ones after it
    final next = previous.catchError((_) {}).then((_) => write());
    _sectionWrites[key] = next;
    return next;
  }

  Future<Directory> get _cavesDir async {
    if (_baseDir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDir = Directory('${appDir.path}/caves');
    }
    if (!await _baseDir!.exists()) {
      await _baseDir!.create(recursive: true);
    }
    return _baseDir!;
  }

  Directory _caveDir(Directory cavesDir, String caveId) {
    return Directory('${cavesDir.path}/$caveId');
  }

  File _caveFile(Directory caveDir) {
    return File('${caveDir.path}/cave.json');
  }

  Directory _tripsDir(Directory caveDir) {
    return Directory('${caveDir.path}/trips');
  }

  File _tripFile(Directory tripsDir, String tripId) {
    return File('${tripsDir.path}/$tripId.json');
  }

  Directory _sectionsDir(Directory caveDir) {
    return Directory('${caveDir.path}/sections');
  }

  Directory _sectionDir(Directory sectionsDir, String sectionId) {
    return Directory('${sectionsDir.path}/$sectionId');
  }

  File _sectionFile(Directory sectionDir) {
    return File('${sectionDir.path}/section.json');
  }

  File _outlineSketchFile(Directory sectionDir) {
    return File('${sectionDir.path}/outline.sketch');
  }

  File _sideViewSketchFile(Directory sectionDir) {
    return File('${sectionDir.path}/sideview.sketch');
  }

  @override
  Future<List<CaveSummary>> listCaves() async {
    final cavesDir = await _cavesDir;
    final summaries = <CaveSummary>[];

    if (!await cavesDir.exists()) {
      return summaries;
    }

    await for (final entity in cavesDir.list()) {
      if (entity is Directory) {
        final caveFile = _caveFile(entity);
        if (await caveFile.exists()) {
          try {
            final json = jsonDecode(await caveFile.readAsString());
            final cave = CaveFile.fromJson(json as Map<String, dynamic>);
            summaries.add(CaveSummary(
              id: cave.id,
              name: cave.name,
              description: cave.description,
              createdAt: cave.createdAt,
              modifiedAt: cave.modifiedAt,
              sectionCount: _countSections(cave),
            ));
          } catch (e) {
            // Skip invalid cave files
          }
        }
      }
    }

    return summaries;
  }

  int _countSections(CaveFile cave) {
    int count = cave.rootSectionIds.length;
    for (final area in cave.areas) {
      count += _countAreaSections(area);
    }
    return count;
  }

  int _countAreaSections(AreaRef area) {
    int count = area.sectionIds.length;
    for (final subArea in area.subAreas) {
      count += _countAreaSections(subArea);
    }
    return count;
  }

  @override
  Future<Cave?> getCave(String caveId) async {
    final cavesDir = await _cavesDir;
    final caveDir = _caveDir(cavesDir, caveId);
    final caveFile = _caveFile(caveDir);

    if (!await caveFile.exists()) {
      return null;
    }

    final json = jsonDecode(await caveFile.readAsString());
    final caveData = CaveFile.fromJson(json as Map<String, dynamic>);

    // Load all sections
    final sectionsDir = _sectionsDir(caveDir);
    final sections = <String, Section>{};

    if (await sectionsDir.exists()) {
      await for (final entity in sectionsDir.list()) {
        if (entity is Directory) {
          final sectionId = entity.path.split('/').last;
          final section = await _loadSection(entity);
          if (section != null) {
            sections[sectionId] = section;
          }
        }
      }
    }

    // Build cave domain model
    return _buildCave(caveData, sections, await _loadTrips(caveDir));
  }

  /// All trips of a cave, in the order they were created
  Future<List<Trip>> _loadTrips(Directory caveDir) async {
    final tripsDir = _tripsDir(caveDir);
    final trips = <Trip>[];
    if (!await tripsDir.exists()) return trips;

    await for (final entity in tripsDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final json = jsonDecode(await entity.readAsString());
          trips.add(Trip.fromJson(json as Map<String, dynamic>));
        } catch (e) {
          // Skip invalid trip files
        }
      }
    }
    trips.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return trips;
  }

  Future<Section?> _loadSection(Directory sectionDir) async {
    final sectionFile = _sectionFile(sectionDir);
    if (!await sectionFile.exists()) {
      return null;
    }

    final json = jsonDecode(await sectionFile.readAsString());
    final sectionData = SectionFile.fromJson(json as Map<String, dynamic>);

    // Load sketches
    Sketch outlineSketch = const Sketch();
    Sketch sideViewSketch = const Sketch();

    final outlineFile = _outlineSketchFile(sectionDir);
    if (await outlineFile.exists()) {
      final bytes = await outlineFile.readAsBytes();
      outlineSketch = SketchSerializer.sketchFromBytes(bytes);
    }

    final sideViewFile = _sideViewSketchFile(sectionDir);
    if (await sideViewFile.exists()) {
      final bytes = await sideViewFile.readAsBytes();
      sideViewSketch = SketchSerializer.sketchFromBytes(bytes);
    }

    return Section(
      id: sectionData.id,
      name: sectionData.name,
      createdAt: sectionData.createdAt,
      modifiedAt: sectionData.modifiedAt,
      survey: sectionData.survey,
      outlineSketch: outlineSketch,
      sideViewSketch: sideViewSketch,
    );
  }

  Cave _buildCave(
      CaveFile caveData, Map<String, Section> sections, List<Trip> trips) {
    return Cave(
      id: caveData.id,
      name: caveData.name,
      description: caveData.description,
      createdAt: caveData.createdAt,
      modifiedAt: caveData.modifiedAt,
      trips: trips,
      areas: caveData.areas.map((a) => _buildArea(a, sections)).toList(),
      sections: caveData.rootSectionIds
          .map((id) => sections[id])
          .whereType<Section>()
          .toList(),
    );
  }

  Area _buildArea(AreaRef areaData, Map<String, Section> sections) {
    return Area(
      id: areaData.id,
      name: areaData.name,
      createdAt: areaData.createdAt,
      modifiedAt: areaData.modifiedAt,
      subAreas: areaData.subAreas.map((a) => _buildArea(a, sections)).toList(),
      sections: areaData.sectionIds
          .map((id) => sections[id])
          .whereType<Section>()
          .toList(),
    );
  }

  @override
  Future<void> saveCave(Cave cave) async {
    final cavesDir = await _cavesDir;
    final caveDir = _caveDir(cavesDir, cave.id);

    // Ensure directories exist
    if (!await caveDir.exists()) {
      await caveDir.create(recursive: true);
    }

    // Build cave file data
    final caveData = CaveFile(
      id: cave.id,
      name: cave.name,
      description: cave.description,
      createdAt: cave.createdAt,
      modifiedAt: cave.modifiedAt,
      areas: cave.areas.map(_buildAreaRef).toList(),
      rootSectionIds: cave.sections.map((s) => s.id).toList(),
    );

    // Write cave.json
    final caveFile = _caveFile(caveDir);
    await caveFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(caveData.toJson()),
    );

    // Collect all sections
    final allSections = <Section>[];
    _collectSections(cave, allSections);

    // Write all sections
    final sectionsDir = _sectionsDir(caveDir);
    for (final section in allSections) {
      await _queueSectionWrite(
          cave.id, section.id, () => _saveSection(sectionsDir, section));
    }

    // Write all trips
    final tripsDir = _tripsDir(caveDir);
    for (final trip in cave.trips) {
      await _saveTrip(tripsDir, trip);
    }
  }

  @override
  Future<void> saveTrip(String caveId, Trip trip) async {
    final cavesDir = await _cavesDir;
    await _saveTrip(_tripsDir(_caveDir(cavesDir, caveId)), trip);
  }

  Future<void> _saveTrip(Directory tripsDir, Trip trip) async {
    if (!await tripsDir.exists()) {
      await tripsDir.create(recursive: true);
    }
    await _tripFile(tripsDir, trip.id).writeAsString(
      const JsonEncoder.withIndent('  ').convert(trip.toJson()),
    );
  }

  @override
  Future<void> deleteTrip(String caveId, String tripId) async {
    final cavesDir = await _cavesDir;
    final tripFile =
        _tripFile(_tripsDir(_caveDir(cavesDir, caveId)), tripId);
    if (await tripFile.exists()) {
      await tripFile.delete();
    }
  }

  void _collectSections(Cave cave, List<Section> sections) {
    sections.addAll(cave.sections);
    for (final area in cave.areas) {
      _collectAreaSections(area, sections);
    }
  }

  void _collectAreaSections(Area area, List<Section> sections) {
    sections.addAll(area.sections);
    for (final subArea in area.subAreas) {
      _collectAreaSections(subArea, sections);
    }
  }

  AreaRef _buildAreaRef(Area area) {
    return AreaRef(
      id: area.id,
      name: area.name,
      createdAt: area.createdAt,
      modifiedAt: area.modifiedAt,
      subAreas: area.subAreas.map(_buildAreaRef).toList(),
      sectionIds: area.sections.map((s) => s.id).toList(),
    );
  }

  Future<void> _saveSection(Directory sectionsDir, Section section) async {
    final sectionDir = _sectionDir(sectionsDir, section.id);
    if (!await sectionDir.exists()) {
      await sectionDir.create(recursive: true);
    }

    // Write section.json
    final sectionData = SectionFile(
      id: section.id,
      name: section.name,
      createdAt: section.createdAt,
      modifiedAt: section.modifiedAt,
      survey: section.survey,
    );

    final sectionFile = _sectionFile(sectionDir);
    await sectionFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(sectionData.toJson()),
    );

    // Write sketches
    final outlineFile = _outlineSketchFile(sectionDir);
    await outlineFile.writeAsBytes(SketchSerializer.sketchToBytes(section.outlineSketch));

    final sideViewFile = _sideViewSketchFile(sectionDir);
    await sideViewFile.writeAsBytes(SketchSerializer.sketchToBytes(section.sideViewSketch));
  }

  @override
  Future<void> deleteCave(String caveId) async {
    final cavesDir = await _cavesDir;
    final caveDir = _caveDir(cavesDir, caveId);

    if (await caveDir.exists()) {
      await caveDir.delete(recursive: true);
    }
  }

  @override
  Future<Section?> getSection(String caveId, String sectionId) async {
    final cavesDir = await _cavesDir;
    final caveDir = _caveDir(cavesDir, caveId);
    final sectionsDir = _sectionsDir(caveDir);
    final sectionDir = _sectionDir(sectionsDir, sectionId);

    return _loadSection(sectionDir);
  }

  @override
  Future<void> saveSection(String caveId, Section section) =>
      // Queued before anything is awaited, so the order of calls is kept
      _queueSectionWrite(caveId, section.id, () async {
        final cavesDir = await _cavesDir;
        await _saveSection(_sectionsDir(_caveDir(cavesDir, caveId)), section);
      });

  @override
  Future<void> deleteSection(String caveId, String sectionId) async {
    final cavesDir = await _cavesDir;
    final caveDir = _caveDir(cavesDir, caveId);
    final sectionsDir = _sectionsDir(caveDir);
    final sectionDir = _sectionDir(sectionsDir, sectionId);

    if (await sectionDir.exists()) {
      await sectionDir.delete(recursive: true);
    }
  }

  @override
  Future<Section> importSection(String caveId, Section section) async {
    // Import with original ID preserved
    await saveSection(caveId, section);
    return section;
  }

  @override
  Future<String> exportSection(String caveId, String sectionId) async {
    final cavesDir = await _cavesDir;
    final caveDir = _caveDir(cavesDir, caveId);
    final sectionsDir = _sectionsDir(caveDir);
    final sectionDir = _sectionDir(sectionsDir, sectionId);

    // For now, just return the directory path
    // TODO: Create a zip archive for sharing
    return sectionDir.path;
  }
}
