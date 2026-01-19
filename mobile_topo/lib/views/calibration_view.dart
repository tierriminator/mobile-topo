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
class CalibrationView extends StatefulWidget {
  const CalibrationView({super.key});

  @override
  State<CalibrationView> createState() => _CalibrationViewState();
}

class _CalibrationViewState extends State<CalibrationView> {
  /// Track if phase 2 dialog has been shown this session.
  bool _phase2DialogShown = false;

  /// Previous measurement count to detect when we cross 16.
  int _previousCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkPhase2Transition();
  }

  void _checkPhase2Transition() {
    final calibration = context.read<CalibrationService>();
    final currentCount = calibration.measurementCount;

    // Show phase 2 dialog when crossing from <16 to >=16
    if (!_phase2DialogShown &&
        _previousCount < 16 &&
        currentCount >= 16 &&
        calibration.state == CalibrationState.measuring) {
      _phase2DialogShown = true;
      // Schedule dialog for after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPhase2Instructions(context);
        }
      });
    }
    _previousCount = currentCount;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final calibration = context.watch<CalibrationService>();
    final distoX = context.watch<DistoXService>();

    // Check for phase transition on each build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkPhase2Transition();
    });

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
                child: Text(
                  l10n.calibrationModeIndicator,
                  style: const TextStyle(
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
              _CalibrationGuidance(calibration: calibration),

            // Measurement table or start page
            Expanded(
              child: _CalibrationTable(
                measurements: calibration.measurements,
                results: calibration.results,
                calibration: calibration,
                distoX: distoX,
                onStartPressed: () => _showPhase1InstructionsAndStart(context, calibration),
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

  /// Show phase 1 instructions and then start calibration.
  void _showPhase1InstructionsAndStart(
    BuildContext context,
    CalibrationService calibration,
  ) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.calibrationPhase1Title,
          style: const TextStyle(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.calibrationPhase1Instructions,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.calibrationEnvironmentText,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              calibration.startCalibration();
              // Reset phase 2 flag when starting fresh
              _phase2DialogShown = false;
              _previousCount = 0;
            },
            child: Text(l10n.calibrationBegin),
          ),
        ],
      ),
    );
  }

  /// Show phase 2 instructions when transitioning to coverage measurements.
  void _showPhase2Instructions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.calibrationPhase1Complete,
          style: const TextStyle(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.calibrationPreciseMeasurementsDone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.calibrationPhase2Title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.calibrationPhase2Instructions,
                style: const TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.calibrationContinue),
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
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await calibration.writeCoefficients();
              if (success && context.mounted) {
                Navigator.pop(context);
              }
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
  final VoidCallback? onStartPressed;

  const _CalibrationTable({
    required this.measurements,
    required this.results,
    required this.calibration,
    required this.distoX,
    this.onStartPressed,
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
                onPressed: isConnected ? onStartPressed : null,
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

    final detectedPositions = calibration.detectedPositions;

    // Group measurements by direction
    final groups = _buildDirectionGroups(measurements, results, detectedPositions);

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        return _DirectionGroup(
          group: group,
          onMeasurementTap: (measurementIndex, m, r) =>
              _showMeasurementDetails(context, measurementIndex, m, r),
        );
      },
    );
  }

  /// Build direction groups from measurements, ordered by first appearance.
  List<_DirectionGroupData> _buildDirectionGroups(
    List<CalibrationMeasurement> measurements,
    List<CalibrationResult?>? results,
    List<CalibrationPosition?> detectedPositions,
  ) {
    // Track groups by direction index, preserving order of first appearance
    final groupOrder = <int>[]; // Direction indices in order of first appearance
    final groupMeasurements = <int, List<_GroupedMeasurement>>{}; // Direction -> measurements

    for (int i = 0; i < measurements.length; i++) {
      final m = measurements[i];
      final r = results != null && i < results.length ? results[i] : null;
      final detectedPos = i < detectedPositions.length ? detectedPositions[i] : null;

      // Determine direction: use detected position if available, otherwise use index-based
      final direction = detectedPos?.direction ?? (i ~/ 4);
      final rollIndex = detectedPos?.rollIndex ?? (i % 4);

      // Track first appearance order
      if (!groupMeasurements.containsKey(direction)) {
        groupOrder.add(direction);
        groupMeasurements[direction] = [];
      }

      groupMeasurements[direction]!.add(_GroupedMeasurement(
        measurementIndex: i,
        measurement: m,
        result: r,
        detectedPosition: detectedPos,
        rollIndex: rollIndex,
      ));
    }

    // Build group data in order of first appearance
    return groupOrder.map((direction) {
      final groupMeas = groupMeasurements[direction]!;
      // Sort by roll index within the group
      groupMeas.sort((a, b) => a.rollIndex.compareTo(b.rollIndex));

      // Count filled rolls (unique roll indices)
      final filledRolls = groupMeas.map((m) => m.rollIndex).toSet().length;

      // Check if any measurement has high error
      final hasError = groupMeas.any((m) => m.result != null && m.result!.error >= 0.5);

      return _DirectionGroupData(
        direction: direction,
        measurements: groupMeas,
        filledRolls: filledRolls,
        hasError: hasError,
      );
    }).toList();
  }

  void _showMeasurementDetails(
    BuildContext context,
    int index,
    CalibrationMeasurement m,
    CalibrationResult? r,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _MeasurementDetailsView(
          index: index,
          measurement: m,
          result: r,
          calibration: calibration,
        ),
      ),
    );
  }
}

