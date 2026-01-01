import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/selection_state.dart';
import '../controllers/survey_history.dart';
import '../data/cave_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/survey.dart';
import 'widgets/data_tables.dart';

class DataView extends StatefulWidget {
  const DataView({super.key});

  @override
  State<DataView> createState() => _DataViewState();
}

enum DataViewMode { stretches, referencePoints }

class _DataViewState extends State<DataView> {
  DataViewMode _mode = DataViewMode.stretches;
  final SurveyHistory _history = SurveyHistory();
  String? _currentSectionId;

  void _checkSectionChange(Section? section) {
    if (section?.id != _currentSectionId) {
      _history.clear();
      _currentSectionId = section?.id;
    }
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
      _history.recordState(section.survey);
    }

    final updatedSection = section.copyWith(
      survey: newSurvey,
      modifiedAt: DateTime.now(),
    );

    await repository.saveSection(caveId, updatedSection);
    selectionState.updateSection(updatedSection);
    setState(() {}); // Refresh undo/redo button states
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
    // Determine next station IDs based on existing stretches
    final stretches = section.survey.stretches;
    Point from;
    Point to;
    if (stretches.isEmpty) {
      from = const Point(1, 0);
      to = const Point(1, 1);
    } else {
      final lastStretch = stretches.last;
      from = lastStretch.to;
      to = Point(from.corridorId, from.pointId.toInt() + 1);
    }

    final stretch = MeasuredDistance(from, to, 0, 0, 0);
    await _applySurveyChange(section, section.survey.addStretch(stretch));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final section = context.watch<SelectionState>().selectedSection;

    // Clear history when section changes
    _checkSectionChange(section);

    if (section == null) {
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

    return Column(
      children: [
        // Section name header
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.description, size: 20),
              const SizedBox(width: 8),
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
        // Mode toggle
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SegmentedButton<DataViewMode>(
            segments: [
              ButtonSegment(
                value: DataViewMode.stretches,
                label: Text(l10n.stretches),
                icon: const Icon(Icons.straighten),
              ),
              ButtonSegment(
                value: DataViewMode.referencePoints,
                label: Text(l10n.referencePoints),
                icon: const Icon(Icons.location_on),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (Set<DataViewMode> selection) {
              setState(() {
                _mode = selection.first;
              });
            },
          ),
        ),
        // Data table
        Expanded(
          child: _buildDataContent(section),
        ),
      ],
    );
  }

  Widget _buildDataContent(Section section) {
    final l10n = AppLocalizations.of(context)!;
    final stretches = section.survey.stretches;
    final referencePoints = section.survey.referencePoints;

    if (_mode == DataViewMode.stretches) {
      if (stretches.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.dataViewNoStretches,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        );
      }
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: StretchesTable(
            data: stretches,
            onUpdate: (index, stretch) =>
                _updateStretch(section, index, stretch),
            onDelete: (index) => _deleteStretch(section, index),
          ),
        ),
      );
    } else {
      if (referencePoints.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.dataViewNoReferencePoints,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        );
      }
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ReferencePointsTable(
            data: referencePoints,
            onUpdate: (index, point) =>
                _updateReferencePoint(section, index, point),
            onDelete: (index) => _deleteReferencePoint(section, index),
          ),
        ),
      );
    }
  }
}
