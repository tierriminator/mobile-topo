import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../controllers/explorer_state.dart';
import '../controllers/selection_state.dart';
import '../controllers/settings_controller.dart';
import '../controllers/view_navigation.dart';
import '../data/cave_repository.dart';
import '../data/pocket_topo_file.dart';
import '../data/settings_repository.dart';
import '../data/therion_file.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/explorer_path.dart';
import '../models/survey.dart';
import '../models/trip.dart';
import 'cave_page.dart';
import 'section_page.dart';
import 'trip_page.dart';
import 'widgets/choice_sheet.dart';

class ExplorerView extends StatefulWidget {
  const ExplorerView({super.key});

  @override
  State<ExplorerView> createState() => ExplorerViewState();
}

/// Public so that trips can be created from outside the explorer through a
/// GlobalKey
class ExplorerViewState extends State<ExplorerView> {
  final _uuid = const Uuid();

  // Explorer state with loaded caves
  ExplorerState _explorerState = const ExplorerState();

  // Track expanded state for tree nodes
  final Set<String> _expandedIds = {};

  // Loading state
  bool _isLoading = true;

  bool _initialized = false;

  late final SelectionState _selectionState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _selectionState = context.read<SelectionState>();
      _selectionState.addListener(_onSelectionChanged);
      _loadCaves();
    }
  }

  @override
  void dispose() {
    _selectionState.removeListener(_onSelectionChanged);
    super.dispose();
  }

  /// Keep the loaded caves in sync with edits made to the selected section
  /// and the cave's trips in other views.
  void _onSelectionChanged() {
    final selectedCave = _selectionState.selectedCave;
    final section = _selectionState.selectedSection;
    if (selectedCave == null || section == null) return;

    final cave = _explorerState.findCave(selectedCave.id);
    if (cave == null) return;
    final sectionSynced = cave.allSections.any((s) => identical(s, section));
    final tripsSynced = identical(cave.trips, selectedCave.trips);
    if (sectionSynced && tripsSynced) return;

    setState(() {
      _explorerState = _explorerState.copyWith(caves: [
        for (final c in _explorerState.caves)
          c.id == cave.id
              ? c.replaceSection(section).copyWith(trips: selectedCave.trips)
              : c,
      ]);
    });
  }

  Future<void> _loadCaves() async {
    setState(() => _isLoading = true);

    final repository = context.read<CaveRepository>();
    final summaries = await repository.listCaves();
    final caves = <Cave>[];

    for (final summary in summaries) {
      final cave = await repository.getCave(summary.id);
      if (cave != null) {
        caves.add(cave);
      }
    }

    setState(() {
      _explorerState = ExplorerState(caves: caves);
      _isLoading = false;
    });

    // Restore previously selected section
    _restoreSelection(caves);
  }

  /// Restore the previously selected section from settings
  void _restoreSelection(List<Cave> caves) {
    final settingsController = context.read<SettingsController>();
    final caveId = settingsController.lastSelectedCaveId;
    final sectionId = settingsController.lastSelectedSectionId;

    if (caveId == null || sectionId == null) return;

    // Find the cave
    final cave = caves.where((c) => c.id == caveId).firstOrNull;
    if (cave == null) return;

    // Find the section and path to it
    final result = _findSectionInCave(cave, sectionId);
    if (result == null) return;

    final (section, path, expandIds) = result;

    setState(() {
      _explorerState = _explorerState.copyWith(currentPath: path);
      _expandedIds.addAll(expandIds);
    });

    // Update shared selection state
    context.read<SelectionState>().selectSection(cave, section);
  }

  /// Find a section in a cave, returning the section, path, and IDs to expand
  (Section, ExplorerPath, Set<String>)? _findSectionInCave(
    Cave cave,
    String sectionId,
  ) {
    final expandIds = <String>{cave.id};

    // Check direct sections
    for (final section in cave.sections) {
      if (section.id == sectionId) {
        return (section, ExplorerPath.cave(cave.id).toSection(section.id), expandIds);
      }
    }

    // Check sections in areas recursively
    for (final area in cave.areas) {
      final result = _findSectionInArea(
        area,
        sectionId,
        ExplorerPath.cave(cave.id),
        expandIds,
      );
      if (result != null) return result;
    }

    return null;
  }

  /// Find a section in an area recursively
  (Section, ExplorerPath, Set<String>)? _findSectionInArea(
    Area area,
    String sectionId,
    ExplorerPath parentPath,
    Set<String> expandIds,
  ) {
    final currentPath = parentPath.enterArea(area.id);
    final currentExpandIds = {...expandIds, area.id};

    // Check direct sections
    for (final section in area.sections) {
      if (section.id == sectionId) {
        return (section, currentPath.toSection(section.id), currentExpandIds);
      }
    }

    // Check sub-areas recursively
    for (final subArea in area.subAreas) {
      final result = _findSectionInArea(
        subArea,
        sectionId,
        currentPath,
        currentExpandIds,
      );
      if (result != null) return result;
    }

    return null;
  }

  /// Creates a cave with the default name and opens its page, editing the
  /// name
  Future<void> _createNewCave() async {
    final l10n = AppLocalizations.of(context)!;
    final repository = context.read<CaveRepository>();
    final coordinateSystem =
        context.read<SettingsController>().defaultCoordinateSystem;
    final now = DateTime.now();

    final cave = Cave(
      id: _uuid.v4(),
      name: l10n.explorerNewCave,
      coordinateSystem: coordinateSystem,
      createdAt: now,
      modifiedAt: now,
    );

    await repository.saveCave(cave);
    await _loadCaves();

    // Expand the new cave
    setState(() {
      _expandedIds.add(cave.id);
    });

    final loaded = _explorerState.findCave(cave.id);
    if (loaded == null || !mounted) return;
    await _openCave(loaded, editName: true);
  }

  /// Creates a section with the default name in [cave] and opens its page,
  /// editing the name
  Future<void> _createNewSection(Cave cave) async {
    final l10n = AppLocalizations.of(context)!;
    final repository = context.read<CaveRepository>();
    final now = DateTime.now();

    final section = Section(
      id: _uuid.v4(),
      name: l10n.explorerNewSection,
      survey: const Survey(stretches: [], referencePoints: []),
      createdAt: now,
      modifiedAt: now,
    );

    // Add section to cave
    final updatedCave = cave.addSection(section);
    await repository.saveCave(updatedCave);
    await _loadCaves();

    _showSections(cave);

    final loaded = _loadedSection(cave.id, section.id);
    if (loaded == null || !mounted) return;
    await _openSection(
        loaded, ExplorerPath.cave(cave.id).toSection(section.id),
        editName: true);
  }

  /// Imports the PocketTopo files the user picks, each as a new section of
  /// [cave] named after the file, in the order of their names. Their trips
  /// are added to the cave unless it already has the same trip.
  Future<void> _importPocketTopo(Cave cave) async {
    final l10n = AppLocalizations.of(context)!;
    final repository = context.read<CaveRepository>();
    final messenger = ScaffoldMessenger.of(context);

    // Not filtered by extension: platforms without a type for .top would
    // offer no file at all. The reader checks the contents instead.
    final files = [...await FilePicker.pickFiles()]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (files.isEmpty) return;

    var updatedCave = cave;
    var skipped = 0;
    final failures = <String>[];
    for (final file in files) {
      final PocketTopoImport imported;
      try {
        imported = PocketTopoFile.read(await file.readAsBytes())
            .withTripsFrom(updatedCave.trips);
      } on FormatException catch (e) {
        failures.add(l10n.importPocketTopoFailed(file.name, e.message));
        continue;
      }

      final now = DateTime.now();
      final name =
          file.name.replaceFirst(RegExp(r'\.top$', caseSensitive: false), '');
      final section = Section(
        id: _uuid.v4(),
        name: name.isEmpty ? l10n.explorerNewSection : name,
        // The file's coordinates are taken to be in the cave's system
        survey: imported.survey.withReferenceSystem(cave.coordinateSystem),
        outlineSketch: imported.outlineSketch,
        sideViewSketch: imported.sideViewSketch,
        createdAt: now,
        modifiedAt: now,
      );
      updatedCave = updatedCave
          .copyWith(trips: [...updatedCave.trips, ...imported.trips])
          .addSection(section);
      skipped += imported.skippedShots;
    }

    if (!identical(updatedCave, cave)) {
      await repository.saveCave(updatedCave);
      if (!mounted) return;
      context.read<SelectionState>().updateTrips(updatedCave);
      await _loadCaves();
      _showSections(cave);
    }

    final messages = [
      ...failures,
      if (skipped > 0) l10n.importPocketTopoSkipped(skipped),
    ];
    if (messages.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(messages.join('\n'))));
    }
  }

  /// Lets the user save [sections] of [cave] for Therion under [name]:
  /// as a survey file, or as the text PocketTopo exports for xtherion if
  /// [pocketTopoText] is set
  Future<void> _exportTherion(Cave cave, List<Section> sections, String name,
      {required bool pocketTopoText}) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final contents = pocketTopoText
        ? TherionFile.pocketTopoText(cave, sections)
        : TherionFile.survey(cave, sections, name);
    final baseName = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    try {
      await FilePicker.saveFile(
        fileName: '${baseName.isEmpty ? 'survey' : baseName}'
            '${pocketTopoText ? '.txt' : '.th'}',
        bytes: utf8.encode(contents),
        mimeType: 'text/plain',
      );
    } on Exception catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))));
    }
  }

  /// Asks whether to add an empty section to [cave] or to import PocketTopo
  /// files as new sections, and does so
  Future<void> _addSection(Cave cave) async {
    final l10n = AppLocalizations.of(context)!;
    final import = await showChoiceSheet(
      context,
      title: l10n.explorerAddSection,
      choices: [
        (
          value: false,
          icon: Icons.note_add,
          label: l10n.explorerNewSection,
          help: l10n.explorerNewSectionHelp,
        ),
        (
          value: true,
          icon: Icons.file_open,
          label: l10n.explorerImportPocketTopo,
          help: l10n.explorerImportPocketTopoHelp,
        ),
      ],
    );
    if (import == null || !mounted) return;
    // The cave may have changed while the sheet was open
    final current = _explorerState.findCave(cave.id) ?? cave;
    if (import) {
      await _importPocketTopo(current);
    } else {
      await _createNewSection(current);
    }
  }

  /// Expansion key of a cave's sections node, which unlike the others
  /// starts expanded
  String _sectionsNodeId(Cave cave) => '${cave.id}/sections';

  /// Sections nodes the user collapsed
  final Set<String> _collapsedSectionNodes = {};

  void _toggleSectionsNode(Cave cave) {
    final id = _sectionsNodeId(cave);
    setState(() {
      if (!_collapsedSectionNodes.remove(id)) _collapsedSectionNodes.add(id);
    });
  }

  /// Shows the sections of [cave], as after adding one
  void _showSections(Cave cave) {
    setState(() {
      _expandedIds.add(cave.id);
      _collapsedSectionNodes.remove(_sectionsNodeId(cave));
    });
  }

  /// Expansion key of a cave's trips node
  String _tripsNodeId(Cave cave) => '${cave.id}/trips';

  /// Shows the trip changes of [cave] here and in the other views
  void _applyTrips(Cave cave) {
    setState(() {
      _explorerState = _explorerState.copyWith(caves: [
        for (final c in _explorerState.caves)
          c.id == cave.id ? c.copyWith(trips: cave.trips) : c,
      ]);
    });
    context.read<SelectionState>().updateTrips(cave);
  }

  /// Creates a trip, which new measurements are assigned to from now on,
  /// and opens it for editing
  Future<void> _createTrip(Cave cave) async {
    final repository = context.read<CaveRepository>();
    final now = DateTime.now();

    // The declination is computed for the trip's date. Should it be set by
    // hand, the latest trip's value is a good starting point, as it changes
    // slowly.
    final trip = Trip(
      id: _uuid.v4(),
      date: DateUtils.dateOnly(now),
      declination: cave.activeTrip?.declination ?? 0,
      autoDeclination: true,
      createdAt: now,
    );

    _applyTrips(cave.addTrip(trip));
    setState(() {
      _expandedIds.addAll({cave.id, _tripsNodeId(cave)});
    });
    await repository.saveTrip(cave.id, trip);

    if (!mounted) return;
    await _editTrip(trip);
  }

  /// Creates a trip in the given cave and opens it for editing
  Future<void> createTrip(String caveId) async {
    final cave = _explorerState.findCave(caveId);
    if (cave != null) await _createTrip(cave);
  }

  /// The loaded cave a trip belongs to. Looked up by the trip rather than
  /// kept, as the cave may change while a trip page is open.
  Cave? _caveOfTrip(Trip trip) => _explorerState.caves
      .where((c) => c.findTrip(trip.id) != null)
      .firstOrNull;

  /// Opens a trip for editing and saves the changes
  Future<void> _editTrip(Trip trip) async {
    final repository = context.read<CaveRepository>();
    final opened = _caveOfTrip(trip);
    if (opened == null) return;
    final edited = await editTrip(context, opened, trip,
        onDelete: () => _deleteTrip(trip));
    if (edited == null || !mounted) return;

    final cave = _caveOfTrip(trip);
    if (cave == null) return;
    _applyTrips(cave.replaceTrip(edited));
    await repository.saveTrip(cave.id, edited);
  }

  /// Whether a trip may be deleted: only if no measurement refers to it.
  /// Explains why not otherwise.
  bool _canDeleteTrip(Trip trip) {
    final cave = _caveOfTrip(trip);
    if (cave == null) return false;
    if (cave.isTripUsed(trip.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.tripInUse)),
      );
      return false;
    }
    return true;
  }

  /// Deletes a trip no measurement refers to; returns whether it was deleted
  Future<bool> _deleteTrip(Trip trip) async {
    if (!_canDeleteTrip(trip)) return false;
    final cave = _caveOfTrip(trip)!;
    final repository = context.read<CaveRepository>();

    _applyTrips(cave.removeTrip(trip.id));
    await repository.deleteTrip(cave.id, trip.id);
    return true;
  }

  /// Opens the page of a cave, editing the name if [editName] is set, and
  /// saves its changed name and coordinate system
  Future<void> _openCave(Cave cave, {bool editName = false}) async {
    final repository = context.read<CaveRepository>();
    final selectionState = context.read<SelectionState>();

    final edited = await editCave(
      context,
      cave,
      editName: editName,
      onExport: (name, {required pocketTopoText}) async {
        final current = _explorerState.findCave(cave.id);
        if (current == null) return;
        await _exportTherion(current, current.allSections, name,
            pocketTopoText: pocketTopoText);
      },
      onDelete: () => _deleteCave(cave),
      onShowReferencePoints: cave.allSections.isEmpty
          ? null
          : () => _showReferencePoints(cave.id),
    );
    if (edited == null || !mounted) return;

    // The cave may have changed while the page was open
    final current = _explorerState.findCave(cave.id);
    if (current == null) return;
    final updated = current.copyWith(
      name: edited.name,
      coordinateSystem: edited.coordinateSystem,
      modifiedAt: DateTime.now(),
    );
    setState(() {
      _explorerState = _explorerState.copyWith(caves: [
        for (final c in _explorerState.caves) c.id == cave.id ? updated : c,
      ]);
    });
    selectionState.updateCoordinateSystem(updated);
    await repository.saveCave(updated);
  }

  /// Shows the reference points of a cave in the data view, selecting the
  /// section of its first reference point, or else the selected section if
  /// it is in the cave, or else its first section
  void _showReferencePoints(String caveId) {
    final cave = _explorerState.findCave(caveId);
    if (cave == null) return;
    final sections = cave.allSections;
    final ref = cave.firstReferencePoint;
    final selected = context.read<SelectionState>().selectedSection;
    final section = sections
            .where((s) => s.survey.referencePoints.contains(ref))
            .firstOrNull ??
        sections.where((s) => s.id == selected?.id).firstOrNull ??
        sections.firstOrNull;
    if (section == null) return;
    final found = _findSectionInCave(cave, section.id);
    if (found == null) return;

    final (_, path, expandIds) = found;
    setState(() => _expandedIds.addAll(expandIds));
    _showSections(cave);
    _selectSection(path, section);
    context.read<ViewNavigation>().showReferencePoints(ref?.id);
  }

  /// Deletes a cave with everything in it after asking; returns whether it
  /// was deleted
  Future<bool> _deleteCave(Cave cave) async {
    final l10n = AppLocalizations.of(context)!;
    final repository = context.read<CaveRepository>();
    final selectionState = context.read<SelectionState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.explorerDeleteCaveTitle),
        content: Text(l10n.explorerDeleteCaveMessage(cave.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.explorerDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    setState(() {
      _explorerState = ExplorerState(
        caves: [
          for (final c in _explorerState.caves)
            if (c.id != cave.id) c,
        ],
        currentPath: _explorerState.currentPath?.caveId == cave.id
            ? null
            : _explorerState.currentPath,
      );
    });
    selectionState.removeCave(cave.id);

    await repository.deleteCave(cave.id);
    return true;
  }

  /// The loaded section with [sectionId] in the cave with [caveId], if any
  Section? _loadedSection(String caveId, String sectionId) => _explorerState
      .findCave(caveId)
      ?.allSections
      .where((s) => s.id == sectionId)
      .firstOrNull;

  /// Opens the page of a section, editing the name if [editName] is set,
  /// and saves its changed name
  Future<void> _openSection(Section section, ExplorerPath path,
      {bool editName = false}) async {
    final repository = context.read<CaveRepository>();
    final selectionState = context.read<SelectionState>();
    final cave = _explorerState.findCave(path.caveId);
    if (cave == null) return;

    final name = await editSection(
      context,
      cave,
      section,
      editName: editName,
      isSelected: _explorerState.currentPath?.sectionId == section.id,
      onSelect: () {
        final current = _loadedSection(cave.id, section.id);
        if (current != null) _selectSection(path, current);
      },
      onExport: (name, {required pocketTopoText}) async {
        final current = _loadedSection(cave.id, section.id);
        final latest = _explorerState.findCave(cave.id);
        if (current == null || latest == null) return;
        await _exportTherion(latest, [current], name,
            pocketTopoText: pocketTopoText);
      },
      onDelete: () => _deleteSection(section, cave.id),
    );
    if (name == null || !mounted) return;

    // The section may have changed while the page was open; the selected
    // one is changed through the selection, which the explorer follows
    Section rename(Section s) =>
        s.copyWith(name: name, modifiedAt: DateTime.now());
    var renamed = selectionState.changeSection(section.id, rename);
    if (renamed == null) {
      final current = _loadedSection(cave.id, section.id);
      if (current == null) return;
      renamed = rename(current);
      setState(() {
        _explorerState = _explorerState.copyWith(caves: [
          for (final c in _explorerState.caves)
            c.id == cave.id ? c.replaceSection(renamed!) : c,
        ]);
      });
    }
    await repository.saveSection(cave.id, renamed);
  }

  /// Deletes a section after asking, and the trips only it used unless the
  /// user keeps them; returns whether it was deleted
  Future<bool> _deleteSection(Section section, String caveId) async {
    final repository = context.read<CaveRepository>();
    final selectionState = context.read<SelectionState>();
    final cave = _explorerState.findCave(caveId);
    if (cave == null) return false;
    final unusedTrips = cave.tripsOnlyUsedBy(section.id);

    final deleteTrips = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteSectionDialog(
        sectionName: section.name,
        tripCount: unusedTrips.length,
      ),
    );
    if (deleteTrips == null || !mounted) return false;

    // The cave may have changed while the dialog was open
    var updatedCave =
        (_explorerState.findCave(caveId) ?? cave).removeSection(section.id);
    if (deleteTrips) {
      for (final trip in unusedTrips) {
        updatedCave = updatedCave.removeTrip(trip.id);
      }
    }

    setState(() {
      _explorerState = ExplorerState(
        caves: [
          for (final c in _explorerState.caves)
            c.id == caveId ? updatedCave : c,
        ],
        currentPath: _explorerState.currentPath?.sectionId == section.id
            ? null
            : _explorerState.currentPath,
      );
    });
    selectionState
      ..removeSection(caveId, section.id)
      ..updateTrips(updatedCave);

    await repository.saveCave(updatedCave);
    await repository.deleteSection(caveId, section.id);
    if (deleteTrips) {
      for (final trip in unusedTrips) {
        await repository.deleteTrip(caveId, trip.id);
      }
    }
    return true;
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _selectSection(ExplorerPath path, Section section) {
    setState(() {
      _explorerState = _explorerState.copyWith(currentPath: path);
    });

    // Update shared selection state
    final cave = _explorerState.findCave(path.caveId);
    if (cave != null) {
      context.read<SelectionState>().selectSection(cave, section);
    }

    // Persist the selection
    final settingsController = context.read<SettingsController>();
    settingsController.setLastSelectedSection(path.caveId, section.id);
    context.read<SettingsRepository>().save(settingsController.settings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Toolbar
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                l10n.explorerTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createNewCave,
                tooltip: l10n.explorerAddNew,
              ),
            ],
          ),
        ),
        // Tree view
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _explorerState.caves.isEmpty
                  ? Center(child: Text(l10n.explorerEmpty))
                  : ListView(
                      children: [
                        for (final cave in _explorerState.caves)
                          _buildCaveNode(cave),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildCaveNode(Cave cave) {
    final isExpanded = _expandedIds.contains(cave.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeTile(
          icon: Icons.landscape,
          iconColor: Colors.brown,
          label: cave.name,
          subtitle: cave.description,
          depth: 0,
          isExpanded: isExpanded,
          hasChildren: true, // Always show expand arrow for caves
          onTap: () => _toggleExpanded(cave.id),
          trailing: IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            style: _trailingButtonStyle,
            onPressed: () => _openCave(cave),
            tooltip: AppLocalizations.of(context)!.caveOverview,
          ),
        ),
        if (isExpanded) ...[
          _buildSectionsNode(cave),
          _buildTripsNode(cave),
        ],
      ],
    );
  }

  Widget _buildSectionsNode(Cave cave) {
    final l10n = AppLocalizations.of(context)!;
    final isExpanded =
        !_collapsedSectionNodes.contains(_sectionsNodeId(cave));
    final path = ExplorerPath.cave(cave.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeTile(
          icon: Icons.folder_copy,
          iconColor: Colors.blue,
          label: l10n.explorerSections,
          depth: 1,
          isExpanded: isExpanded,
          hasChildren: true,
          onTap: () => _toggleSectionsNode(cave),
          trailing: IconButton(
            icon: const Icon(Icons.add, size: 20),
            style: _trailingButtonStyle,
            onPressed: () => _addSection(cave),
            tooltip: l10n.explorerAddSection,
          ),
        ),
        if (isExpanded) ...[
          for (final area in cave.areas) _buildAreaNode(area, path, 2),
          for (final section in cave.sections)
            _buildSectionNode(section, path, 2),
          if (cave.isEmpty) _buildPlaceholder(l10n.explorerNoSections, 2),
        ],
      ],
    );
  }

  /// Italic hint shown in place of the children of an empty node, aligned
  /// with the labels of rows at [depth]
  Widget _buildPlaceholder(String text, int depth) {
    return Container(
      decoration: _rowDecoration(),
      constraints: const BoxConstraints(minHeight: _rowHeight),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 68.0 + depth * 24.0, right: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }

  Widget _buildTripsNode(Cave cave) {
    final l10n = AppLocalizations.of(context)!;
    final nodeId = _tripsNodeId(cave);
    final isExpanded = _expandedIds.contains(nodeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeTile(
          icon: Icons.event_note,
          iconColor: Colors.teal,
          label: l10n.explorerTrips,
          depth: 1,
          isExpanded: isExpanded,
          hasChildren: true,
          onTap: () => _toggleExpanded(nodeId),
          trailing: IconButton(
            icon: const Icon(Icons.add, size: 20),
            style: _trailingButtonStyle,
            onPressed: () => _createTrip(cave),
            tooltip: l10n.explorerAddTrip,
          ),
        ),
        if (isExpanded) ...[
          // Newest first
          for (final trip in cave.trips.reversed) _buildTripNode(cave, trip),
          if (cave.trips.isEmpty) _buildPlaceholder(l10n.explorerNoTrips, 2),
        ],
      ],
    );
  }

  /// A trip; tapping it opens it for editing. The active trip, which new
  /// measurements are assigned to, is marked as such. Swiping it left
  /// reveals a delete button, swiping it far deletes it right away.
  Widget _buildTripNode(Cave cave, Trip trip) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final label = tripLabel(context, trip);

    return Slidable(
      key: ValueKey(trip.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.2,
        dismissible: DismissiblePane(
          confirmDismiss: () async => _canDeleteTrip(trip),
          closeOnCancel: true,
          onDismissed: () => _deleteTrip(trip),
        ),
        children: [
          SlidableAction(
            onPressed: (_) => _deleteTrip(trip),
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
            icon: Icons.delete,
          ),
        ],
      ),
      child: _buildTreeTile(
        icon: Icons.event,
        iconColor: Colors.teal,
        label: identical(cave.activeTrip, trip)
            ? '$label ${l10n.tripActive}'
            : label,
        depth: 2,
        isExpanded: false,
        hasChildren: false,
        onTap: () => _editTrip(trip),
      ),
    );
  }

  Widget _buildAreaNode(Area area, ExplorerPath parentPath, int depth) {
    final isExpanded = _expandedIds.contains(area.id);
    final hasChildren = area.subAreas.isNotEmpty || area.sections.isNotEmpty;
    final currentPath = parentPath.enterArea(area.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeTile(
          icon: Icons.folder,
          iconColor: Colors.amber.shade700,
          label: area.name,
          depth: depth,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          onTap: hasChildren ? () => _toggleExpanded(area.id) : null,
        ),
        if (isExpanded) ...[
          for (final subArea in area.subAreas)
            _buildAreaNode(subArea, currentPath, depth + 1),
          for (final section in area.sections)
            _buildSectionNode(section, currentPath, depth + 1),
        ],
      ],
    );
  }

  Widget _buildSectionNode(Section section, ExplorerPath parentPath, int depth) {
    final path = parentPath.toSection(section.id);
    final isSelected = _explorerState.currentPath?.sectionId == section.id;

    return _buildTreeTile(
      icon: Icons.description,
      iconColor: Colors.blue,
      label: section.name,
      depth: depth,
      isExpanded: false,
      hasChildren: false,
      isSelected: isSelected,
      onTap: () => _openSection(section, path),
    );
  }

  /// Minimum height of a tree row; rows with a subtitle grow beyond it
  static const _rowHeight = 40.0;

  /// Style for buttons at the end of a row, small enough not to make the
  /// row taller than [_rowHeight]
  static final _trailingButtonStyle = IconButton.styleFrom(
    fixedSize: const Size.square(32),
    minimumSize: const Size.square(32),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// Background and bottom divider of a tree row
  BoxDecoration _rowDecoration({bool isSelected = false}) {
    final colors = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: isSelected ? colors.primaryContainer : null,
      border: Border(bottom: BorderSide(color: colors.outlineVariant)),
    );
  }

  Widget _buildTreeTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    required int depth,
    required bool isExpanded,
    required bool hasChildren,
    bool isSelected = false,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: _rowDecoration(isSelected: isSelected),
        constraints: const BoxConstraints(minHeight: _rowHeight),
        padding: EdgeInsets.only(
          left: 16.0 + depth * 24.0,
          right: trailing != null ? 4.0 : 16.0,
          top: 4.0,
          bottom: 4.0,
        ),
        child: Row(
          children: [
            if (hasChildren)
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            else
              const SizedBox(width: 20),
            const SizedBox(width: 4),
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

/// Asks whether to delete a section. Pops whether the trips only it uses
/// are deleted too, or null if the user cancels.
class _DeleteSectionDialog extends StatefulWidget {
  final String sectionName;

  /// Number of trips only this section uses
  final int tripCount;

  const _DeleteSectionDialog({
    required this.sectionName,
    required this.tripCount,
  });

  @override
  State<_DeleteSectionDialog> createState() => _DeleteSectionDialogState();
}

class _DeleteSectionDialogState extends State<_DeleteSectionDialog> {
  bool _deleteTrips = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.explorerDeleteSectionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.explorerDeleteSectionMessage(widget.sectionName)),
          if (widget.tripCount > 0)
            CheckboxListTile(
              value: _deleteTrips,
              onChanged: (value) => setState(() => _deleteTrips = value!),
              title: Text(l10n.explorerDeleteSectionTrips(widget.tripCount)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(widget.tripCount > 0 && _deleteTrips),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.explorerDelete),
        ),
      ],
    );
  }
}