/// Data for a single measurement within a group.
class _GroupedMeasurement {
  final int measurementIndex;
  final CalibrationMeasurement measurement;
  final CalibrationResult? result;
  final CalibrationPosition? detectedPosition;
  final int rollIndex;

  const _GroupedMeasurement({
    required this.measurementIndex,
    required this.measurement,
    required this.result,
    required this.detectedPosition,
    required this.rollIndex,
  });
}

/// Data for a direction group.
class _DirectionGroupData {
  final int direction;
  final List<_GroupedMeasurement> measurements;
  final int filledRolls;
  final bool hasError;

  const _DirectionGroupData({
    required this.direction,
    required this.measurements,
    required this.filledRolls,
    required this.hasError,
  });

  bool get isComplete => filledRolls >= 4;
}

/// Widget displaying a direction group with its measurements.
class _DirectionGroup extends StatelessWidget {
  final _DirectionGroupData group;
  final void Function(int measurementIndex, CalibrationMeasurement m, CalibrationResult? r) onMeasurementTap;

  const _DirectionGroup({
    required this.group,
    required this.onMeasurementTap,
  });

  // Direction icons
  static const _directionIcons = [
    Icons.arrow_upward,
    Icons.arrow_forward,
    Icons.arrow_downward,
    Icons.arrow_back,
    Icons.north_east,
    Icons.south_east,
    Icons.south_west,
    Icons.north_west,
    Icons.north_east,
    Icons.south_east,
    Icons.south_west,
    Icons.north_west,
    Icons.expand_less,
    Icons.expand_more,
  ];

  /// Get localized direction label.
  static String getDirectionLabel(AppLocalizations l10n, int direction) {
    switch (direction) {
      case 0: return l10n.calibrationDirectionForward;
      case 1: return l10n.calibrationDirectionRight;
      case 2: return l10n.calibrationDirectionBack;
      case 3: return l10n.calibrationDirectionLeft;
      case 4: return l10n.calibrationDirectionForwardRightUp;
      case 5: return l10n.calibrationDirectionRightBackUp;
      case 6: return l10n.calibrationDirectionBackLeftUp;
      case 7: return l10n.calibrationDirectionLeftForwardUp;
      case 8: return l10n.calibrationDirectionForwardRightDown;
      case 9: return l10n.calibrationDirectionRightBackDown;
      case 10: return l10n.calibrationDirectionBackLeftDown;
      case 11: return l10n.calibrationDirectionLeftForwardDown;
      case 12: return l10n.calibrationDirectionUp;
      case 13: return l10n.calibrationDirectionDown;
      default: return l10n.calibrationDirectionN(direction);
    }
  }

  /// Get localized roll label.
  static String getRollLabel(AppLocalizations l10n, int rollIndex) {
    switch (rollIndex) {
      case 0: return l10n.calibrationRollFlat;
      case 1: return l10n.calibrationRoll90CW;
      case 2: return l10n.calibrationRollUpsideDown;
      case 3: return l10n.calibrationRoll90CCW;
      default: return l10n.calibrationRollN(rollIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dirLabel = getDirectionLabel(l10n, group.direction);
    final dirIcon = group.direction < _directionIcons.length
        ? _directionIcons[group.direction]
        : Icons.explore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: group.isComplete
                ? Colors.green.withValues(alpha: 0.1)
                : group.hasError
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                dirIcon,
                size: 20,
                color: group.isComplete
                    ? Colors.green
                    : group.hasError
                        ? Colors.orange
                        : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dirLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: group.isComplete
                        ? Colors.green.shade700
                        : group.hasError
                            ? Colors.orange.shade700
                            : null,
                  ),
                ),
              ),
              // Completion indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: group.isComplete
                      ? Colors.green.withValues(alpha: 0.2)
                      : group.hasError
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (group.isComplete)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.check, size: 14, color: Colors.green),
                      )
                    else if (group.hasError)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                      ),
                    Text(
                      '${group.filledRolls}/4',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: group.isComplete
                            ? Colors.green.shade700
                            : group.hasError
                                ? Colors.orange.shade700
                                : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Measurements in this group
        ...group.measurements.map((gm) => _GroupedMeasurementRow(
              groupedMeasurement: gm,
              rollLabel: getRollLabel(l10n, gm.rollIndex),
              onTap: () => onMeasurementTap(gm.measurementIndex, gm.measurement, gm.result),
            )),
      ],
    );
  }
}

