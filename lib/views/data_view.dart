import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/history.dart';
import '../controllers/selection_state.dart';
import '../data/cave_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/survey.dart';
import '../services/measurement_service.dart';
import 'trip_page.dart';
import 'widgets/data_tables.dart';

class DataView extends StatefulWidget {
  const DataView({super.key});

  @override
  State<DataView> createState() => _DataViewState();
}

enum DataViewMode { stretches, referencePoints }

class _DataViewState extends State<DataView> {
  DataViewMode _mode = DataViewMode.stretches;
  final History<Survey> _history = History<Survey>();
  String? _currentSectionId;
  bool _measurementServiceBound = false;
  bool _cellEditMode = false;

  // Save lock to prevent concurrent writes that can corrupt files
  Future<void>? _pendingSave;

  // Local section state that gets updated synchronously when measurements
  // come in. This prevents race conditions where multiple measurements arrive
  // before the async save completes and SelectionState gets updated.
  Section? _localSection;

  void _checkSectionChange(Section? section) {
    if (section?.id != _currentSectionId) {
      _history.clear();
      _localSection = null; // Clear local state when section changes
      _currentSectionId = section?.id;
    }
  }

  /// Get the current effective section, preferring local state over SelectionState.
  /// This ensures we see our own pending changes that haven't been saved yet.
  Section? _getEffectiveSection(String expectedSectionId) {
    // If we have local state for this section, use it
    if (_localSection != null && _localSection!.id == expectedSectionId) {
      return _localSection;
    }
    // Otherwise fall back to SelectionState
    final selectionSection = context.read<SelectionState>().selectedSection;
    if (selectionSection?.id == expectedSectionId) {
      return selectionSection;
    }
    return null;
  }

  /// Routes measurements to whichever section is selected when they arrive.
  void _bindMeasurementService() {
    if (_measurementServiceBound) return;

    final measurementService = context.read<MeasurementService>();

    measurementService.stationProvider = _currentStation;

    measurementService.onStretchReady = (stretch) {
      final sectionId = _currentSectionId;
      if (sectionId != null) _addMeasuredStretch(sectionId, stretch);
    };

    measurementService.onCrossSectionReady = (crossSection) {
      final sectionId = _currentSectionId;
      if (sectionId != null) _addMeasuredStretch(sectionId, crossSection);
    };

    measurementService.onTripleReplace = (removeCount, stretch) {
      final sectionId = _currentSectionId;
      if (sectionId != null) {
        _replaceWithSurveyShot(sectionId, removeCount, stretch);
      }
    };

    _measurementServiceBound = true;
  }

  Future<void> _addMeasuredStretch(
      String sectionId, MeasuredDistance stretch) async {
    // Get effective section (local state if available, otherwise SelectionState)
    final currentSection = _getEffectiveSection(sectionId);
    if (currentSection == null) return;

    final newSurvey = currentSection.survey
        .addStretch(stretch.copyWith(tripId: _activeTripId));
    await _applySurveyChangeWithLocalState(currentSection, newSurvey);
  }

  Future<void> _replaceWithSurveyShot(
      String sectionId, int removeCount, MeasuredDistance stretch) async {
    debugPrint('DataView._replaceWithSurveyShot: removeCount=$removeCount, stretch=$stretch');

    // Get effective section (local state if available, otherwise SelectionState)
    final currentSection = _getEffectiveSection(sectionId);
    if (currentSection == null) {
      debugPrint('DataView._replaceWithSurveyShot: section not found, aborting');
      return;
    }

    debugPrint('DataView._replaceWithSurveyShot: current stretches count=${currentSection.survey.stretches.length}');

    // Replace last N splays with the survey shot
    final newSurvey = currentSection.survey.replaceLastNWithStretch(
        removeCount, stretch.copyWith(tripId: _activeTripId));
    debugPrint('DataView._replaceWithSurveyShot: new stretches count=${newSurvey.stretches.length}');

    await _applySurveyChangeWithLocalState(currentSection, newSurvey);
  }

