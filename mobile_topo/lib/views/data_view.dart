import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/selection_state.dart';
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

  Future<void> _addStretch(Section section) async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final caveId = selectionState.selectedCaveId;

    if (caveId == null) return;

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
    final updatedSurvey = section.survey.addStretch(stretch);
    final updatedSection = section.copyWith(
      survey: updatedSurvey,
      modifiedAt: DateTime.now(),
    );

    await repository.saveSection(caveId, updatedSection);
    selectionState.updateSection(updatedSection);
  }

  Future<void> _updateStretch(
    Section section,
    int index,
    MeasuredDistance stretch,
  ) async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final caveId = selectionState.selectedCaveId;

    if (caveId == null) return;

    final updatedSurvey = section.survey.updateStretchAt(index, stretch);
    final updatedSection = section.copyWith(
      survey: updatedSurvey,
      modifiedAt: DateTime.now(),
    );

    await repository.saveSection(caveId, updatedSection);
    selectionState.updateSection(updatedSection);
  }

  Future<void> _deleteStretch(Section section, int index) async {
    final selectionState = context.read<SelectionState>();
    final repository = context.read<CaveRepository>();
    final caveId = selectionState.selectedCaveId;

    if (caveId == null) return;

    final updatedSurvey = section.survey.removeStretchAt(index);
    final updatedSection = section.copyWith(
      survey: updatedSurvey,
      modifiedAt: DateTime.now(),
    );

    await repository.saveSection(caveId, updatedSection);
    selectionState.updateSection(updatedSection);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final section = context.watch<SelectionState>().selectedSection;

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
              if (_mode == DataViewMode.stretches)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addStretch(section),
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
          child: Text(
            l10n.dataViewNoReferencePoints,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        );
      }
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ReferencePointsTable(data: referencePoints),
        ),
      );
    }
  }
}
