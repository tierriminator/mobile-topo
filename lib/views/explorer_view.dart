import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../controllers/explorer_state.dart';
import '../controllers/selection_state.dart';
import '../controllers/settings_controller.dart';
import '../data/cave_repository.dart';
import '../data/pocket_topo_file.dart';
import '../data/settings_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/explorer_path.dart';
import '../models/survey.dart';
import '../models/trip.dart';
import 'trip_page.dart';

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

  Future<void> _createNewCave() async {
    final l10n = AppLocalizations.of(context)!;
    final repository = context.read<CaveRepository>();
    final now = DateTime.now();

    // Show dialog to get cave name
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NewItemDialog(
        title: l10n.explorerNewCaveTitle,
        labelText: l10n.explorerCaveName,
        defaultName: l10n.explorerNewCave,
      ),
    );

    if (name == null || name.isEmpty) return;

    final cave = Cave(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      modifiedAt: now,
    );

    await repository.saveCave(cave);
    await _loadCaves();

    // Expand the new cave
    setState(() {
      _expandedIds.add(cave.id);
    });
  }

  Future<void> _createNewSection(Cave cave) async {
    final l10n = AppLocalizations.of(context)!;
    final repository = context.read<CaveRepository>();
    final now = DateTime.now();

    // Show dialog to get section name
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NewItemDialog(
        title: l10n.explorerNewSectionTitle,
        labelText: l10n.explorerSectionName,
        defaultName: l10n.explorerNewSection,
      ),
    );

    if (name == null || name.isEmpty) return;

    final section = Section(
      id: _uuid.v4(),
      name: name,
      survey: const Survey(stretches: [], referencePoints: []),
      createdAt: now,
      modifiedAt: now,
    );

    // Add section to cave
    final updatedCave = cave.addSection(section);
    await repository.saveCave(updatedCave);
    await _loadCaves();

    // Expand the cave to show the new section
    setState(() {
      _expandedIds.add(cave.id);
    });
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
        survey: imported.survey,
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
      setState(() {
        _expandedIds.add(cave.id);
      });
    }

    final messages = [
      ...failures,
      if (skipped > 0) l10n.importPocketTopoSkipped(skipped),
    ];
    if (messages.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(messages.join('\n'))));
    }
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

    // The declination changes slowly, so the latest trip's value is a good
    // starting point
    final trip = Trip(
      id: _uuid.v4(),
      date: DateUtils.dateOnly(now),
      declination: cave.activeTrip?.declination ?? 0,
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
    final l10n = AppLocalizations.of(context)!;
    final isExpanded = _expandedIds.contains(cave.id);
    final hasChildren = cave.areas.isNotEmpty || cave.sections.isNotEmpty;

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
          trailing: _trailingMenu(
            onSelected: (value) {
              switch (value) {
                case 'add_section':
                  _createNewSection(cave);
                case 'add_trip':
                  _createTrip(cave);
                case 'import_pocket_topo':
                  _importPocketTopo(cave);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add_section',
                child: Row(
                  children: [
                    const Icon(Icons.description, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.explorerAddSection),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_trip',
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.explorerAddTrip),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import_pocket_topo',
                child: Row(
                  children: [
                    const Icon(Icons.file_open, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text(l10n.explorerImportPocketTopo)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isExpanded) ...[
          for (final area in cave.areas)
            _buildAreaNode(area, ExplorerPath.cave(cave.id), 1),
          for (final section in cave.sections)
            _buildSectionNode(section, ExplorerPath.cave(cave.id), 1),
          if (!hasChildren) _buildPlaceholder(l10n.explorerEmpty, 1),
          _buildTripsNode(cave),
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
      onTap: () => _selectSection(path, section),
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

  /// Compact menu button at the end of a row
  Widget _trailingMenu({
    required List<PopupMenuEntry<String>> Function(BuildContext) itemBuilder,
    required void Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      padding: EdgeInsets.zero,
      style: _trailingButtonStyle,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
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

/// Generic dialog for creating a new item (cave, section, area)
class _NewItemDialog extends StatefulWidget {
  final String title;
  final String labelText;
  final String defaultName;

  const _NewItemDialog({
    required this.title,
    required this.labelText,
    required this.defaultName,
  });

  @override
  State<_NewItemDialog> createState() => _NewItemDialogState();
}

class _NewItemDialogState extends State<_NewItemDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultName);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.defaultName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.labelText,
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
