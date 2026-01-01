import 'package:flutter/material.dart';
import '../data/data_service.dart';
import '../data/selection_state.dart';
import '../explorer.dart';
import '../l10n/app_localizations.dart';
import '../table.dart';

class DataView extends StatefulWidget {
  const DataView({super.key});

  @override
  State<DataView> createState() => _DataViewState();
}

enum DataViewMode { stretches, referencePoints }

class _DataViewState extends State<DataView> {
  DataViewMode _mode = DataViewMode.stretches;
  final SelectionState _selectionState = DataService().selectionState;

  @override
  void initState() {
    super.initState();
    _selectionState.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _selectionState.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final section = _selectionState.selectedSection;

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
              Text(
                section.name,
                style: Theme.of(context).textTheme.titleMedium,
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
          child: Text(
            l10n.dataViewNoStretches,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        );
      }
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: StretchesTable(data: stretches),
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