/// Row for a single measurement within a group.
class _GroupedMeasurementRow extends StatelessWidget {
  final _GroupedMeasurement groupedMeasurement;
  final String rollLabel;
  final VoidCallback onTap;

  const _GroupedMeasurementRow({
    required this.groupedMeasurement,
    required this.rollLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = groupedMeasurement.measurement;
    final r = groupedMeasurement.result;
    final hasError = r != null && r.error >= 0.5;
    final disabledColor = Theme.of(context).colorScheme.outline;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: !m.enabled
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : hasError
                  ? Colors.orange.withValues(alpha: 0.05)
                  : null,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 44, right: 12, top: 8, bottom: 8),
          child: Row(
            children: [
              // Roll indicator
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rollLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: m.enabled ? null : disabledColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Error value if available
              if (r != null)
                SizedBox(
                  width: 50,
                  child: Text(
                    'Δ ${r.error.toStringAsFixed(2)}°',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasError ? Colors.orange : Colors.green,
                      fontWeight: hasError ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              const Spacer(),
              // Status icon
              if (hasError)
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 16,
                )
              else if (r != null)
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green.withValues(alpha: 0.7),
                  size: 16,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen view showing measurement details.
class _MeasurementDetailsView extends StatelessWidget {
  final int index;
  final CalibrationMeasurement measurement;
  final CalibrationResult? result;
  final CalibrationService calibration;

  const _MeasurementDetailsView({
    required this.index,
    required this.measurement,
    required this.result,
    required this.calibration,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasError = result != null && result!.error >= 0.5;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.calibrationMeasurement} #${index + 1}'),
        actions: [
          // Toggle enabled
          IconButton(
            onPressed: () {
              calibration.toggleEnabled(index);
              Navigator.pop(context);
            },
            icon: Icon(
              measurement.enabled ? Icons.visibility_off : Icons.visibility,
            ),
            tooltip: measurement.enabled ? l10n.calibrationDisable : l10n.calibrationEnable,
          ),
          // Delete
          IconButton(
            onPressed: () {
              calibration.deleteMeasurement(index);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status badge
          if (hasError)
            _buildStatusBadge(context, l10n.calibrationHighError, Colors.orange)
          else if (result != null)
            _buildStatusBadge(context, l10n.calibrationGood, Colors.green),

          const SizedBox(height: 24),

          // Raw sensor values
          Text(
            l10n.calibrationRawValues,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          _buildDataCard(context, [
            _DataRow('Gx', measurement.gx.toString()),
            _DataRow('Gy', measurement.gy.toString()),
            _DataRow('Gz', measurement.gz.toString()),
          ]),
          const SizedBox(height: 8),
          _buildDataCard(context, [
            _DataRow('Mx', measurement.mx.toString()),
            _DataRow('My', measurement.my.toString()),
            _DataRow('Mz', measurement.mz.toString()),
          ]),

          // Computed results if available
          if (result != null) ...[
            const SizedBox(height: 24),
            Text(
              l10n.calibrationComputedValues,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            _buildDataCard(context, [
              _DataRow(l10n.calibrationError, '${result!.error.toStringAsFixed(3)}°',
                  highlight: hasError),
              _DataRow(l10n.calibrationAzimuth, '${result!.azimuth.toStringAsFixed(1)}°'),
              _DataRow(l10n.calibrationInclination, '${result!.inclination.toStringAsFixed(1)}°'),
              _DataRow(l10n.calibrationRoll, '${result!.roll.toStringAsFixed(1)}°'),
            ]),
            const SizedBox(height: 8),
            _buildDataCard(context, [
              _DataRow('|G|', result!.gMagnitude.toStringAsFixed(4)),
              _DataRow('|M|', result!.mMagnitude.toStringAsFixed(4)),
              _DataRow(l10n.calibrationAlphaDip, '${result!.alpha.toStringAsFixed(2)}°'),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            color == Colors.green ? Icons.check_circle : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(BuildContext context, List<_DataRow> rows) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: rows.map((row) => _buildRow(context, row)).toList(),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _DataRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              row.label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: row.highlight ? FontWeight.bold : null,
                color: row.highlight ? Colors.orange : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow {
  final String label;
  final String value;
  final bool highlight;

  const _DataRow(this.label, this.value, {this.highlight = false});
}

/// Guidance widget showing what measurement to take next.
/// Uses auto-detection when available to show progress by filled slots.
class _CalibrationGuidance extends StatelessWidget {
  final CalibrationService calibration;

  const _CalibrationGuidance({required this.calibration});

  /// Find first measurement with high error for retake.
  int? _findFirstBadMeasurement() {
    final measurements = calibration.measurements;
    final results = calibration.results;

    // Don't suggest corrections until all 56 measurements are done
    if (measurements.length < 56) return null;
    if (results == null) return null;

    for (int i = 0; i < results.length && i < measurements.length; i++) {
      final r = results[i];
      if (r != null && measurements[i].enabled && r.error >= 0.5) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final measurements = calibration.measurements;
    final count = measurements.length;
    final badIndex = _findFirstBadMeasurement();
    final isRetake = badIndex != null;

    // Use auto-detection progress if available
    final useAutoDetect = calibration.canAutoDetect && calibration.autoDetectEnabled;
    final filledSlots = useAutoDetect ? calibration.filledSlotCount : count;
    final suggestedDescription = useAutoDetect
        ? _getLocalizedSuggestedDescription(l10n)
        : null;

    // If all 56 slots filled and no bad measurements, show completion
    if (filledSlots >= 56 && !isRetake) {
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
            Expanded(
              child: Text(
                l10n.calibrationComplete,
                style: const TextStyle(fontWeight: FontWeight.w600),
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

    // Progress as fraction (use filled slots if auto-detect is available)
    final progress = filledSlots / 56;

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

          // Retake warning
          if (isRetake) ...[
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.calibrationRetakeNeeded(badIndex + 1),
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

          // Suggested next shot (from auto-detection or fallback)
          Row(
            children: [
              // Direction icon based on suggested position
              Icon(
                _getDirectionIcon(calibration.suggestedNext?.direction),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestedDescription ?? _getFallbackDescription(l10n, count),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (useAutoDetect && calibration.suggestedNext != null)
                      Text(
                        _getRollDescription(l10n, calibration.suggestedNext!.rollIndex),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),

              // Progress text (show both if different)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$filledSlots / 56',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isRetake ? Colors.orange : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (useAutoDetect && count != filledSlots)
                    Text(
                      '($count shots)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get direction icon for a direction index.
  IconData _getDirectionIcon(int? direction) {
    const icons = [
      Icons.arrow_upward,    // 0: North
      Icons.arrow_forward,   // 1: East
      Icons.arrow_downward,  // 2: South
      Icons.arrow_back,      // 3: West
      Icons.north_east,      // 4: NE up
      Icons.south_east,      // 5: SE up
      Icons.south_west,      // 6: SW up
      Icons.north_west,      // 7: NW up
      Icons.north_east,      // 8: NE down
      Icons.south_east,      // 9: SE down
      Icons.south_west,      // 10: SW down
      Icons.north_west,      // 11: NW down
      Icons.expand_less,     // 12: Up
      Icons.expand_more,     // 13: Down
    ];
    if (direction == null || direction < 0 || direction >= icons.length) {
      return Icons.explore;
    }
    return icons[direction];
  }

  /// Get localized roll description.
  String _getRollDescription(AppLocalizations l10n, int rollIndex) {
    switch (rollIndex) {
      case 0: return l10n.calibrationRollDescFlat;
      case 1: return l10n.calibrationRollDesc90CW;
      case 2: return l10n.calibrationRollDescUpsideDown;
      case 3: return l10n.calibrationRollDesc90CCW;
      default: return '';
    }
  }

  /// Get localized suggested description from auto-detect.
  String? _getLocalizedSuggestedDescription(AppLocalizations l10n) {
    final suggested = calibration.suggestedNext;
    if (suggested == null) return null;
    return _DirectionGroup.getDirectionLabel(l10n, suggested.direction);
  }

  /// Fallback description when auto-detect not available.
  String _getFallbackDescription(AppLocalizations l10n, int count) {
    if (count >= 56) return l10n.calibrationTakeMoreOrRetake;
    final dirIndex = count ~/ 4;
    final rollIndex = count % 4;
    final progress = (count % 4) + 1; // Which shot of 4 for this direction
    final dir = _DirectionGroup.getDirectionLabel(l10n, dirIndex);
    final roll = _DirectionGroup.getRollLabel(l10n, rollIndex);
    return l10n.calibrationShotDescription(dir, roll, progress);
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
