import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/history.dart';
import '../controllers/selection_state.dart';
import '../data/cave_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/survey.dart';
import '../services/measurement_service.dart';
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

      // Update measurement service with current station from survey
      // Use addPostFrameCallback to avoid calling setState during build
      if (section != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final measurementService = context.read<MeasurementService>();
          final stretches = section.survey.stretches;
          if (stretches.isNotEmpty) {
            final lastStretch = stretches.last;
            // If last stretch has a "To" station, continue from there
            if (lastStretch.to != null) {
              measurementService.continueFrom(lastStretch.to!);
            } else {
              measurementService.continueFrom(lastStretch.from);
            }
          }
        });
      }
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

  void _bindMeasurementService(Section section) {
    if (_measurementServiceBound) return;

    final measurementService = context.read<MeasurementService>();
    final sectionId = section.id;

    measurementService.onStretchReady = (stretch) {
      _addMeasuredStretch(sectionId, stretch);
    };

    measurementService.onCrossSectionReady = (crossSection) {
      _addMeasuredStretch(sectionId, crossSection);
    };

    measurementService.onTripleReplace = (removeCount, stretch) {
      _replaceWithSurveyShot(sectionId, removeCount, stretch);
    };

    _measurementServiceBound = true;
  }

  Future<void> _addMeasuredStretch(
      String sectionId, MeasuredDistance stretch) async {
    // Get effective section (local state if available, otherwise SelectionState)
    final currentSection = _getEffectiveSection(sectionId);
    if (currentSection == null) return;

    final newSurvey = currentSection.survey.addStretch(stretch);
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
    final newSurvey = currentSection.survey.replaceLastNWithStretch(removeCount, stretch);
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
    final stretches = section.survey.stretches;
    Point from;
    Point? to;
    if (stretches.isEmpty) {
      from = const Point(1, 0);
      to = const Point(1, 1);
    } else {
      final lastStretch = stretches.last;
      from = lastStretch.to ?? lastStretch.from;
      to = Point(from.corridorId, from.pointId.toInt() + 1);
    }

    final stretch = MeasuredDistance(from, to, 0, 0, 0);
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

    final stretch = MeasuredDistance(from, to, 0, 0, 0);
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

  Future<void> _startNewSeries(Section section, Point fromStation) async {
    final measurementService = context.read<MeasurementService>();

    // Find the maximum corridor ID used in the survey
    int maxCorridorId = 0;
    for (final stretch in section.survey.stretches) {
      if (stretch.from.corridorId.toInt() > maxCorridorId) {
        maxCorridorId = stretch.from.corridorId.toInt();
      }
      if (stretch.to != null && stretch.to!.corridorId.toInt() > maxCorridorId) {
        maxCorridorId = stretch.to!.corridorId.toInt();
      }
    }

    // New series starts at (maxCorridorId + 1).0
    final newCorridorId = maxCorridorId + 1;
    final newStation = Point(newCorridorId, 0);

    // Create empty stretch connecting the selected station to the new series
    final emptyStretch = MeasuredDistance(fromStation, newStation, 0, 0, 0);
    await _applySurveyChange(section, section.survey.addStretch(emptyStretch));

    // Update measurement service to continue from the new station
    measurementService.continueFrom(newStation);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectionSection = context.watch<SelectionState>().selectedSection;
    final measurementService = context.watch<MeasurementService>();

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
    _bindMeasurementService(selectionSection);

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
                icon: const Icon(Icons.add),
                onPressed: () => _mode == DataViewMode.stretches
                    ? _addStretch(section)
                    : _addReferencePoint(section),
                tooltip: l10n.addStretch,
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
                '${l10n.currentStation}: ${measurementService.currentStation}',
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
    final stretches = section.survey.stretches;
    final referencePoints = section.survey.referencePoints;

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
                onInsertAbove: (index) => _insertStretchAt(section, index),
                onInsertBelow: (index) =>
                    _insertStretchAt(section, index + 1),
                onUpdate: (index, stretch) =>
                    _updateStretch(section, index, stretch),
                onDelete: (index) => _deleteStretch(section, index),
                onStartHere: (station) => _startNewSeries(section, station),
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
                onInsertAbove: (index) =>
                    _insertReferencePointAt(section, index),
                onInsertBelow: (index) =>
                    _insertReferencePointAt(section, index + 1),
                onUpdate: (index, point) =>
                    _updateReferencePoint(section, index, point),
                onDelete: (index) => _deleteReferencePoint(section, index),
              ),
      ],
    );
  }
}
