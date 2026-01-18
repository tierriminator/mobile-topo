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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calibrationTitle),
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
          // Control buttons
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

          // Measurement table
          Expanded(
            child: _CalibrationTable(
              measurements: calibration.measurements,
              results: calibration.results,
              onToggleEnabled: calibration.toggleEnabled,
              onCycleGroup: calibration.cycleGroup,
              onDelete: calibration.deleteMeasurement,
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
    );
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
    final isMeasuring = calibration.state == CalibrationState.measuring;
    final isComputing = calibration.state == CalibrationState.computing;
    final isWriting = calibration.state == CalibrationState.writing;
    final isReading = calibration.state == CalibrationState.reading;
    final isBusy = isComputing || isWriting || isReading;
    final isConnected = distoX.isConnected;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Start/Stop button
          if (isMeasuring)
            FilledButton.icon(
              onPressed: isBusy ? null : () => calibration.stopCalibration(),
              icon: const Icon(Icons.stop),
              label: Text(l10n.calibrationStop),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            )
          else
            FilledButton.icon(
              onPressed:
                  (isBusy || !isConnected) ? null : () => calibration.startCalibration(),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.calibrationStart),
            ),

          // New button
          OutlinedButton.icon(
            onPressed: isBusy
                ? null
                : () => _confirmClear(context, calibration, l10n),
            icon: const Icon(Icons.add),
            label: Text(l10n.calibrationNew),
          ),

          // Evaluate button
          FilledButton.tonal(
            onPressed: (isBusy || calibration.measurementCount < 16)
                ? null
                : () => calibration.evaluate(),
            child: isComputing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.calibrationEvaluate),
          ),

          // Update button (write to device)
          FilledButton.tonal(
            onPressed:
                (isBusy || !isConnected || !calibration.hasResults)
                    ? null
                    : () => _confirmUpdate(context, calibration, l10n),
            child: isWriting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.calibrationUpdate),
          ),
        ],
      ),
    );
  }

  void _confirmClear(
    BuildContext context,
    CalibrationService calibration,
    AppLocalizations l10n,
  ) {
    if (calibration.measurementCount == 0) {
      calibration.clear();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.calibrationNew),
        content: Text(l10n.calibrationClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              calibration.clear();
            },
            child: Text(l10n.calibrationClear),
          ),
        ],
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
  final List<CalibrationResult>? results;
  final void Function(int index) onToggleEnabled;
  final void Function(int index) onCycleGroup;
  final void Function(int index) onDelete;

  const _CalibrationTable({
    required this.measurements,
    required this.results,
    required this.onToggleEnabled,
    required this.onCycleGroup,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (measurements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tune,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.calibrationNoMeasurements,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 36,
          columns: [
            DataColumn(label: Text(l10n.calibrationColumnEnabled)),
            DataColumn(label: Text(l10n.calibrationColumnGroup)),
            const DataColumn(label: Text('#')),
            if (results != null) ...[
              DataColumn(
                label: Text(l10n.calibrationColumnError),
                numeric: true,
              ),
              DataColumn(
                label: Text(l10n.calibrationColumnGMag),
                numeric: true,
              ),
              DataColumn(
                label: Text(l10n.calibrationColumnMMag),
                numeric: true,
              ),
              DataColumn(
                label: Text(l10n.calibrationColumnAlpha),
                numeric: true,
              ),
            ],
            const DataColumn(label: Text('Gx'), numeric: true),
            const DataColumn(label: Text('Gy'), numeric: true),
            const DataColumn(label: Text('Gz'), numeric: true),
            const DataColumn(label: Text('Mx'), numeric: true),
            const DataColumn(label: Text('My'), numeric: true),
            const DataColumn(label: Text('Mz'), numeric: true),
            if (results != null) ...[
              DataColumn(
                label: Text(l10n.columnAzimuth),
                numeric: true,
              ),
              DataColumn(
                label: Text(l10n.columnInclination),
                numeric: true,
              ),
            ],
            const DataColumn(label: Text('')), // Delete action
          ],
          rows: List.generate(measurements.length, (index) {
            final m = measurements[index];
            final r = results != null && index < results!.length
                ? results![index]
                : null;

            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                if (!m.enabled) {
                  return Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5);
                }
                if (r != null && r.error >= 0.5) {
                  return Colors.orange.withValues(alpha: 0.1);
                }
                return null;
              }),
              cells: [
                // Enabled checkbox
                DataCell(
                  Checkbox(
                    value: m.enabled,
                    onChanged: (_) => onToggleEnabled(index),
                  ),
                ),
                // Group
                DataCell(
                  GestureDetector(
                    onTap: () => onCycleGroup(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _groupColor(m.group),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        m.group ?? '-',
                        style: TextStyle(
                          color: m.group != null ? Colors.white : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // Index
                DataCell(Text('${m.index}')),
                // Results columns (if available)
                if (r != null) ...[
                  DataCell(
                    Text(
                      r.error.toStringAsFixed(2),
                      style: TextStyle(
                        color: r.error >= 0.5 ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(Text(r.gMagnitude.toStringAsFixed(3))),
                  DataCell(Text(r.mMagnitude.toStringAsFixed(3))),
                  DataCell(Text(r.alpha.toStringAsFixed(1))),
                ],
                // Raw sensor values
                DataCell(Text('${m.gx}')),
                DataCell(Text('${m.gy}')),
                DataCell(Text('${m.gz}')),
                DataCell(Text('${m.mx}')),
                DataCell(Text('${m.my}')),
                DataCell(Text('${m.mz}')),
                // Computed angles (if available)
                if (r != null) ...[
                  DataCell(Text(r.azimuth.toStringAsFixed(1))),
                  DataCell(Text(r.inclination.toStringAsFixed(1))),
                ],
                // Delete button
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => onDelete(index),
                    tooltip: l10n.explorerDelete,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Color? _groupColor(String? group) {
    switch (group) {
      case 'A':
        return Colors.blue;
      case 'B':
        return Colors.green;
      default:
        return null;
    }
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
