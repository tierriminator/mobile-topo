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

  void _checkSectionChange(Section? section) {
    if (section?.id != _currentSectionId) {
      _history.clear();
      _currentSectionId = section?.id;
    }
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
    await _changeSurvey(sectionId,
        (survey) => survey.addStretch(stretch.copyWith(tripId: _activeTripId)));
  }

  /// Replaces the last [removeCount] splays with the survey shot smart mode
  /// detected in them
  Future<void> _replaceWithSurveyShot(
      String sectionId, int removeCount, MeasuredDistance stretch) async {
    await _changeSurvey(
        sectionId,
        (survey) => survey.replaceLastNWithStretch(
            removeCount, stretch.copyWith(tripId: _activeTripId)));
  }

  /// Applies [change] to the latest survey of the section with [sectionId],
  /// if it is still selected, and saves it. Measurements arriving in quick
  /// succession and changes made in other views build on each other this
  /// way, as SelectionState is updated synchronously.
  Future<void> _changeSurvey(
    String sectionId,
    Survey Function(Survey survey) change, {
    bool recordHistory = true,
  }) async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final caveId = selectionState.selectedCaveId;
    if (caveId == null) return;

    final changed = selectionState.changeSection(sectionId, (section) {
      if (recordHistory) _history.record(section.survey);
      return section.copyWith(
        survey: change(section.survey),
        modifiedAt: DateTime.now(),
      );
    });
    if (changed != null) await repository.saveSection(caveId, changed);
  }

  Future<void> _undo(Section section) async {
    await _changeSurvey(section.id, (survey) => _history.undo(survey) ?? survey,
        recordHistory: false);
  }

  Future<void> _redo(Section section) async {
    await _changeSurvey(section.id, (survey) => _history.redo(survey) ?? survey,
        recordHistory: false);
  }

  Future<void> _addStretch(Section section) async {
    await _changeSurvey(section.id, (survey) {
      final from = _caveSurvey(survey).lastStation ?? _defaultStation;
      final to = Point(from.corridorId, from.pointId.toInt() + 1);
      return survey.addStretch(
          MeasuredDistance(from, to, 0, 0, 0, tripId: _activeTripId));
    });
  }

  Future<void> _insertStretchAt(Section section, int index) async {
    await _changeSurvey(section.id, (survey) {
      final stretches = survey.stretches;
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
      return survey.insertStretchAt(
          index, MeasuredDistance(from, to, 0, 0, 0, tripId: _activeTripId));
    });
  }

  Future<void> _updateStretch(
    Section section,
    int index,
    MeasuredDistance stretch,
  ) async {
    await _changeSurvey(
        section.id, (survey) => survey.updateStretchAt(index, stretch));
  }

  Future<void> _deleteStretch(Section section, int index) async {
    await _changeSurvey(section.id, (survey) => survey.removeStretchAt(index));
  }

  Future<void> _addReferencePoint(Section section) async {
    const point = ReferencePoint(Point(1, 0), 0, 0, 0);
    await _changeSurvey(
        section.id, (survey) => survey.addReferencePoint(point));
  }

  Future<void> _insertReferencePointAt(Section section, int index) async {
    const point = ReferencePoint(Point(1, 0), 0, 0, 0);
    await _changeSurvey(
        section.id, (survey) => survey.insertReferencePointAt(index, point));
  }

  Future<void> _updateReferencePoint(
    Section section,
    int index,
    ReferencePoint point,
  ) async {
    await _changeSurvey(
        section.id, (survey) => survey.updateReferencePointAt(index, point));
  }

  Future<void> _deleteReferencePoint(Section section, int index) async {
    await _changeSurvey(
        section.id, (survey) => survey.removeReferencePointAt(index));
  }

  /// PocketTopo's "Start Here": appends a dummy shot from [fromStation] to the
  /// first station of a new series, so measuring continues from there.
  Future<void> _startNewSeries(Section section, Point fromStation) async {
    await _changeSurvey(section.id, (survey) {
      // Station IDs must be unique in the whole cave, so the new series
      // number is taken from all sections, not just this one
      final newStation = _caveSurvey(survey).nextSeriesStart;
      return survey.addStretch(MeasuredDistance(
          fromStation, newStation, 0, 0, 0,
          tripId: _activeTripId));
    });
  }

  /// PocketTopo's "Continue Here", offered only at the last station of a
  /// series: appends a dummy cross section at [station], so measuring
  /// continues from there.
  Future<void> _continueHere(Section section, Point station) async {
    final dummy =
        MeasuredDistance(station, null, 0, 0, 0, tripId: _activeTripId);
    await _changeSurvey(section.id, (survey) => survey.addStretch(dummy));
  }

  /// The trip new rows are assigned to: the cave's newest trip
  String? get _activeTripId =>
      context.read<SelectionState>().selectedCave?.activeTrip?.id;

  /// Opens the trip a row was measured on for inspection and editing
  Future<void> _showTrip(MeasuredDistance stretch) async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final opened = selectionState.selectedCave;
    final trip = opened?.findTrip(stretch.tripId);
    if (opened == null || trip == null) return;

    final edited = await editTrip(context, opened, trip);
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
    final section =
        mounted ? context.read<SelectionState>().selectedSection : null;
    if (section == null) return _defaultStation;
    return _caveSurvey(section.survey).lastStation ?? _defaultStation;
  }

  /// The data of all sections of the cave but the selected one, shown
  /// read-only above the selected section's own rows
  Survey _otherSectionsSurvey() {
    final selectionState = context.read<SelectionState>();
    final sectionId = selectionState.selectedSection?.id;
    final others = [
      ...?selectionState.selectedCave?.allSections
          .where((s) => s.id != sectionId),
    ];
    return Survey(
      stretches: [for (final s in others) ...s.survey.stretches],
      referencePoints: [for (final s in others) ...s.survey.referencePoints],
    );
  }

  /// The whole cave as the table lists it: the other sections first, then
  /// the selected section's [sectionSurvey]
  Survey _caveSurvey(Survey sectionSurvey) {
    final others = _otherSectionsSurvey();
    return Survey(
      stretches: [...others.stretches, ...sectionSurvey.stretches],
      referencePoints: [
        ...others.referencePoints,
        ...sectionSurvey.referencePoints,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectionSection = context.watch<SelectionState>().selectedSection;

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

    final section = selectionSection;

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
    final caveSurvey = _caveSurvey(section.survey);
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
                onCommentChanged: (index, comment) => _updateStretch(
                    section,
                    index - stretchOffset,
                    stretches[index].withComment(comment)),
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
                onCommentChanged: (index, comment) => _updateReferencePoint(
                    section,
                    index - pointOffset,
                    referencePoints[index].withComment(comment)),
                onStartHere: (station) => _startNewSeries(section, station),
                onAdd: () => _addReferencePoint(section),
              ),
      ],
    );
  }
}
