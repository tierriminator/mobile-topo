import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/calibration.dart';
import '../services/calibration_service.dart';
import '../services/distox_service.dart';

/// Full-screen calibration view for DistoX device calibration.
///
/// Displays:
/// - Connection status and calibration mode indicator
/// - Control buttons (Start/Stop, New, Evaluate, Update)
/// - Table of measurements with results
/// - Status bar with measurement count and RMS error
class CalibrationView extends StatelessWidget {
  const CalibrationView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final calibration = context.watch<CalibrationService>();
    final distoX = context.watch<DistoXService>();

    return PopScope(
      canPop: calibration.measurementCount == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit(context, calibration, l10n);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.calibrationTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _handleBack(context, calibration, l10n),
          ),
          actions: [
            // Connection indicator
            _ConnectionIndicator(distoX: distoX),
            // Calibration mode indicator
            if (calibration.state == CalibrationState.measuring)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Write button (only show after all 56 measurements are complete)
            if (calibration.hasResults && calibration.measurementCount >= 56)
              _ControlBar(calibration: calibration, distoX: distoX, l10n: l10n),

            // Error message if any
            if (calibration.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: Text(
                  calibration.error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),

            // Guidance for next measurement or retake (only when measuring or have data)
            if (calibration.state == CalibrationState.measuring ||
                calibration.measurementCount > 0)
              _CalibrationGuidance(
                measurements: calibration.measurements,
                results: calibration.results,
              ),

            // Measurement table or start page
            Expanded(
              child: _CalibrationTable(
                measurements: calibration.measurements,
                results: calibration.results,
                calibration: calibration,
                distoX: distoX,
              ),
            ),

            // Status bar
            _StatusBar(
              count: calibration.measurementCount,
              rmsError: calibration.rmsError,
              iterations: calibration.iterations,
              state: calibration.state,
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }

  void _handleBack(
    BuildContext context,
    CalibrationService calibration,
    AppLocalizations l10n,
  ) {
    if (calibration.measurementCount == 0) {
      _exit(context, calibration);
    } else {
      _confirmExit(context, calibration, l10n);
    }
  }

  void _confirmExit(
    BuildContext context,
    CalibrationService calibration,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.calibrationCancelTitle),
        content: Text(l10n.calibrationCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exit(context, calibration);
            },
            child: Text(l10n.calibrationDiscard),
          ),
        ],
      ),
    );
  }

  void _exit(BuildContext context, CalibrationService calibration) {
    // Always stop calibration mode on device when exiting
    calibration.stopCalibration();
    calibration.clear();
    Navigator.pop(context);
  }
}

/// Connection status indicator.
class _ConnectionIndicator extends StatelessWidget {
  final DistoXService distoX;

  const _ConnectionIndicator({required this.distoX});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (distoX.connectionState) {
      case DistoXConnectionState.connected:
        icon = Icons.bluetooth_connected;
        color = Colors.green;
      case DistoXConnectionState.connecting:
      case DistoXConnectionState.reconnecting:
        icon = Icons.bluetooth_searching;
        color = Colors.orange;
      case DistoXConnectionState.disconnected:
        icon = Icons.bluetooth_disabled;
        color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(icon, color: color),
    );
  }
}

/// Control buttons bar.
class _ControlBar extends StatelessWidget {
  final CalibrationService calibration;
  final DistoXService distoX;
  final AppLocalizations l10n;

  const _ControlBar({
    required this.calibration,
    required this.distoX,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isWriting = calibration.state == CalibrationState.writing;
    final isReading = calibration.state == CalibrationState.reading;
    final isBusy = isWriting || isReading;
    final isConnected = distoX.isConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: (isBusy || !isConnected)
              ? null
              : () => _confirmUpdate(context, calibration, l10n),
          child: isWriting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.calibrationWrite),
        ),
      ),
    );
  }

  void _confirmUpdate(
    BuildContext context,
    CalibrationService calibration,
    AppLocalizations l10n,
  ) {
    final rmsError = calibration.rmsError ?? 0;
    final isGood = rmsError < 0.5;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.calibrationUpdate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.calibrationUpdateConfirm),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isGood ? Icons.check_circle : Icons.warning,
                  color: isGood ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  isGood
                      ? l10n.calibrationQualityGood
                      : l10n.calibrationQualityPoor,
                  style: TextStyle(
                    color: isGood ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              calibration.writeCoefficients();
            },
            child: Text(l10n.calibrationUpdate),
          ),
        ],
      ),
    );
  }
}

