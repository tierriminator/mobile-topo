import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/coordinate_system.dart';
import '../../models/geo_position.dart';
import '../../services/location_service.dart';
import '../../services/position_average.dart';

/// A measured position: WGS84 degrees and, if the device reported one, the
/// altitude in metres above sea level
typedef MeasuredPosition = ({
  double latitude,
  double longitude,
  double? altitude,
});

/// Measures the device's position, averaging fixes for as long as the user
/// lets it, and returns the averaged position, or null if cancelled. The
/// position is shown in [coordinateSystem] while measuring.
Future<MeasuredPosition?> measurePosition(
        BuildContext context, CoordinateSystem coordinateSystem) =>
    showDialog<MeasuredPosition>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          PositionMeasurementDialog(coordinateSystem: coordinateSystem),
    );

/// Dialog measuring the device's position; see [measurePosition]
class PositionMeasurementDialog extends StatefulWidget {
  final CoordinateSystem coordinateSystem;

  const PositionMeasurementDialog({super.key, required this.coordinateSystem});

  @override
  State<PositionMeasurementDialog> createState() =>
      _PositionMeasurementDialogState();
}

class _PositionMeasurementDialogState
    extends State<PositionMeasurementDialog> {
  late final LocationService _service;
  final _average = PositionAverage();
  StreamSubscription<LocationFix>? _subscription;
  bool _preparing = true;
  LocationProblem? _problem;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _service = context.read<LocationService>();
    _start();
  }

  Future<void> _start() async {
    final problem = await _service.prepare();
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _problem = problem;
    });
    if (problem != null) return;
    _subscription = _service.fixes().listen(
          (fix) => setState(() => _average.add(fix)),
          onError: (Object error) => setState(() => _error = error),
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _use() {
    Navigator.of(context).pop((
      latitude: _average.latitude,
      longitude: _average.longitude,
      altitude: _average.altitude,
    ));
  }

  String _problemText(AppLocalizations l10n, LocationProblem problem) =>
      switch (problem) {
        LocationProblem.disabled => l10n.locationDisabled,
        LocationProblem.denied => l10n.locationDenied,
        LocationProblem.imprecise => l10n.locationImprecise,
      };

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  /// The statistics of the fixes so far and the averaged position, East
  /// and North in the coordinate system
  List<Widget> _measurement(AppLocalizations l10n) {
    final latest = _average.latest;
    if (latest == null) {
      return [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(l10n.measurePositionWaiting),
      ];
    }
    final unit = context.read<SettingsController>().settings.lengthUnit;
    final system = widget.coordinateSystem;
    final (:east, :north) = system
        .fromGeo(GeoPosition(_average.latitude, _average.longitude));
    final altitude = _average.altitude;
    return [
      _row(l10n.measurePositionFixes, '${_average.count}'),
      _row(l10n.measurePositionAccuracy,
          '±${latest.accuracy.toStringAsFixed(1)} m'),
      _row(l10n.measurePositionScatter,
          '${_average.scatter.toStringAsFixed(1)} m'),
      const Divider(height: 24),
      if (system.isMetric) ...[
        _row(l10n.columnEast, '${east.toStringAsFixed(2)} m'),
        _row(l10n.columnNorth, '${north.toStringAsFixed(2)} m'),
      ] else ...[
        _row(l10n.caveLongitude, '${east.toStringAsFixed(7)}°'),
        _row(l10n.caveLatitude, '${north.toStringAsFixed(7)}°'),
      ],
      _row(
          l10n.caveAltitude,
          altitude == null
              ? '–'
              : '${unit.fromMeters(altitude).toStringAsFixed(1)} '
                  '${unit.symbol}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final problem = _problem;

    return AlertDialog(
      title: Text(l10n.measurePositionTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_preparing)
              const Center(child: CircularProgressIndicator())
            else if (problem != null)
              Text(_problemText(l10n, problem))
            else if (_error != null)
              Text(l10n.measurePositionFailed(_error.toString()))
            else ...[
              Text(
                l10n.measurePositionHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ..._measurement(l10n),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if (problem != null)
          TextButton(
            onPressed: () => _service.openSettings(problem),
            child: Text(l10n.locationOpenSettings),
          )
        else
          FilledButton(
            onPressed: _average.isEmpty ? null : _use,
            child: Text(l10n.measurePositionUse),
          ),
      ],
    );
  }
}
