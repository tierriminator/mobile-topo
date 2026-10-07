import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/calibration.dart';
import '../services/calibration_diagnosis.dart';
import '../services/calibration_service.dart';
import '../services/distox_service.dart';
import 'widgets/calibration_cube.dart';

/// Full-screen calibration view for DistoX device calibration.
///
/// Displays:
/// - Connection status and calibration mode indicator
/// - While slots are open, the next shot to take
/// - Once all slots are filled, the directions to retake and the Write button
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
    // Null once all 56 slots are filled
    final nextShot = calibration.suggestedNext;
    final started = calibration.state == CalibrationState.measuring ||
        calibration.measurementCount > 0;

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

            if (!started)
              Expanded(
                child: _StartPage(
                  isConnected: distoX.isConnected,
                  onStartPressed: () =>
                      _showPhase1InstructionsAndStart(context, calibration),
                ),
              )
            // While slots are open, only the next shot is shown
            else if (nextShot != null)
              Expanded(
                child: _NextShotPanel(calibration: calibration, next: nextShot),
              )
            else ...[
              Expanded(child: _Overview(calibration: calibration)),
              if (calibration.hasResults)
                _WriteBar(calibration: calibration, distoX: distoX),
            ],
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
                    Expanded(
                      child: Text(
                        l10n.calibrationPreciseMeasurementsDone,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.calibrationPhase2Tip,
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.calibrationContinue),
          ),
        ],
      ),
    );
  }
}

/// Localized name of a calibration direction.
String _directionLabel(AppLocalizations l10n, int direction) {
  switch (direction) {
    case 0: return l10n.calibrationDirection0;
    case 1: return l10n.calibrationDirection1;
    case 2: return l10n.calibrationDirection2;
    case 3: return l10n.calibrationDirection3;
    case 4: return l10n.calibrationDirection4;
    case 5: return l10n.calibrationDirection5;
    case 6: return l10n.calibrationDirection6;
    case 7: return l10n.calibrationDirection7;
    case 8: return l10n.calibrationDirection8;
    case 9: return l10n.calibrationDirection9;
    case 10: return l10n.calibrationDirection10;
    case 11: return l10n.calibrationDirection11;
    case 12: return l10n.calibrationDirection12;
    case 13: return l10n.calibrationDirection13;
    default: return l10n.calibrationDirectionN(direction);
  }
}

/// Which way the display faces for [rollIndex] in [direction].
///
/// Pointing vertically, the display faces sideways in every orientation.
/// Tilting the device from horizontal with the display up to pointing up
/// turns the display towards the person, and to pointing down turns it
/// forward, so "up" becomes backward or forward respectively.
String _displayLabel(AppLocalizations l10n, int direction, int rollIndex) {
  final (_, inclination) = CalibrationPositions.relativeDirections[direction];
  final vertical = inclination.abs() == 90;
  final upFacesForward = inclination < 0;
  switch (rollIndex) {
    case 1: return l10n.calibrationDisplayRight;
    case 3: return l10n.calibrationDisplayLeft;
    case 2:
      if (!vertical) return l10n.calibrationDisplayDown;
      return upFacesForward
          ? l10n.calibrationDisplayBackward
          : l10n.calibrationDisplayForward;
    default:
      if (!vertical) return l10n.calibrationDisplayUp;
      return upFacesForward
          ? l10n.calibrationDisplayForward
          : l10n.calibrationDisplayBackward;
  }
}

/// Labels for the forward, right, back and left faces of the cube.
List<String> _faceLabels(AppLocalizations l10n) =>
    [for (int d = 0; d < 4; d++) _directionLabel(l10n, d)];

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

/// Button at the bottom that writes the coefficients to the device: green
/// with a checkmark when the calibration error is within
/// [CalibrationService.errorThreshold], yellow with a warning and a
/// confirmation otherwise.
class _WriteBar extends StatelessWidget {
  final CalibrationService calibration;
  final DistoXService distoX;

  const _WriteBar({required this.calibration, required this.distoX});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = calibration.state != CalibrationState.idle &&
        calibration.state != CalibrationState.measuring;
    final rmsError = calibration.rmsError;
    final isGood =
        rmsError != null && rmsError < CalibrationService.errorThreshold;
    final background =
        isGood ? CalibrationShotColors.done : CalibrationShotColors.current;
    final foreground = isGood ? Colors.white : Colors.black87;