  /// Apply survey change with local state tracking for measurements.
  /// Updates _localSection synchronously so subsequent measurements see our changes.
  Future<void> _applySurveyChangeWithLocalState(
    Section section,
    Survey newSurvey,
  ) async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final caveId = selectionState.selectedCaveId;

    if (caveId == null) return;

    _history.record(section.survey);

    final updatedSection = section.copyWith(
      survey: newSurvey,
      modifiedAt: DateTime.now(),
    );

    // Update local state SYNCHRONOUSLY so subsequent measurements see our changes
    _localSection = updatedSection;
    // Update SelectionState immediately so other views (map, sketch) see changes
    selectionState.updateSection(updatedSection);
    if (mounted) setState(() {}); // Update UI immediately

    // Chain saves to prevent concurrent writes that can corrupt files
    Future<void> doSave() async {
      await repository.saveSection(caveId, updatedSection);
    }
    _pendingSave = _pendingSave?.then((_) => doSave()) ?? doSave();
    await _pendingSave;
  }

  Future<void> _applySurveyChange(
    Section section,
    Survey newSurvey, {
    bool recordHistory = true,
  }) async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final caveId = selectionState.selectedCaveId;

    if (caveId == null) return;

    if (recordHistory) {
      _history.record(section.survey);
    }

    final updatedSection = section.copyWith(
      survey: newSurvey,
      modifiedAt: DateTime.now(),
    );

    // Update state immediately so all views see changes
    _localSection = null;
    selectionState.updateSection(updatedSection);
    if (mounted) setState(() {});

    // Chain saves to prevent concurrent writes that can corrupt files
    Future<void> doSave() async {
      await repository.saveSection(caveId, updatedSection);
    }
    _pendingSave = _pendingSave?.then((_) => doSave()) ?? doSave();
    await _pendingSave;
  }

  Future<void> _undo(Section section) async {
    final previousSurvey = _history.undo(section.survey);
    if (previousSurvey != null) {
      await _applySurveyChange(section, previousSurvey, recordHistory: false);
    }
  }

  Future<void> _redo(Section section) async {
    final nextSurvey = _history.redo(section.survey);
    if (nextSurvey != null) {
      await _applySurveyChange(section, nextSurvey, recordHistory: false);
    }
  }

  Future<void> _addStretch(Section section) async {
    final from = _caveSurvey(section).lastStation ?? _defaultStation;
    final to = Point(from.corridorId, from.pointId.toInt() + 1);

    final stretch = MeasuredDistance(from, to, 0, 0, 0, tripId: _activeTripId);
    await _applySurveyChange(section, section.survey.addStretch(stretch));
  }

  Future<void> _insertStretchAt(Section section, int index) async {
    final stretches = section.survey.stretches;
    Point from;
    Point? to;
    if (stretches.isEmpty) {
      from = const Point(1, 0);
      to = const Point(1, 1);
    } else if (index < stretches.length) {
      final refStretch = stretches[index];
      from = refStretch.from;
      to = refStretch.from;
    } else {
      final lastStretch = stretches.last;
      from = lastStretch.to ?? lastStretch.from;
      to = Point(from.corridorId, from.pointId.toInt() + 1);
    }

    final stretch = MeasuredDistance(from, to, 0, 0, 0, tripId: _activeTripId);
    await _applySurveyChange(
      section,
      section.survey.insertStretchAt(index, stretch),
    );
  }

  Future<void> _updateStretch(
    Section section,
    int index,
    MeasuredDistance stretch,
  ) async {
    await _applySurveyChange(
      section,
      section.survey.updateStretchAt(index, stretch),
    );
  }

  Future<void> _deleteStretch(Section section, int index) async {
    await _applySurveyChange(section, section.survey.removeStretchAt(index));
  }

  Future<void> _addReferencePoint(Section section) async {
    const point = ReferencePoint(Point(1, 0), 0, 0, 0);
    await _applySurveyChange(section, section.survey.addReferencePoint(point));
  }

  Future<void> _insertReferencePointAt(Section section, int index) async {
    const point = ReferencePoint(Point(1, 0), 0, 0, 0);
    await _applySurveyChange(
      section,
      section.survey.insertReferencePointAt(index, point),
    );
  }

  Future<void> _updateReferencePoint(
    Section section,
    int index,
    ReferencePoint point,
  ) async {
    await _applySurveyChange(
      section,
      section.survey.updateReferencePointAt(index, point),
    );
  }

  Future<void> _deleteReferencePoint(Section section, int index) async {
    await _applySurveyChange(
      section,
      section.survey.removeReferencePointAt(index),
    );
  }

  /// PocketTopo's "Start Here": appends a dummy shot from [fromStation] to the
  /// first station of a new series, so measuring continues from there.
  Future<void> _startNewSeries(Section section, Point fromStation) async {
    // Station IDs must be unique in the whole cave, so the new series number
    // is taken from all sections, not just this one
    final newStation = _caveSurvey(section).nextSeriesStart;

    final emptyStretch = MeasuredDistance(fromStation, newStation, 0, 0, 0,
        tripId: _activeTripId);
    await _applySurveyChange(section, section.survey.addStretch(emptyStretch));
  }

  /// PocketTopo's "Continue Here", offered only at the last station of a
  /// series: appends a dummy cross section at [station], so measuring
  /// continues from there.
  Future<void> _continueHere(Section section, Point station) async {
    final dummy =
        MeasuredDistance(station, null, 0, 0, 0, tripId: _activeTripId);
    await _applySurveyChange(section, section.survey.addStretch(dummy));
  }

  /// The trip new rows are assigned to: the cave's newest trip
  String? get _activeTripId =>
      context.read<SelectionState>().selectedCave?.activeTrip?.id;

  /// Opens the trip a row was measured on for inspection and editing
  Future<void> _showTrip(MeasuredDistance stretch) async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final trip = selectionState.selectedCave?.findTrip(stretch.tripId);
    if (trip == null) return;

    final edited = await editTrip(context, trip);
    // The cave may have changed while the page was open
    final cave = selectionState.selectedCave;
    if (edited == null || cave?.findTrip(trip.id) == null) return;

    selectionState.updateTrips(cave!.replaceTrip(edited));
    await repository.saveTrip(cave.id, edited);
  }

  /// Station used when the whole cave has no data yet
  static const _defaultStation = Point(1, 0);

  /// The station new measurements start from: as in PocketTopo, it follows
  /// from the last row of the table
  Point _currentStation() {
    final sectionId = _currentSectionId;
    final section =
        mounted && sectionId != null ? _getEffectiveSection(sectionId) : null;
    if (section == null) return _defaultStation;
    return _caveSurvey(section).lastStation ?? _defaultStation;
  }

  /// The data of all other sections of the cave, shown read-only above the
  /// selected section's own rows
  Survey _otherSectionsSurvey(Section section) {
    final cave = context.read<SelectionState>().selectedCave;
    final others = [
      ...?cave?.allSections.where((s) => s.id != section.id),
    ];
    return Survey(
      stretches: [for (final s in others) ...s.survey.stretches],
      referencePoints: [for (final s in others) ...s.survey.referencePoints],
    );
  }

  /// The whole cave as the table lists it: the other sections first, then
  /// this section with its latest changes
  Survey _caveSurvey(Section section) {
    final others = _otherSectionsSurvey(section);
    return Survey(
      stretches: [...others.stretches, ...section.survey.stretches],
      referencePoints: [
        ...others.referencePoints,
        ...section.survey.referencePoints,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectionState = context.watch<SelectionState>();
    final selectionSection = selectionState.selectedSection;
    final activeTrip = selectionState.selectedCave?.activeTrip;

    // Clear history when section changes
    _checkSectionChange(selectionSection);

    if (selectionSection == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.dataViewNoSection,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    // Use local section for display if available (shows pending changes immediately)
    final section = _localSection?.id == selectionSection.id
        ? _localSection!
        : selectionSection;

    // Bind measurement service callbacks
    _bindMeasurementService();

    return Column(
      children: [
        // Section name header with mode toggle
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ToggleButtons(
                isSelected: [
                  _mode == DataViewMode.stretches,
                  _mode == DataViewMode.referencePoints,
                ],
                onPressed: (index) {
                  setState(() {
                    _mode = index == 0
                        ? DataViewMode.stretches
                        : DataViewMode.referencePoints;
                  });
                },
                constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                borderRadius: BorderRadius.circular(8),
                children: [
                  Tooltip(
                    message: l10n.stretches,
                    child: const Icon(Icons.straighten, size: 20),
                  ),
                  Tooltip(
                    message: l10n.referencePoints,
                    child: const Icon(Icons.location_on, size: 20),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _history.canUndo ? () => _undo(section) : null,
                tooltip: l10n.undo,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: _history.canRedo ? () => _redo(section) : null,
                tooltip: l10n.redo,
              ),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: _cellEditMode
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: () {
                  setState(() {
                    _cellEditMode = !_cellEditMode;
                  });
                },
                tooltip: l10n.cellEditMode,
              ),
            ],
          ),
        ),
        // Data table
        Expanded(
          child: _buildDataContent(section),
        ),
        // Status bar
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${l10n.currentStation}: ${_currentStation()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${l10n.trip}: ${activeTrip != null ? tripLabel(context, activeTrip) : l10n.noTrip}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataContent(Section section) {
    final l10n = AppLocalizations.of(context)!;

    // Like PocketTopo, the table lists the whole cave: the other sections'
    // rows come first and are read-only, this section's rows follow. Table
    // indices are converted back to this section's indices for editing.
    final caveSurvey = _caveSurvey(section);
    final stretches = caveSurvey.stretches;
    final referencePoints = caveSurvey.referencePoints;
    final stretchOffset =
        stretches.length - section.survey.stretches.length;
    final pointOffset =
        referencePoints.length - section.survey.referencePoints.length;

    return IndexedStack(
      index: _mode == DataViewMode.stretches ? 0 : 1,
      children: [
        // Stretches view
        stretches.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.dataViewNoStretches,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _addStretch(section),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addStretch),
                    ),
                  ],
                ),
              )
            : StretchesTable(
                data: stretches,
                readOnlyRows: stretchOffset,
                editMode: _cellEditMode,
                onInsertAbove: (index) =>
                    _insertStretchAt(section, index - stretchOffset),
                onInsertBelow: (index) =>
                    _insertStretchAt(section, index - stretchOffset + 1),
                onUpdate: (index, stretch) =>
                    _updateStretch(section, index - stretchOffset, stretch),
                onDelete: (index) =>
                    _deleteStretch(section, index - stretchOffset),
                onStartHere: (station) => _startNewSeries(section, station),
                onContinueHere: (station) => _continueHere(section, station),
                onShowTrip: _showTrip,
                // Series can span sections, so their ends are taken from the
                // whole cave
                seriesEnds: caveSurvey.seriesEnds,
                onAdd: () => _addStretch(section),
              ),
        // Reference points view
        referencePoints.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.dataViewNoReferencePoints,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _addReferencePoint(section),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.referencePoints),
                    ),
                  ],
                ),
              )
            : ReferencePointsTable(
                data: referencePoints,
                readOnlyRows: pointOffset,
                editMode: _cellEditMode,
                onInsertAbove: (index) =>
                    _insertReferencePointAt(section, index - pointOffset),
                onInsertBelow: (index) =>
                    _insertReferencePointAt(section, index - pointOffset + 1),
                onUpdate: (index, point) =>
                    _updateReferencePoint(section, index - pointOffset, point),
                onDelete: (index) =>
                    _deleteReferencePoint(section, index - pointOffset),
                onStartHere: (station) => _startNewSeries(section, station),
                onAdd: () => _addReferencePoint(section),
              ),
      ],
    );
  }
}