/// Table displaying calibration measurements and results.
class _CalibrationTable extends StatelessWidget {
  final List<CalibrationMeasurement> measurements;
  final List<CalibrationResult?>? results;
  final CalibrationService calibration;
  final DistoXService distoX;

  const _CalibrationTable({
    required this.measurements,
    required this.results,
    required this.calibration,
    required this.distoX,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isConnected = distoX.isConnected;

    if (measurements.isEmpty) {
      // Start page
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.tune,
                size: 72,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.calibrationTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.calibrationDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: isConnected ? () => calibration.startCalibration() : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.calibrationStart),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              if (!isConnected) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.calibrationNotConnected,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: measurements.length,
      itemBuilder: (context, index) {
        final m = measurements[index];
        final r = results != null && index < results!.length
            ? results![index]
            : null;

        return _MeasurementRow(
          index: index,
          measurement: m,
          result: r,
        );
      },
    );
  }
}

/// Single measurement row with compact layout.
class _MeasurementRow extends StatelessWidget {
  final int index;
  final CalibrationMeasurement measurement;
  final CalibrationResult? result;

  const _MeasurementRow({
    required this.index,
    required this.measurement,
    required this.result,
  });

  // Directions (same as _CalibrationGuidance)
  static const _directions = [
    'Forward', 'Backward', 'Left', 'Right', 'Up', 'Down',
    'Forward-Left-Up', 'Forward-Right-Up', 'Forward-Left-Down', 'Forward-Right-Down',
    'Backward-Left-Up', 'Backward-Right-Up', 'Backward-Left-Down', 'Backward-Right-Down',
  ];

  static const _horizontalOrientations = ['Display up', 'Display right', 'Display down', 'Display left'];
  static const _verticalOrientations = ['Display forward', 'Display right', 'Display backward', 'Display left'];

