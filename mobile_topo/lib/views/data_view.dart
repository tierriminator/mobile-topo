import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../table.dart';
import '../topo.dart';

class DataView extends StatefulWidget {
  const DataView({super.key});

  @override
  State<DataView> createState() => _DataViewState();
}

enum DataViewMode { stretches, referencePoints }

class _DataViewState extends State<DataView> {
  DataViewMode _mode = DataViewMode.stretches;

  // Placeholder data - will be replaced with actual data management later
  final List<MeasuredDistance> _stretches = const [
    MeasuredDistance(Point(1, 0), Point(1, 1), 2.5, 45.0, -5.0),
    MeasuredDistance(Point(1, 1), Point(1, 2), 3.2, 120.0, 10.0),
    MeasuredDistance(Point(1, 2), Point(1, 3), 1.8, 90.0, 0.0),
  ];

  final List<ReferencePoint> _referencePoints = const [
    ReferencePoint(Point(1, 0), 600000.0, 200000.0, 450.0),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
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
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _mode == DataViewMode.stretches
                  ? StretchesTable(data: _stretches)
                  : ReferencePointsTable(data: _referencePoints),
            ),
          ),
        ),
      ],
    );
  }
}