    // Continues the background of the panel above it
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: isBusy || !distoX.isConnected
                ? null
                : isGood
                    ? () => _write(context)
                    : () => _confirmWrite(context, l10n, rmsError),
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isGood ? Icons.check : Icons.warning_amber_rounded),
            label: Text(l10n.calibrationWrite),
          ),
        ),
      ),
    );
  }

  Future<void> _write(BuildContext context) async {
    final success = await calibration.writeCoefficients();
    if (success && context.mounted) {
      Navigator.pop(context);
    }
  }

  void _confirmWrite(
    BuildContext context,
    AppLocalizations l10n,
    double? rmsError,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: CalibrationShotColors.currentOutline,
        ),
        title: Text(l10n.calibrationHighErrorTitle),
        content: Text(l10n.calibrationHighErrorConfirm(
          rmsError?.toStringAsFixed(2) ?? '–',
          CalibrationService.errorThreshold.toStringAsFixed(2),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _write(context);
            },
            child: Text(l10n.calibrationWriteAnyway),
          ),
        ],
      ),
    );
  }
}

/// Introduction with the button that starts calibration.
class _StartPage extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onStartPressed;

  const _StartPage({required this.isConnected, required this.onStartPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
}

/// The shot to take next while slots are still open: its direction in a cube
/// around the person calibrating, the device orientation, and a short
/// description.
class _NextShotPanel extends StatelessWidget {
  final CalibrationService calibration;
  final CalibrationPosition next;

  const _NextShotPanel({required this.calibration, required this.next});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final filled = calibration.filledSlots;
    final completedDirections = {
      for (final MapEntry(key: direction, value: rolls)
          in calibration.progressByDirection.entries)
        if (rolls >= 4) direction,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: filled.length / 56,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                if (CalibrationPositions.isPrecise(next.direction)) ...[
                  const Icon(Icons.gps_fixed, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.calibrationPreciseMeasurement,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (calibration.canUndoLastShot)
                  TextButton.icon(
                    onPressed: () => _confirmUndo(context, l10n),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(l10n.calibrationUndoLastShot),
                  ),
              ],
            ),
          ),

          // Direction
          Expanded(
            child: CalibrationCube(
              currentDirection: next.direction,
              completedDirections: completedDirections,
              faceLabels: _faceLabels(l10n),
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _directionLabel(l10n, next.direction),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Device orientation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CalibrationShotColors.current.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CalibrationShotColors.current.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                DeviceRollIndicator(rollIndex: next.rollIndex),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayLabel(l10n, next.direction, next.rollIndex),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // The four orientations of this direction
                      Row(
                        children: [
                          for (int r = 0; r < 4; r++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.circle,
                                size: 12,
                                color: r == next.rollIndex
                                    ? CalibrationShotColors.current
                                    : filled.contains(next.direction * 4 + r)
                                        ? CalibrationShotColors.done
                                        : theme.colorScheme.outline
                                            .withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmUndo(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.calibrationUndoLastShot),
        content: Text(l10n.calibrationUndoConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              calibration.undoLastShot();
            },
            child: Text(l10n.undo),
          ),
        ],
      ),
    );
  }
}

/// All directions once every slot is filled, with the flagged ones in red
/// and listed below the cube for retaking.
class _Overview extends StatelessWidget {
  final CalibrationService calibration;

  const _Overview({required this.calibration});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diagnosis = calibration.diagnosis;
    final flagged = diagnosis.directions;
    final flaggedDirections = flagged.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The cube takes whatever the panel leaves
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CalibrationCube(
                  currentDirection: null,
                  completedDirections: {
                    for (int d = 0;
                        d < CalibrationPositions.relativeDirections.length;
                        d++)
                      if (!flagged.containsKey(d)) d,
                  },
                  flaggedDirections: flagged.keys.toSet(),
                  faceLabels: _faceLabels(l10n),
                ),
              ),
            ),
            if (calibration.hasResults)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.45,
                ),
                child: _FlaggedDirectionsPanel(
                  problem: diagnosis.problem,
                  children: [
                    for (final direction in flaggedDirections)
                      _FlaggedDirectionTile(
                        direction: direction,
                        issues: flagged[direction]!,
                        onRetake: () => calibration.retakeDirection(direction),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Panel below the cube with the likely cause of a high calibration error
/// and the directions to retake, or saying that all is well.
///
/// The scrollbar stays visible and the bottom edge fades out while rows are
/// hidden below, so that the list reads as scrollable on touch screens too.
class _FlaggedDirectionsPanel extends StatefulWidget {
  final CalibrationProblem? problem;
  final List<Widget> children;

  const _FlaggedDirectionsPanel({
    required this.problem,
    required this.children,
  });

  @override
  State<_FlaggedDirectionsPanel> createState() =>
      _FlaggedDirectionsPanelState();
}

class _FlaggedDirectionsPanelState extends State<_FlaggedDirectionsPanel> {
  final _scrollController = ScrollController();

  /// Whether rows are hidden below the visible part of the list.
  bool _moreBelow = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics metrics) {
    final moreBelow = metrics.extentAfter > 0;
    if (moreBelow != _moreBelow) setState(() => _moreBelow = moreBelow);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final count = widget.children.length;
    final problem = widget.problem;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: count == 0 && problem == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: CalibrationShotColors.done,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.calibrationAllDirectionsGood,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          : NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) => _onMetrics(n.metrics),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) => _onMetrics(n.metrics),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      _moreBelow ? Colors.transparent : Colors.black,
                    ],
                    stops: const [0.75, 1],
                  ).createShader(rect),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    // The cause scrolls with the list, so that a long one
                    // leaves room for the directions
                    child: ListView(
                      controller: _scrollController,
                      shrinkWrap: true,
                      // Inside the list, so its scrollbar stays clear of the
                      // retake buttons
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      children: [
                        if (problem != null) _ProblemMessage(problem: problem),
                        if (count > 0) ...[
                          Padding(
                            padding: EdgeInsets.only(
                              top: problem != null ? 12 : 0,
                              bottom: 4,
                            ),
                            child: _header(l10n, theme, count),
                          ),
                          ...widget.children,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _header(AppLocalizations l10n, ThemeData theme, int count) => Row(
        children: [
          Expanded(
            child: Text(
              l10n.calibrationDirectionsToRetake,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: CalibrationShotColors.flagged,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
}

/// A direction whose shots should be retaken, with a hint per suspect shot
/// and a retake button.
class _FlaggedDirectionTile extends StatelessWidget {
  final int direction;
  final List<ShotIssue> issues;
  final VoidCallback onRetake;

  const _FlaggedDirectionTile({
    required this.direction,
    required this.issues,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(
        Icons.warning_amber_rounded,
        color: CalibrationShotColors.flagged,
      ),
      title: Text(
        _directionLabel(l10n, direction),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_instruction(l10n)),
      trailing: OutlinedButton(
        onPressed: onRetake,
        child: Text(l10n.calibrationRetake),
      ),
    );
  }

  /// What to do differently on the retake: one fix per kind of problem among
  /// the shots, joined with "and".
  String _instruction(AppLocalizations l10n) {
    final problems = issues.map((i) => i.problem).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final fixes = [
      for (final problem in problems)
        switch (problem) {
          ShotProblem.wrongDirection => l10n.calibrationFixDirection,
          ShotProblem.offTarget => l10n.calibrationFixTarget,
          ShotProblem.wrongOrientation => l10n.calibrationFixOrientation,
          ShotProblem.unsteady => l10n.calibrationFixSteady,
          ShotProblem.disturbed => l10n.calibrationFixMagnetic,
        },
    ];
    final joined = fixes.length == 1
        ? fixes.single
        : l10n.calibrationFixesJoined(
            fixes.take(fixes.length - 1).join(', '),
            fixes.last,
          );
    return joined.isEmpty
        ? joined
        : joined[0].toUpperCase() + joined.substring(1);
  }
}

/// What most likely causes the high calibration error, with what to do.
class _ProblemMessage extends StatelessWidget {
  final CalibrationProblem problem;

  const _ProblemMessage({required this.problem});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = switch (problem) {
      CalibrationProblem.coverage => l10n.calibrationProblemCoverage,
      CalibrationProblem.unsteady => l10n.calibrationProblemUnsteady,
      CalibrationProblem.magnetic => l10n.calibrationProblemMagnetic,
      CalibrationProblem.aiming => l10n.calibrationProblemAiming,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CalibrationShotColors.current.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CalibrationShotColors.current.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: CalibrationShotColors.currentOutline,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