  @override
  Widget build(BuildContext context) {
    final hasError = result != null && result!.error >= 0.5;

    // Calculate direction and orientation from index
    final directionIndex = index ~/ 4;
    final orientationIndex = index % 4;
    final direction = directionIndex < _directions.length ? _directions[directionIndex] : _directions.last;
    final isVertical = directionIndex == 4 || directionIndex == 5;
    final orientation = isVertical ? _verticalOrientations[orientationIndex] : _horizontalOrientations[orientationIndex];

    return Container(
      decoration: BoxDecoration(
        color: !measurement.enabled
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : hasError
                ? Colors.orange.withValues(alpha: 0.08)
                : null,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Direction and orientation
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    direction,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    orientation,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),

            // Status icon
            if (hasError)
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 20,
              )
            else if (result != null)
              Icon(
                Icons.check_circle_outline,
                color: Colors.green.withValues(alpha: 0.7),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Guidance widget showing what measurement to take next.
class _CalibrationGuidance extends StatelessWidget {
  final List<CalibrationMeasurement> measurements;
  final List<CalibrationResult?>? results;

  const _CalibrationGuidance({
    required this.measurements,
    required this.results,
  });

  // 14 directions covering the full sphere:
  // 6 cardinal directions + 8 corners
  static const _directions = [
    ('Forward', Icons.arrow_upward),
    ('Backward', Icons.arrow_downward),
    ('Left', Icons.arrow_back),
    ('Right', Icons.arrow_forward),
    ('Up', Icons.expand_less),
    ('Down', Icons.expand_more),
    ('Forward-Left-Up', Icons.north_west),
    ('Forward-Right-Up', Icons.north_east),
    ('Forward-Left-Down', Icons.south_west),
    ('Forward-Right-Down', Icons.south_east),
    ('Backward-Left-Up', Icons.north_west),
    ('Backward-Right-Up', Icons.north_east),
    ('Backward-Left-Down', Icons.south_west),
    ('Backward-Right-Down', Icons.south_east),
  ];

  // 4 orientations for horizontal directions (display facing)
  static const _horizontalOrientations = [
    ('Display up', Icons.smartphone),
    ('Display right', Icons.stay_current_landscape),
    ('Display down', Icons.smartphone),
    ('Display left', Icons.stay_current_landscape),
  ];

  // 4 orientations for vertical directions (Up/Down - display facing)
  static const _verticalOrientations = [
    ('Display forward', Icons.smartphone),
    ('Display right', Icons.stay_current_landscape),
    ('Display backward', Icons.smartphone),
    ('Display left', Icons.stay_current_landscape),
  ];

  /// Get direction and orientation labels for a measurement index (0-55)
  (String direction, String orientation) _getLabels(int index) {
    final directionIndex = index ~/ 4;
    final orientationIndex = index % 4;

    final direction = directionIndex < _directions.length
        ? _directions[directionIndex].$1
        : _directions.last.$1;

    final isVertical = directionIndex == 4 || directionIndex == 5;
    final orientations = isVertical ? _verticalOrientations : _horizontalOrientations;
    final orientation = orientations[orientationIndex].$1;

    return (direction, orientation);
  }

  /// Find first measurement with high error.
  /// Only checks after all 56 measurements are taken.
  int? _findFirstBadMeasurement() {
    // Don't suggest corrections until all 56 measurements are done
    if (measurements.length < 56) return null;
    if (results == null) return null;

    for (int i = 0; i < results!.length && i < measurements.length; i++) {
      final r = results![i];
      if (r != null && measurements[i].enabled && r.error >= 0.5) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final count = measurements.length;
    final badIndex = _findFirstBadMeasurement();
    final isRetake = badIndex != null;

    // If all 56 done and no bad measurements, show completion
    if (count >= 56 && !isRetake) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Calibration complete',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '56 / 56',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    // Determine what to show
    final targetIndex = isRetake ? badIndex : count;
    final (direction, orientation) = _getLabels(targetIndex);
    final directionIndex = targetIndex ~/ 4;
    final directionIcon = directionIndex < _directions.length
        ? _directions[directionIndex].$2
        : _directions.last.$2;

    // Progress as fraction
    final progress = count / 56;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isRetake
            ? Colors.orange.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: isRetake ? Colors.orange : null,
            ),
          ),

          const SizedBox(height: 12),

          // Retake warning or next measurement
          if (isRetake) ...[
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Measurement #${badIndex + 1} has high error. Retake:',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Direction and orientation info
          Row(
            children: [
              // Direction
              Icon(directionIcon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Point: $direction',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      orientation,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

              // Progress text
              Text(
                '$count / 56',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isRetake ? Colors.orange : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status bar showing calibration state and statistics.
class _StatusBar extends StatelessWidget {
  final int count;
  final double? rmsError;
  final int? iterations;
  final CalibrationState state;
  final AppLocalizations l10n;

  const _StatusBar({
    required this.count,
    required this.rmsError,
    required this.iterations,
    required this.state,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    String stateText;
    switch (state) {
      case CalibrationState.idle:
        stateText = '';
      case CalibrationState.measuring:
        stateText = l10n.calibrationMeasuring;
      case CalibrationState.computing:
        stateText = l10n.calibrationComputing;
      case CalibrationState.writing:
        stateText = l10n.calibrationWriting;
      case CalibrationState.reading:
        stateText = l10n.calibrationReading;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Measurement count
          Text(
            l10n.calibrationStatusCount(count),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 24),

          // Iterations
          if (iterations != null) ...[
            Text(
              l10n.calibrationStatusIterations(iterations!),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 24),
          ],

          // RMS error
          if (rmsError != null) ...[
            Text(
              l10n.calibrationStatusError(rmsError!.toStringAsFixed(2)),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: rmsError! < 0.5 ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],

          const Spacer(),

          // State indicator
          if (stateText.isNotEmpty)
            Text(
              stateText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
        ],
      ),
    );
  }
}
